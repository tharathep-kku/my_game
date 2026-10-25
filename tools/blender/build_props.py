# HD remaster: realistic office furniture and fixtures, written to assets/models/real/<name>.glb.
# Each model with the name of a Kenney model (assets/models/<name>.glb) replaces it in the HD look
# (scripts/hd.gd realize(): fitted to the Kenney model's box, so placement and colliders stay).
# The rest (troffer, vent, outlet, ...) are the fixtures hd.gd puts on the walls and ceilings.
#
# Run (from the project folder; any Blender 4.2+ or the `bpy` pip module):
#   blender --background --python tools/blender/build_props.py            (all)
#   blender --background --python tools/blender/build_props.py -- desk    (only one)
#
# Conventions: geometry is written in Godot axes (x right, y up, +z = the front of the model),
# metres, origin at the bottom centre. Material names tell the game which HD surface to use:
# the part before the first "_" is wood / plastic / fabric / metal / concrete (texture + shine),
# screen (glossy, no texture) or glow (lit: glow_<hex colour>).
import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Euler, Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "models", "real")

# name: (sRGB hex, roughness, metallic)
MATS = {
    "wood_laminate": ("8c8578", 0.5, 0.0),
    "wood_front": ("7a7468", 0.48, 0.0),
    "wood_oak": ("8a6a48", 0.5, 0.0),
    "wood_cork": ("9a7650", 0.95, 0.0),
    "plastic_black": ("1d1e21", 0.42, 0.0),
    "plastic_dark": ("2d2f34", 0.5, 0.0),
    "plastic_grey": ("5d6064", 0.45, 0.0),
    "plastic_light": ("a7a9aa", 0.45, 0.0),
    "plastic_white": ("d6d4cd", 0.42, 0.0),
    "plastic_beige": ("c4bba5", 0.5, 0.0),
    "plastic_red": ("8e1410", 0.32, 0.0),
    "plastic_cardboard": ("9a754a", 0.92, 0.0),
    "plastic_tape": ("b7996c", 0.35, 0.0),
    "plastic_paper": ("e6e2d6", 0.9, 0.0),
    "plastic_pot": ("34343a", 0.6, 0.0),
    "plastic_leaf": ("2c4724", 0.5, 0.0),
    "plastic_bark": ("4a3b2c", 0.85, 0.0),
    "concrete_soil": ("2a2119", 1.0, 0.0),
    "metal_chrome": ("cfd0d2", 0.16, 1.0),
    "metal_steel": ("8f9398", 0.38, 0.85),
    "metal_painted": ("7d8287", 0.5, 0.25),
    "metal_pedestal": ("575b60", 0.48, 0.3),
    "metal_dark": ("2a2b2e", 0.42, 0.7),
    "fabric_seat": ("2a2c31", 0.95, 0.0),
    "fabric_mesh": ("1c1d21", 0.9, 0.0),
    "fabric_mattress": ("aebdc4", 0.85, 0.0),
    "fabric_sheet": ("d8d8d2", 0.9, 0.0),
    "screen_glass": ("060709", 0.1, 0.0),
    "glow_ffb040": ("ffb040", 0.5, 0.0),
    "glow_ff2a1a": ("ff2a1a", 0.5, 0.0),
    "glow_3dff6a": ("3dff6a", 0.5, 0.0),
    "glow_fff6e8": ("fff6e8", 0.5, 0.0),
    "glow_e8fff0": ("e8fff0", 0.5, 0.0),
}

