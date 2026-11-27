#!/usr/bin/env python3
"""Compare a Godot 4.6 Web PCK with the launcher source and a desktop PCK."""

import argparse
import base64
import fnmatch
import json
import re
import struct
import zlib
from collections import Counter
from pathlib import Path, PurePosixPath
from posixpath import normpath


ROOT = Path(__file__).resolve().parent.parent
MAP_CATALOGS = (
    "assets/maps/original_crossgate/catalog.json",
    "assets/maps/falan/sokia/fixed/catalog.json",
    "assets/maps/original_crossgate/university/catalog.json",
    "assets/maps/original_crossgate/elsa/catalog.json",
)
PLAYABLE_MAPS = (
    "assets/maps/forest_wind_meadow.json",
    "assets/maps/forest_wind_meadow_large.json",
    "assets/maps/falan/web_adventure.json",
)
CROSSGATE = "assets/characters/crossgate/"
PLAYER_AUDIO = "assets/audio/crossgate/player-attacks.json"
HEADS = "assets/ui/portraits/crossgate/model-heads.json"
WEB_FONT = "assets/ui/fonts/NotoSansCJKtc-Regular.otf"
WEB_FONT_LICENSE = "assets/ui/fonts/NotoSansTC-OFL.txt"
WEAPONS = CROSSGATE + "weapons/catalog.json"
PETS = CROSSGATE + "guard_pets/motions.json"
FORMAT = struct.Struct("<4sIIIIIQQ")
INDEX_ENTRY = struct.Struct("<QQ16sI")
REMAP = re.compile(r'^path(?:\.[\w_]+)?="res://([^"]+)"', re.MULTILINE)
RAW_READ = re.compile(
    r"""FileAccess\.(?:get_file_as_string|get_file_as_bytes|open)\(\s*["']res://([^"']+\.(?:json|bin))["']"""
)


class Pack:
    def __init__(self, path, stream):
        self.path = path
        self.stream = stream
        magic, version, major, minor, _, flags, base, directory = FORMAT.unpack(
            stream.read(FORMAT.size)
        )
        if (magic, version, major, minor, flags) != (b"GDPC", 3, 4, 6, 2):
            raise ValueError(f"{path}: expected an unencrypted Godot 4.6 pack")
        if not FORMAT.size <= base <= directory < path.stat().st_size:
            raise ValueError(f"{path}: pack directory offset is out of range")
        stream.seek(directory)
        self.entries = {}
        for _ in range(self.uint32()):
            length = self.uint32()
            name = stream.read(length).rstrip(b"\0").decode("utf-8")
            offset, size, digest, entry_flags = INDEX_ENTRY.unpack(stream.read(INDEX_ENTRY.size))
            if name in self.entries or base + offset + size > directory or entry_flags:
                raise ValueError(f"{path}: invalid entry {name}")
            self.entries[name] = (base + offset, size, digest)

    def uint32(self):
        return struct.unpack("<I", self.stream.read(4))[0]

    def read(self, path):
        offset, size, _ = self.entries[path]
        self.stream.seek(offset)
        return self.stream.read(size)

    def logical_entries(self):
        for path in self.entries:
            if path.startswith(".godot/") or path.endswith(".gdc"):
                continue
            yield path.removesuffix(".remap").removesuffix(".import")

    def has_resource(self, path):
        if path in self.entries:
            return True
        for descriptor in (path + ".import", path + ".remap"):
            if descriptor in self.entries:
                return any(target in self.entries for target in REMAP.findall(self.read(descriptor).decode()))
        return False


def resource_path(path):
    return path.removeprefix("res://")


def map_requirements(root, path):
    data = json.loads((root / path).read_bytes())
    parent = PurePosixPath(MAP_CATALOGS[0] if path in MAP_CATALOGS[2:] else path).parent
    atlases = {
        normpath(str(parent / page))
        for kind in ("pages", "solid_pages", "surface_pages")
        for page in data[kind]
    }
    return data, atlases


def check_map_catalog(pack, path, problems):
    data = json.loads(pack.read(path))
    for name, entry in data["maps"].items():
        width, height = entry["size"]
        size = width * height
        try:
            terrain = zlib.decompress(base64.b64decode(entry.get("restored_raw", entry["raw"])))
            walk = zlib.decompress(base64.b64decode(entry["walk"]))
            if len(terrain) != entry["bytes"] or len(terrain) != 20 + size * 6:
                raise ValueError("invalid terrain size")
            if terrain[:4] != b"MAP\x01" or struct.unpack_from("<II", terrain, 12) != (width, height):
                raise ValueError("invalid terrain header")
            if len(walk) != (size + 7) // 8:
                raise ValueError("invalid walk mask size")
        except (ValueError, zlib.error) as error:
            problems.append(f"{path}: {name}: {error}")
    return data["maps"]


