#!/usr/bin/env python3
"""Builds the NPC body data from the MakeHuman base mesh (all inputs CC0).

Downloads (or reads from --src) the MakeHuman 1.x base mesh, macro targets,
default skeleton and weights, and writes, per sex:
  godot/npc/models/mh_<sex>.bin   float32/int32 blocks (see meta)
  godot/npc/models/mh_<sex>.json  layout, bone rest positions, landmarks
NpcBodyMesh turns these into a skinned ArrayMesh with LODs at runtime.

Run from the repo root:  python3 godot/npc/tools/build_mh_body.py --src /tmp/mh
"""
import argparse, json, math, os, struct, urllib.request
import numpy as np

RAW = "https://raw.githubusercontent.com/makehumancommunity/makehuman/master/makehuman/data/"
OUT = "godot/npc/models"
RACES = ["caucasian", "african", "asian"]

# MakeHuman bone -> NPC skeleton bone (see NpcBodyMesh.BONES).
def map_bone(n):
    side = "_L" if n.endswith(".L") else ("_R" if n.endswith(".R") else "")
    b = n[:-2] if side else n
    if b in ("root", "spine05", "pelvis"): return "pelvis"
    if b in ("spine04", "spine03"): return "spine"
    if b in ("spine02", "spine01", "breast", "clavicle"): return "chest"
    if b in ("neck01", "neck02", "neck03"): return "neck"
    if b in ("upperleg01", "upperleg02"): return "thigh" + side
    if b in ("lowerleg01", "lowerleg02"): return "shin" + side
    if b == "foot" or b.startswith("toe"): return "foot" + side
    if b in ("shoulder01", "upperarm01", "upperarm02"): return "upperarm" + side
    if b in ("lowerarm01", "lowerarm02"): return "forearm" + side
    if b in ("wrist",) or b.startswith("metacarpal"): return "hand" + side
    if b.startswith("finger"):
        f, seg = b[6:].split("-")
        name = ["thumb", "index", "middle", "ring", "little"][int(f) - 1]
        return "%s%d%s" % (name, 1 if seg == "1" else 2, side)
    return "head"  # head, jaw, eyes, tongue and face muscles

FACE_SHAPES = [
    ("nose_width", ["nose/nose-scale-horiz-incr"], ["nose/nose-scale-horiz-decr"]),
    ("nose_length", ["nose/nose-scale-vert-incr"], ["nose/nose-scale-vert-decr"]),
    ("nose_hump", ["nose/nose-hump-incr"], ["nose/nose-hump-decr"]),
    ("nose_up", ["nose/nose-trans-up"], []),
    ("nose_depth", ["nose/nose-scale-depth-incr"], []),
    ("chin_prominent", ["chin/chin-prominent-incr"], ["chin/chin-prominent-decr"]),
    ("chin_width", ["chin/chin-width-incr"], ["chin/chin-width-decr"]),
    ("mouth_width", ["mouth/mouth-scale-horiz-incr"], ["mouth/mouth-scale-horiz-decr"]),
    ("lips_full", ["mouth/mouth-upperlip-volume-incr", "mouth/mouth-lowerlip-volume-incr"], []),
    ("head_oval", ["head/head-oval"], ["head/head-round"]),
    ("head_square", ["head/head-square"], []),
    ("eyes_big", ["eyes/l-eye-scale-incr", "eyes/r-eye-scale-incr"], []),
    ("cheekbones", ["cheek/l-cheek-bones-incr", "cheek/r-cheek-bones-incr"], []),
    ("cheeks_full", ["cheek/l-cheek-inner-incr", "cheek/r-cheek-inner-incr"], []),
    ("brows_up", ["eyebrows/eyebrows-trans-up"], []),
    ("brows_angle", ["eyebrows/eyebrows-angle-up"], []),
    ("ears_big", ["ears/l-ear-scale-incr", "ears/r-ear-scale-incr"], []),
    ("young_face", ["head/head-age-decr"], []),
]

