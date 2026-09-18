"""
City Pulse — Ultimate 16 Category 3D Icon Generator
===================================================
Produces extremely high-end, detailed 3D icons for all 16 civic categories.
Includes microscopic noise bump maps, procedural diagonal hazard stripes,
specular reflection floor catchers, and detailed components (bolts, rivets,
cables, page bookmark ribbons, and adjustable wrench knurls).
Renders using Cycles to transparent 512x512 PNGs.
"""
import bpy
import math
import os

OUT_DIR = r"C:\Soobshio_project\blender_assets\output"
os.makedirs(OUT_DIR, exist_ok=True)

# Shared Design Colors (RGBA)
COLOR_CYAN     = (0.000, 0.898, 1.000, 1.0)
COLOR_VIOLET   = (0.486, 0.302, 1.000, 1.0)
COLOR_ORANGE   = (1.000, 0.350, 0.000, 1.0)
COLOR_COPPER   = (0.800, 0.450, 0.350, 1.0)
COLOR_CHROME   = (0.880, 0.880, 0.900, 1.0)
COLOR_ASPHALT  = (0.060, 0.060, 0.080, 1.0)
COLOR_GREEN    = (0.100, 0.780, 0.250, 1.0)
COLOR_BLUE     = (0.000, 0.400, 0.900, 1.0)
COLOR_ICE      = (0.750, 0.920, 1.000, 0.8)
COLOR_GOLD     = (0.950, 0.750, 0.200, 1.0)

