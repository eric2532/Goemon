# Goemon v2.15.0 — distinct rising jumps

The cloak geometry, materials and running animation are unchanged. Equipped Goemon now has four jumps with three looks: normal lift/tuck on jumps 1–2, one vertical-axis 360-degree spin on jump 3, and one forward somersault around the torso on jump 4. Turns use a 0.42-second eased timeline and complete before the default jump apex. HUD/toast/control descriptions now show quad jump. Edo and unequipped Goemon retain double jump.

Validation:
- Rendered jump suite: 27 checks passed; frames reviewed and encoded to jump-preview.mp4.
- Headless jump suite: 27 checks passed.
- Existing cloak suite updated for four jumps: 33 checks passed.
- Packaged Mac app jump suite: 27 checks passed.
- Measured third-jump yaw: 6.283 radians; fourth-jump pitch: -6.283 radians. Both finish during ascent and restore the normal pose.
- Fifth jump rejection, midair outfit toggles, landing reset, pause/resume, Edo switching, E and T interruption checked.
- Universal Mac release version 2.15.0 exported successfully; deep/strict code-signature verification passed. Packaged headless test printed an existing dummy-renderer shader allocation warning on exit, with no gameplay failures.

Prior source and v2.14 app/ZIP are preserved in backups/ronin-jumps/.
