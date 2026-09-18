---
name: comfyui-pipeline
description: Execute and manage ComfyUI workflows via API, manage model files, and interface with the image generation pipeline. Enables Hermes to queue prompts, monitor status, and retrieve outputs programmatically.
version: 1.0.0
author: pipeline-hermes
license: MIT
dependencies: [requests, Pillow, watchdog]
metadata:
  hermes:
    tags: [ComfyUI, ImageGeneration, FLUX, AI, Pipeline, API]
    related_skills: [asset-format-bridge, blender-helper, godot-pipeline]
    mcp_servers: []
---

# ComfyUI Pipeline Skill

Interface ComfyUI as a programmable node in the Hermes asset pipeline. Run workflows, manage models, and feed outputs downstream to Blender or Godot.

## ComfyUI API Base

Default: `http://127.0.0.1:8188`
Set `COMFYUI_HOST` env var to override.

## Core Tools

### 1. Queue Prompt
```python
import requests

def queue_comfyui_prompt(prompt_json: dict, workflow_name: str = "pipeline") -> str:
    """Queue a ComfyUI workflow. Returns prompt_id."""
    resp = requests.post(
        f"{COMFYUI_HOST}/api/prompt",
        json={"prompt": prompt_json, "workflow_name": workflow_name},
        timeout=30
    )
    resp.raise_for_status()
    return resp.json()["prompt_id"]
```

### 2. Monitor History
```python
import requests, time

def wait_for_completion(prompt_id: str, timeout: int = 300) -> dict:
    """Poll ComfyUI history until prompt completes."""
    start = time.time()
    while time.time() - start < timeout:
        resp = requests.get(f"{COMFYUI_HOST}/api/history/{prompt_id}", timeout=10)
        history = resp.json()
        if prompt_id in history:
            status = history[prompt_id].get("status", {})
            if status.get("state") == "success":
                return history[prompt_id]
            elif status.get("state") == "failed":
                raise RuntimeError(f"Prompt failed: {status}")
        time.sleep(5)
    raise TimeoutError(f"Prompt {prompt_id} did not complete in {timeout}s")
```

### 3. Get Output Images
```python
import os, shutil, requests
from pathlib import Path

def fetch_output_images(prompt_id: str, output_dir: Path) -> list[Path]:
    """Download all images from a completed ComfyUI run."""
    output_dir.mkdir(parents=True, exist_ok=True)
    resp = requests.get(f"{COMFYUI_HOST}/api/history/{prompt_id}", timeout=10)
    data = resp.json()[prompt_id]
    paths = []
    for node in data.get("outputs", {}).values():
        for item in node.get("images", []) + node.get("ui", {}).get("images", []):
            fname = item.get("filename")
            if fname:
                src = f"{COMFYUI_HOST}/view?filename={fname}&type=output"
                dst = output_dir / fname
                r = requests.get(src, timeout=60)
                dst.write_bytes(r.content)
                paths.append(dst)
    return paths
```

### 4. List Installed Models
```python
import os
from pathlib import Path

def list_models(model_type: str = "checkpoints") -> list[str]:
    """List available ComfyUI model files by type."""
    base = Path(os.environ.get("COMFYUI_MODELS", "/mnt/e/ComfyUI/models"))
    return [p.name for p in (base / model_type).iterdir() if p.is_file()]
```

## Pipeline Integration

- **Output → Blender:** Save images to `pipeline/staging/2d_to_3d/` for projection mapping or texture generation
- **Output → Godot:** Save images to `pipeline/staging/godot_textures/` for Sprite2D/TextureStage use
- **Model management:** Keep FLUX/Gemma models in `models/diffusion/` — reference by filename in workflow JSON

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `COMFYUI_HOST` | `http://127.0.0.1:8188` | ComfyUI API endpoint |
| `COMFYUI_MODELS` | `/mnt/e/ComfyUI/models` | Models root directory |
| `COMFYUI_OUTPUT` | `pipeline/staging/comfyui_output` | Local staging output dir |

## Common Workflow Patterns

### Text-to-Image → Stage for 3D
1. Queue prompt with FLUX model node
2. Wait for completion
3. Fetch output images
4. Copy to `pipeline/staging/2d_to_3d/`
5. Log new asset in `pipeline/assets_manifest.json`

### Upscale → Godot
1. Queue upscale workflow (4x node)
2. Wait for completion
3. Fetch output → `pipeline/staging/godot_textures/`
4. Trigger Godot import scan
