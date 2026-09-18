"""
City Pulse — 3D Logo Splash
============================
Neon cyan pulse-rings + glassmorphic core, animated beat.
Outputs: logo_city_pulse.png (transparent), logo_city_pulse.mp4 (loop), logo_city_pulse.glb
"""
import bpy
import bmesh
import math
import os
from mathutils import Vector

OUT_DIR = r"C:\Soobshio_project\blender_assets\output"
os.makedirs(OUT_DIR + "/png", exist_ok=True)
os.makedirs(OUT_DIR + "/video", exist_ok=True)
os.makedirs(OUT_DIR + "/glb", exist_ok=True)

# --- Design tokens from design-tokens/colors.json ---
COLOR_BG       = (0.008, 0.024, 0.090, 1.0)   # #020617 background
COLOR_PRIMARY  = (0.000, 0.898, 1.000, 1.0)   # #00E5FF cyan
COLOR_ACCENT   = (0.486, 0.302, 1.000, 1.0)   # #7C4DFF violet
COLOR_GOLD     = (1.000, 0.784, 0.341, 1.0)   # #FFC857
COLOR_GLASS    = (0.047, 0.086, 0.157, 0.45)  # glass surface

# ============================================================
# STEP 1 — Reset scene
# ============================================================
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'Filmic'
scene.view_settings.look = 'Medium High Contrast'

# World — pure dark background (transparent PNG will composite over anything)
world = bpy.data.worlds.new("PulseWorld")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes['Background']
bg.inputs[0].default_value = COLOR_BG
bg.inputs[1].default_value = 0.5  # dim

# ============================================================
# STEP 2 — Helper: create neon emission material
# ============================================================
def make_neon_material(name, color, strength=8.0):
    """Bright neon-emission material via Principled BSDF (Blender 5.x compatible).
    Uses high Emission Strength + slight Transmission for depth."""
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    # Base settings
    bsdf.inputs['Base Color'].default_value = color
    bsdf.inputs['Roughness'].default_value = 0.1
    # Emission (key for neon)
    if 'Emission Color' in bsdf.inputs:
        bsdf.inputs['Emission Color'].default_value = color
        bsdf.inputs['Emission Strength'].default_value = strength
    elif 'Emission' in bsdf.inputs:
        bsdf.inputs['Emission'].default_value = color
        if 'Emission Strength' in bsdf.inputs:
            bsdf.inputs['Emission Strength'].default_value = strength
    # Slight transmission for jewel depth
    if 'Transmission Weight' in bsdf.inputs:
        bsdf.inputs['Transmission Weight'].default_value = 0.3
    elif 'Transmission' in bsdf.inputs:
        bsdf.inputs['Transmission'].default_value = 0.3
    # Subtle clearcoat for highlight
    if 'Coat Weight' in bsdf.inputs:
        bsdf.inputs['Coat Weight'].default_value = 1.0
        bsdf.inputs['Coat Roughness'].default_value = 0.05
    elif 'Clearcoat' in bsdf.inputs:
        bsdf.inputs['Clearcoat'].default_value = 1.0
    return mat

def make_glass_material(name, color, roughness=0.05):
    """Glassmorphism material — semi-transparent glass via Principled BSDF."""
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    bsdf.inputs['Base Color'].default_value = color
    bsdf.inputs['Roughness'].default_value = roughness
    if 'Transmission Weight' in bsdf.inputs:
        bsdf.inputs['Transmission Weight'].default_value = 0.9
    elif 'Transmission' in bsdf.inputs:
        bsdf.inputs['Transmission'].default_value = 0.9
    if 'IOR' in bsdf.inputs:
        bsdf.inputs['IOR'].default_value = 1.40
    if 'Alpha' in bsdf.inputs:
        bsdf.inputs['Alpha'].default_value = color[3] if len(color) > 3 else 0.6
    mat.blend_method = 'BLEND'
    return mat

MAT_CYAN   = make_neon_material("NeonCyan",   COLOR_PRIMARY, strength=10.0)
MAT_VIOLET = make_neon_material("NeonViolet", COLOR_ACCENT,  strength=8.0)
MAT_GOLD   = make_neon_material("NeonGold",   COLOR_GOLD,    strength=6.0)
MAT_GLASS  = make_glass_material("GlassCore", COLOR_GLASS)

# ============================================================
# STEP 3 — Central pulsing core (icosphere with glass + emission)
# ============================================================
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=5, radius=0.6, location=(0,0,0))
core = bpy.context.active_object
core.name = "PulseCore"
core.data.materials.append(MAT_GLASS)

# Inner glow sphere (extra-bright)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=0.45, location=(0,0,0))
inner = bpy.context.active_object
inner.name = "PulseCoreInner"
mat_inner = make_neon_material("CoreGlow", COLOR_PRIMARY, strength=30.0)
inner.data.materials.append(mat_inner)

# ============================================================
# STEP 4 — Three concentric pulse rings (the "city pulse" waves)
# ============================================================
rings = []
for i, (radius, mat, name) in enumerate([
    (1.0,  MAT_CYAN,   "Ring1"),
    (1.6,  MAT_VIOLET, "Ring2"),
    (2.3,  MAT_GOLD,   "Ring3"),
]):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=radius,
        minor_radius=0.04,
        major_segments=96,
        minor_segments=12,
        location=(0, 0, 0),
    )
    ring = bpy.context.active_object
    ring.name = name
    ring.data.materials.append(mat)
    # Tilt each ring differently for 3D depth
    ring.rotation_euler = [math.radians(70 + i*15), math.radians(i*25), 0]
    rings.append(ring)

