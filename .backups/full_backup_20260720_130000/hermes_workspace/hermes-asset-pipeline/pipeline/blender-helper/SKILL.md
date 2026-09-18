---
name: blender-helper
description: Automate Blender 4.x operations headless from Hermes — render scenes, apply textures from ComfyUI outputs, export GLB/GLTF for Godot, and run batch processing pipelines via Blender's Python API.
version: 1.0.0
author: pipeline-hermes
license: MIT
dependencies: []
metadata:
  hermes:
    tags: [Blender, 3D, Rendering, GLTF, Headless, Python]
    related_skills: [comfyui-pipeline, asset-format-bridge, godot-pipeline]
---

# Blender Helper Skill

Drive Blender headless as a rendering and mesh-processing node in the Hermes pipeline.

## Blender CLI

```bash
blender --background --python $SCRIPT -- $ARGS
```

 Blender executable: `blender` (add to PATH or set `BLENDER_BIN` env var).

## Core Tools

### 1. Apply Texture from ComfyUI Output
```python
# apply_texture.py — run headless: blender --background --python apply_texture.py -- mesh.blend texture.png
import bpy, sys

blend_file = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else ""
texture_file = sys.argv[sys.argv.index("--") + 2] if "--" in sys.argv else ""

if blend_file:
    bpy.ops.wm.open_mainfile(filepath=blend_file)

# Create material with ComfyUI texture
mat = bpy.data.materials.new(name="ComfyUITexture")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
tex_image = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex_image.image = bpy.data.images.load(texture_file)
mat.node_tree.links.new(bsdf.inputs["Base Color"], tex_image.outputs["Color"])

# Assign to selected mesh
if bpy.context.selected_objects:
    obj = bpy.context.selected_objects[0]
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)
```

### 2. Render Scene Headless
```python
# render_scene.py
import bpy, sys, pathlib

scene_file = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else ""
output_path = sys.argv[sys.argv.index("--") + 3] if len(sys.argv) > sys.argv.index("--") + 3 else "/tmp/render"

bpy.ops.wm.open_mainfile(filepath=scene_file)
bpy.ops.render.render()

output = pathlib.Path(output_path)
bpy.data.images["Render Result"].save_render(str(output))
print(f"Rendered: {output}")
```

### 3. GLTF Export for Godot
```python
# export_gltf.py
import bpy, sys

blend_file = sys.argv[sys.argv.index("--") + 1]
output_file = sys.argv[sys.argv.index("--") + 2]

bpy.ops.wm.open_mainfile(filepath=blend_file)

bpy.ops.export_scene.gltf(
    filepath=output_file,
    export_format="GLB",
    use_selection=True,
    export_materials="EXPORT",
    export_draco_meshopt_compression=True,
)
print(f"Exported: {output_file}")
```

### 4. Run Any Blender Python Script Headless
```python
import subprocess, os
from pathlib import Path

BLENDER_BIN = os.environ.get("BLENDER_BIN", "blender")

def blender_run(script: str, blend_file: str = None, args: list = None) -> str:
    """Execute a Blender Python script headless."""
    cmd = [BLENDER_BIN, "--background", "--python", script]
    if blend_file:
        cmd += ["--", blend_file]
    if args:
        cmd += args
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    return result.stdout + result.stderr
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `BLENDER_BIN` | `blender` | Blender executable path |
| `BLENDER_PYTHON` | auto-detected | Python lib path for bpy module |

## Pipeline Integration

- **ComfyUI → Blender:** ComfyUI texture → `apply_texture.py` → textured mesh → GLTF export
- **Blender → Godot:** Blender GLB export → Godot `res://models/` import
- **Blender → ComfyUI:** Rendered mesh view → feed back for AI refinement

## Quick Reference

| Task | Command |
|---|---|
| Apply texture | `blender --background --python apply_texture.py -- scene.blend texture.png` |
| Export GLB | `blender --background --python export_gltf.py -- scene.blend out.glb` |
| Render to PNG | `blender --background --python render.py -- scene.blend /tmp/out.png` |
| Batch process | Loop over files in `pipeline/staging/blender_import/` |
