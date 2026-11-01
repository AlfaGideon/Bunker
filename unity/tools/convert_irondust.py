#!/usr/bin/env python3
"""Convert the author's legacy ASCII FBX 6.1 meshes to individual OBJ files.

FBX 6.1 is unsupported by current Assimp and some Unity versions. This limited
converter deliberately validates the layout it handles; it is not a general
FBX importer. Positions are local to each object, with Blender Z up converted
to Y up. Source normals and per-polygon-vertex atlas UVs are retained.
"""
import argparse
import re
from pathlib import Path

HEADER = re.compile(r'^\s*Model: "Model::([^"\n]+)", "Mesh" \{\s*$', re.M)

def array(block, name, typ):
    m = re.search(r'^\s*' + name + r':\s*([\d.,eE+\-\s]+)', block, re.M)
    if not m:
        raise ValueError('missing ' + name)
    return [typ(x) for x in m.group(1).replace('\n', '').split(',') if x.strip()]

def convert(source, destination):
    text = source.read_text(encoding='utf-8')
    if 'FBXVersion: 6100' not in text:
        raise ValueError('expected FBX 6.1')
    headers = list(HEADER.finditer(text))
    destination.mkdir(parents=True, exist_ok=True)
    names = set()
    for i, header in enumerate(headers):
        name = header.group(1)
        # Definitions in the Takes section repeat model names but have no geometry.
        block = text[header.end():headers[i+1].start() if i+1 < len(headers) else len(text)]
        if not re.search(r'^\s*Vertices:', block, re.M):
            continue
        if name in names or not re.fullmatch(r'[A-Za-z0-9_]+', name):
            raise ValueError('duplicate or unsafe name: ' + name)
        names.add(name)
        verts = array(block, 'Vertices', float)
        polys = array(block, 'PolygonVertexIndex', int)
        uv = array(block, 'UV', float)
        uv_idx = array(block, 'UVIndex', int)
        normals = array(block, 'Normals', float)
        if len(verts)%3 or len(uv)%2 or len(normals)!=len(polys)*3 or len(uv_idx)!=len(polys):
            raise ValueError('unsupported FBX geometry layout: ' + name)
        if any(u < 0 or u >= len(uv)//2 for u in uv_idx):
            raise ValueError('invalid UV index in '+name)
        out = ['# Irondust CC0, converted from FBX 6.1; local coordinates, Y up', 'o '+name]
        for j in range(0,len(verts),3):
            x,y,z = verts[j:j+3]; out.append(f'v {x:g} {z:g} {-y:g}')
        for j in range(0,len(uv),2):
            out.append(f'vt {uv[j]:g} {uv[j+1]:g}')
        for j in range(0,len(normals),3):
            x,y,z = normals[j:j+3]; out.append(f'vn {x:g} {z:g} {-y:g}')
        face=[]
        for j,v in enumerate(polys):
            last=v<0; vi=(-v-1 if last else v)
            if vi < 0 or vi >= len(verts)//3: raise ValueError('invalid vertex index: '+name)
            face.append(f'{vi+1}/{uv_idx[j]+1}/{j+1}')
            if last:
                if len(face)<3: raise ValueError('invalid polygon: '+name)
                out.append('f '+' '.join(face)); face=[]
        if face: raise ValueError('unterminated polygon: '+name)
        (destination/(name+'.obj')).write_text('\n'.join(out)+'\n',encoding='utf-8')
        print(name, len(verts)//3, 'vertices', sum(1 for p in polys if p<0), 'polygons')
    if len(names)!=23:
        raise ValueError(f'expected 23 meshes, found {len(names)}')

if __name__ == '__main__':
    p=argparse.ArgumentParser(); p.add_argument('source',type=Path); p.add_argument('destination',type=Path)
    args=p.parse_args(); convert(args.source,args.destination)
