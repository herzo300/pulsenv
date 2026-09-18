"""DWG Memory index loader, reporter, and fix-script generator.

The input is JSON exported by lisp/DWG_EXPORT_INDEX.lsp from AutoCAD.
This module intentionally uses only the Python standard library.
"""

from __future__ import annotations

import argparse
import csv
import json
import shutil
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any


INDEX_FORMAT = "dwg-memory-index-v1"


@dataclass(frozen=True)
class DwgIndex:
    path: Path
    data: dict[str, Any]

    @property
    def metadata(self) -> dict[str, Any]:
        return self.data.get("metadata", {})

    @property
    def layers(self) -> list[dict[str, Any]]:
        return self.data.get("layers", [])

    @property
    def blocks(self) -> list[dict[str, Any]]:
        return self.data.get("blocks", [])

    @property
    def layouts(self) -> list[dict[str, Any]]:
        return self.data.get("layouts", [])

    @property
    def entities(self) -> list[dict[str, Any]]:
        return self.data.get("entities", [])


def load_index(path: str | Path) -> DwgIndex:
    index_path = Path(path)
    with index_path.open("r", encoding="utf-8-sig") as fh:
        data = json.load(fh)
    if data.get("format") != INDEX_FORMAT:
        raise ValueError(
            f"Unsupported index format: {data.get('format')!r}. "
            f"Expected {INDEX_FORMAT!r}."
        )
    return DwgIndex(path=index_path, data=data)


def build_summary(index: DwgIndex) -> dict[str, Any]:
    entities = index.entities
    type_counts = Counter(str(e.get("type") or "") for e in entities)
    layer_counts = Counter(str(e.get("layer") or "") for e in entities)
    layout_counts = Counter(str(e.get("layout") or "Model") for e in entities)
    block_ref_counts = Counter(
        str(e.get("name") or "")
        for e in entities
        if str(e.get("type") or "").upper() == "INSERT"
    )
    text_entities = [
        e
        for e in entities
        if e.get("text") not in (None, "")
        or str(e.get("type") or "").upper() in {"TEXT", "MTEXT", "ATTRIB", "ATTDEF"}
    ]
    empty_layers = [
        layer.get("name")
        for layer in index.layers
        if layer.get("name") not in layer_counts
    ]
    return {
        "drawing": index.metadata.get("dwgname") or index.path.stem,
        "source": str(index.path),
        "layers": len(index.layers),
        "blocks": len(index.blocks),
        "layouts": len(index.layouts),
        "entities": len(entities),
        "text_entities": len(text_entities),
        "type_counts": type_counts,
        "layer_counts": layer_counts,
        "layout_counts": layout_counts,
        "block_ref_counts": block_ref_counts,
        "empty_layers": empty_layers,
    }


def search_entities(index: DwgIndex, query: str, limit: int = 500) -> list[dict[str, Any]]:
    needle = query.strip().lower()
    if not needle:
        return index.entities[:limit]

    results: list[dict[str, Any]] = []
    for entity in index.entities:
        haystack = " ".join(
            str(entity.get(key) or "")
            for key in ("handle", "type", "layer", "layout", "name", "text")
        ).lower()
        for attr in entity.get("attributes", []):
            haystack += " " + " ".join(str(attr.get(k) or "") for k in ("tag", "text"))
        if needle in haystack:
            results.append(entity)
            if len(results) >= limit:
                break
    return results


def entity_extent_points(entity: dict[str, Any]) -> list[list[float]]:
    points: list[list[float]] = []
    for item in entity.get("points", []):
        value = item.get("value")
        if isinstance(value, list) and len(value) >= 2:
            try:
                points.append([float(value[0]), float(value[1]), float(value[2] if len(value) > 2 else 0.0)])
            except (TypeError, ValueError):
                continue
    return points


def write_report(index: DwgIndex, output_path: str | Path) -> Path:
    output = Path(output_path)
    summary = build_summary(index)
    lines: list[str] = []
    lines.append(f"# DWG Memory Report: {summary['drawing']}")
    lines.append("")
    lines.append(f"- Source index: `{summary['source']}`")
    lines.append(f"- Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"- Layers: {summary['layers']}")
    lines.append(f"- Blocks: {summary['blocks']}")
    lines.append(f"- Layouts: {summary['layouts']}")
    lines.append(f"- Entities: {summary['entities']}")
    lines.append(f"- Text-like entities: {summary['text_entities']}")
    lines.append("")

    lines.append("## Metadata")
    for key, value in sorted(index.metadata.items()):
        lines.append(f"- `{key}`: `{value}`")
    lines.append("")

    lines.append("## Entity Types")
    for name, count in summary["type_counts"].most_common():
        lines.append(f"- `{name}`: {count}")
    lines.append("")

    lines.append("## Layers By Entity Count")
    for name, count in summary["layer_counts"].most_common():
        lines.append(f"- `{name}`: {count}")
    lines.append("")

    lines.append("## Block References")
    if summary["block_ref_counts"]:
        for name, count in summary["block_ref_counts"].most_common():
            lines.append(f"- `{name}`: {count}")
    else:
        lines.append("- No INSERT references found.")
    lines.append("")

    lines.append("## Empty Layers")
    if summary["empty_layers"]:
        for name in sorted(str(x) for x in summary["empty_layers"]):
            lines.append(f"- `{name}`")
    else:
        lines.append("- No empty layers detected from exported entities.")
    lines.append("")

    lines.append("## Notes")
    lines.append("- DWG binary data is not stored here; this is an extracted searchable index.")
    lines.append("- Validate generated fixes on a copy of the DWG before applying to production files.")
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return output


def write_entities_csv(index: DwgIndex, output_path: str | Path) -> Path:
    output = Path(output_path)
    with output.open("w", encoding="utf-8-sig", newline="") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=[
                "handle",
                "type",
                "layer",
                "layout",
                "space",
                "color",
                "linetype",
                "name",
                "text",
                "attributes",
                "point_count",
            ],
        )
        writer.writeheader()
        for entity in index.entities:
            attrs = "; ".join(
                f"{a.get('tag')}={a.get('text')}" for a in entity.get("attributes", [])
            )
            writer.writerow(
                {
                    "handle": entity.get("handle"),
                    "type": entity.get("type"),
                    "layer": entity.get("layer"),
                    "layout": entity.get("layout"),
                    "space": entity.get("space"),
                    "color": entity.get("color"),
                    "linetype": entity.get("linetype"),
                    "name": entity.get("name"),
                    "text": entity.get("text"),
                    "attributes": attrs,
                    "point_count": len(entity.get("points", [])),
                }
            )
    return output


