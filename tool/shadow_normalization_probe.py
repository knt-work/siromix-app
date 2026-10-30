"""Offline experiment only; does not modify app code or original fixtures."""
from pathlib import Path
from PIL import Image, ImageFilter
import numpy as np
r=Path(__file__).resolve().parents[1]
for part in ['candidate','code','answers']:
    image=Image.open(r/f'test/fixtures/shadow-{part}.png').convert('L')
    small=image.copy(); small.thumbnail((500,500))
    illumination=small.filter(ImageFilter.MaxFilter(31)).filter(ImageFilter.GaussianBlur(3))
    illumination=illumination.resize(image.size,Image.Resampling.BILINEAR)
    raw=np.asarray(image,dtype=np.float32); bg=np.asarray(illumination,dtype=np.float32)
    corrected=np.minimum(255,raw*240/np.maximum(bg,20)).astype(np.uint8)
    Image.fromarray(corrected).save(r/f'build/shadow-normalized-{part}.png')
    print(part, 'paper illumination percentiles',np.percentile(bg,[5,50,95]).round().tolist())