# ============================================================
# STEP 5 — Vertical "signal bars" around the core (data vibes)
# ============================================================
bars = []
import random
random.seed(42)
for i in range(8):
    angle = i * (2 * math.pi / 8)
    r = 1.9
    x, y = r * math.cos(angle), r * math.sin(angle)
    h = 0.6 + random.random() * 0.8
    bpy.ops.mesh.primitive_cube_add(size=0.12, location=(x, y, h/2 - 0.4))
    bar = bpy.context.active_object
    bar.name = f"SignalBar_{i}"
    bar.scale = (1, 1, h / 0.12)
    mat = MAT_CYAN if i % 2 == 0 else MAT_VIOLET
    bar.data.materials.append(mat)
    bars.append(bar)

# ============================================================
# STEP 6 — Camera + Lights
# ============================================================
bpy.ops.object.camera_add(location=(4.2, -4.2, 3.0), rotation=(math.radians(60), 0, math.radians(45)))
cam = bpy.context.active_object
cam.name = "MainCam"
cam.data.lens = 50
scene.camera = cam

# Key light (cyan rim)
bpy.ops.object.light_add(type='AREA', location=(3, -3, 4))
key = bpy.context.active_object
key.data.energy = 200
key.data.size = 3
key.data.color = COLOR_PRIMARY[:3]
key.rotation_euler = (math.radians(45), math.radians(20), math.radians(45))

# Fill light (violet)
bpy.ops.object.light_add(type='AREA', location=(-3, -1, 2))
fill = bpy.context.active_object
fill.data.energy = 80
fill.data.size = 4
fill.data.color = COLOR_ACCENT[:3]
fill.rotation_euler = (math.radians(60), 0, math.radians(-30))

# Backlight (gold rim)
bpy.ops.object.light_add(type='SPOT', location=(0, 4, 2))
back = bpy.context.active_object
back.data.energy = 150
back.data.spot_size = math.radians(90)
back.data.color = COLOR_GOLD[:3]
back.rotation_euler = (math.radians(110), 0, 0)

# ============================================================
# STEP 7 — Animation: pulse cycle (60 frames, loopable)
# ============================================================
FPS = 30
DURATION = 60  # 2 sec loop
scene.frame_start = 1
scene.frame_end = DURATION
scene.render.fps = FPS

# Animate core scale (pulse beat)
for f in range(1, DURATION + 1):
    t = (f - 1) / DURATION
    # Heart-beat: two pulses per loop
    pulse = 0.5 * (math.sin(t * 4 * math.pi) ** 4) + 0.5
    core.scale = (1 + 0.15 * pulse,) * 3
    core.keyframe_insert('scale', frame=f)
    inner.scale = (1 + 0.25 * pulse,) * 3
    inner.keyframe_insert('scale', frame=f)

# Animate rings: outward expansion + fade via scale (rotation)
for i, ring in enumerate(rings):
    base_radius = float(ring.name[-1] if ring.name[-1].isdigit() else '1')
    phase = i * 0.33
    for f in range(1, DURATION + 1):
        t = (f - 1) / DURATION
        wave = 0.5 * math.sin((t + phase) * 2 * math.pi) + 0.5
        s = 0.9 + 0.25 * wave
        ring.scale = (s, s, s)
        ring.keyframe_insert('scale', frame=f)
        # Rotate each ring continuously
        ring.rotation_euler[2] = t * math.radians(60 + i*40)
        ring.keyframe_insert('rotation_euler', frame=f)

# Animate signal bars: random heights cycling
for i, bar in enumerate(bars):
    for f in range(1, DURATION + 1, 4):  # every 4 frames
        t = (f - 1) / DURATION
        phase = i * 0.2
        h = 0.4 + 0.8 * abs(math.sin(t * 6 * math.pi + phase))
        bar.scale.z = h / 0.12
        bar.keyframe_insert('scale', frame=f)

# Note: Bezier interpolation is the default for new keyframes in Blender 5.x,
# so the loop is already smooth. Skip the fcurves iteration (API changed).

# ============================================================
# STEP 8 — Render single PNG (hero frame at peak pulse)
# ============================================================
scene.frame_set(DURATION // 2)
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.filepath = os.path.join(OUT_DIR, "png", "logo_city_pulse.png")
bpy.ops.render.render(write_still=True)
print(f"[OK] PNG saved: {scene.render.filepath}")

# ============================================================
# STEP 9 — Render MP4 loop
# ============================================================
scene.render.image_settings.file_format = 'FFMPEG'
scene.render.ffmpeg.format = 'MPEG4'
scene.render.ffmpeg.codec = 'H264'
scene.render.ffmpeg.constant_rate_factor = 'MEDIUM'
scene.render.filepath = os.path.join(OUT_DIR, "video", "logo_city_pulse.mp4")
bpy.ops.render.render(animation=True)
print(f"[OK] MP4 saved: {scene.render.filepath}")

# ============================================================
# STEP 10 — Export GLB (for three.js / Flutter)
# ============================================================
# Select all renderable objects
for obj in bpy.data.objects:
    obj.select_set(obj.type in {'MESH'})
bpy.ops.export_scene.gltf(
    filepath=os.path.join(OUT_DIR, "glb", "logo_city_pulse.glb"),
    export_format='GLB',
    export_animations=True,
    export_apply=True,
    use_selection=True,
)
print(f"[OK] GLB saved")

print("\n=== City Pulse 3D Logo: ALL DONE ===")
