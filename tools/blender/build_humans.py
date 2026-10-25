# Realistic characters for the HD remaster, built from the MakeHuman base mesh (CC0: see
# tools/makehuman/LICENSE.ASSETS.md). Body shape from the MakeHuman macro targets (Asian, gender,
# age, muscle, weight, height), clothes as shells of the body's own surface, hair from the hair
# helper, eyes and teeth from the eye/teeth helpers, skin detail in vertex colours. One skinned mesh
# on a 7-bone rig that body.gd drives exactly like the old rigid parts:
#   Torso > LegL, LegR, ArmL, ArmR, Neck > Head   (every bone points up: identity rest rotations)
# Output: assets/characters/real/<name>.glb (+ .blend). Faces -Z (Godot forward).
#   python tools/blender/build_humans.py -- tong manager_night     (bpy pip module, or blender -b -P)
import bpy
import json
import math
import os
import sys

import numpy as np
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MH = os.path.join(ROOT, "tools", "makehuman")
OUT = os.path.join(ROOT, "assets", "characters", "real")
BONES = ["Torso", "LegL", "LegR", "ArmL", "ArmR", "Neck", "Head"]
PARENT = {"LegL": "Torso", "LegR": "Torso", "ArmL": "Torso", "ArmR": "Torso", "Neck": "Torso", "Head": "Neck"}


def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


# ---------------------------------------------------------------- MakeHuman data
def load_obj():
    verts, faces = [], []
    group = None
    for line in open(os.path.join(MH, "base.obj")):
        if line.startswith("v "):
            verts.append([float(x) for x in line.split()[1:4]])
        elif line.startswith("g "):
            group = line.split()[1]
        elif line.startswith("f "):
            faces.append((group, [int(t.split("/")[0]) - 1 for t in line.split()[1:]]))
    return np.array(verts), faces


_targets = {}
def target(name):
    if name not in _targets:
        rows = [l.split() for l in open(os.path.join(MH, "targets", name + ".target")) if l.strip() and not l.startswith("#")]
        a = np.array(rows, dtype=float).reshape(-1, 4)   # (the average/average targets are empty)
        _targets[name] = (a[:, 0].astype(int), a[:, 1:4])
    return _targets[name]


def shape(V, s):
    """MakeHuman macro targets, weighted the way its sliders mix them."""
    V = V.copy()
    g = s["gender"]
    old = s.get("old", 0.0)
    m = s.get("muscle", 0.0)
    w = s.get("weight", 0.0)

    def add(name, k):
        if k > 1e-4:
            idx, d = target(name)
            V[idx] += d * k
    for age, ka in (("young", 1.0 - old), ("old", old)):
        add("asian-%s-%s" % (g, age), ka)
        for mn, km in (("averagemuscle", 1 - abs(m)), ("maxmuscle" if m > 0 else "minmuscle", abs(m))):
            for wn, kw in (("averageweight", 1 - abs(w)), ("maxweight" if w > 0 else "minweight", abs(w))):
                add("universal-%s-%s-%s-%s" % (g, age, mn, wn), ka * km * kw)
    h = s.get("height", 0.0)
    if h:
        add("%s-young-averagemuscle-averageweight-%s" % (g, "maxheight" if h > 0 else "minheight"), abs(h))
    return V


CURL_SIGN = 1.0

def rotate(v, axis, a):   # Rodrigues
    return v * math.cos(a) + np.cross(axis, v) * math.sin(a) + axis * np.dot(axis, v) * (1 - math.cos(a))


def coarse(bone):
    side = bone[-1] if bone[-2:] in (".L", ".R") else ""
    base = bone.split(".")[0]
    if base.startswith(("upperleg", "lowerleg", "foot", "toe")):
        return "Leg" + side
    if base.startswith(("shoulder", "upperarm", "lowerarm", "wrist", "finger", "metacarpal")):
        return "Arm" + side
    if base.startswith("neck"):
        return "Neck"
    if base in ("root", "pelvis", "clavicle", "breast") or base.startswith("spine"):
        return "Torso"
    return "Head"


