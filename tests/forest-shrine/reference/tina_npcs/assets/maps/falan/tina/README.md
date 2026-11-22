# Tina Explorer NPC services

Runtime owner: `scripts/forest/forest_explorer_npcs.gd`. Recover or verify the
prepared NPC data/art with `python3 tools/recover_tina_explorer.py [--check]`.
Client appearance/anchors and the pinned corroborating server records remain
under `assets/references/crossgate_tina/events/`; these do not establish that
the pinned CGMSV server is identical to BlueCG.

## Travelling merchant 瓦努斯 (1050)

The Itemshop2 argument contract is rates, mode, six message IDs, 48 accepted-item
type flags, then retail item IDs. The old reader mistook message IDs 10146–10151
for six unavailable goods and invented a six-metal retail list. They are the
shop's original greeting/error/sale/thanks messages. Mode 2 is buyback only and
the actual retail list is empty. The source 150% retail rate is retained but
unused; buyback uses the recorded 80% rate, truncated per item before quantity.

The merchant lists owned, positive-price items of accepted source types.
Zero-price quest items and excluded types are refused. Source copper is an
accepted type; do not assume all ores are excluded from this table. Sale amounts
are 1, up to 5/10, or the owned stack, bounded by actual inventory and 999.
Forged retail, unknown item, invalid quantity and over-selling requests leave
state and gold unchanged. Completion uses the source thank-you text. Existing
metal items remain in the catalog so old inventories continue to load.

## Pet teacher 亞斯帕 (8608)

Techshop arguments provide the fee percentage, five source message IDs and ten
technique IDs. The original `tech.txt` has been copied from the already pinned
local archive with its source hash and Git blob recorded in `references.json`.
Its tier-III techniques are 34/134/334/534/634/734/834/934/1134/1234. Prepared
records retain names, handlers, parameters, pet level 30 requirement, individual
4,000/5,000 Gold fees and 25–75 MP costs. No message ID is treated as an item.

The shared conversation presents technique → selected party pet → one of the
existing three skill slots → explicit confirmation. Replacing an occupied slot
names its old skill. Level, current party membership, slot contents and funds
are revalidated before writing. Duplicate/stale choices cannot charge twice.
Gold is debited only when the learned-technique record and pet loadout commit
through the existing atomic settings writer, with rollback on failure. Gold
keeps its existing run lifetime. `pet_training` is additive
and sanitized on load; existing quest progress, bags, names, packs and spells
are retained. The equipment panel offers these techniques only after that pet
has learned them. Existing freely selectable abilities stay available.

Native wire codes 1–11 retain their order; Tina occupies 12–21. Subsequent
shared abilities append after them. `pet_catalog.gd` reads source costs once at
setup; no per-frame resource parsing or new combat owner exists. The current
native pet animation/contact clock, queries, damage, counters, guard interception
and pooled presentation execute the techniques. Their original normal attack
frames are reused. Costs above a pet's maximum MP are valid loadouts; that pet
uses its normal attack until it has enough MP. MP stat upgrades use the existing
progression owner. New combo counts, hit/evasion/counter outcomes, shield amounts
and healing ranges use bags without replacement; remaining bags survive rest.

Real-time adaptations: active defensive windows and cooldowns use five seconds;
連擊 repeats the existing grounded strike 1–3 times without the unrelated blink
combo; flat damage/defense scaling uses the current combat system. 護衛Ⅲ reuses
the shared interruption/interception owner and spends its source MP when it
intercepts a physical melee hit. 戰慄襲心 removes 25% of the target's current
native MP once per strike sequence; targets with zero MP are unaffected. Most
ordinary world enemies currently have no native MP budget, and their original
server MP/AI rules are not implemented by this shop change. No invisible MP
pool or substituted HP damage is invented for those enemies. 明鏡止水 heals
5–30% of maximum HP using its source range. Source pet levels live for the
current run; paid loadouts and training records remain saved, following the
existing progression and preference lifetimes.

## Verification

`tests/forest-shrine/test_tina_source.py` checks message/type/technique parsing,
raw table fields, source hashes and unchanged NPC art. `tina_shops_test.gd`
checks actual Explorer conversations, quantities, fees, level/slot/duplicate
validation, a real confirmation click, failed-write rollback, saved-state
sanitization, reload and night-only vendor absence. `--combat-review` adds a
native Explorer fight with taught combo and healing. `tina_services_test.gd`
retains the other service regressions. `tina_pet_shop_test.cpp` covers the nine active
techniques across five pet families and three update rates, plus reactive source
bodyguard interception/MP debit,
actual damage/healing/guard results, bag distributions, rest and pooled reuse.

Evidence belongs under `build/Other Files/Asset Toolkit/Tina Recovery/Shops/`.
This change does not export an app or establish long-session performance.

Fresh results for this change: 72 rendered shop/combat checks, 62 headless
shop/combat checks, 78 shared service checks, 164 quest checks, 86 existing
loadout checks, 109 existing attack checks, 818 native Tina checks and 88,365
native pet regressions passed. Five Python source tests and exact recovery
reproduction passed. Final logs contain no script errors. The native universal
library was rebuilt for arm64/x86_64. Asset preservation passed; the audit read
319 assets with zero read errors. Test fixtures now use actual catalog names
and physical blockers for ranged-command checks. Earlier transient shared
minimap errors and an unprepared-enemy review fixture are retained separately
in Diagnostics. Godot's existing teardown resource/RID warnings remain.
