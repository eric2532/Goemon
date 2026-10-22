# Fire Siege economy asset provenance

The tower, mine, and construction effects are preserved under `assets/economy_v1/`. Their local README files describe node names, animation clips, import settings, and editing/export workflows. The combined presentation under `assets/economy_v1/presentation/combined_demo/` is an asset demonstration.

This directory retains asset origin and integrity data. The superseded v0.2 gameplay specification, duplicate DOCX, and implementation prompts are available in Git history. Use the current game source for gameplay behavior.

- [Asset provenance](PROVENANCE.md)
- `SOURCE_PROVENANCE.json`: original source hashes, including compressed Blender sources.
- `INVENTORY.json` and `SHA256SUMS.txt`: retained package file integrity.

Run from the repository root:

```sh
python3 docs/handoffs/fire-siege-economy-v0.2/verify_inventory.py
```