def lin(c):   # sRGB -> linear (Blender stores linear; Godot shows exactly the hex)
    return tuple(((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c)

def rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

def material(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    col, rough, metal = MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(rgb(col)), 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if name.startswith("glow_"):
        b.inputs["Emission Color"].default_value = (*lin(rgb(col)), 1.0)
        b.inputs["Emission Strength"].default_value = 2.0
    return m

# Godot axes -> Blender axes (a proper rotation: windings stay outward)
G2B = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))

class Model:
    """Collects primitives (one bmesh) with a material per face."""
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def _mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    # Moves geometry made in a temporary bmesh (at the origin, Godot axes) into place.
    def _add(self, tmp, mat, c, rot, smooth):
        e = Euler([math.radians(a) for a in rot], "XYZ")
        m = Matrix.Translation(Vector(c)) @ e.to_matrix().to_4x4()
        bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts)
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        mi = self._mi(mat)
        for p in me.polygons:
            p.material_index = mi
            p.use_smooth = smooth
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def box(self, c, s, mat, bevel=0.004, seg=2, rot=(0, 0, 0), taper=1.0):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            k = taper if v.co.y > 0 else 1.0
            v.co = Vector((v.co.x * s[0] * k, v.co.y * s[1], v.co.z * s[2] * k))
        b = min(bevel, min(s) * 0.45)
        if b > 0.0005:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=b, segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
        self._add(tmp, mat, c, rot, b > 0.0005)

    # Cylinder along local y, r1 bottom / r2 top.
    def cyl(self, c, r1, h, mat, r2=None, n=24, rot=(0, 0, 0), bevel=0.0, caps=True):
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=caps, cap_tris=False, segments=n, radius1=r1, radius2=r1 if r2 is None else r2, depth=h)
        bmesh.ops.rotate(tmp, verts=tmp.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-90), 3, "X"))
        if bevel > 0:
            rims = [e for e in tmp.edges if abs(e.verts[0].co.y - e.verts[1].co.y) < 1e-6 and abs(abs(e.verts[0].co.y) - h / 2) < 1e-6]
            bmesh.ops.bevel(tmp, geom=rims, offset=bevel, segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
        self._add(tmp, mat, c, rot, True)

    def sphere(self, c, s, mat, rot=(0, 0, 0), u=20, v=12):
        tmp = bmesh.new()
        bmesh.ops.create_uvsphere(tmp, u_segments=u, v_segments=v, radius=0.5)
        for vv in tmp.verts:
            vv.co = Vector((vv.co.x * s[0], vv.co.y * s[1], vv.co.z * s[2]))
        self._add(tmp, mat, c, rot, True)

    # A grid of quads (u along x, v along z) shaped by f(u, v) -> Vector; two-sided (a back copy).
    def sheet(self, f, nu, nv, mat, thick=0.002):
        tmp = bmesh.new()
        rows = []
        for j in range(nv + 1):
            rows.append([tmp.verts.new(f(i / nu, j / nv)) for i in range(nu + 1)])
        for j in range(nv):
            for i in range(nu):
                tmp.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        bmesh.ops.solidify(tmp, geom=list(tmp.faces), thickness=thick)
        self._add(tmp, mat, (0, 0, 0), (0, 0, 0), True)

    def finish(self):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.transform(self.bm, matrix=G2B.to_4x4(), verts=self.bm.verts)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.00002)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(material(m))
        me.set_sharp_from_angle(angle=math.radians(40))
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob

def export(name):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                              export_yup=True, export_apply=True, export_materials="EXPORT")
    print("built", name)

def handle(m, x, y, z, w=0.13, axis="x"):
    """Bar pull on a front face at depth z (sticking out to +z)."""
    if axis == "x":
        m.box((x, y, z + 0.022), (w, 0.011, 0.011), "metal_chrome", 0.004, 2)
        for dx in (-w / 2 + 0.01, w / 2 - 0.01):
            m.box((x + dx, y, z + 0.01), (0.009, 0.009, 0.024), "metal_chrome", 0.002, 1)
    else:
        m.box((x, y, z + 0.022), (0.011, w, 0.011), "metal_chrome", 0.004, 2)
        for dy in (-w / 2 + 0.01, w / 2 - 0.01):
            m.box((x, y + dy, z + 0.01), (0.009, 0.009, 0.024), "metal_chrome", 0.002, 1)

