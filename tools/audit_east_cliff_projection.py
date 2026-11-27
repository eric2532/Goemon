"""Read-only native-angle silhouette audit; never certifies inferred3D visuals."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from east_cliff_geometry import raster


def audit(folder):
    metadata=json.loads((folder/'source-geometry.json').read_text());geometry=np.load(folder/'geometry.npz');triangles=geometry['triangles'];normals=geometry['normals'];original=Image.open(folder/'12538-native-untouched.png').convert('RGBA');visible=Image.open(folder/'observed-native.png').convert('RGBA')
    padding=64;size=(original.width+padding*2,original.height+padding*2);canvas=Image.new('RGBA',size);g=dict(metadata['graphic']);g['origin']=[g['origin'][0]-padding,g['origin'][1]-padding];ph=metadata['pixel_height'];eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye)
    white=np.full_like(triangles,255.);rendered=raster(triangles,normals,None,canvas,eye,g,ph,source=True,palette=white,unlit=True);pixels=np.asarray(rendered)[::2,::2];actual=np.any(pixels!=[38,47,55],axis=2)
    expected=np.zeros(actual.shape,bool);paint=np.zeros_like(expected);expected[padding:padding+original.height,padding:padding+original.width]=np.asarray(original)[:,:,3]>=128;paint[padding:padding+visible.height,padding:padding+visible.width]=np.asarray(visible)[:,:,3]>=128
    extra=actual&~expected;missing=paint&~actual;occluded=actual&expected&~paint
    image=np.zeros((*actual.shape,3),np.uint8);image[:]=[38,47,55];image[actual]=[160,173,146];image[extra]=[224,78,67];image[missing]=[63,138,228];image[occluded]=[205,166,72]
    Image.fromarray(image).resize((size[0]*2,size[1]*2),Image.Resampling.NEAREST).save(folder/'source-silhouette-audit.png')
    report={'status':'AUDIT_ONLY_NO_VISUAL_ACCEPTANCE','native_rgba_sha256':hashlib.sha256(original.tobytes()).hexdigest(),'geometry_npz_sha256':hashlib.sha256((folder/'geometry.npz').read_bytes()).hexdigest(),'source_visible_pixels':int(paint.sum()),'source_occupied_including_black_occlusion_pixels':int(expected.sum()),'candidate_projected_pixels':int(actual.sum()),'unrecorded_outside_original_alpha_pixels':int(extra.sum()),'missing_visible_native_pixels':int(missing.sum()),'inferred_geometry_over_original_occlusion_pixels':int(occluded.sum()),'observed_paint_coverage':float((paint&actual).sum()/max(1,paint.sum())),'unrecorded_extra_fraction_of_native':float(extra.sum()/max(1,expected.sum())),'padding_pixels':padding,'mask_legend':{'red':'Geometry beyond the original occupied alpha silhouette: unresolved source-facing shape work.','blue':'Original visible art absent from geometry: may require verified thin source fringe, not invented mass.','gold':'Geometry over original opaque occlusion mask: inferred upper/hidden body, not measured native rock.','grey':'Candidate geometry over measured original visible art.'},'scope':'Original native-angle shape audit from the private candidate. Full map placement, foot/walk/nav/portals are separate. Native alpha/paint coverage does not prove correct hidden forms, source3D, shaded art or gameplay performance.'}
    (folder/'source-silhouette-audit.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items()if k.endswith('pixels')or k in['observed_paint_coverage','unrecorded_extra_fraction_of_native']}))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('folder',type=Path);args=parser.parse_args();audit(args.folder)
