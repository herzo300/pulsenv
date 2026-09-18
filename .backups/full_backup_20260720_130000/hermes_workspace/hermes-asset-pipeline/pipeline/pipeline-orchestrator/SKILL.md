---
name: pipeline-orchestrator
description: Coordinate the ComfyUI–Blender–Godot–Python pipeline as a series of staged steps. Watches staging directories, triggers format conversions, manages the asset manifest, and logs pipeline state for reproducibility.
version: 1.0.0
author: pipeline-hermes
license: MIT
dependencies: [watchdog, requests]
metadata:
  hermes:
    tags: [Pipeline, Orchestration, Automation, Staging, Workflow]
    related_skills: [comfyui-pipeline, blender-helper, godot-pipeline, asset-format-bridge]
---

# Pipeline Orchestrator Skill

The central coordination layer for the ComfyUI ↔ Blender ↔ Godot pipeline. Manages staging directories, triggers stage transitions, and maintains an asset manifest.

## Architecture

```
ComfyUI Output
    ↓
pipeline/staging/comfyui_output/     ← image lands here
    ↓  [asset-format-bridge]
pipeline/staging/2d_to_3d/           ← texture pack generated
    ↓  [blender-helper]
pipeline/staging/blender_import/     ← mesh + textures applied
    ↓  [asset-format-bridge]
pipeline/staging/godot_models/       ← GLB exported
    ↓  [godot-pipeline]
Godot res:// import                  ← Godot picks up on next scan
    ↓
pipeline/staging/exports/            ← Godot final export
```

## Core Tools

### 1. Pipeline State Manager
```python
import json, os
from pathlib import Path
from datetime import datetime

MANIFEST = Path("pipeline/staging/assets_manifest.json")
LOG = Path("pipeline/pipeline.log")

def log(msg: str):
    ts = datetime.now().isoformat()
    line = f"[{ts}] {msg}"
    print(line)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    LOG.open("a").write(line + "\n")

def init_pipeline():
    """Initialize empty manifest."""
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps({"version": "1.0", "assets": [], "runs": []}, indent=2))
    log("Pipeline initialized")

def record_asset(file: str, stage: str, meta: dict = None):
    manifest = json.loads(MANIFEST.read_text())
    manifest["assets"].append({
        "file": file,
        "stage": stage,
        "timestamp": datetime.now().isoformat(),
        "meta": meta or {}
    })
    MANIFEST.write_text(json.dumps(manifest, indent=2))
    log(f"[{stage}] {file}")

def record_run(name: str, steps: list[str], status: str):
    manifest = json.loads(MANIFEST.read_text())
    manifest["runs"].append({
        "name": name,
        "steps": steps,
        "status": status,
        "timestamp": datetime.now().isoformat()
    })
    MANIFEST.write_text(json.dumps(manifest, indent=2))
    log(f"[RUN:{status}] {name} — {' → '.join(steps)}")
```

### 2. Stage Processor
```python
import subprocess, os
from pathlib import Path

STAGING = Path("pipeline/staging")

STAGE_HANDLERS = {
    "comfyui_output": ["asset-format-bridge", "generate_texture_pack"],
    "2d_to_3d": ["blender-helper", "apply_textures_and_export"],
    "blender_import": ["asset-format-bridge", "obj_to_glb"],
    "godot_models": ["godot-pipeline", "trigger_import_scan"],
}

def process_stage(stage_name: str, files: list[Path] = None):
    """Dispatch appropriate handler for a staging directory."""
    handler_key = STAGE_HANDLERS.get(stage_name)
    if not handler_key:
        log(f"No handler for stage: {stage_name}")
        return
    
    tool, action = handler_key
    log(f"Processing {stage_name} with {tool}::{action}")
    
    for f in (files or list(STAGING.joinpath(stage_name).iterdir())):
        record_asset(f.name, stage_name)
    log(f"Stage '{stage_name}' complete: {len(files or [])} files")
```

### 3. Run Full Pipeline
```python
def run_pipeline(start_stage: str = "comfyui_output"):
    """Execute all pipeline stages in sequence."""
    stages = list(STAGE_HANDLERS.keys())
    start_idx = stages.index(start_stage) if start_stage in stages else 0
    
    run_id = datetime.now().strftime("%Y%m%d_%H%M%S")
    log(f"=== Pipeline run {run_id} ===")
    
    for stage in stages[start_idx:]:
        files = list(STAGING.joinpath(stage).iterdir())
        if files:
            process_stage(stage, files)
        else:
            log(f"Stage '{stage}': no files, skipping")
    
    record_run(f"run_{run_id}", stages[start_idx:], "COMPLETE")
    log(f"=== Pipeline run {run_id} COMPLETE ===")
```

## Environment Variables

| Variable | Default |
|---|---|
| `PIPELINE_ROOT` | `pipeline/staging` |
| `MANIFEST_PATH` | `pipeline/staging/assets_manifest.json` |

## Usage from Hermes

When Hermes detects new files in a staging directory, load this skill and call `process_stage()` with the appropriate stage name.

Example Hermes prompt:
> "Check pipeline/staging/comfyui_output for new renders and advance them through the full pipeline to godot_models."

## Log Analysis
```bash
tail -f pipeline/pipeline.log
grep "\[RUN:FAIL" pipeline/pipeline.log
jq '.assets[] | select(.stage=="godot_models")' pipeline/staging/assets_manifest.json
```
