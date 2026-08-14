#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import importlib.util
import json
import math
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GENERATOR_PATH = ROOT / "fixtures" / "quality" / "generate_fixtures.py"
REPORT_PATH = ROOT / "fixtures" / "quality" / "render_report.py"


def load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"unable to load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_frame(path: Path):
    with path.open("rb") as stream:
        if stream.readline() != b"CBEF_RGBA32F\n":
            raise AssertionError(f"invalid frame magic: {path}")
        width, height = (int(value) for value in stream.readline().decode("ascii").split())
        payload = stream.read()
    expected = width * height * 4 * 4
    if len(payload) != expected:
        raise AssertionError(f"invalid frame payload size: {path}")
    values = struct.unpack(f"<{width * height * 4}f", payload)
    return width, height, values


class QualityFixtureTest(unittest.TestCase):
    def generate(self, directory: Path):
        manifest_path = directory / "manifest.json"
        result = subprocess.run(
            [sys.executable, str(GENERATOR_PATH), "--output-dir", str(directory), "--manifest-out", str(manifest_path)],
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertIn("generated 10 fixtures", result.stdout)
        return json.loads(manifest_path.read_text(encoding="utf-8"))

    def test_reproducible_scene_linear_suite_and_provenance(self):
        with tempfile.TemporaryDirectory(prefix="cbef-quality-a-") as first_name, tempfile.TemporaryDirectory(prefix="cbef-quality-b-") as second_name:
            first = Path(first_name)
            second = Path(second_name)
            manifest_a = self.generate(first)
            manifest_b = self.generate(second)
            self.assertEqual(manifest_a, manifest_b)
            self.assertEqual(manifest_a["generator"]["version"], "1.2.0")
            self.assertEqual(manifest_a["color_pipeline"]["domain"], "scene-linear")
            self.assertEqual(len(manifest_a["fixtures"]), 10)
            self.assertEqual(manifest_a["external_assets"]["records"], [])
            self.assertIn("official_url", manifest_a["external_assets"]["record_schema"])
            self.assertIn("download_terms", manifest_a["external_assets"]["record_schema"])
            self.assertIn("color_transform", manifest_a["external_assets"]["record_schema"])

            for entry in manifest_a["fixtures"]:
                frame_a = first / entry["frame_path"]
                frame_b = second / entry["frame_path"]
                mask_a = first / entry["mask_path"]
                mask_b = second / entry["mask_path"]
                self.assertEqual(sha256(frame_a), entry["frame_sha256"])
                self.assertEqual(sha256(mask_a), entry["mask_sha256"])
                self.assertEqual(frame_a.read_bytes(), frame_b.read_bytes())
                self.assertEqual(mask_a.read_bytes(), mask_b.read_bytes())
                width, height, values = read_frame(frame_a)
                self.assertEqual([width, height], entry["resolution"])
                for index in range(0, len(values), 4):
                    self.assertTrue(all(math.isfinite(value) for value in values[index:index + 4]))
                    self.assertGreaterEqual(values[index + 3], 0.0)
                    self.assertLessEqual(values[index + 3], 1.0)
                mask = json.loads(mask_a.read_text(encoding="utf-8"))
                self.assertEqual(mask["fixture_id"], entry["id"])
                self.assertEqual(mask["crop"], entry["crop"])
                self.assertEqual(sorted(entry["expected_mask"]["labels"]), sorted(region["id"] for region in mask["regions"]))
                for metric in entry["metrics"]:
                    self.assertIn(metric["provenance"], manifest_a["provenance_classes"])
                    if metric["provenance"] == "placeholder":
                        self.assertFalse(metric["measured_profile_gate"])

    def test_top_level_render_contract_comparison(self):
        report = load_module(REPORT_PATH, "cbef_render_report")
        baseline = {
            "schema_version": "1.0",
            "fixture_id": "field-psf",
            "effect": "OpticalBlur",
            "backend": "CPU",
            "frame": 0,
            "metrics": {"psf-centroid": 0.12, "psf-energy": 1.0},
            "provenance": {"psf-centroid": "internal tolerance", "psf-energy": "placeholder"},
            "source": "v1-baseline",
        }
        candidate = dict(baseline)
        candidate["backend"] = "Metal"
        candidate["metrics"] = {"psf-centroid": 0.08, "psf-energy": 1.0}
        candidate["source"] = "v2-target"
        comparison = report.compare_reports(baseline, candidate)
        self.assertEqual(comparison["fixture_id"], "field-psf")
        self.assertEqual(comparison["rows"][0]["candidate"], 0.08)
        self.assertIn("placeholder values", comparison["provenance_policy"])

    def test_checked_in_manifest_matches_generated_assets(self):
        manifest = json.loads((ROOT / "fixtures" / "quality" / "manifest.json").read_text(encoding="utf-8"))
        asset_root = ROOT / manifest["asset_root"]
        self.assertEqual(len(manifest["fixtures"]), 10)
        for entry in manifest["fixtures"]:
            frame = asset_root / entry["frame_path"]
            mask = asset_root / entry["mask_path"]
            self.assertTrue(frame.is_file())
            self.assertTrue(mask.is_file())
            self.assertEqual(sha256(frame), entry["frame_sha256"])
            self.assertEqual(sha256(mask), entry["mask_sha256"])
            width, height, values = read_frame(frame)
            self.assertEqual([width, height], entry["resolution"])
            self.assertEqual(len(values), width * height * 4)
        self.assertEqual((ROOT / "fixtures" / "quality" / "local-assets" / ".gitignore").read_text(), "*\n!.gitignore\n")


if __name__ == "__main__":
    unittest.main()
