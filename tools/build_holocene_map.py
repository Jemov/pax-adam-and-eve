"""Build an approximate 6 ka environment from public-domain Natural Earth data.

Inputs: NE2_50M_SR_W.zip, land.zip, lakes.zip in --source. Runtime files only
contain derived cartography; source archives and the game's assets stay outside.
"""
import argparse,io,json,struct,zipfile
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFilter
from scipy.ndimage import gaussian_filter

W,H=4096,2048
ROOT=Path(__file__).resolve().parents[1]

def shp_parts(archive):
    with zipfile.ZipFile(archive) as z:
        raw=z.read(next(n for n in z.namelist() if n.endswith('.shp')))
    offset=100
    while offset<len(raw):
        _,words=struct.unpack_from('>ii',raw,offset);data=memoryview(raw)[offset+8:offset+8+words*2];offset+=8+words*2
        if len(data)<44 or struct.unpack_from('<i',data)[0] not in (5,15,25): continue
        parts,points=struct.unpack_from('<ii',data,36)
        starts=np.frombuffer(data,dtype='<i4',count=parts,offset=44).tolist()+[points]
        coords=np.frombuffer(data,dtype='<f8',count=points*2,offset=44+parts*4).reshape(-1,2)
        yield [coords[starts[i]:starts[i+1]] for i in range(parts)]

def xy(points): return [((float(x)+180)*W/360,(90-float(y))*H/180) for x,y in points]
def polygons(archive):
    im=Image.new('L',(W,H));draw=ImageDraw.Draw(im)
    for rings in shp_parts(archive):
        for ring in rings:
            if len(ring)<3:continue
            area=np.sum(ring[:-1,0]*ring[1:,1]-ring[1:,0]*ring[:-1,1])
            draw.polygon(xy(ring),fill=255 if area<0 else 0)
    return np.asarray(im).copy()

def poly_mask(points):
    im=Image.new('L',(W,H));ImageDraw.Draw(im).polygon(xy(points),fill=255);return np.asarray(im).copy()
def area_km2(mask):
    lat=90-(np.arange(H)+.5)*180/H
    weights=(6371**2*np.deg2rad(360/W)*np.deg2rad(180/H)*np.cos(np.deg2rad(lat)))[:,None]
    return float(np.sum(weights*(mask>127)))

