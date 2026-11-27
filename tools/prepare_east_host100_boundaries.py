"""Exact private source100 player boundary runs; no global/world mutation."""
import base64
import json
import sys
from pathlib import Path
from prepare_east_host100_fields import OUT, ROOT, RESTORE, digest, within_mask
from run_east_host100_field_proof import decoded
from prepare_east_region_maps import reference_map


def main():
    restore_path=RESTORE/'field100-restore.json';restore=json.loads(restore_path.read_text())
    raw_path=ROOT/restore['raw_path'].removeprefix('res://');assert digest(raw_path)==restore['raw_sha256']
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    pinned_path=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Version Expansion Source Audit/map__00100_field1'
    assert digest(pinned_path)==restore['source100_pinned_sha256']
    w,h,bg,pg,flags=lib.parse_map(raw_path.read_bytes());fw,fh,full,_=reference_map(pinned_path.read_bytes(),100);assert(w,h)==(fw,fh)==(840,610)
    full_bg,full_pg=full[:w*h],full[w*h:2*w*h]
    # A guarded preparer omission is not an original region wall. Only
    # unrecorded zero tuples borrow complete-source metadata outside the fill.
    metadata_raw=bytearray(raw_path.read_bytes());fallback=[]
    for i in range(w*h):
        if (bg[i],pg[i])!=(0,0) or flags[i]&0xc000:continue
        if (full_bg[i],full_pg[i])==(0,0):continue
        bg[i],pg[i]=full_bg[i],full_pg[i];fallback.append(i)
        for plane,value in [(0,bg[i]),(1,pg[i])]:
            at=20+(plane*w*h+i)*2;metadata_raw[at:at+2]=int(value).to_bytes(2,'little')
    native=navigation_grid(w,h,bg,pg,lib.serial_index());bits=bytearray((w*h+7)//8)
    for i,value in enumerate(native):
        if value:bits[i>>3]|=1<<(i&7)
    metadata_path=OUT/'boundary-source-metadata.dat';metadata_path.write_bytes(metadata_raw);areas={}
    paths=[Path(__file__),restore_path,raw_path,pinned_path,OUT/'manifest.json']
    paths += [OUT/(area+'-field.json')for area in ['east_gate','north_coast']]
    before={str(path.relative_to(ROOT)):digest(path)for path in paths}
    def opened(x,z):
        i=z*w+x;return 0<=x<w and 0<=z<h and bool(bits[i>>3]&(1<<(i&7)))
    manifest=json.loads((OUT/'manifest.json').read_text())
    for area in ['east_gate','north_coast']:
        assert digest(OUT/(area+'-field.json'))==manifest['areas'][area]['sha256'],'Only a fully committed two-field product may produce player boundaries'
        field=json.loads((OUT/(area+'-field.json')).read_text());scope=decoded(field,'scope_bits','byte');protected=set(field['protected_bridge_cells']);runs=[];edges=0
        def owned(x,z):
            i=z*w+x
            return 0<=x<w and 0<=z<h and i not in protected and within_mask(area,x,z,field) and bool(scope[i>>3]&(1<<(i&7)))
        for along_x in [True,False]:
            rows,columns=(h,w)if along_x else(w,h)
            for row in range(rows+1):
                start=-1
                for column in range(columns+1):
                    edge=False
                    if column<columns:
                        a=(column,row-1)if along_x else(row-1,column);b=(column,row)if along_x else(row,column)
                        protected_edge=any(0<=x<w and 0<=z<h and z*w+x in protected for x,z in [a,b])
                        edge=not protected_edge and (owned(*a)or owned(*b))and opened(*a)!=opened(*b)
                    if edge and start<0:start=column
                    if edge or start<0:continue
                    runs.append([int(along_x),row,start,column]);edges+=column-start;start=-1
        areas[area]={'field_sha256':digest(OUT/(area+'-field.json')),'runs':runs,'source_edges':edges,'protected_bridge_cells':len(protected)}
    changed=[path for path,sha in before.items()if digest(ROOT/path)!=sha];assert not changed
    report={'raw_sha256':restore['raw_sha256'],'boundary_metadata_raw_path':'res://'+str(metadata_path.relative_to(ROOT)),'boundary_metadata_raw_sha256':digest(metadata_path),'native_walk_bits':base64.b64encode(bits).decode(),'unrecorded_metadata_fallback_cells':len(fallback),'areas':areas,'source_hashes':before,'source_changed':changed,
            'scope':'PRIVATE thin player boundaries only at original source100 open/closed cardinal edges incident to enrolled cells. Existing bridge cells/edges stay with the whole bridge owner. No visual wall or extra route.',
            'inferred':'Collision extends from local-10 to+30 to preserve the original 2D blocked edge under the inferred terrain grade. Camera water-only metadata uses unchanged original BG/PG1/native bits.'}
    (OUT/'player-boundaries.json').write_text(json.dumps(report)+'\n')
    print('HOST100_PLAYER_BOUNDARIES', {area:{'runs':len(row['runs']),'source_edges':row['source_edges']}for area,row in areas.items()})


if __name__=='__main__':main()