BONES = ["root", "pelvis", "spine", "chest", "neck", "head",
         "thigh_L", "shin_L", "foot_L", "thigh_R", "shin_R", "foot_R",
         "upperarm_L", "forearm_L", "hand_L", "upperarm_R", "forearm_R", "hand_R"]
for sd in "LR":
    for f in ["thumb", "index", "middle", "ring", "little"]:
        BONES += ["%s1_%s" % (f, sd), "%s2_%s" % (f, sd)]
# Which MakeHuman joint gives each NPC bone's head position.
BONE_HEAD = {"pelvis": "spine05____head", "spine": "spine04____head", "chest": "spine02____head",
             "neck": "neck01____head", "head": "head____head"}
for sd in "LR":
    BONE_HEAD.update({"thigh_" + sd: "upperleg01.%s____head" % sd, "shin_" + sd: "lowerleg01.%s____head" % sd,
                      "foot_" + sd: "foot.%s____head" % sd, "upperarm_" + sd: "upperarm01.%s____head" % sd,
                      "forearm_" + sd: "lowerarm01.%s____head" % sd, "hand_" + sd: "wrist.%s____head" % sd})
    for i, f in enumerate(["thumb", "index", "middle", "ring", "little"]):
        BONE_HEAD["%s1_%s" % (f, sd)] = "finger%d-1.%s____head" % (i + 1, sd)
        BONE_HEAD["%s2_%s" % (f, sd)] = "finger%d-2.%s____head" % (i + 1, sd)
PART = {"pelvis": 0, "spine": 0, "chest": 0, "neck": 6, "head": 3, "thigh": 1, "shin": 1, "foot": 4,
        "upperarm": 2, "forearm": 2, "hand": 5}


def fetch(src, rel):
    path = os.path.join(src, rel)
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        urllib.request.urlretrieve(RAW + rel, path)
    return path


def read_target(path, n):
    d = np.zeros((n, 3), np.float64)
    for line in open(path):
        if line.startswith("#") or not line.strip(): continue
        i, x, y, z = line.split()
        d[int(i)] = (float(x), float(y), float(z))
    return d


