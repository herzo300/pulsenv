"""
Blender 3D Weather Celestials — Sun, Moon, Clouds, Stars.
Generates high-quality PNG sprites (transparent) for use in WeatherOverlayPanel.

Outputs (all RGBA PNG, transparent background):
  - sun.png            (golden 3D sphere with corona glow)
  - moon.png           (cratered moon with subtle terminator)
  - moon_crescent.png  (crescent moon with earthshine)
  - cloud_01.png       (single puffy cloud, side view)
  - cloud_02.png       (denser cloud for storms)
  - stars.png          (subtle starfield with twinkle)
  - aurora_seamless.png (horizontal aurora gradient for video-bottom)
"""
import bpy
import bmesh
import math
import os
import random
from mathutils import Vector

OUT_DIR = r"C:\Soobshio_project\services\Frontend\assets\weather_3d"
os.makedirs(OUT_DIR, exist_ok=True)

random.seed(42)

# ============================================================
# Helpers
# ============================================================
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.view_settings.view_transform = 'Filmic'
    scene.view_settings.look = 'Medium High Contrast'

    world = bpy.data.worlds.new("SkyWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    bg.inputs[0].default_value = (0.0, 0.0, 0.0, 1.0)
    bg.inputs[1].default_value = 0.0  # pitch black for clean alpha


def setup_camera(target_loc=(0, 0, 0), distance=5.5):
    bpy.ops.object.camera_add(location=(0, -distance, 0))
    cam = bpy.context.active_object
    cam.rotation_euler = (math.radians(90), 0, 0)
    cam.data.lens = 70
    bpy.context.scene.camera = cam
    return cam


def add_area_light(loc, color, energy, size=3.0, rotation=(0,0,0)):
    bpy.ops.object.light_add(type='AREA', location=loc)
    light = bpy.context.active_object
    light.data.energy = energy
    light.data.size = size
    light.data.color = color
    light.rotation_euler = rotation
    return light


def render_png(filename, resolution=512):
    scene = bpy.context.scene
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.filepath = os.path.join(OUT_DIR, filename)
    bpy.ops.render.render(write_still=True)
    print(f"[OK] {scene.render.filepath}")


def make_pbr(name, base_color, metallic=0.0, roughness=0.5, emission=None, emission_strength=0.0, ior=1.45):
    """Build a Principled BSDF material compatible with Blender 5.x."""
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    bsdf.inputs['Base Color'].default_value = base_color
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    if 'IOR' in bsdf.inputs:
        bsdf.inputs['IOR'].default_value = ior
    if emission is not None:
        if 'Emission Color' in bsdf.inputs:
            bsdf.inputs['Emission Color'].default_value = emission
            bsdf.inputs['Emission Strength'].default_value = emission_strength
        elif 'Emission' in bsdf.inputs:
            bsdf.inputs['Emission'].default_value = emission
            if 'Emission Strength' in bsdf.inputs:
                bsdf.inputs['Emission Strength'].default_value = emission_strength
    if 'Coat Weight' in bsdf.inputs:
        bsdf.inputs['Coat Weight'].default_value = 0.2
        bsdf.inputs['Coat Roughness'].default_value = 0.1
    return mat


# ============================================================
# 1) SUN — radiant golden sphere with corona
# ============================================================
def build_sun():
    reset_scene()
    setup_camera(distance=4.0)

    # Sun body — subdivided UV sphere
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=1.2)
    sun = bpy.context.active_object
    sun.name = "Sun"
    sun_shade = sun.modifiers.new("Smooth", 'SUBSURF')
    sun_shade.levels = 1
    sun_shade.render_levels = 2
    sun_mat = make_pbr("SunSurface",
        base_color=(1.0, 0.78, 0.20, 1.0),  # gold
        roughness=0.35,
        emission=(1.0, 0.65, 0.20, 1.0),
        emission_strength=8.0)
    sun.data.materials.append(sun_mat)
    bpy.ops.object.shade_smooth()

    # Corona — 4 transparent expanding shells
    for i, (r, alpha, e) in enumerate([
        (1.45, 0.30, 4.0),
        (1.70, 0.18, 2.5),
        (2.00, 0.10, 1.2),
        (2.40, 0.05, 0.5),
    ]):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=r)
        corona = bpy.context.active_object
        corona.name = f"Corona_{i}"
        cmat = make_pbr(f"CoronaMat_{i}",
            base_color=(1.0, 0.85, 0.30, alpha),
            roughness=1.0,
            emission=(1.0, 0.7, 0.25, 1.0),
            emission_strength=e)
        cmat.blend_method = 'BLEND'
        # Set alpha via Principled BSDF alpha input
        bsdf = cmat.node_tree.nodes['Principled BSDF']
        if 'Alpha' in bsdf.inputs:
            bsdf.inputs['Alpha'].default_value = alpha
        corona.data.materials.append(cmat)
        bpy.ops.object.shade_smooth()

    # Lights
    add_area_light((0, -3, 0), (1.0, 0.95, 0.85), 80, size=4.0, rotation=(math.radians(90), 0, 0))
    add_area_light((-2, -1, 1), (1.0, 0.6, 0.2), 60, size=2.5, rotation=(math.radians(60), 0, math.radians(-30)))
    add_area_light((2, -1, -1), (1.0, 0.4, 0.1), 40, size=2.0, rotation=(math.radians(60), 0, math.radians(30)))

    render_png("sun.png", 512)
    print("=== Sun done ===")


