#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
from pathlib import Path
from typing import Dict, List, Sequence, Tuple


GENERATOR_VERSION = "1.2.0"
FORMAT_MAGIC = b"CBEF_RGBA32F\n"
REQUIRED_FIXTURES = (
    "exposure-color-ramp",
    "flat-fields",
    "point-source-sweep-grid",
    "slanted-edge",
    "thin-line",
    "signage-led",
    "alpha-edge",
    "field-psf",
    "mist-detail-frequency",
    "grain-response-grid",
)
PROVENANCE_CLASSES = {
    "standard": "Measurement definition or invariant directly specified by a public standard.",
    "measured": "Envelope measured from a fixed, rights-cleared asset and acquisition manifest.",
    "internal tolerance": "Project regression or CPU/Metal agreement limit; not a material claim.",
    "placeholder": "Temporary calibration target; never evidence for a measured profile.",
}

Pixel = Tuple[float, float, float, float]
Region = Dict[str, object]


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _write_frame(path: Path, width: int, height: int, pixels: Sequence[Pixel]) -> None:
    if len(pixels) != width * height:
        raise ValueError("pixel count does not match dimensions")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as stream:
        stream.write(FORMAT_MAGIC)
        stream.write(f"{width} {height}\n".encode("ascii"))
        for pixel in pixels:
            stream.write(struct.pack("<4f", *pixel))


def _coord(x: int, y: int, width: int, height: int) -> Tuple[float, float]:
    return (x + 0.5) / width, (y + 0.5) / height


def _blank(width: int, height: int, value: Pixel = (0.0, 0.0, 0.0, 1.0)) -> List[Pixel]:
    return [value] * (width * height)


def _set(pixels: List[Pixel], width: int, x: int, y: int, value: Pixel) -> None:
    if 0 <= x < width and 0 <= y < len(pixels) // width:
        pixels[y * width + x] = value


