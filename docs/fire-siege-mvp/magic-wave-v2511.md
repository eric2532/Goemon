# Magic Swordsman Energy Wave — v2.51.1 preview

Magic Swordsman's RMB / 3 must release a strong, broad energy wave rather than
feel like another close sword hit. The v2.51.0 aim code pointed the high wave
origin at a close enemy's lower aim point. With J enabled this sent the wave into
the floor shortly after the first enemy, cutting travel to roughly 6 metres in
the reproduced 2-metre target case. The ability remained bound and spawned a
projectile; its useful travel was lost.

Grounded waves now retain the horizontal heading of the reticle or J target and
travel level. Airborne waves retain three-dimensional aim. RMB and 3 release a
100-damage piercing wave at 22 metres per second, with a 40-metre center travel
budget and a 2.5-metre collision radius (roughly a 5-metre attack corridor).
Collision radii, launch offset, and enemy size can extend contact beyond the
center travel budget. The existing purple energy blade is larger and uses the
same emissive materials and geometry. Buildings still block it.

The ordinary 2.1-second cooldown and Final Strike's 0.42-second wave cadence are
preserved. Left-click sword attacks, Ranger spread/deviation/curves, other hero
VFX, Japanese districts, discoveries, shrine battles and ice towers are unchanged.

Regression tests exercise actual RMB / 3 input, nearby locks, a low reticle,
piercing damage at 35 metres, broad lateral contacts and exclusion limits,
airborne targets, Final Strike repetition, terrain and buffered secondary input.
The initial focused test failed against the previous attack and passed after
the fix. Source and exported-resource check results accompany the preview.

FPS benchmarking remains deferred at the user's request. This development
preview makes no new FPS guarantee.
