from __future__ import annotations

import argparse
import glob
import json
import sys
from pathlib import Path
from typing import Sequence

from normalizer import (
    AlreadyNormalizedError,
    NormalizeOptions,
    NormalizationError,
    ProhibitedPresetError,
    normalize_files,
    normalize_sequence,
)
from presets import PRESETS


IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"}


def _grid(value: str) -> tuple[int, int]:
    normalized = value.lower().replace("×", "x")
    try:
        width, height = (int(part) for part in normalized.split("x", maxsplit=1))
    except (TypeError, ValueError) as exc:
        raise argparse.ArgumentTypeError("网格格式必须是 WIDTHxHEIGHT，例如 32x32。") from exc
    if width < 2 or height < 2:
        raise argparse.ArgumentTypeError("网格宽高必须都大于等于 2。")
    return width, height


def _expand_inputs(raw_inputs: Sequence[str]) -> list[Path]:
    resolved: list[Path] = []
    for raw in raw_inputs:
        if any(character in raw for character in "*?[]"):
            matches = [Path(path) for path in glob.glob(raw)]
        else:
            path = Path(raw)
            matches = (
                sorted(
                    item
                    for item in path.iterdir()
                    if item.is_file() and item.suffix.lower() in IMAGE_SUFFIXES
                )
                if path.is_dir()
                else [path]
            )
        for match in matches:
            if match.suffix.lower() in IMAGE_SUFFIXES and match not in resolved:
                resolved.append(match)
    if not resolved:
        raise ValueError("没有找到可处理的图片。")
    return resolved


def _add_common_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("inputs", nargs="+", help="图片、目录或通配符。")
    parser.add_argument(
        "-o", "--output-dir", required=True, help="规范化 PNG 的输出目录。"
    )
    parser.add_argument(
        "--preset",
        default="auto",
        choices=["auto", *PRESETS.keys()],
        help="MagArena 资产预设；auto 会根据项目路径判断。",
    )
    parser.add_argument(
        "--sampling",
        default="median",
        choices=["median", "center", "majority"],
        help="单元格颜色采样方式。",
    )
    parser.add_argument("--grid", type=_grid, help="手动网格，例如 32x32。")
    parser.add_argument("--scale", type=int, default=1, help="最近邻导出倍率，1–32。")
    parser.add_argument(
        "--refine", type=float, default=0.25, help="网格边缘校正强度，0–0.5。"
    )
    parser.add_argument(
        "--protection",
        choices=["error", "copy", "allow"],
        default="error",
        help="成品资产处理：报错、原样复制或强制重处理。",
    )
    parser.add_argument(
        "--alpha-mode",
        choices=["hard", "stepped", "preserve"],
        help="覆盖预设的 Alpha 处理方式。",
    )
    parser.add_argument("--alpha-steps", type=int, default=5)
    parser.add_argument("--palette-limit", type=int)
    parser.add_argument("--report", help="质量报告 JSON 路径。")
    parser.add_argument(
        "--json", action="store_true", help="在标准输出打印机器可读摘要。"
    )


def _options(args: argparse.Namespace) -> NormalizeOptions:
    return NormalizeOptions(
        sampling=args.sampling,
        export_scale=args.scale,
        grid_size=args.grid,
        refine_intensity=args.refine,
        preset=args.preset,
        protection=args.protection,
        alpha_mode=args.alpha_mode,
        alpha_steps=args.alpha_steps,
        palette_limit=args.palette_limit,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="PerfectPixelCLI",
        description="MagArena 像素资产规范化、序列锁定和质量检查工具。",
    )
    parser.add_argument("--version", action="version", version="PerfectPixelNormalizer 1.0")
    subparsers = parser.add_subparsers(dest="command", required=True)

    normalize_parser = subparsers.add_parser(
        "normalize", help="独立处理一张或多张图片。"
    )
    _add_common_options(normalize_parser)

    sequence_parser = subparsers.add_parser(
        "sequence", help="使用同一组网格坐标处理动画序列。"
    )
    _add_common_options(sequence_parser)
    sequence_parser.add_argument(
        "--reference-index",
        type=int,
        default=0,
        help="用于检测并锁定网格的参考帧索引。",
    )
    return parser


def run(argv: Sequence[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8")
            except (AttributeError, OSError):
                pass
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        paths = _expand_inputs(args.inputs)
        options = _options(args)
        output_dir = Path(args.output_dir)
        report_path = Path(args.report) if args.report else output_dir / "quality_report.json"
        if args.command == "sequence":
            result = normalize_sequence(
                paths,
                output_dir,
                options,
                reference_index=args.reference_index,
                report_path=report_path,
            )
            report = result.report
        else:
            report = normalize_files(
                paths, output_dir, options, report_path=report_path
            )

        summary = {
            "status": "ok",
            "command": args.command,
            "file_count": report["summary"]["file_count"],
            "warning_count": report["summary"]["warning_count"],
            "report": str(report_path.resolve()),
        }
        if args.json:
            print(json.dumps(summary, ensure_ascii=False))
        else:
            print(
                f"完成：{summary['file_count']} 个文件，"
                f"{summary['warning_count']} 条警告。"
            )
            print(f"质量报告：{summary['report']}")
        return 0
    except AlreadyNormalizedError as exc:
        print(str(exc), file=sys.stderr)
        return 3
    except ProhibitedPresetError as exc:
        print(f"禁止处理：{exc}", file=sys.stderr)
        return 4
    except (NormalizationError, FileNotFoundError, ValueError) as exc:
        print(f"处理失败：{exc}", file=sys.stderr)
        return 5


if __name__ == "__main__":
    sys.exit(run())
