# Fire Siege Astra implementation handoff

Start with ASTRA_START_HERE.md, then read the complete specification and its two JSON companions. The editable DOCX is the same handoff in document form. This package documents confirmed requirements and explicitly unresolved decisions; it does not implement or validate a playable redesigned game.

## Included documentation

- ASTRA_START_HERE.md: concise pasteable prompt and file order
- fire_siege_redesign_v0_2.md: full implementation handoff, source map, decision register, and acceptance contracts
- fire_siege_redesign_decisions_v0_2.json: canonical values, state contracts, decision IDs, and approval boundaries
- fire_siege_asset_contract_v0_2.json: exact reusable files, nodes, clips, axes, and import settings
- Fire Siege Redesign Implementation Specification v0.2.docx: editable document rendering

The standalone Library Markdown handoff contains the complete readable specification, not just the prompt. The actual GLB and Blender assets are separate supplied packages; the documentation alone does not contain those models.

## Source and planned placement

Repository eric2532/Goemon; source branch label codex/fire-siege-universal-controls; authoritative baseline commit 81b9f0b69ea6b0fef3c3b832d24641ca64eb8640. Preserve that baseline and unrelated work. The branch label is not a statement about its current remote head.

Planned docs destination: docs/handoffs/fire-siege-economy-v0.2/. Planned runtime roots: assets/economy_v1/arrow_tower/, assets/economy_v1/gold_mine/, and assets/economy_v1/construction_fx/. The optional assets/economy_v1/presentation/combined_demo/ is presentation-only. Blender sources are .blend.gz; extract before editing.

Local staging has been verified separately, but GitHub publication is pending. Do not claim these paths exist on the baseline branch or publish based on a gameplay-number approval.

## Design authority

The latest canonical values are 10 starting gold; 5-gold arrow tower; one visible 50-damage arrow every 0.5 seconds; initial normal HP 100; 10-gold mine earning 2 gold/sec during combat; combat-only direct gold drain per completed tower, including idle towers, with numeric drain and zero-wallet behavior unresolved. All ten waves use 5 enemies/sec for 60 seconds, then remaining-enemy clearance. No kills yield gold or pickups. Each completed wave N pays 10 × N, including the final 100 before victory.

Null is unresolved. Proposed values, old source defaults, animation durations, and simulation scenarios are not approved balance. The decision register preserves all open areas, not just upkeep. Runtime values in the specification supersede older annotations inside visual model packages. No rebuilding of geometry is required for balance changes.