# ---------------------------------------------------------------- furniture (Kenney names)
def desk(m):
    m.box((0, 0.753, 0), (1.468, 0.03, 0.784), "wood_laminate", 0.005, 3)
    for x in (-0.71, 0.71):
        m.box((x, 0.369, -0.02), (0.028, 0.738, 0.72), "wood_laminate", 0.003)
        m.box((x, 0.006, -0.02), (0.034, 0.012, 0.7), "plastic_black", 0.002)   # floor glides
    m.box((0, 0.47, -0.31), (1.39, 0.46, 0.018), "wood_laminate", 0.003)        # modesty panel
    # drawer pedestal under the right side
    px = 0.44
    m.box((px, 0.36, 0.0), (0.42, 0.68, 0.6), "metal_pedestal", 0.006)
    y0 = 0.035
    for h in (0.15, 0.15, 0.33):
        m.box((px, y0 + h / 2, 0.309), (0.41, h - 0.008, 0.018), "metal_pedestal", 0.004)
        handle(m, px, y0 + h - 0.035, 0.318, 0.14)
        y0 += h
    m.cyl((px + 0.15, 0.665, 0.32), 0.009, 0.012, "metal_chrome", rot=(90, 0, 0))   # lock
    for x in (px - 0.17, px + 0.17):
        for z in (-0.25, 0.25):
            m.cyl((x, 0.012, z), 0.018, 0.024, "plastic_black", n=12)   # castors
    # cable grommet, a cable going down, a little stack of paper and a pen cup
    m.cyl((-0.58, 0.7535, -0.3), 0.032, 0.032, "plastic_black", bevel=0.003)
    m.cyl((-0.58, 0.4, -0.33), 0.006, 0.7, "plastic_black", n=8)
    for i in range(5):
        m.box((-0.47 + i * 0.002, 0.7705 + i * 0.0022, 0.16 - i * 0.003), (0.21, 0.002, 0.297), "plastic_paper", 0.0, rot=(0, 3 - i * 2.2, 0))
    m.cyl((-0.62, 0.818, 0.12), 0.036, 0.1, "plastic_dark", r2=0.038)
    for i, (dx, dz, a) in enumerate(((0.01, 0.0, 8), (-0.012, 0.01, -10), (0.0, -0.012, 4))):
        m.cyl((-0.62 + dx, 0.86, 0.12 + dz), 0.004, 0.14, ("plastic_black", "plastic_red", "plastic_white")[i], n=6, rot=(a, 0, a))

def chairDesk(m):
    for i in range(5):
        a = math.radians(i * 72 + 18)
        d = Vector((math.cos(a), 0, math.sin(a)))
        m.box(tuple(d * 0.14 + Vector((0, 0.085, 0))), (0.28, 0.034, 0.042), "plastic_black", 0.012, 2, rot=(0, -math.degrees(a), 0), taper=0.8)
        tip = d * 0.285
        m.cyl((tip.x, 0.068, tip.z), 0.014, 0.03, "plastic_black", n=10)
        m.cyl((tip.x, 0.03, tip.z), 0.028, 0.026, "plastic_dark", n=16, rot=(90, -math.degrees(a), 0))   # castor wheel
    m.cyl((0, 0.085, 0), 0.055, 0.06, "plastic_black", r2=0.04, bevel=0.006)
    m.cyl((0, 0.2, 0), 0.032, 0.2, "plastic_black", n=20)
    m.cyl((0, 0.36, 0), 0.02, 0.16, "metal_chrome", n=20)
    m.box((0, 0.43, 0.01), (0.22, 0.04, 0.25), "metal_dark", 0.006)
    m.box((0.13, 0.43, 0.12), (0.012, 0.012, 0.12), "plastic_black", 0.004, rot=(0, 20, 0))   # height lever
    m.box((0, 0.495, 0.02), (0.5, 0.085, 0.48), "fabric_seat", 0.034, 4)
    m.box((0, 0.452, 0.02), (0.46, 0.012, 0.44), "plastic_black", 0.005)   # seat shell
    m.box((0, 0.56, -0.24), (0.07, 0.17, 0.03), "plastic_black", 0.01, rot=(-12, 0, 0))
    m.box((0, 0.71, -0.275), (0.07, 0.2, 0.026), "plastic_black", 0.01, rot=(-6, 0, 0))
    m.box((0, 0.94, -0.3), (0.46, 0.52, 0.06), "fabric_mesh", 0.028, 4, rot=(-9, 0, 0), taper=0.96)
    m.box((0, 0.94, -0.335), (0.44, 0.5, 0.02), "plastic_black", 0.008, rot=(-9, 0, 0), taper=0.96)
    for x in (-0.27, 0.27):
        m.box((x * 0.8, 0.462, 0.0), (0.12, 0.016, 0.05), "plastic_black", 0.004)
        m.box((x, 0.59, 0.0), (0.032, 0.25, 0.048), "plastic_black", 0.01)
        m.box((x, 0.72, 0.02), (0.075, 0.03, 0.25), "plastic_dark", 0.013, 3)

