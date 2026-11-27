#!/usr/bin/env python3
"""Stage a Godot 4.6.1 Web export without a monolithic Chrome response body."""

from argparse import ArgumentParser
from gzip import GzipFile
from hashlib import sha256
from pathlib import Path
from shutil import copyfile, copyfileobj
from tempfile import TemporaryDirectory
import json
import re


PART_SIZE = 64 * 1024 * 1024
ENGINE_FILES = (
    "index.js",
    "index.wasm",
    "index.side.wasm",
    "index.audio.worklet.js",
    "index.audio.position.worklet.js",
    "index.png",
    "index.icon.png",
    "index.apple-touch-icon.png",
)


def stage(source: Path, destination: Path) -> None:
    if destination.exists():
        raise ValueError(f"Destination already exists: {destination}")
    html = (source / "index.html").read_text(encoding="utf-8")
    config_line = re.search(r"^const GODOT_CONFIG = (\{.+\});$", html, re.MULTILINE)
    engine_script = '<script src="index.js"></script>'
    start_game = "engine.startGame({"
    if not config_line or html.count(engine_script) != 1 or html.count(start_game) != 1:
        raise ValueError("Expected the standard Godot 4.6 Web export shell")
    config = json.loads(config_line[1])
    if config["executable"] != "index" or config.get("serviceWorker"):
        raise ValueError("Export as index.html with the Godot PWA option disabled")
    libraries = config["gdextensionLibs"]
    if not all(Path(name).name == name and name.endswith(".wasm") for name in libraries):
        raise ValueError("Expected WebAssembly libraries next to index.html")
    pack = source / "index.pck"
    size = pack.stat().st_size
    if not 0 < size <= 1000 * PART_SIZE or size != config["fileSizes"][pack.name]:
        raise ValueError("Pack size does not match the exported shell")

    with TemporaryDirectory(dir=destination.parent, prefix=".web-export-") as temporary:
        output = Path(temporary) / "export"
        output.mkdir()
        artifacts = {}
        for name in (*ENGINE_FILES, *libraries):
            copyfile(source / name, output / name)
        # Reduce the engine download size without rewriting the WebAssembly.
        with (output / "index.side.wasm.gz").open("wb") as compressed:
            with GzipFile(filename="", mode="wb", compresslevel=1, fileobj=compressed, mtime=0) as stream:
                with (output / "index.side.wasm").open("rb") as side_module:
                    copyfileobj(side_module, stream)
        pack_hash = sha256()
        with pack.open("rb") as stream:
            if stream.read(4) != b"GDPC":
                raise ValueError("Invalid resource pack header")
            stream.seek(0)
            for index in range((size + PART_SIZE - 1) // PART_SIZE):
                data = stream.read(PART_SIZE)
                if len(data) != min(PART_SIZE, size - index * PART_SIZE):
                    raise ValueError("Pack size changed during staging")
                name = f"{pack.name}.{index:03d}"
                (output / name).write_bytes(data)
                pack_hash.update(data)
                artifacts[name] = {"bytes": len(data), "sha256": sha256(data).hexdigest()}
            if stream.read(1):
                raise ValueError("Pack size changed during staging")
        copyfile(Path(__file__).with_name("web_pack_loader.js"), output / "index.pack.js")
        html = html.replace(engine_script, f'{engine_script}\n\t\t<script src="index.pack.js"></script>')
        part_hashes = json.dumps([part["sha256"] for part in artifacts.values()])
        html = html.replace(start_game, f"startCrossGate(engine, GODOT_CONFIG, {part_hashes}, {{")
        (output / "index.html").write_text(html, encoding="utf-8")
        for path in output.iterdir():
            if path.name not in artifacts:
                data = path.read_bytes()
                artifacts[path.name] = {"bytes": len(data), "sha256": sha256(data).hexdigest()}
        (output / "build-info.json").write_text(
            json.dumps({
                "build_id": destination.name,
                "godot": "4.6.1",
                "pack_sha256": pack_hash.hexdigest(),
                "artifacts": artifacts,
            }, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        output.rename(destination)


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="folder containing the Godot index.html export")
    parser.add_argument("destination", type=Path, help="new folder for public export files")
    arguments = parser.parse_args()
    try:
        stage(arguments.source, arguments.destination)
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f"Cannot stage Web export: {error}\n")
