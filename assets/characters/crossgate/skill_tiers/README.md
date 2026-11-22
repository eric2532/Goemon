# Original Cross Gate skill tiers

The ordinary PNGs are exact copies from the preserved Magic Power recovery.
The EX PNGs are decoded directly from the preserved V3 client pack with the
same decoder. Source IDs, SHA-256 hashes, frame bounds and timing are in
`manifest.json`. Existing shared sheets are referenced directly. Identical
Fire variants share one path and immutable texture.

Rebuild from the complete Goemon project:

```sh
python3 tools/recover_crossgate_skill_tiers.py '../Magic Power'
```

Fire, Ice, Wind and Meteor use original ranks 1, 4, 7 and 10 for levels 1–9,
10–18, 19–27 and 28–29. Level 30 uses the EX cast and target sheets, including
all three distinct Fire and Meteor EX variants. The current attack clocks and
contact volumes still use the ordinary tier.

Recovery and meditation also use the four ordinary tiers and the EX tier.
Physical charge, Qi and Two Birds select their prepared EX sheets at level 30.
Guard Break uses its verified EX contact when set to 30 in Skill Balance.

The existing pooled projectile/recovery owners select these prepared resources.
No extraction, asset loading, new material or controller is needed per hit.
User-approved elemental presentation uses a shared 1.25 runtime visual scale
for Fire/Ice/Wind/Meteor casts, bodies, trails and impacts at every level.
Combat dimensions and the source PNGs remain unchanged; Ice/Wind stay grounded.
`docs/crossgate-skill-rules.md` records level bands and gameplay budgets; comparison
captures and full original inventories are under `build/Other Files/Asset Toolkit/`.
