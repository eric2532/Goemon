"""Apply the requested game palette to vertex colours; preserve source recovery.

PS1 display RGB was initially carried directly into glTF linear vertex colour,
which lifts the entire vertex palette toward pastel when displayed. Match the
reference's golden skin, clean whites, rich indigo, bright red and yellow gold.
Geometry, rig weights, texture pixels, and animation buffers remain unchanged.
"""
from pathlib import Path
import argparse,json,struct,hashlib

HAIR_PARTS={0,1,2,3,13,14,15,16,17}

def linear(value):
    return value/12.92 if value<=.04045 else ((value+.055)/1.055)**2.4

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    original=args.source.read_bytes();size=struct.unpack_from('<I',original,12)[0]
    doc=json.loads(original[20:20+size]);binary=bytearray(original[28+size:])
    parts={node['mesh']:node['extras']['source_part_index'] for node in doc['nodes']
           if 'mesh' in node and 'source_part_index' in node.get('extras',{})}
    edits={'navy_hair_and_brows':0,'bright_red':0,'golden_skin':0,
           'clean_white':0,'gold':0,'silver':0,'other_corrected_colours':0};visited=set()
    for mesh_index,mesh in enumerate(doc['meshes']):
        part=parts[mesh_index]
        for primitive in mesh['primitives']:
            material=doc['materials'][primitive['material']]
            if 'baseColorTexture' in material.get('pbrMetallicRoughness',{}):continue
            accessor=doc['accessors'][primitive['attributes']['COLOR_0']]
            view=doc['bufferViews'][accessor['bufferView']]
            n=int(accessor['type'][-1]);kind=accessor['componentType']
            assert kind in (5126,5121,5123)
            width,format_code,maximum={5126:(4,'f',1),5121:(1,'B',255),5123:(2,'H',65535)}[kind]
            fmt='<'+format_code*n
            start=view.get('byteOffset',0)+accessor.get('byteOffset',0)
            stride=view.get('byteStride',width*n)
            for vertex in range(accessor['count']):
                offset=start+stride*vertex
                if offset in visited:continue
                visited.add(offset)
                values=list(struct.unpack_from(fmt,binary,offset))
                rgb=[v/maximum for v in values[:3]]
                r,g,b=rgb;target=rgb
                if part in HAIR_PARTS and b>r*1.25 and b>g*1.25 and r<.45:
                    target=[37/255,39/255,91/255]
                    edits['navy_hair_and_brows']+=1
                elif r>g*2 and r>b*2 and r>.35:
                    target=[min(1,.92+.1*r),.10+.25*g,.13+.22*b]
                    edits['bright_red']+=1
                elif r>.97 and .70<g<.86 and .44<b<.56:
                    # Same warm display RGB as the original facial texture's
                    # skin colour, avoiding pale ears/hands against the face.
                    target=[1.0,198/255,123/255]
                    edits['golden_skin']+=1
                elif max(rgb)-min(rgb)<.025 and r>.65:
                    target=[min(1,r*1.15+.04),min(1,g*1.15+.035),min(1,b*1.15+.03)]
                    edits['clean_white']+=1
                elif r>.8 and g>.65 and b<.44:
                    target=[min(1,r+.06),min(1,g+.055),max(0,b-.08)]
                    edits['gold']+=1
                elif part in {21,22,23,24,25} and abs(r-g)<.025 and b>r+.13 and r>.45:
                    target=[min(1,r+.13),min(1,g+.16),min(1,b+.10)]
                    edits['silver']+=1
                else:
                    edits['other_corrected_colours']+=1
                values[:3]=[linear(v) for v in target]
                if width!=4:values[:3]=[round(v*maximum) for v in values[:3]]
                struct.pack_into(fmt,binary,offset,*values)
    assert edits['navy_hair_and_brows']>100 and edits['bright_red']>100,edits
    assert edits['golden_skin']>100 and edits['clean_white']>100,edits
    doc['asset'].setdefault('extras',{})['game_palette']='Full corrected display palette: golden skin matching the facial atlas (#FFC67B), navy-indigo hair/brows (#25275B), bright red, clean whites, yellow gold and cool silver. All untextured vertex RGB encoded in linear space. Original source recovery preserved separately.'
    encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
    output=struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))
    output+=struct.pack('<II',len(encoded),0x4e4f534a)+encoded
    output+=struct.pack('<II',len(binary),0x004e4942)+binary
    args.output.write_bytes(output)
    report={'source_sha256':hashlib.sha256(original).hexdigest(),
            'game_asset_sha256':hashlib.sha256(output).hexdigest(),'edited_vertices':edits,
            'preserved_animations':len(doc['animations']),'hair_display_hex':'#25275B',
            'skin_display_hex':'#FFC67B','all_untextured_vertex_colours_corrected':True}
    if args.report:args.report.write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
