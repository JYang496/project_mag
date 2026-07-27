from __future__ import annotations

import queue
import sys
import threading
import traceback
from pathlib import Path
from tkinter import (
    BooleanVar,
    DoubleVar,
    END,
    HORIZONTAL,
    IntVar,
    Listbox,
    StringVar,
    Tk,
    filedialog,
    messagebox,
    ttk,
)

from PIL import Image, ImageTk

from normalizer import NormalizeOptions, normalize_files, normalize_pil, normalize_sequence
from presets import PRESETS


APP_NAME = "Perfect Pixel 图片规范化工具"
PRESET_LABELS = {"自动识别项目路径": "auto"}
PRESET_LABELS.update({preset.label: preset_id for preset_id, preset in PRESETS.items()})
PRESET_IDS_TO_LABELS = {preset_id: label for label, preset_id in PRESET_LABELS.items()}
SUPPORTED_FILES = (
    ("图片文件", "*.png *.jpg *.jpeg *.webp *.bmp *.tif *.tiff"),
    ("所有文件", "*.*"),
)


class PerfectPixelApp:
    def __init__(self, root: Tk) -> None:
        self.root = root
        self.root.title(APP_NAME)
        self.root.geometry("1160x760")
        self.root.minsize(920, 650)

        self.paths: list[Path] = []
        self.preview_refs: list[ImageTk.PhotoImage | None] = [None, None]
        self.events: queue.Queue[tuple[str, object]] = queue.Queue()

        self.sampling = StringVar(value="median")
        self.export_scale = IntVar(value=1)
        self.preset_label = StringVar(value="自动识别项目路径")
        self.protect_finished = BooleanVar(value=True)
        self.lock_sequence = BooleanVar(value=False)
        self.manual_grid = BooleanVar(value=False)
        self.grid_width = IntVar(value=32)
        self.grid_height = IntVar(value=32)
        self.refine = DoubleVar(value=0.25)
        self.fix_square = BooleanVar(value=True)
        self.output_dir = StringVar(value="")
        self.status = StringVar(value="请选择一张或多张图片。")

        self._build_ui()
        self._set_busy(False)
        self.root.after(100, self._poll_events)

    def _build_ui(self) -> None:
        shell = ttk.Frame(self.root, padding=12)
        shell.pack(fill="both", expand=True)
        shell.columnconfigure(1, weight=1)
        shell.rowconfigure(1, weight=1)

        toolbar = ttk.Frame(shell)
        toolbar.grid(row=0, column=0, columnspan=2, sticky="ew", pady=(0, 10))
        ttk.Button(toolbar, text="添加图片", command=self._add_images).pack(side="left")
        ttk.Button(toolbar, text="移除所选", command=self._remove_selected).pack(
            side="left", padx=6
        )
        ttk.Button(toolbar, text="清空", command=self._clear).pack(side="left")
        ttk.Button(toolbar, text="选择输出目录", command=self._choose_output).pack(
            side="left", padx=(18, 6)
        )
        ttk.Label(toolbar, textvariable=self.output_dir).pack(
            side="left", fill="x", expand=True
        )

        left = ttk.LabelFrame(shell, text="任务与参数", padding=10)
        left.grid(row=1, column=0, sticky="nsw", padx=(0, 10))

        self.file_list = Listbox(left, width=40, height=13, exportselection=False)
        self.file_list.pack(fill="x")
        self.file_list.bind("<<ListboxSelect>>", self._selection_changed)

        form = ttk.Frame(left)
        form.pack(fill="x", pady=(12, 0))
        ttk.Label(form, text="单元格采样").grid(row=0, column=0, sticky="w")
        ttk.Combobox(
            form,
            textvariable=self.sampling,
            values=("median", "center", "majority"),
            state="readonly",
            width=15,
        ).grid(row=0, column=1, sticky="ew", pady=3)

        ttk.Label(form, text="资产预设").grid(row=1, column=0, sticky="w")
        ttk.Combobox(
            form,
            textvariable=self.preset_label,
            values=tuple(PRESET_LABELS.keys()),
            state="readonly",
            width=24,
        ).grid(row=1, column=1, sticky="ew", pady=3)

        ttk.Label(form, text="导出倍率").grid(row=2, column=0, sticky="w")
        ttk.Spinbox(form, from_=1, to=32, textvariable=self.export_scale, width=16).grid(
            row=2, column=1, sticky="ew", pady=3
        )

        ttk.Checkbutton(
            form,
            text="手动网格",
            variable=self.manual_grid,
            command=self._toggle_manual_grid,
        ).grid(row=3, column=0, sticky="w")
        grid_box = ttk.Frame(form)
        grid_box.grid(row=3, column=1, sticky="ew", pady=3)
        self.grid_w_input = ttk.Spinbox(
            grid_box, from_=2, to=512, textvariable=self.grid_width, width=7
        )
        self.grid_w_input.pack(side="left")
        ttk.Label(grid_box, text=" × ").pack(side="left")
        self.grid_h_input = ttk.Spinbox(
            grid_box, from_=2, to=512, textvariable=self.grid_height, width=7
        )
        self.grid_h_input.pack(side="left")

        ttk.Label(form, text="边缘校正").grid(row=4, column=0, sticky="w")
        ttk.Scale(
            form,
            from_=0.0,
            to=0.5,
            variable=self.refine,
            orient=HORIZONTAL,
        ).grid(row=4, column=1, sticky="ew", pady=3)

        ttk.Checkbutton(
            form, text="近方形时自动修正", variable=self.fix_square
        ).grid(row=5, column=0, columnspan=2, sticky="w", pady=3)
        ttk.Checkbutton(
            form, text="保护疑似成品资产", variable=self.protect_finished
        ).grid(row=6, column=0, columnspan=2, sticky="w", pady=3)
        ttk.Checkbutton(
            form, text="批量时锁定为动画序列", variable=self.lock_sequence
        ).grid(row=7, column=0, columnspan=2, sticky="w", pady=3)
        form.columnconfigure(1, weight=1)

        hint = (
            "median：抗噪声，推荐\n"
            "center：最快，适合干净网格\n"
            "majority：颜色复杂时更稳，但较慢\n"
            "序列模式让所有帧共享参考帧网格。"
        )
        ttk.Label(left, text=hint, foreground="#555").pack(anchor="w", pady=(10, 12))

        action_box = ttk.Frame(left)
        action_box.pack(fill="x")
        self.preview_button = ttk.Button(
            action_box, text="预览所选", command=self._preview_selected
        )
        self.preview_button.pack(side="left", fill="x", expand=True)
        self.batch_button = ttk.Button(
            action_box, text="批量导出", command=self._batch_export
        )
        self.batch_button.pack(side="left", fill="x", expand=True, padx=(6, 0))

        preview = ttk.Frame(shell)
        preview.grid(row=1, column=1, sticky="nsew")
        preview.columnconfigure(0, weight=1)
        preview.columnconfigure(1, weight=1)
        preview.rowconfigure(0, weight=1)

        self.before = ttk.Label(
            preview, text="原图", anchor="center", relief="solid", padding=4
        )
        self.before.grid(row=0, column=0, sticky="nsew", padx=(0, 5))
        self.after = ttk.Label(
            preview, text="规范化结果", anchor="center", relief="solid", padding=4
        )
        self.after.grid(row=0, column=1, sticky="nsew", padx=(5, 0))

        ttk.Separator(shell).grid(
            row=2, column=0, columnspan=2, sticky="ew", pady=(10, 8)
        )
        ttk.Label(shell, textvariable=self.status).grid(
            row=3, column=0, columnspan=2, sticky="w"
        )

    def _toggle_manual_grid(self) -> None:
        state = "normal" if self.manual_grid.get() else "disabled"
        self.grid_w_input.configure(state=state)
        self.grid_h_input.configure(state=state)

    def _set_busy(self, busy: bool) -> None:
        state = "disabled" if busy else "normal"
        self.preview_button.configure(state=state)
        self.batch_button.configure(state=state)
        self._toggle_manual_grid()

    def _add_images(self) -> None:
        selected = filedialog.askopenfilenames(title="选择图片", filetypes=SUPPORTED_FILES)
        for raw in selected:
            path = Path(raw)
            if path not in self.paths:
                self.paths.append(path)
                self.file_list.insert(END, path.name)
        if selected and not self.output_dir.get():
            self.output_dir.set(str(Path(selected[0]).parent / "normalized"))
        if self.paths and not self.file_list.curselection():
            self.file_list.selection_set(0)
            self._show_source(self.paths[0])
        self.status.set(f"已添加 {len(self.paths)} 张图片。")

    def _remove_selected(self) -> None:
        selected = self.file_list.curselection()
        if not selected:
            return
        index = selected[0]
        self.file_list.delete(index)
        self.paths.pop(index)
        self.status.set(f"剩余 {len(self.paths)} 张图片。")

    def _clear(self) -> None:
        self.paths.clear()
        self.file_list.delete(0, END)
        self.before.configure(image="", text="原图")
        self.after.configure(image="", text="规范化结果")
        self.preview_refs = [None, None]
        self.status.set("列表已清空。")

    def _choose_output(self) -> None:
        selected = filedialog.askdirectory(title="选择输出目录")
        if selected:
            self.output_dir.set(selected)

    def _selection_changed(self, _event: object = None) -> None:
        selected = self.file_list.curselection()
        if selected:
            self._show_source(self.paths[selected[0]])

    def _thumbnail(self, image: Image.Image) -> ImageTk.PhotoImage:
        copy = image.copy()
        copy.thumbnail((460, 590), Image.Resampling.NEAREST)
        return ImageTk.PhotoImage(copy)

    def _show_source(self, path: Path) -> None:
        try:
            with Image.open(path) as image:
                image.load()
                photo = self._thumbnail(image.convert("RGBA"))
            self.preview_refs[0] = photo
            self.before.configure(image=photo, text="")
        except Exception as exc:
            self.status.set(f"无法预览 {path.name}：{exc}")

    def _options(self) -> NormalizeOptions:
        grid = (
            (int(self.grid_width.get()), int(self.grid_height.get()))
            if self.manual_grid.get()
            else None
        )
        return NormalizeOptions(
            sampling=self.sampling.get(),
            export_scale=int(self.export_scale.get()),
            grid_size=grid,
            refine_intensity=float(self.refine.get()),
            fix_square=bool(self.fix_square.get()),
            preset=PRESET_LABELS[self.preset_label.get()],
            protection="error" if self.protect_finished.get() else "allow",
        )

    def _preview_selected(self) -> None:
        selected = self.file_list.curselection()
        if not selected:
            messagebox.showinfo(APP_NAME, "请先选择一张图片。")
            return
        path = self.paths[selected[0]]
        try:
            options = self._options()
            options.validate()
        except Exception as exc:
            messagebox.showerror(APP_NAME, str(exc))
            return
        self._set_busy(True)
        self.status.set(f"正在处理 {path.name}…")
        threading.Thread(
            target=self._preview_worker, args=(path, options), daemon=True
        ).start()

    def _preview_worker(self, path: Path, options: NormalizeOptions) -> None:
        try:
            with Image.open(path) as image:
                image.load()
                result = normalize_pil(image, options, source_path=path)
            self.events.put(("preview", (path, result)))
        except Exception as exc:
            self.events.put(("error", (str(exc), traceback.format_exc())))

    def _batch_export(self) -> None:
        if not self.paths:
            messagebox.showinfo(APP_NAME, "请先添加图片。")
            return
        if not self.output_dir.get():
            self._choose_output()
        if not self.output_dir.get():
            return
        try:
            options = self._options()
            options.validate()
        except Exception as exc:
            messagebox.showerror(APP_NAME, str(exc))
            return
        self._set_busy(True)
        self.status.set(f"开始批量处理 {len(self.paths)} 张图片…")
        threading.Thread(
            target=self._batch_worker,
            args=(
                list(self.paths),
                Path(self.output_dir.get()),
                options,
                bool(self.lock_sequence.get()),
            ),
            daemon=True,
        ).start()

    def _batch_worker(
        self,
        paths: list[Path],
        output_dir: Path,
        options: NormalizeOptions,
        lock_sequence: bool,
    ) -> None:
        report_path = output_dir / "quality_report.json"
        try:
            if lock_sequence:
                sequence = normalize_sequence(
                    paths,
                    output_dir,
                    options,
                    reference_index=0,
                    report_path=report_path,
                )
                successes = [str(item.destination_path) for item in sequence.items]
                warning_count = int(sequence.report["summary"]["warning_count"])
            else:
                report = normalize_files(
                    paths, output_dir, options, report_path=report_path
                )
                successes = [
                    str(output_dir / f"{path.stem}_normalized.png") for path in paths
                ]
                warning_count = int(report["summary"]["warning_count"])
            self.events.put(
                ("batch", (successes, [], str(report_path), warning_count))
            )
        except Exception as exc:
            self.events.put(("batch", ([], [str(exc)], str(report_path), 0)))

    def _poll_events(self) -> None:
        try:
            while True:
                kind, payload = self.events.get_nowait()
                if kind == "preview":
                    path, result = payload
                    photo = self._thumbnail(result.image)
                    self.preview_refs[1] = photo
                    self.after.configure(image=photo, text="")
                    self.status.set(
                        f"{path.name}：识别为 {result.grid_width} × "
                        f"{result.grid_height} 网格；预设 "
                        f"{PRESET_IDS_TO_LABELS.get(result.preset, result.preset)}；"
                        f"警告 {len(result.warnings)}。"
                    )
                    self._set_busy(False)
                elif kind == "progress":
                    self.status.set(str(payload))
                elif kind == "batch":
                    successes, failures, report_path, warning_count = payload
                    self._set_busy(False)
                    self.status.set(
                        f"完成：成功 {len(successes)}，失败 {len(failures)}，"
                        f"警告 {warning_count}。"
                    )
                    if failures:
                        messagebox.showwarning(
                            APP_NAME,
                            "部分图片处理失败：\n\n" + "\n".join(failures[:12]),
                        )
                    else:
                        messagebox.showinfo(
                            APP_NAME,
                            f"已导出 {len(successes)} 张图片到：\n"
                            f"{self.output_dir.get()}\n\n质量报告：\n{report_path}",
                        )
                elif kind == "error":
                    message, details = payload
                    self._set_busy(False)
                    self.status.set("处理失败。")
                    messagebox.showerror(APP_NAME, f"{message}\n\n{details[-1200:]}")
        except queue.Empty:
            pass
        self.root.after(100, self._poll_events)


def main() -> int:
    if "--self-test" in sys.argv:
        import numpy as np

        pattern = np.zeros((80, 80, 3), dtype=np.uint8)
        pattern[::2, :] = (225, 80, 65)
        pattern[:, ::2] = (55, 130, 220)
        result = normalize_pil(
            Image.fromarray(pattern),
            NormalizeOptions(grid_size=(8, 8), export_scale=2),
        )
        if result.image.size != (result.grid_width * 2, result.grid_height * 2):
            print("SELF_TEST_FAILED")
            return 1
        print(
            f"SELF_TEST_OK grid={result.grid_width}x{result.grid_height} "
            f"output={result.image.width}x{result.image.height}"
        )
        return 0

    root = Tk()
    try:
        ttk.Style().theme_use("vista")
    except Exception:
        pass
    PerfectPixelApp(root)
    root.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
