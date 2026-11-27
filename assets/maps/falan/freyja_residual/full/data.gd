extends RefCounted
## Prepared full-source inputs for the existing map100 owners; originals stay intact.
const SOURCE_SHA256="1005a9032918d1be6108d5b0a7e5925225c16a576519f2b772417df68ad18850"
const PREVIEW_BOUNDS=[193, 405, 34, 39]
const SURFACES={
 "freyja":preload("res://assets/maps/falan/freyja_residual/full/freyja-surface.png"),
 "east_gate":preload("res://assets/maps/falan/freyja_residual/full/east_gate-surface.png"),
 "south_gate":preload("res://assets/maps/falan/freyja_residual/full/south_gate-surface.png"),
 "west_lakes":preload("res://assets/maps/falan/freyja_residual/full/west_lakes-surface.png"),
 "north_coast":preload("res://assets/maps/falan/freyja_residual/full/north_coast-surface.png"),
 "south_lakes":preload("res://assets/maps/falan/freyja_residual/full/south_lakes-surface.png"),
 "east_coast":preload("res://assets/maps/falan/freyja_residual/full/east_coast-surface.png"),
}
const ORIGINS={
 "freyja":Vector2(-480.0,-204.0),
 "east_gate":Vector2(-675.0,-204.0),
 "south_gate":Vector2(-480.0,-204.0),
 "west_lakes":Vector2(-480.0,-480.0),
 "north_coast":Vector2(-480.0,-480.0),
 "south_lakes":Vector2(-582.0,-480.0),
 "east_coast":Vector2(-480.0,-480.0),
}
const MASK_RGBA={"east_coast": "7676b8e2b5791c8651f1675e50a1a8d0b21b0e34205cea9cf506930c33cf5327", "east_gate": "41ea92c37a7284fcc13303760bb48f9be31738f1a367d9a3f16cb8b3dbf7f705", "freyja": "976139982755d241e226cd207e1024c761e29bb3f35acccf999cdb9d7092e1b4", "north_coast": "200a3ecb2b0c356fe83f289b4e55795ca651a853aa24bd869233a1c65318d244", "south_gate": "70eb83d5cf13ce7c6ac6c0aefe308c3193db7123b1a854d4c0bfff5aac91f14b", "south_lakes": "5792f228d4737416b71308be439f38568e83c6d74367d671b3070d90a9904ceb", "west_lakes": "6c7e02ceac59cc3006d32b9a33951374726e07e4b51f44edeceef21ac6e62e91"}
const SUPPORT_RGBA={"east_coast": "2539eb980ec9b168a700c78e5e042c80835f363579654e3ff972a7e10188bee1", "east_gate": "31429e88d24766ba2ff066d7bf1e4d78e29f8e5ad932448c4fa861a65273da01", "freyja": "5c20cd6a6ad06684b0f7379d78e74a6599ac5617c68c5ad130c62badaa429b0c", "north_coast": "c59fe73d7191c886ffb91f3f7c0c0e92abea9432a226946b7f7f6668e59d8c53", "south_gate": "e5d0b58af6e403c6950179ef3071ee05ee6274c0ff4c785213a8f25713e53852", "south_lakes": "b39acac92c36ad9bc6809a9a95ca2b4ced66426bf0405395e0962930750d0de0", "west_lakes": "3e054f2f77b9ad16703332b9718399ecbca83c967f97a0cc4d6f1c3d173d4af0"}
const DOMAIN_RGBA="0d9093da2fe54994522e2c1f183e0664da4edce1c6186bd54925a402c0f09e33"
const BLOCKS={
 "freyja":[],
 "east_gate":[],
 "south_gate":[],
 "west_lakes":[],
 "north_coast":[],
 "south_lakes":[],
 "east_coast":[],
}
## Exact opaque-city/joined-village exclusions in local mask pixels, including source water/control cells.
const SAFE_RECTANGLES={
 "freyja":[Rect2i(73,0,248,2),Rect2i(74,2,247,2),Rect2i(76,4,245,2),Rect2i(77,6,244,1),Rect2i(77,7,210,6),Rect2i(289,7,32,8),Rect2i(81,13,206,14),Rect2i(289,15,29,1),Rect2i(289,16,28,2),Rect2i(82,27,205,15),Rect2i(84,42,203,3),Rect2i(86,45,201,2),Rect2i(87,47,200,1),Rect2i(92,48,195,5),Rect2i(92,53,159,16),Rect2i(257,53,30,1),Rect2i(259,54,28,1),Rect2i(96,69,155,1),Rect2i(98,70,153,1),Rect2i(114,71,137,4),Rect2i(114,75,113,11)],
 "east_gate":[Rect2i(56,0,259,12),Rect2i(57,12,258,1),Rect2i(61,13,254,4),Rect2i(61,17,252,1),Rect2i(62,18,251,1),Rect2i(63,19,250,1),Rect2i(64,20,249,2),Rect2i(66,22,247,2),Rect2i(72,24,239,1),Rect2i(101,25,206,1),Rect2i(101,26,204,12),Rect2i(101,38,198,15),Rect2i(137,53,162,1),Rect2i(137,54,161,14),Rect2i(137,68,154,2),Rect2i(137,70,152,2),Rect2i(137,72,139,5),Rect2i(159,77,117,9),Rect2i(0,287,111,90)],
 "south_gate":[Rect2i(50,0,216,1),Rect2i(267,0,26,4),Rect2i(51,1,215,23),Rect2i(267,4,25,6),Rect2i(266,9,1,25),Rect2i(267,10,24,7),Rect2i(267,17,23,1),Rect2i(267,18,3,16),Rect2i(271,18,18,1),Rect2i(271,19,17,1),Rect2i(270,20,17,1),Rect2i(270,21,16,1),Rect2i(270,22,15,6),Rect2i(52,24,214,2),Rect2i(53,26,213,4),Rect2i(270,28,6,1),Rect2i(277,28,8,1),Rect2i(271,29,4,1),Rect2i(60,30,206,2),Rect2i(271,30,3,1),Rect2i(75,32,191,2),Rect2i(75,34,170,22),Rect2i(97,56,124,24),Rect2i(96,62,1,18),Rect2i(95,64,1,16)],
 "west_lakes":[],
 "north_coast":[Rect2i(55,69,100,100)],
 "south_lakes":[],
 "east_coast":[],
}
const CITY_REPAIRS=["freyja", "east_gate"]
const WATER=preload("res://assets/maps/falan/freyja_residual/full/water.png")
const OCEAN_BACKDROP=preload("res://assets/maps/falan/freyja_residual/full/ocean-backdrop.png")
const OCEAN_INDEX_PATH="res://assets/maps/falan/freyja_residual/full/ocean-index.png"