# ============================================================
# Core Render Setup Helper
# ============================================================
def reset_scene_for_icon(engine='CYCLES'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = engine
    
    if engine == 'CYCLES':
        scene.cycles.device = 'CPU'
        scene.cycles.samples = 96  # Higher quality for clean transparency
        scene.cycles.use_denoising = True
        
    scene.render.film_transparent = True
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = 'Filmic'
    scene.view_settings.look = 'Medium High Contrast'
    
    # Transparent world — no background color leaks into render
    world = bpy.data.worlds.new("IconWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    bg.inputs[0].default_value = (0.0, 0.0, 0.0, 1.0)
    bg.inputs[1].default_value = 0.15  # Minimal ambient for reflection falloff
    
    # ── Camera Setup ──
    # Closer isometric view for larger icon fill
    bpy.ops.object.camera_add(location=(1.30, -1.75, 1.25))
    cam = bpy.context.active_object
    cam.name = "IconCam"
    cam.data.lens = 72  # Tighter framing
    scene.camera = cam
    
    # Track to center constraint
    empty = bpy.data.objects.new("Target", None)
    empty.location = (0, 0, 0.22)
    scene.collection.objects.link(empty)
    
    track = cam.constraints.new(type='TRACK_TO')
    track.target = empty
    track.track_axis = 'TRACK_NEGATIVE_Z'
    track.up_axis = 'UP_Y'
    
    # ── Studio Three-Point Lighting (boosted for no-floor renders) ──
    # Key Light (Cool)
    bpy.ops.object.light_add(type='AREA', location=(2.5, -2.8, 2.2))
    key = bpy.context.active_object
    key.data.energy = 1200
    key.data.size = 3.0
    key.data.color = (0.92, 0.96, 1.0)
    
    # Fill Light (Warm)
    bpy.ops.object.light_add(type='AREA', location=(-2.5, -1.8, 1.4))
    fill = bpy.context.active_object
    fill.data.energy = 550
    fill.data.size = 4.0
    fill.data.color = (1.0, 0.94, 0.88)
    
    # Backlight (Rim)
    bpy.ops.object.light_add(type='AREA', location=(-0.5, 2.6, 2.4))
    back = bpy.context.active_object
    back.data.energy = 900
    back.data.size = 3.0
    back.data.color = (1.0, 1.0, 1.0)
    
    # NO StudioFloor — transparent background renders cleanly as PNG alpha


# ============================================================
# Shader & Texture Helpers
# ============================================================
def create_pbr_material(name, base_color, metallic=0.0, roughness=0.2, transmission=0.0, emission_color=None, emission_strength=1.0, clearcoat=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes['Principled BSDF']
    
    bsdf.inputs['Base Color'].default_value = base_color
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    
    if transmission > 0.0:
        if 'Transmission Weight' in bsdf.inputs:
            bsdf.inputs['Transmission Weight'].default_value = transmission
        elif 'Transmission' in bsdf.inputs:
            bsdf.inputs['Transmission'].default_value = transmission
        if 'IOR' in bsdf.inputs:
            bsdf.inputs['IOR'].default_value = 1.48
            
    if clearcoat > 0.0:
        if 'Coat Weight' in bsdf.inputs:
            bsdf.inputs['Coat Weight'].default_value = clearcoat
            bsdf.inputs['Coat Roughness'].default_value = 0.05
        elif 'Clearcoat' in bsdf.inputs:
            bsdf.inputs['Clearcoat'].default_value = clearcoat
            
    if emission_color:
        if 'Emission Color' in bsdf.inputs:
            bsdf.inputs['Emission Color'].default_value = emission_color
            bsdf.inputs['Emission Strength'].default_value = emission_strength
        elif 'Emission' in bsdf.inputs:
            bsdf.inputs['Emission'].default_value = emission_color
            if 'Emission Strength' in bsdf.inputs:
                bsdf.inputs['Emission Strength'].default_value = emission_strength
                
    return mat

def add_noise_bump(mat, scale=150.0, strength=0.08, roughness_min=0.1, roughness_max=0.5):
    """Add fine noise bump to PBR material for realistic light reflections (scratches/dust)."""
    nt = mat.node_tree
    bsdf = nt.nodes.get('Principled BSDF')
    if not bsdf:
        return
    
    # Create noise and bump nodes
    noise = nt.nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = scale
    noise.inputs['Detail'].default_value = 6.0
    
    bump = nt.nodes.new('ShaderNodeBump')
    bump.inputs['Distance'].default_value = 0.05
    bump.inputs['Strength'].default_value = strength
    
    color_ramp = nt.nodes.new('ShaderNodeValToRGB')
    color_ramp.color_ramp.elements[0].position = 0.0
    color_ramp.color_ramp.elements[0].color = (roughness_min, roughness_min, roughness_min, 1.0)
    color_ramp.color_ramp.elements[1].position = 1.0
    color_ramp.color_ramp.elements[1].color = (roughness_max, roughness_max, roughness_max, 1.0)
    
    # Links
    nt.links.new(noise.outputs['Fac'], bump.inputs['Height'])
    nt.links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    nt.links.new(noise.outputs['Fac'], color_ramp.inputs['Fac'])
    nt.links.new(color_ramp.outputs['Color'], bsdf.inputs['Roughness'])

def make_procedural_stripes_material(name, color1, color2):
    """Generates diagonal warning stripe material procedurally."""
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    tex_coord = nt.nodes.new('ShaderNodeTexCoord')
    wave = nt.nodes.new('ShaderNodeTexWave')
    
    wave.wave_type = 'BANDS'
    wave.inputs['Scale'].default_value = 16.0
    wave.inputs['Distortion'].default_value = 0.0
    
    # Map rotated vector for diagonal direction
    mapping = nt.nodes.new('ShaderNodeMapping')
    mapping.inputs['Rotation'].default_value = (0, 0, math.radians(45))
    
    color_ramp = nt.nodes.new('ShaderNodeValToRGB')
    color_ramp.color_ramp.elements[0].position = 0.48
    color_ramp.color_ramp.elements[0].color = color1
    color_ramp.color_ramp.elements[1].position = 0.52
    color_ramp.color_ramp.elements[1].color = color2
    
    # Links
    nt.links.new(tex_coord.outputs['Generated'], mapping.inputs['Vector'])
    nt.links.new(mapping.outputs['Vector'], wave.inputs['Vector'])
    nt.links.new(wave.outputs['Color'], color_ramp.inputs['Fac'])
    nt.links.new(color_ramp.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return mat

# ============================================================
# CATEGORY 1 — ЧП (Emergency)
# Triangle warning with rivets, beacon frame, and glowing exclamation
# ============================================================
def build_emergency_icon():
    reset_scene_for_icon()
    # Hexagonal base plate with noise bump
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.48, depth=0.06, location=(0,0,0.03))
    base = bpy.context.active_object
    base_mat = create_pbr_material("StandMetal", (0.1, 0.1, 0.12, 1.0), metallic=0.9, roughness=0.25)
    add_noise_bump(base_mat, scale=120.0, strength=0.06)
    base.data.materials.append(base_mat)
    bpy.ops.object.shade_smooth()
    
    # 4 small steel rivets around base plate
    for i in range(4):
        angle = i * (math.pi / 2) + math.radians(45)
        rx, ry = 0.38 * math.cos(angle), 0.38 * math.sin(angle)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.02, depth=0.02, location=(rx, ry, 0.065))
        rivet = bpy.context.active_object
        rivet.data.materials.append(create_pbr_material(f"Rivet_{i}", COLOR_CHROME, metallic=0.95, roughness=0.1))
        bpy.ops.object.shade_smooth()
        
    # Warning Triangle Outer Frame (Dark Iron)
    bpy.ops.mesh.primitive_cylinder_add(vertices=3, radius=0.4, depth=0.08, location=(0, 0, 0.36))
    tri = bpy.context.active_object
    tri.rotation_euler = (math.radians(90), 0, 0)
    tri.data.materials.append(base_mat)
    bpy.ops.object.shade_smooth()
    
    # Glowing Orange Core
    bpy.ops.mesh.primitive_cylinder_add(vertices=3, radius=0.32, depth=0.04, location=(0, -0.015, 0.36))
    tri_core = bpy.context.active_object
    tri_core.rotation_euler = (math.radians(90), 0, 0)
    tri_core.data.materials.append(create_pbr_material("WarningOrange", COLOR_ORANGE, emission_color=COLOR_ORANGE, emission_strength=12.0))
    bpy.ops.object.shade_smooth()
    
    # Exclamation mark
    bpy.ops.mesh.primitive_cylinder_add(radius=0.025, depth=0.18, location=(0, -0.04, 0.40))
    mark1 = bpy.context.active_object
    mark1.rotation_euler = (math.radians(90), 0, 0)
    mark1.data.materials.append(create_pbr_material("MarkBlack", (0.01, 0.01, 0.02, 1.0), roughness=0.05))
    bpy.ops.object.shade_smooth()
    
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.026, subdivisions=3, location=(0, -0.04, 0.25))
    mark2 = bpy.context.active_object
    mark2.data.materials.append(mark1.data.materials[0])
    bpy.ops.object.shade_smooth()

# ============================================================
# CATEGORY 2 — ЖКХ (Housing/Utilities)
# Flange bolts, copper pipe and wrench with helical adjustment knurls
# ============================================================
def build_utilities_icon():
    reset_scene_for_icon()
    # Flange pipe base
    bpy.ops.mesh.primitive_cylinder_add(radius=0.15, depth=0.08, location=(0,0,0.04))
    flange = bpy.context.active_object
    flange_mat = create_pbr_material("FlangeSteel", (0.7, 0.72, 0.75, 1.0), metallic=0.98, roughness=0.18)
    flange.data.materials.append(flange_mat)
    bpy.ops.object.shade_smooth()
    
    # 6 bolts on flange rim
    for i in range(6):
        angle = i * (math.pi / 3)
        bx, by = 0.12 * math.cos(angle), 0.12 * math.sin(angle)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.014, depth=0.04, location=(bx, by, 0.08))
        bolt = bpy.context.active_object
        bolt.data.materials.append(flange_mat)
        bpy.ops.object.shade_smooth()
        
    # Copper pipe
    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=0.6, location=(0,0,0.34))
    pipe = bpy.context.active_object
    pipe_mat = create_pbr_material("Copper", COLOR_COPPER, metallic=0.95, roughness=0.2)
    add_noise_bump(pipe_mat, scale=180.0, strength=0.04)
    pipe.data.materials.append(pipe_mat)
    bpy.ops.object.shade_smooth()
    
    # Red Valve Wheel on top
    bpy.ops.mesh.primitive_torus_add(major_radius=0.22, minor_radius=0.038, location=(0,0,0.64))
    valve = bpy.context.active_object
    valve.data.materials.append(create_pbr_material("ValveRed", (0.9, 0.05, 0.1, 1.0), metallic=0.2, roughness=0.15, clearcoat=0.8))
    bpy.ops.object.shade_smooth()
    
    # Spokes for the valve wheel (3 cylinders)
    for i in range(3):
        angle = i * math.radians(120)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.015, depth=0.44, location=(0, 0, 0.64))
        spoke = bpy.context.active_object
        spoke.rotation_euler = (0, math.radians(90), angle)
        spoke.data.materials.append(flange_mat)
        bpy.ops.object.shade_smooth()
        
    # Wrench with adjust knurls
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    wrench = bpy.context.active_object
    wrench.scale = (0.045, 0.026, 0.62)
    wrench.location = (0.16, -0.12, 0.28)
    wrench.rotation_euler = (math.radians(20), math.radians(18), math.radians(-25))
    wrench.data.materials.append(flange_mat)
    
    b_mod = wrench.modifiers.new(name="Bevel", type='BEVEL')
    b_mod.width = 0.006
    b_mod.segments = 3
    bpy.ops.object.shade_smooth()
    
    # Small adjusting knurled cylinder on wrench
    bpy.ops.mesh.primitive_cylinder_add(radius=0.024, depth=0.06, location=(0.14, -0.15, 0.44))
    knurl = bpy.context.active_object
    knurl.rotation_euler = (math.radians(20), math.radians(18), math.radians(-25))
    knurl_mat = create_pbr_material("KnurlBrass", COLOR_GOLD, metallic=0.9, roughness=0.1)
    add_noise_bump(knurl_mat, scale=350.0, strength=0.2)  # high micro-bumps
    knurl.data.materials.append(knurl_mat)
    bpy.ops.object.shade_smooth()

