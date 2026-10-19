import { NodeIO } from '@gltf-transform/core';
import { simplify, prune, textureCompress } from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';
import sharp from 'sharp';
const [,, src, dst, ratio] = process.argv;
const io = new NodeIO();
const doc = await io.read(src);
await MeshoptSimplifier.ready;
await doc.transform(
  simplify({ simplifier: MeshoptSimplifier, ratio: parseFloat(ratio), error: 0.004, lockBorder: false }),
  textureCompress({ encoder: sharp, resize: [512, 512] }),
  prune());
let t=0; for (const m of doc.getRoot().listMeshes()) for (const p of m.listPrimitives()) t+=p.getIndices().getCount()/3;
await io.write(dst, doc); console.log('tris', t);
