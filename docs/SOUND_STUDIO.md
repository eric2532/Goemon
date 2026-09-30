# Sound Studio

Open **Settings → Sound Studio · Record sounds** from the main menu or pause menu.

1. Select a sound slot on the left.
2. Choose your microphone. Refresh lists newly connected devices.
3. Press Record and allow microphone access when macOS asks.
4. Make your sound, then press Stop (maximum eight seconds).
5. Listen to the take. Press Save take to use it in gameplay, or record again.

Each slot has a volume control and Restore default. Saved/default playback previews the sound currently used by the game. Slots cover pipe swings, enemy impacts, coin throws and light/heavy coin impacts, player hurt, jump, landing, evade, footsteps and pickup/energy effects.

The microphone runs only after Record. Stop, leaving the page, resuming gameplay or quitting stops input. Its bus is muted to prevent speaker feedback. Game music is paused and current effects stopped while recording. An unsaved take is discarded when leaving the page or selecting another slot. Save replaces only the chosen slot; Restore default removes only that saved recording. Microphone selection and slot volumes persist separately from gameplay settings.

If input is silent, choose another microphone and check macOS System Settings → Privacy & Security → Microphone → Goemon. The level meter shows incoming audio. The app's microphone permission message and audio-input entitlement are included in the exported build.

## Local storage

Recordings are 16-bit mono WAV files in `user://recorded_sounds/`. On this Mac this is normally `~/Library/Application Support/Godot/app_userdata/Azure Ember/recorded_sounds/`. Settings are `user://sound_studio.cfg`. They survive app rebuilds because they are outside the application bundle. Nothing is uploaded.

Leading/trailing silence is trimmed with a short margin; short fades prevent clicks; conservative peak normalization avoids clipping. Empty or silent takes are rejected. Custom recordings retain their original pitch. Built-in effects retain their original pitch variation and remain the fallback for unsaved slots.

## Implementation and verification

- `scripts/sound_library.gd`: device enumeration, muted AudioEffectCapture bus, explicit microphone lifetime, bounded takes, PCM conversion, atomic WAV save, persistent replacement streams and preview player.
- `scripts/sound_studio.gd`: settings page shared by main/pause menus.
- `game.gd` routes audio through saved slot overrides. Coin throw/impact slots are distinct; their defaults match the previous game sounds.
- `--sound-studio-test`: generated audio exercises the real capture bus without recording private microphone audio, plus trimming, persistence, custom playback, restore, pause and teardown tests.

Actual devices were enumerated (built-in MacBook Air and external microphone). Rendered standalone tests captured a generated tone with zero dropped frames. Physical speech recording and the user's first macOS permission interaction remain a user-side check; tests deliberately did not capture the room.

## Goemon v2.11

Search by attack name (for example `Chain pipe` or `Edo`). The 20 new slots cover wind spin, giant coin, Sky Strike leap/impact, chain throw/fan/hit/R explosion/R fire swing, Edo triple/giant fireballs and impact, shield, beam start/loop, meteor summon/strike/impact, and fire dodge/departure-arrival explosion. Saved beam audio loops at its original pitch. Browsing or previewing never enables the microphone. The renamed app deliberately keeps its former save directory so existing recordings and volume settings survive.

## Goemon v2.12

Goemon’s E dash and shove have separate recording slots. Player attack sounds use 16 reserved voices; crowd impacts, enemy attacks and movement sounds cannot replace them. Impacts use a quieter mix and at most two overlapping copies per type. Custom attack pitch and slot volume are preserved. If all 16 attack voices are busy, only a new player attack can replace the oldest attack.

`--priority-dash-test` checks sound isolation under 2,000 crowd sound requests, recording overrides, dash damage, knockback, distance, invulnerability, cooldown, wall collisions and cancellation. `--priority-dash-visual` also verifies that the real audio mixer continues playback and saves gameplay captures.
