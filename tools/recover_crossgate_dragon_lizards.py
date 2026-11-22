"""Recover the twenty reviewed dragon-lizard IDs using the shared pet packer."""
import argparse
from pathlib import Path
from recover_crossgate_mantises import ROOT, recover

ACTORS = [(101720, 'original:2940'), (101721, 'original:2941'), (101722, 'original:2942'), (101723, 'original:2943'), (103379, 'puk2:1303'), (103380, 'puk2:1304'), (103381, 'puk2:1305'), (103382, 'puk2:1306'), (107917, 'ch1:619'), (107918, 'ch1:620'), (109260, 'ch1:677'), (117028, 'v3:774'), (117151, 'puk3:352'), (109878, 'puk3:821'), (116561, 'puk3:707'), (109938, 'puk3:881'), (119268, 'ch1:969'), (119269, 'ch1:970'), (119270, 'ch1:971'), (119271, 'ch1:972')]

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('source',type=Path)
    recover(parser.parse_args().source,ACTORS,ROOT/'assets/characters/crossgate/dragon_lizards',range(119268,119272))