# ============================================================
# CATEGORY 3 — Дороги (Roads)
# Procedural striped warning barrier, highway block, and traffic cone
# ============================================================
def build_roads_icon():
    reset_scene_for_icon()
    # Highway asphalt block
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    road = bpy.context.active_object
    road.scale = (0.85, 0.85, 0.06)
    road.location = (0, 0, 0.03)
    road_mat = create_pbr_material("Asphalt", COLOR_ASPHALT, roughness=0.85)
    add_noise_bump(road_mat, scale=240.0, strength=0.12)  # rough asphalt
    road.data.materials.append(road_mat)
    
    b_mod = road.modifiers.new(name="Bevel", type='BEVEL')
    b_mod.width = 0.008
    b_mod.segments = 4
    bpy.ops.object.shade_smooth()
    
    # Glowing Road Stripes
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    stripe1 = bpy.context.active_object
    stripe1.scale = (0.06, 0.36, 0.002)
    stripe1.location = (0, 0.2, 0.061)
    stripe1.data.materials.append(create_pbr_material("NeonStripe", COLOR_CYAN, emission_color=COLOR_CYAN, emission_strength=6.0))
    
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    stripe2 = bpy.context.active_object
    stripe2.scale = (0.06, 0.36, 0.002)
    stripe2.location = (0, -0.2, 0.061)
    stripe2.data.materials.append(stripe1.data.materials[0])
    
    # Procedural striped barrier board
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    barrier = bpy.context.active_object
    barrier.scale = (0.04, 0.72, 0.08)
    barrier.location = (-0.36, 0, 0.10)
    barrier.data.materials.append(make_procedural_stripes_material("BarrierStripes", COLOR_GOLD, (0.02, 0.02, 0.02, 1.0)))
    bpy.ops.object.shade_smooth()
    
    # Traffic Cone
    bpy.ops.mesh.primitive_cone_add(radius1=0.10, radius2=0.015, depth=0.34, location=(0.24, -0.18, 0.23))
    cone = bpy.context.active_object
    cone.data.materials.append(create_pbr_material("ConeOrange", COLOR_ORANGE, emission_color=COLOR_ORANGE, emission_strength=5.0))
    bpy.ops.object.shade_smooth()
    
    # Cone white strip
    bpy.ops.mesh.primitive_cylinder_add(radius=0.064, depth=0.08, location=(0.24, -0.18, 0.20))
    strip = bpy.context.active_object
    strip.data.materials.append(create_pbr_material("ConeWhite", (0.9, 0.9, 0.92, 1.0), roughness=0.4))
    bpy.ops.object.shade_smooth()

# ============================================================
# CATEGORY 4 — Освещение (Lighting)
# Arched post casting volumetric-like light on brick pavement tiles
# ============================================================
def build_lighting_icon():
    reset_scene_for_icon()
    # Pavement tile base with brick bump pattern
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    tile = bpy.context.active_object
    tile.scale = (0.75, 0.75, 0.04)
    tile.location = (0, 0, 0.02)
    tile_mat = create_pbr_material("BaseTile", (0.18, 0.18, 0.2, 1.0), roughness=0.6)
    add_noise_bump(tile_mat, scale=250.0, strength=0.15)
    tile.data.materials.append(tile_mat)
    bpy.ops.object.shade_smooth()
    
    # Sleek curved light post
    bpy.ops.mesh.primitive_cylinder_add(radius=0.028, depth=0.88, location=(-0.25, 0.25, 0.46))
    pole = bpy.context.active_object
    pole.data.materials.append(create_pbr_material("SleekIron", (0.08, 0.08, 0.1, 1.0), metallic=0.92, roughness=0.22))
    bpy.ops.object.shade_smooth()
    
    # Lamp head casing
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    head = bpy.context.active_object
    head.scale = (0.34, 0.12, 0.06)
    head.location = (0.0, 0.12, 0.88)
    head.rotation_euler = (0, math.radians(-12), 0)
    head.data.materials.append(pole.data.materials[0])
    
    h_mod = head.modifiers.new(name="Bevel", type='BEVEL')
    h_mod.width = 0.012
    h_mod.segments = 4
    bpy.ops.object.shade_smooth()
    
    # Bright LED lens
    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=0.02, location=(0.04, 0.12, 0.86))
    led = bpy.context.active_object
    led.rotation_euler = (0, math.radians(-12), 0)
    led.data.materials.append(create_pbr_material("LEDNeon", (1.0, 0.85, 0.40, 1.0), emission_color=(1.0, 0.85, 0.40, 1.0), emission_strength=25.0))
    bpy.ops.object.shade_smooth()
    
    # Glowing Light Cone
    bpy.ops.mesh.primitive_cone_add(radius1=0.06, radius2=0.52, depth=0.80, location=(0.14, 0.10, 0.44))
    cone = bpy.context.active_object
    cone.rotation_euler = (0, math.radians(-12), 0)
    cone.data.materials.append(create_pbr_material("LightVolume", (1.0, 0.9, 0.5, 0.08), roughness=0.05, transmission=0.98))
    bpy.ops.object.shade_smooth()

