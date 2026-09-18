import bpy
import math
import os

OUT_DIR = r"C:\Soobshio_project\blender_assets\output"
os.makedirs(OUT_DIR, exist_ok=True)

# Shared Design Colors (RGBA)
COLOR_CHROME   = (0.880, 0.880, 0.900, 1.0)
COLOR_GOLD     = (0.950, 0.750, 0.200, 1.0)
COLOR_CYAN     = (0.000, 0.898, 1.000, 1.0)
COLOR_ORANGE   = (1.000, 0.350, 0.000, 1.0)
COLOR_LEATHER  = (0.350, 0.180, 0.080, 1.0)
COLOR_WHITE    = (0.950, 0.950, 0.950, 1.0)
COLOR_GREY     = (0.450, 0.450, 0.450, 1.0)
COLOR_BLUE     = (0.050, 0.200, 0.800, 1.0)

def reset_scene_for_icon():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 16  # Quick samples for agent performance
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = 'Filmic'
    
    # World setup
    world = bpy.data.worlds.new("LFWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    bg.inputs[0].default_value = (0.0, 0.0, 0.0, 1.0)
    bg.inputs[1].default_value = 0.2
    
    # Camera
    bpy.ops.object.camera_add(location=(1.4, -1.8, 1.3))
    cam = bpy.context.active_object
    cam.data.lens = 65
    scene.camera = cam
    
    empty = bpy.data.objects.new("Target", None)
    empty.location = (0, 0, 0.15)
    scene.collection.objects.link(empty)
    
    track = cam.constraints.new(type='TRACK_TO')
    track.target = empty
    track.track_axis = 'TRACK_NEGATIVE_Z'
    track.up_axis = 'UP_Y'
    
    # Light
    bpy.ops.object.light_add(type='AREA', location=(2.0, -2.5, 2.0))
    key = bpy.context.active_object
    key.data.energy = 800
    key.data.size = 2.0
    key.data.color = (0.95, 0.97, 1.0)

    bpy.ops.object.light_add(type='AREA', location=(-2.0, -2.0, 1.0))
    fill = bpy.context.active_object
    fill.data.energy = 400
    fill.data.size = 3.0
    fill.data.color = (1.0, 0.95, 0.9)

def create_material(name, color, metallic=0.0, roughness=0.2, emission=None):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = color
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    if emission:
        if 'Emission Color' in bsdf.inputs:
            bsdf.inputs['Emission Color'].default_value = emission
            bsdf.inputs['Emission Strength'].default_value = 5.0
        elif 'Emission' in bsdf.inputs:
            bsdf.inputs['Emission'].default_value = emission
    return mat

def build_cat():
    reset_scene_for_icon()
    # Cat face (sphere)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.25, location=(0,0,0.2))
    face = bpy.context.active_object
    face.data.materials.append(create_material("CatOrange", COLOR_ORANGE, roughness=0.5))
    bpy.ops.object.shade_smooth()
    
    # Left Ear (cone)
    bpy.ops.mesh.primitive_cone_add(radius1=0.08, depth=0.18, location=(-0.14, 0.05, 0.38))
    ear_l = bpy.context.active_object
    ear_l.rotation_euler = (0, math.radians(-15), 0)
    ear_l.data.materials.append(create_material("CatEar", COLOR_WHITE, roughness=0.5))
    bpy.ops.object.shade_smooth()
    
    # Right Ear (cone)
    bpy.ops.mesh.primitive_cone_add(radius1=0.08, depth=0.18, location=(0.14, 0.05, 0.38))
    ear_r = bpy.context.active_object
    ear_r.rotation_euler = (0, math.radians(15), 0)
    ear_r.data.materials.append(ear_l.data.materials[0])
    bpy.ops.object.shade_smooth()
    
    # Nose (pink cone)
    bpy.ops.mesh.primitive_cone_add(radius1=0.03, depth=0.04, location=(0, -0.22, 0.18))
    nose = bpy.context.active_object
    nose.rotation_euler = (math.radians(-90), 0, 0)
    nose.data.materials.append(create_material("CatNose", (1.0, 0.6, 0.7, 1.0), roughness=0.4))
    bpy.ops.object.shade_smooth()

def build_dog():
    reset_scene_for_icon()
    # Dog head (cube rounded)
    bpy.ops.mesh.primitive_cube_add(size=0.4, location=(0,0,0.2))
    head = bpy.context.active_object
    head.scale = (1, 1.1, 0.9)
    head.data.materials.append(create_material("DogBrown", (0.5, 0.3, 0.15, 1.0), roughness=0.6))
    bpy.ops.object.shade_smooth()
    
    # Dog muzzle (cylinder)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=0.18, location=(0, -0.2, 0.15))
    muzzle = bpy.context.active_object
    muzzle.rotation_euler = (math.radians(90), 0, 0)
    muzzle.data.materials.append(create_material("DogMuzzle", COLOR_WHITE, roughness=0.5))
    bpy.ops.object.shade_smooth()
    
    # Dog nose (black sphere)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.03, location=(0, -0.3, 0.18))
    nose = bpy.context.active_object
    nose.data.materials.append(create_material("DogNose", (0.02, 0.02, 0.02, 1.0), roughness=0.1))
    bpy.ops.object.shade_smooth()
    
    # Ears floppy (cylinders stretched)
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=0.25, location=(side * 0.22, 0, 0.22))
        ear = bpy.context.active_object
        ear.rotation_euler = (math.radians(10), 0, side * math.radians(-10))
        ear.data.materials.append(head.data.materials[0])
        bpy.ops.object.shade_smooth()