# ---------------------------------------------------------------- the build
class Human:
    def __init__(self, name, spec):
        self.name, self.s = name, spec
        V0, self.faces = load_obj()
        V = shape(V0, spec)
        skel = json.load(open(os.path.join(MH, "default.mhskel")))
        J = {k: V[v].mean(0) for k, v in skel["joints"].items()}
        self.J = lambda b, end="head": J[skel["bones"][b][end]]
        # weights: MakeHuman's 163 bones folded into our 7
        W = np.zeros((len(V), len(BONES)))
        Wf = {"L": np.zeros(len(V)), "R": np.zeros(len(V)), "TL": np.zeros(len(V)), "TR": np.zeros(len(V))}   # fingers, thumbs
        for bone, pairs in json.load(open(os.path.join(MH, "default_weights.mhw")))["weights"].items():
            c = BONES.index(coarse(bone))
            for vi, wt in pairs:
                W[vi, c] += wt
            if bone.startswith("finger"):
                key = ("T" if bone.startswith("finger1") else "") + bone[-1]
                for vi, wt in pairs:
                    Wf[key][vi] += wt
        body = sorted({i for g, f in self.faces if g == "body" for i in f})
        bodyset = np.array(body)
        unweighted = np.where(W.sum(1) < 1e-6)[0]
        if len(unweighted):   # helpers (hair, eyes, teeth...): copy from the nearest body vertex
            from mathutils import kdtree
            kd = kdtree.KDTree(len(body))
            for i in body:
                kd.insert(V[i], i)
            kd.balance()
            for i in unweighted:
                W[i] = W[kd.find(V[i])[1]]
        W /= np.maximum(W.sum(1, keepdims=True), 1e-6)
        # arms down from MakeHuman's A-pose, to hang by the sides (6 degrees out)
        for side, sign in (("L", 1.0), ("R", -1.0)):
            sh = self.J("upperarm01." + side)
            wr = self.J("wrist." + side)
            d = wr - sh
            ang = math.atan2(abs(d[0]), -d[1]) - math.radians(6)
            k = W[:, BONES.index("Arm" + side)]
            a = -sign * ang * k
            x, y = V[:, 0] - sh[0], V[:, 1] - sh[1]
            V[:, 0] = np.where(k > 0, sh[0] + x * np.cos(a) - y * np.sin(a), V[:, 0])
            V[:, 1] = np.where(k > 0, sh[1] + x * np.sin(a) + y * np.cos(a), V[:, 1])
        Js = {k: V[v].mean(0) for k, v in skel["joints"].items()}   # joints with the arms down
        Jsw = lambda b: Js[skel["bones"][b]["head"]]
        # relaxed hands: the fingers curl in about the knuckle line, the thumb a little
        for side in "LR":
            k1, k2 = Jsw("finger2-1." + side), Jsw("finger5-1." + side)
            axis = (k2 - k1) / np.linalg.norm(k2 - k1)
            piv = (k1 + k2) / 2
            for key, ang in ((side, spec.get("curl", 0.9)), ("T" + side, spec.get("curl", 0.9) * 0.35)):
                k = np.clip(Wf[key], 0, 1)
                sel = np.where(k > 0.01)[0]
                for i in sel:
                    V[i] = piv + rotate(V[i] - piv, axis, ang * k[i] * (1 if side == "L" else -1) * CURL_SIGN)
        self.ymin = V[bodyset, 1].min()
        self.V, self.W = V, W
        J2 = {k: V[v].mean(0) for k, v in skel["joints"].items()}   # joints after the arm swing
        self.J = lambda b, end="head": J2[skel["bones"][b][end]]
        self.normals = self._normals()

    # MakeHuman (decimetres, +Z forward) -> Godot (metres, feet on 0, facing -Z)
    def g(self, p):
        return np.array([-p[0] * 0.1, (p[1] - self.ymin) * 0.1, -p[2] * 0.1])

    def _normals(self):
        N = np.zeros_like(self.V)
        for grp, f in self.faces:
            if grp.startswith("joint-"):
                continue
            p = self.V[f]
            n = np.cross(p[1] - p[0], p[2] - p[0])
            for i in f:
                N[i] += n
        return N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)


