---
name: python-tool-builder
description: Build, structure, and maintain custom Python tools for the ComfyUI–Blender–Godot pipeline. Enforces virtual environment discipline, clean module structure, and reproducible dependency management using uv.
version: 1.0.0
author: pipeline-hermes
license: MIT
dependencies: [uv]
metadata:
  hermes:
    tags: [Python, ToolBuilding, BestPractices, uv, venv, DevOps]
    related_skills: [comfyui-pipeline, blender-helper, godot-pipeline, asset-format-bridge]
---

# Python Tool Builder Skill

Scaffold and maintain Python tools for the pipeline with proper isolation and dependency management.

## Project Scaffolding

```bash
# Create new tool in pipeline/lib/
cd pipeline/lib
uv init --name $TOOL_NAME
uv add requests Pillow watchdog numpy

# Structure:
# pipeline/lib/$TOOL_NAME/
# ├── pyproject.toml        ← uv managed
# ├── src/$TOOL_NAME/
# │   ├── __init__.py
# │   ├── main.py
# │   └── utils.py
# ├── tests/
# │   └── test_main.py
# └── README.md
```

## Dependency Management Rules

1. **Always use uv** — never `pip install` directly into system Python
2. **One venv per tool** — `pipeline/lib/$TOOL_NAME/.venv`
3. **Pin versions in CI** — `uv pip freeze > requirements.lock`
4. **No stray dependencies** — if it's not in `pyproject.toml`, it's not installed

## Virtual Environment Workflow

```bash
# Activate venv
source pipeline/lib/$TOOL_NAME/.venv/bin/activate

# Run tool
python -m $TOOL_NAME

# Update dependencies
uv add newpackage
uv sync

# Lock versions (for reproducibility)
uv pip freeze | grep -v "#" > pipeline/lib/$TOOL_NAME/requirements.lock
```

## Pipeline-Specific Tool Template

```python
#!/usr/bin/env python3
"""
$TEMPLATE_TOOL_NAME — one-line description.
Run: python -m $TEMPLATE_TOOL_NAME [args]
"""
import argparse
import os
import sys
from pathlib import Path

# Ensure project root in path
ROOT = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(ROOT / "lib" / "$TEMPLATE_TOOL_NAME" / "src"))

def main():
    parser = argparse.ArgumentParser(description="$TEMPLATE_TOOL_NAME")
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()
    
    output = args.output or args.input.with_suffix(".out.png")
    # TODO: implement transformation
    print(f"Processed: {args.input} → {output}")

if __name__ == "__main__":
    main()
```

## Running in the Pipeline venv

The main pipeline venv at `awesome-hermes-agent/.venv` has:
- Pillow, opencv-python, numpy, watchdog, requests, h5py, trimesh
- pydantic, fastapi, uvicorn

Use it for: image transforms, file watching, HTTP APIs, mesh I/O.

For tool-specific deps, create a separate venv in `pipeline/lib/$TOOL_NAME/`.

## Shared Library Imports

```
pipeline/lib/shared/          ← common code across tools
├── texture_utils.py
├── mesh_utils.py
├── staging.py
└── manifest.py
```

## Quick Reference

| Task | Command |
|---|---|
| New tool | `uv init --name mytool && cd mytool && uv add deps` |
| Activate venv | `source pipeline/lib/$TOOL_NAME/.venv/bin/activate` |
| Lock deps | `uv pip freeze > requirements.lock` |
| Run tool | `python -m $TOOL_NAME --arg val` |
| Add to pipeline venv | `uv pip install --python awesome-hermes-agent/.venv/bin/python $PACKAGE` |