# ============================================================
# CATEGORY 5 — Экология (Ecology)
# Glass sphere bulb filled with dirt, and a leaf sprout with veins
# ============================================================
def build_ecology_icon():
    reset_scene_for_icon()
    # Glass globe
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.38, subdivisions=5, location=(0,0,0.28))
    globe = bpy.context.active_object
    globe.data.materials.append(create_pbr_material("EcoGlobe", (0.35, 0.8, 1.0, 0.18), roughness=0.05, transmission=0.96))
    bpy.ops.object.shade_smooth()
    
    # Soil level inside
    bpy.ops.mesh.primitive_cylinder_add(radius=0.32, depth=0.04, location=(0,0,0.12))
    soil = bpy.context.active_object
    soil.data.materials.append(create_pbr_material("EcoSoil", (0.16, 0.11, 0.08, 1.0), roughness=0.85))
    bpy.ops.object.shade_smooth()
    
    # Leaf Stem
    bpy.ops.mesh.primitive_cylinder_add(radius=0.015, depth=0.36, location=(0, 0, 0.32))
    stem = bpy.context.active_object
    stem.rotation_euler = (0, math.radians(16), 0)
    stem.data.materials.append(create_pbr_material("StemGreen", COLOR_GREEN, roughness=0.25))
    bpy.ops.object.shade_smooth()
    
    # Leaves with micro-vein noise bumps
    # Leaf 1 (Large)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.18, subdivisions=4, location=(0.06, 0, 0.44))
    leaf1 = bpy.context.active_object
    leaf1.scale = (0.18, 1.0, 0.02)
    leaf1.rotation_euler = (math.radians(-25), math.radians(28), math.radians(45))
    leaf1_mat = create_pbr_material("LeafMat1", COLOR_GREEN, roughness=0.2, clearcoat=0.6, emission_color=COLOR_GREEN, emission_strength=1.5)
    add_noise_bump(leaf1_mat, scale=280.0, strength=0.15)  # fine leaf veins
    leaf1.data.materials.append(leaf1_mat)
    bpy.ops.object.shade_smooth()
    
    # Leaf 2 (Small)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.12, subdivisions=4, location=(-0.05, 0.02, 0.34))
    leaf2 = bpy.context.active_object
    leaf2.scale = (0.18, 1.0, 0.02)
    leaf2.rotation_euler = (math.radians(22), math.radians(-32), math.radians(-40))
    leaf2.data.materials.append(leaf1_mat)
    bpy.ops.object.shade_smooth()

# ============================================================
# CATEGORY 6 — Транспорт (Transport)
# High-speed train with detailed cabin windshield & neon side-rails
# ============================================================
def build_transport_icon():
    reset_scene_for_icon()
    # Maglev track base
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    track = bpy.context.active_object
    track.scale = (0.38, 0.85, 0.06)
    track.location = (0, 0, 0.03)
    track.data.materials.append(create_pbr_material("TrackGrey", (0.24, 0.25, 0.28, 1.0), roughness=0.6))
    bpy.ops.object.shade_smooth()
    
    # Glowing side rails
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        rail = bpy.context.active_object
        rail.scale = (0.02, 0.86, 0.02)
        rail.location = (side * 0.18, 0, 0.07)
        rail.data.materials.append(create_pbr_material("RailNeon", COLOR_CYAN, emission_color=COLOR_CYAN, emission_strength=8.0))
        bpy.ops.object.shade_smooth()
        
    # High-Speed Train Body
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    train = bpy.context.active_object
    train.scale = (0.28, 0.72, 0.30)
    train.location = (0, 0.02, 0.23)
    train_mat = create_pbr_material("TrainMetallic", COLOR_BLUE, metallic=0.92, roughness=0.14, clearcoat=0.9)
    add_noise_bump(train_mat, scale=200.0, strength=0.03)
    train.data.materials.append(train_mat)
    
    t_mod = train.modifiers.new(name="Bevel", type='BEVEL')
    t_mod.width = 0.05
    t_mod.segments = 10
    bpy.ops.object.shade_smooth()
    
    # Windshield
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    glass = bpy.context.active_object
    glass.scale = (0.29, 0.18, 0.14)
    glass.location = (0, -0.28, 0.29)
    glass.data.materials.append(create_pbr_material("WindshieldGlass", (0.06, 0.06, 0.08, 1.0), roughness=0.02, transmission=0.95))
    
    g_mod = glass.modifiers.new(name="Bevel", type='BEVEL')
    g_mod.width = 0.02
    g_mod.segments = 4
    bpy.ops.object.shade_smooth()
    
    # Headlights
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.024, depth=0.01, location=(side * 0.09, -0.34, 0.14))
        light = bpy.context.active_object
        light.rotation_euler = (math.radians(90), 0, 0)
        light.data.materials.append(create_pbr_material("Headlight", (1.0, 1.0, 0.9, 1.0), emission_color=(1.0, 1.0, 0.9, 1.0), emission_strength=12.0))
        bpy.ops.object.shade_smooth()

# ============================================================
# CATEGORY 7 — Снег/Наледь (Snow/Ice)
# Intricate geometric snowflake with internal voronoi cracks
# ============================================================
def build_snow_icon():
    reset_scene_for_icon()
    # Ice material with cell-bump texture for internal cracks
    mat_ice = create_pbr_material("CrystalIce", COLOR_ICE, roughness=0.08, transmission=0.96)
    add_noise_bump(mat_ice, scale=120.0, strength=0.2, roughness_min=0.06, roughness_max=0.2)  # voronoi crack effect
    
    # Hexagonal core
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.12, depth=0.06, location=(0,0,0.30))
    core = bpy.context.active_object
    core.rotation_euler = (math.radians(90), 0, 0)
    core.data.materials.append(mat_ice)
    bpy.ops.object.shade_smooth()
    
    # Central glowing core
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.06, subdivisions=3, location=(0,0,0.30))
    glow_core = bpy.context.active_object
    glow_core.data.materials.append(create_pbr_material("CoreNeon", COLOR_CYAN, emission_color=COLOR_CYAN, emission_strength=10.0))
    bpy.ops.object.shade_smooth()
    
    # 6 Main Branches
    for i in range(6):
        angle = i * math.radians(60)
        x = 0.24 * math.cos(angle)
        z = 0.30 + 0.24 * math.sin(angle)
        
        bpy.ops.mesh.primitive_cylinder_add(radius=0.022, depth=0.48, location=(x, 0, z))
        arm = bpy.context.active_object
        arm.rotation_euler = (math.radians(90), 0, angle + math.radians(90))
        arm.data.materials.append(mat_ice)
        bpy.ops.object.shade_smooth()
        
        # Secondary Needles
        for d in [0.14, 0.26]:
            for side in [-1, 1]:
                nx = (d * math.cos(angle)) + (0.08 * math.cos(angle + side * math.radians(60)))
                nz = 0.30 + (d * math.sin(angle)) + (0.08 * math.sin(angle + side * math.radians(60)))
                
                bpy.ops.mesh.primitive_cylinder_add(radius=0.014, depth=0.16, location=(nx, 0, nz))
                needle = bpy.context.active_object
                needle.rotation_euler = (math.radians(90), 0, angle + side * math.radians(35) + math.radians(90))
                needle.data.materials.append(mat_ice)
                bpy.ops.object.shade_smooth()