def computerScreen(m):
    m.box((0, 0.008, -0.02), (0.26, 0.016, 0.2), "plastic_black", 0.006, 3)
    m.box((0, 0.19, -0.075), (0.07, 0.34, 0.026), "plastic_black", 0.008, 2, rot=(-5, 0, 0))
    m.box((0, 0.36, -0.03), (0.786, 0.455, 0.022), "plastic_black", 0.004, 2)
    m.box((0, 0.335, -0.055), (0.5, 0.28, 0.034), "plastic_black", 0.012, 3)
    m.box((0, 0.37, -0.0185), (0.758, 0.421, 0.002), "screen_glass", 0.0)
    m.box((0.355, 0.146, -0.0185), (0.006, 0.004, 0.003), "glow_ffb040", 0.0)   # standby light
    m.cyl((0.0, 0.25, -0.09), 0.006, 0.4, "plastic_black", n=8, rot=(14, 0, 0))   # cable

def computerKeyboard(m):
    # native: the user's side is -z (the game turns it round); mouse to the user's right
    kx = 0.07
    m.box((kx, 0.011, 0.0), (0.42, 0.02, 0.15), "plastic_black", 0.005, 2, rot=(-3, 0, 0))
    m.box((kx, 0.004, 0.06), (0.4, 0.008, 0.02), "plastic_dark", 0.003)
    p = 0.0215
    rows = [(-0.052, 0.0215), (-0.03, 0.0225), (-0.008, 0.0235), (0.014, 0.0245), (0.036, 0.0255), (0.062, 0.0265)]
    for r, (z, y) in enumerate(rows):
        cols = 15
        x = kx - 0.2 + p / 2
        i = 0
        while i < cols:
            w = 1
            if r == 0 and i == 4:
                w = 6   # space bar
            if r == 5:
                kw = 0.016
                m.box((x, y, z), (kw, 0.006, 0.012), "plastic_dark", 0.002, 1)
            else:
                m.box((x + (w - 1) * p / 2, y, z), (w * p - 0.004, 0.008, 0.0175), "plastic_dark", 0.0025, 1)
            x += w * p
            i += w
        if r < 5:   # number pad
            for j in range(3):
                m.box((kx + 0.2 - 0.07 + j * p, y, z), (p - 0.004, 0.008, 0.0175), "plastic_dark", 0.0025, 1)
    m.box((kx + 0.19, 0.0225, 0.07), (0.004, 0.002, 0.003), "glow_3dff6a", 0.0)
    m.box((-0.2, 0.0015, 0.0), (0.2, 0.003, 0.22), "fabric_seat", 0.002)   # mouse pad
    m.sphere((-0.205, 0.018, -0.02), (0.036, 0.03, 0.064), "plastic_black")
    m.box((-0.205, 0.006, -0.02), (0.034, 0.008, 0.06), "plastic_black", 0.008, rot=(0, 0, 0))
    m.cyl((-0.195, 0.004, 0.06), 0.002, 0.11, "plastic_black", n=6, rot=(90, 0, 15))

def sideTableDrawers(m):
    m.box((0, 0.4, -0.012), (1.02, 0.7, 0.42), "wood_laminate", 0.003)
    m.box((0, 0.753, 0), (1.068, 0.03, 0.444), "wood_laminate", 0.005, 3)
    m.box((0, 0.026, -0.02), (0.98, 0.052, 0.37), "plastic_black", 0.002)
    for x in (-0.255, 0.255):
        y0 = 0.058
        for h in (0.22, 0.22, 0.235):
            m.box((x, y0 + h / 2, 0.205), (0.497, h - 0.006, 0.02), "wood_front", 0.003)
            handle(m, x, y0 + h - 0.05, 0.215, 0.16)
            y0 += h

