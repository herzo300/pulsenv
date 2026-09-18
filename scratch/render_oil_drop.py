# Blender 5.1 headless: 3D золотая капля нефти — логотип «Пульс Города»
import bpy
import math
import os

# Очистка сцены
bpy.ops.wm.read_factory_settings(use_empty=True)

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 640
scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.film_transparent = True

# ── Капля: сфера + вытянутый конус сверху ──
bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=64, ring_count=48, location=(0, 0, -0.15))
drop = bpy.context.active_object
drop.scale = (0.82, 0.82, 1.0)
bpy.ops.object.shade_smooth()

# Верхний «хвост» капли
bpy.ops.mesh.primitive_cone_add(vertices=64, radius1=0.62, radius2=0.0, depth=1.6, location=(0, 0, 0.95))
tip = bpy.context.active_object
bpy.ops.object.shade_smooth()

# Объединяем
bpy.ops.object.select_all(action='DESELECT')
drop.select_set(True)
tip.select_set(True)
bpy.context.view_layer.objects.active = drop
bpy.ops.object.join()

# Материал: жидкое золото с глубиной
mat = bpy.data.materials.new("OilGold")
mat.use_nodes = True
nt = mat.node_tree.nodes
nt.clear()
out = nt.new("ShaderNodeOutputMaterial")
bsdf = nt.new("ShaderNodeBsdfPrincipled")
bsdf.inputs["Base Color"].default_value = (0.55, 0.32, 0.05, 1.0)
bsdf.inputs["Metallic"].default_value = 0.85
bsdf.inputs["Roughness"].default_value = 0.18
bsdf.inputs["Coat Weight"].default_value = 0.6
bsdf.inputs["Coat Roughness"].default_value = 0.1
links = mat.node_tree.links
links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
drop.data.materials.append(mat)

# Золотое светящееся ядро внутри капли
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.45, segments=48, ring_count=32, location=(0, 0, -0.15))
core = bpy.context.active_object
bpy.ops.object.shade_smooth()
cmat = bpy.data.materials.new("GoldCore")
cmat.use_nodes = True
cnt = cmat.node_tree.nodes
cnt.clear()
cout = cnt.new("ShaderNodeOutputMaterial")
em = cnt.new("ShaderNodeEmission")
em.inputs["Color"].default_value = (1.0, 0.72, 0.15, 1.0)
em.inputs["Strength"].default_value = 6.0
cmat.node_tree.links.new(em.outputs["Emission"], cout.inputs["Surface"])
core.data.materials.append(cmat)

# Кольцо-орбита вокруг капли (пульс)
bpy.ops.mesh.primitive_torus_add(major_radius=1.35, minor_radius=0.045, major_segments=72, minor_segments=16,
                                 location=(0, 0, -0.15), rotation=(math.radians(75), 0, 0))
ring = bpy.context.active_object
rmat = bpy.data.materials.new("RingGold")
rmat.use_nodes = True
rnt = rmat.node_tree.nodes
rnt.clear()
rout = rnt.new("ShaderNodeOutputMaterial")
rem = rnt.new("ShaderNodeEmission")
rem.inputs["Color"].default_value = (1.0, 0.78, 0.25, 1.0)
rem.inputs["Strength"].default_value = 3.0
rmat.node_tree.links.new(rem.outputs["Emission"], rout.inputs["Surface"])
ring.data.materials.append(rmat)

# ── Освещение: студийное трёхточечное ──
def add_light(name, loc, energy, color, size=2.0):
    ld = bpy.data.lights.new(name, type='AREA')
    ld.energy = energy
    ld.color = color
    ld.shape = 'DISK'
    ld.size = size
    lo = bpy.data.objects.new(name, ld)
    bpy.context.collection.objects.link(lo)
    lo.location = loc
    # направить на центр
    direction = -lo.location
    lo.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    return lo

add_light("Key", (3, -3, 4), 900, (1.0, 0.85, 0.6))
add_light("Fill", (-3.5, -2, 2), 500, (0.5, 0.65, 1.0))
add_light("Rim", (0, 3.5, 3), 1100, (1.0, 0.7, 0.3))

# ── Камера ──
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
bpy.context.collection.objects.link(cam)
cam.location = (0, -6.2, 0.6)
cam.rotation_euler = (math.radians(84), 0, 0)
cam_data.lens = 55
scene.camera = cam

out_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "services", "Frontend", "assets", "splash", "oil_drop_3d.png"))
scene.render.filepath = out_path
bpy.ops.render.render(write_still=True)
print("RENDERED:", out_path)