# ============================================================
# CATEGORY 8 — Безопасность (Security)
# Layered shield with carbon-black core, gold star & border rivets
# ============================================================
def build_security_icon():
    reset_scene_for_icon()
    # Outer Steel Frame (Pentagon)
    bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=0.44, depth=0.06, location=(0, 0, 0.32))
    shield_outer = bpy.context.active_object
    shield_outer.rotation_euler = (math.radians(90), 0, math.radians(180))
    shield_outer.data.materials.append(create_pbr_material("ShieldSteel", COLOR_CHROME, metallic=1.0, roughness=0.06, clearcoat=0.9))
    
    b_mod = shield_outer.modifiers.new(name="Bevel", type='BEVEL')
    b_mod.width = 0.025
    b_mod.segments = 6
    bpy.ops.object.shade_smooth()
    
    # 10 small steel rivets along the shield border
    for i in range(10):
        angle = i * (2 * math.pi / 10)
        sx, sz = 0.41 * math.cos(angle), 0.32 + 0.41 * math.sin(angle)
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.015, subdivisions=2, location=(sx, -0.03, sz))
        rivet = bpy.context.active_object
        rivet.data.materials.append(shield_outer.data.materials[0])
        bpy.ops.object.shade_smooth()
        
    # Inner Carbon-Fiber Plate
    bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=0.38, depth=0.07, location=(0, -0.005, 0.32))
    shield_inner = bpy.context.active_object
    shield_inner.rotation_euler = (math.radians(90), 0, math.radians(180))
    shield_inner_mat = create_pbr_material("ShieldCarbon", (0.05, 0.05, 0.06, 1.0), roughness=0.45)
    add_noise_bump(shield_inner_mat, scale=320.0, strength=0.2)  # carbon texture
    shield_inner.data.materials.append(shield_inner_mat)
    
    b_mod2 = shield_inner.modifiers.new(name="Bevel", type='BEVEL')
    b_mod2.width = 0.01
    b_mod2.segments = 3
    bpy.ops.object.shade_smooth()
    
    # Gold Star
    bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.18, radius2=0.0, depth=0.06, location=(0, -0.046, 0.32))
    star = bpy.context.active_object
    star.rotation_euler = (math.radians(90), 0, math.radians(180))
    star.data.materials.append(create_pbr_material("StarGold", COLOR_GOLD, metallic=0.98, roughness=0.1, clearcoat=1.0, emission_color=COLOR_GOLD, emission_strength=1.5))
    bpy.ops.object.shade_smooth()

# ============================================================
# CATEGORY 9 — Медицина (Medicine)
# Medicine capsule (red/white) wrapped with detailed stethoscope tube
# ============================================================
def build_medicine_icon():
    reset_scene_for_icon()
    # Capsule Red Half
    bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=0.25, location=(-0.12, 0.06, 0.28))
    cap_red = bpy.context.active_object
    cap_red.rotation_euler = (0, math.radians(45), math.radians(35))
    cap_red.data.materials.append(create_pbr_material("CapRed", (0.9, 0.02, 0.05, 1.0), roughness=0.1, clearcoat=0.9))
    bpy.ops.object.shade_smooth()
    
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.12, subdivisions=3, location=(-0.21, 0.12, 0.40))
    cap_red_end = bpy.context.active_object
    cap_red_end.data.materials.append(cap_red.data.materials[0])
    bpy.ops.object.shade_smooth()
    
    # Capsule White Half
    bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=0.25, location=(0.04, -0.06, 0.16))
    cap_white = bpy.context.active_object
    cap_white.rotation_euler = (0, math.radians(45), math.radians(35))
    cap_white.data.materials.append(create_pbr_material("CapWhite", (0.95, 0.95, 0.96, 1.0), roughness=0.1, clearcoat=0.9))
    bpy.ops.object.shade_smooth()
    
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.12, subdivisions=3, location=(0.13, -0.12, 0.04))
    cap_white_end = bpy.context.active_object
    cap_white_end.data.materials.append(cap_white.data.materials[0])
    bpy.ops.object.shade_smooth()
    
    # Stethoscope Tube Wrapping (torus segments simulating a cord wrap)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.18, minor_radius=0.015, location=(-0.04, 0.0, 0.22))
    tube1 = bpy.context.active_object
    tube1.rotation_euler = (math.radians(35), math.radians(45), 0)
    tube1.data.materials.append(create_pbr_material("TubeGrey", (0.2, 0.2, 0.22, 1.0), roughness=0.3))
    bpy.ops.object.shade_smooth()
    
    # Red cross
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    vbar = bpy.context.active_object
    vbar.scale = (0.12, 0.08, 0.48)
    vbar.location = (0.14, 0.12, 0.38)
    vbar.data.materials.append(create_pbr_material("MedCrossRed", (1.0, 0.02, 0.05, 1.0), emission_color=(1.0, 0.02, 0.05, 1.0), emission_strength=7.0))
    bpy.ops.object.shade_smooth()
    
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    hbar = bpy.context.active_object
    hbar.scale = (0.48, 0.08, 0.12)
    hbar.location = (0.14, 0.12, 0.38)
    hbar.data.materials.append(vbar.data.materials[0])
    bpy.ops.object.shade_smooth()

# ============================================================
# CATEGORY 10 — Образование (Education)
# Cap, tassel, leather book, and a red fabric bookmark ribbon
# ============================================================
def build_education_icon():
    reset_scene_for_icon()
    # Book Cover
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    book = bpy.context.active_object
    book.scale = (0.64, 0.48, 0.12)
    book.location = (0, 0, 0.06)
    book_mat = create_pbr_material("LeatherCover", (0.12, 0.06, 0.04, 1.0), roughness=0.65)
    add_noise_bump(book_mat, scale=300.0, strength=0.15)  # leather texture
    book.data.materials.append(book_mat)
    
    b_mod = book.modifiers.new(name="Bevel", type='BEVEL')
    b_mod.width = 0.015
    b_mod.segments = 3
    bpy.ops.object.shade_smooth()
    
    # Book pages
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    pages = bpy.context.active_object
    pages.scale = (0.60, 0.45, 0.09)
    pages.location = (0.01, -0.01, 0.06)
    pages_mat = create_pbr_material("BookPages", (0.9, 0.88, 0.8, 1.0), roughness=0.55)
    add_noise_bump(pages_mat, scale=400.0, strength=0.08)  # page ridges
    pages.data.materials.append(pages_mat)
    bpy.ops.object.shade_smooth()
    
    # Red fabric bookmark ribbon hanging out of the pages block
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    bookmark = bpy.context.active_object
    bookmark.scale = (0.08, 0.16, 0.01)
    bookmark.location = (0.18, -0.25, 0.05)
    bookmark.rotation_euler = (math.radians(10), 0, 0)
    bookmark.data.materials.append(create_pbr_material("BookmarkRed", (0.8, 0.02, 0.04, 1.0), roughness=0.5))
    bpy.ops.object.shade_smooth()
    
    # Academic Cap Board
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    board = bpy.context.active_object
    board.scale = (0.54, 0.54, 0.024)
    board.location = (0.04, -0.04, 0.30)
    board.rotation_euler = (math.radians(12), 0, math.radians(35))
    board.data.materials.append(create_pbr_material("CapDark", (0.05, 0.07, 0.16, 1.0), roughness=0.4))
    
    b_mod2 = board.modifiers.new(name="Bevel", type='BEVEL')
    b_mod2.width = 0.008
    b_mod2.segments = 3
    bpy.ops.object.shade_smooth()
    
    # Skull cap base
    bpy.ops.mesh.primitive_cylinder_add(radius=0.16, depth=0.12, location=(0.06, -0.06, 0.20))
    cap_base = bpy.context.active_object
    cap_base.rotation_euler = (math.radians(12), 0, math.radians(35))
    cap_base.data.materials.append(board.data.materials[0])
    bpy.ops.object.shade_smooth()
    
    # Golden Tassel
    bpy.ops.mesh.primitive_cylinder_add(radius=0.007, depth=0.26, location=(0.20, -0.22, 0.21))
    string = bpy.context.active_object
    string.rotation_euler = (math.radians(35), math.radians(22), 0)
    string.data.materials.append(create_pbr_material("TasselGold", COLOR_GOLD, metallic=0.9, roughness=0.2))
    bpy.ops.object.shade_smooth()

