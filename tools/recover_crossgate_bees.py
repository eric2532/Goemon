"""Recover only the twenty-one reviewed bee IDs using the shared pet packer."""
import argparse
from pathlib import Path
from recover_crossgate_mantises import ROOT, recover

ACTORS = [(101310, 'original:2862'), (101311, 'original:2863'), (101312, 'original:2864'), (101313, 'original:3170'), (101314, 'original:2866'), (102360, 'ex:1599'), (102361, 'ex:1600'), (102362, 'ex:1601'), (102363, 'ex:1602'), (102364, 'ex:1603'), (108208, 'joy-ex:552'), (108333, 'puk2:705'), (117136, 'puk3:337'), (109879, 'puk3:822'), (116562, 'puk3:708'), (118949, 'v3:1929'), (119190, 'ch1:891'), (119191, 'ch1:892'), (119192, 'ch1:893'), (119193, 'ch1:894'), (119194, 'ch1:895')]

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('source',type=Path)
    recover(parser.parse_args().source,ACTORS,ROOT/'assets/characters/crossgate/bees',range(119190,119195))
