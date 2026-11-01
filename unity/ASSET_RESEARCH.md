# Unity environment asset research

The replacement environment is not yet implemented. Do not treat these candidates as approved visuals or mobile-ready assets.

## Irondust: Sci-fi environment pack

- Source and CC0 declaration: https://opengameart.org/content/sci-fi-environment-pack
- Archive URL: https://opengameart.org/sites/default/files/Sci-fi%20env2.zip
- Archive SHA-256 (downloaded and inspected in CI): `d756531f835afca5ee0d4767b92b1017ebcefb1dc2539a957744ad045d9d329f`
- Inventory: `Meshes.fbx`, `Ramps.fbx`, `Meshes.blend` and albedo, normal, specular, emission and other maps in several colour schemes. Some uncompressed TGA maps are 64 MiB each; these need resizing/compression and profiling for Android, rather than blindly shipping the archive.
- Original ASCII FBX 6.1 was rejected by Assimp; 23 objects have been converted to OBJ with UVs and normals. Imported successfully in Unity 2022.3 and rendered in CI ([run](https://github.com/AlfaGideon/Bunker/actions/runs/41307248305)). The test render is only an asset audit, not a level. Most geometry is extremely simple (many walls are just 8 vertices); detail primarily comes from the atlas. This is not sufficient by itself for the requested detailed bunker. Normal/specular quality, seams and runtime performance on Android remain unverified.
- Inventory audit: https://github.com/AlfaGideon/Bunker/actions/runs/41306258664

## Experimental 3D match view

The separate Unity prototype now has an opt-in 3D view linked to its match state,
with local-only movement and character selection returning to the existing card
UI. It uses the Irondust test environment and one repeated MakeHuman candidate;
it is not the requested final art or a full game. Movement is not synchronized
between clients, participants are not seated, and there is no room/exit system.
The prototype APK is debug-signed with a separate package ID and cannot update
the production Godot APK. It is not a release candidate. Physical Android input,
performance, clipping, audio, and network gameplay need device testing.

The 2026-11-01 Unity CI run 41311532725 instantiated the world with two test
participants, checked collisions and clip binding, rendered a frame and built a
debug APK. The first render showed an unsampled T-pose on the second participant
in the editor-only capture; runtime idle sampling and the capture were adjusted
subsequently and must be rechecked. Further provenance review remains necessary
before distributing the model in a release.

## Camp candidate audit (not enabled in the menu)

Unity run 41314941427 rendered the camp candidate. The result is not acceptable
for the requested final menu: the horizon is bare, foliage colours are wrong,
the fire is a simple prop, and the procedural sitting pose needs correction.
`CampWorld` is deliberately not wired into the menu. It also does not implement
the loading transition, profile or final radio. Do not present it as finished.
The Poly Haven-derived tree and rock still need a device performance check.

Run 41314000064 rendered the experimental match world and verified physical
interaction targets, table height and the state-driven medical door. That is
not proof of touch operation, online sync or the full requested bunker on a
phone. The temporary rectangular exit door is not the requested round airlock
and has no elimination sequence. Medical and corridor geometry are preliminary.