def build(source):
    out=ROOT/'assets/maps';out.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(source/'NE2_50M_SR_W.zip') as z:
        with z.open(next(n for n in z.namelist() if n.endswith('.tif'))) as f:
            im=Image.open(f);base=np.asarray(im.convert('RGB').resize((W,H),Image.Resampling.LANCZOS)).astype(np.float32)
    land=polygons(source/'land.zip');lakes=polygons(source/'lakes.zip');land[lakes>127]=0
    lon=(-180+(np.arange(W)+.5)*360/W)[None,:];lat=(90-(np.arange(H)+.5)*180/H)[:,None]
    # Deterministic gentle texture, not invented topographic measurements.
    rng=np.random.default_rng(6000)
    noise=gaussian_filter(rng.normal(size=(H,W)).astype(np.float32),6)
    noise/=max(float(np.std(noise)),.001)
    sahara=poly_mask([(-17,14),(-16,22),(-11,28),(0,30),(10,29),(20,28),(30,25),(35,20),(35,13),(20,11),(0,12)])
    arabia=poly_mask([(36,18),(39,23),(45,26),(52,24),(57,20),(54,16),(46,13),(41,14)])
    wet=np.maximum(sahara/255,arabia/255*.65)
    wet=gaussian_filter(wet,26)*(land>127)
    north=np.clip((lat-12)/18,0,1)
    steppe=np.zeros_like(base);steppe[:,:,0]=126+north*35;steppe[:,:,1]=151+north*8;steppe[:,:,2]=80+north*15
    # Retain the existing relief pattern so ranges don't turn into a flat green slab.
    luminance=base.mean(axis=2);detail=np.clip(luminance/140,.65,1.25)
    steppe*=np.clip(detail[:,:,None]+noise[:,:,None]*.025,.65,1.3)
    strength=wet[:,:,None]*.70
    base=base*(1-strength)+steppe*strength
    features=[]
    mega=[(12.9,12.2),(14.0,11.8),(15.4,12.0),(16.7,12.5),(18,13.1),(19.2,14.6),(20.0,16),(19.8,17.6),(18.4,18.1),(17.4,17.6),(16,17.1),(14.7,16.1),(13.4,14.6)]
    center=np.array([16.4,14.9]);pts=np.array(mega,float)
    # The highstand is approximate; calibrate only the total area, never claim a surveyed coast.
    scale=(350000/area_km2(poly_mask(pts)))**.5
    pts=center+(pts-center)*scale
    geometries=[('mega_chad',pts.tolist(),'schematic high-water shoreline, ~350,000 km²; uncertainty not quantified'),
        ('turkana',[(35.5,2.5),(35.75,3.5),(35.8,4.5),(36.1,5.05),(36.5,5.15),(36.65,4.5),(36.5,3.5),(36.1,2.5)],'schematic larger mid-Holocene lake'),
        ('persian_gulf',[(48.0,29.7),(48.35,30.0),(47.8,30.55),(47.1,30.9),(46.6,30.85),(46.9,30.45),(47.5,30.1)],'uncertain local shoreline; schematic northern embayment'),
        ('bothnian_bay',[(23.4,65.4),(24.2,65.35),(25.3,65.65),(25.0,66.05),(24.2,66.1),(23.65,65.85)],'schematic Littorina coastal inundation; local uplift is not simulated'),
        ('arabian_lake',[(45.0,18.2),(45.25,18.55),(45.65,18.45),(45.65,18.15),(45.3,18.0)],'schematic southern Arabian palaeolake')]
    added=np.zeros((H,W),dtype=np.uint8)
    for name,pts,note in geometries:
        mask=poly_mask(pts);added=np.maximum(added,mask)
        features.append({'id':name,'polygon':pts,'area_km2':round(area_km2(mask)),'confidence':note})
    water=np.maximum(255-land,added)
    lake_edge=gaussian_filter(added.astype(np.float32)/255,.65)
    lake_colour=np.array([31,83,100],np.float32)
    base=base*(1-lake_edge[:,:,None])+lake_colour*lake_edge[:,:,None]
    # Permanent Greenland / Antarctic land ice. No Laurentide/Fennoscandian ice sheets.
    greenland=poly_mask([(-56,60),(-47,59),(-39,64),(-20,70),(-10,81),(-28,85),(-60,84),(-76,76),(-63,68)])>127
    ice_land=((lat<-61)|greenland)&(water<128)
    shade=np.clip(detail,.8,1.06)
    base[ice_land]=(np.stack(np.broadcast_arrays(222*shade,232*shade,238*shade),axis=-1))[ice_land]
    Image.fromarray(np.uint8(np.clip(base,0,255))).save(out/'earth_holocene_albedo.webp',quality=94,method=6)
    Image.fromarray(water).save(out/'earth_holocene_ocean.png',optimize=True)
    Image.fromarray(added).save(out/'water_add.png',optimize=True)
    # Channel masks are schematic seasonal extents, not a quantitative ice reconstruction.
    x=np.deg2rad(lon)
    n_winter=72+5*np.cos(x)+2*np.cos(2*x)
    n_summer=84+2*np.cos(x+1)-1*np.cos(2*x)
    s_winter=62+2.5*np.sin(x)-1.5*np.cos(2*x)
    s_summer=72+1.5*np.cos(2*x)
    def edge(v):return np.clip(v/1.4+.5,0,1)*(water/255)
    channels=[edge(lat-n_winter),edge(lat-n_summer),edge(-lat-s_winter),edge(-lat-s_summer)]
    ice=np.uint8(np.stack(channels,axis=-1)*255)
    Image.fromarray(ice).save(out/'sea_ice.png',optimize=True)
    # Sparse indices in the game's 4096×2048 province raster; no stock map is shipped.
    indices=np.flatnonzero(added>127).astype('<i4')
    (out/'water_cells.bin').write_bytes(indices.tobytes())
    model={'version':1,'period_bce':4000,'dimensions':[W,H],'global_anomaly_vs_1850_1900_c':{'range':[.2,1.0],'illustrative_midpoint':.6},'features':features,'added_water_pixels':len(indices),'ice_channels':['north_march','north_september','south_september','south_march'],'seasonal_ice':'schematic; NH maximum in March, SH maximum in September','biomes':'schematic mid-Holocene steppe/savanna in Sahara and wetter southern Arabia'}
    (ROOT/'data/holocene_world.json').write_text(json.dumps(model,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps({'assets':str(out),'mega_chad_km2':features[0]['area_km2'],'water_cells':len(indices)},ensure_ascii=False))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,required=True);build(parser.parse_args().source)