def build_keys():
    reset_scene_for_icon()
    # Ring (torus)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.15, minor_radius=0.02, location=(0,0,0.3))
    ring = bpy.context.active_object
    ring.rotation_euler = (math.radians(45), 0, 0)
    ring.data.materials.append(create_material("KeyChrome", COLOR_CHROME, metallic=0.98, roughness=0.1))
    bpy.ops.object.shade_smooth()
    
    # Key shaft 1
    bpy.ops.mesh.primitive_cylinder_add(radius=0.016, depth=0.35, location=(-0.08, -0.08, 0.15))
    key1 = bpy.context.active_object
    key1.rotation_euler = (math.radians(65), 0, math.radians(-30))
    key1.data.materials.append(ring.data.materials[0])
    bpy.ops.object.shade_smooth()
    
    # Key shaft 2
    bpy.ops.mesh.primitive_cylinder_add(radius=0.016, depth=0.35, location=(0.08, -0.08, 0.15))
    key2 = bpy.context.active_object
    key2.rotation_euler = (math.radians(75), 0, math.radians(30))
    key2.data.materials.append(create_material("KeyGold", COLOR_GOLD, metallic=0.98, roughness=0.15))
    bpy.ops.object.shade_smooth()

def build_phone():
    reset_scene_for_icon()
    # Body (cube flat)
    bpy.ops.mesh.primitive_cube_add(size=0.45, location=(0,0,0.22))
    body = bpy.context.active_object
    body.scale = (0.6, 0.1, 1.2)
    body.data.materials.append(create_material("PhoneDark", (0.05, 0.05, 0.07, 1.0), metallic=0.9, roughness=0.2))
    
    # Screen (glowing cyan plane front)
    bpy.ops.mesh.primitive_cube_add(size=0.42, location=(0, -0.024, 0.22))
    screen = bpy.context.active_object
    screen.scale = (0.54, 0.02, 1.14)
    screen.data.materials.append(create_material("ScreenNeon", COLOR_CYAN, roughness=0.05, emission=COLOR_CYAN))

def build_wallet():
    reset_scene_for_icon()
    # Wallet core (cube stretched)
    bpy.ops.mesh.primitive_cube_add(size=0.4, location=(0,0,0.18))
    wallet = bpy.context.active_object
    wallet.scale = (1.1, 0.5, 0.7)
    wallet.data.materials.append(create_material("LeatherMat", COLOR_LEATHER, roughness=0.6))
    bpy.ops.object.shade_smooth()
    
    # Credit Card 1 (blue slab)
    bpy.ops.mesh.primitive_cube_add(size=0.24, location=(-0.1, 0, 0.32))
    card1 = bpy.context.active_object
    card1.scale = (1.0, 0.1, 0.7)
    card1.rotation_euler = (math.radians(5), math.radians(-10), 0)
    card1.data.materials.append(create_material("CardBlue", COLOR_BLUE, roughness=0.2))
    
    # Credit Card 2 (gold slab)
    bpy.ops.mesh.primitive_cube_add(size=0.24, location=(0.1, -0.02, 0.34))
    card2 = bpy.context.active_object
    card2.scale = (1.0, 0.1, 0.7)
    card2.rotation_euler = (math.radians(8), math.radians(12), 0)
    card2.data.materials.append(create_material("CardGold", COLOR_GOLD, roughness=0.15))

def build_backpack():
    reset_scene_for_icon()
    # Main bag body (sphere elongated)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.25, location=(0,0,0.25))
    bag = bpy.context.active_object
    bag.scale = (0.9, 0.8, 1.3)
    bag_mat = create_material("BackpackCyan", COLOR_CYAN, roughness=0.45)
    bag.data.materials.append(bag_mat)
    bpy.ops.object.shade_smooth()
    
    # Front pocket
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.14, location=(0,-0.16,0.15))
    pocket = bpy.context.active_object
    pocket.scale = (1.0, 0.7, 1.0)
    pocket.data.materials.append(create_material("BackpackOrange", COLOR_ORANGE, roughness=0.5))
    bpy.ops.object.shade_smooth()

