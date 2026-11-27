extends RefCounted
## Source-backed torch consumption and event-state map transfers.
const EVENTS={
 "6582": {
  "kind": "torch",
  "source": 20501,
  "cell": [
   17,
   46
  ],
  "target": [],
  "file": "EV_aoki_6582.txt",
  "sha256": "d06d6bf41a0536107d1bda6b3853a7ac76872a8e47b62f22fa74e41bc9c34ac0"
 },
 "6583": {
  "kind": "flame",
  "source": 20501,
  "cell": [
   25,
   51
  ],
  "target": [],
  "file": "EV_aoki_6565.txt",
  "sha256": "b9788c497bb11462392a1145e7638c60d12a5953ef3526064e602d8b5c7db12d"
 },
 "6584": {
  "kind": "flame",
  "source": 20502,
  "cell": [
   61,
   15
  ],
  "target": [],
  "file": "EV_aoki_6565.txt",
  "sha256": "b9788c497bb11462392a1145e7638c60d12a5953ef3526064e602d8b5c7db12d"
 },
 "6585": {
  "kind": "flame",
  "source": 20504,
  "cell": [
   19,
   86
  ],
  "target": [],
  "file": "EV_aoki_6565.txt",
  "sha256": "b9788c497bb11462392a1145e7638c60d12a5953ef3526064e602d8b5c7db12d"
 },
 "6586": {
  "kind": "flame",
  "source": 20504,
  "cell": [
   25,
   51
  ],
  "target": [],
  "file": "EV_aoki_6565.txt",
  "sha256": "b9788c497bb11462392a1145e7638c60d12a5953ef3526064e602d8b5c7db12d"
 },
 "6587": {
  "kind": "flame",
  "source": 20517,
  "cell": [
   10,
   6
  ],
  "target": [],
  "file": "EV_aoki_6565.txt",
  "sha256": "b9788c497bb11462392a1145e7638c60d12a5953ef3526064e602d8b5c7db12d"
 },
 "6588": {
  "kind": "flame",
  "source": 20508,
  "cell": [
   46,
   47
  ],
  "target": [],
  "file": "EV_aoki_6565.txt",
  "sha256": "b9788c497bb11462392a1145e7638c60d12a5953ef3526064e602d8b5c7db12d"
 },
 "6589": {
  "kind": "flame",
  "source": 20509,
  "cell": [
   83,
   45
  ],
  "target": [],
  "file": "EV_aoki_6565.txt",
  "sha256": "b9788c497bb11462392a1145e7638c60d12a5953ef3526064e602d8b5c7db12d"
 },
 "6590": {
  "kind": "flame",
  "source": 20511,
  "cell": [
   33,
   18
  ],
  "target": [],
  "file": "EV_aoki_6565.txt",
  "sha256": "b9788c497bb11462392a1145e7638c60d12a5953ef3526064e602d8b5c7db12d"
 },
 "6591": {
  "kind": "flame",
  "source": 20520,
  "cell": [
   8,
   72
  ],
  "target": [],
  "file": "EV_aoki_6565.txt",
  "sha256": "b9788c497bb11462392a1145e7638c60d12a5953ef3526064e602d8b5c7db12d"
 },
 "6592": {
  "kind": "flame",
  "source": 20521,
  "cell": [
   71,
   57
  ],
  "target": [],
  "file": "EV_aoki_6565.txt",
  "sha256": "b9788c497bb11462392a1145e7638c60d12a5953ef3526064e602d8b5c7db12d"
 },
 "6593": {
  "kind": "flame",
  "source": 20513,
  "cell": [
   15,
   14
  ],
  "target": [],
  "file": "EV_aoki_6565.txt",
  "sha256": "b9788c497bb11462392a1145e7638c60d12a5953ef3526064e602d8b5c7db12d"
 },
 "6594": {
  "kind": "candle",
  "source": 20514,
  "cell": [
   76,
   50
  ],
  "target": [
   20501,
   75,
   50
  ],
  "file": "EV_aoki_6594.txt",
  "sha256": "857f3e85a8bd1bc375ee58ff1d68a3ca356b1f7f36164a2e2d61d7d9ce6a4c04"
 },
 "6595": {
  "kind": "candle",
  "source": 20503,
  "cell": [
   13,
   70
  ],
  "target": [
   20516,
   12,
   70
  ],
  "file": "EV_aoki_6595.txt",
  "sha256": "db76d7674130067500f8e7b7be77bf3b916d538b7c535dfc037854e226908d75"
 },
 "6596": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   28,
   81
  ],
  "target": [
   20504,
   30,
   81
  ],
  "file": "EV_aoki_6596.txt",
  "sha256": "93f3c202096fb277daca14e3fb17f9cd24029092d6c2a18e83ed05317c5955c3"
 },
 "6597": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   29,
   81
  ],
  "target": [
   20504,
   27,
   81
  ],
  "file": "EV_aoki_6597.txt",
  "sha256": "f031fba2b9da5759e026a49cbf80d45ae22a1f199c4144976f19325d17281d21"
 },
 "6598": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   47,
   80
  ],
  "target": [
   20504,
   49,
   80
  ],
  "file": "EV_aoki_6598.txt",
  "sha256": "4b874ef12a253d6cd6638682cd827ed8444dd18b57e705013c3b674db31ff70a"
 },
 "6599": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   48,
   80
  ],
  "target": [
   20504,
   46,
   80
  ],
  "file": "EV_aoki_6599.txt",
  "sha256": "c8ff5b68d2f9178a846d8ed3e92499e9ffcd91d207815cd5a54e6190756591d9"
 },
 "6600": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   17,
   70
  ],
  "target": [
   20504,
   17,
   68
  ],
  "file": "EV_aoki_6600.txt",
  "sha256": "4a69a8afa91e3046d78a9de0589a3f89b7a84c0f600c8de687c21cf92977270c"
 },
 "6601": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   17,
   69
  ],
  "target": [
   20504,
   17,
   71
  ],
  "file": "EV_aoki_6601.txt",
  "sha256": "a2e7da81166b36819c3698b7e19ff6bb4c704bf6db4c20e1eaea2a7ded6d36a6"
 },
 "6602": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   28,
   48
  ],
  "target": [
   20504,
   30,
   48
  ],
  "file": "EV_aoki_6602.txt",
  "sha256": "d6729c41f3db87c88a553d6333e4b14d1942690b669a1422a70e1eaadef34861"
 },
 "6603": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   29,
   48
  ],
  "target": [
   20504,
   27,
   48
  ],
  "file": "EV_aoki_6603.txt",
  "sha256": "9b22334891ef0e5ca722b054e0a8f8ec65990fdac6d649243ae2547830af4c4e"
 },
 "6604": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   63,
   48
  ],
  "target": [
   20504,
   65,
   48
  ],
  "file": "EV_aoki_6604.txt",
  "sha256": "2da6a796f2506fb223d483b9ca125e8e60d4cb5c9dc16e511b85dec13a543cc1"
 },
 "6605": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   64,
   48
  ],
  "target": [
   20504,
   62,
   48
  ],
  "file": "EV_aoki_6605.txt",
  "sha256": "85149ac40005292850bfecb31a47dff56022b4d224cbd3b793c09339f1862fe9"
 },
 "6606": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   79,
   40
  ],
  "target": [
   20504,
   78,
   38
  ],
  "file": "EV_aoki_6606.txt",
  "sha256": "261204fb4f16809a8a9eacdd74c9a27cd40e481401ebf4e25112f0eaf3774c95"
 },
 "6607": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   79,
   39
  ],
  "target": [
   20504,
   79,
   41
  ],
  "file": "EV_aoki_6607.txt",
  "sha256": "71540f520505b18d04deeeae59066d77b4f9b3004a7d91a2d34e72e94a9a5a91"
 },
 "6608": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   79,
   25
  ],
  "target": [
   20504,
   79,
   23
  ],
  "file": "EV_aoki_6608.txt",
  "sha256": "4728ce769723dc5b594bd3b9d98dae3a83f7817a49670b81c2a9d6c555a03df9"
 },
 "6609": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   79,
   24
  ],
  "target": [
   20504,
   79,
   26
  ],
  "file": "EV_aoki_6609.txt",
  "sha256": "4fcffd6dd3ebf18581bfcdcbf27379c3ca57c36466d40bbfd93b3a1c8fafc50f"
 },
 "6610": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   64,
   15
  ],
  "target": [
   20504,
   62,
   15
  ],
  "file": "EV_aoki_6610.txt",
  "sha256": "9d1994399dde00cd39312c36940f7413f21a0520139efe4d794110f9152575bb"
 },
 "6611": {
  "kind": "candle",
  "source": 20504,
  "cell": [
   63,
   15
  ],
  "target": [
   20504,
   65,
   15
  ],
  "file": "EV_aoki_6611.txt",
  "sha256": "f36cacb40a14902dea68d2fe3e4401f1963c0e95349086a1fbcbd52ebacdf648"
 },
 "6612": {
  "kind": "candle",
  "source": 20505,
  "cell": [
   14,
   83
  ],
  "target": [
   20518,
   15,
   83
  ],
  "file": "EV_aoki_6612.txt",
  "sha256": "5d078da5625ec686dfc375a0056eae64a6b58fc03db592960b91ff35585b74ef"
 },
 "6613": {
  "kind": "candle",
  "source": 20524,
  "cell": [
   77,
   47
  ],
  "target": [
   20506,
   78,
   47
  ],
  "file": "EV_aoki_6613.txt",
  "sha256": "7d49b3684924a61155b30011e9c0107603549a1bfb6bea841e7bbddb8becbf9d"
 },
 "6614": {
  "kind": "candle",
  "source": 20508,
  "cell": [
   74,
   30
  ],
  "target": [
   20519,
   74,
   29
  ],
  "file": "EV_aoki_6614.txt",
  "sha256": "45f5cffcbcd33f5a8c2382d04cdac3ebff806f34c4dd2794f017c9a95fe95b03"
 },
 "6615": {
  "kind": "candle",
  "source": 20508,
  "cell": [
   74,
   64
  ],
  "target": [
   20530,
   74,
   63
  ],
  "file": "EV_aoki_6615.txt",
  "sha256": "0b4e9e90c15512b670ed6d1d419bd907462e581b4b29f71049e68bbbeb05a7ae"
 },
 "6616": {
  "kind": "candle",
  "source": 20510,
  "cell": [
   8,
   76
  ],
  "target": [
   20525,
   9,
   76
  ],
  "file": "EV_aoki_6616.txt",
  "sha256": "9fb7eee4fce6c5e4d2e272781c4e400527f81725169807c3f9d869890b3e8b8e"
 },
 "6617": {
  "kind": "candle",
  "source": 20511,
  "cell": [
   47,
   27
  ],
  "target": [
   20520,
   48,
   29
  ],
  "file": "EV_aoki_6617.txt",
  "sha256": "a19b7dec187d54c4b2a7eb730ccfb3a0f60a70e9f6b46323cf41bcd67a574b57"
 },
 "6618": {
  "kind": "candle",
  "source": 20512,
  "cell": [
   73,
   24
  ],
  "target": [
   20521,
   73,
   23
  ],
  "file": "EV_aoki_6618.txt",
  "sha256": "c334a704490adae025b486aa4f361e922265a99c143e6bfeadfce52c2a0e1115"
 },
 "6619": {
  "kind": "candle",
  "source": 20522,
  "cell": [
   8,
   8
  ],
  "target": [
   20526,
   9,
   8
  ],
  "file": "EV_aoki_6619.txt",
  "sha256": "50afea1730d0ddcac7a2873e85f774c4db24fc27ad3ab826762ff308f676fd74"
 },
 "6620": {
  "kind": "candle",
  "source": 20502,
  "cell": [
   45,
   55
  ],
  "target": [
   20515,
   45,
   56
  ],
  "file": "EV_aoki_6620.txt",
  "sha256": "ec8a70703cbd8b82bdf0de80b0031e2583bac3bf9871710dfd8cba1fbc4dbb6c"
 },
 "6621": {
  "kind": "flame",
  "source": 20502,
  "cell": [
   45,
   66
  ],
  "target": [],
  "file": "EV_aoki_6565.txt",
  "sha256": "b9788c497bb11462392a1145e7638c60d12a5953ef3526064e602d8b5c7db12d"
 },
 "6622": {
  "kind": "flame",
  "source": 20504,
  "cell": [
   53,
   80
  ],
  "target": [],
  "file": "EV_aoki_6565.txt",
  "sha256": "b9788c497bb11462392a1145e7638c60d12a5953ef3526064e602d8b5c7db12d"
 },
 "6623": {
  "kind": "flame",
  "source": 20515,
  "cell": [
   45,
   66
  ],
  "target": [],
  "file": "EV_aoki_6565.txt",
  "sha256": "b9788c497bb11462392a1145e7638c60d12a5953ef3526064e602d8b5c7db12d"
 },
 "6624": {
  "kind": "candle",
  "source": 20519,
  "cell": [
   73,
   64
  ],
  "target": [
   20530,
   74,
   63
  ],
  "file": "EV_aoki_6615.txt",
  "sha256": "0b4e9e90c15512b670ed6d1d419bd907462e581b4b29f71049e68bbbeb05a7ae"
 },
 "6625": {
  "kind": "flame",
  "source": 20520,
  "cell": [
   33,
   18
  ],
  "target": [],
  "file": "EV_aoki_6565.txt",
  "sha256": "b9788c497bb11462392a1145e7638c60d12a5953ef3526064e602d8b5c7db12d"
 }
}