def kitchenCoffeeMachine(m):
    m.box((0, 0.025, 0.0), (0.26, 0.05, 0.48), "plastic_black", 0.014, 3)
    m.box((0, 0.19, -0.17), (0.26, 0.33, 0.14), "plastic_black", 0.016, 3)
    m.box((0, 0.31, -0.02), (0.26, 0.09, 0.36), "plastic_black", 0.016, 3)
    m.box((0, 0.262, 0.06), (0.17, 0.008, 0.17), "plastic_dark", 0.004)   # filter basket underside
    m.cyl((0, 0.053, 0.08), 0.072, 0.006, "metal_steel", n=28)
    m.cyl((0, 0.135, 0.08), 0.07, 0.155, "screen_glass", r2=0.056, n=28)
    m.cyl((0, 0.085, 0.08), 0.071, 0.05, "concrete_soil", r2=0.068, n=28)   # old coffee in the pot
    m.cyl((0, 0.222, 0.08), 0.059, 0.022, "plastic_black", n=28, bevel=0.004)
    m.box((0.0, 0.14, 0.16), (0.02, 0.11, 0.025), "plastic_black", 0.006)
    m.box((0.0, 0.2, 0.15), (0.02, 0.02, 0.05), "plastic_black", 0.005)
    m.box((0.0, 0.085, 0.15), (0.02, 0.02, 0.05), "plastic_black", 0.005)
    m.box((0.07, 0.03, 0.235), (0.05, 0.016, 0.01), "plastic_dark", 0.003)
    m.box((0.07, 0.03, 0.241), (0.008, 0.005, 0.002), "glow_ff2a1a", 0.0)
    m.cyl((0.175, 0.046, 0.16), 0.04, 0.092, "plastic_white", n=24, bevel=0.003)   # a mug
    m.box((0.22, 0.05, 0.16), (0.012, 0.05, 0.012), "plastic_white", 0.005)

def radio(m):
    m.box((0, 0.15, 0), (0.5, 0.26, 0.15), "plastic_grey", 0.025, 3)
    for x in (-0.15, 0.15):
        m.cyl((x, 0.13, 0.072), 0.094, 0.012, "plastic_black", rot=(90, 0, 0), n=32, bevel=0.003)
        m.cyl((x, 0.13, 0.079), 0.082, 0.004, "metal_dark", rot=(90, 0, 0), n=32)
        m.cyl((x, 0.13, 0.082), 0.022, 0.006, "plastic_black", rot=(90, 0, 0), n=16)
    m.box((0, 0.12, 0.075), (0.1, 0.075, 0.006), "screen_glass", 0.002)
    m.box((0, 0.235, 0.075), (0.38, 0.034, 0.004), "plastic_black", 0.002)
    m.box((-0.12, 0.235, 0.078), (0.004, 0.026, 0.002), "glow_ff2a1a", 0.0)
    for i in range(6):
        m.box((-0.1 + i * 0.04, 0.284, 0.03), (0.03, 0.014, 0.03), "plastic_black", 0.004)
    m.box((0, 0.345, -0.02), (0.36, 0.02, 0.026), "plastic_black", 0.008)
    for x in (-0.17, 0.17):
        m.box((x, 0.31, -0.02), (0.022, 0.06, 0.026), "plastic_black", 0.006)
    m.cyl((0.02, 0.29, -0.06), 0.004, 0.36, "metal_chrome", n=8, rot=(0, 0, 90))

def kitchenBar(m):
    m.box((0, 0.535, 0), (1.0, 0.83, 0.46), "wood_laminate", 0.004)
    m.box((0, 0.99, 0), (1.032, 0.035, 0.504), "wood_oak", 0.006, 3)
    m.box((0, 0.06, 0), (0.97, 0.12, 0.42), "plastic_black", 0.003)
    for z in (-0.232, 0.232):
        m.box((0, 0.62, z), (1.0, 0.04, 0.004), "metal_chrome", 0.001)
    m.box((0.3, 0.9, -0.2), (0.3, 0.015, 0.06), "plastic_paper", 0.0)   # sign-in sheet edge

