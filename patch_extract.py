import numpy as np
import openslide
import sys
import os
from PIL import Image
from xml.dom import minidom
import pandas as pd
from skimage import draw
import numpy as np
import PIL.ImageDraw as ImageDraw
import matplotlib.pyplot as plt

class patch_extract:

    def __init__(self):
        self.data_location = 'M:/Stephanie Harmon/TIL/example'
        self.save_location = 'M:/Stephanie Harmon/TIL/example_out'
        self.boxSz = 100
        self.pullSize = 5000 #lets pull 5000x5000 patches at mag=20 to get 2500 TIL patches per batch
        self.power = 20 #magnification expected

    def organize_data(self):
        slide_list = os.listdir(self.data_location)

        for slide in slide_list:
            slide_name = slide.split('.')[0]
            self.read_bigimage(slide_name=slide_name,slide_id=slide)


    def read_bigimage(self,slide_name,slide_id):
        oslide = openslide.OpenSlide(os.path.join(self.data_location,slide_id))
        mag = int(oslide.properties[openslide.PROPERTY_NAME_OBJECTIVE_POWER])
        resizefactor=mag/self.power
        width = oslide.dimensions[0];
        height = oslide.dimensions[1];
        shape = (int(self.pullSize*resizefactor),int(self.pullSize*resizefactor))
        num_subs_updown = int(np.floor(width/shape[0])) + 1;
        num_subs_leftright = int(np.floor(height/shape[1])) + 1;
        print(num_subs_updown)
        print(num_subs_leftright)
        #send to patches at varying levels
        fname = os.path.join(self.save_location,slide_name);
        os.mkdir(os.path.join(fname))
        print(fname)

        batch = 1
        for x in range(0,num_subs_leftright-1):
            for y in range(0,num_subs_updown-1):
                #note you could add a whitespace constraint here if you wanted
                patch = oslide.read_region((int(self.pullSize*x), int(self.pullSize*y)), 0, shape);
                batch_id = slide_name+'_batch'+str(batch)+'-'+str(self.pullSize*x)+'-'+str(self.pullSize*y)
                os.mkdir(os.path.join(fname, 'batch'+str(batch)))
                self.sub_patch(patch=patch,batch=batch,batch_id = batch_id,resizefactor=resizefactor,fname=fname)
                batch+=1

        #patch.save(fname);


    def sub_patch(self,patch,batch,batch_id,resizefactor,fname):
        patchnum = 1

        x_fit = int(patch._size[0]/(self.boxSz*resizefactor))
        y_fit = int(patch._size[1]/(self.boxSz*resizefactor))

        for x in range(0,x_fit):
            for y in range(0,y_fit):
                subpatch = patch.crop(box=(self.boxSz*resizefactor*x,self.boxSz*resizefactor*y,self.boxSz*resizefactor*(x+1),self.boxSz*resizefactor*(y+1)))
                subpatch_name = batch_id + "_sub" + str(patchnum) + ".png"
                patch_out = subpatch.resize(size=(self.boxSz,self.boxSz), resample=Image.ANTIALIAS)
                ws_out = self.whitespace_check(im=patch_out)
                if ws_out < 0.9:
                    patch_out.save(os.path.join(fname, 'batch'+str(batch), subpatch_name))
                patchnum += 1

    def whitespace_check(self,im):
        bw = im.convert('L')
        bw = np.array(bw)
        bw = bw.astype('float')
        bw=bw/255
        prop_ws = (bw > 0.8).sum()/(bw>0).sum()
        return prop_ws


if __name__ == '__main__':
    c = patch_extract()
    c.organize_data()
    #c.read_tmaimage()