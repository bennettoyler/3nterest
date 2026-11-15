#!/usr/bin/env python3
# Renders seed/thumbs/*.jpg from seed/models/*.usdz and the seeded rooms as deployed (seed:roomPicks).
# Needs: pip install usd-core pyrender trimesh pillow 'numpy<2' 'scipy<1.14' PyOpenGL==3.1.7; run with PYOPENGL_PLATFORM=egl.
import io, json, os, subprocess, sys, zipfile
import numpy as np
np.infty = np.inf
from PIL import Image
os.environ.setdefault("PYOPENGL_PLATFORM", "egl")
import pyrender
from pxr import Usd, UsdGeom, UsdShade

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(ROOT)
MODELS, THUMBS = os.path.join(ROOT, "models"), os.path.join(ROOT, "thumbs")
SIZE, SS = 600, 2


def shader_inputs(material):
    surf = material.ComputeSurfaceSource()[0]
    if not surf:
        return (0.8, 0.8, 0.8), None
    inp = surf.GetInput("diffuseColor")
    if not inp:
        return (0.8, 0.8, 0.8), None
    src = inp.GetConnectedSource()
    if src:
        f = UsdShade.Shader(src[0].GetPrim()).GetInput("file")
        if f and f.Get():
            return (1, 1, 1), f.Get().path
    v = inp.Get()
    return (tuple(v) if v is not None else (0.8, 0.8, 0.8)), None


def load_usdz(path):
    stage = Usd.Stage.Open(path)
    z = zipfile.ZipFile(path)
    tex_cache, prims = {}, []
    for prim in stage.Traverse():
        if not prim.IsA(UsdGeom.Mesh):
            continue
        mesh = UsdGeom.Mesh(prim)
        pts = np.array(mesh.GetPointsAttr().Get(), dtype=np.float64)
        counts = np.array(mesh.GetFaceVertexCountsAttr().Get())
        idx = np.array(mesh.GetFaceVertexIndicesAttr().Get())
        xf = np.array(UsdGeom.Xformable(prim).ComputeLocalToWorldTransform(Usd.TimeCode.Default()))
        pts = (np.c_[pts, np.ones(len(pts))] @ xf)[:, :3]
        corners, start = [], 0
        for c in counts:
            for k in range(1, c - 1):
                corners += [start, start + k, start + k + 1]
            start += c
        corners = np.array(corners)
        pos = pts[idx[corners]]
        uv = None
        st = UsdGeom.PrimvarsAPI(prim).GetPrimvar("st")
        if st and st.HasValue():
            vals = np.array(st.ComputeFlattened(), dtype=np.float32)
            interp = st.GetInterpolation()
            if interp == "faceVarying" and len(vals) == len(idx):
                uv = vals[corners]
            elif len(vals) == len(pts):
                uv = vals[idx[corners]]
        tri = pos.reshape(-1, 3, 3)
        fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        fn /= np.linalg.norm(fn, axis=1, keepdims=True) + 1e-12
        nrm = np.repeat(fn, 3, axis=0)
        color, tex = (0.8, 0.8, 0.8), None
        mat = UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial()[0]
        if mat:
            color, tex = shader_inputs(mat)
        kw = dict(baseColorFactor=list(color) + [1.0], metallicFactor=0.0, roughnessFactor=0.85, doubleSided=True)
        if tex and uv is not None:
            if tex not in tex_cache:
                name = next((n for n in z.namelist() if n.endswith(tex.lstrip("./"))), None)
                img = Image.open(io.BytesIO(z.read(name))).convert("RGB") if name else None
                tex_cache[tex] = np.array(img) if img else None
            if tex_cache[tex] is not None:
                kw["baseColorTexture"] = pyrender.Texture(source=tex_cache[tex], source_channels="RGB")
        material = pyrender.MetallicRoughnessMaterial(**kw)
        prims.append(pyrender.Primitive(positions=pos.astype(np.float32), normals=nrm.astype(np.float32),
                                        texcoord_0=uv if "baseColorTexture" in kw else None, material=material))
    return pyrender.Mesh(primitives=prims)


def box(size, center, color):
    import trimesh
    m = trimesh.creation.box(extents=size)
    m.apply_translation(center)
    mat = pyrender.MetallicRoughnessMaterial(baseColorFactor=list(color) + [1.0], metallicFactor=0.0, roughnessFactor=1.0)
    return pyrender.Mesh.from_trimesh(m, material=mat, smooth=False)


def look_at(eye, target):
    eye, target = np.array(eye, float), np.array(target, float)
    f = target - eye; f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0]); r /= np.linalg.norm(r)
    u = np.cross(r, f)
    m = np.eye(4)
    m[:3, 0], m[:3, 1], m[:3, 2], m[:3, 3] = r, u, -f, eye
    return m


def render(scene, eye, target, yfov, out, renderer):
    cam = pyrender.PerspectiveCamera(yfov=yfov, aspectRatio=1.0, znear=0.05, zfar=100)
    scene.add(cam, pose=look_at(eye, target))
    key = look_at(np.array(eye) + [1.5, 4, 0.5], target)
    scene.add(pyrender.DirectionalLight(color=[1, 1, 1], intensity=3.2), pose=key)
    scene.add(pyrender.DirectionalLight(color=[1, 0.97, 0.92], intensity=1.2), pose=look_at([-4, 3, 2], [0, 0, 0]))
    color, depth = renderer.render(scene, flags=pyrender.RenderFlags.SHADOWS_DIRECTIONAL)
    color = color.copy()
    color[depth == 0] = 255
    img = Image.fromarray(color).resize((SIZE, SIZE), Image.LANCZOS)
    q = 88
    while True:
        img.save(out, "JPEG", quality=q, optimize=True)
        if os.path.getsize(out) < 190_000 or q < 50:
            break
        q -= 8
    print(out, os.path.getsize(out))