def runtime_requirements(root):
    raw = set(PLAYABLE_MAPS) | set(MAP_CATALOGS) | {PLAYER_AUDIO, HEADS, WEAPONS, PETS}
    resources = {"scenes/forest_title.tscn", "scripts/forest/forest_game.gd"}
    if (root / WEB_FONT).is_file():
        resources.add(WEB_FONT)
        raw.add(WEB_FONT_LICENSE)
    sources = list((root / "scripts/forest").rglob("*.gd"))
    for name in ("crossgate_model.gd", "rogue_roster.gd", "assets.gd"):
        sources.append(root / "scripts" / name)
    for path in sources:
        raw.update(RAW_READ.findall(path.read_text()))

    for path in MAP_CATALOGS:
        _, atlases = map_requirements(root, path)
        resources.update(atlases)

    audio = json.loads((root / PLAYER_AUDIO).read_bytes())
    resources.update(resource_path(sample) for sample in audio["samples"].values() if sample)
    heads = json.loads((root / HEADS).read_bytes())
    resources.update(str(PurePosixPath(HEADS).parent / path) for path in heads.values())
    equipment = json.loads((root / WEAPONS).read_bytes())
    motion_roots = {resource_path(path) for path in audio["profiles"]}
    for fighter in equipment.values():
        for skin in fighter.values():
            for route in skin.values():
                if "root" in route:
                    motion_roots.add(resource_path(route["root"]))

    for path in motion_roots:
        manifest = path + "motions.json"
        raw.add(manifest)
        data = json.loads((root / manifest).read_bytes())
        for pose in [data, *data.get("weapons", [])]:
            if "art_pages" in pose:
                resources.update(resource_path(page) for page in pose["art_pages"])
            elif "atlas_paths" in pose:
                resources.update(resource_path(page) for page in pose["atlas_paths"])
            elif "pages" in pose and isinstance(pose["pages"], int):
                resources.update(path + f"atlas-{page}.png" for page in range(pose["pages"]))
            resources.update(resource_path(sample) for sample in pose.get("audio", {}).values())
        if (root / (path + "art.json")).is_file():
            raw.add(path + "art.json")

    pets = json.loads((root / PETS).read_bytes())
    resources.update(resource_path(path) for path in pets["atlas_paths"])
    resources.update(resource_path(pet["portrait_path"]) for pet in pets["variants"] if "portrait_path" in pet)
    resources.update(resource_path(sound["goemon_file"]) for sound in pets["sounds"].values())
    raw.add(CROSSGATE + "guard_pets/frames.bin")
    resources.add(CROSSGATE + "guard_pets/palette.png")

    return raw, resources, {
        "fighter_weapon_catalog_entries": len(equipment),
        "appearance_weapon_catalog_entries": sum(map(len, equipment.values())),
        "appearance_routes": sum(len(skin) for fighter in equipment.values() for skin in fighter.values()),
        "motion_manifest_roots": len(motion_roots),
        "prepared_hud_portraits": len(heads),
        "prepared_pet_appearances": len(pets["variants"]),
    }


def compare_pack(pack, reference, allowed_missing):
    desktop = {
        path for path in reference.logical_entries()
        if path.startswith(("assets/", "audio/", "scenes/", "scripts/"))
    }
    web = set(pack.logical_entries())
    return {
        "desktop_logical_paths": len(desktop),
        "web_logical_paths": len(web),
        "missing_desktop_paths": sorted(
            path for path in desktop
            if not pack.has_resource(path)
            and not any(fnmatch.fnmatchcase(path, pattern) for pattern in allowed_missing)
        ),
        "different_shared_raw_data": sorted(
            path for path in desktop
            if path.endswith((".json", ".bin")) and path in pack.entries and path in reference.entries
            and pack.entries[path][2] != reference.entries[path][2]
        ),
        "different_shared_compiled_scripts": sorted(
            path for path in pack.entries.keys() & reference.entries.keys()
            if path.endswith(".gdc") and pack.entries[path][2] != reference.entries[path][2]
        ),
    }


def audit(pack, root):
    raw, resources, inventory = runtime_requirements(root)
    missing_raw = sorted(raw - pack.entries.keys())
    different_raw = sorted(
        path for path in raw & pack.entries.keys()
        if not (root / path).is_file() or (root / path).read_bytes() != pack.read(path)
    )
    map_problems = []
    map_sizes = {}
    map_names = set()
    for path in MAP_CATALOGS:
        if path in pack.entries:
            maps = check_map_catalog(pack, path, map_problems)
            map_sizes[path] = len(maps)
            map_names.update(maps)
    return {
        "pack": str(pack.path),
        "source_root": str(root),
        "bytes": pack.path.stat().st_size,
        "pack_records": len(pack.entries),
        "required_resources_checked": len(resources),
        "required_raw_paths_checked": len(raw),
        "missing_required_resources": sorted(path for path in resources if not pack.has_resource(path)),
        "missing_required_raw_paths": missing_raw,
        "required_raw_data_differs_from_source": different_raw,
        "map_catalog_sizes": map_sizes,
        "unique_catalogued_map_records_read": len(map_names),
        "map_data_errors": map_problems,
        "inventory": inventory,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("web_pack", type=Path)
    parser.add_argument("--source-root", type=Path, default=ROOT, help="The exact project used for the export")
    parser.add_argument("--desktop-pack", type=Path, help="A current Painterly Preview macOS --export-pack")
    parser.add_argument("--allow-missing", action="append", default=[], metavar="PATH_PATTERN")
    args = parser.parse_args()
    with args.web_pack.open("rb") as web_stream:
        web = Pack(args.web_pack, web_stream)
        report = audit(web, args.source_root.resolve())
        problems = [
            report[key] for key in (
                "missing_required_resources", "missing_required_raw_paths",
                "required_raw_data_differs_from_source", "map_data_errors",
            )
        ]
        if args.desktop_pack:
            with args.desktop_pack.open("rb") as desktop_stream:
                comparison = compare_pack(web, Pack(args.desktop_pack, desktop_stream), args.allow_missing)
            report["desktop_comparison"] = comparison
            problems.extend([comparison["missing_desktop_paths"], comparison["different_shared_raw_data"]])
        report["missing_by_asset_family"] = dict(Counter(
            "/".join(path.split("/")[:4]) for path in report["missing_required_resources"]
        ))
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 1 if any(problems) else 0


if __name__ == "__main__":
    raise SystemExit(main())