def pottedPlant(m):
    rnd = random.Random(4)
    m.cyl((0, 0.18, 0), 0.13, 0.36, "plastic_pot", r2=0.17, n=32)
    m.cyl((0, 0.355, 0), 0.178, 0.03, "plastic_pot", n=32, bevel=0.006)
    m.cyl((0, 0.33, 0), 0.158, 0.02, "concrete_soil", n=32)
    for s in range(3):
        a = s * 2.1 + 0.3
        top = Vector((math.cos(a) * 0.06, 1.0 + s * 0.17, math.sin(a) * 0.06))
        bot = Vector((math.cos(a) * 0.02, 0.33, math.sin(a) * 0.02))
        mid = (top + bot) / 2
        d = top - bot
        tilt = math.degrees(math.atan2(math.hypot(d.x, d.z), d.y))
        yaw = math.degrees(math.atan2(d.x, d.z))
        m.cyl(tuple(mid), 0.012, d.length, "plastic_bark", r2=0.007, n=8, rot=(tilt, yaw, 0))
        for k in range(16):   # leaves up the stem, spiralling, bigger lower down
            t = 0.25 + 0.75 * k / 15
            base = bot.lerp(top, t)
            yaw_l = rnd.uniform(0, 2 * math.pi)
            ln = 0.2 * (1.25 - t * 0.5) * rnd.uniform(0.85, 1.15)
            wd = ln * 0.36
            droop = rnd.uniform(0.15, 0.45)
            up = rnd.uniform(0.25, 0.6)
            cy, sy = math.cos(yaw_l), math.sin(yaw_l)
            def leaf(u, v, base=base, ln=ln, wd=wd, droop=droop, up=up, cy=cy, sy=sy):
                along = v * ln
                width = math.sin(math.pi * min(v * 1.08, 1.0)) * wd * (u - 0.5)
                fold = abs(u - 0.5) * wd * 0.35
                rise = along * up - droop * (v ** 2) * ln
                return base + Vector((cy * along - sy * width, rise + fold, sy * along + cy * width))
            m.sheet(leaf, 2, 5, "plastic_leaf", 0.0015)

def bedSingle(m):
    # hospital bed, head to -z
    for x in (-0.5, 0.5):
        m.box((x, 0.36, 0), (0.04, 0.05, 2.1), "metal_steel", 0.01)
    for z in (-1.0, 1.0):
        m.box((0, 0.36, z), (1.04, 0.05, 0.04), "metal_steel", 0.01)
        for x in (-0.45, 0.45):
            m.cyl((x, 0.2, z), 0.022, 0.32, "metal_steel", n=12)
            m.cyl((x, 0.05, z), 0.05, 0.035, "plastic_black", rot=(0, 0, 90), n=18)
    m.box((0, 0.48, 0.05), (0.92, 0.17, 1.95), "fabric_mattress", 0.05, 4)
    m.box((0, 0.5, 0.25), (0.96, 0.15, 1.3), "fabric_sheet", 0.04, 4)
    m.box((0, 0.6, -0.78), (0.6, 0.1, 0.35), "plastic_white", 0.045, 4)   # pillow
    m.box((0, 0.66, -1.08), (1.0, 0.62, 0.05), "plastic_beige", 0.02, 3)
    m.box((0, 0.56, 1.08), (1.0, 0.42, 0.05), "plastic_beige", 0.02, 3)
    for x in (-0.52, 0.52):
        m.box((x, 0.68, -0.45), (0.025, 0.2, 0.75), "plastic_light", 0.008)
        for z in (-0.7, -0.45, -0.2):
            m.box((x, 0.57, z), (0.02, 0.06, 0.02), "metal_steel", 0.004)

def cardboardBoxClosed(m):
    m.box((0, 0.28, 0), (0.42, 0.56, 0.42), "plastic_cardboard", 0.006)
    m.box((0, 0.5605, 0), (0.002, 0.002, 0.42), "concrete_soil", 0.0)
    m.box((0, 0.561, 0), (0.07, 0.002, 0.425), "plastic_tape", 0.0)
    for z in (-0.211, 0.211):
        m.box((0, 0.5, z), (0.07, 0.12, 0.002), "plastic_tape", 0.0)
    m.box((0.08, 0.36, 0.2115), (0.14, 0.09, 0.002), "plastic_paper", 0.0)

