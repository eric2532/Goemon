The two undersea floors share the native cave encounter renderer, movement,
hit queries, and sprite attack cue playback. The three original actors are
100802 (熱砂的歐茲尼克), 101721 (水龍蜥), and 101700 (蜥蜴戰士). Their
graphic IDs come from the archived enemybase records 1017, 722, and 701.

Rebuild with `python3 tools/recover_habaru_encounter.py '../Magic Power' --undersea`.
The atlas and timeline are prepared once and shared by every encounter actor.
The lizard patrols use their original directional guard poses from action 9.
The Lizard Warrior's extra sound cue stays audible and its original contact
cue drives the hit. Attack audio reuses byte-identical project assets where
available. Encounter placement and stats are in `undersea_sprites.gd` and
`forest_waves.gd`.

熊哥 keeps source actor 100802's unarmed attack (source action 5) and its
original fist-contact cue. Native `UNDERSEA_QIGONG` (711) is a separate .75 s
windup and three-orb ranged release, with a six-second cooldown. It reuses
Kaz's original `qigong/orbs.png`, shared orb shader, native projectile collision
and the army's immutable mesh/MultiMesh presentation. The source melee swing
remains the normal attack; no weapon model or sword effect is attached.

Sokia has 40 source-grid patrols (20 of each lizard) and Venoa Undersea has 48
(24 of each). These visible patrols adapt the original random encounters;
they are not a claim of fixed spawn coordinates in Blue CG. The historical boss
has 2,000 HP (https://guide.bluecg.net/blue-cg/453468); Goemon now preserves his
level 40 with 48,000 HP and 320 base damage for real-time combat. Balance data
lives in `scripts/forest/cave_progression.gd`; provenance is documented in
`docs/cave-monster-progression.md`. Dialogue and ring
requirements remain bypassed for the current exploration rules.

熊哥's support skills reuse his native unit's existing cooldown and buff timers:
- `UNDERSEA_MEDITATION` (712): below 60% HP, a 1.2-second interruptible cast
  restores half of his current HP, capped at maximum; 18-second cooldown. This
  matches the existing Shin self-heal rule. 陽炎 is cleared when meditation starts.
- `UNDERSEA_HAZE` (713): a .5-second stance gives a 50% chance to dodge each
  physical hit for five seconds, with a 14-second cooldown. It does not stack,
  grant invulnerability, or evade magical/status-only hits. Dodges emit 714.

The original seven-frame 明鏡止水 sheet now runs at two client updates per
frame with 128/255 opacity, matching Shin's prepared cast. It follows the boss's
body at 55% of standing height with source offset (4,-2); successful recovery
plays cue 256 after opening cue 261. Both 陽炎 and 氣功彈 start the original
110100 physical shine at the same body anchor, with source offset (22.5,-10.5),
nine frames at 20 Hz and cue 251. These sounds' decoded PCM matches the archive.
The new native zero-amount 713 event signals the start of 陽炎; the existing
five-second positive-amount event still signals actual dodge activation.

Successful 陽炎 dodges reuse the actor's indexed atlas, palette and frame lookup
through the shared hound shader include. A prepared transparent material variant
draws at most six pooled afterimages: two-update spacing, twelve-update life,
128/255 opacity and original dodge cue 210. Overlapping contacts share one trail
and sound. Body collision and native movement stay authoritative. MISS labels
remain pooled. Spell art stops on interruption, death or removed/reused handles;
reduced-flash opacity applies to the body effects and afterimages.

Healing and dodge state remain native; these timings adapt Blue CG's turn-based
skills to the current real-time fight. No other boss is assigned this dodge chance.
