# Regional source schema evidence

`references.json` pins nine reference Java readers/types from
Muscipular/CrossGateData commit `4074d43e2fc96c953e40b21e2af4801ddc57caf2`.
The exact Git blob IDs, raw-byte SHA256 hashes and primary URLs are recorded.
This is a schema reference, not authenticated original BlueCG server execution.

`CFileMapReader` confirms the static LS2MAP format: 44-byte header, big-endian
16-bit dimensions at offsets40/42, followed by floor and object planes. It has
no client flag plane. The existing East map helpers implement this format and
preserve cached client cells during source completion; reuse them.

`CEnemyGroupReader` names group fields 3/4 as required/forbidden item IDs,
5–14 as enemy IDs, 15–24 as member weights and 25–34 as mandatory-member
flags. The latter are **not inventory conditions**. Order is field 1; ID is 2.
`CDungeonReader` names field 49 as encounter ID, 50/51 as enemy levels,
52/53 as enemy-rate range and 54 as chest amount. Its reference generator
uses integer floor interpolation; the original server generator is unavailable.
It selects the chest amount once across all generated floors. The Cape uses
five/six whole-branch chests, not that amount on each floor. Warp-resource roles
are pinned separately under `../cape_schema/`; preserve the raw fields when a
cached fixed-map stair differs from the configuration.

The encounter and enemy readers have apparent schema/index errors relative
to our pinned tables: `CEncountInfoReader` calls 10 priority, whereas the
rare-zone data clearly distinguishes priority in 11; `CEnemyReader` reads
both levels and counts from 4/5. Existing prepared count rows use 6/7.
Do not change runtime count/probability behavior solely from these readers.
Retain raw records and qualify uncorroborated algorithms.

`CEnemyReader` identifies enemy field8 as the AI ID. `CEnemyAiReader` retains
ten ordered slots: conditions1–10, targets11–20, techniques21–30 and rates31–40.
A blank condition disables a slot; numeric zero remains an active condition.
The pinned `../ai/enemyai.txt` and existing `tech.txt` resolve all253 AI IDs
referenced by the current regional encounter/script candidates and their linked
enemy forms. These are
source records, not verified original decision timing or native AI behavior.
For example, enemy9067 has an escape slot with raw rate20 and Qi BlastLV6;
9068 lacks that escape slot and uses Qi BlastLV5. Their shared appearance does
not erase those differences. Original condition/rate execution remains open.

Script `Encount` and inline `StandEnemy` field 9 are **encounter IDs**:
resolve `encount.txt` first, then its weighted `group.txt` IDs. The previous
audit's seven named boss conflicts resulted from skipping that step.
