"""Build an isolated test extension; never replace canonical Native artifacts."""
from pathlib import Path
import hashlib
import json
import platform
import shutil
import subprocess
import time

ROOT=Path(__file__).resolve().parents[1]
REGION=ROOT/'build/Other Files/Asset Toolkit/East Gate Region'
CONTRACT=REGION/'Il Source Completion/Low Source Candidate/Host/Original100 Candidate/Diagonal Contract'
OUT=REGION/'Village Props/Cliff Audit/Source Context Audit/Prototype/Native Failure Triage/Actual Binding Proof'
SOURCES=['terrain_math.cpp','crowd_binding.cpp','crowd/core.cpp','crowd/terrain.cpp','crowd/air.cpp','crowd/kits.cpp','crowd/combat.cpp','crowd/skullpion.cpp','crowd/dark_lumina_3.cpp','crowd/dark_lumina.cpp','crowd/bunker.cpp','crowd/instance_buffers.cpp']

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 manifest=json.loads((CONTRACT/'source-contract.json').read_text())
 native=ROOT/'native/terrain_math';sources=OUT/'native';sources.mkdir(parents=True,exist_ok=True);(OUT/'bin').mkdir(exist_ok=True)
 inputs={str((CONTRACT/'source-contract.json').relative_to(ROOT)):sha(CONTRACT/'source-contract.json')}
 for name,record in manifest['sources'].items():
  if 'candidate_sha256' not in record:continue
  for prefix,key in [('before','before_sha256'),('candidate','candidate_sha256')]:
   path=CONTRACT/prefix/name;assert sha(path)==record[key],path;inputs[str(path.relative_to(ROOT))]=sha(path)
 paths=[native/name for name in SOURCES]+list(native.rglob('*.h'))
 for path in paths:
  relative=path.relative_to(native);candidate=CONTRACT/'candidate/native/terrain_math'/relative
  chosen=candidate if candidate.exists() else path
  inputs[str(chosen.relative_to(ROOT))]=sha(chosen)
  destination=sources/relative;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(chosen,destination)
 replacements={
  'terrain_math.cpp':{'GoemonTerrainMath':'GoemonEastDiagonalProofTerrain','goemon_terrain_math_init':'goemon_east_diagonal_proof_init'},
  'crowd_binding.cpp':{'GoemonCrowdRuntime':'GoemonEastDiagonalProofCrowd'},
 }
 for filename,pairs in replacements.items():
  path=sources/filename;text=path.read_text()
  for original,replacement in pairs.items():assert text.count(original)==1,(filename,original);text=text.replace(original,replacement)
  path.write_text(text)
 canonical=native/'bin/libgoemon_terrain_math.macos.universal.dylib';canonical_before=sha(canonical)
 arch=platform.machine();assert arch in ['arm64','x86_64']
 library=OUT/'bin'/('libeast_diagonal_proof.'+arch+'.dylib')
 command=['clang++','-std=c++17','-O3','-ffp-contract=off','-fno-fast-math','-fvisibility=hidden','-arch',arch,'-mmacosx-version-min=11.0','-dynamiclib',*[str(sources/name) for name in SOURCES],'-install_name','@rpath/'+library.name,'-o',str(library)]
 started=time.monotonic();run=subprocess.run(command,capture_output=True,text=True);(OUT/'build.log').write_text(run.stdout+run.stderr);assert run.returncode==0,run.stderr
 sign=subprocess.run(['codesign','--force','--sign','-',str(library)],capture_output=True,text=True);(OUT/'codesign.log').write_text(sign.stdout+sign.stderr);assert sign.returncode==0,sign.stderr
 resource='res://'+str(library.relative_to(ROOT))
 extension=OUT/'east_diagonal_proof.gdextension';extension.write_text('[configuration]\nentry_symbol = "goemon_east_diagonal_proof_init"\ncompatibility_minimum = "4.6"\nreloadable = false\n\n[libraries]\nmacos.debug.'+arch+'.single = '+json.dumps(resource)+'\nmacos.release.'+arch+'.single = '+json.dumps(resource)+'\n')
 changed=[p for p,d in inputs.items() if sha(ROOT/p)!=d];assert not changed
 assert sha(canonical)==canonical_before
 result={'patch_sha256':manifest['patch_sha256'],'architecture':arch,'compile_seconds':time.monotonic()-started,'canonical_dylib_sha256_before':canonical_before,'canonical_dylib_sha256_after':sha(canonical),'private_library':resource,'private_library_sha256':sha(library),'private_extension':'res://'+str(extension.relative_to(ROOT)),'extension_sha256':sha(extension),'source_hashes':inputs,'owned_copies':{str(p.relative_to(ROOT)):sha(p) for p in sources.rglob('*') if p.is_file()},'source_changed':changed,'scope':'Copied candidate sources, proof-only class names and entry symbol, current-host architecture test dylib only. Canonical Native code/classes/dylib and source contexts unchanged. No app/PCK export.'}
 (OUT/'build-proof.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k not in ['source_hashes','owned_copies']},indent=2))

if __name__=='__main__':main()
