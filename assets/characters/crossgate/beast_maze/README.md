# Original Beast-maze bomb

大炸彈 is appearance 101522 / `original:2906`, recovered with
`python3 tools/recover_habaru_encounter.py '../Magic Power' --beast`.
Its 528 frames preserve original RGBA pixels, eight facings, origins, clocks,
attack contacts and audio. This is a data bank for the existing native cave
sprite batch, not a new controller or renderer. `pet_dimensions.gd` fits its
standing body to 0.6 Kaz height, matching the related original bomb family.

大地翼龍 (101710 / `original:2935`) and 神獸史雷普尼爾
(101032 / `original:2820`) reuse the existing companion bank. No original 3D
mesh is supplied for these creatures; preserve their drawings in the 3D world.
`tests/forest-shrine/test_jenova_beast_source.py` independently decodes and
compares every bomb frame, origin, clock, contact marker and audio sample.
The map catalog records the pinned reference encounter identities and levels;
real-time placement and combat are adaptations, not recovered BlueCG server AI.