# ============================================================
# CATEGORY 11 — Парковки (Parking)
# Sign post, Letter P, and parking meter with a glowing digital screen
# ============================================================
def build_parking_icon():
    reset_scene_for_icon()
    # Asphalt surface plate
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    plate = bpy.context.active_object
    plate.scale = (0.75, 0.75, 0.04)
    plate.location = (0, 0, 0.02)
    plate_mat = create_pbr_material("AsphaltBase", COLOR_ASPHALT, roughness=0.8)
    add_noise_bump(plate_mat, scale=240.0, strength=0.1)
    plate.data.materials.append(plate_mat)
    bpy.ops.object.shade_smooth()
    
    # Post
    bpy.ops.mesh.primitive_cylinder_add(radius=0.022, depth=0.74, location=(-0.16, 0, 0.39))
    post = bpy.context.active_object
    post.data.materials.append(create_pbr_material("PostSteel", (0.35, 0.36, 0.38, 1.0), metallic=0.95, roughness=0.18))
    bpy.ops.object.shade_smooth()
    
    # Blue sign board
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    board = bpy.context.active_object
    board.scale = (0.44, 0.03, 0.44)
    board.location = (0.02, 0.02, 0.58)
    board.data.materials.append(create_pbr_material("SignBlue", (0.0, 0.32, 0.85, 1.0), roughness=0.12, clearcoat=0.6))
    
    b_mod = board.modifiers.new(name="Bevel", type='BEVEL')
    b_mod.width = 0.038
    b_mod.segments = 4
    bpy.ops.object.shade_smooth()
    
    # Letter P
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    stem = bpy.context.active_object
    stem.scale = (0.044, 0.012, 0.24)
    stem.location = (-0.05, 0.04, 0.56)
    stem.data.materials.append(create_pbr_material("WhiteText", (0.95, 0.95, 0.96, 1.0), roughness=0.2))
    bpy.ops.object.shade_smooth()
    
    bpy.ops.mesh.primitive_torus_add(major_radius=0.075, minor_radius=0.02, location=(-0.01, 0.04, 0.62))
    loop = bpy.context.active_object
    loop.rotation_euler = (math.radians(90), 0, 0)
    loop.data.materials.append(stem.data.materials[0])
    bpy.ops.object.shade_smooth()
    
    # Parking Meter with screen next to the signpost
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    meter = bpy.context.active_object
    meter.scale = (0.08, 0.08, 0.24)
    meter.location = (0.16, 0.12, 0.22)
    meter.data.materials.append(create_pbr_material("MeterBody", (0.1, 0.12, 0.15, 1.0), metallic=0.9, roughness=0.2))
    bpy.ops.object.shade_smooth()
    
    # Digital screen on meter
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    screen = bpy.context.active_object
    screen.scale = (0.002, 0.06, 0.06)
    screen.location = (0.12, 0.12, 0.26)
    screen.data.materials.append(create_pbr_material("MeterScreen", COLOR_CYAN, emission_color=COLOR_CYAN, emission_strength=4.0))
    bpy.ops.object.shade_smooth()
    
    # Yellow stripe
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    bay = bpy.context.active_object
    bay.scale = (0.06, 0.62, 0.002)
    bay.location = (0.24, -0.06, 0.042)
    bay.data.materials.append(create_pbr_material("StripeYellow", COLOR_GOLD, emission_color=COLOR_GOLD, emission_strength=5.0))
    bpy.ops.object.shade_smooth()

# ============================================================
# CATEGORY 12 — Строительство (Construction)
# Yellow safety helmet resting on structural I-beam under a steel crane hook
# ============================================================
def build_construction_icon():
    reset_scene_for_icon()
    # Structural Steel I-Beam
    # Central web
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    web = bpy.context.active_object
    web.scale = (0.04, 0.85, 0.16)
    web.location = (0, 0, 0.12)
    web.data.materials.append(create_pbr_material("RedIronBeam", (0.75, 0.22, 0.16, 1.0), metallic=0.8, roughness=0.3))
    bpy.ops.object.shade_smooth()
    
    # Top flange
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    top_f = bpy.context.active_object
    top_f.scale = (0.24, 0.85, 0.03)
    top_f.location = (0, 0, 0.20)
    top_f.data.materials.append(web.data.materials[0])
    bpy.ops.object.shade_smooth()
    
    # Bottom flange
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    bot_f = bpy.context.active_object
    bot_f.scale = (0.24, 0.85, 0.03)
    bot_f.location = (0, 0, 0.04)
    bot_f.data.materials.append(web.data.materials[0])
    bpy.ops.object.shade_smooth()
    
    # Yellow Safety Helmet
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.28, subdivisions=5, location=(0,0,0.38))
    helmet = bpy.context.active_object
    helmet.scale = (1.0, 1.0, 0.78)
    helmet.data.materials.append(create_pbr_material("HelmetYellow", (1.0, 0.68, 0.0, 1.0), roughness=0.12, clearcoat=0.6))
    bpy.ops.object.shade_smooth()
    
    # Helmet Brim
    bpy.ops.mesh.primitive_cylinder_add(radius=0.34, depth=0.024, location=(0,0,0.28))
    brim = bpy.context.active_object
    brim.scale = (1.0, 1.15, 1.0)
    brim.data.materials.append(helmet.data.materials[0])
    bpy.ops.object.shade_smooth()
    
    # Steel Crane Hook hanging from above
    # Torus segment for the hook curve
    bpy.ops.mesh.primitive_torus_add(major_radius=0.10, minor_radius=0.025, location=(0, -0.22, 0.62))
    hook_curve = bpy.context.active_object
    hook_curve.rotation_euler = (0, math.radians(90), 0)
    hook_curve.data.materials.append(create_pbr_material("HookSteel", COLOR_CHROME, metallic=1.0, roughness=0.15))
    bpy.ops.object.shade_smooth()
    
    # Cable cylinder
    bpy.ops.mesh.primitive_cylinder_add(radius=0.012, depth=0.42, location=(0, -0.22, 0.83))
    cable = bpy.context.active_object
    cable.data.materials.append(hook_curve.data.materials[0])
    bpy.ops.object.shade_smooth()

