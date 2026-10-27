"""Original finale TMD vertex morphs (shared engine funcs 80132288/801325B8)."""
import struct
GROUPS = {
 'wind':[0x801AFF44+i*12 for i in range(9)],
 'wind_outer':[0x801AFFB0+i*12 for i in range(9)],
 'sword':[0x801AFB98],
 'core':[0x801AFA70+i*12 for i in range(4)]+[0x801AFAAC],
 'core_open':[0x801AFAA0],
}
def add_morphs(glb, metadata, data, base):
    def read(address,fmt):
        assert base<=address<=base+len(data)-struct.calcsize(fmt)
        return struct.unpack_from(fmt,data,address-base)
    def vertices(address):
        flags=read(address+4,'<I')[0];assert flags==0
        offset,count=read(address+12,'<2I')
        return [read(address+12+offset+i*8,'<4h')[:3] for i in range(count)]
    def convert(v):return [v[0],-v[1],-v[2]]
    metadata['morphs']={}
    for part in metadata['parts']:
        group=part['group']
        if group not in GROUPS:continue
        original=vertices(int(part['source_address'],16));lookup={tuple(convert(v)):i for i,v in enumerate(original)}
        assert len(lookup)==len(original),'Ambiguous source vertex identity'
        states=[];names=[]
        for descriptor in GROUPS[group]:
            mesh,delta,normals=read(descriptor,'<3I');assert normals==0
            start=vertices(mesh);assert len(start)==len(original)
            _,_,first,count=read(delta,'<4I');assert first+count<=len(start)
            end=list(start)
            for i in range(count):
                offset=read(delta+16+i*8,'<4h')[:3]
                end[first+i]=tuple(start[first+i][k]+offset[k] for k in range(3))
            states.extend([start,end]);names.extend([f'Morph_{descriptor:08x}_start',f'Morph_{descriptor:08x}_end'])
        mesh=glb.doc['meshes'][glb.doc['nodes'][part['node']]['mesh']]
        mesh['extras']={'targetNames':names};mesh['weights']=[0]*len(names)
        for primitive in mesh['primitives']:
            points=glb.accessor(primitive['attributes']['POSITION']);ids=[lookup[tuple(p)] for p in points]
            primitive['targets']=[]
            for state in states:
                deltas=[tuple(convert(state[index])[k]-point[k] for k in range(3)) for point,index in zip(points,ids)]
                accessor=glb.append_accessor(deltas,dict(type='VEC3',componentType=5126))
                primitive['targets'].append({'POSITION':accessor})
        metadata['morphs'][group]={'descriptors':[hex(d) for d in GROUPS[group]],'names':names,'vertex_count':len(original)}
