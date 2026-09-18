"""Windows GUI for DWG Memory Pack."""

from __future__ import annotations

import json
import sys
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk
from typing import Any

try:
    from dwg_analyzer import (
        DwgIndex,
        build_summary,
        generate_fix_lisp,
        load_index,
        save_memory_snapshot,
        search_entities,
        write_entities_csv,
        write_report,
    )
except ImportError:
    sys.path.append(str(Path(__file__).resolve().parent))
    from dwg_analyzer import (  # type: ignore[no-redef]
        DwgIndex,
        build_summary,
        generate_fix_lisp,
        load_index,
        save_memory_snapshot,
        search_entities,
        write_entities_csv,
        write_report,
    )


ROOT = Path(__file__).resolve().parent.parent
BASE_APPLY_LISP = ROOT / "lisp" / "DWG_APPLY_FIXES.lsp"


class DwgMemoryApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("DWG Memory - AutoCAD Index Viewer")
        self.geometry("1160x760")
        self.minsize(960, 620)

        self.index: DwgIndex | None = None
        self.fix_actions: list[dict[str, Any]] = []

        self._build_ui()

    def _build_ui(self) -> None:
        self.columnconfigure(0, weight=1)
        self.rowconfigure(1, weight=1)

        toolbar = ttk.Frame(self, padding=(10, 8))
        toolbar.grid(row=0, column=0, sticky="ew")
        toolbar.columnconfigure(6, weight=1)

        ttk.Button(toolbar, text="Открыть JSON", command=self.open_index).grid(row=0, column=0, padx=4)
        ttk.Button(toolbar, text="Запомнить снимок", command=self.save_memory).grid(row=0, column=1, padx=4)
        ttk.Button(toolbar, text="Отчет MD", command=self.save_report).grid(row=0, column=2, padx=4)
        ttk.Button(toolbar, text="Экспорт CSV", command=self.save_csv).grid(row=0, column=3, padx=4)
        ttk.Button(toolbar, text="Сохранить правки LSP", command=self.save_fix_lisp).grid(row=0, column=4, padx=4)

        self.status_var = tk.StringVar(value="Открой JSON, экспортированный командой DWG_EXPORT_INDEX в AutoCAD.")
        ttk.Label(toolbar, textvariable=self.status_var, anchor="e").grid(row=0, column=6, sticky="ew", padx=8)

        self.tabs = ttk.Notebook(self)
        self.tabs.grid(row=1, column=0, sticky="nsew", padx=10, pady=(0, 10))

        summary_frame, self.summary_text = self._text_frame()
        self.tabs.add(summary_frame, text="Сводка")

        layers_frame, self.layers_tree = self._tree_frame(("name", "color", "linetype", "lineweight", "flags"))
        self.tabs.add(layers_frame, text="Слои")

        blocks_frame, self.blocks_tree = self._tree_frame(("name", "flags", "xref_path", "origin"))
        self.tabs.add(blocks_frame, text="Блоки")

        entities_frame = ttk.Frame(self.tabs)
        entities_frame.columnconfigure(0, weight=1)
        entities_frame.rowconfigure(1, weight=1)
        search_bar = ttk.Frame(entities_frame, padding=6)
        search_bar.grid(row=0, column=0, sticky="ew")
        search_bar.columnconfigure(1, weight=1)
        ttk.Label(search_bar, text="Поиск").grid(row=0, column=0, padx=(0, 6))
        self.search_var = tk.StringVar()
        search_entry = ttk.Entry(search_bar, textvariable=self.search_var)
        search_entry.grid(row=0, column=1, sticky="ew")
        search_entry.bind("<Return>", lambda _event: self.refresh_entities())
        ttk.Button(search_bar, text="Найти", command=self.refresh_entities).grid(row=0, column=2, padx=6)
        ttk.Button(search_bar, text="Сброс", command=self.clear_search).grid(row=0, column=3)
        self.entities_tree = self._tree(
            entities_frame,
            ("handle", "type", "layer", "layout", "name", "text", "attributes", "point_count"),
        )
        self.entities_tree.grid(row=1, column=0, sticky="nsew")
        entities_ybar = ttk.Scrollbar(entities_frame, orient="vertical", command=self.entities_tree.yview)
        entities_ybar.grid(row=1, column=1, sticky="ns")
        self.entities_tree.configure(yscrollcommand=entities_ybar.set)
        self.tabs.add(entities_frame, text="Объекты")

        self.fixes_frame = ttk.Frame(self.tabs, padding=10)
        self.tabs.add(self.fixes_frame, text="Правки")
        self._build_fixes_tab()

    def _tree(self, parent: tk.Widget, columns: tuple[str, ...]) -> ttk.Treeview:
        tree = ttk.Treeview(parent, columns=columns, show="headings")
        for col in columns:
            tree.heading(col, text=col)
            width = 160 if col in {"text", "attributes", "xref_path", "origin"} else 110
            tree.column(col, width=width, minwidth=70, stretch=True)
        return tree

    def _text_frame(self) -> tuple[ttk.Frame, tk.Text]:
        frame = ttk.Frame(self.tabs)
        frame.columnconfigure(0, weight=1)
        frame.rowconfigure(0, weight=1)
        widget = tk.Text(frame, wrap="word", height=10)
        widget.configure(font=("Consolas", 10))
        widget.grid(row=0, column=0, sticky="nsew")
        ybar = ttk.Scrollbar(frame, orient="vertical", command=widget.yview)
        ybar.grid(row=0, column=1, sticky="ns")
        widget.configure(yscrollcommand=ybar.set)
        return frame, widget

    def _tree_frame(self, columns: tuple[str, ...]) -> tuple[ttk.Frame, ttk.Treeview]:
        frame = ttk.Frame(self.tabs)
        frame.columnconfigure(0, weight=1)
        frame.rowconfigure(0, weight=1)
        tree = self._tree(frame, columns)
        tree.grid(row=0, column=0, sticky="nsew")
        ybar = ttk.Scrollbar(frame, orient="vertical", command=tree.yview)
        ybar.grid(row=0, column=1, sticky="ns")
        tree.configure(yscrollcommand=ybar.set)
        return frame, tree

    def _build_fixes_tab(self) -> None:
        self.fixes_frame.columnconfigure(0, weight=1)
        self.fixes_frame.columnconfigure(1, weight=1)
        self.fixes_frame.rowconfigure(5, weight=1)

        ttk.Label(
            self.fixes_frame,
            text="Правки генерируются как AutoLISP. Применяй их только на копии DWG.",
        ).grid(row=0, column=0, columnspan=2, sticky="w", pady=(0, 10))

        layer_box = ttk.LabelFrame(self.fixes_frame, text="Слой", padding=8)
        layer_box.grid(row=1, column=0, sticky="ew", padx=(0, 8), pady=4)
        layer_box.columnconfigure(1, weight=1)
        ttk.Label(layer_box, text="Слой").grid(row=0, column=0, sticky="w")
        self.fix_layer_var = tk.StringVar()
        self.fix_layer_combo = ttk.Combobox(layer_box, textvariable=self.fix_layer_var)
        self.fix_layer_combo.grid(row=0, column=1, sticky="ew", padx=6)
        ttk.Label(layer_box, text="Цвет ACI").grid(row=1, column=0, sticky="w")
        self.fix_layer_color_var = tk.IntVar(value=1)
        ttk.Spinbox(layer_box, from_=1, to=255, textvariable=self.fix_layer_color_var, width=8).grid(
            row=1, column=1, sticky="w", padx=6
        )
        ttk.Button(layer_box, text="Добавить смену цвета слоя", command=self.add_layer_color_fix).grid(
            row=2, column=0, columnspan=2, sticky="ew", pady=(8, 0)
        )

        rename_box = ttk.LabelFrame(self.fixes_frame, text="Переименовать слой", padding=8)
        rename_box.grid(row=1, column=1, sticky="ew", pady=4)
        rename_box.columnconfigure(1, weight=1)
        ttk.Label(rename_box, text="Старый").grid(row=0, column=0, sticky="w")
        self.rename_old_var = tk.StringVar()
        self.rename_old_combo = ttk.Combobox(rename_box, textvariable=self.rename_old_var)
        self.rename_old_combo.grid(row=0, column=1, sticky="ew", padx=6)
        ttk.Label(rename_box, text="Новый").grid(row=1, column=0, sticky="w")
        self.rename_new_var = tk.StringVar()
        ttk.Entry(rename_box, textvariable=self.rename_new_var).grid(row=1, column=1, sticky="ew", padx=6)
        ttk.Button(rename_box, text="Добавить переименование", command=self.add_rename_layer_fix).grid(
            row=2, column=0, columnspan=2, sticky="ew", pady=(8, 0)
        )

        entity_box = ttk.LabelFrame(self.fixes_frame, text="Объект по handle", padding=8)
        entity_box.grid(row=2, column=0, sticky="ew", padx=(0, 8), pady=4)
        entity_box.columnconfigure(1, weight=1)
        ttk.Label(entity_box, text="Handle").grid(row=0, column=0, sticky="w")
        self.handle_var = tk.StringVar()
        ttk.Entry(entity_box, textvariable=self.handle_var).grid(row=0, column=1, sticky="ew", padx=6)
        ttk.Label(entity_box, text="Слой").grid(row=1, column=0, sticky="w")
        self.move_layer_var = tk.StringVar()
        self.move_layer_combo = ttk.Combobox(entity_box, textvariable=self.move_layer_var)
        self.move_layer_combo.grid(row=1, column=1, sticky="ew", padx=6)
        ttk.Button(entity_box, text="Перенести на слой", command=self.add_move_entity_fix).grid(
            row=2, column=0, columnspan=2, sticky="ew", pady=(8, 0)
        )
        ttk.Label(entity_box, text="Цвет ACI").grid(row=3, column=0, sticky="w", pady=(8, 0))
        self.entity_color_var = tk.IntVar(value=256)
        ttk.Spinbox(entity_box, from_=1, to=256, textvariable=self.entity_color_var, width=8).grid(
            row=3, column=1, sticky="w", padx=6, pady=(8, 0)
        )
        ttk.Button(entity_box, text="Задать цвет объекта", command=self.add_entity_color_fix).grid(
            row=4, column=0, columnspan=2, sticky="ew", pady=(8, 0)
        )

        text_box = ttk.LabelFrame(self.fixes_frame, text="Текст", padding=8)
        text_box.grid(row=2, column=1, sticky="ew", pady=4)
        text_box.columnconfigure(1, weight=1)
        ttk.Label(text_box, text="Handle").grid(row=0, column=0, sticky="w")
        self.text_handle_var = tk.StringVar()
        ttk.Entry(text_box, textvariable=self.text_handle_var).grid(row=0, column=1, sticky="ew", padx=6)
        ttk.Label(text_box, text="Новый текст").grid(row=1, column=0, sticky="w")
        self.text_value_var = tk.StringVar()
        ttk.Entry(text_box, textvariable=self.text_value_var).grid(row=1, column=1, sticky="ew", padx=6)
        ttk.Button(text_box, text="Заменить текст", command=self.add_set_text_fix).grid(
            row=2, column=0, columnspan=2, sticky="ew", pady=(8, 0)
        )
        ttk.Button(text_box, text="Удалить объект по handle", command=self.add_delete_entity_fix).grid(
            row=3, column=0, columnspan=2, sticky="ew", pady=(8, 0)
        )

        self.actions_list = tk.Listbox(self.fixes_frame, height=10)
        self.actions_list.grid(row=5, column=0, columnspan=2, sticky="nsew", pady=(10, 4))
        action_buttons = ttk.Frame(self.fixes_frame)
        action_buttons.grid(row=6, column=0, columnspan=2, sticky="ew")
        ttk.Button(action_buttons, text="Удалить выбранную", command=self.remove_selected_action).pack(
            side="left", padx=(0, 6)
        )
        ttk.Button(action_buttons, text="Очистить", command=self.clear_actions).pack(side="left")

    def open_index(self) -> None:
        path = filedialog.askopenfilename(
            title="Выбери DWG Memory JSON",
            filetypes=[("DWG Memory JSON", "*.json"), ("All files", "*.*")],
        )
        if not path:
            return
        try:
            self.index = load_index(path)
        except Exception as exc:
            messagebox.showerror("Ошибка чтения", str(exc))
            return
        self.status_var.set(f"Открыто: {path}")
        self.refresh_all()

    def refresh_all(self) -> None:
        if not self.index:
            return
        self.refresh_summary()
        self.refresh_layers()
        self.refresh_blocks()
        self.refresh_entities()
        self.refresh_layer_choices()

    def refresh_summary(self) -> None:
        assert self.index
        summary = build_summary(self.index)
        lines = [
            f"Чертеж: {summary['drawing']}",
            f"JSON: {summary['source']}",
            "",
            f"Слоев: {summary['layers']}",
            f"Блоков: {summary['blocks']}",
            f"Листов/layouts: {summary['layouts']}",
            f"Объектов: {summary['entities']}",
            f"Текстовых объектов: {summary['text_entities']}",
            "",
            "Типы объектов:",
        ]
        lines.extend(f"  {name}: {count}" for name, count in summary["type_counts"].most_common(30))
        lines.append("")
        lines.append("Слои по количеству объектов:")
        lines.extend(f"  {name}: {count}" for name, count in summary["layer_counts"].most_common(30))
        lines.append("")
        lines.append("Пустые слои:")
        if summary["empty_layers"]:
            lines.extend(f"  {name}" for name in sorted(str(x) for x in summary["empty_layers"])[:100])
        else:
            lines.append("  не найдены")

        self.summary_text.configure(state="normal")
        self.summary_text.delete("1.0", tk.END)
        self.summary_text.insert(tk.END, "\n".join(lines))
        self.summary_text.configure(state="disabled")

    def refresh_layers(self) -> None:
        assert self.index
        self._clear_tree(self.layers_tree)
        for layer in self.index.layers:
            self.layers_tree.insert(
                "",
                tk.END,
                values=(
                    layer.get("name"),
                    layer.get("color"),
                    layer.get("linetype"),
                    layer.get("lineweight"),
                    layer.get("flags"),
                ),
            )

    def refresh_blocks(self) -> None:
        assert self.index
        self._clear_tree(self.blocks_tree)
        for block in self.index.blocks:
            self.blocks_tree.insert(
                "",
                tk.END,
                values=(
                    block.get("name"),
                    block.get("flags"),
                    block.get("xref_path"),
                    block.get("origin"),
                ),
            )

    def refresh_entities(self) -> None:
        if not self.index:
            return
        self._clear_tree(self.entities_tree)
        entities = search_entities(self.index, self.search_var.get(), limit=2000)
        for entity in entities:
            attrs = "; ".join(
                f"{a.get('tag')}={a.get('text')}" for a in entity.get("attributes", [])
            )
            text = entity.get("text")
            if isinstance(text, str) and len(text) > 180:
                text = text[:177] + "..."
            self.entities_tree.insert(
                "",
                tk.END,
                values=(
                    entity.get("handle"),
                    entity.get("type"),
                    entity.get("layer"),
                    entity.get("layout"),
                    entity.get("name"),
                    text,
                    attrs,
                    len(entity.get("points", [])),
                ),
            )
        self.status_var.set(f"Показано объектов: {len(entities)}")

    def refresh_layer_choices(self) -> None:
        if not self.index:
            return
        names = sorted(str(layer.get("name")) for layer in self.index.layers if layer.get("name"))
        for combo in (self.fix_layer_combo, self.rename_old_combo, self.move_layer_combo):
            combo.configure(values=names)

    def clear_search(self) -> None:
        self.search_var.set("")
        self.refresh_entities()

    @staticmethod
    def _clear_tree(tree: ttk.Treeview) -> None:
        for item in tree.get_children():
            tree.delete(item)

    def save_memory(self) -> None:
        if not self.index:
            messagebox.showinfo("Нет данных", "Сначала открой JSON.")
            return
        try:
            folder = save_memory_snapshot(self.index)
        except Exception as exc:
            messagebox.showerror("Ошибка", str(exc))
            return
        messagebox.showinfo("Готово", f"Снимок сохранен:\n{folder}")

    def save_report(self) -> None:
        if not self.index:
            messagebox.showinfo("Нет данных", "Сначала открой JSON.")
            return
        path = filedialog.asksaveasfilename(
            title="Сохранить Markdown отчет",
            defaultextension=".md",
            initialfile=f"{self.index.path.stem}_report.md",
            filetypes=[("Markdown", "*.md"), ("All files", "*.*")],
        )
        if not path:
            return
        write_report(self.index, path)
        messagebox.showinfo("Готово", f"Отчет сохранен:\n{path}")

    def save_csv(self) -> None:
        if not self.index:
            messagebox.showinfo("Нет данных", "Сначала открой JSON.")
            return
        path = filedialog.asksaveasfilename(
            title="Сохранить CSV объектов",
            defaultextension=".csv",
            initialfile=f"{self.index.path.stem}_entities.csv",
            filetypes=[("CSV", "*.csv"), ("All files", "*.*")],
        )
        if not path:
            return
        write_entities_csv(self.index, path)
        messagebox.showinfo("Готово", f"CSV сохранен:\n{path}")

    def add_action(self, action: dict[str, Any], label: str) -> None:
        self.fix_actions.append(action)
        self.actions_list.insert(tk.END, label)

    def add_layer_color_fix(self) -> None:
        layer = self.fix_layer_var.get().strip()
        if not layer:
            messagebox.showinfo("Нет слоя", "Выбери или введи слой.")
            return
        color = int(self.fix_layer_color_var.get())
        self.add_action(
            {"kind": "set_layer_color", "layer": layer, "color": color},
            f"Цвет слоя {layer} -> {color}",
        )

    def add_rename_layer_fix(self) -> None:
        old = self.rename_old_var.get().strip()
        new = self.rename_new_var.get().strip()
        if not old or not new:
            messagebox.showinfo("Нет данных", "Укажи старое и новое имя слоя.")
            return
        self.add_action(
            {"kind": "rename_layer", "old": old, "new": new},
            f"Переименовать слой {old} -> {new}",
        )

    def add_move_entity_fix(self) -> None:
        handle = self.handle_var.get().strip()
        layer = self.move_layer_var.get().strip()
        if not handle or not layer:
            messagebox.showinfo("Нет данных", "Укажи handle и слой.")
            return
        self.add_action(
            {"kind": "move_entity_to_layer", "handle": handle, "layer": layer},
            f"Объект {handle} на слой {layer}",
        )

    def add_entity_color_fix(self) -> None:
        handle = self.handle_var.get().strip()
        if not handle:
            messagebox.showinfo("Нет handle", "Укажи handle объекта.")
            return
        color = int(self.entity_color_var.get())
        self.add_action(
            {"kind": "set_entity_color", "handle": handle, "color": color},
            f"Цвет объекта {handle} -> {color}",
        )

    def add_set_text_fix(self) -> None:
        handle = self.text_handle_var.get().strip()
        text = self.text_value_var.get()
        if not handle:
            messagebox.showinfo("Нет handle", "Укажи handle текстового объекта.")
            return
        self.add_action(
            {"kind": "set_entity_text", "handle": handle, "text": text},
            f"Текст {handle} -> {text}",
        )

    def add_delete_entity_fix(self) -> None:
        handle = self.text_handle_var.get().strip() or self.handle_var.get().strip()
        if not handle:
            messagebox.showinfo("Нет handle", "Укажи handle объекта.")
            return
        if not messagebox.askyesno("Подтверждение", f"Добавить удаление объекта {handle}?"):
            return
        self.add_action({"kind": "delete_entity", "handle": handle}, f"Удалить объект {handle}")

    def remove_selected_action(self) -> None:
        selected = list(self.actions_list.curselection())
        if not selected:
            return
        for idx in reversed(selected):
            self.actions_list.delete(idx)
            del self.fix_actions[idx]

    def clear_actions(self) -> None:
        self.fix_actions.clear()
        self.actions_list.delete(0, tk.END)

    def save_fix_lisp(self) -> None:
        if not self.fix_actions:
            messagebox.showinfo("Нет правок", "Сначала добавь хотя бы одну правку.")
            return
        initial_dir = str(self.index.path.parent) if self.index else str(Path.home())
        path = filedialog.asksaveasfilename(
            title="Сохранить AutoLISP правки",
            initialdir=initial_dir,
            initialfile="apply_generated_fixes.lsp",
            defaultextension=".lsp",
            filetypes=[("AutoLISP", "*.lsp"), ("All files", "*.*")],
        )
        if not path:
            return
        try:
            generate_fix_lisp(self.fix_actions, path, BASE_APPLY_LISP)
        except Exception as exc:
            messagebox.showerror("Ошибка", str(exc))
            return
        messagebox.showinfo(
            "Готово",
            "LISP с правками сохранен.\n\n"
            "В AutoCAD загрузи его через APPLOAD и выполни команду:\n"
            "DWG_MEMORY_APPLY_GENERATED",
        )


def main() -> int:
    app = DwgMemoryApp()
    app.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
