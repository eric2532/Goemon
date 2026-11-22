# Cross Gate stat symbols

Original editable SVGs for the character Stats panel and resource presentation.
Inspired by League of Legends' compact, colored stat silhouettes and dark/gold HUD;
these are original geometry, not recovered Riot artwork. Each icon is 64×64 and
is imported once, shared through `forest_hud_icons.gd::STATS`, and scaled with
linear filtering. Keep these SVGs as the authoritative sources.

- Heart: health / Vitality; circular arrow and cross: health regeneration.
- Sword: physical damage / Attack; crystal: magic power.
- Lightning: attack speed; shield: Defense; shield-minus: damage reduction.
- Impact burst: character critical chance / pet contact count.
- Boot with speed lines: character Dodge / pet base movement speed.
- Returning arrow and sword: counter attack; blue drop: mana.
- Gold spark-plus: the existing shared stat/skill/pet upgrade point.

The shared Stat view is embedded in Q Equipment. I and Shift+P are retired;
Equipment also contains explicit-slot pet selection and per-wearer skill upgrades.
The right panel switches to native pet health, normal attack data and learned
skill levels for the selected pet; it restores allocations for the character.

Names and point effects remain on hover tooltips and keyboard-focused upgrade
buttons retain their focus outline. Stat keys, rank order and gameplay formulas
are unchanged. The previous recovered status frame is preserved in `../status/`.

Mana starts at 100/100 and follows the controlled player between character
selections. New runs and respawn refill it. Skill costs and mana regeneration
are not enabled by this presentation pass.

Use `Play Goemon.command --script res://tests/forest-shrine/unified_equipment_test.gd`
for rendered evidence. Captures and logs belong under
`build/Other Files/Asset Toolkit/Unified Equipment/`.
