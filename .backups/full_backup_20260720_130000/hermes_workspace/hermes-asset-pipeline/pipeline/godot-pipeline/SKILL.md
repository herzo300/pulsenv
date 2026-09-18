---
name: godot-pipeline
description: Automate Godot 4.x project operations from Hermes — import assets, run headless exports, execute GDScript pipeline steps, and manage scenes programmatically via the godot-python bindings or CLI.
version: 1.0.0
author: pipeline-hermes
license: MIT
dependencies: []
metadata:
  hermes:
    tags: [Godot, GameEngine, 3D, Pipeline, Export, GDScript]
    related_skills: [comfyui-pipeline, asset-format-bridge, blender-helper]
---

# Godot Pipeline Skill

Drive Godot 4.x as a pipeline step — import assets produced by ComfyUI or Blender, trigger exports, and run scene automation.

## Godot CLI Base

```bash
godot --headless --path /path/to/project
```

Default project path: `/mnt/e/GoDot/getting-started-with-godot-4`

## Core Tools

### 1. Import Assets (Headless)
```bash
# Trigger Godot asset import re-scan
godot --headless --path "$GODOT_PROJECT" --editor --quit 2>/dev/null

# Or via GDScript executed inline:
godot --headless --script '
extends SceneTree
func _init():
    var dir = DirAccess.open("res://")
    dir.make_dir_recursive("res://pipeline_import/")
    print("Import scan complete")
    quit()
' --path "$GODOT_PROJECT"
```

### 2. Run Headless Scene Export
```python
import subprocess, json
from pathlib import Path

GODOT_BIN = os.environ.get("GODOT_BIN", "godot")
PROJECT = os.environ.get("GODOT_PROJECT", "/mnt/e/GoDot/getting-started-with-godot-4")

def godot_export(preset: str = "standalone", output_path: str = None) -> Path:
    """Run Godot headless export."""
    cmd = [
        GODOT_BIN, "--headless",
        "--path", PROJECT,
        "--export-release", preset
    ]
    if output_path:
        cmd.append(output_path)
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    if result.returncode != 0:
        raise RuntimeError(f"Godot export failed: {result.stderr}")
    return Path(output_path or f"{PROJECT}/exports/{preset}")
```

### 3. Execute GDScript Pipeline Step
```python
import subprocess

def run_gdscript(script_path: str, args: list[str] = None) -> str:
    """Execute a GDScript file headless with optional args."""
    cmd = [
        "godot", "--headless",
        "--script", script_path,
        "--path", os.environ["GODOT_PROJECT"]
    ]
    if args:
        cmd += args
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    return result.stdout + result.stderr
```

### 4. Watch Import Folder + Trigger
```python
import watchdog.events, watchdog.observers, time, subprocess, os

class GodotImportHandler(watchdog.events.FileSystemEventHandler):
    def on_created(self, event):
        if event.is_directory:
            return
        ext = Path(event.src_path).suffix.lower()
        if ext in [".png", ".jpg", ".glb", ".gltf", ".fbx"]:
            print(f"New asset detected: {event.src_path}")
            # Trigger Godot import scan
            subprocess.run(
                ["godot", "--headless", "--path", os.environ["GODOT_PROJECT"],
                 "--editor", "--quit"],
                capture_output=True, timeout=60
            )
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `GODOT_BIN` | `godot` | Godot 4.x binary path |
| `GODOT_PROJECT` | `/mnt/e/GoDot/getting-started-with-godot-4` | Godot project root |
| `GODOT_PIPELINE_STAGING` | `pipeline/staging/godot_textures` | Auto-import source dir |

## Pipeline Integration

- **ComfyUI → Godot:** Output images land in `godot_textures/` → Godot imports on next scan
- **Blender → Godot:** GLB/GLTF exported from Blender → `res://models/` → Godot import
- **Godot → ComfyUI:** Capture viewport/render → feed back for AI upscaling or inpainting

## Common Patterns

| Task | Command |
|---|---|
| Quick import scan | `godot --headless --path $GODOT_PROJECT --editor --quit` |
| Export PCK | `godot --headless --path $GODOT_PROJECT --export-release "PCK" out.pck` |
| List scenes | `find $GODOT_PROJECT -name "*.tscn" -o -name "*.escn"` |
| Trigger import of specific file | `godot --headless --script import_one.gd -- path=res://file.png` |