# ============================================================
# 2) MOON (full) — cratered grey sphere with soft terminator
# ============================================================
def build_moon(crescent=False):
    reset_scene()
    setup_camera(distance=4.0)

    bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=1.2)
    moon = bpy.context.active_object
    moon.name = "Moon"

    # Add crater bumps via displace noise + subdivision
    subsurf = moon.modifiers.new("Subsurf", 'SUBSURF')
    subsurf.levels = 2
    bpy.ops.object.shade_smooth()

    # Moon material — dusty grey with subtle blue
    mat = make_pbr("MoonSurface",
        base_color=(0.93, 0.94, 0.97, 1.0),
        roughness=0.85,
        metallic=0.0)
    # Add procedural crater displacement
    nt = mat.node_tree
    bsdf = nt.nodes['Principled BSDF']
    tex_coord = nt.nodes.new('ShaderNodeTexCoord')
    noise = nt.nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 18.0
    noise.inputs['Detail'].default_value = 6.0
    noise.inputs['Roughness'].default_value = 0.7
    color_ramp = nt.nodes.new('ShaderNodeValToRGB')
    color_ramp.color_ramp.elements[0].position = 0.4
    color_ramp.color_ramp.elements[0].color = (0.50, 0.51, 0.55, 1.0)
    color_ramp.color_ramp.elements[1].color = (0.95, 0.96, 0.99, 1.0)
    nt.links.new(tex_coord.outputs['Generated'], noise.inputs['Vector'])
    nt.links.new(noise.outputs['Fac'], color_ramp.inputs['Fac'])
    nt.links.new(color_ramp.outputs['Color'], bsdf.inputs['Base Color'])
    moon.data.materials.append(mat)

    # Crescent: add a "shadow sphere" overlapping
    if crescent:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=1.18,
                                              location=(0.35, 0.05, -0.10))
        shadow = bpy.context.active_object
        shadow.name = "ShadowSphere"
        smat = make_pbr("Shadow",
            base_color=(0.02, 0.04, 0.10, 1.0),
            roughness=1.0)
        smat.blend_method = 'BLEND'
        if 'Alpha' in smat.node_tree.nodes['Principled BSDF'].inputs:
            smat.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value = 0.98
        shadow.data.materials.append(smat)
        bpy.ops.object.shade_smooth()
        # Make shadow "subtractive" via alpha — easiest: just opaque dark sphere
        # Apply boolean difference via mesh merge
        bpy.ops.object.select_all(action='DESELECT')
        moon.select_set(True)
        shadow.select_set(True)
        bpy.context.view_layer.objects.active = moon
        try:
            bool_mod = moon.modifiers.new("Cut", 'BOOLEAN')
            bool_mod.operation = 'DIFFERENCE'
            bool_mod.object = shadow
            bpy.ops.object.modifier_apply(modifier="Cut")
            bpy.data.objects.remove(shadow, do_unlink=True)
        except Exception as e:
            print(f"Boolean cut skipped: {e}")

    # Lights — soft cold key, warm fill from below (earthshine)
    add_area_light((3, -2, 2), (0.85, 0.90, 1.0), 50, size=3.0, rotation=(math.radians(60), 0, math.radians(40)))
    add_area_light((-1, -3, -1), (0.40, 0.50, 0.80), 8, size=4.0, rotation=(math.radians(90), 0, math.radians(-20)))
    add_area_light((0, -1, -3), (0.20, 0.25, 0.40), 5, size=4.0, rotation=(math.radians(110), 0, 0))

    filename = "moon_crescent.png" if crescent else "moon.png"
    render_png(filename, 512)
    print(f"=== {'Crescent Moon' if crescent else 'Full Moon'} done ===")


