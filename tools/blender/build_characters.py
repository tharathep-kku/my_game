# Builds every character as a segmented low-poly PSX model (like PS1 games: rigid parts that
# rotate at the joints) and writes, per character:
#   assets/characters/<name>.blend   <- open this in Blender to edit the model
#   assets/characters/<name>.glb     <- what the game loads (scripts/body.gd)
#
# Run (from the project folder):
#   blender --background --python tools/blender/build_characters.py
#   blender --background --python tools/blender/build_characters.py -- manager     (only one)
#   ... -- --preview <dir>   also renders a front/side PNG of each into <dir>
#
# WARNING: this regenerates the .blend files from scratch. If you edited a .blend by hand,
# don't run this for that character; export it yourself instead (see EDITING.md).
#
# Rules the game relies on (keep them if you edit a model by hand):
#   - objects named LegL, LegR, ArmL, ArmR, Torso, Neck (an Empty) with children NeckMesh and Head
#   - each object's origin = its joint (hip, shoulder, waist, neck base, head bottom)
#   - NeckMesh is 1 m tall from its origin, squashed by its scale (the game stretches it)
#   - the character faces +Y in Blender (= forward in Godot). L = the character's own left (-X)
#   - colours = material Base Color (the game redraws them with its PSX shader)
import bpy
import math
import os
import sys
from mathutils import Euler, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "characters")

# ---------------------------------------------------------------- helpers
# Geometry is written in Godot axes (x right, y up, -z forward); g2b() converts to Blender.
def g2b(v):
    return Vector((v[0], -v[2], v[1]))

