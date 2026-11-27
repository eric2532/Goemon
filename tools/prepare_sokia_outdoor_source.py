"""Validate outdoor completion and prepare explicit existing-owner inputs; preserve client archives."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys
import os

from prepare_east_region_maps import complete_map, reference_map

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/references/crossgate_sokia/maps/server'
OUT = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server completion'
MAPS = {100: '00100_field1', 300: '00300_field2'}
ACTIVE = ROOT / 'assets/maps/falan/sokia/source'
FREYJA_ACTIVE = ROOT / 'assets/maps/falan/freyja_source'


def source_folder():
    return Path(os.environ.get('CROSSGATE_SOKIA_SOURCE_DIR',str(ACTIVE)))


def active_map(library,number=300):
    """Prepared outdoor planes; runtime owners still consume their usual derivatives."""
    assert number in (100,300)
    folder=source_folder()if number==300 else Path(os.environ.get('CROSSGATE_FREYJA_SOURCE_DIR',str(FREYJA_ACTIVE)))
    path=folder/f'{number}.dat'
    if not path.exists():return None
    state=json.loads((folder/'provenance.json').read_text());raw=path.read_bytes()
    assert sha(raw)==state['active_sha256']
    client=Path(state['client_path']).read_bytes()
    assert sha(client)==state['client_sha256']
    w,h,f,o,flags=library.parse_map(raw);cw,ch,cf,co,cflags=library.parse_map(client)
    assert (w,h)==(cw,ch)and flags==cflags
    assert all((f[i],o[i])==(cf[i],co[i])for i,v in enumerate(flags)if v&0xc000)
    assert all(not v or f[i]==v for i,v in enumerate(cf))
    assert all(not v or o[i]==v for i,v in enumerate(co))
    return w,h,f,o,flags


def stage_freyja(destination,bounds=None):
    """Prepare the validated map100 completion offline before any mask activation."""
    outputs,report=prepare();record=next(r for r in report['maps']if r['map']==100)
    raw=outputs[record['candidate']]
    if bounds:
        x,y,width,height=bounds;partial=bytearray(Path(record['client_path']).read_bytes());w,h=record['dimensions'];cells=w*h
        assert 0<=x<x+width<=w and 0<=y<y+height<=h
        for yy in range(y,y+height):
            for xx in range(x,x+width):
                i=yy*w+xx
                for plane in (0,1):
                    offset=20+(plane*cells+i)*2;partial[offset:offset+2]=raw[offset:offset+2]
        raw=bytes(partial)
    state=dict(record,active=False,active_sha256=sha(raw),preview_bounds=bounds,stage='coherent-cluster-outdoor100-offline'if bounds else'full-source-outdoor100-offline',
               contract='Offline full-source input only. Existing masks, native support, scenery and encounter owners remain unchanged until separately reviewed publication.')
    folder=Path(destination);folder.mkdir(parents=True,exist_ok=True)
    (folder/'.gdignore').touch();(folder/'100.dat').write_bytes(raw)
    (folder/'provenance.json').write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n')
    return state


def publish_sokia(bounds=None,destination=None):
    outputs,report=prepare();record=next(r for r in report['maps']if r['map']==300)
    raw=outputs[record['candidate']]
    if bounds:
        x,y,width,height=bounds;client=Path(record['client_path']).read_bytes();partial=bytearray(client)
        w,h=record['dimensions'];cells=w*h
        assert 0<=x<x+width<=w and 0<=y<y+height<=h
        for yy in range(y,y+height):
            for xx in range(x,x+width):
                i=yy*w+xx
                for plane in (0,1):
                    offset=20+(plane*cells+i)*2;partial[offset:offset+2]=raw[offset:offset+2]
        raw=bytes(partial)
    state=dict(record,active=destination is None or Path(destination).resolve()==ACTIVE.resolve(),active_sha256=sha(raw),preview_bounds=bounds,
               stage='coherent-cluster-review'if bounds else'full-source-outdoor300',
               contract='Original archive/client remains unchanged; only existing four outdoor owners consume these prepared planes. Map100 completion remains inactive.')
    state['limits']=record['limits'][:2]+[
        'The existing four outdoor owners consume the published prepared additions; provenance and fixed-camera checks distinguish this active extent from the inactive full-source candidate.'
        if state['active']else'Staged offline only; current runtime derivatives remain unchanged.']
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    w,h,floor,objects,_=lib.parse_map(raw)
    _,_,old_floor,old_objects,_=lib.parse_map(Path(record['client_path']).read_bytes())
    state['active_additions']={
        'dry_ground_cells':sum(not old_floor[i]and s not in (0,100)and not 5000<=s<=5008 for i,s in enumerate(floor)),
        'water_ground_cells':sum(not old_floor[i]and 5000<=s<=5008 for i,s in enumerate(floor)),
        'raw_object_anchors':sum(not old_objects[i]and bool(s)for i,s in enumerate(objects)),
        'graphic_anchors':sum(not old_objects[i]and s>=1000 for i,s in enumerate(objects))}
    state['active_decoder_open_cells']=sum(navigation_grid(w,h,floor,objects,lib.serial_index()))
    folder=Path(destination)if destination else ACTIVE
    folder.mkdir(parents=True,exist_ok=True)
    (folder/'.gdignore').touch()
    (folder/'300.dat').write_bytes(raw);(folder/'provenance.json').write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n')
    return state


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def prepare():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    proofs = {r['file']: r for r in json.loads((SOURCE / 'references.json').read_text())}
    lookup = lib.serial_index()
    records = []
    outputs = {}
    for number, name in MAPS.items():
        server = (SOURCE / name).read_bytes()
        assert sha(server) == proofs[name]['sha256']
        w, h, source_values, title = reference_map(server, number)
        client_path = ROOT.parent / f'Magic Power/data/crossgate/source/BlueCrossgate/map/0/{number}.dat'
        client = client_path.read_bytes()
        merged, contract = complete_map(client, server, number)
        assert contract['compatible'], 'Unrecorded cells need a compatible source variant'
        cw, ch, old_floor, old_objects, flags = lib.parse_map(client)
        mw, mh, floor, objects, final_flags = lib.parse_map(merged)
        assert (w, h) == (cw, ch) == (mw, mh) and flags == final_flags
        cells = w*h
        known = [i for i, flag in enumerate(flags) if flag & 0xc000]
        assert all((floor[i], objects[i]) == (old_floor[i], old_objects[i]) for i in known)
        variations = [dict(cell=[i%w, i//w], client=[old_floor[i], old_objects[i]],
                           server=[source_values[i], source_values[cells+i]])
                      for i in known if (old_floor[i], old_objects[i]) !=
                      (source_values[i], source_values[cells+i])]
        added_dry = [i for i in range(cells) if not old_floor[i] and floor[i] not in (0, 100)
                     and not 5000 <= floor[i] <= 5008]
        added_objects = [i for i in range(cells) if not old_objects[i] and objects[i]]
        old_walk = navigation_grid(w, h, old_floor, old_objects, lookup)
        walk = navigation_grid(w, h, floor, objects, lookup)
        record = dict(map=number, title=title, dimensions=[w, h], source=proofs[name],
            client_path=str(client_path), client_sha256=sha(client), candidate_sha256=sha(merged),
            candidate=f'{number}-client-plus-server.dat', completion=contract,
            recorded_client_variations_preserved=variations,
            client_flags_preserved=True, original_client_flags_for_server_only_cells_available=False,
            added_dry_ground_cells=len(added_dry),
            added_ground_serials=dict(Counter(floor[i] for i in range(cells) if not old_floor[i] and floor[i])),
            added_object_anchors=len(added_objects),
            added_object_serials=dict(Counter(objects[i] for i in added_objects)),
            client_open_cells=sum(old_walk), candidate_open_cells=sum(walk),
            recorded_walk_changes_from_completed_footprints=[
                [i%w, i//w, old_walk[i], walk[i]] for i in known if old_walk[i] != walk[i]],
            active=False,
            limits=['Only unrecorded client cells are completed; every recorded client plane and all flags remain exact.',
                    'Server planes have no client flag layer. Configured/scripted entrances and runtime collisions need their own checks.',
                    'This stages data only; current terrain, art, mask bounds, native navigation and encounter owners are unchanged.'])
        records.append(record)
        outputs[record['candidate']] = merged
    report = dict(goal_complete=False, source_variant='Recorded BlueCrossgate client plus pinned LS2MAP in unrecorded cells',
                  maps=records, next='Reconcile all server-only surfaces, object anchors, source entrance rules and native ownership before activation.')
    outputs['source-completion.json'] = (json.dumps(report, ensure_ascii=False, indent=2) + '\n').encode()
    return outputs, report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    outputs, report = prepare()
    OUT.mkdir(parents=True, exist_ok=True)
    for name, raw in outputs.items():
        if args.check:
            assert (OUT / name).read_bytes() == raw, name
        else:
            (OUT / name).write_bytes(raw)
    print(json.dumps([dict(map=r['map'], dry=r['added_dry_ground_cells'], objects=r['added_object_anchors'],
                           open=r['candidate_open_cells'], recorded_walk_changes=len(r['recorded_walk_changes_from_completed_footprints']))
                      for r in report['maps']]))


if __name__ == '__main__':
    main()
