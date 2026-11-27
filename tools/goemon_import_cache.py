"""Skip the editor importer only when its source and generated inputs match."""
from pathlib import Path
from hashlib import sha256
import json
import os
import sys


def snapshot(project, engine):
    rows = []
    for folder, dirs, files in os.walk(project):
        root = Path(folder)
        if ".gdignore" in files or (root != project and "project.godot" in files):
            dirs[:] = []
            continue
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for name in sorted(files):
            if name.startswith("."):
                continue
            path = root / name
            stat = path.stat()
            rows.append((str(path.relative_to(project)), stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns))
    # Missing/replaced imports must trigger repair, even with unchanged sources.
    for path in sorted((project / ".godot/imported").glob("*")):
        stat = path.stat()
        rows.append((str(path.relative_to(project)), stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns))
    stat = engine.stat()
    rows.append((str(engine), stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns))
    # Godot rewrites the class list at runtime even when its contents match.
    for name in ("global_script_class_cache.cfg", "extension_list.cfg"):
        path = project / ".godot" / name
        if path.is_file():
            rows.append((str(path), sha256(path.read_bytes()).hexdigest()))
    return json.dumps(rows, separators=(",", ":"))


def main():
    mode, project_path, engine_path = sys.argv[1:]
    project = Path(project_path)
    cache = project / ".godot/goemon_import_snapshot.json"
    current = snapshot(project, Path(engine_path))
    if mode == "check":
        return 0 if (project / ".godot/editor/filesystem_cache10").is_file() and cache.is_file() and cache.read_text() == current else 1
    if mode != "record":
        raise ValueError("Expected check or record")
    temporary = cache.with_suffix(".tmp")
    temporary.write_text(current)
    temporary.replace(cache)
    return 0


if __name__ == "__main__":
    sys.exit(main())