# ============================================================
# CATEGORY 13 — Животные (Animals)
# Tilted collar buckle, paw print with detailed small claws
# ============================================================
def build_animals_icon():
    reset_scene_for_icon()
    # Dog Collar Ring
    bpy.ops.mesh.primitive_torus_add(major_radius=0.38, minor_radius=0.04, location=(0, 0, 0.16))
    collar = bpy.context.active_object
    collar.rotation_euler = (math.radians(16), math.radians(10), 0)
    collar.data.materials.append(create_pbr_material("CollarRed", (0.9, 0.02, 0.04, 1.0), metallic=0.2, roughness=0.15, clearcoat=0.8))
    bpy.ops.object.shade_smooth()
    
    # Buckle
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    buckle = bpy.context.active_object
    buckle.scale = (0.12, 0.12, 0.12)
    buckle.location = (0.28, -0.22, 0.15)
    buckle.rotation_euler = (math.radians(16), math.radians(10), 0)
    buckle.data.materials.append(create_pbr_material("BuckleGold", COLOR_GOLD, metallic=0.98, roughness=0.1))
    bpy.ops.object.shade_smooth()
    
    # Paw Print
    # Main pad
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.15, subdivisions=4, location=(0, 0, 0.20))
    pad = bpy.context.active_object
    pad.scale = (1.25, 1.0, 0.25)
    pad.data.materials.append(create_pbr_material("PawPads", (0.05, 0.05, 0.06, 1.0), roughness=0.15, emission_color=(0.1, 0.8, 1.0, 1.0), emission_strength=4.0))
    bpy.ops.object.shade_smooth()
    
    # 4 Toe pads and tiny claws
    toes = [
        (-0.16, 0.04, 0.34),
        (-0.06, 0.04, 0.42),
        (0.06, 0.04, 0.42),
        (0.16, 0.04, 0.34)
    ]
    for idx, loc in enumerate(toes):
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.05, subdivisions=3, location=loc)
        t = bpy.context.active_object
        t.scale = (1.0, 1.0, 0.4)
        t.data.materials.append(pad.data.materials[0])
        bpy.ops.object.shade_smooth()
        
        # Tiny claw cone on top of each toe
        cx, cz = loc[0], loc[2] + 0.058
        bpy.ops.mesh.primitive_cone_add(radius1=0.012, radius2=0.002, depth=0.038, location=(cx, loc[1] + 0.01, cz))
        claw = bpy.context.active_object
        claw.rotation_euler = (math.radians(-20), 0, 0)
        claw.data.materials.append(create_pbr_material(f"Claw_{idx}", COLOR_CHROME, metallic=0.9, roughness=0.1))
        bpy.ops.object.shade_smooth()

# ============================================================
# CATEGORY 14 — Вещи (Items)
# Suitcase with PBR cloth texture, leather straps & two keys
# ============================================================
def build_items_icon():
    reset_scene_for_icon()
    # Suitcase base with detailed fabric noise bump
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    case = bpy.context.active_object
    case.scale = (0.72, 0.46, 0.16)
    case.location = (0, 0, 0.08)
    case_mat = create_pbr_material("SuitcaseCloth", (0.8, 0.4, 0.1, 1.0), roughness=0.6)
    add_noise_bump(case_mat, scale=320.0, strength=0.22)  # fine suitcase fabric weave
    case.data.materials.append(case_mat)
    
    b_mod = case.modifiers.new(name="Bevel", type='BEVEL')
    b_mod.width = 0.02
    b_mod.segments = 4
    bpy.ops.object.shade_smooth()
    
    # 2 Leather straps wrapped around it
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        strap = bpy.context.active_object
        strap.scale = (0.05, 0.48, 0.17)
        strap.location = (side * 0.20, 0, 0.08)
        strap.data.materials.append(create_pbr_material(f"Strap_{side}", (0.18, 0.10, 0.06, 1.0), roughness=0.55))
        bpy.ops.object.shade_smooth()
    
    # Suitcase corner brass caps
    corners = [
        (-0.36, -0.23, 0.08),
        (0.36, -0.23, 0.08)
    ]
    for idx, loc in enumerate(corners):
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.05, subdivisions=3, location=loc)
        cap = bpy.context.active_object
        cap.data.materials.append(create_pbr_material(f"Cap_{idx}", COLOR_GOLD, metallic=0.95, roughness=0.15))
        bpy.ops.object.shade_smooth()
        
    # Golden Keys
    mat_gold = create_pbr_material("KeyGold", COLOR_GOLD, metallic=0.98, roughness=0.15)
    # Key 1
    bpy.ops.mesh.primitive_torus_add(major_radius=0.10, minor_radius=0.02, location=(-0.1, -0.06, 0.28))
    ring1 = bpy.context.active_object
    ring1.rotation_euler = (math.radians(20), math.radians(-15), math.radians(25))
    ring1.data.materials.append(mat_gold)
    bpy.ops.object.shade_smooth()
    
    bpy.ops.mesh.primitive_cylinder_add(radius=0.014, depth=0.38, location=(0.04, 0.0, 0.22))
    shaft1 = bpy.context.active_object
    shaft1.rotation_euler = (math.radians(20), math.radians(-15), math.radians(25))
    shaft1.data.materials.append(mat_gold)
    bpy.ops.object.shade_smooth()
    
    # Key 2
    bpy.ops.mesh.primitive_torus_add(major_radius=0.10, minor_radius=0.02, location=(0.1, 0.06, 0.32))
    ring2 = bpy.context.active_object
    ring2.rotation_euler = (math.radians(-20), math.radians(15), math.radians(-45))
    ring2.data.materials.append(mat_gold)
    bpy.ops.object.shade_smooth()
    
    bpy.ops.mesh.primitive_cylinder_add(radius=0.014, depth=0.38, location=(-0.04, 0.0, 0.26))
    shaft2 = bpy.context.active_object
    shaft2.rotation_euler = (math.radians(-20), math.radians(15), math.radians(-45))
    shaft2.data.materials.append(mat_gold)
    bpy.ops.object.shade_smooth()

