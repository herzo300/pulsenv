# hermes-asset-pipeline

**AI-driven asset pipeline orchestrator** — bridges ComfyUI, Blender, and Godot 4.x through a Hermes Agent skill layer. Generates assets with diffusion models, processes them through 3D tools, and delivers production-ready exports via a staged, observable workflow.

---

## Overview

This project provides a Hermes Agent skill suite that automates the full lifecycle of AI-generated 3D assets:

```
ComfyUI (FLUX/Gemma)  →  Asset Format Bridge  →  Blender (texturing/render)  →  Godot (scene import/export)
```

Built for creators and developers who want to embed AI image generation directly into a 3D production workflow, driven by an autonomous agent that learns from your patterns over time.

### Core Capabilities

- **ComfyUI Integration** — Queue prompts, poll completion, fetch outputs programmatically via REST API
- **Blender Headless** — Apply AI textures to meshes, render scenes, export GLB/GLTF without GUI
- **Godot 4.x Pipeline** — Headless scene imports, GLTF processing, PCK/executable export
- **Format Bridge** — Automatic conversion between PNG, WebP, JPG, OBJ, GLB, GLTF
- **Texture Pack Generation** — Diffuse → albedo + normal + roughness from a single ComfyUI output
- **Pipeline Orchestration** — Staged asset flow with manifest logging and failure recovery
- **uv-isolated Python tooling** — Every tool runs in its own virtual environment, no dependency conflicts

---

## Architecture