def build_passport():
    reset_scene_for_icon()
    # Cover (cube)
    bpy.ops.mesh.primitive_cube_add(size=0.4, location=(0,0,0.22))
    cover = bpy.context.active_object
    cover.scale = (0.8, 0.15, 1.1)
    cover.rotation_euler = (math.radians(10), math.radians(-12), 0)
    cover.data.materials.append(create_material("CoverBlue", COLOR_BLUE, roughness=0.4))
    
    # Gold Seal on front cover
    bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=0.02, location=(-0.04, -0.035, 0.22))
    seal = bpy.context.active_object
    seal.rotation_euler = (math.radians(100), math.radians(-12), 0)
    seal.data.materials.append(create_material("SealGold", COLOR_GOLD, metallic=0.9, roughness=0.15))
    bpy.ops.object.shade_smooth()

def build_event():
    reset_scene_for_icon()
    # Megaphone body (cone stretched)
    bpy.ops.mesh.primitive_cone_add(radius1=0.08, radius2=0.22, depth=0.35, location=(0.04, -0.05, 0.22))
    horn = bpy.context.active_object
    horn.rotation_euler = (0, math.radians(70), 0)
    horn.data.materials.append(create_material("HornBody", COLOR_ORANGE, roughness=0.2))
    bpy.ops.object.shade_smooth()

    # Megaphone handle (cylinder)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.026, depth=0.18, location=(-0.08, 0, 0.12))
    handle = bpy.context.active_object
    handle.rotation_euler = (0, math.radians(15), 0)
    handle.data.materials.append(create_material("HandleMat", COLOR_WHITE, roughness=0.4))
    bpy.ops.object.shade_smooth()

    # Megaphone ring/rim
    bpy.ops.mesh.primitive_torus_add(major_radius=0.22, minor_radius=0.02, location=(0.18, -0.08, 0.24))
    rim = bpy.context.active_object
    rim.rotation_euler = (0, math.radians(70), 0)
    rim.data.materials.append(create_material("RimChrome", COLOR_WHITE, roughness=0.1))
    bpy.ops.object.shade_smooth()

    # Megaphone back (sphere)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.09, location=(-0.11, -0.01, 0.2))
    back = bpy.context.active_object
    back.data.materials.append(create_material("BackGold", COLOR_GOLD, roughness=0.2))
    bpy.ops.object.shade_smooth()

def build_garbage():
    reset_scene_for_icon()
    # Trash can main body (cylinder with tapered bottom)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.18, depth=0.32, location=(0, 0, 0.22))
    can = bpy.context.active_object
    can.data.materials.append(create_material("CanMetal", COLOR_CHROME, metallic=0.9, roughness=0.15))
    bpy.ops.object.shade_smooth()

    # Can rim (torus at the top)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.18, minor_radius=0.015, location=(0, 0, 0.38))
    rim = bpy.context.active_object
    rim.data.materials.append(create_material("RimChrome", COLOR_CHROME, metallic=0.95, roughness=0.05))
    bpy.ops.object.shade_smooth()

    # Vertical ridges/grooves on the can
    for i in range(12):
        angle = i * (2 * math.pi / 12)
        rx = 0.182 * math.cos(angle)
        ry = 0.182 * math.sin(angle)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.01, depth=0.30, location=(rx, ry, 0.22))
        ridge = bpy.context.active_object
        ridge.data.materials.append(can.data.materials[0])
        bpy.ops.object.shade_smooth()

    # Handles (two toruses on the sides)
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.05, minor_radius=0.01, location=(side * 0.20, 0, 0.26))
        handle = bpy.context.active_object
        handle.rotation_euler = (0, math.radians(90), 0)
        handle.data.materials.append(create_material("HandleGold", COLOR_GOLD, metallic=0.98, roughness=0.15))
        bpy.ops.object.shade_smooth()

    # A crumpled trash bag peeking out of the top
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.12, subdivisions=3, location=(0, 0, 0.40))
    bag = bpy.context.active_object
    bag.scale = (1.1, 1.1, 0.8)
    bag.data.materials.append(create_material("TrashBag", COLOR_ORANGE, roughness=0.25))
    bpy.ops.object.shade_smooth()

def render_and_save(filename):
    scene = bpy.context.scene
    filepath = os.path.join(OUT_DIR, filename)
    scene.render.filepath = filepath
    bpy.ops.render.render(write_still=True)
    print(f"Rendered: {filepath}")

# Execution mapping
renders = [
    (build_cat, "lf_cat.png"),
    (build_dog, "lf_dog.png"),
    (build_keys, "lf_keys.png"),
    (build_phone, "lf_phone.png"),
    (build_wallet, "lf_wallet.png"),
    (build_backpack, "lf_backpack.png"),
    (build_passport, "lf_passport.png"),
    (build_event, "lf_event.png"),
    (build_garbage, "lf_garbage.png"),
]

for builder, filename in renders:
    builder()
    render_and_save(filename)
