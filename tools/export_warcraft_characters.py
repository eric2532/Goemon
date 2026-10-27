"""Export the saved Warcraft masters read-only; run with Blender --background --python.

glTF carries the original skin/actions. The sidecar carries Blender's custom-property
opacity and prepared particle tracks, which glTF cannot represent.
"""
import hashlib
import json
import shutil
import sys
from pathlib import Path

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / "Warcraft"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare_blademaster_team_color(package):
    changed = set()
    for material in bpy.data.materials:
        if not material.use_nodes:
            continue
        for node in material.node_tree.nodes:
            if node.type != "TEX_IMAGE" or node.image is None:
                continue
            for kind in ["TeamColor", "TeamGlow"]:
                if Path(node.image.filepath).name == kind + "00.png":
                    node.image = bpy.data.images.load(str(package / "original/ReplaceableTextures" / kind / (kind + "00.png")), check_existing=True)
                    changed.add(kind)
    assert changed, "Blademaster's original team textures were not found"
    return changed


def export(name, key):
    package = SOURCE / "assets" / name
    master = package / (name + ".blend")
    before = digest(master)
    bpy.ops.wm.open_mainfile(filepath=str(master))
    scene = bpy.context.scene
    rig = next(o for o in scene.objects if o.type == "ARMATURE")
    model_name = {"blademaster": "HeroBladeMaster", "demon-hunter": "IllidanEvil", "peasant": "Peasant"}[key]
    model = json.loads((SOURCE / "work" / (model_name + ".mdx.json")).read_text())
    out = ROOT / "assets/models/characters/warcraft" / key
    data = ROOT / "assets/characters/warcraft" / key
    out.mkdir(parents=True, exist_ok=True)
    data.mkdir(parents=True, exist_ok=True)
    meshes = sorted((o for o in scene.objects if o.type == "MESH" and o.name.split()[0].isdigit()), key=lambda o: int(o.name.split()[0]))
    particles = sorted((o for o in scene.objects if o.type == "MESH" and o.get("source_emitter")), key=lambda o: o.name)
    info = {"source": str(master), "sha256": before, "fps": 30, "meshes": [], "particles": [], "clips": {}}
    if key == "blademaster":
        # Use the original red team color and hero glow without changing the editable master.
        team_textures = prepare_blademaster_team_color(package)
        assert team_textures == {"TeamColor", "TeamGlow"}
        info["team_color"] = 0
    if name == "Illidan":
        # Preserve slot 32's attack recovery; keep native timings in the editable master.
        for clip in ["Attack", "Attack 2"]:
            action = bpy.data.actions[clip]
            factor = 27 / action.frame_end
            for layer in action.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        for curve in bag.fcurves:
                            for point in curve.keyframe_points:
                                point.co.x *= factor
                                point.handle_left.x *= factor
                                point.handle_right.x *= factor
            action.frame_end = 27
        info["prepared_attack_seconds"] = .9
    for i, obj in enumerate(meshes):
        obj.name = "Geoset_%02d" % i
        layers = model["Materials"][model["Geosets"][i]["MaterialID"]]["Layers"]
        images = [n.image for n in obj.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE"]
        image = images[-1]
        pixels = np.array(image.pixels[:], dtype=np.float32).reshape(-1, 4)
        if len(images) == 2:
            # Composite the prepared team layer under the authored skin's alpha.
            team = np.array(images[0].pixels[:4], dtype=np.float32)
            pixels[:, :3] = pixels[:, :3] * pixels[:, 3:4] + team[:3] * (1 - pixels[:, 3:4])
            pixels[:, 3] = 1
        mode = layers[-1]["FilterMode"]
        if mode in (3, 4):
            pixels[:, 3] *= pixels[:, :3].max(axis=1)
        texture = bpy.data.images.new(key + "_%02d" % i, width=image.size[0], height=image.size[1], alpha=True)
        texture.pixels.foreach_set(pixels.ravel())
        texture.pack()
        mat = bpy.data.materials.new(obj.name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = texture
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        mat.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        bsdf.inputs["Roughness"].default_value = 1
        bsdf.inputs["Specular IOR Level"].default_value = 0
        mat.surface_render_method = "DITHERED"
        mat.use_backface_culling = not bool(layers[-1].get("Shading", 0) & 16)
        obj.data.materials.clear()
        obj.data.materials.append(mat)
        info["meshes"].append({"name": obj.name, "mode": mode, "tint": next((a.get("Color", [1, 1, 1]) for a in model.get("GeosetAnims", []) if a["GeosetId"] == i), [1, 1, 1])})
    particle_images = set()
    for index, obj in enumerate(particles):
        prefix = obj.data.name
        image = next(n.image for n in obj.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE")
        path = data / ("smoke.png" if prefix.startswith("fx0_") else "energy.png" if prefix.startswith("fx1_") else "water.png")
        if path.name not in particle_images:
            pixels = np.array(image.pixels[:], dtype=np.float32).reshape(-1, 4)
            brightness = pixels[:, :3] @ np.array([.2126, .7152, .0722])
            pixels[:, 3] *= (1 - brightness) if prefix.startswith("fx0_") else brightness
            if prefix.startswith("fx0_"):
                pixels[:, :3] = 0
            sprite = bpy.data.images.new(key + "_" + path.stem, width=image.size[0], height=image.size[1], alpha=True)
            sprite.pixels.foreach_set(pixels.ravel())
            sprite.filepath_raw = str(path)
            sprite.file_format = "PNG"
            sprite.save()
            particle_images.add(path.name)
        info["particles"].append({"prefix": prefix, "texture": path.name, "uv": [list(u.uv) for u in obj.data.uv_layers.active.data]})
    # All particle placement is already authored in the rig action. Keep it out
    # of the skin export and sample it once instead of carrying Blender drivers.
    for action in bpy.data.actions:
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        frames = []
        for frame in range(int(action.frame_end) + 1):
            scene.frame_set(frame)
            opacity = [round(float(rig.get("geoset_%d_opacity" % i, 1)), 6) for i in range(len(meshes))]
            active = []
            for i, particle in enumerate(info["particles"]):
                p = particle["prefix"]
                if rig.get(p + "alpha", 0) > .001:
                    active.append([i] + [round(float(rig.get(p + channel, 0)), 6) for channel in ["x", "y", "z", "size", "alpha", "r", "g", "b", "u", "v"]])
            frames.append({"opacity": opacity, "particles": active})
        info["clips"][action.name] = frames
    rig.animation_data.action = bpy.data.actions["Stand"]
    rig.animation_data.action_slot = rig.animation_data.action.slots[0]
    scene.frame_set(0)
    points = []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for i, obj in enumerate(meshes):
        if rig.get("geoset_%d_opacity" % i, 1) < .5 or info["meshes"][i]["mode"] in (3, 4):
            continue
        evaluated = obj.evaluated_get(depsgraph)
        points.extend(evaluated.matrix_world @ v.co for v in evaluated.data.vertices)
    info["standing_height"] = max(v.z for v in points) - min(v.z for v in points)
    info["floor"] = min(v.z for v in points)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(out / (key + ".glb")), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
        export_frame_range=False, export_cameras=False, export_lights=False, export_yup=True, export_apply=False)
    info["glb_sha256"] = digest(out / (key + ".glb"))
    (data / "motion.json").write_text(json.dumps(info, separators=(",", ":")) + "\n")
    (data / "audio").mkdir(exist_ok=True)
    audio_package = SOURCE / "assets/DemonHunter" if name == "Illidan" else package
    for sound in (audio_package / "sounds").glob("*.wav"):
        shutil.copy2(sound, data / "audio" / sound.name)
    if key == "demon-hunter":
        shutil.copy2(audio_package / "original/Textures/Green_Glow3.png", data / "bolt.png")
    for filename in ["sound-events.json", "sound-tables.json"]:
        shutil.copy2(audio_package / filename, data / filename)
    for filename in ["animation-index.json", "extraction-manifest.json"]:
        shutil.copy2(package / filename, data / filename)
    if not (data / "portrait.png").exists():
        shutil.copy2(package / (name + "-preview.png"), data / "portrait.png")
    if key == "blademaster":
        portrait_master = package / "Blademaster_Portrait.blend"
        portrait_before = digest(portrait_master)
        bpy.ops.wm.open_mainfile(filepath=str(portrait_master))
        prepare_blademaster_team_color(package)
        bpy.context.scene.render.filepath = str(data / "hud_portrait.png")
        bpy.ops.render.render(write_still=True)
        assert digest(portrait_master) == portrait_before, "Portrait master was changed"
    elif key != "peasant":
        shutil.copy2(package / (name + "_Portrait-preview.png"), data / "hud_portrait.png")
    assert digest(master) == before, "Source master was changed"
    assert len(info["clips"]) == len(model["Sequences"])
    print("WARCRAFT EXPORTED", key, len(info["clips"]), flush=True)


selected = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
assert not selected or selected in [["Blademaster"], ["Illidan"], ["Peasant"]], selected
for name, key in [("Blademaster", "blademaster"), ("Illidan", "demon-hunter"), ("Peasant", "peasant")]:
    if (not selected and name != "Peasant") or name in selected:
        export(name, key)
