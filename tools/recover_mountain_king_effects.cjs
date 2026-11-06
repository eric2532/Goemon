// Bake original MDX effects offline with the already installed Warcraft renderer.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),assert=require('assert');
const root=path.resolve(__dirname,'..'),wc=path.resolve(root,'../Warcraft');
const {parseMDX,ModelRenderer}=require(path.join(wc,'work/tools/package/dist/war3-model.cjs'));
const original=path.join(wc,'assets/MountainKing/original'),out=path.join(root,'assets/characters/warcraft/mountain-king/effects');
const staging=path.join(root,'build/Other Files/Asset Toolkit/Mountain King');
fs.mkdirSync(out,{recursive:true});
const files={bolt:'Abilities/Spells/Human/StormBolt/StormBoltMissile.mdx',clap:'Abilities/Spells/Human/Thunderclap/ThunderclapCaster.mdx',avatar:'Abilities/Spells/Human/Avatar/AvatarCaster.mdx',stun:'Abilities/Spells/Human/StormBolt/StormBoltTarget.mdx',bash:'Abilities/Spells/Human/Thunderclap/ThunderclapTarget.mdx',slow:'Abilities/Spells/Orc/StasisTrap/StasisTotemTarget.mdx',body:'Units/Human/HeroMountainKing/HeroMountainKing.mdx'};
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const catalog={sources:{},effects:{}};
let seed=33;Math.random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
const plain=v=>JSON.parse(JSON.stringify(v,(_,x)=>ArrayBuffer.isView(x)?Array.from(x):x));
const point=(m,x,y,z)=>[m[0]*x+m[4]*y+m[8]*z+m[12],m[1]*x+m[5]*y+m[9]*z+m[13],m[2]*x+m[6]*y+m[10]*z+m[14]];
for(const [key,file] of Object.entries(files)){
 const bytes=fs.readFileSync(path.join(original,file)),m=parseMDX(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength));
 catalog.sources[file]=hash(bytes);
 const textures=m.Textures.map(t=>{
  const source=t.Image?t.Image.replaceAll('\\','/').replace(/\.blp$/i,'.png'):`ReplaceableTextures/${t.ReplaceableId===1?'TeamColor':'TeamGlow'}/${t.ReplaceableId===1?'TeamColor':'TeamGlow'}00.png`;
  const b=fs.readFileSync(path.join(original,source)),name=hash(b).slice(0,12)+'-'+path.basename(source);
  fs.writeFileSync(path.join(out,name),b);catalog.sources[source]=hash(b);return name;
 });
 // Some original global tracks have a zero period; their value is the first key.
 m.GlobalSequences=m.GlobalSequences.map(v=>v||1);
 const spec={textures,clips:{}};
 for(let si=0;si<m.Sequences.length;si++){
  const seq=m.Sequences[si];if(seq.Interval[1]<seq.Interval[0])continue;
  if(key==='body'&&!/Slam|Morph/.test(seq.Name))continue;
  const r=new ModelRenderer(m);r.setSequence(si);
  const duration=(seq.Interval[1]-seq.Interval[0])/1000,frames=[];
  for(let fi=0;fi<=Math.ceil(duration*30);fi++){
   r.rendererData.frame=Math.min(seq.Interval[1],seq.Interval[0]+fi*1000/30);
   r.updateGlobalSequences(fi?1000/30:0);r.updateNode(r.rendererData.rootNode);r.particlesController.update(fi?1000/30:0);
   const surfaces=[];
   if(key!=='body')for(let gi=0;gi<m.Geosets.length;gi++){
    const g=m.Geosets[gi],ga=m.GeosetAnims.find(a=>a.GeosetId===gi),color=ga?.Color||[1,1,1];
    const vertices=[];
    for(let vi=0;vi<g.Vertices.length/3;vi++){
     const group=g.Groups[g.VertexGroup[vi]],p=[0,0,0];
     for(const bone of group){const q=point(r.rendererData.nodes[bone].matrix,...g.Vertices.slice(vi*3,vi*3+3));for(let j=0;j<3;j++)p[j]+=q[j]/group.length;}
     vertices.push(...p);
    }
    for(const layer of m.Materials[g.MaterialID].Layers){
     const alpha=r.findAlpha(gi)*r.interp.animVectorVal(layer.Alpha,1);
     if(alpha<=.001)continue;
     const ti=typeof layer.TextureID==='number'?layer.TextureID:r.interp.num(layer.TextureID);
     surfaces.push({vertices,uv:Array.from(g.TVertices[0]),indices:Array.from(g.Faces),color:[...color,alpha],texture:textures[ti],mode:layer.FilterMode});
    }
   }
   for(const e of r.particlesController.emitters)for(const part of ['head','tail']){
    const n=e.particles.length,v=e[part+'Vertices'],uv=e[part+'TexCoords'];if(!n||!v)continue;
    surfaces.push({vertices:Array.from(v.slice(0,n*12)),uv:Array.from(uv.slice(0,n*8)),indices:Array.from(e.indices.slice(0,n*6)),colors:Array.from(e.colors.slice(0,n*16)),texture:textures[e.props.TextureID],mode:[2,3,5,4,1][e.props.FilterMode]??3});
   }
   assert(surfaces.every(s=>s.vertices.every(Number.isFinite)),`${key}/${seq.Name}/${fi}`);
   frames.push(surfaces);
  }
  spec.clips[seq.Name]={duration,frames};
 }
 fs.writeFileSync(path.join(staging,key+'-frames.json'),JSON.stringify(spec));
 catalog.effects[key]={file,clips:Object.fromEntries(Object.entries(spec.clips).map(([n,c])=>[n,{duration:c.duration,frames:c.frames.length}]))};
 console.log(key,Object.keys(spec.clips),fs.statSync(path.join(staging,key+'-frames.json')).size);
}
fs.writeFileSync(path.join(out,'sources.json'),JSON.stringify(catalog,null,2)+'\n');
assert(Object.keys(catalog.effects).length===7);