def build(name):
    spec = CHARS[name]
    h = Human(name, spec)
    V, W, J = h.V, h.W, h.J
    pal = {k: rgb(v) for k, v in PAL.items()}
    pal.update({k: rgb(v) for k, v in spec.get("colors", {}).items()})
    rng = np.random.default_rng(abs(hash(name)) % 2 ** 32)

    # landmarks (MakeHuman space)
    neck_y = J("neck01")[1]
    waist_y = J("spine03")[1] - 0.15
    ankle_y = J("foot.L")[1] + 0.35
    eye_l, eye_r = J("eye.L"), J("eye.R")
    mouth = np.array([0.0, 6.6, 1.55]) + (J("jaw") - np.array([0, 6.88, 0.64])) * np.array([0, 1, 1])
    wrist = {s: J("wrist." + s) for s in "LR"}
    shoulder = {s: J("upperarm01." + s) for s in "LR"}

    # ---- one mesh: lists of (polygon, material, per-vertex colours, layer offset)
    out_v, out_w, out_c, polys, mats = [], [], [], [], []
    mat_names = []
    remap_cache = {}

    def mat_index(m):
        if m not in mat_names:
            mat_names.append(m)
        return mat_names.index(m)

    def add_poly(f, m, color_fn, offset=0.0, pos=None):
        mi = mat_index(m)
        key = (m, offset)
        cache = remap_cache.setdefault(key, {})
        idx = []
        for i in f:
            if i not in cache:
                p = (pos[i] if pos is not None else V[i]) + h.normals[i] * offset
                cache[i] = len(out_v)
                out_v.append(h.g(p))
                out_w.append(W[i])
                out_c.append(color_fn(i))
            idx.append(cache[i])
        polys.append(idx)
        mats.append(mi)

    dom = W.argmax(1)
    def collar(c):   # the shirt's neckline: higher at the back, an open collar at the front
        front = np.clip(c[2] / 1.0, 0.0, 1.0)
        return J("neck01")[1] + 0.1 - 0.55 * front
    def region(f):
        """What a body face is: head/neck/hand/foot/torso/arm/leg (+ clothing cut lines)."""
        c = V[f].mean(0)
        b = BONES[np.bincount(dom[f], minlength=7).argmax()]
        if b in ("Head", "Neck") or (b == "Torso" and c[1] > collar(c)):
            return "neck" if c[1] < J("head")[1] - 0.05 else "head"
        if b.startswith("Arm"):
            s = b[-1]
            reach = np.linalg.norm(c - shoulder[s]) / np.linalg.norm(wrist[s] - shoulder[s])
            if reach > 0.97:
                return "hand"
            return "arm_upper" if reach < spec.get("sleeve", 1.0) * 0.55 else ("arm" if reach < spec.get("sleeve", 1.0) * 0.97 else "forearm_bare")
        if b.startswith("Leg"):
            return "foot" if c[1] < ankle_y else "leg"
        return "torso_low" if c[1] < waist_y else "torso"

    skin = pal[spec.get("skin", "skin")]
    def skin_color(i):
        p = V[i]
        col = skin * (1.0 + rng.normal() * 0.025)
        # lips, brows, eye shadow, stubble: painted by distance to the landmarks
        dm = np.array([(p[0]) / 0.27, (p[1] - mouth[1]) / 0.07, 0])
        if p[2] > mouth[2] - 0.25 and np.linalg.norm(dm) < 1.0:
            col = col * 0.75 + pal["lips"] * 0.25 if not spec.get("lipstick") else pal["lipstick"]
        for e in (eye_l, eye_r):
            d = p - e
            if p[2] > e[2] - 0.1 and abs(d[0]) < 0.2 and 0.1 < d[1] < 0.2:
                col = pal[spec.get("brow", "hair")] * 0.9   # eyebrows
            elif p[2] > e[2] - 0.15 and abs(d[0]) < 0.24 and -0.18 < d[1] < 0.02:
                col = col * (1.0 - spec.get("sunken", 0.12))   # under the eyes
        if spec.get("stubble") and p[1] < mouth[1] + 0.05 and p[1] > J("neck03")[1] and p[2] > 0.4:
            col = col * 0.82 + pal["stubble"] * 0.18
        for grin in spec.get("grin", []):   # night: a mouth that keeps going
            gx = abs(p[0]) / grin["w"]
            gy = (p[1] - mouth[1] - grin.get("rise", 0.0) * gx * gx) / grin["h"]
            if p[2] > 0.6 and gx < 1.0 and abs(gy) < 1.0:
                col = pal["socket"] if abs(gy) < 0.55 else pal["blood"]
        return np.clip(col, 0, 1)

    def flat(c, var=0.03):
        return lambda i: np.clip(c * (1.0 + rng.normal() * var), 0, 1)

    shirt, pants, shoes = pal[spec["shirt"]], pal[spec["pants"]], pal[spec.get("shoes", "shoe")]
    blood_spots = [V[j] for j in rng.choice(len(V), size=spec.get("blood", 0), replace=False)] if spec.get("blood") else []
    def cloth(c):
        def fn(i):
            col = c * (1.0 + rng.normal() * 0.02)
            for b in blood_spots:
                if np.linalg.norm(V[i] - b) < 0.55:
                    col = col * 0.35 + pal["blood"] * 0.65
            return np.clip(col, 0, 1)
        return fn

    # body faces -> skin, or a garment: the garment is the body's own surface, smoothed (no
    # anatomy showing through the cloth) and pushed out, so it hangs a little loose
    which = {}
    for k, (grp, f) in enumerate(h.faces):
        if grp != "body":
            continue
        r = region(f)
        if r in ("head", "neck", "hand", "forearm_bare"):
            which[k] = "skin"
        elif r == "foot":
            which[k] = "shoes"
        elif r in ("torso", "arm", "arm_upper"):
            which[k] = "shirt"
        else:
            which[k] = "skin" if (spec.get("bare_legs") and r == "leg") else "pants"
    shells = {}
    for garment, iters in (("shirt", 30), ("pants", 22), ("shoes", 60)):
        fs = [h.faces[k][1] for k, w in which.items() if w == garment]
        if fs:
            shells[garment] = smooth_shell(V, fs, iters, garment != "shoes")
    if "shoes" in shells:   # flat soles on the floor, a little longer and wider than the foot
        sp = shells["shoes"]
        for i in sp:
            sp[i][1] = max(sp[i][1], h.ymin + 0.03)
    LOOSE = {"shirt": spec.get("loose", 0.12), "pants": 0.12, "shoes": 0.3}
    for k, w in which.items():
        f = h.faces[k][1]
        if w in ("shirt", "pants"):   # a backing in the garment's colour on the skin: no see-through seams
            add_poly(f, w, cloth(shirt if w == "shirt" else pants), 0.0)
        if w == "skin":
            add_poly(f, "skin", skin_color)
        elif w == "shoes":
            add_poly(f, "shoes", flat(shoes, 0.02), LOOSE["shoes"], shells["shoes"])
        elif w == "shirt":
            add_poly(f, "shirt", cloth(shirt), LOOSE["shirt"], shells["shirt"])
        else:
            add_poly(f, "pants", cloth(pants), LOOSE["pants"], shells["pants"])
    for grp, f in h.faces:
        if grp == "body":
            continue
        elif grp in ("helper-l-eye", "helper-r-eye"):
            e = eye_l if grp.endswith("l-eye") else eye_r
            def eye_color(i, e=e):
                d = V[i] - e
                fwd = d[2] / max(np.linalg.norm(d), 1e-6)
                if spec.get("no_eyes"):
                    return skin * 0.9
                if fwd > 0.93:
                    return pal[spec.get("pupil", "pupil")]
                if fwd > 0.82:
                    return pal[spec.get("iris", "iris")]
                return pal[spec.get("sclera", "sclera")]
            m = "eye"
            if spec.get("glow_eyes"):   # the pupils glow (material named after the colour: body.gd reads it)
                cc = V[f].mean(0) - e
                if cc[2] / max(np.linalg.norm(cc), 1e-6) > 0.8:
                    m = "glow_" + PAL[spec.get("pupil", "glow")].lower()
            add_poly(f, m, eye_color)
        elif grp in ("helper-upper-teeth", "helper-lower-teeth"):
            add_poly(f, "teeth", flat(pal["teeth"], 0.02))
        elif grp == "helper-hair":
            pass   # (the hair is built from the scalp below: the helper is too coarse)
        elif grp == "helper-skirt" and spec.get("skirt"):
            c = V[f].mean(0)
            if c[1] > spec["skirt"]:
                add_poly(f, "skirt", cloth(pal[spec.get("skirt_color", spec["pants"])]))

    # ---- hair: a shell over the scalp (the body's own surface), then for longer styles a fringe
    # of hair hanging from its edge
    style = spec.get("hair", "short")
    if style != "none":
        ey = eye_l[1]
        def on_scalp(c):
            if style == "bald":   # a horseshoe round the back and sides
                return c[1] > ey + 0.1 and c[1] < ey + 0.75 and c[2] < 0.7
            if style == "cap":
                return c[1] > ey + 0.35
            hairline = c[1] > ey + 0.4 and not (c[2] > 0.95 and c[1] < ey + 0.78)
            back = c[2] < 0.25 and c[1] > mouth[1] + 0.35
            sides = abs(c[0]) > 0.72 and c[2] < 0.75 and c[1] > ey - 0.05
            return hairline or back or sides
        hd = W[:, BONES.index("Head")] > 0.5
        scalp = [f for k, (grp, f) in enumerate(h.faces) if grp == "body" and hd[f].all() and on_scalp(V[f].mean(0))]
        if scalp:
            hp = smooth_shell(V, scalp, 12)
            hc = flat(pal[spec.get("hair_color", "hair")], 0.06)
            lift = spec.get("hair_lift", 0.09)
            for f in scalp:
                add_poly(f, "hair", hc, lift, hp)
            drop = {"bob": 1.1, "long": 2.6, "curtain": 2.6}.get(style, 0.0)
            if drop:
                _hair_drape(h, scalp, hp, lift, drop, style == "curtain", pal[spec.get("hair_color", "hair")],
                            out_v, out_w, out_c, polys, mats, mat_index, rng)

    # ---- props: rigid boxes on one bone (tie, cap, badge, mask, mop...)
    for p in spec.get("props", []):
        _box_prop(p, h, pal, out_v, out_w, out_c, polys, mats, mat_index)

    # ---- Blender objects
    bpy.ops.wm.read_factory_settings(use_empty=True)
    coll = bpy.context.scene.collection
    arm_data = bpy.data.armatures.new(name + "_rig")
    rig = bpy.data.objects.new("Armature", arm_data)
    coll.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    heads = {
        "Torso": J("spine05"), "LegL": J("upperleg01.L"), "LegR": J("upperleg01.R"),
        "ArmL": J("upperarm01.L"), "ArmR": J("upperarm01.R"), "Neck": J("neck01"), "Head": J("head"),
    }
    eb = {}
    for b in BONES:
        e = arm_data.edit_bones.new(b)
        gp = h.g(heads[b])
        e.head = Vector((gp[0], -gp[2], gp[1]))
        e.tail = e.head + Vector((0, 0, 0.12))   # every bone points up: identity rest rotation
        e.roll = 0.0
        eb[b] = e
    for b, par in PARENT.items():
        eb[b].parent = eb[par]
    bpy.ops.object.mode_set(mode="OBJECT")

    me = bpy.data.meshes.new(name)
    me.from_pydata([Vector((p[0], -p[2], p[1])) for p in out_v], [], polys)
    me.validate()
    for mname in mat_names:
        m = bpy.data.materials.new(mname)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        attr = m.node_tree.nodes.new("ShaderNodeVertexColor")
        m.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = {"skin": 0.55, "eye": 0.15, "eye_glow": 0.2, "teeth": 0.3, "hair": 0.6, "shoes": 0.35}.get(mname, 0.85)
        me.materials.append(m)
    for poly, mi in zip(me.polygons, mats):
        poly.material_index = mi
        poly.use_smooth = True
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, c in enumerate(out_c):
        col.data[i].color = (*[float(x) for x in c], 1.0)
    body = bpy.data.objects.new(name, me)
    coll.objects.link(body)
    for bi, b in enumerate(BONES):
        vg = body.vertex_groups.new(name=b)
        for i, w in enumerate(out_w):
            if w[bi] > 0.002:
                vg.add([i], float(w[bi]), "REPLACE")
    body.parent = rig
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    os.makedirs(OUT, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, name + ".blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", export_yup=True,
                              export_apply=False, export_skins=True, export_animations=False,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("built", name, len(out_v), "verts", mat_names)


def _hair_drape(h, scalp, hp, lift, drop, over_face, color, out_v, out_w, out_c, polys, mats, mat_index, rng):
    """Hair hanging from the scalp shell's edge: a strip from each edge vertex down `drop`
    decimetres, flaring out a little. over_face: the front edge too (night: wet hair over the face)."""
    use = {}
    for f in scalp:
        n = len(f)
        for a in range(n):
            e = tuple(sorted((f[a], f[(a + 1) % n])))
            use[e] = use.get(e, 0) + 1
    edges = [e for e, c in use.items() if c == 1]
    mi = mat_index("hair")
    top, bot = {}, {}
    cx = np.array([0.0, h.J("head")[1] + 0.6, 0.15])
    for e in edges:
        for i in e:
            if i in top:
                continue
            p = hp[i] + h.normals[i] * lift
            front = p[2] > 0.85
            if front and not over_face:
                continue
            out = p - cx
            out[1] = 0.0
            out = out / max(np.linalg.norm(out), 1e-6)
            fz = np.clip((p[2] - 0.2) / 0.9, 0.0, 1.0)   # shorter toward the face
            length = drop * (1.0 - 0.35 * fz) - (p[1] - (h.J("eye.L")[1] - 0.1)) * 0.6   # ends level, wherever it starts
            q = p + out * 0.25 + np.array([0.0, -max(length, 0.3), 0.0])
            w = h.W[i]
            top[i] = len(out_v)
            out_v.append(h.g(p)); out_w.append(w); out_c.append(color)
            bot[i] = len(out_v)
            out_v.append(h.g(q)); out_w.append(w); out_c.append(color * 0.85)
    for a, b in edges:
        if a in top and b in top:
            for f in ([top[a], top[b], bot[b], bot[a]], [top[a], bot[a], bot[b], top[b]]):   # both sides
                polys.append(f)
                mats.append(mi)


def smooth_shell(V, faces, iters, taubin=True):
    """Laplacian-smoothed copy of the vertices these faces use (neighbours within the set).
    taubin: keep the volume (clothes, hair); off: shrink-smooth into a rounder blob (shoes)."""
    nb = {}
    for f in faces:
        n = len(f)
        for a in range(n):
            i, j = f[a], f[(a + 1) % n]
            nb.setdefault(i, set()).add(j)
            nb.setdefault(j, set()).add(i)
    keys = list(nb)
    # edge of the garment (an edge used by only one face): pinned, so the cuffs and hems don't
    # shrink away from the skin and leave a gap
    edge_use = {}
    for f in faces:
        n = len(f)
        for a in range(n):
            e = tuple(sorted((f[a], f[(a + 1) % n])))
            edge_use[e] = edge_use.get(e, 0) + 1
    rim = {i for e, c in edge_use.items() if c == 1 for i in e}
    pos = {i: V[i].copy() for i in keys}
    for it in range(iters * 2):   # Taubin (shrink, then grow back): smooths without sinking into the body
        k = 0.5 if (it % 2 == 0 or not taubin) else -0.53
        new = {}
        for i in keys:
            if i in rim:
                new[i] = pos[i]
                continue
            m = np.mean([pos[j] for j in nb[i]], axis=0)
            new[i] = pos[i] + (m - pos[i]) * k
        pos = new
    return pos


def anchor(h, name):
    """Points on the body (Godot metres) props attach to."""
    V, W = h.V, h.W
    hd = W[:, BONES.index("Head")] > 0.6
    if name == "head_top":
        i = np.where(hd)[0][np.argmax(V[hd, 1])]
        return h.g(V[i])
    if name == "sternum":   # the front of the chest, a hand below the collar
        y0 = h.J("neck01")[1]
        sel = np.where((np.abs(V[:, 0]) < 0.15) & (V[:, 1] < y0 - 0.5) & (V[:, 1] > y0 - 1.3) & (W[:, 0] > 0.5))[0]
        return h.g(V[sel[np.argmax(V[sel, 2])]])
    if name == "face":   # the front of the face at the mouth
        sel = np.where(hd & (np.abs(V[:, 0]) < 0.1) & (np.abs(V[:, 1] - 6.7) < 0.2))[0]
        return h.g(V[sel[np.argmax(V[sel, 2])]])
    return h.g(h.J(name))


def _box_prop(p, h, pal, out_v, out_w, out_c, polys, mats, mat_index):
    """p = {bone, anchor (a point on the body: anchor()) or joint, at (Godot metres from it), size, color, mat}"""
    bi = BONES.index(p["bone"])
    base = anchor(h, p["anchor"]) if "anchor" in p else (h.g(h.J(p["joint"])) if "joint" in p else np.zeros(3))
    c = base + np.array(p.get("at", [0, 0, 0]))
    s = np.array(p["size"]) / 2
    rot = p.get("rot", 0.0)
    corners = []
    for x, y, z in ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1), (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)):
        v = np.array([x, y, z]) * s
        if rot:
            ca, sa = math.cos(rot), math.sin(rot)
            v = np.array([v[0], v[1] * ca - v[2] * sa, v[1] * sa + v[2] * ca])
        corners.append(c + v)
    first = len(out_v)
    w = np.zeros(len(BONES))
    w[bi] = 1.0
    col = pal[p["color"]]
    for v in corners:
        out_v.append(v)
        out_w.append(w)
        out_c.append(col)
    mi = mat_index(p.get("mat", "prop"))
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        polys.append([first + i for i in f])
        mats.append(mi)