def make_arm_pose(base, skel, wts, n):
    """Returns f(points) that hangs the arms down from the A-pose (linear blend
    skinning with MakeHuman's own weights: clavicle, shoulder and upper arm share
    the rotation so the shoulder keeps its slope)."""
    jp = lambda k: base[skel["joints"][k]].mean(0)
    bones = skel["bones"]
    names = list(bones.keys())
    head = {b: jp(bones[b]["head"]) for b in names}
    local = {b: np.eye(4) for b in names}
    def rot(axis, ang, c):
        axis = axis / np.linalg.norm(axis)
        x, y, z = axis; c_, s_ = math.cos(ang), math.sin(ang); t = 1 - c_
        R = np.array([[t*x*x + c_, t*x*y - s_*z, t*x*z + s_*y], [t*x*y + s_*z, t*y*y + c_, t*y*z - s_*x], [t*x*z - s_*y, t*y*z + s_*x, t*z*z + c_]])
        M = np.eye(4); M[:3, :3] = R; M[:3, 3] = c - R @ c
        return M
    for sd, sx in (("L", 1.0), ("R", -1.0)):
        d = head["lowerarm01." + sd] - head["upperarm01." + sd]
        d /= np.linalg.norm(d)
        target = np.array([sx * 0.12, -1.0, -0.02]); target /= np.linalg.norm(target)
        axis = np.cross(d, target); ang = math.asin(min(1.0, np.linalg.norm(axis)))
        for b, f in (("clavicle", 0.08), ("shoulder01", 0.22), ("upperarm01", 0.70)):
            local[b + "." + sd] = rot(axis, ang * f, head[b + "." + sd])
        # straighten the elbow to a slight bend, and twist the forearm so the
        # palms face the thighs (thumbs forward = +Z here)
        Ru = local["clavicle." + sd] @ local["shoulder01." + sd] @ local["upperarm01." + sd]
        la = head["lowerarm01." + sd]
        fa = head["wrist." + sd] - la; fa /= np.linalg.norm(fa)
        want = np.array([sx * 0.10, -1.0, 0.2]); want /= np.linalg.norm(want)
        want_rest = Ru[:3, :3].T @ want
        ax2 = np.cross(fa, want_rest)
        align = rot(ax2, math.asin(min(1.0, np.linalg.norm(ax2))), la) if np.linalg.norm(ax2) > 1e-6 else np.eye(4)
        th_ = np.append(head["finger1-1." + sd], 1); li_ = np.append(head["finger5-1." + sd], 1)
        best = None
        for deg in range(-180, 180, 5):
            L = align @ rot(fa, math.radians(deg), la)
            M = Ru @ L
            score = (M @ th_)[2] - (M @ li_)[2]
            if best is None or score > best[0]:
                best = (score, L)
        local["lowerarm01." + sd] = best[1]
        # bring the fingers halfway together (the A-pose spreads them)
        dm = jp(bones["finger3-1." + sd]["tail"]) - head["finger3-1." + sd]
        for f in (2, 4, 5):
            b = "finger%d-1.%s" % (f, sd)
            df_ = jp(bones[b]["tail"]) - head[b]
            ax3 = np.cross(df_, dm)
            ang3 = math.atan2(np.linalg.norm(ax3), np.dot(df_, dm))
            if np.linalg.norm(ax3) > 1e-9:
                local[b] = rot(ax3, ang3 * 0.55, head[b])
    world = {}
    def W(b):
        if b not in world:
            par = bones[b].get("parent")
            world[b] = (W(par) if par else np.eye(4)) @ local[b]
        return world[b]
    mats = np.stack([W(b) for b in names])
    bi = {b: i for i, b in enumerate(names)}
    Wm = np.zeros((n, len(names)))
    for b, lst in wts.items():
        if b in bi:
            for vi, w in lst:
                Wm[vi, bi[b]] += w
    tot = Wm.sum(1, keepdims=True)
    Wm = np.where(tot > 0, Wm / np.maximum(tot, 1e-9), 0)
    Wm[tot[:, 0] == 0, bi["head"]] = 1.0
    def f(p):
        ph = np.concatenate([p, np.ones((len(p), 1))], 1)
        out = np.zeros_like(p)
        for k in range(len(names)):
            w = Wm[:, k]
            nz = w > 0
            if nz.any():
                out[nz] += w[nz, None] * (ph[nz] @ mats[k].T)[:, :3]
        return out
    return f


