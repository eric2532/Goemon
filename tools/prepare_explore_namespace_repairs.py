"""Recover reviewed local EX bindings, preserving raw maps and every existing bitmap."""
import base64
import io
import json
from pathlib import Path
import sys
import zlib
from audit_explore_access import CATALOGS
from prepare_explore_missing_maps import FRONTIER_EX_NAMESPACES
from prepare_east_region_maps import expanded_lookup, navigation_function, solid_pages
import recover_original_crossgate_maps as recovery
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/Other Files/Asset Toolkit/Explore Access/Namespace review'

def save_exact(image,path):
    buffer=io.BytesIO();image.save(buffer,format='PNG')
    if path.exists():
        assert path.read_bytes()==buffer.getvalue(), 'Preserve existing prepared art: '+str(path)
    else:path.write_bytes(buffer.getvalue())

def main():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    navigation_grid=navigation_function(lib)
    path=ROOT/'assets/maps/original_crossgate/explore_recovered/catalog.json'
    data=json.loads(path.read_text());shared={}
    for catalog in CATALOGS:shared.update(json.loads((ROOT/catalog).read_text()).get('graphics',{}))
    lookup=lib.serial_index();before={};reports=[];prepared={};entries={}
    for key,row in data['maps'].items():
        ident=int(row['id'])
        if ident not in FRONTIER_EX_NAMESPACES:continue
        assert row['layout_reference']['sha256']==FRONTIER_EX_NAMESPACES[ident]
        before[key]=row.copy()
        raw=zlib.decompress(base64.b64decode(row.get('restored_raw',row['raw'])))
        width,height,floor,objects,_=lib.parse_map(raw)
        serials={s for s in floor if s}|{s for s in objects if s>=1000}
        expanded,aliases=expanded_lookup(lib,serials,lookup)
        assert not serials-expanded.keys()
        for serial,alias in aliases.items():entries[alias]=dict(expanded[serial],source_serial=serial)
        prepared[key]=(width,height,floor,objects,expanded,aliases)
    missing={alias:entry for alias,entry in entries.items()if str(alias)not in shared}
    if missing:
        # The one absent chair bitmap uses the existing source decoder and atlas helpers.
        assert set(missing)=={1235045}, 'Review any additional artwork before preparing it'
        assert len(data['pages'])==len(data['solid_pages'])
        pages,graphics,_=recovery.pack_graphics(set(missing),missing,{},lib)
        pages=[page.crop((0,0,128,128))for page in pages]
        surfaces=recovery.rock_surfaces(dict(graphics=graphics),pages);solids=solid_pages(graphics,pages)
        offset=len(data['pages']);surface_offset=len(data['surface_pages'])
        for images,field,stem in[(pages,'pages','atlas'),(surfaces,'surface_pages','surfaces'),(solids,'solid_pages','solid')]:
            for i,image in enumerate(images):
                relative='explore_recovered/namespace-%s-%d.png'%(stem,i)
                save_exact(image,path.parent/Path(relative).name);data[field].append(relative)
        for alias,entry in missing.items():
            graphic=graphics[str(alias)];graphic['page']+=offset
            if 'surfaces'in graphic:graphic['surfaces'][0]+=surface_offset
            assert graphic['rgba_sha256']=='8e72b7c7210646c38173b9de92c21460c31b0a0c52990634f54ce9cfabf33929'
            graphic.update(source_serial=entry['source_serial'],source_native_serial=entry['serial'])
            assert graphic['rect'][0]+graphic['rect'][2]<=128 and graphic['rect'][1]+graphic['rect'][3]<=128
            data['graphics'][str(alias)]=graphic;shared[str(alias)]=graphic
    OUT.mkdir(parents=True,exist_ok=True)
    old_baselines={}
    for baseline in OUT.glob('before-local-EX-map-bindings*.json'):old_baselines.update(json.loads(baseline.read_text()))
    additions={key:row for key,row in before.items()if key not in old_baselines}
    if additions:
        baseline=OUT/('before-local-EX-map-bindings.json'if not old_baselines else'before-local-EX-map-bindings-expanded-frontier.json')
        assert not baseline.exists(), 'Never overwrite a preservation baseline'
        baseline.write_text(json.dumps(additions,ensure_ascii=False,indent=1)+'\n')
    for key,(width,height,floor,objects,expanded,aliases)in prepared.items():
        row=data['maps'][key];ident=int(row['id'])
        assert all(str(alias)in shared for alias in aliases.values())
        walk=navigation_grid(width,height,floor,objects,expanded);bits=bytearray((len(walk)+7)//8)
        for i,opened in enumerate(walk):
            if opened:bits[i>>3]|=1<<(i&7)
        row['graphic_aliases']={str(k):v for k,v in aliases.items()}
        row['walk']=base64.b64encode(zlib.compress(bits,9)).decode()
        row['namespace_repair']={'source_sha256':FRONTIER_EX_NAMESPACES[ident],'local_serial_offset':200000,
            'basis':'Reviewed EX floor namespace: overlapping unexpanded IDs are unrelated non-walkable UI icons; exact64x47 EX floor counterparts and same-map EX prop bindings corroborate the local namespace.',
            'qualification':'Reviewed binding inference; pinned raw layout and original bitmap masters are unchanged. Actual entrance and rendered route checks remain separate.'}
        assert all(row[k]==v for k,v in before[key].items()if k not in['walk','graphic_aliases','namespace_repair'])
        reports.append({'map':ident,'aliases':len(aliases),'walkable_cells':sum(walk)})
    assert len(reports)==len(FRONTIER_EX_NAMESPACES)
    path.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
    (OUT/'local-EX-bindings.json').write_text(json.dumps(reports,indent=2)+'\n')
    print('EXPLORE_NAMESPACE_REPAIRS',reports)

if __name__=='__main__':main()
