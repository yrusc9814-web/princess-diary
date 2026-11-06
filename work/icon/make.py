from PIL import Image, ImageDraw, ImageFilter
import statistics, os
src=Image.open('src.png').convert('RGB')
# sample bg: tile interior band pixels (inside rim), median
px=[]
for x in range(130,1125,5):
    for y in (100,1115): px.append(src.getpixel((x,y)))
for y in range(130,1100,5):
    for x in (125,1130): px.append(src.getpixel((x,y)))
bg=tuple(int(statistics.median(p[k] for p in px)) for k in range(3))
print('bg', '#%02X%02X%02X'%bg)
BOX=(112,78,1142,1108)
art=src.crop(BOX)  # 1030 square, tile interior w/o rim
art.save('art_crop.png')
N=art.size[0]
def feather_mask(size, radius_frac=0.22, blur_frac=0.04):
    m=Image.new('L',(size*4,size*4),0)
    d=ImageDraw.Draw(m); inset=int(size*4*blur_frac)
    d.rounded_rectangle([inset,inset,size*4-inset,size*4-inset], radius=int(size*4*radius_frac), fill=255)
    m=m.resize((size,size),Image.LANCZOS)
    return m.filter(ImageFilter.GaussianBlur(size*blur_frac/2))
# adaptive foreground master 1080 (=108dp*10)
S=1080; A=800; dy=50  # art 80dp, shifted down 5dp so crown top sits on the 66dp safe circle
fg=Image.new('RGBA',(S,S),(0,0,0,0))
a=art.resize((A,A),Image.LANCZOS).convert('RGBA')
a.putalpha(feather_mask(A))
fg.alpha_composite(a,((S-A)//2,(S-A)//2+dy))
fg.save('fg_master.png')
full=Image.new('RGBA',(S,S),bg+(255,)); full.alpha_composite(fg); full.save('adaptive_full.png')
# legacy master 1024: art with rounded-rect mask, tiny padding
L=1024; pad=int(L*0.03)
leg=Image.new('RGBA',(L,L),(0,0,0,0))
la=art.resize((L-2*pad,L-2*pad),Image.LANCZOS).convert('RGBA')
mm=Image.new('L',((L-2*pad)*4,)*2,0); ImageDraw.Draw(mm).rounded_rectangle([0,0,(L-2*pad)*4-1,(L-2*pad)*4-1],radius=int((L-2*pad)*4*0.2),fill=255)
la.putalpha(mm.resize(la.size,Image.LANCZOS)); leg.alpha_composite(la,(pad,pad)); leg.save('legacy_master.png')
rnd=Image.new('RGBA',(L,L),(0,0,0,0))
ra=art.resize((L-2*pad,L-2*pad),Image.LANCZOS).convert('RGBA')
cm=Image.new('L',((L-2*pad)*4,)*2,0); ImageDraw.Draw(cm).ellipse([0,0,(L-2*pad)*4-1,(L-2*pad)*4-1],fill=255)
ra.putalpha(cm.resize(ra.size,Image.LANCZOS)); rnd.alpha_composite(ra,(pad,pad)); rnd.save('round_master.png')
# preview: square(adaptive full), circle mask(66/72dp visible), rounded mask, plus legacy round, safe-zone overlay
P=360
def mask_full(kind):
    im=full.resize((P,P),Image.LANCZOS)
    # launcher shows center 72dp of 108 -> crop to 2/3
    c=int(P*18/108); im=im.crop((c,c,P-c,P-c)).resize((P,P),Image.LANCZOS)
    m=Image.new('L',(P*4,P*4),0); d=ImageDraw.Draw(m)
    if kind=='circle': d.ellipse([0,0,P*4-1,P*4-1],fill=255)
    elif kind=='round': d.rounded_rectangle([0,0,P*4-1,P*4-1],radius=int(P*4*0.22),fill=255)
    else: d.rectangle([0,0,P*4,P*4],fill=255)
    im=im.copy(); im.putalpha(m.resize((P,P),Image.LANCZOS)); return im
safe=full.resize((P,P),Image.LANCZOS); d=ImageDraw.Draw(safe)
r=P*33/108; d.ellipse([P/2-r,P/2-r,P/2+r,P/2+r],outline=(0,120,255,255),width=2)
r2=P*36/108; d.rectangle([P/2-r2,P/2-r2,P/2+r2,P/2+r2],outline=(0,180,0,255),width=1)
tiles=[mask_full('square'),mask_full('circle'),mask_full('round'),safe,round_ := rnd.resize((P,P),Image.LANCZOS)]
W=Image.new('RGBA',(P*len(tiles)+20*(len(tiles)+1),P+40),(255,255,255,255))
for i,t in enumerate(tiles): W.alpha_composite(t,(20+i*(P+20),20))
W.convert('RGB').save('icon_preview.png')
