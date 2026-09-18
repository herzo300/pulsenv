# services/business/blender_generator.py
"""
Blender 3D Object Generator Engine.
Provides Python templates and script runners to orchestrate Blender Foundation's
bpy API headless engine for high-detailed 3D modeling and rendering.
"""
import os
import subprocess
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

ROOT = Path(__file__).resolve().parents[2]


def _find_blender() -> str | None:
    """Blender из env, PATH или типичных каталогов установки (Win/Linux)."""
    env_path = os.getenv("BLENDER_PATH")
    if env_path and os.path.exists(env_path):
        return env_path
    from shutil import which
    found = which("blender")
    if found:
        return found
    base = Path(r"C:\Program Files\Blender Foundation")
    if base.exists():
        versions = sorted(base.glob("Blender */blender.exe"), reverse=True)
        if versions:
            return str(versions[0])
    for cand in ("/usr/bin/blender", "/usr/local/bin/blender", "/snap/bin/blender"):
        if os.path.exists(cand):
            return cand
    return None


BLENDER_PATH = _find_blender()

def generate_blender_script(prompt_type: str, output_gltf_path: str) -> str:
    """Generate python script content to run inside Blender's python environment."""
    
    # Template for a high-detailed street bench with wooden slats and metal supports
    bench_template = f"""import bpy

# 1. Clear default scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# 2. Create Metal Frame Supports (Beveled Cubes)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-1.5, 0, 0.4))
left_support = bpy.context.active_object
left_support.scale = (0.1, 0.8, 0.8)

# Add bevel modifier for smooth realistic metal edges
bevel_mod = left_support.modifiers.new(name="Bevel", type='BEVEL')
bevel_mod.width = 0.02
bevel_mod.segments = 3

# Duplicate for right support (Blender 4.x/5.x: duplicate_move + TRANSFORM_OT_translate удалены)
bpy.ops.object.duplicate()
right_support = bpy.context.active_object
right_support.location = (1.5, 0, 0.4)

# 3. Create Wooden Slats (Seat and Backrest)
slat_count = 5
for i in range(slat_count):
    y_pos = -0.3 + (i * 0.15)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, y_pos, 0.82))
    slat = bpy.context.active_object
    slat.scale = (3.2, 0.1, 0.03)
    
    # Wooden slat bevel
    slat_bevel = slat.modifiers.new(name="SlatBevel", type='BEVEL')
    slat_bevel.width = 0.01
    slat_bevel.segments = 2

# 4. Create and Apply PBR Materials
# Metal Material
metal_mat = bpy.data.materials.new(name="DarkMetal")
metal_mat.use_nodes = True
nodes = metal_mat.node_tree.nodes
principled = nodes.get("Principled BSDF")
principled.inputs['Base Color'].default_value = (0.15, 0.15, 0.15, 1.0)
principled.inputs['Metallic'].default_value = 0.9
principled.inputs['Roughness'].default_value = 0.25

left_support.data.materials.append(metal_mat)
right_support.data.materials.append(metal_mat)

# Export to GLTF
bpy.ops.export_scene.gltf(filepath="{output_gltf_path.replace(chr(92), '/')}")
print("3D Model successfully exported to GLTF.")
"""

    # Template for a high-detailed 3D map dome/marker
    marker_template = f"""import bpy

# 1. Clear scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# 2. Create Futuristic Dome Base
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.6, location=(0, 0, 0))
sphere = bpy.context.active_object

# Apply subdivision surface for organic look
sub_mod = sphere.modifiers.new(name="Subdivision", type='SUBSURF')
sub_mod.levels = 2
bpy.ops.object.shade_smooth()

# 3. Apply Glowing Emission Material (Rich Gold/Neon)
glow_mat = bpy.data.materials.new(name="NeonGlow")
glow_mat.use_nodes = True
nodes = glow_mat.node_tree.nodes
principled = nodes.get("Principled BSDF")
principled.inputs['Base Color'].default_value = (1.0, 0.7, 0.0, 1.0)
principled.inputs['Emission Color'].default_value = (1.0, 0.6, 0.0, 1.0)
principled.inputs['Emission Strength'].default_value = 2.5

sphere.data.materials.append(glow_mat)

# Export to GLTF
bpy.ops.export_scene.gltf(filepath="{output_gltf_path.replace(chr(92), '/')}")
print("3D Marker successfully exported to GLTF.")
"""

    playground_template = f"""import bpy

# 1. Clear scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# 2. Create Sandpit (Cylinder with Boolean cut)
bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=2.5, depth=0.4, location=(0, 0, 0.2))
sandpit_outer = bpy.context.active_object

bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=2.3, depth=0.5, location=(0, 0, 0.3))
sandpit_inner = bpy.context.active_object

# Apply Boolean Difference
bool_mod = sandpit_outer.modifiers.new(name="Cut", type='BOOLEAN')
bool_mod.object = sandpit_inner
bool_mod.operation = 'DIFFERENCE'
bpy.context.view_layer.objects.active = sandpit_outer
bpy.ops.object.modifier_apply(modifier="Cut")
bpy.ops.object.select_all(action='DESELECT')
sandpit_inner.select_set(True)
bpy.ops.object.delete()

# 3. Create Slide (Slanted Cube with Bevel)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 3.0, 1.2))
slide_base = bpy.context.active_object
slide_base.scale = (0.6, 2.2, 0.05)
slide_base.rotation_euler = (0.45, 0, 0) # Slanted

slide_bevel = slide_base.modifiers.new(name="Bevel", type='BEVEL')
slide_bevel.width = 0.02
slide_bevel.segments = 2

# 4. Apply bright plastic materials
plastic_mat = bpy.data.materials.new(name="BrightPlastic")
plastic_mat.use_nodes = True
nodes = plastic_mat.node_tree.nodes
principled = nodes.get("Principled BSDF")
principled.inputs['Base Color'].default_value = (0.0, 0.6, 1.0, 1.0) # Bright Blue
principled.inputs['Roughness'].default_value = 0.15

sandpit_outer.data.materials.append(plastic_mat)
slide_base.data.materials.append(plastic_mat)

# Export to GLTF
bpy.ops.export_scene.gltf(filepath="{output_gltf_path.replace(chr(92), '/')}")
print("3D Playground successfully exported to GLTF.")
"""

    if "bench" in prompt_type.lower():
        return bench_template
    elif "playground" in prompt_type.lower():
        return playground_template
    else:
        return marker_template