def subdivide_head(pos, nrm, uv, uv2, tuv, col, bones, weights, idx, blocks):
    """Splits every face triangle (head, eyes, hair) into four, with curved
    (PN-triangle) edge midpoints; neighbours of split edges are split too, so
    there are no cracks. Roughly quadruples the face's triangle count."""
    tri = idx.reshape(-1, 3)
    part = np.floor(uv[:, 0] + 0.01).astype(int)
    face = np.isin(part, [3, 8, 11])
    split_tri = face[tri].all(1)
    edges = {}
    def key(a, b): return (a, b) if a < b else (b, a)
    for t in tri[split_tri]:
        for k in range(3):
            edges[key(t[k], t[(k + 1) % 3])] = -1
    ek = list(edges.keys())
    a = np.array([e[0] for e in ek]); b = np.array([e[1] for e in ek])
    base = len(pos)
    for j, e in enumerate(ek): edges[e] = base + j
    def mid(P, N):
        d = P[b] - P[a]
        m = (P[a] + P[b]) / 2 + ((np.sum(d * N[a], 1) - np.sum(d * N[b], 1)) / 8)[:, None] * (N[a] + N[b]) / 2
        nn = N[a] + N[b]
        return m, nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-9)
    pm, nm = mid(pos, nrm)
    pos = np.concatenate([pos, pm]); nrm = np.concatenate([nrm, nm])
    uv = np.concatenate([uv, np.stack([uv[a, 0], (uv[a, 1] + uv[b, 1]) / 2], 1)])
    uv2 = np.concatenate([uv2, (uv2[a] + uv2[b]) / 2])
    tuv = np.concatenate([tuv, (tuv[a] + tuv[b]) / 2])
    col = np.concatenate([col, (col[a] + col[b]) / 2])
    nb = np.zeros((len(ek), 4), np.int32); nw = np.zeros((len(ek), 4), np.float32)
    for j in range(len(ek)):
        acc = {}
        for v in (a[j], b[j]):
            for k in range(4): acc[bones[v, k]] = acc.get(bones[v, k], 0) + weights[v, k] * 0.5
        top = sorted(acc.items(), key=lambda t: -t[1])[:4]
        tot = sum(w for _, w in top) or 1
        for k, (bb, w) in enumerate(top): nb[j, k] = bb; nw[j, k] = w / tot
    bones = np.concatenate([bones, nb]); weights = np.concatenate([weights, nw])
    blocks = [(np.concatenate([sp, mid(sp, sn)[0]]).astype(np.float32), np.concatenate([sn, mid(sp, sn)[1]]).astype(np.float32)) for sp, sn in blocks]
    out = []
    for t in tri:
        m = [edges.get(key(t[k], t[(k + 1) % 3]), -1) for k in range(3)]
        cnt = sum(x >= 0 for x in m)
        if cnt == 0: out.append(t); continue
        if cnt == 3:
            out += [[t[0], m[0], m[2]], [m[0], t[1], m[1]], [m[2], m[1], t[2]], [m[0], m[1], m[2]]]; continue
        # rotate so the first split edge is (v0, v1)
        r = [k for k in range(3) if m[k] >= 0][0] if cnt == 1 else [k for k in range(3) if m[k] < 0][0]
        v = [t[(r + k) % 3] for k in range(3)]; mm = [m[(r + k) % 3] for k in range(3)]
        if cnt == 1:
            out += [[v[0], mm[0], v[2]], [mm[0], v[1], v[2]]]
        else:   # edge (v0, v1) not split; (v1, v2) and (v2, v0) split
            out += [[v[0], v[1], mm[1]], [v[0], mm[1], mm[2]], [mm[2], mm[1], v[2]]]
    idx = np.array(out, np.int64).reshape(-1)
    return pos.astype(np.float32), nrm.astype(np.float32), uv, uv2, tuv, col, bones, weights, list(idx), blocks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="/tmp/mh")
    a = ap.parse_args()
    src = a.src
    obj = fetch(src, "3dobjs/base.obj")
    skel = json.load(open(fetch(src, "rigs/default.mhskel")))
    wts = json.load(open(fetch(src, "rigs/default_weights.mhw")))["weights"]

    V, VT, faces = [], [], []
    group = None
    for line in open(obj):
        if line.startswith("v "): V.append([float(t) for t in line.split()[1:4]])
        elif line.startswith("vt "): VT.append([float(t) for t in line.split()[1:3]])
        elif line.startswith("g "): group = line.split()[1]
        elif line.startswith("f "):
            corners = [tuple(int(x) - 1 for x in c.split("/")[:2]) for c in line.split()[1:]]
            faces.append((group, corners))
    V = np.array(V)
    n = len(V)
    keep = lambda g: g == "body" or g in ("helper-l-eye", "helper-r-eye")
    part_of_group = lambda g: 8 if g.endswith("-eye") else (10 if "eyelashes" in g else -1)

    # Bone weights per MakeHuman vertex, collapsed onto the NPC skeleton.
    W = {}
    for mb, lst in wts.items():
        nb = BONES.index(map_bone(mb))
        for vi, w in lst:
            W.setdefault(vi, {}).setdefault(nb, 0.0)
            W[vi][nb] += w

    for sex in ["male", "female"]:
        races = {r: read_target(fetch(src, "targets/macrodetails/%s-%s-young.target" % (r, sex)), n) for r in RACES}
        mean = sum(races.values()) / 3.0
        def univ(m, w):
            return read_target(fetch(src, "targets/macrodetails/universal-%s-young-%s-%s.target" % (sex, m, w)), n)
        base = V + mean
        pose_fn = make_arm_pose(base, skel, wts, n)
        shapes = {
            "fat": univ("averagemuscle", "maxweight"), "slim": univ("averagemuscle", "minweight"),
            "muscle": univ("maxmuscle", "averageweight"),
        }
        for r in RACES:
            shapes[r] = races[r] - mean
        # Per-person face variety: signed shapes (weight -1..1) from MakeHuman modifiers.
        T = lambda rel: read_target(fetch(src, "targets/%s.target" % rel), n)
        for nm, pos_t, neg_t in FACE_SHAPES:
            d = sum(T(t) for t in pos_t) / 1.0
            if neg_t:
                d = (d - sum(T(t) for t in neg_t)) / 2.0
            shapes[nm] = d
        # MakeHuman: decimeters, +Z forward, +X = character's left.
        # Game: meters, -Z forward, -X = character's left (rotate 180 degrees about Y).
        conv = lambda p: np.stack([-p[:, 0], p[:, 1], -p[:, 2]], 1) * 0.1
        posed = pose_fn(base)
        shapes = {k: pose_fn(base + v) - posed for k, v in shapes.items()}
        V_rest = V
        base = posed
        P = conv(base)
        body_idx = sorted({c[0] for g, cs in faces if g == "body" for c in cs})
        ground = P[body_idx, 1].min()
        P[:, 1] -= ground
        D = {k: conv(v) for k, v in shapes.items()}
        H = P[body_idx, 1].max()

        joints = {k: P[v].mean(0) for k, v in skel["joints"].items()}
        rest = []
        for b in BONES:
            rest.append([0.0, 0.0, 0.0] if b == "root" else list(map(float, joints[BONE_HEAD[b]])))
        landmarks = {
            "eye_y": float(joints["eye.L____head"][1] / H),
            "head_center": list(map(float, joints["head____head"] * 0 + (joints["eye.L____head"] + joints["eye.R____head"]) / 2)),
        }

        # Unique (vertex, uv) pairs become render vertices.
        remap, out_v, out_uv, idx = {}, [], [], []
        part_override = {}
        for g, cs in faces:
            if not keep(g): continue
            tri = []
            for vi, ti in cs:
                key = (vi, ti)
                if key not in remap:
                    remap[key] = len(out_v)
                    out_v.append(vi)
                    out_uv.append(VT[ti])
                    if part_of_group(g) >= 0: part_override[remap[key]] = part_of_group(g)
                tri.append(remap[key])
            # quads -> two triangles (MakeHuman winds counter-clockwise; mirrored by the 180 turn: no change)
            for k in range(1, len(tri) - 1):
                idx += [tri[0], tri[k], tri[k + 1]]
        out_v = np.array(out_v)
        m = len(out_v)
        pos = P[out_v]

        # Weights (top 4) and part / side / shader coordinates.
        bones = np.zeros((m, 4), np.int32)
        weights = np.zeros((m, 4), np.float32)
        part = np.zeros(m, np.float32)
        uv2 = np.zeros((m, 2), np.float32)
        hc = np.array(landmarks["head_center"])
        for i, vi in enumerate(out_v):
            ws = sorted(W.get(int(vi), {BONES.index("head"): 1.0}).items(), key=lambda t: -t[1])[:4]
            tot = sum(w for _, w in ws) or 1.0
            for k, (b, w) in enumerate(ws):
                bones[i, k] = b
                weights[i, k] = w / tot
            dom = BONES[bones[i, 0]]
            side = 0.5 if dom.endswith("_R") else 0.0
            if i in part_override:
                p = part_override[i]
                side = 0.5 if pos[i, 0] > 0 else 0.0
            elif any(dom.startswith(f) for f in ["thumb", "index", "middle", "ring", "little"]):
                p = 7
            else:
                p = PART[dom.split("_")[0]]
            part[i] = p + side
            d = pos[i] - hc
            th = (math.degrees(math.atan2(d[2], d[0])) + 360.0) % 360.0
            uv2[i] = (th / 360.0, 0.5)
        eye_dir = {}
        # Eyeballs: distance from the front pole (iris and pupil in the shader).
        for i in range(m):
            if int(part[i]) == 8:
                pass
        for sd in (-1, 1):
            sel = [i for i in range(m) if int(part[i]) == 8 and np.sign(pos[i, 0]) == sd]
            if not sel: continue
            c = pos[sel].mean(0)
            r = np.linalg.norm(pos[sel] - c, axis=1).max()
            for i in sel:
                v = (pos[i] - c) / r
                eye_dir[i] = v / max(np.linalg.norm(v), 1e-9)
                uv2[i, 1] = math.degrees(math.acos(max(-1.0, min(1.0, -v[2])))) / 32.0 * 0.075
        # Arms, hands and fingers: height as if the arm hung straight down, so the
        # shader's sleeve cut works on the A-pose rest mesh.
        yv = pos[:, 1].copy()
        for i in range(m):
            p_ = int(part[i])
            if p_ in (2, 5, 7):
                sd = "_R" if part[i] - p_ > 0.25 else "_L"
                sh = np.array(rest[BONES.index("upperarm" + sd)])
                yv[i] = sh[1] - np.linalg.norm(pos[i] - sh)
        # Region weights for the shader in COLOR: r lips, g brows, b nails, a beard.
        J = lambda k: conv(base[skel["joints"][k]].mean(0, keepdims=True))[0] - np.array([0, ground, 0])
        col = np.zeros((m, 4), np.float32)
        for i, v in eye_dir.items():
            col[i, :3] = v * 0.5 + 0.5   # eyeball: direction from its center (iris drawn per pixel)
        n_pre = None
        mouth = (J("oris05____head") + J("oris01____head")) / 2
        eye_l, eye_r = J("eye.L____head"), J("eye.R____head")
        eye_mid = (eye_l + eye_r) / 2
        head_dom = bones[:, 0] == BONES.index("head")
        for i in range(m):
            if int(part[i]) != 3: continue
            q = pos[i]
            front = q[2] < hc[2] - 0.02
            dx, dy = abs(q[0] - mouth[0]), q[1] - mouth[1]
            lip = (dx / 0.026) ** 2 + (dy / (0.0105 if dy > 0 else 0.0095)) ** 2
            if front and q[2] < mouth[2] + 0.012:
                col[i, 0] = float(np.clip((1.15 - lip) / 0.3, 0, 1))
            # brows: an arch above each eye
            ex = abs(q[0]) - abs(eye_l[0])
            by = eye_l[1] + 0.008 + 0.006 * math.cos(min(abs(ex) / 0.03, 1.5)) - 0.004 * (ex / 0.03) ** 2
            if front and -0.035 < ex < 0.03 and abs(q[0]) > 0.009:
                col[i, 1] = float(np.clip(1 - abs(q[1] - by) / 0.0055, 0, 1) * np.clip((0.034 - abs(ex + 0.002)) / 0.01, 0, 1))
            # beard zone: below the cheekbones, in front of the ears, not the lips
            df = abs(((math.degrees(math.atan2(q[2] - hc[2], q[0] - hc[0])) + 360) % 360) - 270)
            if q[1] < eye_l[1] - 0.035 and df < 80 and lip > 1.3:
                col[i, 3] = float(np.clip((eye_l[1] - 0.035 - q[1]) / 0.012, 0, 1) * np.clip((80 - df) / 12, 0, 1))
        # Finger and toe nails: the top of the last segment.
        tips = []
        for sd in "LR":
            for f in range(1, 6):
                tips.append(("finger%d-3.%s" % (f, sd), 0.008))
                tips.append(("toe%d-%d.%s" % (f, 2 if f == 1 else 3, sd), 0.009 if f == 1 else 0.006))
        nrm_tmp = None
        for name, rad in tips:
            a_, b_ = J(name + "____head"), J(name + "____tail")
            ax = b_ - a_; L = np.linalg.norm(ax); ax /= L
            rel = pos - a_
            t = rel @ ax / L
            dist = np.linalg.norm(rel - np.outer(rel @ ax, ax), axis=1)
            near = (t > 0.15) & (t < 1.25) & (dist < rad * 1.6)
            if not near.any(): continue
            # the nail side is where the segment's vertices bulge least: use the
            # direction of the back of the hand / top of the foot
            up = np.array([0, 1.0, 0]) if name.startswith("toe") else None
            if up is None:
                sd = name[-1]
                w0, i0, l0 = (J("wrist.%s____head" % sd), J("finger2-1.%s____head" % sd), J("finger5-1.%s____head" % sd))
                up = np.cross(i0 - w0, l0 - w0); up /= np.linalg.norm(up)
                if up[1] < 0: up = -up
            dirn = rel - np.outer(rel @ ax, ax)
            dirn /= np.maximum(np.linalg.norm(dirn, axis=1, keepdims=True), 1e-9)
            nail = near & ((dirn @ up) > 0.55) & (t > 0.35)
            col[nail, 2] = 1.0
        # Eyelashes: draw both sides.
        lash = [k for k in range(0, len(idx), 3) if int(part[idx[k]]) == 10]
        for k in lash:
            idx += [idx[k], idx[k + 2], idx[k + 1]]
        # Hair shell: the scalp above the hairline, pushed out along the normal.
        hair_line = {"front": float(eye_l[1] + 0.075), "side": float(eye_l[1] + 0.045), "back": float(eye_l[1] - 0.05)}
        def hairline(df):
            if df < 40: return hair_line["front"] + (hair_line["side"] - hair_line["front"]) * np.clip((df - 20) / 20, 0, 1)
            return hair_line["side"] + (hair_line["back"] - hair_line["side"]) * np.clip((df - 95) / 45, 0, 1)
        scalp = np.zeros(m, bool)
        for i in range(m):
            if int(part[i]) == 3 and head_dom[i]:
                q = pos[i]
                df = abs(((math.degrees(math.atan2(q[2] - hc[2], q[0] - hc[0])) + 360) % 360) - 270)
                scalp[i] = q[1] > hairline(df)
        hair_faces = [idx[k:k + 3] for k in range(0, len(idx), 3) if all(scalp[v] for v in idx[k:k + 3])]
        hv = sorted({v for f in hair_faces for v in f})
        hmap = {v: m + j for j, v in enumerate(hv)}
        for f in hair_faces:
            idx += [hmap[v] for v in f]
        hv = np.array(hv)
        top = pos[:, 1].max()
        thick = 0.006 + 0.012 * np.clip((pos[hv, 1] - (top - 0.06)) / 0.06, 0, 1)
        out_v = np.concatenate([out_v, out_v[hv]])
        pos = np.concatenate([pos, pos[hv]])
        bones = np.concatenate([bones, bones[hv]]); weights = np.concatenate([weights, weights[hv]])
        part = np.concatenate([part, np.full(len(hv), 11.0, np.float32)])
        uv2 = np.concatenate([uv2, uv2[hv]]); col = np.concatenate([col, np.zeros((len(hv), 4), np.float32)])
        yv = np.concatenate([yv, yv[hv]])
        out_uv = list(out_uv) + [out_uv[v] for v in hv]
        m_body = m
        m = len(pos)
        landmarks["hair"] = {k: v / H for k, v in hair_line.items()}
        landmarks["eye_y"] = float(eye_l[1] / H)
        # Normals per shape, smooth.
        idx_a = np.array(idx, np.int64).reshape(-1, 3)
        def normals(pp):
            fn = np.cross(pp[idx_a[:, 1]] - pp[idx_a[:, 0]], pp[idx_a[:, 2]] - pp[idx_a[:, 0]])
            nn = np.zeros_like(pp)
            for k in range(3): np.add.at(nn, idx_a[:, k], fn)
            # merge across UV seams: accumulate per original vertex
            key = out_v + np.where(part >= 11, n, 0)
            acc = np.zeros((2 * n, 3)); np.add.at(acc, key, nn)
            nn = acc[key]
            return nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-9)
        def shell(pp):
            nn = normals(pp)
            pp = pp.copy(); pp[m_body:] += nn[m_body:] * thick[:, None]
            return pp
        n0 = normals(pos)
        pos_rest = pos.copy()
        # Muscle flex shapes, applied along the surface normal.
        flex = {}
        y = pos[:, 1] / H
        def g(x, c, s): return np.exp(-((x - c) / s) ** 2)
        for sd, name in ((-1, "L"), (1, "R")):
            on_side = np.sign(pos[:, 0]) == sd
            shin = np.isin(bones[:, 0], [BONES.index("shin_" + name)]) & on_side
            thigh = np.isin(bones[:, 0], [BONES.index("thigh_" + name)]) & on_side
            pelv = np.isin(bones[:, 0], [BONES.index("pelvis"), BONES.index("thigh_" + name)]) & on_side
            back = np.clip(n0[:, 2], 0, 1)
            front = np.clip(-n0[:, 2], 0, 1)
            amp = (g(y, 0.235, 0.035) * 1.0 + g(y, 0.17, 0.03) * 0.4) * back * shin * 0.0055 * (H / 1.75)
            flex["calf_flex_" + name] = n0 * amp[:, None] + np.array([0, 0.004, 0]) * (amp[:, None] > 1e-4) * g(y, 0.235, 0.05)[:, None]
            amp = g(y, 0.37, 0.05) * front * thigh * 0.004 * (H / 1.75)
            flex["quad_flex_" + name] = n0 * amp[:, None]
            amp = g(y, 0.5, 0.035) * back * pelv * 0.005 * (H / 1.75)
            flex["glute_flex_" + name] = n0 * amp[:, None]
        names = ["fat", "slim", "muscle", "calf_flex_L", "calf_flex_R", "quad_flex_L", "quad_flex_R",
                 "glute_flex_L", "glute_flex_R", "barefoot", "caucasian", "african", "asian"] + [f[0] for f in FACE_SHAPES]
        blocks = []
        for nm in names:
            if nm in D: sp = pos_rest + D[nm][out_v]
            elif nm in flex: sp = pos_rest + flex[nm]
            else: sp = pos_rest.copy()
            sp = shell(sp)
            blocks.append((sp.astype(np.float32), normals(sp).astype(np.float32)))

        # UV.x = part + side, UV.y = height fraction; nails flagged in UV2.
        pos = shell(pos_rest)
        n0 = normals(pos)
        uv = np.stack([part, yv / H], 1).astype(np.float32)
        pos, n0, uv, uv2, out_uv, col, bones, weights, idx, blocks = subdivide_head(
            pos.astype(np.float32), n0, uv, uv2, np.array(out_uv, np.float32), col, bones, weights, np.array(idx, np.int64), blocks)
        m = len(pos)
        meta = {"sex": sex, "height": float(H), "vertices": m, "indices": int(len(idx)), "bones": BONES,
                "rest": rest, "shapes": names, "landmarks": landmarks,
                "layout": ["pos", "normal", "uv", "uv2", "texuv", "color", "bones", "weights", "index", "shapes(pos,normal)..."]}
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, "mh_%s.bin" % sex), "wb") as f:
            for arr in [pos.astype(np.float32), n0.astype(np.float32), uv.astype(np.float32), uv2.astype(np.float32),
                        np.array(out_uv, np.float32), col.astype(np.float32), bones.astype(np.int32), weights.astype(np.float32), np.array(idx, np.int32)]:
                f.write(arr.tobytes())
            for sp, sn in blocks:
                f.write(sp.tobytes()); f.write(sn.tobytes())
        json.dump(meta, open(os.path.join(OUT, "mh_%s.json" % sex), "w"))
        print(sex, "height %.3f m" % H, m, "vertices", len(idx) // 3, "triangles")


if __name__ == "__main__":
    main()
