Falan's outdoor patrols use the original Blue CG battle sprites and cues.

| Actor | Archive graphic | Enemybase record |
| --- | --- | --- |
| 迷你蝙蝠 | 101242 | 243 |
| 哥布林 | 101800 | 801 |
| 盜賊 | 101820 | 821 |
| 黃蜂 | 101313 | 314 |
| 樹精 | 101400 | 401 |

The current 29-species patrol derivative and rebuild instructions are in
[`../falan_encounters/README.md`](../falan_encounters/README.md).
This original five-species recovery remains intact as a preservation reference.
The recovered source retains its historical height fitting. Explore applies
`pet_dimensions.gd` species proportions to both sprites and collision: mini bats
and bees reach 80% of Kaz's height, goblins 70%, bandits 100%, and trees 190%.
Review `build/Other Files/BlueCG Map Study/Pet Size/species-lineup.png` before
changing that table; preserve the source artwork and its animation samples. Each actor keeps
its source attack contact and uses the shared native sprite batch. All five
use 3,000 HP and 30 base damage per contact.

`assets/maps/falan/freyja_patrol_data.gd` records the archive cell, sprite
slot, and encounter area for each post. The [CGMSV reference encounter table](https://raw.githubusercontent.com/linv2/Crossgate_Docker/dd8690ed3df11e4eb5a038a54079a8f40d8e93b3/gmsv/data/encount.txt)
and [group table](https://raw.githubusercontent.com/linv2/Crossgate_Docker/dd8690ed3df11e4eb5a038a54079a8f40d8e93b3/gmsv/data/group.txt)
describe random battles within rectangles. The stationary home posts sample
dry cells inside those rectangles for Goemon's real-time patrols.

The [Blue CG 樹精 guide](https://gamerch.com/blue-cg/453080) records the
east-bridge encounter area and reports (562,221). The [Blue CG 黃蜂 guide](https://guide.bluecg.net/blue-cg/452920)
records the Il fields and reports (690,286). Each post is one tile north
of the report to give the 3D patrol's footprint clearance from the bank.
The route from the city to the bridge uses bats and goblins. Bandits occupy
side pockets at least 13 tiles from painted roads. The western and southern
fields use the local reference groups for the five supported actors.
