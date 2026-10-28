"""Derive menu/splash textures from the exact user-selected logo; keep original intact."""
from pathlib import Path
from PIL import Image, ImageDraw
root=Path(__file__).resolve().parent.parent/'assets/branding'
original=Image.open(root/'logo-choice-next.png').convert('RGBA')
logo=original.crop((60,220,original.width-60,985))
for point in [(0,0),(logo.width-1,0),(0,logo.height-1),(logo.width-1,logo.height-1)]:
 ImageDraw.floodfill(logo,point,(0,0,0,0),thresh=35)
logo.save(root/'logo.png',optimize=True)
splash=Image.new('RGBA',(1280,720),(6,8,8,255))
copy=logo.copy();copy.thumbnail((1040,650),Image.Resampling.LANCZOS)
splash.alpha_composite(copy,((1280-copy.width)//2,(720-copy.height)//2))
splash.convert('RGB').save(root/'splash.png',optimize=True)
