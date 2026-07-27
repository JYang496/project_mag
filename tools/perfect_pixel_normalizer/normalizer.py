from __future__ import annotations

import hashlib
import contextlib
import io
import json
import shutil
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal, Sequence

import cv2
import numpy as np
from PIL import Image
from perfect_pixel import perfect_pixel as upstream

from presets import AssetPreset, AlphaMode, get_preset, infer_preset_from_path


SamplingMethod = Literal["center", "median", "majority"]
ProtectionMode = Literal["error", "copy", "allow"]


class NormalizationError(ValueError):
    pass


class AlreadyNormalizedError(NormalizationError):
    pass


class ProhibitedPresetError(NormalizationError):
    pass


class GridDetectionError(NormalizationError):
    pass


@dataclass(frozen=True)
class NormalizeOptions:
    sampling: SamplingMethod = "median"
    export_scale: int = 1
    grid_size: tuple[int, int] | None = None
    min_pixel_size: float = 4.0
    peak_width: int = 6
    refine_intensity: float = 0.25
    fix_square: bool = False
    preset: str = "custom"
    protection: ProtectionMode = "error"
    alpha_mode: AlphaMode | None = None
    alpha_steps: int = 5
    palette_limit: int | None = None

    def validate(self) -> None:
        if self.sampling not in {"center", "median", "majority"}:
            raise ValueError(f"不支持的采样方式：{self.sampling}")
        if not 1 <= self.export_scale <= 32:
            raise ValueError("导出倍率必须在 1 到 32 之间。")
        if self.grid_size is not None and (
            self.grid_size[0] < 2 or self.grid_size[1] < 2
        ):
            raise ValueError("手动网格宽高必须都大于等于 2。")
        if not 0.0 <= self.refine_intensity <= 0.5:
            raise ValueError("边缘校正强度必须在 0 到 0.5 之间。")
        if self.min_pixel_size <= 0:
            raise ValueError("最小像素块尺寸必须大于 0。")
        if self.protection not in {"error", "copy", "allow"}:
            raise ValueError("成品保护模式必须是 error、copy 或 allow。")
        if not 2 <= self.alpha_steps <= 256:
            raise ValueError("Alpha 阶梯数量必须在 2 到 256 之间。")
        if self.palette_limit is not None and self.palette_limit < 2:
            raise ValueError("调色板上限必须大于等于 2。")
        if self.preset != "auto":
            get_preset(self.preset)


@dataclass(frozen=True)
class GridLock:
    source_width: int
    source_height: int
    x_coords: tuple[int, ...]
    y_coords: tuple[int, ...]
    requested_grid: tuple[int, int]
    refined_grid: tuple[int, int]


@dataclass
class NormalizeResult:
    image: Image.Image
    grid_width: int
    grid_height: int
    source_width: int
    source_height: int
    grid_lock: GridLock
    preset: str
    protected: bool = False
    warnings: list[str] = field(default_factory=list)
    quality: dict[str, object] = field(default_factory=dict)


@dataclass(frozen=True)
class SequenceItem:
    source_path: Path
    destination_path: Path
    result: NormalizeResult


@dataclass(frozen=True)
class SequenceResult:
    items: tuple[SequenceItem, ...]
    grid_lock: GridLock
    report: dict[str, object]