def lin(c):   # sRGB -> linear, so Blender's colour picker (and Godot) show exactly c
    return tuple(((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c)

def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

class Part:
    def __init__(self, name):
        self.name = name
        self.verts = []
        self.faces = []    # (indices, colour)

    # Box centred at c (local, Godot axes), size s. top/bot scale the +y / -y face (x, z) for
    # tapered shapes; rot = Euler degrees (Godot axes).
    def box(self, c, s, col, rot=(0, 0, 0), top=(1, 1), bot=(1, 1)):
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        e = Euler([math.radians(a) for a in rot])
        base = len(self.verts)
        for y, sc in ((-hy, bot), (hy, top)):
            for x, z in ((-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz)):
                v = Vector((x * sc[0], y, z * sc[1]))
                v.rotate(e)
                self.verts.append(v + Vector(c))
        b = base
        # outward winding (Godot axes)
        for f in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
            self.faces.append(([b + i for i in f], col))

    def obj(self, mats):
        me = bpy.data.meshes.new(self.name)
        cols = []
        for _, col in self.faces:
            if col not in cols:
                cols.append(col)
        me.from_pydata([g2b(v) for v in self.verts], [], [f for f, _ in self.faces])
        for col in cols:
            me.materials.append(mats(col))
        for poly, (_, col) in zip(me.polygons, self.faces):
            poly.material_index = cols.index(col)
        # pydata winding is in Godot axes; g2b is a proper rotation, so it stays outward
        me.validate()
        me.update()
        return bpy.data.objects.new(self.name, me)


# ---------------------------------------------------------------- palette
C = {k: rgb(v) for k, v in {
    "black": "15131a", "white": "eeeeea", "eye": "f4f2e8", "red": "b8282e", "mouth": "4a0f12",
    "skin": "d9b394", "skin_tan": "c8956c", "skin_brown": "9c6a48", "skin_pale": "e0c4a8",
    "shoe": "1c1a1c", "hair": "1b1a22", "grey_hair": "6d6a70", "gold": "d9b13a",
    "tong_shirt": "a9c4e0", "tong_tie": "1e2a52", "tong_pants": "2c3346", "lanyard": "e04a86",
    "clipboard": "e8c544", "paper": "f2f0e6", "bag": "6d4a7a",
    "suit": "5b5f6c", "suit_dark": "3f424c", "mgr_pants": "45474f", "board": "8a5a2e",
    "porn_shirt": "d0628e", "apron": "e4e4e0", "apron_dark": "b9b9b4", "wrap": "38c1bd", "porn_pants": "4c4b55",
    "stick": "7a4a22", "mop": "d8d6cc", "bowl": "a8acb2", "leaf": "4fae4a", "water": "8fe0ff",
    "hoodie": "5a3a96", "hoodie_dark": "45297a", "tae_pants": "26252e", "cable1": "f05aa8", "cable2": "45d6e0", "cable3": "f2d23c",
    "navy": "1f2d55", "navy_dark": "172042", "tag": "e6e6e6", "phone": "d8cfae", "stubble": "8e6a50",
    "coat": "f2f2f0", "scrubs": "4a8a8c", "steth": "3a3c44",
    "dummy": "c9b9a0", "dummy_joint": "8f8270",
}.items()}

# Standard skeleton (Godot axes, metres) — same joints the old box bodies used.
HIP_Y, SHOULDER_Y, NECK_Y = 0.8, 1.42, 1.46
HEAD = 0.42


# ---------------------------------------------------------------- shared body parts
def legs(parts, pants, shoe, coat=None):
    for s, n in ((-1, "LegL"), (1, "LegR")):
        p = parts[n]
        p.box((0, -0.4, 0), (0.22, 0.8, 0.24), pants, bot=(0.9, 0.9))
        p.box((0, -0.76, -0.05), (0.25, 0.1, 0.34), shoe)
        if coat:   # long coat panel over the thigh
            p.box((0, -0.18, 0), (0.25, 0.36, 0.27), coat)

def arms(parts, sleeve, hand, length=0.65, cuff=None):
    for n in ("ArmL", "ArmR"):
        p = parts[n]
        p.box((0, -length / 2, 0), (0.18, length, 0.2), sleeve, bot=(0.9, 0.9))
        if cuff:
            p.box((0, -length + 0.03, 0), (0.19, 0.06, 0.21), cuff)
        p.box((0, -length - 0.07, 0), (0.15, 0.15, 0.16), hand)

def torso(p, shirt, bottom=(0.86, 0.94), h=0.66):
    p.box((0, h / 2, 0), (0.56, h, 0.32), shirt, bot=bottom)

def shade(c, k):
    return tuple(min(1.0, x * k) for x in c)

# Sculpted head: skull with a narrower jaw, ears, a real nose (narrow bridge, wide tip, nostrils),
# cheekbones and a chin, so the face has depth instead of features painted on a cube.
# chin = colour of the chin block (the guard's is stubble).
def head_base(h, skin, jaw=(0.86, 0.9), size=HEAD, chin=None):
    h.skin = skin
    h.box((0, size / 2, 0), (size, size, size), skin, bot=jaw)
    for s_ in (-1, 1):
        h.box((s_ * (size / 2 + 0.02), size * 0.5, 0.02), (0.05, 0.11, 0.09), skin, bot=(0.8, 0.8))   # ears
        h.box((s_ * (size / 2 + 0.035), size * 0.5, 0.02), (0.02, 0.06, 0.05), shade(skin, 0.75))   # ear hole
        h.box((s_ * 0.135, 0.19, FZ - 0.004), (0.09, 0.05, 0.024), shade(skin, 1.06))   # cheekbones
    h.box((0, 0.19, FZ - 0.035), (0.07, 0.085, 0.07), skin, top=(0.5, 0.55))    # nose
    for s_ in (-1, 1):
        h.box((s_ * 0.017, 0.146, FZ - 0.05), (0.018, 0.01, 0.02), shade(skin, 0.55))   # nostrils
    h.box((0, 0.024, FZ - 0.01), (0.14, 0.045, 0.03), chin or skin, bot=(0.8, 0.8))    # chin

FZ = -HEAD / 2   # face plane

# Eyes sit in dark sockets under a brow ridge that overhangs them (shadowed, deep-set).
def eyes(h, y=0.25, gap=0.095, w=0.1, hgt=0.075, pupil=0.035, look=(0, 0), white="eye", brow=None, brow_rot=0, bags=None):
    skin = getattr(h, "skin", C["skin"])
    h.box((0, y + hgt / 2 + 0.028, FZ - 0.02), (2 * gap + w + 0.06, 0.045, 0.045), skin)   # brow ridge
    for s in (-1, 1):
        x = s * gap
        h.box((x, y, FZ - 0.003), (w * 1.25, hgt * 1.45, 0.012), shade(skin, 0.62))   # socket
        h.box((x, y, FZ - 0.008), (w, hgt, 0.02), C[white])
        h.box((x + look[0], y + look[1], FZ - 0.02), (pupil, pupil, 0.012), C["black"])
        if bags:
            h.box((x, y - hgt / 2 - 0.018, FZ - 0.016), (w * 0.9, 0.022, 0.012), bags)
        if brow:
            h.box((x, y + hgt / 2 + 0.035, FZ - 0.047), (w * 1.1, 0.03, 0.012), brow, rot=(0, 0, s * brow_rot))   # + = angry, - = worried

# Frames sit in front of the brow ridge; temple arms run back to the ears.
def glasses(h, y=0.25, gap=0.095, frame="black", thick=0.022, round_=False):
    col = C[frame]
    z = FZ - 0.052
    for s in (-1, 1):
        x = s * gap
        w, hh = (0.13, 0.11)
        # four bars around the eye
        h.box((x, y + hh / 2, z), (w, thick, 0.015), col)
        h.box((x, y - hh / 2, z), (w * (0.8 if round_ else 1), thick, 0.015), col)
        h.box((x - w / 2, y, z), (thick, hh * (0.8 if round_ else 1), 0.015), col)
        h.box((x + w / 2, y, z), (thick, hh * (0.8 if round_ else 1), 0.015), col)
        h.box((s * (HEAD / 2 + 0.005), y, (z + 0.03) / 2), (0.015, 0.02, 0.03 - z), col)   # temple arm
    h.box((0, y + 0.01, z), (0.06, thick, 0.015), col)   # bridge


# ---------------------------------------------------------------- characters
def tong(p):
    legs(p, C["tong_pants"], C["shoe"])
    arms(p, C["tong_shirt"], C["skin"])
    t = p["Torso"]
    torso(t, C["tong_shirt"])
    t.box((0, 0.6, -0.15), (0.24, 0.08, 0.04), C["white"])                         # collar
    t.box((0, 0.42, -0.17), (0.08, 0.34, 0.02), C["tong_tie"], bot=(0.6, 1))      # tie
    t.box((-0.12, 0.42, -0.165), (0.04, 0.42, 0.02), C["lanyard"], rot=(0, 0, -18))
    t.box((-0.06, 0.22, -0.18), (0.16, 0.12, 0.015), C["clipboard"])              # ID card
    t.box((-0.06, 0.22, -0.19), (0.12, 0.08, 0.01), C["paper"])
    h = p["Head"]
    head_base(h, C["skin"])
    eyes(h, look=(0.0, -0.01), brow=C["hair"], brow_rot=-14, bags=C["bag"])        # worried
    h.box((0, 0.095, FZ - 0.01), (0.13, 0.035, 0.02), C["red"])                   # wobbly frown
    h.box((-0.05, 0.08, FZ - 0.012), (0.04, 0.02, 0.02), C["red"])
    h.box((0.05, 0.08, FZ - 0.012), (0.04, 0.02, 0.02), C["red"])
    h.box((0, HEAD + 0.04, 0.02), (HEAD + 0.04, 0.1, HEAD + 0.02), C["hair"])     # hair cap
    h.box((0, HEAD - 0.03, FZ - 0.01), (HEAD + 0.02, 0.08, 0.05), C["hair"])      # fringe
    for x, z, r in ((-0.13, 0.0, 25), (0.0, -0.08, -15), (0.12, 0.03, -30), (-0.04, 0.1, 10), (0.08, -0.12, 20)):
        h.box((x, HEAD + 0.12, z), (0.09, 0.14, 0.09), C["hair"], rot=(r * 0.5, 0, r), top=(0.2, 0.2))
    for s in (-1, 1):
        h.box((s * (HEAD / 2 + 0.005), HEAD * 0.7, 0.04), (0.03, 0.12, HEAD * 0.75), C["hair"])
    h.box((0.25, 0.38, -0.12), (0.04, 0.07, 0.04), C["water"], top=(0.3, 0.3))   # sweat drop

def manager(p):
    legs(p, C["mgr_pants"], C["shoe"])
    arms(p, C["suit"], C["skin_tan"], cuff=C["white"])
    t = p["Torso"]
    torso(t, C["suit"], bottom=(0.9, 0.95))
    t.box((0, 0.5, -0.155), (0.2, 0.3, 0.02), C["white"], bot=(0.2, 1))           # shirt V
    t.box((0, 0.44, -0.17), (0.07, 0.36, 0.02), C["red"], bot=(0.7, 1))           # red tie
    for s in (-1, 1):
        t.box((s * 0.11, 0.45, -0.165), (0.07, 0.32, 0.02), C["suit_dark"], rot=(0, 0, s * 12))   # lapels
    a = p["ArmR"]   # clipboard in the right hand
    a.box((-0.05, -0.62, -0.16), (0.3, 0.38, 0.03), C["board"])
    a.box((-0.05, -0.64, -0.18), (0.24, 0.3, 0.01), C["paper"])
    a.box((-0.05, -0.68, -0.19), (0.12, 0.03, 0.01), C["leaf"])
    h = p["Head"]
    head_base(h, C["skin_tan"], jaw=(0.8, 0.88))
    for s in (-1, 1):   # bald on top, tufts at the sides
        h.box((s * (HEAD / 2 + 0.015), 0.27, 0.05), (0.04, 0.13, 0.26), C["grey_hair"])
    h.box((0, 0.27, HEAD / 2 + 0.015), (HEAD * 0.9, 0.13, 0.04), C["grey_hair"])
    # thick glasses, wide-open eyes with tiny pupils: the stare
    eyes(h, y=0.27, w=0.11, hgt=0.09, pupil=0.022, brow=C["grey_hair"], brow_rot=-8)
    glasses(h, y=0.27, thick=0.03)
    # the frozen grin: white teeth with dark gaps, lips
    h.box((0, 0.1, FZ - 0.012), (0.28, 0.085, 0.02), C["white"])
    h.box((0, 0.1, FZ - 0.006), (0.31, 0.11, 0.02), C["mouth"])
    for x in (-0.09, -0.03, 0.03, 0.09):
        h.box((x, 0.1, FZ - 0.024), (0.012, 0.085, 0.01), C["black"])
    h.box((0, 0.1, FZ - 0.024), (0.28, 0.01, 0.01), C["black"])

def sweeper(p):
    legs(p, C["porn_pants"], C["shoe"])
    arms(p, C["porn_shirt"], C["skin_brown"], length=0.95)   # gangly arms
    t = p["Torso"]
    torso(t, C["porn_shirt"], bottom=(1.08, 1.05))
    t.box((0, 0.27, -0.165), (0.46, 0.52, 0.02), C["apron"], bot=(1.1, 1))
    t.box((0, 0.2, -0.18), (0.2, 0.1, 0.015), C["apron_dark"])                   # pocket
    t.box((0, 0.56, -0.17), (0.3, 0.03, 0.02), C["apron_dark"])                  # apron strap
    a = p["ArmR"]   # mop
    a.box((0, -0.5, -0.15), (0.05, 1.7, 0.05), C["stick"])
    a.box((0, -1.35, -0.15), (0.36, 0.1, 0.22), C["mop"])
    a.box((0, -1.43, -0.15), (0.42, 0.08, 0.26), C["mop"], top=(0.9, 0.9))
    a = p["ArmL"]   # holy-water bowl with leaves
    a.box((0, -1.08, -0.02), (0.24, 0.06, 0.24), C["bowl"], bot=(0.7, 0.7))
    a.box((0, -1.05, -0.02), (0.18, 0.02, 0.18), C["water"])
    a.box((0.04, -1.0, 0.0), (0.04, 0.16, 0.02), C["leaf"], rot=(0, 0, -25))
    a.box((-0.03, -0.99, -0.03), (0.04, 0.14, 0.02), C["leaf"], rot=(0, 30, 20))
    h = p["Head"]
    head_base(h, C["skin_brown"], jaw=(0.84, 0.9))
    eyes(h, look=(0, 0.005), brow=C["black"], brow_rot=22)                       # angry
    h.box((0, 0.09, FZ - 0.01), (0.13, 0.08, 0.02), C["mouth"])                  # shouting
    h.box((0, 0.115, FZ - 0.016), (0.11, 0.025, 0.01), C["white"])
    h.box((0, HEAD - 0.01, 0.01), (HEAD + 0.05, 0.15, HEAD + 0.05), C["wrap"])   # head wrap
    h.box((0, HEAD * 0.55, HEAD / 2 + 0.03), (HEAD * 0.8, HEAD * 0.6, 0.05), C["wrap"])
    h.box((0, HEAD + 0.12, 0.08), (0.17, 0.12, 0.17), C["grey_hair"], top=(0.6, 0.6))   # bun

def goblin(p):
    legs(p, C["tae_pants"], C["shoe"])
    arms(p, C["hoodie"], C["skin_pale"], cuff=C["hoodie_dark"])
    t = p["Torso"]
    torso(t, C["hoodie"], bottom=(0.95, 1.0))
    t.box((0, 0.6, 0.12), (0.4, 0.18, 0.14), C["hoodie_dark"])                  # hood
    t.box((0, 0.18, -0.17), (0.36, 0.16, 0.02), C["hoodie_dark"])               # pocket
    for s in (-1, 1):
        t.box((s * 0.06, 0.45, -0.172), (0.025, 0.2, 0.015), C["white"])        # drawstrings
    t.box((0.12, 0.42, -0.17), (0.05, 0.05, 0.01), C["gold"])
    a = p["ArmL"]   # tangle of LAN cables
    for i, (col, r) in enumerate((("cable1", 30), ("cable2", -25), ("cable3", 60), ("cable1", -60))):
        a.box((0.05, -0.74 + i * 0.02, -0.12), (0.5, 0.025, 0.025), C[col], rot=(0, r, 8 * (i - 1.5)))
    h = p["Head"]
    head_base(h, C["skin_pale"], jaw=(0.84, 0.9))
    eyes(h, y=0.235, w=0.08, hgt=0.06, pupil=0.03, look=(0.025, -0.012))         # won't meet your eye
    glasses(h, y=0.235, frame="grey_hair", thick=0.016, round_=True)
    h.box((0, 0.11, FZ - 0.01), (0.07, 0.025, 0.02), C["mouth"])
    h.box((0, 0.1, FZ - 0.016), (0.04, 0.025, 0.01), C["white"])                # buck teeth
    h.box((0, HEAD + 0.06, 0.0), (HEAD + 0.08, 0.15, HEAD + 0.08), C["hair"], top=(0.85, 0.85))   # mop of hair
    h.box((0, HEAD - 0.06, FZ - 0.02), (HEAD + 0.06, 0.12, 0.06), C["hair"])     # fringe to the brows
    for s in (-1, 1):
        h.box((s * (HEAD / 2 + 0.025), HEAD * 0.62, 0.02), (0.05, HEAD * 0.55, HEAD + 0.04), C["hair"])
    h.box((0, HEAD * 0.6, HEAD / 2 + 0.03), (HEAD + 0.06, HEAD * 0.7, 0.05), C["hair"])

def guard(p):
    legs(p, C["navy"], C["shoe"])
    arms(p, C["navy"], C["skin_tan"])
    for s, n in ((-1, "ArmL"), (1, "ArmR")):
        p[n].box((0, 0.0, 0), (0.24, 0.05, 0.26), C["gold"])                    # epaulettes
    a = p["ArmR"]   # phone handset with a coiled cord
    a.box((0, -0.8, -0.1), (0.07, 0.24, 0.08), C["phone"])
    for i in range(5):
        a.box((0.05 * (i % 2), -0.95 - i * 0.05, -0.08), (0.04, 0.035, 0.04), C["phone"])
    t = p["Torso"]
    torso(t, C["navy"], bottom=(0.92, 0.96))
    t.box((0, 0.6, -0.15), (0.22, 0.08, 0.04), C["navy_dark"])                   # collar
    t.box((-0.15, 0.48, -0.17), (0.09, 0.11, 0.02), C["gold"])                   # badge
    t.box((0.15, 0.48, -0.17), (0.13, 0.04, 0.02), C["tag"])                     # name tag
    for s in (-1, 1):
        t.box((s * 0.15, 0.36, -0.168), (0.14, 0.1, 0.02), C["navy_dark"])        # pockets
    t.box((0, 0.04, 0), (0.58, 0.07, 0.34), C["black"])                          # belt
    t.box((0, 0.04, -0.175), (0.07, 0.05, 0.01), C["gold"])
    h = p["Head"]
    head_base(h, C["skin_tan"], jaw=(0.9, 0.92), chin=C["stubble"])
    eyes(h, y=0.24, w=0.09, hgt=0.06, pupil=0.035, brow=C["black"], brow_rot=4)   # blank stare
    h.box((0, 0.07, FZ - 0.004), (HEAD * 0.86, 0.14, 0.02), C["stubble"])          # stubble
    h.box((0, 0.145, FZ - 0.016), (0.14, 0.03, 0.015), C["hair"])                  # moustache
    h.box((0, 0.1, FZ - 0.018), (0.1, 0.02, 0.01), C["red"])
    h.box((0, HEAD + 0.05, 0.0), (HEAD + 0.07, 0.15, HEAD + 0.07), C["navy"], top=(1.04, 1.04))   # cap
    h.box((0, HEAD - 0.005, FZ - 0.08), (HEAD + 0.02, 0.035, 0.16), C["navy_dark"])          # brim
    h.box((0, HEAD + 0.07, FZ - 0.045), (0.07, 0.08, 0.02), C["gold"])                       # cap badge

def doctor(p):
    legs(p, C["scrubs"], C["white"], coat=C["coat"])
    arms(p, C["coat"], C["skin_tan"])
    t = p["Torso"]
    torso(t, C["coat"])
    t.box((0, 0.48, -0.165), (0.16, 0.26, 0.02), C["scrubs"], bot=(0.2, 1))
    t.box((0, 0.5, -0.17), (0.3, 0.03, 0.02), C["steth"], rot=(0, 0, 0))
    t.box((-0.1, 0.36, -0.175), (0.03, 0.26, 0.02), C["steth"])
    t.box((-0.1, 0.22, -0.18), (0.06, 0.06, 0.02), C["bowl"])
    t.box((0.15, 0.36, -0.168), (0.12, 0.12, 0.02), C["apron_dark"])
    h = p["Head"]
    head_base(h, C["skin_tan"])
    eyes(h, w=0.09, hgt=0.04, pupil=0.03, brow=C["hair"], brow_rot=0)            # smiling eyes
    h.box((0, 0.1, FZ - 0.01), (0.14, 0.03, 0.02), C["mouth"], bot=(0.6, 1))
    h.box((0, HEAD + 0.03, 0.02), (HEAD + 0.04, 0.08, HEAD + 0.04), C["hair"])
    for s in (-1, 1):
        h.box((s * (HEAD / 2 + 0.01), HEAD * 0.75, 0.04), (0.03, 0.12, HEAD * 0.8), C["hair"])

def dummy(p):   # tutorial: faceless office-training mannequin
    legs(p, C["dummy"], C["dummy_joint"])
    arms(p, C["dummy"], C["dummy"])
    for n in ("ArmL", "ArmR"):
        p[n].box((0, -0.33, 0), (0.2, 0.05, 0.22), C["dummy_joint"])           # elbow seams
    for n in ("LegL", "LegR"):
        p[n].box((0, -0.4, 0), (0.24, 0.05, 0.26), C["dummy_joint"])           # knee seams
    t = p["Torso"]
    torso(t, C["dummy"], bottom=(0.8, 0.9))
    t.box((0, 0.0, 0), (0.46, 0.05, 0.3), C["dummy_joint"])
    t.box((0.15, 0.45, -0.17), (0.14, 0.05, 0.015), C["tag"])                    # "visitor" tag
    h = p["Head"]
    h.box((0, HEAD / 2, 0), (HEAD * 0.85, HEAD * 1.1, HEAD * 0.9), C["dummy"], bot=(0.75, 0.8), top=(0.85, 0.9))
    h.box((0, HEAD * 0.35, FZ * 0.85 - 0.02), (0.05, 0.08, 0.05), C["dummy"])   # just a nose

CHARACTERS = {
    "tong": tong, "manager": manager, "sweeper": sweeper, "goblin": goblin,
    "guard": guard, "doctor": doctor, "dummy": dummy,
}
NECK = {"manager": 0.22}   # default neck length shown in Blender (the game sets its own)


# ---------------------------------------------------------------- scene assembly
def build(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = {}
    def mat(col):
        if col not in mats:
            m = bpy.data.materials.new("c_%02x%02x%02x" % tuple(int(round(x * 255)) for x in col))
            m.diffuse_color = (*lin(col), 1.0)
            m.use_nodes = True
            bsdf = m.node_tree.nodes.get("Principled BSDF")
            bsdf.inputs["Base Color"].default_value = (*lin(col), 1.0)
            bsdf.inputs["Roughness"].default_value = 1.0
            mats[col] = m
        return mats[col]
    names = ["LegL", "LegR", "ArmL", "ArmR", "Torso", "NeckMesh", "Head"]
    parts = {n: Part(n) for n in names}
    skin = {"manager": "skin_tan", "sweeper": "skin_brown", "goblin": "skin_pale", "guard": "skin_tan",
            "doctor": "skin_tan", "dummy": "dummy"}.get(name, "skin")
    parts["NeckMesh"].box((0, 0.5, 0), (0.14, 1.0, 0.14), C[skin])
    CHARACTERS[name](parts)
    coll = bpy.context.scene.collection
    pivots = {"LegL": (-0.13, HIP_Y, 0), "LegR": (0.13, HIP_Y, 0), "ArmL": (-0.37, SHOULDER_Y, 0),
              "ArmR": (0.37, SHOULDER_Y, 0), "Torso": (0, HIP_Y, 0)}
    objs = {}
    for n, pv in pivots.items():
        o = parts[n].obj(mat)
        o.location = g2b(pv)
        coll.objects.link(o)
        objs[n] = o
    neck = bpy.data.objects.new("Neck", None)
    neck.empty_display_size = 0.1
    neck.location = g2b((0, NECK_Y, 0))
    coll.objects.link(neck)
    nl = NECK.get(name, 0.1)
    nm = parts["NeckMesh"].obj(mat)
    nm.parent = neck
    nm.scale = (1, 1, nl)
    coll.objects.link(nm)
    hd = parts["Head"].obj(mat)
    hd.parent = neck
    hd.location = (0, 0, nl)
    coll.objects.link(hd)
    os.makedirs(OUT, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0   # no .blend1 backups
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, name + ".blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                              export_yup=True, export_apply=False, export_materials="EXPORT")
    print("built", name)

def preview(name, out_dir):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"   # lit, so the sculpted depth shows
    scn.display.shading.color_type = "MATERIAL"
    scn.display.shading.show_shadows = True
    scn.display.shading.show_cavity = True
    scn.view_settings.view_transform = "Standard"
    scn.render.resolution_x, scn.render.resolution_y = 360, 480
    scn.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.color = (0.05, 0.05, 0.07)
    scn.world = world
    for tag, pos, at in (("front", (0.0, 4.6, 1.0), 1.0), ("side", (3.2, 3.2, 1.1), 1.0), ("face", (0.6, 1.6, 1.85), 1.7)):
        cam_data = bpy.data.cameras.new("cam")
        cam_data.lens = 70
        cam = bpy.data.objects.new("cam", cam_data)
        scn.collection.objects.link(cam)
        cam.location = pos
        d = Vector((0, 0, at)) - Vector(pos)
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        scn.camera = cam
        scn.render.filepath = os.path.join(out_dir, "%s_%s.png" % (name, tag))
        bpy.ops.render.render(write_still=True)

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    prev = None
    if "--preview" in argv:
        i = argv.index("--preview")
        prev = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    for n in (argv or list(CHARACTERS)):
        build(n)
        if prev:
            preview(n, prev)
