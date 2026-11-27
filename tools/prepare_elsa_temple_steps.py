"""Separate native temple stair/rail surface roles; infer only depth and support."""
import json, math, os, sys
from PIL import Image, ImageDraw, ImageChops, ImageFilter, ImageOps, ImageStat
import recover_elsa_island as source
from prepare_elsa_scenery import solid_pages, outline
from prepare_elsa_temple import RECT, VERTICAL, ground

OUT=source.ROOT/'assets/maps/falan/elsa/scenery/temple-steps'
TEMPLE=source.ROOT/'assets/maps/falan/elsa/scenery/temple'
# Front gilt bands read in the native image, inner to outer. End portions hidden
# by railings/spire continue the neighboring nosing; no new paths or doors.
STAIRS=[dict(name='west-entrance',center=7550,edges=[-2577,-2533,-2491,-2448,-2405,-2360,-2320],back=-2800,
 limits=[(7270,7800),(7235,7850),(7200,7900),(7165,7950),(7130,8000),(7105,8050),(7105,8100)]),
 dict(name='central-entrance',center=9470,edges=[-2299,-2252,-2216,-2175,-2132,-2090,-2047,-2003,-1960],back=-2630,
 limits=[(9250,9740),(9210,9780),(9170,9820),(9130,9860),(9090,9900),(9050,9940),(9010,9980),(8970,10020),(8930,10060)]),
 dict(name='east-entrance',center=11400,edges=[-2245,-2200,-2157,-2115,-2072,-2031,-1987,-1944],back=-2440,
 limits=[(11170,11630),(11130,11670),(11090,11710),(11050,11750),(11010,11790),(10970,11830),(10930,11870),(10890,11910)])]
RAILS=['287','288','291','292','293','294']
LANDING_CIRCLES=[(7565,-2658,100,55),(9395,-2310,60,32),(11375,-2325,100,55)]