def _hash_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _image_metrics(image: Image.Image) -> dict[str, object]:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8)
    alpha = rgba[..., 3]
    visible = alpha > 0
    ys, xs = np.nonzero(visible)
    bbox = (
        [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
        if len(xs)
        else None
    )
    rgb = rgba[..., :3]
    visible_rgb = rgb[visible] if np.any(visible) else rgb.reshape(-1, 3)
    color_count = int(len(np.unique(visible_rgb, axis=0)))
    alpha_values = np.unique(alpha)
    return {
        "width": image.width,
        "height": image.height,
        "mode": image.mode,
        "visible_color_count": color_count,
        "alpha_level_count": int(len(alpha_values)),
        "alpha_levels": [int(value) for value in alpha_values[:32]],
        "partial_alpha_pixels": int(np.count_nonzero((alpha > 0) & (alpha < 255))),
        "opaque_pixels": int(np.count_nonzero(alpha == 255)),
        "transparent_pixels": int(np.count_nonzero(alpha == 0)),
        "visible_bbox": bbox,
    }


def _resolve_preset(options: NormalizeOptions, source_path: str | Path | None) -> AssetPreset:
    preset_id = options.preset
    if preset_id == "auto":
        preset_id = infer_preset_from_path(source_path or "")
    return get_preset(preset_id)


def _is_probably_finished(
    image: Image.Image,
    preset: AssetPreset,
    options: NormalizeOptions,
) -> tuple[bool, str]:
    metrics = _image_metrics(image)
    if options.grid_size is not None and image.size == options.grid_size:
        return True, "输入尺寸已经符合本次实时解析的目标网格。"
    if preset.id != "custom" and preset.size_matches(image.size):
        return True, f"输入尺寸已经符合“{preset.label}”规格。"
    if (
        preset.id == "custom"
        and options.grid_size is None
        and max(image.size) <= 256
        and int(metrics["alpha_level_count"]) <= 16
    ):
        return True, "输入尺寸较小且 Alpha 已离散，疑似已经是规范化像素资产。"
    return False, ""


def _identity_grid_lock(size: tuple[int, int]) -> GridLock:
    width, height = size
    return GridLock(
        source_width=width,
        source_height=height,
        x_coords=tuple(range(width + 1)),
        y_coords=tuple(range(height + 1)),
        requested_grid=(width, height),
        refined_grid=(width, height),
    )


def _target_grid(
    image: Image.Image,
    preset: AssetPreset,
    options: NormalizeOptions,
    bgr: np.ndarray,
) -> tuple[int, int]:
    if options.grid_size is not None:
        return options.grid_size
    preset_target = preset.target_for_source(image.size)
    if preset_target is not None:
        return preset_target
    # The upstream library reports diagnostics with print(). Keep the library
    # output away from the GUI and the CLI's machine-readable JSON stream.
    with contextlib.redirect_stdout(io.StringIO()):
        grid_width, grid_height = upstream.detect_grid_scale(
            bgr,
            peak_width=options.peak_width,
            max_ratio=1.5,
            min_size=options.min_pixel_size,
        )
    if grid_width is None or grid_height is None:
        raise GridDetectionError(
            "无法自动识别网格。请选择 MagArena 资产预设或手动输入目标网格。"
        )
    return int(grid_width), int(grid_height)


def _build_grid_lock(
    image: Image.Image,
    preset: AssetPreset,
    options: NormalizeOptions,
) -> GridLock:
    rgb = np.asarray(image.convert("RGB"), dtype=np.uint8)
    bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
    requested = _target_grid(image, preset, options, bgr)
    x_coords, y_coords = upstream.refine_grids(
        bgr, requested[0], requested[1], options.refine_intensity
    )
    x = tuple(int(value) for value in x_coords)
    y = tuple(int(value) for value in y_coords)
    if len(x) < 2 or len(y) < 2:
        raise GridDetectionError("网格校正后没有得到足够的有效单元格。")
    return GridLock(
        source_width=image.width,
        source_height=image.height,
        x_coords=x,
        y_coords=y,
        requested_grid=requested,
        refined_grid=(len(x) - 1, len(y) - 1),
    )


def _sample(array: np.ndarray, lock: GridLock, method: SamplingMethod) -> np.ndarray:
    if method == "center":
        sampled = upstream.sample_center(array, lock.x_coords, lock.y_coords)
    elif method == "majority":
        sampled = upstream.sample_majority(array, lock.x_coords, lock.y_coords)
    else:
        sampled = upstream.sample_median(array, lock.x_coords, lock.y_coords)
    return np.asarray(sampled, dtype=np.uint8)


def _sample_alpha(alpha: np.ndarray, lock: GridLock, method: SamplingMethod) -> np.ndarray:
    # Alpha must use the exact same grid coordinates as RGB. Median is preferred
    # for majority mode because clustering a scalar transparency channel is unstable.
    alpha_3d = alpha[..., None]
    alpha_method: SamplingMethod = "median" if method == "majority" else method
    sampled = _sample(alpha_3d, lock, alpha_method)
    if sampled.ndim == 3:
        sampled = sampled[..., 0]
    return sampled


def _apply_alpha_mode(alpha: np.ndarray, mode: AlphaMode, steps: int) -> np.ndarray:
    if mode == "hard":
        return np.where(alpha >= 128, 255, 0).astype(np.uint8)
    if mode == "stepped":
        step = 255.0 / (steps - 1)
        return np.clip(np.rint(alpha / step) * step, 0, 255).astype(np.uint8)
    return alpha.astype(np.uint8)


def _quantize_visible_rgb(image: Image.Image, limit: int | None) -> Image.Image:
    if limit is None:
        return image
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = rgba.convert("RGB")
    quantized = rgb.quantize(
        colors=limit,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    quantized.putalpha(alpha)
    return quantized


def _force_target_size(
    image: Image.Image,
    preset: AssetPreset,
    source_size: tuple[int, int],
    explicit_grid: tuple[int, int] | None,
) -> Image.Image:
    target = explicit_grid or preset.target_for_source(source_size)
    if target is None or image.size == target:
        return image
    return image.resize(target, Image.Resampling.NEAREST)


def _quality_warnings(
    before: dict[str, object],
    after: dict[str, object],
    preset: AssetPreset,
    explicit_grid: tuple[int, int] | None,
) -> list[str]:
    warnings: list[str] = []
    target = explicit_grid or preset.target_for_source(
        (int(before["width"]), int(before["height"]))
    )
    if target is not None and (
        int(after["width"]), int(after["height"])
    ) != target:
        warnings.append(f"输出尺寸不符合预设目标 {target[0]}×{target[1]}。")
    if preset.alpha_mode == "hard" and int(after["partial_alpha_pixels"]) > 0:
        warnings.append("硬边资产仍包含半透明像素。")
    if (
        preset.palette_limit is not None
        and int(after["visible_color_count"]) > preset.palette_limit
    ):
        warnings.append(
            f"可见颜色数 {after['visible_color_count']} 超过建议上限 "
            f"{preset.palette_limit}。"
        )
    return warnings


def normalize_pil(
    image: Image.Image,
    options: NormalizeOptions,
    *,
    grid_lock: GridLock | None = None,
    source_path: str | Path | None = None,
) -> NormalizeResult:
    options.validate()
    source = image.copy()
    source_width, source_height = source.size
    preset = _resolve_preset(options, source_path)
    if preset.prohibited:
        raise ProhibitedPresetError(
            f"“{preset.label}”使用抗锯齿和线性过滤，禁止进入像素规范化流程。"
        )

    protected, reason = _is_probably_finished(source, preset, options)
    if protected and options.protection == "error":
        raise AlreadyNormalizedError(f"成品资产保护：{reason}")

    before = _image_metrics(source)
    if protected and options.protection == "copy":
        lock = _identity_grid_lock(source.size)
        copied = source.convert("RGBA")
        logical_output = _image_metrics(copied)
        if options.export_scale > 1:
            copied = copied.resize(
                (
                    copied.width * options.export_scale,
                    copied.height * options.export_scale,
                ),
                Image.Resampling.NEAREST,
            )
        return NormalizeResult(
            image=copied,
            grid_width=source_width,
            grid_height=source_height,
            source_width=source_width,
            source_height=source_height,
            grid_lock=lock,
            preset=preset.id,
            protected=True,
            warnings=[reason],
            quality={
                "before": before,
                "logical_output": logical_output,
                "exported_output": _image_metrics(copied),
            },
        )

    lock = grid_lock or _build_grid_lock(source, preset, options)
    if (lock.source_width, lock.source_height) != source.size:
        raise NormalizationError(
            "锁定网格的源尺寸与当前图片不一致；动画序列的所有帧必须尺寸相同。"
        )

    rgba = np.asarray(source.convert("RGBA"), dtype=np.uint8)
    rgb_sampled = _sample(rgba[..., :3], lock, options.sampling)
    alpha_sampled = _sample_alpha(rgba[..., 3], lock, options.sampling)
    alpha_mode = options.alpha_mode or preset.alpha_mode
    alpha_sampled = _apply_alpha_mode(alpha_sampled, alpha_mode, options.alpha_steps)
    rgb_sampled[alpha_sampled == 0] = 0

    result_array = np.dstack((rgb_sampled, alpha_sampled))
    result = Image.fromarray(result_array)
    result = _force_target_size(result, preset, source.size, options.grid_size)
    palette_limit = (
        options.palette_limit
        if options.palette_limit is not None
        else preset.palette_limit
    )
    result = _quantize_visible_rgb(result, palette_limit)

    if (
        options.fix_square
        and preset.id == "custom"
        and abs(result.width - result.height) == 1
    ):
        side = min(result.width, result.height)
        result = result.crop((0, 0, side, side))

    grid_width, grid_height = result.size
    logical_after = _image_metrics(result)
    warnings = _quality_warnings(
        before, logical_after, preset, options.grid_size
    )
    if options.export_scale > 1:
        result = result.resize(
            (
                result.width * options.export_scale,
                result.height * options.export_scale,
            ),
            Image.Resampling.NEAREST,
        )
    after = _image_metrics(result)
    if protected and options.protection == "allow":
        warnings.insert(0, f"已绕过成品资产保护：{reason}")
    return NormalizeResult(
        image=result,
        grid_width=grid_width,
        grid_height=grid_height,
        source_width=source_width,
        source_height=source_height,
        grid_lock=lock,
        preset=preset.id,
        protected=protected,
        warnings=warnings,
        quality={
            "before": before,
            "logical_output": logical_after,
            "exported_output": after,
        },
    )


def normalize_file(
    source_path: str | Path,
    destination_path: str | Path,
    options: NormalizeOptions,
    *,
    grid_lock: GridLock | None = None,
) -> NormalizeResult:
    source_path = Path(source_path)
    destination_path = Path(destination_path)
    if not source_path.is_file():
        raise FileNotFoundError(f"找不到输入图片：{source_path}")
    with Image.open(source_path) as source:
        source.load()
        result = normalize_pil(
            source, options, grid_lock=grid_lock, source_path=source_path
        )
    destination_path.parent.mkdir(parents=True, exist_ok=True)
    if (
        result.protected
        and options.protection == "copy"
        and options.export_scale == 1
        and source_path.suffix.lower() == ".png"
    ):
        shutil.copy2(source_path, destination_path)
    else:
        result.image.save(destination_path, format="PNG", optimize=True)
    return result


def _file_record(
    source: Path,
    destination: Path,
    result: NormalizeResult,
) -> dict[str, object]:
    return {
        "source": str(source.resolve()),
        "destination": str(destination.resolve()),
        "source_sha256": _hash_bytes(source.read_bytes()),
        "output_sha256": _hash_bytes(destination.read_bytes()),
        "preset": result.preset,
        "protected": result.protected,
        "grid": {
            "requested": list(result.grid_lock.requested_grid),
            "refined": list(result.grid_lock.refined_grid),
            "output": [result.grid_width, result.grid_height],
            "x_coords": list(result.grid_lock.x_coords),
            "y_coords": list(result.grid_lock.y_coords),
            "channels_share_grid": True,
        },
        "quality": result.quality,
        "warnings": result.warnings,
    }


def build_report(
    records: Sequence[dict[str, object]],
    options: NormalizeOptions,
    *,
    sequence_locked: bool,
    reference_index: int | None = None,
) -> dict[str, object]:
    return {
        "schema_version": 1,
        "tool": "PerfectPixelNormalizer",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "sequence_locked": sequence_locked,
        "reference_index": reference_index,
        "options": asdict(options),
        "summary": {
            "file_count": len(records),
            "warning_count": sum(len(record.get("warnings", [])) for record in records),
            "protected_count": sum(bool(record.get("protected")) for record in records),
        },
        "files": list(records),
    }


def write_report(report: dict[str, object], path: str | Path) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def normalize_sequence(
    source_paths: Sequence[str | Path],
    output_dir: str | Path,
    options: NormalizeOptions,
    *,
    reference_index: int = 0,
    report_path: str | Path | None = None,
) -> SequenceResult:
    paths = tuple(Path(path) for path in source_paths)
    if not paths:
        raise ValueError("动画序列至少需要一张图片。")
    if not 0 <= reference_index < len(paths):
        raise ValueError("动画参考帧索引超出范围。")
    for path in paths:
        if not path.is_file():
            raise FileNotFoundError(f"找不到动画帧：{path}")

    sizes: list[tuple[int, int]] = []
    for path in paths:
        with Image.open(path) as image:
            sizes.append(image.size)
    if len(set(sizes)) != 1:
        raise NormalizationError(
            "动画序列锁定要求所有输入帧尺寸一致："
            + ", ".join(f"{path.name}={size[0]}×{size[1]}" for path, size in zip(paths, sizes))
        )

    with Image.open(paths[reference_index]) as reference:
        reference.load()
        preset = _resolve_preset(options, paths[reference_index])
        if preset.prohibited:
            raise ProhibitedPresetError("现代 UI 不能作为像素动画序列处理。")
        protected, reason = _is_probably_finished(reference, preset, options)
        if protected and options.protection == "error":
            raise AlreadyNormalizedError(f"成品资产保护：{reason}")
        lock = (
            _identity_grid_lock(reference.size)
            if protected and options.protection == "copy"
            else _build_grid_lock(reference, preset, options)
        )

    output_dir = Path(output_dir)
    items: list[SequenceItem] = []
    records: list[dict[str, object]] = []
    for path in paths:
        destination = output_dir / f"{path.stem}_normalized.png"
        result = normalize_file(path, destination, options, grid_lock=lock)
        items.append(SequenceItem(path, destination, result))
        records.append(_file_record(path, destination, result))

    report = build_report(
        records,
        options,
        sequence_locked=True,
        reference_index=reference_index,
    )
    if report_path is not None:
        write_report(report, report_path)
    return SequenceResult(tuple(items), lock, report)


def normalize_files(
    source_paths: Sequence[str | Path],
    output_dir: str | Path,
    options: NormalizeOptions,
    *,
    report_path: str | Path | None = None,
) -> dict[str, object]:
    output_dir = Path(output_dir)
    records: list[dict[str, object]] = []
    for raw_path in source_paths:
        source = Path(raw_path)
        destination = output_dir / f"{source.stem}_normalized.png"
        result = normalize_file(source, destination, options)
        records.append(_file_record(source, destination, result))
    report = build_report(records, options, sequence_locked=False)
    if report_path is not None:
        write_report(report, report_path)
    return report
