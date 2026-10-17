# Forest Shrine enemy design

Recorded on 14 October 2026. The four enemy roles and visual requirements below are the design brief for the next implementation pass.

**Implementation authorized.** Eric said “ok implement these new enemies into the game” on 14 October 2026. The approved models and four target priorities are now being connected to Forest Shrine.

## Enemy roles

| Enemy | Primary target | Health | Intended behavior |
| --- | --- | --- | --- |
| Masked Raider | Main character | High | Pursue and attack the main character. |
| Reed Archer | Workers | Low | Prioritize killing workers. |
| Daruma Breaker | Towers and walls | Very high | Walk very slowly and prioritize destroying towers and walls. |
| Lantern Runner | Shrine | Low | Rush to the main base and attack the shrine. |

These are target priorities. Daruma has a written spec with proposed first-playtest values of 0.75 m/s and 3,000 HP. Exact combat values remain subject to review; the other enemy types, fallback rules, target switching, and wave composition still need balancing. Archer targeting of workers stationed in towers also needs a decision before implementation.

## Appearance and proportions

All four enemies must be larger than Goemon. The Raider and Archer use Goemon's large head, compact torso, short limbs, and oversized hands and feet as their humanoid proportion reference. The Daruma is now four times its previous height, width and depth, while retaining its broad round body, and the Lantern retains its paper body and single wooden leg.

Use rounded forms and softened edges. Faces must remain readable and fit curved geometry. The Raider's wooden mask sits over a full skull; its profile must preserve chest and pelvis depth. The Archer's hat, scarf, cloak, bow and quiver retain their distinct silhouette. The Daruma has a painted face on its curved body, and the Lantern has a painted face on its rounded paper shell.

## Saved concept sheets

Each sheet includes front, side and back views plus a Goemon comparison.

- [Masked Raider](turnarounds-v01/masked-raider-turnaround-v01.png)
- [Reed Archer](turnarounds-v01/reed-archer-turnaround-v01.png)
- [Daruma Breaker](turnarounds-v01/daruma-breaker-turnaround-v01.png)
- [Lantern Runner](turnarounds-v01/lantern-runner-turnaround-v01.png)

## Saved 3D assets

The current Daruma Breaker source and GLB are in `assets/blender/enemies/forest_redesign_v02/` and `assets/models/enemies/forest_redesign_v02/`. The other three sources and exports remain in their `forest_redesign_v01/` folders. The previous Daruma is preserved in those original folders. Painted textures are in `assets/textures/enemies/forest_redesign_v01/`.

| Asset | Current source height relative to Goemon |
| --- | --- |
| Masked Raider | 1.40× |
| Reed Archer | 1.35× |
| Daruma Breaker | 7.00× |
| Lantern Runner | 1.55× |

These proportions compare the source models with the approved Goemon normal-hair and body master. Runtime scale has not been implemented.

The assets are static models with separate parts and materials. Rigging, animations and in-game replacement have not been implemented.

- [Current massive Daruma beside the previous model and Goemon](3d-v02/massive-daruma-scale-comparison.png)
- [Initial 3D model and face review before the Daruma enlargement](3d-v01/model-review-contact-sheet.png)
- [Initial exported models beside Goemon before the Daruma enlargement](3d-v01/exported-model-lineup.png)
- [3D asset catalog](3d-v01/asset-catalog.json)
- [Saved role data](enemy-design-v01.json)

## Written spec

[Enemy redesign spec with slow high-health Daruma](../superpowers/specs/2026-10-14-forest-enemy-redesign-design.md). Gameplay integration is authorized; see the [implementation plan](../superpowers/plans/2026-10-14-forest-enemy-integration.md).

## Runtime delivery

Implemented in Goemon2.55.0 on14 October2026. All four approved models and target roles are active. Daruma uses the massive v02 model,3,000HP and0.75m/s, beginning in wave3. Fitted collision, traveling arrows, safe turning, planted feet and shared freeze poses are verified. Initial balancing values and verification evidence are saved in [runtime verification](runtime-v01/verification/release-verification.json). Editable masters are preserved.
