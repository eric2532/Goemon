"""Prepare read-only baseline generators from the pre-reskin commit for audit.gd.
Run from the repository root; generated copies are ignored by Git.
"""
from pathlib import Path
import subprocess
BASE='0da35bc7eaa93c68bf6939b5238989af16920919'
folder=Path(__file__).parent/'baseline';folder.mkdir(exist_ok=True)
for name in ('world.gd','expedition_area.gd','world_expansion.gd'):
    source=subprocess.check_output(['git','show',f'{BASE}:scripts/{name}'],text=True)
    if name=='world.gd':
        # Inherit unchanged data members to remain assignable to game.world.
        source='extends Sanctuary\n\n'+source[source.index('func height_at'):]
    elif name=='expedition_area.gd':
        source=source.replace('class_name ExpeditionArea\nextends Sanctuary','extends "res://tests/environment-reskin/baseline/world.gd"')
    else:source=source.replace('class_name WorldExpansion\n','')
    source=source.replace('WorldExpansion.','preload("res://tests/environment-reskin/baseline/world_expansion.gd").')
    (folder/name).write_text(source)
print('Prepared baseline generators from',BASE)
