# Goemon v2.13.0 — Ronin scarf

Blender 5.2.2 authored a separate four-mesh garment fitted to the original Goemon rig. Two asymmetric tails (3.2 m and 2.45 m) include torn topology, distressed edges, cloth folds and repair stitches. The SHA-256 check confirms the original kai.blend remains unchanged. The editable scene includes Goemon for fitting; the exported GLB contains only the garment.

The game attaches the scarf to the final animated chest pose. Its shader responds to running speed and turning and freezes while paused. Key 4 toggles outfit and bonuses. Normal movement, sprint and slow walk multiply by three; acceleration scales accordingly. Three jumps are available only to scarf-equipped Goemon. Unequipping or switching to Edo removes the movement bonus; midair toggles cannot refill jumps. Outfit selection is retained through character switching and retries.

Validation completed:
- Rendered scarf suite: 30 checks passed; screenshots reviewed from front, side, running, Golden Surge, triple jump and T leap.
- Packaged macOS scarf suite: 30 checks passed.
- Dash and audio priority regression: 39 checks passed.
- Chain pipe regression: 29 checks passed.
- Edo firecaster regression: 49 checks passed.
- Actual run speeds: 10.2 / 30.6 m/s; sprint 18 / 54; slow walk 2.2 / 6.6.
- Boosted sprint respects solid wall collision; no fourth jump or toggle-based jump refill.
- Universal macOS release export succeeded with version 2.13.0; codesign deep/strict verification passed.

Existing headless chain/Edo shutdown resource warnings remain. Rendered scarf and packaged scarf runs exited cleanly with zero failures.
Previous source and v2.12 app/ZIP are preserved in backups/ronin-scarf/.
