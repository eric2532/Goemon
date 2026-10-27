"""Import decisions preserve edits, deletions and engine/cache changes."""
from pathlib import Path
import os
import tempfile
import unittest
from goemon_import_cache import snapshot


class ImportSnapshotTest(unittest.TestCase):
    def test_invalidation(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            engine = root / '.engine'
            engine.write_text('engine')
            (root / 'project.godot').touch()
            (root / '.godot/imported').mkdir(parents=True)
            asset = root / 'model.glb'
            asset.write_bytes(b'first')
            cached = snapshot(root, engine)
            self.assertEqual(cached, snapshot(root, engine))
            # Content replacement with unchanged length/mtime must still refresh.
            stat = asset.stat()
            asset.write_bytes(b'other')
            os.utime(asset, ns=(stat.st_atime_ns, stat.st_mtime_ns))
            self.assertNotEqual(cached, snapshot(root, engine))
            cached = snapshot(root, engine)
            asset.unlink()
            self.assertNotEqual(cached, snapshot(root, engine))
            cached = snapshot(root, engine)
            asset.touch()
            self.assertNotEqual(cached, snapshot(root, engine))
            cached = snapshot(root, engine)
            asset.rename(root / 'renamed.glb')
            self.assertNotEqual(cached, snapshot(root, engine))
            cached = snapshot(root, engine)
            engine.write_text('new engine')
            self.assertNotEqual(cached, snapshot(root, engine))
            imported = root / '.godot/imported/model.scn'
            imported.touch()
            cached = snapshot(root, engine)
            imported.unlink()
            self.assertNotEqual(cached, snapshot(root, engine))
            ignored = root / 'build'
            ignored.mkdir()
            (ignored / '.gdignore').touch()
            cached = snapshot(root, engine)
            (ignored / 'capture.png').touch()
            (root / '.godot/shader_cache').mkdir()
            (root / '.godot/shader_cache/shader').touch()
            self.assertEqual(cached, snapshot(root, engine))
            (ignored / '.gdignore').unlink()
            self.assertNotEqual(cached, snapshot(root, engine))
            nested = root / 'nested'
            nested.mkdir()
            (nested / 'project.godot').touch()
            cached = snapshot(root, engine)
            (nested / 'asset.png').touch()
            self.assertEqual(cached, snapshot(root, engine))


if __name__ == '__main__':
    unittest.main()
