"""
City Pulse — Premium 3D Smartphone Model
========================================
Realistic Space-Grey metallic smartphone with a detailed triple-camera bump,
side buttons, chrome bezels, and a procedural neon-gradient wallpaper screen.
Outputs: smartphone_render.png, smartphone.blend
"""
import bpy
import math
import os
from mathutils import Vector

OUT_DIR = r"C:\Soobshio_project\blender_assets\output"
os.makedirs(OUT_DIR, exist_ok=True)

# Colors
COLOR_BG       = (0.008, 0.024, 0.090, 1.0)   # #020617 background
COLOR_PRIMARY  = (0.000, 0.898, 1.000, 1.0)   # #00E5FF cyan
COLOR_ACCENT   = (0.486, 0.302, 1.000, 1.0)   # #7C4DFF violet
COLOR_METAL    = (0.100, 0.102, 0.115, 1.0)   # Space Grey metallic
COLOR_CHROME   = (0.850, 0.850, 0.880, 1.0)   # Silver chrome

# ============================================================
# STEP 1 — Reset scene and setup renderer
# ============================================================
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 128  # High-quality render
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x = 1080
scene.render.resolution_y = 1080
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'Filmic'
scene.view_settings.look = 'Medium High Contrast'

# World setting
world = bpy.data.worlds.new("PhoneWorld")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes['Background']
bg.inputs[0].default_value = COLOR_BG
bg.inputs[1].default_value = 0.4

# ============================================================
# STEP 2 — Materials Setup (Space Grey, Chrome, Glass, Wallpaper)
# ============================================================
def make_metal_material(name, color, roughness=0.18):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = color
    bsdf.inputs['Metallic'].default_value = 0.95
    bsdf.inputs['Roughness'].default_value = roughness
    return mat

def make_chrome_material(name):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = COLOR_CHROME
    bsdf.inputs['Metallic'].default_value = 1.0
    bsdf.inputs['Roughness'].default_value = 0.05
    return mat

def make_lens_glass_material(name):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (0.02, 0.02, 0.02, 1.0)
    bsdf.inputs['Roughness'].default_value = 0.02
    if 'Transmission Weight' in bsdf.inputs:
        bsdf.inputs['Transmission Weight'].default_value = 0.98
    elif 'Transmission' in bsdf.inputs:
        bsdf.inputs['Transmission'].default_value = 0.98
    if 'IOR' in bsdf.inputs:
        bsdf.inputs['IOR'].default_value = 1.62
    return mat

def make_flash_material(name):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (1.0, 0.98, 0.90, 1.0)
    if 'Emission Color' in bsdf.inputs:
        bsdf.inputs['Emission Color'].default_value = (1.0, 0.98, 0.90, 1.0)
        bsdf.inputs['Emission Strength'].default_value = 6.0
    elif 'Emission' in bsdf.inputs:
        bsdf.inputs['Emission'].default_value = (1.0, 0.98, 0.90, 1.0)
        if 'Emission Strength' in bsdf.inputs:
            bsdf.inputs['Emission Strength'].default_value = 6.0
    return mat