def run_blender_modeling(prompt_type: str, output_name: str) -> str:
    """Orchestrate headless Blender instance to execute python 3D script."""

    if not BLENDER_PATH:
        return "Error: Blender executable not found (set BLENDER_PATH env or install Blender)"
        
    public_dir = Path(ROOT) / "public" / "models3d"
    public_dir.mkdir(parents=True, exist_ok=True)
    
    output_gltf = public_dir / f"{output_name}.glb"
    script_path = public_dir / "blender_run_script.py"
    
    # 1. Generate Python Modeling Script
    script_content = generate_blender_script(prompt_type, str(output_gltf))
    with open(script_path, "w", encoding="utf-8") as f:
        f.write(script_content)
        
    # 2. Run Headless Blender
    cmd = [
        BLENDER_PATH,
        "--background",
        "--python",
        str(script_path)
    ]
    
    try:
        logger.info(f"Launching Blender headless modeling command: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
        
        # Cleanup script
        if script_path.exists():
            script_path.unlink()
            
        if result.returncode == 0:
            return f"Success! 3D model generated and saved to: {output_gltf.name}"
        else:
            return f"Blender modeling failed: {result.stderr}\nStdout: {result.stdout}"
            
    except Exception as e:
        return f"Failed to execute Blender process: {e}"
