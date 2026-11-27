"""Install reviewed source BG stair data; leave unrelated private fits out."""
import json
import shutil
from PIL import Image
import recover_elsa_island as source
import prepare_elsa_second_stair as stair
from prepare_elsa_hall_entry_floor import CANON,compose_canonical_floor

TARGET=source.ROOT/'assets/maps/falan/elsa/scenery/temple-bg-stair'


def build():
    mesh=json.loads((stair.OUT/'data.json').read_text());support=json.loads((stair.OUT/'support-data.json').read_text())
    assert mesh['geometry_sha256']==support['geometry_sha256']
    assert len(mesh['source_balusters'][0])==6 and len(mesh['source_balusters'][1])==5
    assert support['lower_ramp']['gradient']<.55 and support['steps']['external_visual']
    ground=json.loads((stair.OUT/'parent-ground.json').read_text())
    assert ground['stair_photo_mask_sha256']==source.sha(Image.open(stair.OUT/'bg-photo-mask.png').convert('L').tobytes())
    base=source.REPORT/'Temple Interior/Production Integration Base';base.mkdir(parents=True,exist_ok=True)
    for path in [CANON/'floor-data.json',*CANON.glob('floor-atlas-*.png')]:
        if not (base/path.name).exists():shutil.copy2(path,base/path.name)
    TARGET.mkdir(parents=True,exist_ok=True)
    for name in ['native-paint.png','body.png','body-native-witness.png','cap.png','stone.png','stone_shadow.png','charcoal.png','gold.png','original-background.png','confirmed-floor-mask.png','bg-photo-mask.png']:
        shutil.copy2(stair.OUT/name,TARGET/name)
    for name in ['parent-ground.png','parent-ground-original.png','parent-ground-mask.png','parent-paving-native-witness.png']:
        shutil.copy2(stair.OUT/name,TARGET/name)
    ground['candidate_only']=False;ground['path']='res://'+str((TARGET/'parent-ground.png').relative_to(source.ROOT))
    path=TARGET/'parent-ground.json';temp=path.with_suffix('.tmp');temp.write_text(json.dumps(ground,separators=(',',':'))+'\n');temp.replace(path)
    mesh['candidate_only']=False;support['candidate_only']=False
    support['limits']=[text.replace('No normal activation.','Installed through the normal Explore height owner.') for text in support['limits']]
    for name,row in [('mesh.json',mesh),('data.json',support)]:
        path=TARGET/name;temp=path.with_suffix('.tmp');temp.write_text(json.dumps(row,separators=(',',':'))+'\n');temp.replace(path)
    floor=compose_canonical_floor()
    assert set(floor['regions'])=={'bg_pedestals','bg_stair'}
    old=json.loads((base/'floor-data.json').read_text())
    for key,row in old['placements'].items():assert floor['placements'][key]['rgba_sha256']==row['rgba_sha256'],key
    print('ELSA_BG_STAIR_INSTALLED source-painted geometry/support; canonical pedestal derivative pixels preserved.',flush=True)


if __name__=='__main__':build()