def make_wallpaper_material(name):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    
    # Create nodes
    out_node = nt.nodes.new('ShaderNodeOutputMaterial')
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    tex_coord = nt.nodes.new('ShaderNodeTexCoord')
    gradient = nt.nodes.new('ShaderNodeTexGradient')
    color_ramp = nt.nodes.new('ShaderNodeValToRGB')
    
    # Configure nodes
    gradient.gradient_type = 'LINEAR'
    
    # Setup Color Ramp (Cyan to Violet)
    color_ramp.color_ramp.elements[0].position = 0.1
    color_ramp.color_ramp.elements[0].color = COLOR_PRIMARY
    color_ramp.color_ramp.elements[1].position = 0.9
    color_ramp.color_ramp.elements[1].color = COLOR_ACCENT
    
    # Screen material settings
    bsdf.inputs['Roughness'].default_value = 0.05
    
    # Links
    nt.links.new(tex_coord.outputs['Generated'], gradient.inputs['Vector'])
    nt.links.new(gradient.outputs['Color'], color_ramp.inputs['Fac'])
    nt.links.new(color_ramp.outputs['Color'], bsdf.inputs['Base Color'])
    
    # Emission for screen glow
    if 'Emission Color' in bsdf.inputs:
        nt.links.new(color_ramp.outputs['Color'], bsdf.inputs['Emission Color'])
        bsdf.inputs['Emission Strength'].default_value = 1.8
    elif 'Emission' in bsdf.inputs:
        nt.links.new(color_ramp.outputs['Color'], bsdf.inputs['Emission'])
        if 'Emission Strength' in bsdf.inputs:
            bsdf.inputs['Emission Strength'].default_value = 1.8
            
    nt.links.new(bsdf.outputs['BSDF'], out_node.inputs['Surface'])
    return mat

MAT_METAL     = make_metal_material("PhoneMetal", COLOR_METAL)
MAT_CHROME    = make_chrome_material("PhoneChrome")
MAT_LENS      = make_lens_glass_material("PhoneLens")
MAT_FLASH     = make_flash_material("PhoneFlash")
MAT_WALLPAPER = make_wallpaper_material("PhoneWallpaper")

# ============================================================
# STEP 3 — Modeling Chassis (Rounded rectangular prism)
# ============================================================
bpy.ops.mesh.primitive_cube_add(size=1.0)
chassis = bpy.context.active_object
chassis.name = "PhoneChassis"
chassis.scale = (0.75, 0.06, 1.55)

# Bevel modifier for rounded edges
bev_mod = chassis.modifiers.new(name="Bevel", type='BEVEL')
bev_mod.width = 0.08
bev_mod.segments = 12

# Smooth shading
chassis.data.materials.append(MAT_METAL)
bpy.ops.object.shade_smooth()

# ============================================================
# STEP 4 — Screen & Side Buttons
# ============================================================
# Screen
bpy.ops.mesh.primitive_cube_add(size=1.0)
screen = bpy.context.active_object
screen.name = "PhoneScreen"
screen.scale = (0.70, 0.005, 1.48)
screen.location = (0.0, 0.0305, 0.0)

scr_bev = screen.modifiers.new(name="Bevel", type='BEVEL')
scr_bev.width = 0.075
scr_bev.segments = 12

screen.data.materials.append(MAT_WALLPAPER)
bpy.ops.object.shade_smooth()

# Buttons Helper
def create_button(name, size, loc):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    btn = bpy.context.active_object
    btn.name = name
    btn.scale = size
    btn.location = loc
    btn.data.materials.append(MAT_METAL)
    # slight bevel
    b = btn.modifiers.new(name="Bevel", type='BEVEL')
    b.width = 0.002
    b.segments = 3
    bpy.ops.object.shade_smooth()
    return btn

# Volume Buttons (Left)
create_button("VolumeUp",   (0.015, 0.015, 0.1),  (-0.38, 0.0, 0.38))
create_button("VolumeDown", (0.015, 0.015, 0.1),  (-0.38, 0.0, 0.24))
# Power Button (Right)
create_button("PowerBtn",   (0.015, 0.015, 0.16), (0.38, 0.0, 0.31))

# ============================================================
# STEP 5 — Camera Bump & Lenses (Premium Triple-Camera Setup)
# ============================================================
# Camera Bump Board
bpy.ops.mesh.primitive_cube_add(size=1.0)
bump = bpy.context.active_object
bump.name = "CameraBump"
bump.scale = (0.26, 0.012, 0.26)
bump.location = (-0.18, -0.036, 0.5)

bump_bev = bump.modifiers.new(name="Bevel", type='BEVEL')
bump_bev.width = 0.04
bump_bev.segments = 8

bump.data.materials.append(MAT_METAL)
bpy.ops.object.shade_smooth()

