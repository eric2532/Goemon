"""Recover native weapon effects from the user's local retail Xbox map.

Run with the optional research dependencies in requirements.txt. This tool reads
the map only; it never downloads assets or copies an engine implementation.
PNG atlases retain their original sprite UVs; WAV samples are decoded Xbox ADPCM.
The manifest retains native Halo units (3.048 metres per world unit), radians,
seconds, and enum/function values. No arena gameplay scaling is applied here.
"""
import argparse
import collections
import contextlib
import hashlib
import json
import math
from pathlib import Path
import struct
import wave


WEAPONS = {
    "rocket_launcher": "rocket launcher",
    "pistol": "pistol",
    "shotgun": "shotgun",
    "assault_rifle": "assault rifle",
}
FX_CLASSES = {
    "effect", "particle", "particle_system", "point_physics", "contrail",
    "decal", "light", "light_volume", "lens_flare", "bitmap", "sound", "sound_looping",
    "material_effects", "damage_effect", "projectile", "shader_transparent_generic",
    "shader_transparent_chicago", "shader_transparent_chicago_extended",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def references(node):
    """Walk actual dependency fields, including reflexive STEPTREE children."""
    result = {}

    def walk(value):
        if hasattr(value, "filepath") and hasattr(value, "tag_class"):
            if value.filepath:
                ref = {"class": value.tag_class.enum_name, "path": value.filepath}
                result[(ref["class"], ref["path"])] = ref
            return
        if not hasattr(value, "desc"):
            return
        try:
            for child in value:
                walk(child)
        except (TypeError, AttributeError):
            pass
        if hasattr(value, "STEPTREE"):
            walk(value.STEPTREE)

    walk(node)
    return list(result.values())


def normalize(value, descriptor=None):
    """Preserve all named native fields without map pointers or raw blob dumps.

    Enums are readable labels with raw indices alongside in _enum_values.
    Bit flags are integer masks with enabled labels alongside in _flag_names.
    The separately retained native tags carry original pixels/sound sample bytes.
    """
    if value is None or isinstance(value, (str, bool, int)):
        return value
    if isinstance(value, float):
        if not math.isfinite(value):
            return {"non_finite_float": repr(value)}
        return value
    if isinstance(value, (bytes, bytearray, memoryview)):
        return {"byte_length": len(value), "sha256": digest(value)}
    desc = getattr(value, "desc", descriptor or {})
    type_name = getattr(desc.get("TYPE"), "name", "")
    if hasattr(value, "filepath") and hasattr(value, "tag_class"):
        return {"class": value.tag_class.enum_name, "path": value.filepath}
    if type_name == "Reflexive":
        return [normalize(child) for child in value.STEPTREE]
    if type_name == "RawdataRef":
        data = bytes(value.STEPTREE)
        return {"byte_length": len(data), "sha256": digest(data)}
    if hasattr(value, "enum_name"):
        return value.enum_name
    if hasattr(value, "data"):
        return normalize(value.data)
    if "Array" in type_name or type_name == "Array":
        return [normalize(child) for child in value]
    result, enums, flags = {}, {}, {}
    for index, child in enumerate(value):
        field = desc.get(index, {})
        name = field.get("NAME", str(index))
        result[name] = normalize(child, field)
        if hasattr(child, "enum_name"):
            enums[name] = int(child.data)
        elif getattr(getattr(child, "desc", {}).get("TYPE"), "name", "").startswith("Bool"):
            flags[name] = [n for n in child.desc.get("NAME_MAP", {}) if getattr(child, n, False)]
    if enums:
        result["_enum_values"] = enums
    if flags:
        result["_flag_names"] = flags
    return result


def uri(path, project):
    return "res://" + path.relative_to(project).as_posix()


def resolve_tag(manifest, cls, path):
    entry = manifest["tags"].get(manifest["tag_keys"].get(cls, {}).get(path, path))
    return entry if entry and entry["class"] == cls else None


def authored_data(cls, meta):
    """Undo documented retail map compilation scalars, preserving raw values.

    These are tag format unit corrections, not Goemon's gameplay adaptation.
    All spatial lengths remain native Halo world units.
    """
    data = normalize(meta)
    raw = {}
    def scale(container, name, factor, qualified):
        raw[qualified] = container[name]
        container[name] *= factor
    if cls == "projectile":
        for name in ("initial_velocity", "final_velocity"):
            scale(data["proj_attrs"]["physics"], name, 30.0, "proj_attrs.physics." + name)
    elif cls == "point_physics":
        for name in ("air_friction", "water_friction"):
            scale(data, name, .0001, name)
    elif cls == "light":
        scale(data["effect_parameters"], "duration", 1/30, "effect_parameters.duration")
    elif cls == "damage_effect":
        scale(data["camera_shaking"], "wobble_function_period", 1/30, "camera_shaking.wobble_function_period")
    elif cls == "sound":
        raw["maximum_bend_per_second"] = data["maximum_bend_per_second"]
        data["maximum_bend_per_second"] **= 30
    return data, raw


def canonical_pcm_wav(path):
    # Reclaimer 2.11's extended PCM fmt header undercounts RIFF size by 4.
    # Rewrap exactly the same decoded sample bytes in the standard PCM header.
    with wave.open(str(path), "rb") as source:
        channels, width, rate = source.getnchannels(), source.getsampwidth(), source.getframerate()
        samples = source.readframes(source.getnframes())
    with wave.open(str(path), "wb") as target:
        target.setnchannels(channels)
        target.setsampwidth(width)
        target.setframerate(rate)
        target.writeframes(samples)


def add_markers(manifest, project):
    """Recover native model markers and match the existing glTF basis exactly.

    Existing JMS conversion rotates +90deg about Blender Z, scales .03048,
    then exports Y-up: (x,y,z) -> (-y,z,-x). Native JMS quaternions are
    conjugated by the existing build_master_chief.py converter.
    """
    source = project / "assets/blender/master_chief/decoded_assets.json"
    if not source.is_file():
        return
    decoded = json.loads(source.read_text())
    def quat_mul(a, b):
        x,y,z,w = a; X,Y,Z,W = b
        return [w*X+x*W+y*Z-z*Y, w*Y-x*Z+y*W+z*X,
                w*Z+x*Y-y*X+z*W, w*W-x*X-y*Y-z*Z]
    def rotate(q, p):
        norm = math.sqrt(sum(v*v for v in q))
        q = [v/norm for v in q]
        return quat_mul(quat_mul(q, list(p)+[0]), [-q[0],-q[1],-q[2],q[3]])[:3]
    def local(state):
        x,y,z,w = state["rotation"]
        return list(state["position"]), [-x,-y,-z,w]
    def combine(a, b):
        p = rotate(a[1], b[0])
        return ([a[0][i]+p[i] for i in range(3)], quat_mul(a[1], b[1]))
    def godot(transform):
        (x,y,z),(qx,qy,qz,qw) = transform
        return {"position": [-y*.03048,z*.03048,-x*.03048],
                "rotation_xyzw": [-qy,qz,-qx,qw]}
    for slot in WEAPONS:
        data = decoded if slot == "assault_rifle" else decoded["weapons"][slot]
        model = data["rifle_fp"] if slot == "assault_rifle" else data["model"]
        animation = (data["fp_animations"] if slot == "assault_rifle" else data["animations"])["idle"]
        nodes, frames = animation["nodes"], animation["frames"][0]
        parents = [-1] * len(nodes)
        for i,node in enumerate(nodes):
            child = node["child"]
            while child >= 0:
                parents[child] = i
                child = nodes[child]["sibling"]
        worlds = {}
        def world(i):
            if i not in worlds:
                worlds[i] = combine(world(parents[i]), local(frames[i])) if parents[i]>=0 else local(frames[i])
            return worlds[i]
        byname = {n["name"]: i for i,n in enumerate(nodes)}
        markers = {}
        for marker in model["markers"]:
            bone = model["nodes"][marker["parent"]]["name"]
            entry = {"bone": bone, "native_jms": marker,
                     "godot_local": godot(local(marker))}
            if bone in byname:
                entry["godot_idle"] = godot(combine(world(byname[bone]), local(marker)))
            markers[marker["name"]] = entry
        manifest["weapons"][slot]["markers"] = markers
    manifest["units"]["marker_space"] = "godot_idle: model-local meters; native_jms: .01 Halo world units; godot_local: bone-local meters in converted basis"


def validate(manifest, project):
    """Check playable files, native sprite bounds, dependency closure and roots."""
    from PIL import Image
    errors = []
    images = samples = sprite_count = 0
    for path, entry in manifest["bitmaps"].items():
        for file in entry["files"]:
            local = project / file["path"][6:]
            with Image.open(local) as image:
                image.verify()
            images += 1
        data = resolve_tag(manifest, "bitmap", path)["data"]
        for sequence in data["sequences"]:
            for sprite in sequence["sprites"]:
                sprite_count += 1
                index = sprite["bitmap_index"]
                if index < 0 or index >= len(entry["files"]):
                    errors.append("sprite bitmap index: " + path)
                if not (0 <= sprite["left_side"] < sprite["right_side"] <= 1 and
                        0 <= sprite["top_side"] < sprite["bottom_side"] <= 1):
                    errors.append("sprite UV bounds: " + path)
    for entry in manifest["sounds"].values():
        for file in entry["files"]:
            local = project / file["path"][6:]
            raw = local.read_bytes()
            if struct.unpack_from("<I", raw, 4)[0] != len(raw)-8:
                errors.append("invalid RIFF length: " + file["path"])
            with wave.open(str(local), "rb") as sample:
                if sample.getsampwidth() != 2 or sample.getnframes() <= 0:
                    errors.append("invalid PCM sample: " + file["path"])
            samples += 1
    for weapon in manifest["weapons"].values():
        if not resolve_tag(manifest, "effect", weapon["firing_effect"]["path"]):
            errors.append("missing firing effect")
        if not resolve_tag(manifest, "projectile", weapon["projectile"]["path"]):
            errors.append("missing projectile")
    for entry in manifest["tags"].values():
        for ref in entry["dependencies"]:
            if ref["class"] in FX_CLASSES and not resolve_tag(manifest, ref["class"], ref["path"]):
                errors.append("unresolved effect dependency: " + ref["path"])
    return {"errors": sorted(set(errors)), "png_atlases": images,
            "sprite_rectangles": sprite_count, "pcm_wav_samples": samples,
            "native_tags": len(manifest["tags"])}


def extract(map_path, project, report_dir):
    from refinery.core import RefineryCore
    from reclaimer.enums import materials_list, material_effect_types
    runtime = project / "assets/characters/master_chief/effects"
    editable = project / "assets/blender/master_chief/effects"
    runtime.mkdir(parents=True, exist_ok=True)
    editable.mkdir(parents=True, exist_ok=True)
    report_dir.mkdir(parents=True, exist_ok=True)
    with (report_dir / "extract.log").open("w") as log, contextlib.redirect_stdout(log), contextlib.redirect_stderr(log):
        refinery = RefineryCore()
        halo_map = refinery.load_map(map_path, autoload_resources=False)
        index = {(t.class_1.enum_name, t.path): i for i, t in enumerate(halo_map.tag_index.tag_index)}
        manifest = {
            "schema": 1,
            "source": {"map": map_path.name, "sha256": digest(map_path.read_bytes()),
                       "edition": "Halo Combat Evolved retail Xbox (user supplied)"},
            "units": {"length": "Halo world units", "metres_per_world_unit": 3.048,
                      "time": "seconds", "angles": "radians",
                      "velocity": "world units per second", "arena_scale_applied": False,
                      "map_compilation_corrections": {
                          "projectile.proj_attrs.physics.initial_velocity": "map value * 30",
                          "projectile.proj_attrs.physics.final_velocity": "map value * 30",
                          "light.effect_parameters.duration": "map value / 30",
                          "damage_effect.camera_shaking.wobble_function_period": "map value / 30",
                          "point_physics.air_friction": "map value / 10000",
                          "point_physics.water_friction": "map value / 10000",
                          "sound.maximum_bend_per_second": "map value ** 30"},
                      "note": "Data uses authored tag units with explicit compilation corrections; each affected entry.map_values retains the compiled values. Caller explicitly converts lengths. Bitmap UVs are normalized atlas coordinates. RGB values and function/enum indices are native."},
            "materials": list(materials_list), "material_effect_types": list(material_effect_types),
            "tags": {}, "tag_keys": {}, "bitmaps": {}, "sounds": {}, "weapons": {},
            "defaults": {"light_volume_bitmap": {"class": "bitmap", "path": "rasterizer\\glow"}},
            "missing": [],
        }
        queue = collections.deque()
        for slot, name in WEAPONS.items():
            path = "weapons\\" + name + "\\" + name
            meta = halo_map.get_meta(index[("weapon", path)])
            data = normalize(meta)
            trigger = data["weap_attrs"]["triggers"][0]
            projectile = trigger["projectile"]["projectile"]
            firing_effect = trigger["firing_effects"][0]["firing_effect"]
            root = {"weapon": {"class": "weapon", "path": path},
                    "projectile": projectile, "firing_effect": firing_effect,
                    "trigger": trigger,
                    "attachments": data["obje_attrs"]["attachments"],
                    "functions": data["obje_attrs"]["functions"]}
            manifest["weapons"][slot] = root
            # Weapon metadata supplies firing/reload/switch roots, but do not walk
            # models, HUDs, ammo pickups, or unrelated object dependencies.
            queue.append(("weapon", path))
            for ref in references(meta):
                if ref["class"] in FX_CLASSES:
                    queue.append((ref["class"], ref["path"]))
            anim_path = "weapons\\" + name + "\\fp\\fp"
            if ("model_animations", anim_path) in index:
                anim = halo_map.get_meta(index[("model_animations", anim_path)])
                root["animation_sound_references"] = normalize(anim.sound_references)
                root["animation_sound_events"] = [
                    {key: normalize(getattr(a, key)) for key in
                     ("name", "frame_count", "frame_rate", "sound", "sound_frame_index")
                     if hasattr(a, key)} for a in anim.animations.STEPTREE
                ]
                for ref in references(anim.sound_references):
                    queue.append((ref["class"], ref["path"]))
        # Exhaust/explosion are reachable from rocket projectile, so no guessed
        # path aliases or flattened hand-authored replacements are required.
        seen = set()
        while queue:
            cls, path = queue.popleft()
            if (cls, path) in seen:
                continue
            seen.add((cls, path))
            if (cls, path) not in index:
                manifest["missing"].append({"class": cls, "path": path})
                continue
            print("Recovering", cls, path, flush=True)
            tag_index = index[(cls, path)]
            meta = halo_map.get_meta(tag_index)
            if meta is None:
                raise ValueError("Failed to read " + path)
            refs = references(meta)
            if cls == "light_volume" and not meta.map.filepath:
                # Null maps are functional: retail widgets bind the global
                # rasterizer glow bitmap rather than treating this as disabled.
                refs.append({**manifest["defaults"]["light_volume_bitmap"], "implicit_default": True})
            data,map_values = authored_data(cls, meta)
            entry = {"class": cls, "data": data, "dependencies": refs}
            if map_values:
                entry["map_values"] = map_values
            manifest["tags"][(cls, path)] = entry
            refinery.extract_tag(tag_index, extract_mode="tags", out_dir=editable / "tags", do_printout=False)
            for ref in refs:
                if ref["class"] in FX_CLASSES:
                    queue.append((ref["class"], ref["path"]))
            if cls not in ("bitmap", "sound"):
                continue
            result = refinery.extract_tag(tag_index, extract_mode="data", out_dir=runtime,
                                          do_printout=False, bitmap_extract_format="png", decode_adpcm=True)
            if result is not True:
                raise ValueError("Failed to extract " + cls + " " + path + ": " + repr(result))
            local = runtime / Path(*path.split("\\"))
            if cls == "bitmap":
                from PIL import Image
                entries = []
                native_bitmaps = meta.bitmaps.STEPTREE
                for bitmap_index, bitmap in enumerate(native_bitmaps):
                    stem = local.name + ("__" + str(bitmap_index) if len(native_bitmaps)>1 else "")
                    # Match exact stems: 'flash h pistol*' also matches the
                    # separate 'flash h pistol detonate' atlas, corrupting UVs.
                    files = ([local.parent / (stem + ".png")] if bitmap.type.enum_name != "cubemap"
                             else sorted(local.parent.glob(stem + "_tex[0-5].png")))
                    for face_index,file in enumerate(files):
                        with Image.open(file) as image:
                            width, height = image.size
                        entry = {"bitmap_index": bitmap_index, "path": uri(file, project),
                                 "width": width, "height": height, "sha256": digest(file.read_bytes())}
                        if bitmap.type.enum_name == "cubemap":
                            entry["cubemap_face"] = face_index
                        entries.append(entry)
                manifest["bitmaps"][path] = {"files": entries}
            else:
                files = sorted(local.rglob("*.wav"))
                entries = []
                for file in files:
                    canonical_pcm_wav(file)
                    with wave.open(str(file), "rb") as sample:
                        entries.append({"path": uri(file, project), "permutation": file.stem,
                                        "sample_rate": sample.getframerate(), "channels": sample.getnchannels(),
                                        "sample_frames": sample.getnframes(),
                                        "duration": sample.getnframes() / sample.getframerate(),
                                        "sha256": digest(file.read_bytes())})
                manifest["sounds"][path] = {"files": entries}
            if not entries:
                raise ValueError("No extracted files for " + cls + " " + path)
        # Native tags can share a path across classes (bullet projectile/damage).
        # Preserve every tag, leaving the renderable/projectile at the plain path.
        native_tags = manifest["tags"]
        manifest["tags"] = {}
        priority = {"projectile": 0, "particle": 1, "effect": 2, "bitmap": 3}
        for (cls,path),entry in sorted(native_tags.items(), key=lambda item: priority.get(item[0][0], 10)):
            key = path if path not in manifest["tags"] else path + "." + cls
            entry["native_path"] = path
            manifest["tags"][key] = entry
            manifest["tag_keys"].setdefault(cls, {})[path] = key
        add_markers(manifest, project)
        external = {}
        for entry in manifest["tags"].values():
            for ref in entry["dependencies"]:
                if ref["class"] not in FX_CLASSES:
                    external[(ref["class"], ref["path"])] = {
                        **ref, "present_in_source_map": (ref["class"], ref["path"]) in index,
                        "scope": "external models, animation, inventory or HUD; outside the effects graph",
                    }
        manifest["coverage"] = {
            "supported_dependency_classes": sorted(FX_CLASSES),
            "external_dependencies": list(external.values()),
            "missing_scope": "missing counts only supported effect dependencies; external dependencies are enumerated separately",
        }
        # An exact native copy plus JSON makes the source metadata editable.
        manifest_path = runtime / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2, allow_nan=False) + "\n")
        (editable / "native_effects.json").write_text(manifest_path.read_text())
        report = validate(manifest, project)
        report["classes"] = dict(collections.Counter(t["class"] for t in manifest["tags"].values()))
        report["missing"] = manifest["missing"]
        (report_dir / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
        (report_dir / "native_effects.json").write_text(manifest_path.read_text())
        if report["errors"] or report["missing"]:
            raise ValueError("Recovery validation failed: " + repr(report))
    print(json.dumps(report, indent=2))
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("map", type=Path)
    parser.add_argument("project", type=Path)
    parser.add_argument("report_dir", type=Path)
    args = parser.parse_args()
    extract(args.map.resolve(), args.project.resolve(), args.report_dir.resolve())


if __name__ == "__main__":
    main()