# ============================================================
# CATEGORY 15 — Мероприятия (Event)
# Popping cone, star sparks, and spiral party ribbon coils
# ============================================================
def build_event_icon():
    reset_scene_for_icon()
    # Popping cone
    bpy.ops.mesh.primitive_cone_add(radius1=0.0, radius2=0.18, depth=0.40, location=(-0.08, 0.08, 0.22))
    cone = bpy.context.active_object
    cone.rotation_euler = (math.radians(-35), math.radians(-15), 0)
    cone.data.materials.append(create_pbr_material("ConePurple", (0.58, 0.08, 0.75, 1.0), metallic=0.75, roughness=0.15))
    bpy.ops.object.shade_smooth()
    
    # Golden border ring
    bpy.ops.mesh.primitive_torus_add(major_radius=0.178, minor_radius=0.015, location=(-0.02, 0.02, 0.36))
    ring = bpy.context.active_object
    ring.rotation_euler = (math.radians(-35), math.radians(-15), 0)
    ring.data.materials.append(create_pbr_material("ConeGold", COLOR_GOLD, metallic=0.98, roughness=0.1))
    bpy.ops.object.shade_smooth()
    
    # Sparkles (glowing particles)
    colors = [
        (0.0, 0.9, 1.0, 1.0),
        (1.0, 0.8, 0.0, 1.0),
        (1.0, 0.05, 0.1, 1.0)
    ]
    sparkle_locs = [
        (-0.06, -0.16, 0.45),
        (0.08, -0.22, 0.54),
        (0.16, -0.08, 0.41),
        (-0.20, -0.06, 0.38)
    ]
    for idx, loc in enumerate(sparkle_locs):
        col = colors[idx % len(colors)]
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.035, subdivisions=3, location=loc)
        spark = bpy.context.active_object
        spark.data.materials.append(create_pbr_material(f"Spark_{idx}", col, emission_color=col, emission_strength=5.0))
        bpy.ops.object.shade_smooth()
        
    # Add spiral party ribbon coils (3 stacked toruses scaled to spiral)
    for i in range(3):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.06, minor_radius=0.008, location=(0.12 + i*0.04, -0.18 + i*0.02, 0.28 + i*0.06))
        ribbon = bpy.context.active_object
        ribbon.rotation_euler = (math.radians(15), math.radians(20), math.radians(i * 30))
        ribbon.data.materials.append(create_pbr_material(f"Ribbon_{i}", COLOR_CYAN, roughness=0.2))
        bpy.ops.object.shade_smooth()

# ============================================================
# CATEGORY 16 — Прочее (Other)
# Detailed cog sprocket with rivets, info letter "i" and floating sphere
# ============================================================
def build_other_icon():
    reset_scene_for_icon()
    # Gear base (Chrome)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.38, depth=0.06, location=(0,0,0.16))
    gear = bpy.context.active_object
    gear.data.materials.append(create_pbr_material("GearChrome", COLOR_CHROME, metallic=1.0, roughness=0.06, clearcoat=0.8))
    bpy.ops.object.shade_smooth()
    
    # 8 Gear Teeth
    for i in range(8):
        angle = i * (2 * math.pi / 8)
        x = 0.38 * math.cos(angle)
        y = 0.38 * math.sin(angle)
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        tooth = bpy.context.active_object
        tooth.scale = (0.08, 0.08, 0.06)
        tooth.location = (x, y, 0.16)
        tooth.rotation_euler = (0, 0, angle)
        tooth.data.materials.append(gear.data.materials[0])
        bpy.ops.object.shade_smooth()
        
    # 4 micro assembly rivets on gear surface
    for i in range(4):
        angle = i * (math.pi / 2)
        rx, ry = 0.24 * math.cos(angle), 0.24 * math.sin(angle)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.015, depth=0.02, location=(rx, ry, 0.19))
        rivet = bpy.context.active_object
        rivet.data.materials.append(create_pbr_material(f"GearRivet_{i}", COLOR_GOLD, metallic=0.98, roughness=0.15))
        bpy.ops.object.shade_smooth()
        
    # Info "i" Symbol
    # Stem
    bpy.ops.mesh.primitive_cylinder_add(radius=0.038, depth=0.25, location=(0, -0.02, 0.28))
    stem = bpy.context.active_object
    stem.rotation_euler = (math.radians(90), 0, 0)
    stem.data.materials.append(create_pbr_material("InfoBlue", COLOR_CYAN, emission_color=COLOR_CYAN, emission_strength=10.0))
    bpy.ops.object.shade_smooth()
    
    # Dot
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.046, subdivisions=3, location=(0, -0.02, 0.48))
    dot = bpy.context.active_object
    dot.data.materials.append(stem.data.materials[0])
    bpy.ops.object.shade_smooth()

# ============================================================
# Main Processing Loop
# ============================================================
def main():
    import shutil
    
    ASSETS_DIR = r"C:\Soobshio_project\services\Frontend\assets\3d_icons"
    os.makedirs(ASSETS_DIR, exist_ok=True)
    
    # Map: (generator, blender_name, flutter_asset_name)
    generators = [
        (build_emergency_icon,    "cat_chp",          "chp_3d"),
        (build_utilities_icon,    "cat_gkh",          "gkh_3d"),
        (build_roads_icon,        "cat_dorogi",       "dorogi_3d"),
        (build_lighting_icon,     "cat_lighting",     "lighting_3d"),
        (build_transport_icon,    "cat_transport",    "transport_3d"),
        (build_ecology_icon,      "cat_ecology",      "ecology_3d"),
        (build_security_icon,     "cat_security",     "security_3d"),
        (build_snow_icon,         "cat_snow",         "snow_3d"),
        (build_medicine_icon,     "cat_medicine",     "medicine_3d"),
        (build_education_icon,    "cat_education",    "education_3d"),
        (build_parking_icon,      "cat_parking",      "parking_3d"),
        (build_construction_icon, "cat_construction", "construction_3d"),
        (build_animals_icon,      "cat_animals",      "animals_3d"),
        (build_items_icon,        "cat_items",        "items_3d"),
        (build_event_icon,        "cat_event",        "event_3d"),
        (build_other_icon,        "cat_other",        "other_3d"),
    ]
    
    for gen, fname, asset_name in generators:
        print(f"=== GENERATING: {fname} ===")
        # Run scene generator
        gen()
        
        # Save .blend project
        blend_file = os.path.join(OUT_DIR, f"{fname}.blend")
        bpy.ops.wm.save_as_mainfile(filepath=blend_file)
        
        # Render PNG image
        render_image = os.path.join(OUT_DIR, f"{fname}.png")
        bpy.context.scene.render.filepath = render_image
        bpy.ops.render.render(write_still=True)
        
        # Copy to Flutter assets
        asset_dest = os.path.join(ASSETS_DIR, f"{asset_name}.png")
        shutil.copy2(render_image, asset_dest)
        
        print(f"Saved {fname}.blend, rendered {fname}.png → {asset_name}.png\n")

if __name__ == "__main__":
    main()

