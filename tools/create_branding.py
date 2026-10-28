"""Reproducible working hatch emblem and splash. Requires Pillow, not a stock engine logo."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parent.parent
out=ROOT/'assets/branding';out.mkdir(parents=True,exist_ok=True)
im=Image.new('RGB',(1280,720),'#101d25');d=ImageDraw.Draw(im)
cx,cy=640,255
for r,color,width in [(142,'#293f48',12),(122,'#6b8589',5),(106,'#bf9455',3)]:
 d.ellipse((cx-r,cy-r,cx+r,cy+r),outline=color,width=width)
d.rounded_rectangle((cx-69,cy-91,cx+69,cy+95),radius=20,fill='#243a43',outline='#789293',width=4)
d.rectangle((cx+37,cy-74,cx+47,cy+78),fill='#efb65d')
d.ellipse((cx-28,cy-28,cx+28,cy+28),outline='#a1b5b1',width=6)
for a,b in [((cx-47,cy),(cx+47,cy)),((cx,cy-47),(cx,cy+47))]:d.line((a,b),fill='#a1b5b1',width=7)
font='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
for text,y,size,color in [('Б У Н К Е Р',440,76,'#e0e9e2'),('ПОСЛЕДНИЙ ШЛЮЗ',544,25,'#d6ac70')]:
 f=ImageFont.truetype(font,size);box=d.textbbox((0,0),text,font=f);d.text(((1280-(box[2]-box[0]))/2,y),text,font=f,fill=color)
im.save(out/'splash.png',optimize=True)
# Menu texture uses a tight crop of the same identity, not another logo variation.
im.crop((300,90,980,600)).save(out/'logo.png',optimize=True)
(out/'icon.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"><rect width="256" height="256" rx="48" fill="#101d25"/><circle cx="128" cy="128" r="91" fill="#243a43" stroke="#789293" stroke-width="10"/><rect x="163" y="65" width="10" height="126" fill="#efb65d"/><circle cx="116" cy="128" r="25" fill="none" stroke="#d5dfd7" stroke-width="8"/><path d="M76 128h80m-40-40v80" stroke="#d5dfd7" stroke-width="8"/></svg>''')
