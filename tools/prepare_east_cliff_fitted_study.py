"""Private source-alpha-fitting refinement of the connected12538 prototype."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from prepare_east_cliff_boulder_study import ROOT,study
from prepare_east_stone_profiles import source_contour_profile
from east_cliff_geometry import native_triangles
from east_cliff_silhouette_fit import NativeSilhouette,pinned_subdivision

BASE=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Connected Mass Study'
OUT=BASE/'Fused Angular16'


def prepare():
    OUT.mkdir(exist_ok=True)
    source=json.loads((BASE/'Fused Angular14/source-geometry.json').read_text());caps=json.loads((BASE/'Fused Angular15/source-geometry.json').read_text())['parts']
    image=Image.open(BASE/'Fused Angular14/12538-native-untouched.png').convert('RGBA');fit=NativeSilhouette(image,source['graphic'],source['pixel_height']);records=[]
    native=json.loads((ROOT/'assets/maps/original_crossgate/cliff-profiles.json').read_text())['profiles']['12538'];front=Image.open(BASE/'Fused Angular14/observed-native.png').convert('RGBA');profile,contour=source_contour_profile(front,source['graphic'],native);matrix,pinned=pinned_subdivision(native_triangles(profile));low,high=np.array(contour['fitted_source_bounds']);description=study(12538)[-1]
    for index,part in enumerate(source['parts']+caps):
        points=np.array(part['triangles'])
        if index==0:
            raw=native_triangles(profile).reshape(-1,3);pins=np.unique(raw[(abs(raw[:,1])<1e-7)|(abs(raw[:,1]-high[1])<1e-7)],axis=0)
            points,rim=fit.generated_rim(matrix,pins);proof={**pinned,**rim}
        else:
            targets=None
            if part['name'].startswith(('split_crag_','cliff_step_')):
                row=description['placements'][int(part['name'].rsplit('_',1)[1])]
                if row['source_front']:
                    center=np.array(row['source_patch'],float);raw=next(p for p in description['measured_native_patches']if p['center']==row['source_patch']);rx,ry=np.array(raw['radius'])*.35;targets=np.array([center,center+[rx,0],center-[rx,0],center+[0,ry],center-[0,ry]])
            points,proof=fit.whole_part(points,low,high,targets)
        if index>0:
            before=np.array(part['triangles']).reshape(-1,3);after=points.reshape(-1,3);a=before-before.mean(0);b=after-after.mean(0);scale=float((a*b).sum()/(a*a).sum());translation=after.mean(0)-before.mean(0)*scale
            assert np.allclose(before*scale+translation,after,atol=1e-7),'Whole source master must remain a rigid/uniform variant'
            proof['independent_whole_similarity_residual_m']=float(np.linalg.norm(before*scale+translation-after,axis=1).max())
        records.append({**part,'triangles':points.tolist(),'native_silhouette_fit':proof,'native_exposure_targets':targets.tolist()if index>0 and targets is not None else []})
    source['parts']=records;source['native_occupied_alpha_sha256']=hashlib.sha256(image.tobytes()).hexdigest();source['native_silhouette_guard_pixels']=2
    source['inference']+=' Only the source-profile X/Z controls receive bounded<=8pixel silhouette corrections with physicalY unchanged. Existing whole raw crag/ledge parts receive rigid/uniform fitting to original occupied alpha (including original opaque upper occlusion), never vertex flattening, footprint clipping or camera-specific discard. The2pixel inside guard absorbs authoring voxel error; original thin visible artwork is audited separately. This is source-facing shape correction, not quality/placement-count reduction.'
    (OUT/'source-geometry.json').write_text(json.dumps(source,separators=(',',':')));(OUT/'observed-native.png').write_bytes((BASE/'Fused Angular14/observed-native.png').read_bytes())
    print('EAST_FUSED_NATIVE_FIT',len(records),'parts','matrix',records[0]['native_silhouette_fit'],'alpha_unfitted',sum(row['native_silhouette_fit'].get('tested_inside_fraction',1.)<.999 for row in records),'individual_assignments_pending',sum(row['native_silhouette_fit'].get('individual_feature_assignment_unresolved',False)for row in records))


if __name__=='__main__':prepare()
