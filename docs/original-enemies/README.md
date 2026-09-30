# Original Tidefall enemy set

Four original, editable low-poly Blender characters on baseline `82b4e8307af1158dbec566cb67632eb5cdbbb6d2`. No third-party character mesh or texture is used. Existing approved Musashi and playable character masters are untouched.

| Asset ID (under enemies/original_set) | Triangles | Materials | Design |
| --- | ---: | ---: | --- |
| masked_foot_soldier | 430 | 1 | Indigo/vermilion cloth, wooden mask and club, oversized sandals |
| straw_hat_bandit | 478 | 1 | Broad straw hat, hunched hood, patched moss cloth |
| lantern_yokai | 604 | 1 | Paper ribs, mischievous painted face, single sandal and tongue |
| daruma_bruiser | 312 | 1 | Round red silhouette, ink face, chunky dark fists |

`asset-catalog.json` records stable source, export and thumbnail paths. `enemy-contact-sheet.png` is the cloud-rendered design preview. Sources use metres, Blender Z-up/+Y-facing, ground origin and packed original 256×256 atlas. GLBs convert to Godot Y-up/-Z-facing. `tools/draw_enemy_atlas.py`, `tools/build_original_enemies.py` and `tools/enemy_contact_sheet.py` reproduce only this new asset set. The builder refuses existing masters unless passed `-- --replace`. Hand-edited sources should be exported rather than rebuilt.

## Runtime adaptation

Ordinary enemies use four single-surface MultiMesh batches. Named rigid parts merge once at startup; atlas UVs remain in UV0 and limb codes occupy UV2. No skeleton or mesh hierarchy is instantiated per ordinary actor. Guardian rigs and gameplay-owned collision remain separate. Existing variant combat stats and timing remain; these are visual species, not new attack classes. In the active melee survival mode, alternating standard soldiers wear the lantern design so all four designs appear without introducing ranged attacks. The legacy caster variant also uses the lantern.

Rigid animation is deliberately limited: humanoid limb swings/club windup and strike, lantern hop, daruma rocking, existing freeze tint and death shrink. There are no skinned joint deformations, authored animation clips, foot IK, lantern-specific collision or daruma-specific attacks. Lantern/daruma silhouettes differ from their existing gameplay collision volumes; a later gameplay design pass can specialize those separately. Current visual scale factors are retained by the adapter.

The highest mesh has 604 triangles, making 200 instances about 120,800 model triangles before other scene content. This is a budget estimate, not a measured crowd FPS claim. Four material batches, simulation cost, shadows/world draw cost, GPU/backend and hardware still matter. See cap test evidence for cloud-only representative execution; no Mac benchmark was run.

## Verification

`tests/original-enemies/renderer_check.gd` verifies imported surface/UV data, four batches, lightweight actor proxies, visual state cues and clearing all species on return to menu. Survival cap and combat regressions are maintained separately. Blender thumbnails are design previews; runtime screenshots document actual Godot import where available.