def hall_platform_source():
 """Inventory the five native entrance bands without changing runtime art."""
 from prepare_elsa_gate import native_layers
 props=json.loads((source.ROOT/'assets/maps/falan/elsa/props/data.json').read_text())
 rect=(4768,250,5584,1250);folder=source.REPORT/'Temple Interior/Entry Platform Source';folder.mkdir(exist_ok=True)
 foreground,background=native_layers(props['maps']['59530'],rect,59530)
 composite=background.copy();composite.alpha_composite(foreground)
 background.save(folder/'background-original.png');composite.save(folder/'composite-original.png')
 def bands(u):
  result=[];run=[]
  for v in range(520,1080):
   r,g,b,a=background.getpixel((u-rect[0],v-rect[1]));value=max(r,g,b)
   if a>200 and 8<=value<=40:run.append(v)
   elif run:
    if 7<=len(run)<=30:result.append([run[0],run[-1]])
    run=[]
  return result
 traces=[]
 for seed in [740.5,788.,828.,870.5,916.]:
  selected=min(bands(5088),key=lambda r:abs(sum(r)*.5-seed))
  assert abs(sum(selected)*.5-seed)<.01
  halves=[]
  for direction,limit in [(-1,4880),(1,5408)]:
   rows=[];previous=seed;delta=0.
   for u in range(5088+4*direction,limit,4*direction):
    marks=bands(u)
    if not marks:break
    chosen=min(marks,key=lambda r:abs(sum(r)*.5-previous-delta));centre=sum(chosen)*.5
    if abs(centre-previous-delta)>12:break
    rows.append([u,*chosen]);delta=(centre-previous)*.6+delta*.4;previous=centre
   halves.append(rows)
  points=list(reversed(halves[0]))+[[5088,*selected]]+halves[1]
  assert len(points)>30
  for u,top,bottom in points:
   assert 7<=bottom-top+1<=30
   for v in range(top,bottom+1):
    r,g,b,a=background.getpixel((u-rect[0],v-rect[1]));assert a>200 and 8<=max(r,g,b)<=40
  traces.append(dict(points=points,bounds=[points[0][0],min(p[1] for p in points),points[-1][0],max(p[2] for p in points)]))
 guide=composite.convert('RGB');draw=ImageDraw.Draw(guide)
 for index,trace in enumerate(traces):
  color=[(255,90,60),(100,255,100),(70,220,255),(255,220,50),(240,100,255)][index]
  points=[(u-rect[0],(top+bottom)*.5-rect[1]) for u,top,bottom in trace['points']]
  draw.line(points,fill=color,width=2);draw.text(points[len(points)//2],str(index+1),fill=color)
 guide.save(folder/'band-traces-review.png')
 # Radial sampling also reaches the steep left ends that column traces miss.
 # This frame parameterizes the visible strokes; it does not assert a circle.
 def dark_at(u,v):
  x,y=round(u)-rect[0],round(v)-rect[1]
  if not 0<=x<background.width or not 0<=y<background.height:return False
  r,g,b,a=background.getpixel((x,y));return a>200 and 8<=max(r,g,b)<=40
 radial=[];centre=(5216.,590.);aspect=.75
 for seed in [740.5,788.,828.,870.5,916.]:
  dx,dy=5088-centre[0],(seed-centre[1])/aspect;start=math.atan2(dy,dx);radius=math.hypot(dx,dy);halves=[]
  for direction in [-1,1]:
   points=[];previous=radius;delta=0.
   for step in range(1,271):
    angle=start+direction*math.radians(.5)*step
    if not math.radians(45)<=angle<=math.pi:break
    values=[previous+delta-32+i*.5 for i in range(129)];runs=[];run=[]
    for distance in values:
     if dark_at(centre[0]+math.cos(angle)*distance,centre[1]+math.sin(angle)*distance*aspect):run.append(distance)
     elif run:
      if 4<=run[-1]-run[0]<=40:runs.append(run)
      run=[]
    if not runs:break
    chosen=min(runs,key=lambda r:abs((r[0]+r[-1])*.5-previous-delta));value=(chosen[0]+chosen[-1])*.5
    if abs(value-previous-delta)>12:break
    u=centre[0]+math.cos(angle)*value;v=centre[1]+math.sin(angle)*value*aspect
    assert dark_at(u,v)
    points.append([u,v]);delta=(value-previous)*.6+delta*.4;previous=value
   halves.append(points)
  points=list(reversed(halves[0]))+[[5088.,seed]]+halves[1]
  assert len(points)>60
  radial.append(dict(points=points,bounds=[min(p[0] for p in points),min(p[1] for p in points),max(p[0] for p in points),max(p[1] for p in points)]))
 radial_guide=composite.convert('RGB');draw=ImageDraw.Draw(radial_guide)
 for index,trace in enumerate(radial):
  color=[(255,90,60),(100,255,100),(70,220,255),(255,220,50),(240,100,255)][index]
  draw.line([(u-rect[0],v-rect[1]) for u,v in trace['points']],fill=color,width=2)
 radial_guide.save(folder/'radial-traces-review.png')
 _,_,planes=source.reference_map(59530);cuts=source.cut_records(59530)
 masters=sorted({cuts[v-1000][0] for v in planes[0] if v>=1000})
 data=dict(map=59530,reference_return_stone=[59,93],native_rect=list(rect),background_masters=masters,
  background_rgba_sha256=source.sha(background.tobytes()),composite_rgba_sha256=source.sha(composite.tobytes()),
  dark_bands=traces,radial_bands=radial,radial_parameter_frame=dict(centre=list(centre),aspect=aspect,angular_bounds=[45,180],inferred_parameterization_only=True),candidate_only=True,
  confirmed=['Five visible dark stair bands at this entrance; their selected pixels come directly from the original BG layer.',
             'A second blue-orb pedestal is painted into the BG, outside the69 foreground-group inventory.'],
  limits=['Band grouping and hidden continuations need review. No original3D heights are available; this report does not assign stair heights.',
          'The broad gray apron and narrow dark risers must have separate roles. Do not turn the entire apron into one vertical wall.',
          'Original void beyond the platform must remain void. Restore only confirmed parent surfaces through the original pedestal occlusion.',
          'No runtime map, placement, navigation, collision, travel, source image or music changes.'])
 (folder/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 print('ELSA_HALL_PLATFORM_SOURCE five bands;',sum(len(t['points']) for t in traces),'confirmed pixel columns;',len(masters),'BG masters; report only',flush=True)


def gold(image,u,v):
 if not RECT[0]<=u<RECT[2] or not RECT[1]<=v<RECT[3]:return False
 r,g,b,a=image.getpixel((round(u)-RECT[0],round(v)-RECT[1]));return bool(a and r>110 and g>75 and r>g*1.025 and r>b*1.7)


def hall_platform_joins():
 """Recover visible stair end faces without substituting circular step outlines."""
 import heapq
 from prepare_elsa_gate import native_layers
 folder=source.REPORT/'Temple Interior/Entry Platform Source'
 original=json.loads((folder/'data.json').read_text());rect=original['native_rect']
 props=json.loads((source.ROOT/'assets/maps/falan/elsa/props/data.json').read_text())
 foreground,background=native_layers(props['maps']['59530'],tuple(rect),59530)
 assert source.sha(background.tobytes())==original['background_rgba_sha256'], 'Refresh source platform inventory first'
 composite=background.copy();composite.alpha_composite(foreground)
 assert source.sha(composite.tobytes())==original['composite_rgba_sha256'], 'Original FG/BG placement changed'
 assert all(foreground.getpixel((5309-rect[0],v-rect[1]))[3]>200 for v in range(730,748)), 'First boundary must be checked against the original FG occlusion'
 def pixel(u,v):return background.getpixel((u-rect[0],v-rect[1]))
 def dark(u,v):
  if not 5086<=u<=5240 or not 770<=v<=945:return False
  c=pixel(u,v);return c[3]>200 and 8<=max(c[:3])<=40
 frontier=[]
 for v in range(730,960):
  points=[u for u in range(5088,5408) if pixel(u,v)[3]>200 and max(pixel(u,v)[:3])>8]
  if points:frontier.append([v,max(points)])
 runs=[]
 for v,u in frontier:
  if runs and runs[-1][0]==u and runs[-1][2]==v-1:runs[-1][2]=v
  else:runs.append([u,v,v])
 ends=[row for row in runs if row[2]-row[1]>=3 and row[1]>780]
 assert ends==[[5232,831,841],[5199,865,876],[5167,899,909],[5135,932,941]], 'Original stair return corners changed'
 # The earlier5308/730–747 run is the missing FG pedestal photograph, not a stair.
 joins=[];used=set()
 for step,(seed,row) in enumerate(zip([788,828,870,916],ends),2):
  start=(5088,seed);end=(row[0],(row[1]+row[2])//2)
  assert dark(*start) and dark(*end)
  queue=[(abs(end[0]-start[0])+abs(end[1]-start[1]),0,start)];cost={start:0};parent={}
  while queue:
   _,distance,at=heapq.heappop(queue)
   if distance!=cost[at]:continue
   if at==end:break
   for dx,dy in [(1,0),(0,1),(0,-1),(-1,0)]:
    p=(at[0]+dx,at[1]+dy)
    if not dark(*p):continue
    value=distance+1
    if value<cost.get(p,float('inf')):
     cost[p]=value;parent[p]=at
     heapq.heappush(queue,(value+abs(end[0]-p[0])+abs(end[1]-p[1]),value,p))
  assert end in cost, ('Stair return needs source evidence',step)
  path=[end]
  while path[-1]!=start:path.append(parent[path[-1]])
  path.reverse()
  assert not used.intersection(path), 'Different original stair faces must remain distinct'
  used.update(path)
  assert all(dark(*p) for p in path)
  joins.append(dict(step=step,vertical_edge=dict(u=row[0],top=row[1],bottom=row[2],visible_pixels=row[2]-row[1]+1),dark_source_path=[list(p) for p in path]))
 guide=composite.convert('RGB');draw=ImageDraw.Draw(guide)
 for item,color in zip(joins,[(100,255,100),(70,220,255),(255,220,50),(240,100,255)]):
  draw.line([(u-rect[0],v-rect[1]) for u,v in item['dark_source_path']],fill=color,width=2)
  edge=item['vertical_edge'];u=edge['u']-rect[0];top=edge['top']-rect[1];bottom=edge['bottom']-rect[1]
  draw.rectangle((u-3,top-2,u+3,bottom+2),outline=color,width=1);draw.text((u+6,top),str(item['step']),fill=color)
 guide.save(folder/'right-joins-review.png')
 result=dict(map=59530,native_rect=rect,background_rgba_sha256=source.sha(background.tobytes()),joins=joins,
  foreground_occlusion=dict(u=5308,top=730,bottom=747,foreground_neighbor_u=5309,verified_opaque_neighbors=18,role='FG406 pedestal cutout boundary; not a visible stair end'),
  inferred_riser_candidate=dict(native_pixels=11,world_height=11/VERTICAL,basis='Median of four visible end-face spans, with1px variation. First end is occluded; this is not original3D height evidence.'),
  confirmed=['Four straight source stair end faces span11,12,11,10 pixels. Each has a separate continuous path through original dark BG pixels.',
             'Earlier curved traces missed the right corners of steps3/4; these joins extend them without imposing a circular footprint.'],
  limits=['Pixel paths identify source material continuity, not exact top/bottom contours or original3D height.',
          'First stair end is occluded by FG406. Any continuation or common riser height is inferred.',
          'No runtime, floor, physics, navigation, door, NPC or music change.'])
 (folder/'right-joins.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 print('ELSA_HALL_RIGHT_JOINS',len(joins),'separate original end faces;',sum(len(j['dark_source_path']) for j in joins),'verified source samples; no runtime changes',flush=True)


def curves(image,spec):
 result=[]
 for seed,(left,right) in zip(spec['edges'],spec['limits']):
  halves=[]
  for direction,end in [(-1,left),(1,right)]:
   points=[];previous=seed;delta=0.
   for u in range(spec['center'],end+direction,4*direction):
    predicted=previous+delta
    marks=[v for v in range(round(previous)-4,round(previous)+5) if gold(image,u,v)]
    if marks:
     chosen=min(marks,key=lambda v:abs(v-predicted));run=[v for v in marks if abs(v-chosen)<5]
     v=sum(run)/len(run);delta=(v-previous)*.45+delta*.55;confirmed=True
    else:v=predicted;confirmed=False
    delta=max(-4.,min(4.,delta));previous=v;points.append([u,v,confirmed])
   halves.append(points)
  raw=list(reversed(halves[0][1:]))+halves[1];smooth=[]
  for i,(u,v,confirmed) in enumerate(raw):
   neighbors=raw[max(0,i-3):min(len(raw),i+4)];mean=sum(p[1] for p in neighbors)/len(neighbors)
   smooth.append([u,v+max(-1.5,min(1.5,mean-v)),confirmed])
  result.append(smooth)
 return result


def inside(x,y,poly):
 result=False
 for a,b in zip(poly,poly[1:]+poly[:1]):
  if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:result=not result
 return result


def support_grid(tiers):
 polygons=[[[p[0],p[2]] for p in t['points']+t['back_points']] for t in tiers];spacing=1.5
 low=[math.floor(min(p[a] for poly in polygons for p in poly)/spacing)*spacing-spacing for a in [0,1]]
 high=[math.ceil(max(p[a] for poly in polygons for p in poly)/spacing)*spacing+spacing for a in [0,1]]
 dims=[round((b-a)/spacing)+1 for a,b in zip(low,high)]
 bounds=[(min(p[0] for p in poly),min(p[1] for p in poly),max(p[0] for p in poly),max(p[1] for p in poly)) for poly in polygons]
 heights=[]
 for z in range(dims[1]):
  for x in range(dims[0]):
   px=low[0]+x*spacing;py=low[1]+z*spacing;height=0.
   for tier,poly,box in zip(tiers,polygons,bounds):
    if not box[0]<=px<=box[2] or not box[1]<=py<=box[3] or not inside(px,py,poly):continue
    distance=1e10
    for a,b in zip(poly,poly[1:]+poly[:1]):
     dx,dy=b[0]-a[0],b[1]-a[1];length=dx*dx+dy*dy;t=max(0,min(1,((px-a[0])*dx+(py-a[1])*dy)/length)) if length else 0
     distance=min(distance,math.hypot(px-a[0]-dx*t,py-a[1]-dy*t))
    height=max(height,tier['height']*min(1,distance/.5))
   heights.append(height)
 return dict(origin=low,size=dims,spacing=spacing,heights=heights)


def with_base_beam(art,origin,anchor,foot,background,minimum_x=0):
 result=Image.new('RGBA',art.size)
 for y in range(art.height):
  for x in range(minimum_x,art.width):
   expected=foot[0]*(origin[0]+x)+foot[1]-origin[1]
   u=anchor[0]+origin[0]+x-RECT[0];v=anchor[1]+origin[1]+y-RECT[1]
   if not expected-8<=y<=expected+16 or not 0<=u<background.width or not 0<=v<background.height:continue
   r,g,b,a=background.getpixel((u,v))
   if a and r>45 and g>25 and b<r*.9:result.putpixel((x,y),(r,g,b,a))
 result.alpha_composite(art)
 return result


def hidden_rail(original,group,placement,props,pages):
 """Continue the native motif only where the original tower hid rail 294."""
 if placement['group']!='294':return original,None
 template=props['groups']['288'];x,y,w,h=template['rect']
 source_art=pages[template['page']].crop((x,y,x+w,y+h))
 shifted=Image.new('RGBA',original.size);shifted.paste(source_art,(17,19))
 tower=json.loads((source.ROOT/'assets/maps/falan/elsa/scenery/data.json').read_text())['tower']
 tx,ty,tw,th=tower['rect'];u=placement['anchor'][0]+group['origin'][0]-tx;v=placement['anchor'][1]+group['origin'][1]-ty
 occlusion=Image.open(source.ROOT/'assets/maps/falan/elsa/scenery/tower.png').getchannel('A').crop((u,v,u+original.width,v+original.height))
 missing=original.getchannel('A').point(lambda p:255 if p==0 else 0)
 mask=ImageChops.multiply(shifted.getchannel('A'),ImageChops.multiply(occlusion,missing))
 shifted.putalpha(mask);shifted.alpha_composite(original);mask.save(OUT/'294-inferred-mask.png')
 return shifted,dict(template='288',shift=[17,19],mask='294-inferred-mask.png',mask_sha256=source.sha(mask.tobytes()),
  inference='The matching original ascending rail motif continues through the original tower occlusion. Alignment was measured against the surviving target spans; every original nontransparent target pixel is retained.')


def paving_sampler(background,traced,occlusion,fallback):
 """Native paving at consistent UV scale, toned from each actual tread."""
 columns={};tones={};mean=ImageStat.Stat(fallback).mean
 tile=Image.new('RGB',(fallback.width*2,fallback.height*2))
 tile.paste(fallback,(0,0));tile.paste(ImageOps.mirror(fallback),(fallback.width,0))
 tile.paste(ImageOps.flip(fallback),(0,fallback.height));tile.paste(ImageOps.flip(ImageOps.mirror(fallback)),(fallback.width,fallback.height))
 def values(u):
  if u not in columns:
   flight=min(traced,key=lambda entry:abs(u-sum(p[0] for p in entry['curves'][0])/len(entry['curves'][0])))
   heights=[]
   for curve in flight['curves']:
    if u<=curve[0][0]:v=curve[0][1]
    elif u>=curve[-1][0]:v=curve[-1][1]
    else:
     a,b=next((a,b) for a,b in zip(curve,curve[1:]) if a[0]<=u<=b[0]);v=a[1]+(b[1]-a[1])*(u-a[0])/(b[0]-a[0])
    heights.append(v)
   columns[u]=(flight,heights)
  return columns[u]
 def sample(u,v):
  flight,heights=values(u);level=sum(v>=h for h in heights)-1
  if level<0:return fallback.getpixel((u%fallback.width,v%fallback.height))
  level=min(level,len(heights)-2);key=(flight['name'],level)
  if key not in tones:
   colors=[]
   center=next(spec['center'] for spec in STAIRS if spec['name']==flight['name'])
   for at in range(center-16,center+16):
    _,edge=values(at)
    for y in range(round(edge[level])+30,round(edge[level+1])-4):
     x=at-RECT[0];z=y-RECT[1]
     if not 0<=x<background.width or not 0<=z<background.height or occlusion.getpixel((x,z)):continue
     r,g,b,a=background.getpixel((x,z))
     if a and max(r,g,b)-min(r,g,b)<30 and 35<max(r,g,b)<245:colors.append((r,g,b))
   tones[key]=[sum(color[c] for color in colors)/len(colors)/mean[c] for c in range(3)] if colors else [1.,1.,1.]
  color=tile.getpixel((u%tile.width,v%tile.height))
  return tuple(min(255,round(color[c]*tones[key][c])) for c in range(3))
 return sample


def repair_front(background,rail_mask,building):
 """Continue architecture through relocated foreground, never copy floor art."""
 tower=json.loads((source.ROOT/'assets/maps/falan/elsa/scenery/data.json').read_text())['tower'];tx,ty,tw,th=tower['rect']
 tower_mask=Image.new('L',background.size);tower_mask.paste(Image.open(source.ROOT/'assets/maps/falan/elsa/scenery/tower.png').getchannel('A'),(tx-RECT[0],ty-RECT[1]))
 occlusion=ImageChops.lighter(rail_mask,tower_mask)
 front_mask=ImageChops.multiply(occlusion,building)
 front=Image.open(TEMPLE/'front-solid.png').convert('RGB')
 near=occlusion.filter(ImageFilter.MaxFilter(31));allowed=ImageChops.multiply(building,ImageChops.invert(near))
 box=front_mask.getbbox();box=(max(0,box[0]-64),max(0,box[1]-64),min(front.width,box[2]+64),min(front.height,box[3]+64))
 white=background.crop(box);blue=white.copy();wp=white.load();bp=blue.load();ap=allowed.load()
 for y in range(white.height):
  for x in range(white.width):
   r,g,b,a=wp[x,y];valid=bool(a and ap[x+box[0],y+box[1]])
   if not valid or min(r,g,b)<110 or max(r,g,b)-min(r,g,b)>100 or g>r+12 and g>b+12 or r>g+15 and b>g+15:wp[x,y]=(0,0,0,0)
   if not valid or not (b>r*1.25 and b>g*1.1):bp[x,y]=(0,0,0,0)
 white=solid_pages(dict(graphics={'white':dict(rect=[0,0,*white.size],page=0)}),[white])[0]
 blue=solid_pages(dict(graphics={'blue':dict(rect=[0,0,*blue.size],page=0)}),[blue])[0]
 old=front.copy();target=front.load();original=old.load();fm=front_mask.load();np=near.load();building_pixels=building.load()
 for x in range(front.width):
  previous=None
  for y in range(front.height):
   if not np[x,y] and building_pixels[x,y]:previous=original[x,y]
   if not fm[x,y]:continue
   r,g,b=previous if previous is not None else (200,210,220)
   if previous is not None and r>110 and g>75 and r>b*1.7:color=previous
   elif previous is not None and max(previous)<35:color=previous
   elif b>r*1.25 and b>g*1.1:color=blue.getpixel((x-box[0],y-box[1]))[:3]
   else:color=white.getpixel((x-box[0],y-box[1]))[:3]
   target[x,y]=color
 for name,image in [('front-paint.png',front),('front-infill-mask.png',front_mask)]:
  temporary=OUT/(name+'.tmp');image.save(temporary,format='PNG');os.replace(temporary,OUT/name)
 print('ELSA_TEMPLE_FRONT architecture-only continuations; original pixels outside the recorded occlusions retained',flush=True)


def build():
 OUT.mkdir(parents=True,exist_ok=True)
 background=Image.open(TEMPLE/'original-background.png').convert('RGBA');props=json.loads((source.ROOT/'assets/maps/falan/elsa/props/data.json').read_text())
 rail_mask=Image.new('L',background.size);rails=[];pages={}
 for token in RAILS:
  row=next(p for p in props['maps']['59520'] if p['group']==token);g=props['groups'][token]
  if g['page'] not in pages:pages[g['page']]=Image.open(source.ROOT/f"assets/maps/falan/elsa/props/atlas-{g['page']}.png").convert('RGBA')
  x,y,w,h=g['rect'];original=pages[g['page']].crop((x,y,x+w,y+h))
  continued,inference=hidden_rail(original,g,row,props,pages)
  art=with_base_beam(continued,g['origin'],row['anchor'],g['wall']['foot'],background)
  art.save(OUT/(token+'.png'));solid_pages(dict(graphics={'rail':dict(rect=[0,0,w,h],page=0)}),[art])[0].save(OUT/(token+'-solid.png'))
  u=row['anchor'][0]+g['origin'][0]-RECT[0];v=row['anchor'][1]+g['origin'][1]-RECT[1]
  layer=Image.new('L',background.size);layer.paste(art.getchannel('A'),(u,v));rail_mask=ImageChops.lighter(rail_mask,layer)
  rail=dict(group=token,anchor=row['anchor'],source_master=g['master'],size=[w,h],edges=outline(art),source_rgba_sha256=source.sha(original.tobytes()),rgba_sha256=source.sha(art.tobytes()))
  if inference:rail['hidden_continuation']=inference
  rails.append(rail)
 rail_mask=rail_mask.filter(ImageFilter.MaxFilter(5))
 seed=background.copy();seed_alpha=ImageChops.multiply(background.getchannel('A'),ImageChops.invert(rail_mask))
 near=rail_mask.filter(ImageFilter.MaxFilter(31));np=near.load();alpha_pixels=seed_alpha.load();original=background.load()
 for y in range(background.height):
  for x in range(background.width):
   r,g,b,a=original[x,y]
   if np[x,y] and (r>60 and g>30 and b<r*.85 or r>110 and b>80 and g<max(r,b)*.85):alpha_pixels[x,y]=0
 seed.putalpha(seed_alpha)
 repaired=solid_pages(dict(graphics={'paint':dict(rect=[0,0,*background.size],page=0)}),[seed])[0]
 building=Image.open(TEMPLE/'building-mask.png').convert('L')
 repair_front(background,rail_mask,building)
 gaps=ImageChops.multiply(ImageChops.invert(background.getchannel('A')),Image.open(TEMPLE/'occluded-floor-mask.png').convert('L'))
 paint_infill=ImageChops.lighter(rail_mask,gaps)
 paint=background.convert('RGB');paint.paste(repaired,(0,0),paint_infill);paint.save(OUT/'paint.png');paint_infill.save(OUT/'paint-infill-mask.png')
 tiers=[];footprint=Image.new('L',background.size);draw=ImageDraw.Draw(footprint);rises={};traced=[]
 for spec in STAIRS:
  native_curves=curves(background,spec);rises[spec['name']]=len(native_curves)*.5
  traced.append(dict(name=spec['name'],curves=native_curves))
  for i,curve in enumerate(reversed(native_curves)):
   rise=(i+1)*.5;points=[]
   for u,v,confirmed in curve:
    a,b=ground(u,v);points.append([a,rise,b])
   back=[]
   for u in [spec['limits'][0][1],spec['limits'][0][0]]:
    a,b=ground(u,spec['back']);back.append([a,rise,b])
   polygon=[(u-RECT[0],v-RECT[1]) for u,v,c in curve]+[(spec['limits'][0][1]-RECT[0],spec['back']-RECT[1]),(spec['limits'][0][0]-RECT[0],spec['back']-RECT[1])]
   draw.polygon(polygon,fill=255);tiers.append(dict(entrance=spec['name'],height=rise,riser=.5,points=points,back_points=back,native_curve=curve))
 flights={'287':'west-entrance','288':'central-entrance','291':'central-entrance','292':'east-entrance','293':'east-entrance','294':'west-entrance'}
 for row in rails:
  ascending=row['group'] in ['288','292','294'];height=rises[flights[row['group']]]
  row['grade']=[0.,height] if ascending else [height,0.]
  row['height_inference']='One continuous rail plane joins the original flight ends; step heights are inferred.'
 blue_role=Image.new('L',background.size);outer_halo=Image.new('L',background.size);role=blue_role.load();halo=outer_halo.load();covered=building.load();fp=footprint.load();floor_samples={}
 for entry in traced:
  for index,curve in enumerate(entry['curves']):
   for a,b in zip(curve,curve[1:]):
    for u in range(a[0],b[0]):
     y=a[1]+(b[1]-a[1])*(u-a[0])/(b[0]-a[0])
     for v in range(round(y)-4,round(y)+30):
      x=u-RECT[0];z=v-RECT[1]
      if not 0<=x<background.width or not 0<=z<background.height:continue
      r,g,b_,alpha=background.getpixel((x,z))
      if fp[x,z]:role[x,z]=255
      elif not covered[x,z] and index==len(entry['curves'])-1 and alpha and r<105 and b_>r*1.3 and b_>g*1.2:
       halo[x,z]=255;floor_samples[(x,z)]=(*repaired.getpixel((x,min(background.height-1,round(y)+34-RECT[1])))[:3],255)
 tiles={'riser':(7500,-2569,32,12),'nosing':(7525,-2580,16,4),'paving':(7510,-2605,32,16)};materials={}
 for name,(u,v,w,h) in tiles.items():
  image=background.crop((u-RECT[0],v-RECT[1],u-RECT[0]+w,v-RECT[1]+h));tile=solid_pages(dict(graphics={'tile':dict(rect=[0,0,w,h],page=0)}),[image])[0].convert('RGB');tile.save(OUT/(name+'.png'));materials[name]=dict(rect=[u,v,w,h],source_rgba_sha256=source.sha(image.tobytes()),rgb_sha256=source.sha(tile.tobytes()))
 # Covered stair ends continue paving, not the pylon/rail photographs that
 # originally hid them. The whole photographed riser/nosing band is relocated;
 # selecting only blue pixels left gold/shadow stripes smeared across the top.
 blue_role=ImageChops.lighter(blue_role,ImageChops.multiply(footprint,ImageChops.lighter(rail_mask,building)));role=blue_role.load()
 tower=json.loads((source.ROOT/'assets/maps/falan/elsa/scenery/data.json').read_text())['tower'];tx,ty,tw,th=tower['rect']
 tower_mask=Image.new('L',background.size);tower_mask.paste(Image.open(source.ROOT/'assets/maps/falan/elsa/scenery/tower.png').getchannel('A'),(tx-RECT[0],ty-RECT[1]))
 blue_role=ImageChops.lighter(blue_role,ImageChops.multiply(footprint,tower_mask));role=blue_role.load()
 bg=background.load()
 for y in range(background.height):
  for x in range(background.width):
   if not fp[x,y]:continue
   u=x+RECT[0];v=y+RECT[1]
   if any(((u-cx)/rx)**2+((v-cy)/ry)**2<=1 for cx,cy,rx,ry in LANDING_CIRCLES):continue
   r,g,b,a=bg[x,y]
   if a and (g>r*1.05 and g>b*1.05 or b>r*1.25 and b>g*1.1):role[x,y]=255
 paving=Image.open(OUT/'paving.png').convert('RGB');paint_pixels=paint.load()
 sample_paving=paving_sampler(background,traced,ImageChops.lighter(tower_mask,ImageChops.lighter(rail_mask,building)),paving)
 for y in range(background.height):
  for x in range(background.width):
   if role[x,y]:paint_pixels[x,y]=sample_paving(x+RECT[0],y+RECT[1])
 paint_infill=ImageChops.lighter(paint_infill,blue_role);paint_infill.save(OUT/'paint-infill-mask.png');paint.save(OUT/'paint.png')
 blue_role.save(OUT/'riser-role-mask.png');outer_halo.save(OUT/'outer-halo-mask.png')
 floor=Image.open(TEMPLE/'floor.png').convert('RGBA')
 floor.paste(repaired,(0,0),ImageChops.multiply(rail_mask,ImageChops.invert(building)))
 meta=json.loads((TEMPLE/'data.json').read_text());x,y,w,h=meta['grass_rect'];grass=background.crop((x,y,x+w,y+h));fp=footprint.load();pixels=floor.load();sample=grass.load()
 for v in range(floor.height):
  for u in range(floor.width):
   if fp[u,v]:pixels[u,v]=sample[(u-x)%w,(v-y)%h]
 for (x,y),color in floor_samples.items():floor.putpixel((x,y),color)
 floor.save(OUT/'floor.png');rail_mask.save(OUT/'rail-mask.png');footprint.save(OUT/'footprint-mask.png')
 width,height,_=source.reference_map(59520)
 data=dict(map=59520,rect=list(RECT),rails=rails,rises=rises,source_curves=traced,materials=materials,
  steps=dict(tiers=tiers,grid=support_grid(tiers),map_width=width,riser_texture='riser.png',nosing_texture='nosing.png',map_origin=[-(width//2)*3,-(height//2)*3],sample_ground=True),
  hashes=dict(background=source.sha(background.tobytes()),paint=source.sha(paint.tobytes()),floor=source.sha(floor.tobytes())),
  inference='Native nosing bands/rail art and source XZ footprints are retained. Occluded curve ends, 0.5m rises, support smoothing, under-stair fill, under-rail continuation, and paving beneath relocated riser pixels are inferred. Original vertical blue bands use native blue stone on the actual riser faces. Door cells and original walking flags are unchanged.')
 (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
 print('ELSA_TEMPLE_STEPS',len(tiers),'curved levels;',len(rails),'native rails;',len(data['steps']['grid']['heights']),'support samples')

if __name__=='__main__':
 if '--hall-platform-source' in sys.argv:hall_platform_source()
 elif '--hall-platform-joins' in sys.argv:hall_platform_joins()
 elif '--front-only' in sys.argv:
  repair_front(Image.open(TEMPLE/'original-background.png').convert('RGBA'),Image.open(OUT/'rail-mask.png').convert('L'),Image.open(TEMPLE/'building-mask.png').convert('L'))
 else:build()
