# Tina Explorer

Tina NPC gameplay was removed at the user's request on 2026-11-23: no Tina
NPC actors, dialogue, shops, paid teaching, nurses, rentals, message boards,
quest inventory/effects or scripted battles run in the game. Separate Falan
citizen conversations and shared pet/Bodyguard abilities remain intact.

J opens direct region travel. Recovered linked areas and former NPC-gated
rooms remain enterable without NPCs, quests, fees or rewards. Village scenery,
building entrances, original map data, the 24-minute outdoor clock and roaming
night/road encounters retain their existing owners.

Original server tables remain under assets/references/crossgate_tina/events.
The previous implementation, prepared NPC data/art and historical tests are
retained as excluded reference under tests/forest-shrine/reference/tina_npcs.
Existing saved NPC metadata is preserved but inactive. Removed teaching-slot
assignments are kept in the same inactive preference namespace before being
omitted from the live pet loadout; ordinary assignments keep their slots.
Native codes 12–21 are rejected, and shared Bodyguard retains code 22.

Verification: tina_npc_removal_test.gd, tina_explorer_review.gd, existing
Falan conversation, day/night, roaming-enemy, pet and Bodyguard regressions.
Evidence belongs under Asset Toolkit's Tina Recovery/NPC Removal/. No app
export is part of this change.