def bookcaseClosedDoors(m):
    m.box((0, 0.94, 0), (0.88, 1.84, 0.53), "metal_painted", 0.004)
    m.box((0, 0.03, 0.0), (0.84, 0.06, 0.5), "metal_dark", 0.002)
    for x in (-0.219, 0.219):
        m.box((x, 0.96, 0.27), (0.434, 1.74, 0.014), "metal_painted", 0.003)
        for y in (0.25, 1.65):
            for i in range(5):
                m.box((x, y + i * 0.022, 0.278), (0.22, 0.008, 0.003), "metal_dark", 0.0)
    m.box((0.035, 1.0, 0.29), (0.018, 0.16, 0.02), "metal_chrome", 0.006)
    m.cyl((-0.03, 1.15, 0.28), 0.01, 0.012, "metal_chrome", rot=(90, 0, 0), n=12)
    m.box((0.2, 1.75, 0.2785), (0.11, 0.05, 0.002), "plastic_paper", 0.0)

def trashcan(m):
    m.cyl((0, 0.36, 0), 0.17, 0.72, "plastic_grey", r2=0.2, n=32)
    m.cyl((0, 0.735, 0), 0.205, 0.03, "plastic_dark", n=32, bevel=0.008)
    m.sphere((0, 0.75, 0), (0.4, 0.17, 0.4), "plastic_dark", u=28, v=10)
    m.box((0, 0.79, 0.12), (0.2, 0.09, 0.012), "plastic_black", 0.004, rot=(-30, 0, 0))

# ---------------------------------------------------------------- fixtures (hd.gd decorates)
def troffer(m):
    # 1.2 x 0.6 recessed light: top at y = 0.06 (flush with the ceiling), open to -y
    W, D, H = 1.2, 0.6, 0.06
    for z in (-D / 2 + 0.015, D / 2 - 0.015):
        m.box((0, 0.01, z), (W, 0.02, 0.03), "plastic_white", 0.003)
    for x in (-W / 2 + 0.015, W / 2 - 0.015):
        m.box((x, 0.01, 0), (0.03, 0.02, D), "plastic_white", 0.003)
    m.box((0, H - 0.004, 0), (W - 0.04, 0.008, D - 0.04), "plastic_white", 0.0)
    for z in (-0.13, 0.13):
        m.cyl((0, 0.042, z), 0.013, W - 0.08, "glow_fff6e8", rot=(0, 0, 90), n=14)
        for x in (-W / 2 + 0.035, W / 2 - 0.035):
            m.box((x, 0.042, z), (0.02, 0.03, 0.04), "plastic_light", 0.003)
    for z in (-0.27, 0.0, 0.27):   # parabolic louvres
        m.box((0, 0.025, z), (W - 0.05, 0.035, 0.003), "metal_chrome", 0.0)
    for i in range(9):
        x = -W / 2 + 0.025 + (i + 0.5) * (W - 0.05) / 9
        m.box((x, 0.025, 0), (0.003, 0.035, D - 0.05), "metal_chrome", 0.0)

def vent(m):
    # square ceiling diffuser, 0.6 m, face down, top at y = 0.03
    for i, s in enumerate((0.6, 0.48, 0.36, 0.24)):
        y = 0.008 + i * 0.006
        t = 0.05 if i == 0 else 0.022
        for z in (-s / 2 + t / 2, s / 2 - t / 2):
            m.box((0, y, z), (s, 0.016, t), "plastic_white", 0.002)
        for x in (-s / 2 + t / 2, s / 2 - t / 2):
            m.box((x, y, 0), (t, 0.016, s), "plastic_white", 0.002)
    m.box((0, 0.028, 0), (0.56, 0.004, 0.56), "concrete_soil", 0.0)
    m.box((0, 0.012, 0), (0.13, 0.024, 0.13), "plastic_white", 0.003)

def smoke(m):
    m.cyl((0, 0.016, 0), 0.065, 0.032, "plastic_white", r2=0.07, n=28, bevel=0.006)
    m.cyl((0, -0.002, 0), 0.03, 0.006, "plastic_white", n=20)
    m.box((0.04, -0.001, 0), (0.006, 0.003, 0.006), "glow_ff2a1a", 0.0)

def sprinkler(m):
    m.cyl((0, 0.012, 0), 0.03, 0.006, "metal_chrome", n=16)
    m.cyl((0, -0.005, 0), 0.007, 0.03, "metal_chrome", n=8)
    m.cyl((0, -0.022, 0), 0.016, 0.003, "metal_chrome", n=12)

