"""Recover the two retail Sonic effects; editable masters use the normal importer/exporter."""
import hashlib
import json
from pathlib import Path
from recover import ROOT, relocated, textures, recover_model

def main():
    folder=ROOT/'build/Other Files/Asset Toolkit/Sonic/Research'
    output=ROOT/'assets/characters/recovered_sonic'
    models=relocated((folder/'ModelsMiles.rel').read_bytes())
    images=textures((folder/'son_eff.GVM').read_bytes())
    manifest={'disc':'GXSP8P revision 1','sources':{name:hashlib.sha256((folder/name).read_bytes()).hexdigest() for name in ('ModelsMiles.rel','son_eff.GVM')},'models':{}}
    for name,address in [('effect_trail',0x21b848),('effect_ball',0x21c288)]:
        manifest['models'][name]=recover_model(models,address,[],images,output/(name+'.glb'))
        print(name,manifest['models'][name]['triangles'])
    (output/'effects_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

if __name__=='__main__':main()
