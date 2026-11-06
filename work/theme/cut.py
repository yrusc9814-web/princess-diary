import sys, numpy as np
from PIL import Image
from scipy import ndimage
def cut(src, dst, T=14, soft=30, scale=1):
    im=np.asarray(Image.open(src).convert('RGB')).astype(float)
    h,w,_=im.shape
    border=np.concatenate([im[0],im[-1],im[:,0],im[:,-1]])
    bg=np.median(border,axis=0)
    # per-pixel bg estimate: blend along y between top and bottom rows median
    top=np.median(im[:3].reshape(-1,3),0); bot=np.median(im[-3:].reshape(-1,3),0)
    t=np.linspace(0,1,h)[:,None,None]
    bgimg=top*(1-t)+bot*t
    d=np.sqrt(((im-bgimg)**2).sum(-1))
    cand=d<T
    lab,n=ndimage.label(cand)
    edge=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
    sizes=ndimage.sum(cand,lab,range(1,n+1))
    big={i+1 for i,v in enumerate(sizes) if v>1500}
    bgmask=np.isin(lab,list(edge|big))
    # soft alpha: distance-based near bg region
    alpha=np.clip((d-T*0.5)/soft,0,1)
    near=ndimage.binary_dilation(bgmask,iterations=3)
    a=np.where(bgmask,0,np.where(near,np.maximum(alpha,0),1.0))
    # unpremultiply-ish: recover color against bg for semi-transparent pixels
    aa=np.clip(a,1e-3,1)[...,None]
    col=np.clip((im-bgimg*(1-aa))/aa,0,255)
    col=np.where(a[...,None]>0.99,im,col)
    out=np.dstack([col,a*255]).astype(np.uint8)
    o=Image.fromarray(out,'RGBA')
    bb=o.getbbox(); o=o.crop(bb)
    if scale!=1: o=o.resize((int(o.width*scale),int(o.height*scale)),Image.LANCZOS)
    o.save(dst); print(dst,o.size,bg)
cut(sys.argv[1],sys.argv[2],float(sys.argv[3]) if len(sys.argv)>3 else 14)
