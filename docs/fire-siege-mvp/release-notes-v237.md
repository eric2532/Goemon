# Fire Siege v2.37.0 MVP

The latest Fire Siege MVP combines the Rogue roster redesign, combat upgrades,
movement improvements and simpler construction interactions developed since
v2.32.0.

- **Latest character corrections:** Samurai has a shorter neck and compact red
  scarf with a long animated tail. Dragoon wears a closed dragon faceplate;
  Magic Swordsman has a purple demon mask beneath his crystal crown.
- **Full Rogue art update:** coordinated heads, facial depth, hair, equipment,
  natural weapon grips and updated character-picker portraits.
- **Combat upgrades:** three times the original basic attack range for all
  twelve heroes; improved class attacks and effects. Right-click and **3** share
  secondary controls for Rogue heroes.
- **Signature skills:** Magic Swordsman's double-jump dive, piercing Pirate
  bullets and Mage fireballs, Ninja/Rogue light-attack energy for one free heavy,
  and Dragoon's higher jumps with a three-pulse blue landing shockwave. Airborne
  Dragoon Leap descends to a real floor before impact.
- **Ranger:** three times the configured primary firing rate and twice-size
  arrows, retaining their existing flight speed and range.
- **Movement and building:** improved movement-facing/camera behavior, more
  nearby mines, construction from any accessible side, an in-range prompt and
  progress bars shown only after building begins.

## Download

`Goemon-Fire-Siege-v2.37.0-macOS.zip` contains the tested universal macOS app
(Apple Silicon and Intel). Extract the ZIP and launch **Goemon Fire Siege.app**.
The macOS app is ad-hoc signed and is not notarized.

`Goemon-Fire-Siege-v2.37.0-Linux-x86_64.zip` contains the Linux x86_64 executable,
resource pack and launch instructions. Extract the complete folder, keep the
executable and PCK together, and run `./Goemon-Fire-Siege.x86_64`. If necessary,
restore executable permission with `chmod +x Goemon-Fire-Siege.x86_64`.
The Linux resource pack is checked on macOS; native Linux execution has not been
verified on this machine.

The preview, verification report and `SHA256SUMS.txt` are included as release
assets. The Mac ZIP is byte-identical to the locally tested v2.37.0 archive.

## Verification

The final art refinement passes 98 source runtime checks, 58 checks in the
exported Mac app, and 4,326 geometry/preservation checks. The packaged tour
produced 26 captures with no runtime warnings or errors; its three revised model
hashes match source. Earlier combat and construction validation remains documented
in this repository. These are local acceptance checks, not exhaustive testing on
every supported Mac.

The exported Linux resource pack passed 41 equipment/combat checks and 13 scarf
checks using the local Godot runtime outside the source checkout. See the
attached Linux verification report for the native-runtime testing limitation.

See [v2.37 verification](https://github.com/eric2532/Goemon/blob/fire-siege-v2.37.0-mvp/docs/fire-siege-mvp/mask-refinement-v237.md),
[v2.36 equipment/combat verification](https://github.com/eric2532/Goemon/blob/fire-siege-v2.37.0-mvp/docs/fire-siege-mvp/equipment-upgrade-v236-verification.md),
and [v2.35 roster/combat verification](https://github.com/eric2532/Goemon/blob/fire-siege-v2.37.0-mvp/docs/fire-siege-mvp/roster-upgrade-v235-verification.md).

Published as an MVP prerelease in the existing private `eric2532/Goemon`
repository. Access requires permission to that repository.
