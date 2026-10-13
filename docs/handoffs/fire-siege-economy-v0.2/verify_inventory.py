#!/usr/bin/env python3
"""Verify this handoff from an unmodified repository checkout (stdlib only)."""
from pathlib import Path
import gzip
import hashlib
import json
import struct
import sys

HERE = Path(__file__).resolve().parent
ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else HERE.parents[2]


def checked_path(relative):
    path = (ROOT / relative).resolve()
    if ROOT not in path.parents or not path.is_file():
        raise ValueError(f"Invalid or missing package path: {relative}")
    return path


def verify():
    entries = json.loads((HERE / "INVENTORY.json").read_text())["files"]
    for entry in entries:
        data = checked_path(entry["path"]).read_bytes()
        assert len(data) == entry["bytes"], entry["path"] + " size mismatch"
        assert hashlib.sha256(data).hexdigest() == entry["sha256"], entry["path"] + " SHA-256 mismatch"
        git_sha = hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()
        assert git_sha == entry["git_blob_sha1"], entry["path"] + " Git blob mismatch"
        if entry["path"].endswith(".glb"):
            magic, version, length = struct.unpack_from("<4sII", data)
            assert (magic, version, length) == (b"glTF", 2, len(data)), entry["path"] + " invalid GLB"
            json_length, json_type = struct.unpack_from("<II", data, 12)
            assert json_type == 0x4E4F534A, entry["path"] + " missing glTF JSON"
            gltf = json.loads(data[20:20 + json_length])
            assert all("uri" not in b for b in gltf.get("buffers", [])), entry["path"] + " external buffer"
            assert all("uri" not in image or image["uri"].startswith("data:") for image in gltf.get("images", [])), entry["path"] + " external image"
    for line in (HERE / "SHA256SUMS.txt").read_text().splitlines():
        expected, relative = line.split("  ", 1)
        assert hashlib.sha256(checked_path(relative).read_bytes()).hexdigest() == expected, relative + " checksum-list mismatch"
    original = json.loads((HERE / "SOURCE_PROVENANCE.json").read_text())["files"]
    for entry in original:
        data = checked_path(entry["path"]).read_bytes()
        if entry["compression"] == "gzip":
            data = gzip.decompress(data)
        assert len(data) == entry["original_bytes"], entry["path"] + " original size mismatch"
        assert hashlib.sha256(data).hexdigest() == entry["original_sha256"], entry["path"] + " original SHA-256 mismatch"
    print(f"PASS: {len(entries)} payload files, checksum list, source provenance, and self-contained GLBs")


if __name__ == "__main__":
    verify()