def outlet(m):
    # wall plate, back against the wall (z = 0), facing +z
    m.box((0, 0.0, 0.004), (0.075, 0.12, 0.008), "plastic_white", 0.003)
    for y in (-0.028, 0.028):
        m.box((0, y, 0.0085), (0.04, 0.04, 0.002), "plastic_white", 0.006)
        for x in (-0.007, 0.007):
            m.box((x, y + 0.003, 0.0095), (0.003, 0.009, 0.001), "plastic_black", 0.0)
        m.cyl((0, y - 0.01, 0.0095), 0.002, 0.001, "plastic_black", rot=(90, 0, 0), n=8)

def extinguisher(m):
    # against the wall (z = 0), standing on a hook at y = 0
    m.box((0, 0.42, 0.012), (0.08, 0.06, 0.024), "metal_dark", 0.004)
    m.cyl((0, 0.22, 0.1), 0.075, 0.42, "plastic_red", n=28, bevel=0.03)
    m.cyl((0, 0.45, 0.1), 0.022, 0.05, "metal_dark", n=12)
    m.box((0, 0.485, 0.1), (0.03, 0.03, 0.12), "metal_dark", 0.006)
    m.box((0, 0.5, 0.06), (0.025, 0.012, 0.11), "metal_steel", 0.004, rot=(-12, 0, 0))
    m.cyl((0, 0.49, 0.08), 0.02, 0.02, "metal_steel", rot=(90, 0, 0), n=12)
    m.cyl((0.06, 0.32, 0.12), 0.01, 0.3, "plastic_black", n=8, rot=(0, 0, -12))
    m.box((0, 0.22, 0.176), (0.09, 0.12, 0.002), "plastic_paper", 0.0, rot=(0, 0, 0))
    m.box((0, 0.72, 0.006), (0.16, 0.16, 0.012), "plastic_red", 0.003)   # sign above it
    m.box((0, 0.72, 0.0125), (0.1, 0.1, 0.002), "plastic_white", 0.0)

def board(m):
    # notice board against the wall (z = 0) with paper pinned to it
    rnd = random.Random(11)
    m.box((0, 0, 0.012), (0.9, 0.6, 0.024), "metal_steel", 0.004)
    m.box((0, 0, 0.022), (0.86, 0.56, 0.006), "wood_cork", 0.0)
    for i in range(7):
        w, h = rnd.choice(((0.21, 0.297), (0.297, 0.21), (0.15, 0.1), (0.1, 0.15)))
        x = rnd.uniform(-0.43 + w / 2, 0.43 - w / 2)
        y = rnd.uniform(-0.28 + h / 2, 0.28 - h / 2)
        m.box((x, y, 0.026 + i * 0.0008), (w, h, 0.0012), "plastic_paper" if i % 3 else "plastic_beige", 0.0, rot=(0, 0, rnd.uniform(-6, 6)))
        m.cyl((x, y + h / 2 - 0.015, 0.03 + i * 0.0008), 0.006, 0.006, rnd.choice(("plastic_red", "plastic_black", "plastic_white")), rot=(90, 0, 0), n=8)

def exit_sign(m):
    # hangs from the ceiling (top at y = 0), faces +z and -z
    m.box((0, -0.04, 0), (0.012, 0.08, 0.012), "plastic_white", 0.002)
    m.box((0, -0.16, 0), (0.36, 0.16, 0.05), "plastic_white", 0.006)
    for z in (-0.026, 0.026):
        m.box((0, -0.16, z), (0.32, 0.12, 0.002), "glow_3dff6a", 0.0)

def switch(m):
    m.box((0, 0, 0.004), (0.075, 0.12, 0.008), "plastic_white", 0.003)
    m.box((0, 0, 0.01), (0.03, 0.05, 0.006), "plastic_white", 0.003)

MODELS = [desk, chairDesk, computerScreen, computerKeyboard, sideTableDrawers, kitchenCoffeeMachine,
          radio, kitchenBar, pottedPlant, bedSingle, cardboardBoxClosed, bookcaseClosedDoors, trashcan,
          troffer, vent, smoke, sprinkler, outlet, extinguisher, board, exit_sign, switch]

def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for f in MODELS:
        if argv and f.__name__ not in argv:
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        m = Model(f.__name__)
        f(m)
        m.finish()
        export(f.__name__)

main()
