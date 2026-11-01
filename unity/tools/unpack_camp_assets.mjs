import {NodeIO} from '@gltf-transform/core';import {ALL_EXTENSIONS} from '@gltf-transform/extensions';import {MeshoptDecoder} from 'meshoptimizer';import sharp from 'sharp';
await MeshoptDecoder.ready;let io=new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({'meshopt.decoder':MeshoptDecoder});
let doc=await io.read(process.argv[2]);
for(let tex of doc.getRoot().listTextures())if(tex.getMimeType()==='image/webp'){
  let rgba=tex.getName().includes('rgba');
  let pipeline=sharp(tex.getImage()).resize(512,512,{fit:'inside',withoutEnlargement:true});
  tex.setImage(await (rgba?pipeline.png({compressionLevel:9}):pipeline.jpeg({quality:85})).toBuffer());
  tex.setMimeType(rgba?'image/png':'image/jpeg');
}
for(let ext of [...doc.getRoot().listExtensionsUsed()])if(['EXT_meshopt_compression','EXT_texture_webp'].includes(ext.extensionName))ext.dispose();
await io.write(process.argv[3],doc);
