"""Compatibility entry point for the source-derived East cliff-volume pipeline.

The rejected single-surface relief-field prototype is superseded by complete
closed stone volumes. Default output stays private; --publish is explicit.
"""
from east_cliff_geometry import clean_face, lobes, native_triangles, project, raster, rounded_native
from prepare_east_cliff_volumes import main

if __name__ == '__main__':
    main()