# ---------------------------------------------------------------- palette + characters
PAL = {
    "skin": "c99a7c", "skin_tan": "b98262", "skin_brown": "8f5e42", "skin_pale": "d8b49a",
    "lips": "a2564e", "lipstick": "a3141f", "stubble": "4a3a30", "hair": "141217", "grey_hair": "6b676d",
    "sclera": "e6e2d8", "iris": "3a2a1e", "pupil": "070608", "teeth": "e7e1cf", "shoe": "17151a",
    "tong_shirt": "a9c4e0", "tong_pants": "2c3346", "tie": "1e2a52", "lanyard": "c8336e", "badge": "eeeeea",
    "suit": "4e525e", "mgr_pants": "3e4048", "white": "ececE6", "porn_shirt": "c25a83", "apron": "dcdcd6",
    "porn_pants": "48474f", "hoodie": "4f3487", "tae_pants": "25242c", "navy": "1d2a50", "gold": "c9a334",
    "coat": "eeeeec", "scrubs": "45807f", "maroon": "6a1f2e", "skirt": "2a2830", "blouse": "e8e2d6",
    "mop": "6e4a26", "mask": "9cc2c0", "silver": "b8bcc0", "board": "8a5a2e", "paper": "efede4",
    # night
    "dead": "8a9484", "corpse": "7e909a", "ghost": "c9cdc4", "guard_dark": "6e5038",
    "blood": "5e0709", "socket": "060507", "glow": "fff2c8", "glow_red": "ff2a18", "glow_cyan": "3ae6ff",
    "milk": "d0e6de", "staff_shirt": "bfc3cb", "staff_pants": "30333a", "rot": "4a3f2c",
}
TIE = {"bone": "Torso", "anchor": "sternum", "at": [0, -0.03, -0.024], "size": [0.065, 0.36, 0.012], "color": "tie"}
BADGE = {"bone": "Torso", "anchor": "sternum", "at": [-0.09, -0.12, -0.024], "size": [0.055, 0.08, 0.006], "color": "badge"}
VISOR = {"bone": "Head", "anchor": "head_top", "at": [0, -0.075, -0.125], "size": [0.18, 0.012, 0.08], "color": "navy", "rot": -0.25}