```
pipeline/
├── staging/
│   ├── comfyui_output/      # Raw AI renders land here
│   ├── 2d_to_3d/            # Texture packs (albedo, normal, roughness)
│   ├── blender_import/      # Meshes + processed textures ready for Blender
│   ├── godot_models/        # GLB/GLTF files for Godot res:// import
│   ├── godot_textures/      # Textures with Godot-native naming
│   ├── exports/             # Final Godot builds
│   └── assets_manifest.json # Pipeline asset log
│
├── skills/
│   ├── comfyui-pipeline/        # ComfyUI API + model management
│   ├── blender-helper/          # Blender headless operations
│   ├── godot-pipeline/          # Godot CLI automation
│   ├── asset-format-bridge/     # Format conversion + texture packs
│   ├── pipeline-orchestrator/   # Stage dispatcher + manifest
│   └── python-tool-builder/     # Scaffold new pipeline tools
│
├── configs/                 # Configuration files
└── lib/                     # Custom Python tools (one venv per tool)
```

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Python | ≥ 3.12 | `python3 --version` |
| uv | ≥ 0.5 | `uv --version` |
| Blender | ≥ 4.0 | [blender.org](https://blender.org) |
| Godot | ≥ 4.3 | [godotengine.org](https://godotengine.org) |
| ComfyUI | latest | [github.com/comfyanonymous/ComfyUI](https://github.com/comfyanonymous/ComfyUI) |
| Hermes Agent | ≥ v0.10 | [github.com/NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) |

---

## Installation

### 1. Clone and Enter Repo

```bash
git clone https://github.com/Limbicnation/hermes-asset-pipeline.git
cd hermes-asset-pipeline
```

### 2. Set Up Python Environment with uv

```bash
# Create virtual environment
uv venv .venv

# Activate (Linux/macOS)
source .venv/bin/activate

# Activate (Windows PowerShell)
# .venv\Scripts\Activate.ps1

# Install dependencies
uv pip install -e ".[dev]"
```

### 3. Verify Installation

```bash
# Test Python environment
python -c "import PIL, cv2, numpy, watchdog, trimesh, pydantic; print('All packages OK')"
```

### 4. Configure Environment Variables

```bash
# ComfyUI
export COMFYUI_HOST="http://127.0.0.1:8188"
export COMFYUI_MODELS="/path/to/ComfyUI/models"
export COMFYUI_OUTPUT="$(pwd)/pipeline/staging/comfyui_output"

# Blender
export BLENDER_BIN="/usr/bin/blender"       # Adjust to your install

# Godot
export GODOT_BIN="/usr/bin/godot"           # Adjust to your install
export GODOT_PROJECT="/path/to/your/project" # Your Godot project root

# Pipeline
export PIPELINE_ROOT="$(pwd)/pipeline/staging"
```

### 5. Point ComfyUI Output to Pipeline

In ComfyUI → Settings → Output Path:
```
/path/to/hermes-asset-pipeline/pipeline/staging/comfyui_output
```

---

## Usage with Hermes Agent

### Load Pipeline Skills

After installing Hermes Agent, copy or link the skills into your Hermes skills directory:

```bash
cp -r pipeline/skills/* ~/.hermes/skills/
```

Or set your skills root in `hermes.yaml`:
```yaml
skills:
  paths:
    - /path/to/hermes-asset-pipeline/pipeline/skills
```

### Example Agent Prompts

**Generate and process a texture:**
> "Generate a biomechanical dragon texture in ComfyUI using FLUX. Once complete, advance it through the full pipeline to Godot and log the result in the manifest."

**Apply texture to existing mesh:**
> "Use blender-helper to apply the latest texture from `pipeline/staging/2d_to_3d/` to the mesh at `blender_import/character_base.glb`, then export as GLB to `godot_models/`."

**Run full pipeline:**
> "Check `comfyui_output/` for new renders and advance all pending assets through the pipeline. Report any failures in `pipeline.log`."

### Running Standalone (without Hermes)

```bash
source .venv/bin/activate

# Watch staging dir and auto-process
python -m pipeline.skills.pipeline_orchestrator.watch

# Run a specific conversion
python -c "
from pipeline.skills.asset_format_bridge import convert_image
convert_image('input.png', 'PNG', size=(2048,2048))
"
```

---

## Pipeline Skills Reference

| Skill | File | Purpose |
|---|---|---|
| `comfyui-pipeline` | `pipeline/skills/comfyui-pipeline/SKILL.md` | Queue ComfyUI prompts via API, fetch outputs, manage models |
| `blender-helper` | `pipeline/skills/blender-helper/SKILL.md` | Headless Blender rendering, texture application, GLTF export |
| `godot-pipeline` | `pipeline/skills/godot-pipeline/SKILL.md` | Headless Godot exports, GLTF scene imports, CLI automation |
| `asset-format-bridge` | `pipeline/skills/asset-format-bridge/SKILL.md` | Format conversion (PNG↔WebP, GLB↔OBJ), texture pack generation, staging |
| `pipeline-orchestrator` | `pipeline/skills/pipeline-orchestrator/SKILL.md` | Asset manifest, stage processing, pipeline state logging |
| `python-tool-builder` | `pipeline/skills/python-tool-builder/SKILL.md` | Scaffold custom Python tools with uv venv discipline |

---

## Recommended Hermes Ecosystem Add-ons

| Add-on | Source | Purpose |
|---|---|---|
| `wondelai/skills` | agentskills.io | 380+ cross-platform agent skills |
| `rtk-hermes` | awesome-hermes-agent | Shell output compression (60–90% token reduction) |
| `mnemo-hermes` | awesome-hermes-agent | Vector-backed semantic memory |
| `hermes-skill-factory` | awesome-hermes-agent | Auto-generate skills from observed workflows |
| `black-forest-labs/skills` | agentskills.io | FLUX-specific generation optimization |

---

## Extending the Pipeline

### Add a New Tool (uv-virtualized)

```bash
cd pipeline/lib
uv init --name my-tool
cd my-tool
uv add pillow numpy
# Implement in src/my_tool/main.py
# Add SKILL.md to pipeline/skills/my-tool/
```

### Register a New Stage

Edit `pipeline/skills/pipeline_orchestrator/STAGE_HANDLERS`:

```python
STAGE_HANDLERS["my_stage"] = ["my-tool", "process"]
```

---

## Development

```bash
# Format code
ruff format .

# Lint
ruff check .

# Type check
mypy pipeline/

# Run tests
pytest
```

---

## License

Apache 2.0 — see [LICENSE](LICENSE).

---

## Contributing

Contributions welcome. Please open an issue first to discuss scope. Follow the existing skill structure (SKILL.md + scripts/ or lib/) and ensure all Python tooling uses the repo's `.venv`.