def bounds(mesh):
    b = mesh.bounds
    return b[0], b[1]


def product_thumb(slug, renderer):
    mesh = load_usdz(os.path.join(MODELS, slug + ".usdz"))
    lo, hi = bounds(mesh)
    scene = pyrender.Scene(bg_color=[1, 1, 1, 1], ambient_light=[0.65, 0.65, 0.65])
    scene.add(mesh)
    c = (lo + hi) / 2
    r = np.linalg.norm(hi - lo) / 2
    d = np.array([0.75, 0.5, 1.2]); d /= np.linalg.norm(d)
    yfov = np.radians(30)
    dist = r / np.sin(yfov / 2) * 1.02
    render(scene, c + d * dist, c, yfov, os.path.join(THUMBS, slug + ".jpg"), renderer)


def tf(t):
    return np.array(t, float).reshape(4, 4).T


ROOM_STYLES = [
    ((0.96, 0.94, 0.90), (0.80, 0.66, 0.48), (1, 1)),
    ((0.93, 0.90, 0.86), (0.72, 0.56, 0.40), (-1, 1)),
    ((0.97, 0.97, 0.97), (0.86, 0.83, 0.78), (1, 1)),
    ((0.90, 0.93, 0.95), (0.88, 0.80, 0.68), (-1, 1)),
    ((0.82, 0.84, 0.88), (0.62, 0.48, 0.36), (1, 1)),
    ((0.95, 0.89, 0.82), (0.66, 0.48, 0.32), (-1, 1)),
    ((0.78, 0.78, 0.78), (0.55, 0.55, 0.55), (1, 1)),
    ((0.96, 0.88, 0.80), (0.82, 0.70, 0.54), (-1, 1)),
    ((0.92, 0.95, 0.92), (0.84, 0.74, 0.60), (1, 1)),
    ((1.00, 0.90, 0.80), (0.74, 0.60, 0.44), (-1, 1)),
]


def room_picks():
    # The seeded rooms as deployed (seed:roomPicks), so each thumbnail shows the products the room really holds.
    # CONVEX_RUN_FLAGS go to npx convex run, e.g. CONVEX_RUN_FLAGS=--prod.
    cmd = ["npx", "convex", "run", *os.environ.get("CONVEX_RUN_FLAGS", "").split(), "seed:roomPicks"]
    return json.loads(subprocess.run(cmd, cwd=REPO, check=True, capture_output=True, text=True).stdout)


def room_thumbs(renderer):
    meshes = {}
    for i, room in enumerate(r for r in room_picks() if not r["slug"].endswith("-scan")):
        slug = room["slug"]
        wall_c, floor_c, (sx, sz) = ROOM_STYLES[i % len(ROOM_STYLES)]
        scene = pyrender.Scene(bg_color=[1, 1, 1, 1], ambient_light=[0.5, 0.5, 0.5])
        eye = np.array([4.9 * sx, 5.6, 5.6 * sz])
        walls = room["shell"]["walls"]
        xs = [tf(w["transform"])[0, 3] for w in walls]; zs = [tf(w["transform"])[2, 3] for w in walls]
        w_, d_ = max(xs) - min(xs), max(zs) - min(zs)
        scene.add(box([w_, 0.04, d_], [0, -0.02, 0], floor_c))
        for w in walls:
            m = tf(w["transform"])
            c = m[:3, 3]
            if np.dot(c[[0, 2]], eye[[0, 2]]) > 0:
                continue
            mesh = box([w["width"], w["height"], 0.08], [0, 0, 0], wall_c)
            scene.add(mesh, pose=m)
        for win in room["shell"]["windows"]:
            m = tf(win["transform"])
            if np.dot(m[[0, 2], 3], eye[[0, 2]]) <= 0:
                scene.add(box([win["width"], win["height"], 0.1], [0, 0, 0], (0.75, 0.86, 0.95)), pose=m)
        rug = box([1.9, 0.01, 1.3], [0, 0.005, 0], (1.0, 0.4, 0.0) if i % 3 == 0 else (0.9, 0.87, 0.82) if i % 3 == 1 else (0.55, 0.6, 0.62))
        scene.add(rug, pose=tf([1,0,0,0,0,1,0,0,0,0,1,0,0,0,-0.9,1]))
        for p in room["placements"]:
            prod = p["product"]
            if not prod:
                continue
            if prod not in meshes:
                meshes[prod] = load_usdz(os.path.join(MODELS, prod + ".usdz"))
            scene.add(meshes[prod], pose=tf(p["transform"]))
        render(scene, eye, [0, 0.4, 0], np.radians(42), os.path.join(THUMBS, "room-" + slug + ".jpg"), renderer)


if __name__ == "__main__":
    renderer = pyrender.OffscreenRenderer(SIZE * SS, SIZE * SS)
    only = sys.argv[1:]
    for f in sorted(os.listdir(MODELS)):
        if f.endswith(".usdz") and (not only or f[:-5] in only):
            product_thumb(f[:-5], renderer)
    if not only or "rooms" in only:
        room_thumbs(renderer)
