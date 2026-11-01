# Unity environment asset research

The replacement environment is not yet implemented. Do not treat these candidates as approved visuals or mobile-ready assets.

## Irondust: Sci-fi environment pack

- Source and CC0 declaration: https://opengameart.org/content/sci-fi-environment-pack
- Archive URL: https://opengameart.org/sites/default/files/Sci-fi%20env2.zip
- Archive SHA-256 (downloaded and inspected in CI): `d756531f835afca5ee0d4767b92b1017ebcefb1dc2539a957744ad045d9d329f`
- Inventory: `Meshes.fbx`, `Ramps.fbx`, `Meshes.blend` and albedo, normal, specular, emission and other maps in several colour schemes. Some uncompressed TGA maps are 64 MiB each; these need resizing/compression and profiling for Android, rather than blindly shipping the archive.
- Original ASCII FBX 6.1 was rejected by Assimp; 23 objects have been converted to OBJ with UVs and normals. Imported successfully in Unity 2022.3 and rendered in CI ([run](https://github.com/AlfaGideon/Bunker/actions/runs/41307248305)). The test render is only an asset audit, not a level. Most geometry is extremely simple (many walls are just 8 vertices); detail primarily comes from the atlas. This is not sufficient by itself for the requested detailed bunker. Normal/specular quality, seams and runtime performance on Android remain unverified.
- Inventory audit: https://github.com/AlfaGideon/Bunker/actions/runs/41306258664
