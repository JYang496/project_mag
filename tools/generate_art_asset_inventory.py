#!/usr/bin/env python3
"""Generate the Stage 1 MagArena art-asset inventory as a self-contained HTML report."""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import hashlib
import html
import json
import os
from pathlib import Path
import re
import subprocess
from typing import Iterable

from PIL import Image


IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga", ".svg"}
VISUAL_EXTENSIONS = IMAGE_EXTENSIONS | {".gdshader", ".shader", ".ttf", ".otf", ".woff", ".woff2"}
TEXT_EXTENSIONS = {".gd", ".tscn", ".tres", ".godot", ".cfg", ".json", ".gdshader", ".shader"}
SKIP_PARTS = {".git", ".godot", "test-results", "docs"}
RUNTIME_TEXT_ROOTS = ("autoload", "World", "Player", "Combat", "Board", "Objects", "UI", "data", "Visual", "Npc", "Shaders")


def sha256_short(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()[:16]


def svg_dimensions(path: Path) -> tuple[str, str]:
    text = path.read_text(encoding="utf-8", errors="ignore")[:8192]
    tag = re.search(r"<svg\b[^>]*>", text, re.IGNORECASE | re.DOTALL)
    if not tag:
        return "—", "无法解析 SVG 根节点"
    width = re.search(r'\bwidth=["\']\s*([0-9.]+)', tag.group(0), re.IGNORECASE)
    height = re.search(r'\bheight=["\']\s*([0-9.]+)', tag.group(0), re.IGNORECASE)
    if width and height:
        return f"{width.group(1)}×{height.group(1)}", ""
    view_box = re.search(r'\bviewBox=["\']\s*([-0-9.]+)[ ,]+([-0-9.]+)[ ,]+([0-9.]+)[ ,]+([0-9.]+)', tag.group(0), re.IGNORECASE)
    if view_box:
        return f"{view_box.group(3)}×{view_box.group(4)}", "尺寸来自 viewBox"
    return "—", "SVG 未声明尺寸"


def image_metadata(path: Path) -> tuple[str, str, str]:
    if path.suffix.lower() == ".svg":
        dimensions, note = svg_dimensions(path)
        return dimensions, "SVG", note
    try:
        with Image.open(path) as image:
            return f"{image.width}×{image.height}", image.mode, ""
    except Exception as exc:  # inventory must retain broken assets as findings
        return "—", "不可读", f"图像读取失败：{type(exc).__name__}"


def git_tracked_files(root: Path) -> set[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z"], cwd=root, capture_output=True, check=False
    )
    if result.returncode != 0:
        return set()
    return {p.decode("utf-8", errors="replace").replace("\\", "/") for p in result.stdout.split(b"\0") if p}


def runtime_text_files(root: Path) -> list[tuple[str, str]]:
    files: list[tuple[str, str]] = []
    candidates = [root / "project.godot"]
    for dirname in RUNTIME_TEXT_ROOTS:
        base = root / dirname
        if base.exists():
            candidates.extend(p for p in base.rglob("*") if p.is_file() and p.suffix.lower() in TEXT_EXTENSIONS)
    for path in candidates:
        try:
            files.append((path.relative_to(root).as_posix(), path.read_text(encoding="utf-8", errors="ignore")))
        except OSError:
            continue
    return files


def role_for(path: str, suffix: str) -> str:
    low = path.lower()
    name = Path(low).stem
    if suffix in {".ttf", ".otf", ".woff", ".woff2"}:
        return "字体"
    if suffix in {".gdshader", ".shader"}:
        return "Shader"
    rules = (
        (("ui/", "/ui/", "hud", "menu", "button", "panel", "card", "cursor"), "UI"),
        (("enemy", "enemies", "boss", "monster"), "敌人"),
        (("player", "mecha", "character", "drone"), "玩家/机甲"),
        (("weapon", "gun", "cannon", "rifle", "laser", "blade"), "武器"),
        (("projectile", "bullet", "missile", "beam", "shell"), "弹体"),
        (("effect", "explosion", "spark", "smoke", "flame", "glacier", "trail", "vfx"), "特效"),
        (("terrain", "ground", "tile", "cell", "board"), "地形/地块"),
        (("prop", "object", "building", "rest_area", "decoration"), "场景道具"),
        (("module", "passive", "branch", "skill", "perk"), "模块/技能"),
        (("loot", "reward", "collect", "pickup", "coin", "chest"), "掉落/奖励"),
        (("icon",), "图标"),
    )
    for needles, role in rules:
        if any(needle in low or needle in name for needle in needles):
            return role
    return "未分类"


def status_for(path: str, suffix: str, refs: list[str], tracked: bool) -> str:
    parts = set(path.lower().split("/"))
    if "archive" in parts or any(part.startswith("deprecated_") for part in parts):
        return "历史归档"
    if "tests" in parts:
        return "测试素材"
    if suffix == ".svg" and not refs and path != "icon.svg":
        return "编辑源文件"
    if refs:
        return "正式运行时素材"
    if not tracked:
        return "在制候选"
    if suffix in {".gdshader", ".shader", ".ttf", ".otf", ".woff", ".woff2"}:
        return "正式视觉资源"
    return "疑似孤儿/待确认"


def expected_filter(role: str, path: str) -> str:
    low = path.lower()
    if role == "UI" or "ui/themes/modern/" in low:
        return "Linear / Linear Mipmap"
    if role == "字体":
        return "灰度抗锯齿；中文字体禁用 MSDF"
    if Path(path).suffix.lower() in {".gdshader", ".shader", ".svg"}:
        return "按消费者验证"
    return "Nearest / Nearest Mipmap"


def collect_assets(root: Path) -> tuple[list[dict], dict]:
    tracked = git_tracked_files(root)
    runtime_sources = runtime_text_files(root)
    assets: list[dict] = []
    excluded_tmp = collections.Counter()
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in VISUAL_EXTENSIONS:
            continue
        rel = path.relative_to(root).as_posix()
        parts = set(path.relative_to(root).parts)
        if parts & SKIP_PARTS:
            continue
        if rel.startswith("tmp/"):
            excluded_tmp[path.suffix.lower()] += 1
            continue
        suffix = path.suffix.lower()
        resource_path = f"res://{rel}"
        refs = sorted(source for source, text in runtime_sources if resource_path in text)
        dimensions, color_mode, note = image_metadata(path) if suffix in IMAGE_EXTENSIONS else ("—", "—", "")
        role = role_for(rel, suffix)
        tracked_flag = rel in tracked
        status = status_for(rel, suffix, refs, tracked_flag)
        findings = []
        if note:
            findings.append(note)
        if status == "疑似孤儿/待确认":
            findings.append("未发现直接 res:// 运行时引用；需检查 UID、动态路径或生成流程")
        if status == "在制候选":
            findings.append("Git 未跟踪；需确认是否准备纳入项目")
        if suffix == ".svg" and refs and role == "模块/技能":
            findings.append("模块运行时不应直接引用 SVG")
        assets.append({
            "id": f"ART-{len(assets)+1:04d}",
            "path": rel,
            "type": suffix.lstrip(".").upper(),
            "role": role,
            "dimensions": dimensions,
            "mode": color_mode,
            "bytes": path.stat().st_size,
            "hash": sha256_short(path),
            "tracked": "是" if tracked_flag else "否",
            "references": refs,
            "consumer": refs[0] if refs else "—",
            "runtime_size": "待场景级审计",
            "filter": expected_filter(role, rel),
            "status": status,
            "finding": "；".join(findings) if findings else "—",
            "preview": suffix in IMAGE_EXTENSIONS,
        })
    assets.sort(key=lambda item: (item["status"], item["role"], item["path"].lower()))
    return assets, dict(sorted(excluded_tmp.items()))


def human_size(size: int) -> str:
    if size < 1024:
        return f"{size} B"
    if size < 1024 * 1024:
        return f"{size / 1024:.1f} KB"
    return f"{size / 1024 / 1024:.1f} MB"


def render_report(root: Path, assets: list[dict], excluded_tmp: dict, output: Path) -> None:
    status_counts = collections.Counter(a["status"] for a in assets)
    role_counts = collections.Counter(a["role"] for a in assets)
    type_counts = collections.Counter(a["type"] for a in assets)
    runtime_count = sum(1 for a in assets if a["references"])
    untracked_count = sum(1 for a in assets if a["tracked"] == "否")
    broken_count = sum(1 for a in assets if "读取失败" in a["finding"])
    generated = dt.datetime.now().astimezone().isoformat(timespec="seconds")

    def pills(counter: collections.Counter) -> str:
        return "".join(f'<span class="pill">{html.escape(str(k))}<b>{v}</b></span>' for k, v in counter.most_common())

    rows = []
    for asset in assets:
        preview = "—"
        if asset["preview"]:
            preview = f'<a href="../{html.escape(asset["path"], quote=True)}"><img loading="lazy" src="../{html.escape(asset["path"], quote=True)}" alt=""></a>'
        refs = "<br>".join(html.escape(r) for r in asset["references"][:4]) or "—"
        if len(asset["references"]) > 4:
            refs += f"<br>另有 {len(asset['references'])-4} 处"
        values = [
            asset["id"], preview, asset["path"], asset["type"], asset["role"], asset["dimensions"],
            asset["mode"], human_size(asset["bytes"]), asset["hash"], asset["tracked"], asset["status"],
            refs, asset["runtime_size"], asset["filter"], asset["finding"],
        ]
        cells = "".join(f"<td>{v if i == 1 or i == 11 else html.escape(str(v))}</td>" for i, v in enumerate(values))
        search = " ".join(str(v) for v in values if not isinstance(v, bool)).lower()
        rows.append(f'<tr data-role="{html.escape(asset["role"], quote=True)}" data-status="{html.escape(asset["status"], quote=True)}" data-search="{html.escape(search, quote=True)}">{cells}</tr>')

    snapshot = html.escape(json.dumps({
        "generated": generated,
        "asset_count": len(assets),
        "runtime_reference_count": runtime_count,
        "status_counts": status_counts,
        "role_counts": role_counts,
        "type_counts": type_counts,
        "excluded_tmp": excluded_tmp,
    }, ensure_ascii=False, indent=2, default=dict))
    page = f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>MagArena 阶段 1：全量美术素材台账</title>
<style>
:root{{--bg:#071018;--panel:#0e1b27;--line:#244054;--text:#d9edf6;--muted:#82a7b8;--cyan:#36d9ff;--orange:#ff9d42;--bad:#ff6b78}}*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--text);font:14px/1.45 system-ui,"Microsoft YaHei",sans-serif}}header{{padding:32px 4vw 18px;background:linear-gradient(135deg,#102737,#071018 58%,#20170e)}}h1{{margin:0 0 8px;font-size:28px}}h2{{font-size:18px;color:var(--cyan)}}p{{color:var(--muted);max-width:1100px}}main{{padding:18px 4vw 48px}}.cards{{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px}}.card,.panel{{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:14px}}.card b{{display:block;font-size:25px;color:var(--orange)}}.pills{{display:flex;flex-wrap:wrap;gap:8px}}.pill{{border:1px solid var(--line);padding:6px 9px;border-radius:20px;color:var(--muted)}}.pill b{{color:var(--cyan);margin-left:7px}}.toolbar{{position:sticky;top:0;z-index:3;display:flex;gap:8px;flex-wrap:wrap;background:#071018ee;padding:10px 0}}input,select{{background:#0e1b27;color:var(--text);border:1px solid var(--line);padding:9px;border-radius:5px}}input{{min-width:280px;flex:1}}.table-wrap{{overflow:auto;border:1px solid var(--line);border-radius:8px;max-height:72vh}}table{{border-collapse:collapse;min-width:2200px;background:#09141e}}th,td{{border-bottom:1px solid #183143;padding:7px 9px;text-align:left;vertical-align:top}}th{{position:sticky;top:0;background:#122433;color:var(--cyan);z-index:2}}tr:hover{{background:#102330}}td:nth-child(2){{width:72px}}img{{width:64px;height:64px;object-fit:contain;image-rendering:pixelated;background:#13212b}}code,pre{{white-space:pre-wrap;color:#9ec8d8}}.note{{border-left:3px solid var(--orange);padding-left:12px}}.hidden{{display:none}}footer{{color:var(--muted);padding-top:20px}}
</style></head><body>
<header><h1>MagArena 阶段 1：全量美术素材台账</h1><p>生成时间：{html.escape(generated)}。本报告用于建立素材身份、角色、尺寸、静态引用与状态基线；不代表逐张视觉质量验收已经完成。</p></header>
<main>
<section class="cards"><div class="card">纳入台账<b>{len(assets)}</b></div><div class="card">存在静态运行时引用<b>{runtime_count}</b></div><div class="card">Git 未跟踪<b>{untracked_count}</b></div><div class="card">不可读取<b>{broken_count}</b></div><div class="card">tmp/ 另行汇总<b>{sum(excluded_tmp.values())}</b></div></section>
<section><h2>口径与结论边界</h2><div class="panel note">扫描项目内 PNG/JPG/JPEG/WebP/BMP/TGA/SVG、Shader 与字体，排除 <code>.godot/</code>、<code>docs/</code>、<code>test-results/</code>；<code>tmp/</code> 仅计数。引用采用 <code>res://完整路径</code> 静态反查，因此通过 UID、动态拼接、生成脚本或运行时目录枚举加载的素材会标为“待确认”，不能据此删除。运行显示尺寸与节点级过滤需要阶段 4 场景审计。</div></section>
<section><h2>状态分布</h2><div class="pills">{pills(status_counts)}</div><h2>角色分布</h2><div class="pills">{pills(role_counts)}</div><h2>格式分布</h2><div class="pills">{pills(type_counts)}</div></section>
<section><h2>素材明细</h2><div class="toolbar"><input id="search" placeholder="搜索路径、角色、状态、消费者或发现项"><select id="role"><option value="">全部角色</option>{''.join(f'<option>{html.escape(k)}</option>' for k in sorted(role_counts))}</select><select id="status"><option value="">全部状态</option>{''.join(f'<option>{html.escape(k)}</option>' for k in sorted(status_counts))}</select><span id="shown"></span></div>
<div class="table-wrap"><table><thead><tr><th>ID</th><th>预览</th><th>路径</th><th>格式</th><th>角色</th><th>源尺寸</th><th>色彩模式</th><th>大小</th><th>SHA-256</th><th>Git</th><th>状态</th><th>静态消费者</th><th>运行尺寸</th><th>期望过滤</th><th>发现项</th></tr></thead><tbody>{''.join(rows)}</tbody></table></div></section>
<section><h2>临时目录汇总</h2><div class="panel"><code>{html.escape(json.dumps(excluded_tmp, ensure_ascii=False, indent=2))}</code><p>这些文件未进入正式台账，需在后续项目卫生审计中区分外部工具、工作缓存和候选素材。</p></div></section>
<details><summary>机器可读统计快照</summary><pre>{snapshot}</pre></details>
<footer>生成器：tools/generate_art_asset_inventory.py · 报告只读，不修改或删除素材。</footer></main>
<script>const q=document.querySelector('#search'),r=document.querySelector('#role'),s=document.querySelector('#status'),rows=[...document.querySelectorAll('tbody tr')],shown=document.querySelector('#shown');function filter(){{let n=0,term=q.value.trim().toLowerCase();for(const row of rows){{let ok=(!term||row.dataset.search.includes(term))&&(!r.value||row.dataset.role===r.value)&&(!s.value||row.dataset.status===s.value);row.classList.toggle('hidden',!ok);if(ok)n++}}shown.textContent=`显示 ${{n}} / ${{rows.length}}`}}q.addEventListener('input',filter);r.addEventListener('change',filter);s.addEventListener('change',filter);filter();</script></body></html>"""
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(page, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, default=Path("docs/art_asset_inventory_stage1.html"))
    parser.add_argument("--json", type=Path, default=Path("docs/art_asset_inventory_stage1.json"))
    args = parser.parse_args()
    root = args.root.resolve()
    output = args.output if args.output.is_absolute() else root / args.output
    json_output = args.json if args.json.is_absolute() else root / args.json
    assets, excluded_tmp = collect_assets(root)
    render_report(root, assets, excluded_tmp, output)
    json_output.write_text(json.dumps({"assets": assets, "excluded_tmp": excluded_tmp}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"ASSET_INVENTORY_COUNT={len(assets)}")
    print(f"EXCLUDED_TMP_COUNT={sum(excluded_tmp.values())}")
    print(f"HTML={output}")
    print(f"JSON={json_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
