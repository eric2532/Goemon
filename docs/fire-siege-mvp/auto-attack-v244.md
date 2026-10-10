# Automatic normal attacks · v2.44

Press **J** during Fire Siege play to toggle automatic normal attacks. Defaults OFF; applies to all twelve heroes. Move and aim as usual with the camera. HUD primary card changes to AUTO and the lower-left indicator shows ON / PAUSED / OFF. Manual left/right mouse attacks and existing hero abilities remain available.

Normal native attacks retain their cooldowns, damage, combo acceleration and third-shot Ranger green power arrows. A double-jumping Ranger automatically releases downward five-arrow fans; held Space still slows falling. Mage automatic shots are normal taps; holding left click still charges a manual shot. Empowered Edo sustains his normal beam until the toggle is disabled or its power expires.

Auto fire pauses during menus, construction, dodges, travel and committed moves; manual secondary input takes priority. It resumes when those conditions end. Starting/restarting a run, dying, changing hero, entering the map editor and returning to the main menu reset OFF. Disabling the toggle finishes an already released attack rather than removing its projectile. UNLEASHED Goemon and Edo retain their instant native contact but automatic repeat intervals are bounded and scale with ordinary attack speed.

Hero owns the toggle and lifecycle guards. Goemon/Edo dispatch their native primary without synthesizing mouse input; a native-duration repeat clock bounds their UNLEASHED bursts. RogueRosterCombat uses the same attack eligibility and cooldown branch as ordinary held primary. All existing Ranger geometry, flight and map builder modules are preserved.

Verification logs, rendered physical-key tours, before-change snapshots and build identity are in `build/auto-attack`. Tests cover real enemy damage and stopping for all twelve heroes, bounded UNLEASHED contact/projectile counts, Ranger green arrows and glide fans, Mage manual charge, Edo beam, pause/build suspension, and lifecycle resets. Regression suites cover Ranger flight, Fire Siege controls/economy, equipment combat and custom maps. The installed bundle is exported with the Fire Siege macOS preset; the previous v2.43 app is backed up separately. No commit, push or publication is part of this change.

Final verification: all456 source checks and456 exported-package checks passed, including10 rendered physical-key checks and2 captures per tour. Strict bundle signature verification passed. Installed executable, PCK and Info.plist hashes match the tested export. Build identity is recorded in `build/auto-attack/build-info.json`.
