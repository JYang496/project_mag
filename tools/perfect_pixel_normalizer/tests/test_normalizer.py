import contextlib
import hashlib
import io
import json
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

from cli import run as run_cli
from normalizer import (
    AlreadyNormalizedError,
    GridLock,
    NormalizeOptions,
    ProhibitedPresetError,
    normalize_file,
    normalize_pil,
    normalize_sequence,
)
from presets import infer_preset_from_path


def synthetic_pixel_art(
    grid_width: int,
    grid_height: int,
    cell: int = 10,
    *,
    alpha: bool = False,
) -> Image.Image:
    y, x = np.indices((grid_height, grid_width))
    palette = np.array(
        [[24, 28, 36], [230, 86, 64], [78, 174, 96], [72, 120, 220]],
        dtype=np.uint8,
    )
    indices = (x // 3 + y // 2) % len(palette)
    tiny = palette[indices]
    enlarged = np.repeat(np.repeat(tiny, cell, axis=0), cell, axis=1)
    image = Image.fromarray(enlarged)
    if alpha:
        image = image.convert("RGBA")
        mask = np.where(
            np.repeat(np.repeat((x + y) % 2, cell, axis=0), cell, axis=1),
            255,
            0,
        ).astype(np.uint8)
        image.putalpha(Image.fromarray(mask))
    return image


class PresetAndProtectionTests(unittest.TestCase):
    def test_mag_arena_path_inference(self) -> None:
        self.assertEqual(
            infer_preset_from_path("asset/images/weapons/blaster.png"), "weapon"
        )
        self.assertEqual(
            infer_preset_from_path("asset/images/effects/explosion/explosion_01.png"),
            "effect_medium",
        )
        self.assertEqual(
            infer_preset_from_path("UI/themes/modern/heat_gauge.png"), "modern_ui"
        )

    def test_finished_asset_is_protected(self) -> None:
        image = synthetic_pixel_art(32, 32, cell=1)
        with self.assertRaises(AlreadyNormalizedError):
            normalize_pil(image, NormalizeOptions(preset="enemy_standard"))

    def test_finished_asset_can_be_copied_without_resampling(self) -> None:
        image = synthetic_pixel_art(32, 32, cell=1)
        result = normalize_pil(
            image,
            NormalizeOptions(preset="enemy_standard", protection="copy"),
        )
        self.assertTrue(result.protected)
        self.assertEqual(result.image.size, (32, 32))
        np.testing.assert_array_equal(
            np.asarray(result.image.convert("RGB")), np.asarray(image.convert("RGB"))
        )

    def test_finished_png_copy_is_byte_identical(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            source = root / "enemy.png"
            destination = root / "out" / "enemy_normalized.png"
            synthetic_pixel_art(32, 32, cell=1).save(source, optimize=False)
            normalize_file(
                source,
                destination,
                NormalizeOptions(preset="enemy_standard", protection="copy"),
            )
            self.assertEqual(
                hashlib.sha256(source.read_bytes()).hexdigest(),
                hashlib.sha256(destination.read_bytes()).hexdigest(),
            )

    def test_modern_ui_is_rejected(self) -> None:
        with self.assertRaises(ProhibitedPresetError):
            normalize_pil(
                synthetic_pixel_art(16, 16),
                NormalizeOptions(preset="modern_ui"),
            )

    def test_enemy_preset_enforces_canvas_palette_and_hard_alpha(self) -> None:
        image = synthetic_pixel_art(32, 32, cell=10, alpha=True)
        result = normalize_pil(
            image,
            NormalizeOptions(preset="enemy_standard", protection="allow"),
        )
        self.assertEqual((result.grid_width, result.grid_height), (32, 32))
        self.assertEqual(set(result.image.getchannel("A").getdata()), {0, 255})
        self.assertLessEqual(
            result.quality["logical_output"]["visible_color_count"], 64
        )

    def test_weapon_preset_fixes_height_and_preserves_aspect(self) -> None:
        image = synthetic_pixel_art(22, 40, cell=10)
        result = normalize_pil(image, NormalizeOptions(preset="weapon"))
        self.assertEqual((result.grid_width, result.grid_height), (22, 40))

    def test_live_explicit_grid_overrides_static_preset_size(self) -> None:
        image = synthetic_pixel_art(10, 10, cell=10)
        result = normalize_pil(
            image,
            NormalizeOptions(
                preset="enemy_standard",
                grid_size=(36, 36),
                protection="allow",
            ),
        )
        self.assertEqual((result.grid_width, result.grid_height), (36, 36))
        self.assertFalse(
            any("32×32" in warning for warning in result.warnings),
            result.warnings,
        )

    def test_live_explicit_grid_protects_future_finished_size(self) -> None:
        image = synthetic_pixel_art(36, 36, cell=1)
        with self.assertRaisesRegex(AlreadyNormalizedError, "实时解析"):
            normalize_pil(
                image,
                NormalizeOptions(
                    preset="enemy_standard",
                    grid_size=(36, 36),
                ),
            )


class SharedGridAndSequenceTests(unittest.TestCase):
    def test_rgb_and_alpha_use_the_same_nonuniform_grid(self) -> None:
        rgba = np.zeros((4, 8, 4), dtype=np.uint8)
        rgba[..., :3] = (210, 80, 50)
        rgba[..., 3] = 255
        rgba[:, 0, 3] = 0
        image = Image.fromarray(rgba)
        lock = GridLock(
            source_width=8,
            source_height=4,
            x_coords=(0, 2, 8),
            y_coords=(0, 4),
            requested_grid=(2, 1),
            refined_grid=(2, 1),
        )
        result = normalize_pil(
            image,
            NormalizeOptions(
                sampling="center",
                alpha_mode="hard",
                protection="allow",
            ),
            grid_lock=lock,
        )
        self.assertEqual(result.image.size, (2, 1))
        self.assertEqual(list(result.image.getchannel("A").getdata()), [255, 255])
        self.assertEqual(result.grid_lock.x_coords, (0, 2, 8))

    def test_sequence_reuses_reference_grid_and_writes_report(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            paths = []
            for index in range(3):
                path = root / f"explosion_{index:02d}.png"
                image = synthetic_pixel_art(8, 8, cell=10, alpha=True)
                array = np.asarray(image).copy()
                array[:, index : index + 5, :3] = (255, 240, 80)
                Image.fromarray(array).save(path)
                paths.append(path)

            output = root / "out"
            report_path = output / "quality_report.json"
            sequence = normalize_sequence(
                paths,
                output,
                NormalizeOptions(preset="effect_medium"),
                reference_index=1,
                report_path=report_path,
            )
            self.assertEqual(len(sequence.items), 3)
            self.assertTrue(sequence.report["sequence_locked"])
            self.assertEqual(sequence.report["reference_index"], 1)
            self.assertTrue(report_path.is_file())
            locks = [item.result.grid_lock for item in sequence.items]
            self.assertTrue(all(lock == sequence.grid_lock for lock in locks))
            self.assertEqual(
                {item.result.image.size for item in sequence.items}, {(64, 64)}
            )

    def test_sequence_rejects_mixed_source_sizes(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            first = root / "a.png"
            second = root / "b.png"
            synthetic_pixel_art(8, 8).save(first)
            synthetic_pixel_art(9, 8).save(second)
            with self.assertRaisesRegex(ValueError, "尺寸一致"):
                normalize_sequence(
                    [first, second],
                    root / "out",
                    NormalizeOptions(preset="effect_medium"),
                )


class ReportAndCliTests(unittest.TestCase):
    def test_file_output_and_report_have_hashes_and_metrics(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            source = root / "source.jpg"
            output = root / "out" / "normalized.png"
            synthetic_pixel_art(10, 10).save(source)
            result = normalize_file(
                source,
                output,
                NormalizeOptions(grid_size=(10, 10), protection="allow"),
            )
            self.assertTrue(output.is_file())
            self.assertIn("before", result.quality)
            self.assertIn("logical_output", result.quality)
            with Image.open(output) as image:
                self.assertEqual(image.format, "PNG")

    def test_cli_normalize_writes_machine_readable_report(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            source = root / "generated.png"
            output = root / "out"
            report = output / "report.json"
            synthetic_pixel_art(8, 8, cell=10, alpha=True).save(source)
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                exit_code = run_cli(
                    [
                        "normalize",
                        str(source),
                        "-o",
                        str(output),
                        "--preset",
                        "enemy_standard",
                        "--report",
                        str(report),
                        "--json",
                    ]
                )
            self.assertEqual(exit_code, 0)
            self.assertEqual(len(stdout.getvalue().strip().splitlines()), 1)
            self.assertEqual(json.loads(stdout.getvalue())["status"], "ok")
            payload = json.loads(report.read_text(encoding="utf-8"))
            self.assertEqual(payload["schema_version"], 1)
            self.assertFalse(payload["sequence_locked"])
            self.assertEqual(payload["summary"]["file_count"], 1)
            record = payload["files"][0]
            self.assertEqual(len(record["source_sha256"]), 64)
            self.assertEqual(len(record["output_sha256"]), 64)
            self.assertIn("quality", record)
            self.assertTrue(record["grid"]["channels_share_grid"])
            self.assertGreater(len(record["grid"]["x_coords"]), 1)

    def test_cli_sequence_locks_frames(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            inputs = root / "frames"
            inputs.mkdir()
            for index in range(2):
                image = synthetic_pixel_art(8, 8, cell=10, alpha=True)
                image.save(inputs / f"frame_{index:02d}.png")
            output = root / "out"
            exit_code = run_cli(
                [
                    "sequence",
                    str(inputs),
                    "-o",
                    str(output),
                    "--preset",
                    "effect_medium",
                    "--reference-index",
                    "1",
                    "--json",
                ]
            )
            self.assertEqual(exit_code, 0)
            payload = json.loads(
                (output / "quality_report.json").read_text(encoding="utf-8")
            )
            self.assertTrue(payload["sequence_locked"])
            self.assertEqual(payload["reference_index"], 1)
            self.assertEqual(
                payload["files"][0]["grid"]["x_coords"],
                payload["files"][1]["grid"]["x_coords"],
            )

    def test_cli_returns_distinct_protection_exit_code(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            source = root / "enemy.png"
            synthetic_pixel_art(32, 32, cell=1).save(source)
            exit_code = run_cli(
                [
                    "normalize",
                    str(source),
                    "-o",
                    str(root / "out"),
                    "--preset",
                    "enemy_standard",
                ]
            )
            self.assertEqual(exit_code, 3)

    def test_invalid_scale_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            NormalizeOptions(export_scale=0).validate()


if __name__ == "__main__":
    unittest.main()