# ============================================================
# 3) CLOUD — puffy 3D cloud via metaballs
# ============================================================
def build_cloud(name, density=0.6):
    reset_scene()
    setup_camera(distance=4.5)

    # Multiple metaballs forming puffy cloud
    bpy.ops.object.metaball_add(type='BALL', location=(0, 0, 0))
    mb_meta = bpy.context.active_object
    # add 14 child balls in a horizontal cluster
    for i in range(14):
        rx = (random.random() - 0.5) * 1.6
        ry = (random.random() - 0.5) * 0.4
        rz = (random.random() - 0.5) * 0.8
        scale = 0.35 + random.random() * 0.6
        bpy.ops.object.metaball_add(type='BALL', location=(rx, ry, rz))
        mb = bpy.context.active_object
        mb.scale = (scale, scale, scale * 0.85)

    # Apply metaball resolution for smoother surface
    mb_meta.data.resolution = 0.18
    mb_meta.data.render_resolution = 0.07

    # Convert metaballs to mesh so we can assign material
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.convert(target='MESH')
    cloud = bpy.context.active_object
    cloud.name = "Cloud"

    # Soft white volumetric-ish material
    cmat = make_pbr("Cloud",
        base_color=(1.0, 1.0, 1.0, density),
        roughness=1.0,
        metallic=0.0)
    cmat.blend_method = 'BLEND'
    bsdf = cmat.node_tree.nodes['Principled BSDF']
    if 'Alpha' in bsdf.inputs:
        bsdf.inputs['Alpha'].default_value = density
    cloud.data.materials.append(cmat)
    bpy.ops.object.shade_smooth()

    # Soft rim light from behind + top key
    add_area_light((0, -3, 2), (1.0, 1.0, 1.0), 60, size=4.0, rotation=(math.radians(60), 0, 0))
    add_area_light((-2, -2, -1), (0.7, 0.85, 1.0), 30, size=3.0, rotation=(math.radians(90), 0, math.radians(-40)))
    add_area_light((2, 1, 0), (1.0, 0.95, 0.85), 25, size=3.0, rotation=(math.radians(0), math.radians(90), 0))

    render_png(name, 640)
    print(f"=== {name} done ===")


# ============================================================
# 4) STARS — sparse starfield sprite
# ============================================================
def build_stars():
    reset_scene()
    setup_camera(distance=4.0)
    # Camera faces origin
    bpy.context.scene.camera.rotation_euler = (math.radians(90), 0, 0)

    # Plane as backdrop (will be transparent)
    bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, 0))
    plane = bpy.context.active_object
    plane.name = "StarBackdrop"
    # Material: alpha mask with star dots via procedural
    mat = bpy.data.materials.new("StarMask")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    emit = nt.nodes.new('ShaderNodeEmission')
    tex_coord = nt.nodes.new('ShaderNodeTexCoord')
    voronoi = nt.nodes.new('ShaderNodeTexVoronoi')
    voronoi.inputs['Scale'].default_value = 25.0
    cr = nt.nodes.new('ShaderNodeValToRGB')
    cr.color_ramp.elements[0].position = 0.85
    cr.color_ramp.elements[0].color = (0, 0, 0, 0)  # transparent
    cr.color_ramp.elements[1].color = (1, 1, 1, 1)
    # Mix with transparent for alpha
    transparent = nt.nodes.new('ShaderNodeBsdfTransparent')
    mix = nt.nodes.new('ShaderNodeMixShader')
    nt.links.new(tex_coord.outputs['Object'], voronoi.inputs['Vector'])
    nt.links.new(voronoi.outputs['Distance'], cr.inputs['Fac'])
    nt.links.new(cr.outputs['Color'], emit.inputs['Color'])
    nt.links.new(transparent.outputs['BSDF'], mix.inputs[1])
    nt.links.new(emit.outputs['Emission'], mix.inputs[2])
    nt.links.new(cr.outputs['Alpha'], mix.inputs['Fac'])
    nt.links.new(mix.outputs['Shader'], out.inputs['Surface'])
    emit.inputs['Strength'].default_value = 5.0
    mat.blend_method = 'BLEND'
    plane.data.materials.append(mat)

    render_png("stars.png", 512)
    print("=== Stars done ===")