def default_memory_dir() -> Path:
    return Path.home() / "Documents" / "DWG_Memory"


def save_memory_snapshot(index: DwgIndex, root: str | Path | None = None) -> Path:
    memory_root = Path(root) if root else default_memory_dir()
    memory_root.mkdir(parents=True, exist_ok=True)
    drawing_name = str(index.metadata.get("dwgname") or index.path.stem)
    safe_name = "".join(ch if ch.isalnum() or ch in "._-" else "_" for ch in drawing_name)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    target_dir = memory_root / f"{Path(safe_name).stem}_{stamp}"
    target_dir.mkdir(parents=True, exist_ok=True)
    target_json = target_dir / index.path.name
    shutil.copy2(index.path, target_json)
    write_report(index, target_dir / "report.md")
    write_entities_csv(index, target_dir / "entities.csv")
    return target_dir


def _lisp_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def _base_lisp_load_expr(base_lisp_path: Path) -> str:
    normalized = str(base_lisp_path.resolve()).replace("\\", "/")
    return f'(load {_lisp_string(normalized)})'


def generate_fix_lisp(
    actions: list[dict[str, Any]],
    output_path: str | Path,
    base_lisp_path: str | Path,
) -> Path:
    output = Path(output_path)
    base_lisp = Path(base_lisp_path)
    lines = [
        ";;; Generated by DWG Memory GUI.",
        ";;; Review this file before applying it to a copy of the DWG.",
        (_base_lisp_load_expr(base_lisp)),
        "",
        "(defun c:DWG_MEMORY_APPLY_GENERATED (/)",
    ]
    for action in actions:
        kind = action.get("kind")
        if kind == "set_layer_color":
            lines.append(
                f"  (DWGM:SET-LAYER-COLOR {_lisp_string(str(action['layer']))} {int(action['color'])})"
            )
        elif kind == "rename_layer":
            lines.append(
                f"  (DWGM:RENAME-LAYER {_lisp_string(str(action['old']))} {_lisp_string(str(action['new']))})"
            )
        elif kind == "move_entity_to_layer":
            lines.append(
                f"  (DWGM:MOVE-ENTITY-TO-LAYER {_lisp_string(str(action['handle']))} {_lisp_string(str(action['layer']))})"
            )
        elif kind == "set_entity_color":
            lines.append(
                f"  (DWGM:SET-ENTITY-COLOR {_lisp_string(str(action['handle']))} {int(action['color'])})"
            )
        elif kind == "set_entity_text":
            lines.append(
                f"  (DWGM:SET-ENTITY-TEXT {_lisp_string(str(action['handle']))} {_lisp_string(str(action['text']))})"
            )
        elif kind == "delete_entity":
            lines.append(f"  (DWGM:DELETE-ENTITY {_lisp_string(str(action['handle']))})")
        else:
            raise ValueError(f"Unsupported fix action: {kind!r}")
    lines.extend(
        [
            '  (princ "\\nGenerated DWG Memory fixes applied.")',
            "  (princ)",
            ")",
            "",
            '(princ "\\nLoaded generated fixes. Run command: DWG_MEMORY_APPLY_GENERATED")',
            "(princ)",
        ]
    )
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return output


def analyze_to_folder(index_path: str | Path, output_dir: str | Path | None = None) -> dict[str, Path]:
    index = load_index(index_path)
    out_dir = Path(output_dir) if output_dir else Path(index.path).with_suffix("").parent
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = Path(index.path).stem
    report = write_report(index, out_dir / f"{stem}_report.md")
    csv_path = write_entities_csv(index, out_dir / f"{stem}_entities.csv")
    return {"report": report, "entities_csv": csv_path}


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyze DWG Memory JSON exported from AutoCAD.")
    parser.add_argument("index", help="Path to *_dwg_index.json")
    parser.add_argument("--out", help="Output directory for report and CSV")
    args = parser.parse_args()
    outputs = analyze_to_folder(args.index, args.out)
    for label, path in outputs.items():
        print(f"{label}: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
