---
name: asset-format-bridge
description: Convert assets between formats critical for the ComfyUI–Blender–Godot pipeline. Handles GLTF/GLB, FBX, OBJ, USD, image formats, and texture pipelines. Ensures assets flow between environments without manual reimport.
version: 1.0.0
author: pipeline-hermes
license: MIT
dependencies: [numpy, Pillow, h5py, trimesh]
metadata:
  hermes:
    tags: [FormatConversion, GLTF, USD, FBX, Pipeline, AssetManagement]
    related_skills: [comfyui-pipeline, blender-helper, godot-pipeline]
---

# Asset Format Bridge Skill

Convert and transport assets between ComfyUI (image/DTX), Blender (mesh/texture), and Godot (GLTF scene) environments.

## Format Priority for This Pipeline

| From | To | Best Format | Notes |
|---|---|---|---|
| ComfyUI (image) | Blender | PNG 2K/4K → UV-project or texture paint | Use as albedo/normal map in Blender |
| ComfyUI (image) | Godot | WebP or PNG in `res://textures/` | Sprite2D or `StandardMaterial3D` texture |
| Blender (mesh) | Godot | GLB (binary GLTF) | Godot 4.x native GLTF import |
| Blender (mesh) | ComfyUI | FBX → USD → image render | Texture projection workflow |
| Godot (scene) | Blender | GLB export via Godot CLI | Scene-to-mesh for re texturing |

## Core Conversion Tools

### Image Format Conversion
```python
from PIL import Image
from pathlib import Path

def convert_image(src: Path, dst_format: str = "PNG", size: tuple[int,int] = None, quality: int = 95) -> Path:
    """Convert image to target format, optional resize."""
    img = Image.open(src)
    if size:
        img = img.resize(size, Image.LANCZOS)
    if img.mode in ("RGBA", "P") and dst_format in ("JPG", "JPEG"):
        img = img.convert("RGB")
    out = src.with_suffix(f".{dst_format.lower()}")
    img.save(out, format=dst_format, quality=quality)
    return out
```

### Texture Pack Generation (ComfyUI → 3D)
```python
from PIL import Image, ImageDraw
from pathlib import Path

def generate_texture_pack(diffuse_path: Path, output_dir: Path = None) -> dict[str, Path]:
    """Generate albedo + normal + roughness texture set from a single diffuse.
    
    For pipeline: ComfyUI output → projection-ready texture set for Blender/Godot.
    """
    output_dir = output_dir or diffuse_path.parent
    diffuse = Image.open(diffuse_path).convert("RGB")
    
    base = diffuse_path.stem
    textures = {}
    
    # Albedo (diffuse as-is)
    albedo = output_dir / f"{base}_albedo.png"
    diffuse.save(albedo)
    textures["albedo"] = albedo
    
    # Normal map approximation (Sobel on diffuse)
    import numpy as np
    arr = np.array(diffuse, dtype=np.float32)
    gray = 0.299*arr[:,:,0] + 0.587*arr[:,:,1] + 0.114*arr[:,:,2]
    
    sobel_x = np.gradient(gray, axis=1)
    sobel_y = np.gradient(gray, axis=0)
    normal_z = np.sqrt(1 - np.clip(sobel_x**2 + sobel_y**2, 0, 1))
    normal = np.stack([sobel_x, sobel_y, normal_z], axis=-1)
    normal = ((normal + 1) / 2 * 255).astype(np.uint8)
    normal_map = Image.fromarray(normal, mode="RGB")
    normal_path = output_dir / f"{base}_normal.png"
    normal_map.save(normal_path)
    textures["normal"] = normal_path
    
    return textures
```

### Mesh Format Conversion (Blender ↔ Godot)
```python
import trimesh, numpy as np
from pathlib import Path

def glb_to_obj(glb_path: Path, output_dir: Path = None) -> Path:
    """Convert GLB to OBJ for Blender compatibility."""
    mesh = trimesh.load(str(glb_path))
    output_dir = output_dir or glb_path.parent
    obj_path = output_dir / f"{glb_path.stem}.obj"
    mesh.export(str(obj_path), file_type="obj")
    return obj_path

def obj_to_glb(obj_path: Path, output_dir: Path = None) -> Path:
    """Convert OBJ to GLB for Godot import."""
    mesh = trimesh.load(str(obj_path))
    output_dir = output_dir or obj_path.parent
    glb_path = output_dir / f"{obj_path.stem}.glb"
    mesh.export(str(glb_path), file_type="glb")
    return glb_path
```

### Batch Staging (moves processed assets to next pipeline stage)
```python
import shutil, json
from pathlib import Path

STAGING = Path("pipeline/staging")
MANIFEST = STAGING / "assets_manifest.json"

def stage_asset(src: Path, stage: str, metadata: dict = None) -> Path:
    """Move asset to next pipeline stage and log in manifest."""
    STAGING.joinpath(stage).mkdir(parents=True, exist_ok=True)
    dst = STAGING / stage / src.name
    shutil.copy2(src, dst)
    
    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {"assets": []}
    manifest["assets"].append({
        "file": dst.name,
        "stage": stage,
        "source": str(src),
        "metadata": metadata or {}
    })
    MANIFEST.write_text(json.dumps(manifest, indent=2))
    return dst
```

## Staging Directory Structure
```
pipeline/staging/
├── comfyui_output/     # Raw ComfyUI renders
├── 2d_to_3d/           # Images prepped for Blender texturing
├── blender_import/      # Meshes/textures ready for Blender
├── godot_textures/      # Textures for Godot res:// import
├── godot_models/        # GLB/GLTF meshes for Godot
└── assets_manifest.json # Pipeline asset log
```

## Quick Reference

| Conversion | Method |
|---|---|
| PNG → WebP | `Image.save(..., format="WEBP")` |
| JPG → PNG | `Image.open().convert("RGB").save("PNG")` |
| GLB → OBJ | `trimesh.load().export(..., file_type="obj")` |
| OBJ → GLB | `trimesh.load().export(..., file_type="glb")` |
| 2D → 3D texture set | `generate_texture_pack()` above |
| Batch stage | `stage_asset(src, "godot_textures")` |