# ============================================================
# 5) AURORA — horizontal ribbon
# ============================================================
def build_aurora():
    reset_scene()
    # Camera ortho top-down for seamless ribbon
    bpy.ops.object.camera_add(location=(0, -3, 0))
    cam = bpy.context.active_object
    cam.rotation_euler = (math.radians(90), 0, 0)
    cam.data.lens = 35
    bpy.context.scene.camera = cam

    # Plane with aurora gradient
    bpy.ops.mesh.primitive_plane_add(size=4, location=(0, 0, 0))
    plane = bpy.context.active_object
    plane.name = "AuroraRibbon"
    mat = bpy.data.materials.new("AuroraMat")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    emit = nt.nodes.new('ShaderNodeEmission')
    tex_coord = nt.nodes.new('ShaderNodeTexCoord')
    wave = nt.nodes.new('ShaderNodeTexWave')
    wave.inputs['Scale'].default_value = 2.0
    wave.inputs['Distortion'].default_value = 4.0
    wave.inputs['Detail'].default_value = 6.0
    color_ramp = nt.nodes.new('ShaderNodeValToRGB')
    color_ramp.color_ramp.elements[0].position = 0.25
    color_ramp.color_ramp.elements[0].color = (0.0, 0.5, 0.3, 1.0)  # deep teal
    el = color_ramp.color_ramp.elements.new(0.55)
    el.color = (0.0, 1.0, 0.7, 1.0)  # aurora green
    el2 = color_ramp.color_ramp.elements.new(0.75)
    el2.color = (0.4, 0.5, 1.0, 1.0)  # cyan-violet
    color_ramp.color_ramp.elements[1].position = 0.9
    color_ramp.color_ramp.elements[1].color = (0.6, 0.3, 1.0, 1.0)  # violet
    transparent = nt.nodes.new('ShaderNodeBsdfTransparent')
    mix = nt.nodes.new('ShaderNodeMixShader')
    nt.links.new(tex_coord.outputs['Object'], wave.inputs['Vector'])
    nt.links.new(wave.outputs['Color'], color_ramp.inputs['Fac'])
    nt.links.new(color_ramp.outputs['Color'], emit.inputs['Color'])
    nt.links.new(transparent.outputs['BSDF'], mix.inputs[1])
    nt.links.new(emit.outputs['Emission'], mix.inputs[2])
    # Mask bottom (no aurora below certain Y)
    nt.links.new(color_ramp.outputs['Alpha'], mix.inputs['Fac'])
    nt.links.new(mix.outputs['Shader'], out.inputs['Surface'])
    emit.inputs['Strength'].default_value = 8.0
    mat.blend_method = 'BLEND'
    plane.data.materials.append(mat)

    bpy.context.scene.render.resolution_x = 1024
    bpy.context.scene.render.resolution_y = 256
    bpy.context.scene.render.filepath = os.path.join(OUT_DIR, "aurora_seamless.png")
    bpy.ops.render.render(write_still=True)
    print(f"[OK] aurora_seamless.png")


# ============================================================
# RUN ALL
# ============================================================
if __name__ == "__main__":
    print("\n========== SUN ==========")
    build_sun()
    print("\n========== FULL MOON ==========")
    build_moon(crescent=False)
    print("\n========== CRESCENT MOON ==========")
    build_moon(crescent=True)
    print("\n========== CLOUD 1 ==========")
    build_cloud("cloud_01.png", density=0.7)
    print("\n========== CLOUD 2 (storm) ==========")
    build_cloud("cloud_02.png", density=0.9)
    print("\n========== STARS ==========")
    build_stars()
    print("\n========== AURORA ==========")
    build_aurora()
    print("\n\n=== ALL WEATHER CELESTIALS RENDERED ===")
