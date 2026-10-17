# Adjustable melee weapon reach

Work inline, preserving existing map saves, settings, combat styles and the Original Map.

- [x] Add regression coverage before implementation: per-fighter profiles, real fitted weapon reach, real enemy damage outside the original range, cover/fog, and saved menu edits.
- [x] Add a saved Melee reach × stat for the nine melee fighters, default 1, range 0.5–3. Apply to the visible weapon and its fitted hit reach, including physical weapon skills; preserve attack timing, damage, body size, movement and projectile tuning.
- [x] Verify native settings layout and combat, existing combat/settings regressions, and focused independent review.
- [x] Export and verify the packaged app, retain the previous build, install and boot the rebuilt app.

All checks above passed, including packaged native verification and installed app boot. Independent review findings on physical secondaries were reproduced and resolved. Verification: `build/Other Files/melee-reach-stat-20261017/verification.json`.