def _fixture_exposure_color_ramp(width: int, height: int) -> Tuple[List[Pixel], List[Region]]:
    pixels: List[Pixel] = []
    for y in range(height):
        for x in range(width):
            u, v = _coord(x, y, width, height)
            stop = -10.0 + 20.0 * u
            intensity = math.pow(2.0, stop)
            band = min(3, int(v * 4.0))
            if band == 0:
                rgb = (intensity, intensity, intensity)
            elif band == 1:
                rgb = (intensity, intensity * 0.08, intensity * 0.03)
            elif band == 2:
                rgb = (intensity * 0.03, intensity * 0.08, intensity)
            else:
                rgb = (intensity * 0.90, intensity * 0.40, intensity * 0.06)
            pixels.append((rgb[0], rgb[1], rgb[2], 1.0))
    regions = [
        {"id": "neutral", "shape": "rect", "x": 0, "y": 0, "width": width, "height": height // 4},
        {"id": "red", "shape": "rect", "x": 0, "y": height // 4, "width": width, "height": height // 4},
        {"id": "blue", "shape": "rect", "x": 0, "y": height // 2, "width": width, "height": height // 4},
        {"id": "tungsten", "shape": "rect", "x": 0, "y": 3 * height // 4, "width": width, "height": height - 3 * height // 4},
    ]
    return pixels, regions


def _fixture_flat_fields(width: int, height: int) -> Tuple[List[Pixel], List[Region]]:
    pixels = _blank(width, height)
    fields = (
        ((0.18, 0.18, 0.18, 1.0), "neutral-mid"),
        ((1.0, 1.0, 1.0, 1.0), "neutral-white"),
        ((4.0, 1.5, 0.2, 1.0), "hdr-warm"),
        ((-0.06, 0.02, 0.12, 1.0), "negative-residual"),
    )
    regions: List[Region] = []
    half_w, half_h = width // 2, height // 2
    for index, (value, name) in enumerate(fields):
        x = (index % 2) * half_w
        y = (index // 2) * half_h
        for row in range(y, y + half_h):
            for column in range(x, x + half_w):
                _set(pixels, width, column, row, value)
        regions.append({"id": name, "shape": "rect", "x": x, "y": y, "width": half_w, "height": half_h})
    return pixels, regions


def _fixture_point_source_sweep_grid(width: int, height: int) -> Tuple[List[Pixel], List[Region]]:
    pixels = _blank(width, height, (0.002, 0.002, 0.002, 1.0))
    regions: List[Region] = []
    radius = max(1, width // 160)
    for row in range(3):
        for column in range(5):
            cx = int((column + 1) * width / 6)
            cy = int((row + 1) * height / 4)
            channel = (row + column) % 3
            colour = [0.02, 0.02, 0.02]
            colour[channel] = 8.0 + row * 2.0 + column
            for y in range(cy - radius, cy + radius + 1):
                for x in range(cx - radius, cx + radius + 1):
                    if (x - cx) ** 2 + (y - cy) ** 2 <= radius * radius:
                        _set(pixels, width, x, y, (colour[0], colour[1], colour[2], 1.0))
            regions.append({"id": f"grid-{row}-{column}", "shape": "circle", "cx": cx, "cy": cy, "radius": radius})
    y = height - max(3, height // 8)
    for x in range(width):
        value = 0.05 + 12.0 * (x / max(1, width - 1))
        _set(pixels, width, x, y, (value, value * 0.4, value * 0.08, 1.0))
    regions.append({"id": "sweep", "shape": "line", "x1": 0, "y1": y, "x2": width - 1, "y2": y, "width": 1})
    return pixels, regions


def _fixture_slanted_edge(width: int, height: int) -> Tuple[List[Pixel], List[Region]]:
    pixels: List[Pixel] = []
    regions = [{"id": "dark", "shape": "polygon", "points": [[0, 0], [width, 0], [0, height]]},
               {"id": "bright", "shape": "polygon", "points": [[width, 0], [width, height], [0, height]]}]
    for y in range(height):
        for x in range(width):
            bright = x + 0.41 * y >= width * 0.52
            pixels.append((2.0 if bright else 0.01, 1.5 if bright else 0.008, 1.0 if bright else 0.006, 1.0))
    return pixels, regions


def _fixture_thin_line(width: int, height: int) -> Tuple[List[Pixel], List[Region]]:
    pixels = _blank(width, height, (0.004, 0.004, 0.004, 1.0))
    regions: List[Region] = []
    for index, y in enumerate((height // 5, height // 2, 4 * height // 5)):
        colour = ((3.0, 1.2, 0.2), (0.2, 1.5, 4.0), (4.0, 4.0, 4.0))[index]
        line_width = (1, 2, 3)[index]
        for row in range(y, min(height, y + line_width)):
            for x in range(width // 8, 7 * width // 8):
                _set(pixels, width, x, row, (colour[0], colour[1], colour[2], 1.0))
        regions.append({"id": f"line-{line_width}px", "shape": "line", "x1": width // 8, "y1": y,
                        "x2": 7 * width // 8 - 1, "y2": y + line_width - 1, "width": line_width})
    return pixels, regions


def _fixture_signage_led(width: int, height: int) -> Tuple[List[Pixel], List[Region]]:
    pixels = _blank(width, height, (0.003, 0.004, 0.006, 1.0))
    regions: List[Region] = []
    bar_h = max(2, height // 8)
    bars = (("red-led", (10.0, 0.05, 0.02)), ("green-led", (0.05, 10.0, 0.08)),
            ("blue-led", (0.02, 0.05, 10.0)), ("white-signage", (8.0, 8.0, 8.0)))
    for index, (name, rgb) in enumerate(bars):
        y = (index + 1) * height // 6
        for row in range(y, min(height, y + bar_h)):
            for x in range(width // 10, 9 * width // 10):
                _set(pixels, width, x, row, (rgb[0], rgb[1], rgb[2], 1.0))
        regions.append({"id": name, "shape": "rect", "x": width // 10, "y": y,
                        "width": 8 * width // 10, "height": bar_h})
    for row in range(2):
        for column in range(8):
            x = width // 6 + column * max(1, width // 14)
            y = 5 * height // 6 + row * max(1, height // 24)
            _set(pixels, width, x, y, (5.0, 2.0, 0.1, 1.0))
    regions.append({"id": "fine-led-array", "shape": "grid", "x": width // 6, "y": 5 * height // 6,
                    "columns": 8, "rows": 2})
    return pixels, regions


def _fixture_alpha_edge(width: int, height: int) -> Tuple[List[Pixel], List[Region]]:
    pixels: List[Pixel] = []
    cx, cy = width * 0.5, height * 0.5
    radius = min(width, height) * 0.30
    for y in range(height):
        for x in range(width):
            distance = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            alpha = max(0.0, min(1.0, (radius + 1.0 - distance) / 2.0))
            checker = 0.05 if ((x // 8 + y // 8) % 2) else 0.20
            pixels.append((2.0 * alpha, 0.3 * alpha, 0.05 * alpha, alpha))
            if alpha == 0.0:
                pixels[-1] = (checker, checker, checker, 0.0)
    regions = [{"id": "semi-transparent-circle", "shape": "circle", "cx": cx, "cy": cy, "radius": radius},
               {"id": "transparent-checker", "shape": "rect", "x": 0, "y": 0, "width": width, "height": height}]
    return pixels, regions


def _fixture_field_psf(width: int, height: int) -> Tuple[List[Pixel], List[Region]]:
    pixels = _blank(width, height, (0.001, 0.001, 0.001, 1.0))
    regions: List[Region] = []
    points = ((0.12, 0.12), (0.50, 0.12), (0.88, 0.12), (0.12, 0.50),
              (0.50, 0.50), (0.88, 0.50), (0.12, 0.88), (0.50, 0.88), (0.88, 0.88))
    radius = max(1, width // 100)
    for index, (u, v) in enumerate(points):
        cx, cy = int(u * width), int(v * height)
        for y in range(cy - radius, cy + radius + 1):
            for x in range(cx - radius, cx + radius + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= radius * radius:
                    value = 4.0 + index * 0.25
                    _set(pixels, width, x, y, (value, value * 0.9, value * 0.75, 1.0))
        regions.append({"id": f"psf-{index}", "shape": "point", "x": cx, "y": cy, "radius": radius,
                        "field": {"u": u, "v": v}})
    return pixels, regions


def _fixture_mist_detail_frequency(width: int, height: int) -> Tuple[List[Pixel], List[Region]]:
    pixels = _blank(width, height, (0.18, 0.18, 0.18, 1.0))
    regions: List[Region] = []
    for y in range(16, min(height, 72)):
        for x in range(12, min(width, 72)):
            value = 0.30 if (x + y) % 2 == 0 else 0.08
            _set(pixels, width, x, y, (value, value * 0.92, value * 0.85, 1.0))
    regions.append({"id": "skin-fine", "shape": "checker", "x": 12, "y": 16, "width": 60,
                    "height": 56, "period": 2})
    for y in range(10, min(height, 68)):
        value = 1.0 if y < height // 2 else 0.02
        _set(pixels, width, min(width - 1, 100), y, (value, value, value, 1.0))
    regions.append({"id": "eye-edge", "shape": "slanted-edge", "x": 100, "y": 10, "width": 1,
                    "height": 58, "angle": 0.17})
    for line in range(6):
        y = 10 + line * 8
        for x in range(116, min(width, 184)):
            _set(pixels, width, x, y, (0.50, 0.40, 0.30, 1.0))
    regions.append({"id": "hair", "shape": "line-stack", "x": 116, "y": 10, "width": 68,
                    "height": 48, "spacing": 8})
    for y in range(88, min(height, 132)):
        for x in range(12, min(width, 108)):
            value = 0.26 if (x + y) % 5 < 2 else 0.12
            _set(pixels, width, x, y, (value, value * 0.96, value * 0.90, 1.0))
    regions.append({"id": "fabric", "shape": "woven-grid", "x": 12, "y": 88, "width": 96,
                    "height": 44, "period": 5})
    _set(pixels, width, min(width - 1, 216), min(height - 1, 108), (8.0, 8.0, 8.0, 1.0))
    regions.append({"id": "flare", "shape": "point-source", "cx": 216, "cy": 108, "radius": 1,
                    "value": 8.0})
    return pixels, regions


def _fixture_grain_response_grid(width: int, height: int) -> Tuple[List[Pixel], List[Region]]:
    pixels: List[Pixel] = []
    regions: List[Region] = []
    columns, rows = 3, 3
    for y in range(height):
        for x in range(width):
            column = min(columns - 1, x * columns // width)
            row = min(rows - 1, y * rows // height)
            stop = -4.0 + row * 4.0
            intensity = math.pow(2.0, stop) * 0.18
            channel = (column + row) % 3
            rgb = [intensity, intensity, intensity]
            if column != 0:
                rgb[channel] *= 0.45
                rgb[(channel + 1) % 3] *= 0.82
            pixels.append((rgb[0], rgb[1], rgb[2], 1.0))
    for row in range(rows):
        for column in range(columns):
            regions.append({"id": f"exposure-{row}-record-{column}", "shape": "rect",
                            "x": column * width // columns, "y": row * height // rows,
                            "width": width // columns, "height": height // rows,
                            "exposure_stops": -4.0 + row * 4.0,
                            "record": ("neutral", "red", "green")[column]})
    return pixels, regions


GENERATORS = {
    "exposure-color-ramp": _fixture_exposure_color_ramp,
    "flat-fields": _fixture_flat_fields,
    "point-source-sweep-grid": _fixture_point_source_sweep_grid,
    "slanted-edge": _fixture_slanted_edge,
    "thin-line": _fixture_thin_line,
    "signage-led": _fixture_signage_led,
    "alpha-edge": _fixture_alpha_edge,
    "field-psf": _fixture_field_psf,
    "mist-detail-frequency": _fixture_mist_detail_frequency,
    "grain-response-grid": _fixture_grain_response_grid,
}


def _metric(metric_id: str, method: str, provenance: str, threshold: object, notes: str,
            gate_role: str = "model") -> Dict[str, object]:
    return {"id": metric_id, "method": method, "provenance": provenance,
            "threshold": threshold, "gate_role": gate_role, "measured_profile_gate": provenance == "measured",
            "notes": notes}


def _metrics_for(fixture_id: str) -> List[Dict[str, object]]:
    common = [
        _metric("finite-float", "all RGBA values are finite; alpha is within [0,1]", "standard", True,
                "Safety invariant for the float render surface", "safety"),
        _metric("no-wrap", "effect output samples remain inside the declared crop", "internal tolerance", True,
                "Project edge-safety invariant; not an optical measurement", "safety"),
    ]
    if fixture_id == "exposure-color-ramp":
        common.append(_metric("exposure-order", "monotonic median luminance across -10..+10 stop ramp", "internal tolerance",
                              "non-decreasing", "Regression target for exposure response", "model"))
    elif fixture_id == "slanted-edge":
        common.append(_metric("slanted-edge-mtf", "edge spread / MTF measurement on the bright-dark transition", "standard",
                              "method-defined", "Method reference is recorded; project pass envelope is separate", "model"))
    elif fixture_id == "field-psf":
        common.extend([
            _metric("psf-centroid", "centroid of each point response", "internal tolerance", "<= 0.25 px jump",
                    "Tile continuity target", "model"),
            _metric("psf-second-moment", "normalized x/y second moment of each point response", "internal tolerance",
                    "continuous center-to-corner", "Field-dependent PSF shape regression; not a measured lens profile",
                    "model"),
            _metric("psf-axis-ratio", "sqrt(second-moment-x / second-moment-y) across field points", "placeholder",
                    "profile-specific", "Synthetic cat-eye target; calibration placeholder", "measured-profile-forbidden"),
            _metric("psf-energy", "sum of positive response over each point region", "placeholder", "profile-specific",
                    "Calibration placeholder; cannot approve a measured lens profile", "measured-profile-forbidden"),
        ])
    elif fixture_id == "point-source-sweep-grid":
        common.extend([
            _metric("source-precision", "detected source regions divided by all reported regions", "internal tolerance",
                    ">= 0.90", "Synthetic point-source precision target; not a measured optical profile", "model"),
            _metric("source-recall", "detected reference regions divided by all expected regions", "internal tolerance",
                    ">= 0.90", "Synthetic point-source recall target; not a measured optical profile", "model"),
            _metric("source-centroid", "per-source weighted centroid against the fixture mask", "internal tolerance",
                    "<= 1 px", "Spatial source-map target", "model"),
            _metric("source-energy", "per-source integrated energy against the fixture mask", "internal tolerance",
                    "<= 5%", "Spatial source-map target", "model"),
            _metric("source-continuity", "source response across horizontal sweep", "internal tolerance",
                    "no discontinuity", "Threshold continuity target", "model"),
        ])
    elif fixture_id == "signage-led":
        common.extend([
            _metric("source-precision", "detected saturated signage regions divided by all reports", "internal tolerance",
                    ">= 0.90", "Synthetic signage precision target; not a measured optical profile", "model"),
            _metric("source-recall", "detected saturated signage regions divided by expected regions", "internal tolerance",
                    ">= 0.90", "Synthetic signage recall target; not a measured optical profile", "model"),
            _metric("source-channel-energy", "per-channel source energy against the signage mask", "internal tolerance",
                    "<= 5%", "RGB source-map target for clipped LED colors", "model"),
            _metric("source-determinism", "same frame source map across repeated seek order", "internal tolerance",
                    "bit exact", "Spatial detector has no temporal state", "safety"),
        ])
    elif fixture_id == "mist-detail-frequency":
        common.extend([
            _metric("detail-difference-reconstruction", "Final minus source equals Glow + Veil + Detail",
                    "internal tolerance", "<= 2e-4", "Public CPU diagnostic reconstruction", "safety"),
            _metric("skin-high-frequency-softness", "fine-frequency energy decreases at zero retention",
                    "placeholder", "profile-specific", "Synthetic detail target; not a measured filter profile",
                    "measured-profile-forbidden"),
            _metric("edge-mid-frequency-retention", "edge mid-band remains above skin fine-band response",
                    "placeholder", "profile-specific", "Synthetic edge target; not a measured MTF claim",
                    "measured-profile-forbidden"),
        ])
    elif fixture_id == "grain-response-grid":
        common.extend([
            _metric("exposure-rms-envelope", "48-frame flat-field RMS over -4/0/+4 stop rows",
                    "placeholder", "profile-specific", "Synthetic generic profile envelope; no measured stock claim",
                    "model"),
            _metric("record-covariance", "R/G/B covariance and record-specific radial PSD",
                    "placeholder", "profile-specific", "Synthetic record target; no measured stock claim",
                    "model"),
            _metric("population-diameter", "fine/medium/coarse particle diameter and clump response",
                    "placeholder", "profile-specific", "Synthetic population target; no measured stock claim",
                    "model"),
        ])
    elif fixture_id == "alpha-edge":
        common.append(_metric("alpha-preservation", "transparent and semi-transparent edge alpha", "standard", "preserve",
                              "Straight-alpha contract", "safety"))
    else:
        common.append(_metric("constant-field", "flat-field response excluding enabled effect contribution", "standard",
                              "preserve", "Constant-field invariant", "model"))
    return common


def generate(output_dir: Path, manifest_path: Path, width: int = 192, height: int = 128) -> Dict[str, object]:
    output_dir.mkdir(parents=True, exist_ok=True)
    entries: List[Dict[str, object]] = []
    for fixture_id in REQUIRED_FIXTURES:
        pixels, regions = GENERATORS[fixture_id](width, height)
        frame_name = f"{fixture_id}.rgba32f"
        mask_name = f"{fixture_id}.mask.json"
        frame_path = output_dir / frame_name
        mask_path = output_dir / mask_name
        _write_frame(frame_path, width, height, pixels)
        mask = {"schema_version": "1.0", "fixture_id": fixture_id, "crop": [0, 0, width, height],
                "regions": regions}
        if fixture_id == "field-psf":
            mask["field_coordinate_convention"] = "pixel-center normalized over the full declared data window; u/v in [0,1]"
        mask_path.write_text(json.dumps(mask, sort_keys=True, indent=2) + "\n", encoding="utf-8")
        entries.append({
            "id": fixture_id,
            "source": "synthetic",
            "provenance": "internal tolerance",
            "frame_path": frame_name,
            "frame_sha256": _sha256(frame_path),
            "mask_path": mask_name,
            "mask_sha256": _sha256(mask_path),
            "generator": {"name": "generate_fixtures.py", "version": GENERATOR_VERSION},
            "color_encoding": "scene-linear / linear-light RGBA float32",
            "resolution": [width, height],
            "frames": [0],
            "crop": [0, 0, width, height],
            "expected_mask": {"path": mask_name, "labels": [region["id"] for region in regions]},
            "metrics": _metrics_for(fixture_id),
        })
        if fixture_id == "field-psf":
            entries[-1]["field_coordinate_convention"] = (
                "pixel-center normalized over the full declared data window; canonical field coordinates are independent of crop"
            )
    manifest = {
        "schema_version": "1.0",
        "suite_id": "cbef-quality-p0",
        "description": "Reproducible synthetic scene-linear fixtures for the CBEF v2 Model and Safety Gates.",
        "asset_root": "fixtures/quality/generated",
        "generator": {"name": "generate_fixtures.py", "version": GENERATOR_VERSION,
                      "command": "python3 fixtures/quality/generate_fixtures.py"},
        "format": {"name": "CBEF RGBA32F", "extension": ".rgba32f", "magic": "CBEF_RGBA32F\\n",
                   "channels": ["R", "G", "B", "A"], "byte_order": "little-endian",
                   "sample_type": "float32", "alpha": "straight"},
        "color_pipeline": {"domain": "scene-linear", "transfer": "none", "gamut": "working-space supplied by render request",
                           "working_modes": ["DWG / Intermediate", "DWG / Linear", "Rec.709 / Gamma 2.4"],
                           "negative_and_hdr": "preserved; no early clamp"},
        "provenance_classes": PROVENANCE_CLASSES,
        "fixtures": entries,
        "external_assets": {
            "cache_dir": "fixtures/quality/local-assets",
            "redistribution": "forbidden-by-default",
            "records": [],
            "record_schema": {
                "official_url": "required",
                "sha256": "required",
                "acquired_on": "required (YYYY-MM-DD)",
                "download_terms": "required verbatim summary or URL",
                "clip_frame": "required",
                "decode": "required",
                "color_transform": "required",
                "redistribution_rights": "required; must be explicit before shipping",
            },
        },
        "report_contract": {
            "schema_version": "1.0",
            "producer": "top-level RenderRequest/RenderSubmission contract",
            "comparison": "fixtures/quality/render_report.py",
            "required_fields": ["fixture_id", "effect", "backend", "frame", "metrics", "provenance"],
            "note": "The report bridge consumes top-level contract output; it does not expose internal kernels or fake hosts.",
        },
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, sort_keys=True, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=Path("fixtures/quality/generated"))
    parser.add_argument("--manifest-out", type=Path)
    parser.add_argument("--width", type=int, default=192)
    parser.add_argument("--height", type=int, default=128)
    args = parser.parse_args()
    if args.width <= 0 or args.height <= 0:
        parser.error("width and height must be positive")
    manifest_path = args.manifest_out or (args.output_dir / "manifest.json")
    manifest = generate(args.output_dir, manifest_path, args.width, args.height)
    print(f"generated {len(manifest['fixtures'])} fixtures in {args.output_dir}")
    print(f"manifest: {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
