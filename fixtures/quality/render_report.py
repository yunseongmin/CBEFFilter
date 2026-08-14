#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, Mapping


SCHEMA_VERSION = "1.0"
REQUIRED_FIELDS = ("fixture_id", "effect", "backend", "frame", "metrics", "provenance")
PROVENANCE = {"standard", "measured", "internal tolerance", "placeholder"}


def _load(path: Path) -> Dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"report must be an object: {path}")
    return value


def validate_report(report: Mapping[str, Any]) -> None:
    missing = [field for field in REQUIRED_FIELDS if field not in report]
    if missing:
        raise ValueError(f"report missing fields: {', '.join(missing)}")
    if report.get("schema_version", SCHEMA_VERSION) != SCHEMA_VERSION:
        raise ValueError("unsupported report schema version")
    if not isinstance(report["metrics"], Mapping) or not report["metrics"]:
        raise ValueError("report metrics must be a non-empty object")
    provenance = report["provenance"]
    if not isinstance(provenance, Mapping):
        raise ValueError("report provenance must be an object")
    for metric_id in report["metrics"]:
        if metric_id not in provenance:
            raise ValueError(f"missing provenance for metric: {metric_id}")
        if provenance[metric_id] not in PROVENANCE:
            raise ValueError(f"invalid provenance for metric {metric_id}: {provenance[metric_id]}")


def compare_reports(baseline: Mapping[str, Any], candidate: Mapping[str, Any]) -> Dict[str, Any]:
    validate_report(baseline)
    validate_report(candidate)
    if baseline["fixture_id"] != candidate["fixture_id"]:
        raise ValueError("baseline and candidate fixtures differ")
    if baseline["frame"] != candidate["frame"]:
        raise ValueError("baseline and candidate frames differ")
    metric_ids = sorted(set(baseline["metrics"]) | set(candidate["metrics"]))
    rows = []
    for metric_id in metric_ids:
        old = baseline["metrics"].get(metric_id)
        new = candidate["metrics"].get(metric_id)
        delta = None if old is None or new is None else new - old
        rows.append({
            "metric": metric_id,
            "baseline": old,
            "candidate": new,
            "delta": delta,
            "baseline_provenance": baseline["provenance"].get(metric_id),
            "candidate_provenance": candidate["provenance"].get(metric_id),
        })
    return {
        "schema_version": SCHEMA_VERSION,
        "fixture_id": baseline["fixture_id"],
        "effect": candidate["effect"],
        "backend": candidate["backend"],
        "frame": candidate["frame"],
        "baseline_source": baseline.get("source", "v1-baseline"),
        "candidate_source": candidate.get("source", "v2-candidate"),
        "rows": rows,
        "provenance_policy": "placeholder values are not measured-profile approval evidence",
    }


def render_markdown(comparison: Mapping[str, Any]) -> str:
    lines = [
        f"# Render Contract Comparison: {comparison['fixture_id']}",
        "",
        f"- Effect: `{comparison['effect']}`",
        f"- Backend: `{comparison['backend']}`",
        f"- Frame: `{comparison['frame']}`",
        f"- Baseline: `{comparison['baseline_source']}`",
        f"- Candidate: `{comparison['candidate_source']}`",
        "",
        "| Metric | v1 baseline | v2 candidate | Delta | Baseline provenance | Candidate provenance |",
        "|---|---:|---:|---:|---|---|",
    ]
    for row in comparison["rows"]:
        lines.append("| {metric} | {baseline} | {candidate} | {delta} | {baseline_provenance} | {candidate_provenance} |".format(**row))
    lines.extend(["", f"> {comparison['provenance_policy']}", ""])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare top-level Render Contract metric reports.")
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--markdown", type=Path)
    args = parser.parse_args()
    comparison = compare_reports(_load(args.baseline), _load(args.candidate))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(comparison, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    if args.markdown:
        args.markdown.parent.mkdir(parents=True, exist_ok=True)
        args.markdown.write_text(render_markdown(comparison), encoding="utf-8")
    print(f"compared {comparison['fixture_id']} -> {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