# Camera Lens Helper
def create_lens(name, loc):
    # Chrome Outer Bezel
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.045,
        depth=0.016,
        vertices=64,
        location=loc
    )
    outer = bpy.context.active_object
    outer.name = f"{name}_Bezel"
    outer.rotation_euler = (math.radians(90), 0, 0)
    outer.data.materials.append(MAT_CHROME)
    bpy.ops.object.shade_smooth()
    
    # Dark reflective sensor glass inside
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.038,
        depth=0.017,
        vertices=64,
        location=(loc[0], loc[1] - 0.001, loc[2])
    )
    inner = bpy.context.active_object
    inner.name = f"{name}_Glass"
    inner.rotation_euler = (math.radians(90), 0, 0)
    inner.data.materials.append(MAT_LENS)
    bpy.ops.object.shade_smooth()

# Lenses in premium triangle configuration
create_lens("CameraMain",  (-0.23, -0.044, 0.56))
create_lens("CameraWide",  (-0.23, -0.044, 0.44))
create_lens("CameraTele",  (-0.13, -0.044, 0.50))

# Flash
bpy.ops.mesh.primitive_cylinder_add(
    radius=0.018,
    depth=0.006,
    vertices=32,
    location=(-0.13, -0.042, 0.58)
)
flash = bpy.context.active_object
flash.name = "CameraFlash"
flash.rotation_euler = (math.radians(90), 0, 0)
flash.data.materials.append(MAT_FLASH)
bpy.ops.object.shade_smooth()

# ============================================================
# STEP 6 — Studio Camera & Three-Point Lighting
# ============================================================
# Camera
bpy.ops.object.camera_add(location=(2.1, -2.8, 1.4))
cam = bpy.context.active_object
cam.name = "MainCam"
cam.data.lens = 55
scene.camera = cam

# Setup track-to constraint to look directly at the phone
track = cam.constraints.new(type='TRACK_TO')
track.target = chassis
track.track_axis = 'TRACK_NEGATIVE_Z'
track.up_axis = 'UP_Y'

# Key Light
bpy.ops.object.light_add(type='AREA', location=(3.0, -3.5, 2.5))
key = bpy.context.active_object
key.data.energy = 1600
key.data.size = 2.5
key.data.color = (0.9, 0.95, 1.0)
key.rotation_euler = (math.radians(50), 0, math.radians(40))

# Fill Light (Warm)
bpy.ops.object.light_add(type='AREA', location=(-3.0, -2.0, 1.5))
fill = bpy.context.active_object
fill.data.energy = 600
fill.data.size = 3.5
fill.data.color = (1.0, 0.92, 0.84)
fill.rotation_euler = (math.radians(65), 0, math.radians(-30))

# Backlight / Rim Light
bpy.ops.object.light_add(type='AREA', location=(-0.8, 3.2, 3.0))
back = bpy.context.active_object
back.data.energy = 1100
back.data.size = 3.0
back.data.color = (1.0, 1.0, 1.0)
back.rotation_euler = (math.radians(40), 0, math.radians(180))

# Reflective Floor Bounce
bpy.ops.object.light_add(type='AREA', location=(0.0, -1.0, -2.2))
floor_bounce = bpy.context.active_object
floor_bounce.data.energy = 400
floor_bounce.data.size = 4.0
floor_bounce.data.color = COLOR_PRIMARY[:3]

# ============================================================
# STEP 7 — Save & Render
# ============================================================
# Save .blend file
blend_file = os.path.join(OUT_DIR, "smartphone.blend")
bpy.ops.wm.save_as_mainfile(filepath=blend_file)
print(f"Blender model saved successfully to: {blend_file}")

# Render PNG image
render_image = os.path.join(OUT_DIR, "smartphone_render.png")
scene.render.filepath = render_image
bpy.ops.render.render(write_still=True)
print(f"Smartphone model rendered successfully to: {render_image}")
