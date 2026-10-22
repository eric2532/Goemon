# Final asset validation tools

Run Blender Python tools through `/Applications/Blender.app/Contents/MacOS/Blender -b --python <script> -- --audit-only`.

- `verify_final.py`: reload the canonical file, compare the immutable geometry baseline plus the one documented cleanup exception, inspect topology and dependencies, and write `Validation/final_validation.json`. Use `--audit-only` to skip rendering. It never saves the Blender file.
- `asset_validation.py`: shared geometry fingerprint helper.
- `check_lighting.py`: render two temporary lighting variants in memory; never save lighting changes to the master.
- `assemble_final_review.py`: assemble equal-height comparisons and five close-ups from existing renders using Pillow; does not edit the Blender model.

The final material-generation and cleanup development scripts are preserved in `../../Archive/Musashi_Visual_Development.zip` under their original `Final/Tools/` paths. They should not be rerun as automatic visual revisions.
