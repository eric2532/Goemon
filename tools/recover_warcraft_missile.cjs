// Copy the existing recovered Meta missile data without modifying its originals.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const assert = require('assert');
const root = path.resolve(__dirname, '..');
const warcraft = path.resolve(root, '../Warcraft');
const {parseMDX, ModelRenderer} = require(path.join(warcraft, 'work/tools/package/dist/war3-model.cjs'));
const original = path.join(warcraft, 'assets/DemonHunter/original');
const source = 'Abilities/Weapons/DemonHunterMissile/DemonHunterMissile.mdx';
const bytes = fs.readFileSync(path.join(original, source));
const model = parseMDX(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
assert.equal(model.ParticleEmitters2.length, 3);
assert.deepEqual(model.ParticleEmitters2.map(p => p.Name), ['BlizParticle01x02', 'BlizParticle01x01', 'BlizParticle02']);
const out = path.join(root, 'assets/characters/warcraft/demon-hunter/missile');
fs.mkdirSync(out, {recursive: true});
const spec = {source, sha256: crypto.createHash('sha256').update(bytes).digest('hex'), unit: 'Eevm',
    sequences: model.Sequences, emitters: model.ParticleEmitters2, textures: model.Textures, materials: model.Materials};
const geoset = model.Geosets[1], bone = model.Bones.find(b => b.GeosetId === 1);
assert.equal(model.Textures[model.Materials[geoset.MaterialID].Layers[0].TextureID].Image, 'Textures\\EQ_Rock2.blp');
assert.equal(geoset.Vertices.length / 3, 26);
assert.equal(geoset.Faces.length / 3, 24);
const duration = model.GlobalSequences[bone.Rotation.GlobalSeqId];
const renderer = new ModelRenderer(model);
const times = [...new Set([...Array.from({length: 81}, (_, i) => i * duration / 80), ...bone.Rotation.Keys.map(k => k.Frame)])].sort((a,b) => a-b);
const samples = times.map(time => {
    renderer.rendererData.globalSequencesFrames[bone.Rotation.GlobalSeqId] = time;
    return {time, rotation: Array.from(renderer.interp.quat(new Float32Array(4), bone.Rotation))};
});
spec.rock = {geoset, bone, duration, samples};
fs.writeFileSync(path.join(out, 'source.json'), JSON.stringify(spec,
    (key, value) => ArrayBuffer.isView(value) ? Array.from(value) : value, 2) + '\n');
for (const [source, name] of [['ReplaceableTextures/Weather/Clouds8x8.png', 'clouds.png'], ['Textures/Flame4.png', 'flame.png'], ['Textures/EQ_Rock2.png', 'rock.png']]) {
    const bytes = fs.readFileSync(path.join(original, source));
    fs.writeFileSync(path.join(out, name), bytes);
    assert(bytes.equals(fs.readFileSync(path.join(out, name))));
}
console.log('Recovered Meta missile: 24-triangle spinning rock, three native emitters and three unchanged textures.');
