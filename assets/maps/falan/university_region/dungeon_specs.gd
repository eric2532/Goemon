extends RefCounted
## Generated from the pinned original-reference dungeon configuration.
const FIXED=[400, 402, 15000, 15001, 15002, 14000, 14001, 14002, 4000, 4001, 4002, 4008, 4009, 4010, 4011, 4012, 4013, 4020, 4021, 4022, 4099, 4300, 4308, 4309, 4310, 4312, 4313, 4320, 4321, 4322, 4330, 4331, 4332, 4333, 4334, 4335, 4399, 4400, 4401, 4402, 4410, 4411, 4412, 4413, 4414, 4415, 4416, 4417, 4418, 4419, 4420, 4421, 4422, 4423, 4424, 4430, 4431, 4432, 4451, 4452, 4453, 4454, 4455, 4403, 4404, 4405, 4406, 4407, 4408, 4409, 32154, 4456, 4457, 15522, 15523, 15536, 15537, 24008, 24009, 24010, 24011, 24012, 24013, 24014, 24015, 24016, 24017, 24018, 24019, 24020, 24021, 24022, 24023, 24024, 24025, 24026, 24027, 24028, 24029, 24030, 24031, 24032, 24033, 24034, 24035, 24036, 24037, 24038, 24039, 24040, 24041, 24042, 24043, 24044, 24045, 24046, 24047, 24048, 24049, 24050, 24051, 24052, 24053, 24054, 24055, 24056, 24057, 24058, 24059, 24060, 24061, 24062, 24063, 24064, 24065, 24066, 24067, 24068, 24069, 24070, 24071, 24072, 24073, 24074, 16510, 16511, 16512, 16513, 16514, 16515, 16521, 16520, 15531, 15532, 15533, 15535, 15538, 15539, 14003, 14004, 14005, 14006, 14007, 4500, 4501, 4502, 401, 15400, 15401, 15402, 20501, 20502, 20503, 20504, 20505, 20506, 20507, 20508, 20509, 20510, 20511, 20512, 20513, 20514, 20515, 20516, 20517, 20518, 20519, 20520, 20521, 20522, 20524, 20525, 20526, 20527, 20530, 20414, 20428, 20001, 59752, 5014, 4100, 14010, 14011, 14012, 14013, 14014, 14015, 14016, 15006, 15007, 15008, 15009, 15010, 15011, 15012, 32269, 32183]
const SPECS={
 "scientist": {
  "first": 51801,
  "minimum": 5,
  "maximum": 5,
  "size": [
   50,
   80,
   50,
   80
  ],
  "ground": 3077,
  "stairs": [
   13996,
   13997
  ],
  "title": "科學家的牢房",
  "entry": [
   4402,
   16,
   13
  ],
  "end": [
   4430,
   20,
   17
  ],
  "frozen": false,
  "encounter": 16001,
  "levels": [
   20,
   22
  ],
  "config": 401,
  "entry_rect": [
   16,
   13,
   16,
   13
  ],
  "terminal_enemy": 0,
  "terminal_enemy_count": 0,
  "terminal_npc": 0,
  "terminal_placement": -1
 },
 "mountain": {
  "first": 51301,
  "minimum": 20,
  "maximum": 24,
  "size": [
   40,
   40,
   40,
   80
  ],
  "ground": 8175,
  "stairs": [
   17956,
   17957
  ],
  "title": "積雪的山路",
  "entry": [
   402,
   84,
   193
  ],
  "end": [
   15522,
   41,
   40
  ],
  "frozen": true,
  "encounter": 16003,
  "levels": [
   40,
   43
  ],
  "config": 402,
  "entry_rect": [
   84,
   193,
   84,
   193
  ],
  "terminal_enemy": 0,
  "terminal_enemy_count": 0,
  "terminal_npc": 0,
  "terminal_placement": -1
 },
 "lizard": {
  "first": 51401,
  "minimum": 10,
  "maximum": 10,
  "size": [
   60,
   60,
   60,
   60
  ],
  "ground": 3009,
  "stairs": [
   12000,
   12002
  ],
  "title": "蜥蜴之巢",
  "entry": [
   16521,
   10,
   13
  ],
  "end": [
   16520,
   10,
   15
  ],
  "frozen": false,
  "encounter": 12010,
  "levels": [
   35,
   40
  ],
  "config": 403,
  "entry_rect": [
   10,
   13,
   10,
   13
  ],
  "terminal_enemy": 0,
  "terminal_enemy_count": 0,
  "terminal_npc": 0,
  "terminal_placement": -1
 },
 "tunnel": {
  "first": 51501,
  "minimum": 12,
  "maximum": 16,
  "size": [
   50,
   60,
   50,
   60
  ],
  "ground": 7639,
  "stairs": [
   17954,
   17955
  ],
  "title": "奇怪的坑道",
  "entry": [
   400,
   365,
   357
  ],
  "end": [
   15531,
   12,
   64
  ],
  "frozen": false,
  "encounter": 16004,
  "levels": [
   27,
   30
  ],
  "config": 404,
  "entry_rect": [
   356,
   345,
   373,
   450
  ],
  "terminal_enemy": 5307,
  "terminal_enemy_count": 1,
  "terminal_npc": 5246,
  "terminal_placement": 18
 },
 "permafrost": {
  "first": 51601,
  "minimum": 36,
  "maximum": 36,
  "size": [
   40,
   60,
   40,
   60
  ],
  "ground": 8177,
  "stairs": [
   17956,
   17957
  ],
  "title": "永久凍土",
  "entry": [
   15536,
   21,
   8
  ],
  "end": [
   15537,
   24,
   15
  ],
  "frozen": true,
  "encounter": 16005,
  "levels": [
   56,
   64
  ],
  "config": 406,
  "entry_rect": [
   21,
   8,
   21,
   8
  ],
  "terminal_enemy": 0,
  "terminal_enemy_count": 0,
  "terminal_npc": 0,
  "terminal_placement": -1
 },
 "abyss": {
  "first": 51701,
  "minimum": 36,
  "maximum": 36,
  "size": [
   40,
   60,
   40,
   60
  ],
  "ground": 9555,
  "stairs": [
   17974,
   17975
  ],
  "title": "深淵",
  "entry": [
   15538,
   14,
   7
  ],
  "end": [
   15539,
   30,
   21
  ],
  "frozen": false,
  "encounter": 16006,
  "levels": [
   55,
   64
  ],
  "config": 407,
  "entry_rect": [
   14,
   7,
   14,
   7
  ],
  "terminal_enemy": 0,
  "terminal_enemy_count": 0,
  "terminal_npc": 0,
  "terminal_placement": -1
 }
}
