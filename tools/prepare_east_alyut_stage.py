"""Prepare a reviewable canonical Alyut asset set; never activate it."""
import argparse
import hashlib
import json
import shutil
import tempfile
from pathlib import Path

import prepare_east_alyut_complete as complete
import prepare_east_alyut_banks as banks
import prepare_east_alyut_gate_handoffs as handoffs
import prepare_east_alyut_overlaps as overlaps

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Canonical Stage'
CANONICAL=ROOT/'assets/maps/falan/east_region/alyut_source_completion'
NATURAL_PNG='aae20ac28bf1f6dd8c10a6752001420e3cabdefc6e2dde23f7348b39fb23fc58'
CAP_DATA='6ce72ae599e9dbe73e538409551afbdce63b610f0fe347d79612cf407cbb4253'
CPU_PNGS=['mask.png','ground-index.png','ground-atlas.png','props/native.png']
KEEP_IMPORT='[remap]\n\nimporter="keep"\n'
RUNTIME_FILES=['map-data.json','hybrid-map.bin','mask.png','ground-index.png','ground-atlas.png','walk.png','banks.json','gate-handoffs.json','source-overlaps.json','props/data.json','props/native.png',*[name+'.import'for name in CPU_PNGS]]
INPUTS=['tools/prepare_east_alyut_stage.py','tools/prepare_east_alyut_complete.py','tools/prepare_east_alyut_banks.py','tools/prepare_east_alyut_gate_handoffs.py','tools/prepare_east_alyut_overlaps.py','tools/prepare_east_village_props.py','tools/prepare_east_field_cliffs.py','scripts/forest/forest_east_alyut_source_completion.gd','scripts/forest/forest_freyja_art.gd','scripts/forest/forest_east_region.gd','scripts/forest/forest_freyja_regions.gd','scripts/forest/forest_freyja_terrain.gd','scripts/forest/forest_falan_frontier.gd','scripts/forest/forest_rampart_art.gd','scripts/forest/forest_east_bank_underlay.gd','scripts/forest/forest_east_bank_caps.gd','assets/maps/falan/east_region/bank_caps/data.json','assets/maps/falan/east_region/bank_caps/surfaces.png','export_presets.cfg']


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(out):
    assert out.resolve()!=CANONICAL.resolve(),'This staging command never creates/replaces the canonical Alyut asset set'
    caps=ROOT/'assets/maps/falan/east_region/bank_caps'
    assert sha(caps/'surfaces.png')==NATURAL_PNG and sha(caps/'data.json')==CAP_DATA,'Root must publish the accepted canonical natural Caps source before staging'
    with tempfile.TemporaryDirectory(prefix='east-alyut-stage-',dir='/private/tmp')as temp:
        folder=Path(temp);complete.prepare(folder,False);banks.prepare(folder);handoffs.prepare(folder);overlaps.prepare(folder)
        # Exact include filters select these CPU-read PNGs; Keep File prevents
        # Godot's texture importer from replacing their original bytes at export.
        for name in CPU_PNGS:(folder/(name+'.import')).write_text(KEEP_IMPORT)
        out.mkdir(parents=True,exist_ok=True)
        for relative in [*RUNTIME_FILES,'source-contract.json']:
            target=out/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(folder/relative,target)
    data=json.loads((out/'map-data.json').read_text());bank_rows=json.loads((out/'banks.json').read_text());gates=json.loads((out/'gate-handoffs.json').read_text())
    manifest={'status':'STAGED_ONLY_REQUIRES_ROOT_DIFF_REVIEW_BEFORE_PUBLICATION','canonical_target':str(CANONICAL.relative_to(ROOT)),'source_hybrid_sha256':sha(out/'hybrid-map.bin'),'source_pinned_git_blob':data['source']['pinned_git_blob'],'source_variant':data['source']['selected_variant'],'runtime_files':{relative:sha(out/relative)for relative in RUNTIME_FILES},'source_inputs':{relative:sha(ROOT/relative)for relative in INPUTS},'counts':{'source_art':len(data['placements']),'tall_cliffs':204,'native_props':334,'source_trees':31,'banks':len(bank_rows['rows']),'original_water_ring':76,'field_handoffs':len(gates['handoff_cells']),'separate_source100_overlap_cells':6,'source100_restored_flowers':1,'actors':len(data['actors']),'connections':len(data['connections'])},'production_material_owner':'forest_freyja_art.gd calls Full.apply_materials only for alyut/north_coast when its source assets are present. Existing enabled visibility owner is refused with specific terrain metadata. Original water mask is cloned for117source-water bank cells; no original source/mask/height/collision/walk data is mutated. Natural hidden bank finish belongs to the accepted canonical Caps owner. Separate6cell source100overlap preserves5original field routes and restores1original12172flower/nativeclosure; it never enters the2400watercut ring.','raw_png_export_requirements':[str((CANONICAL/name).relative_to(ROOT))for name in CPU_PNGS],'raw_png_import_mode':'Four authored Keep File sidecars retain original PNG bytes for Image.load_from_file. Include filters alone do not bypass texture import remaps. Godot4.6.1 exporter editor_export_platform.cpp1331..1340 preserves importer=keep; editor_file_system.cpp610..612 does not reimport Keep File. No app/PCK export performed.','export_static_proof':'build/Other Files/Asset Toolkit/East Gate Region/Verification/export-data-contract.json (64/0; noapp/PCKexport, futurecanonical4paths explicit)','activation':'Not performed. After Root reviews the concrete diff and minimal current-source stage run, publication would copy ONLY the listed runtime_files plus this source manifest and source-contract into the canonical_target. This tool never writes that target.','verification_pending':'Stage-run actual five gate handoffs +117bank supports +six source100overlap approach/returns and original flower closure +normal/second current views, retaining prior unchanged five-house proof. Whole-Alyut visual completion is not claimed: inherited source100shore slope and cliff-family geometry remain separate unfinished work.'}
    assert manifest['source_hybrid_sha256']==data['source']['sha256']
    (out/'publication.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('EAST_ALYUT_CANONICAL_STAGE',len(RUNTIME_FILES),'runtime files;',manifest['counts'],'CANONICAL_INACTIVE')


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    if args.check:
        with tempfile.TemporaryDirectory(prefix='east-alyut-stage-check-',dir='/private/tmp')as temp:
            folder=Path(temp);prepare(folder);expected=[*RUNTIME_FILES,'source-contract.json','publication.json'];stale=[name for name in expected if not(OUT/name).exists()or(OUT/name).read_bytes()!=(folder/name).read_bytes()]
            assert not stale,'Stale staged Alyut products: '+','.join(stale)
        print('EAST_ALYUT_CANONICAL_STAGE_CHECK PASS')
    else:prepare(OUT)


if __name__=='__main__':main()
