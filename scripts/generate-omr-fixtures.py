from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np
import sys

root=Path(sys.argv[1]);out=root/'test/fixtures';out.mkdir(parents=True,exist_ok=True)
im=Image.open(root/'assets/templates/abcd-10-v1.png').convert('RGB')
d=ImageDraw.Draw(im)
def dot(x,y):
    d.ellipse((round(x)-8,round(y)-8,round(x)+8,round(y)+8),fill=(20,20,20))
for i,a in enumerate('ABCDABCDAB'):dot(211+33*'ABCD'.index(a),610+33.1*i)
for i,a in enumerate('001286'):dot(740+33*i,179.5+33.15*int(a))
for i,a in enumerate('132'):dot(1005+33*i,179.5+33.15*int(a))
im.save(out/'ten-132-clean.png')
# Independent projective transform of the entire printed and filled sheet.
src=[(0,0),(1271,0),(1271,1799),(0,1799)]
dst=[(85,65),(1190,20),(1235,1730),(30,1780)]
rows=[];values=[]
for (x,y),(u,v) in zip(dst,src):
    rows.extend([[x,y,1,0,0,0,-u*x,-u*y],[0,0,0,x,y,1,-v*x,-v*y]])
    values.extend([u,v])
coeffs=np.linalg.solve(np.array(rows,dtype=float),np.array(values,dtype=float))
warped=im.transform(im.size,Image.Transform.PERSPECTIVE,coeffs,Image.Resampling.BICUBIC,fillcolor='white')
warped.save(out/'ten-132-perspective.jpg',quality=88)