CHARS = {
    "tong": {"gender": "male", "weight": -0.2, "muscle": -0.2, "height": -0.1, "shirt": "tong_shirt", "pants": "tong_pants",
             "props": [TIE, BADGE]},
    "manager": {"gender": "male", "old": 0.45, "weight": 0.55, "height": -0.3, "shirt": "suit", "pants": "mgr_pants",
                "skin": "skin_tan", "hair": "bald", "props": [dict(TIE, color="lipstick")]},
    "manager_night": {"gender": "male", "old": 0.45, "weight": 0.55, "height": -0.3, "shirt": "suit", "pants": "mgr_pants",
                      "skin": "dead", "hair": "bald", "sunken": 0.45, "grin": [{"w": 0.62, "h": 0.07, "rise": 0.25}],
                      "props": [dict(TIE, color="lipstick")], "blood": 3, "glow_eyes": True, "pupil": "glow", "iris": "socket", "sclera": "socket"},
    "sweeper": {"gender": "female", "old": 0.8, "weight": 0.35, "height": -0.4, "shirt": "porn_shirt", "pants": "porn_pants",
                "skin": "skin_brown", "hair": "bob", "hair_color": "grey_hair"},
    "sweeper_night": {"gender": "female", "old": 0.8, "weight": 0.35, "height": -0.4, "shirt": "porn_shirt", "pants": "porn_pants",
                      "skin": "corpse", "hair": "curtain", "hair_color": "hair", "hair_lift": 0.09, "sunken": 0.5, "blood": 2,
                      "glow_eyes": True, "pupil": "milk", "iris": "milk", "sclera": "milk"},
    "goblin": {"gender": "male", "weight": -0.6, "muscle": -0.5, "height": -0.2, "shirt": "hoodie", "pants": "tae_pants",
               "skin": "skin_pale", "hair": "short"},
    "goblin_night": {"gender": "male", "weight": -0.8, "muscle": -0.6, "height": -0.2, "shirt": "hoodie", "pants": "tae_pants",
                     "skin": "ghost", "hair": "long", "hair_color": "hoodie", "hair_lift": 0.12, "sunken": 0.4,
                     "glow_eyes": True, "pupil": "glow_cyan", "iris": "glow_cyan", "sclera": "socket"},
    "guard": {"gender": "male", "muscle": 0.4, "weight": 0.2, "height": 0.25, "shirt": "navy", "pants": "navy", "stubble": True,
              "skin": "skin_tan", "hair": "cap", "hair_color": "navy", "hair_lift": 0.14, "props": [VISOR, dict(BADGE, color="gold")]},
    "guard_night": {"gender": "male", "muscle": 0.4, "weight": 0.2, "height": 0.25, "shirt": "navy", "pants": "navy", "stubble": True,
                    "skin": "guard_dark", "hair": "cap", "hair_color": "navy", "hair_lift": 0.14, "props": [VISOR, dict(BADGE, color="gold")], "blood": 4, "sunken": 0.5,
                    "grin": [{"w": 0.3, "h": 0.05, "rise": 0.1}], "glow_eyes": True, "pupil": "glow_red", "iris": "socket", "sclera": "socket"},
    "hr": {"gender": "female", "old": 0.25, "weight": 0.1, "shirt": "maroon", "pants": "skirt", "skirt": -1.6, "bare_legs": True,
           "skin": "skin_pale", "hair": "bob", "lipstick": True},
    "hr_night": {"gender": "female", "old": 0.25, "weight": 0.1, "shirt": "maroon", "pants": "skirt", "skirt": -1.6, "bare_legs": True,
                 "skin": "ghost", "hair": "bob", "lipstick": True, "sunken": 0.4, "grin": [{"w": 0.55, "h": 0.045, "rise": 0.3}],
                 "glow_eyes": True, "pupil": "glow", "iris": "socket", "sclera": "socket"},
    "doctor": {"gender": "male", "old": 0.3, "shirt": "coat", "pants": "scrubs", "skin": "skin_tan", "hair": "short",
               "skirt": -2.6, "skirt_color": "coat"},
    "doctor_night": {"gender": "male", "old": 0.3, "shirt": "coat", "pants": "scrubs", "skin": "ghost", "hair": "short",
                     "skirt": -2.6, "skirt_color": "coat", "blood": 5, "no_eyes": True,
                     "props": [{"bone": "Head", "anchor": "face", "at": [0, 0.01, 0.01], "size": [0.15, 0.1, 0.04], "color": "mask"}]},
    "staff": {"gender": "male", "weight": -0.3, "shirt": "staff_shirt", "pants": "staff_pants", "skin": "ghost", "hair": "none", "no_eyes": True,
              "sunken": 0.0},
    "dummy": {"gender": "male", "shirt": "skin", "pants": "skin", "shoes": "skin", "skin": "apron", "hair": "none", "no_eyes": True,
              "colors": {"skin": "c9b9a0"}},
}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for n in (argv or list(CHARS)):
        build(n)
