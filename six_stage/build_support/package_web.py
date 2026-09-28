from pathlib import Path
import shutil,json,re,struct
from PIL import Image,ImageDraw,ImageFont
r=Path(__file__).resolve().parents[1];target=r.parent/'hovagi-six-stage-site/dist'
for p in (r/'build/web').iterdir():
 if p.suffix not in ['.pck','.wasm']:shutil.copy2(p,target/p.name)
manifest={}
for name,prefix in [('index.wasm','engine'),('index.pck','mission')]:
 raw=(r/'build/web'/name).read_bytes();parts=[]
 for i in range(0,len(raw),12*1024*1024):
  file=f'{prefix}-{i//(12*1024*1024)}.bin';(target/file).write_bytes(raw[i:i+12*1024*1024]);parts.append(file)
 manifest[name]=parts
loader='''const originalFetch=window.fetch.bind(window);
const chunks=CHUNKS;
window.fetch=async function(resource,options){
 const url=typeof resource==='string'?resource:resource.url;
 const name=new URL(url,location.href).pathname.split('/').pop();
 if(chunks[name]){
  const parts=await Promise.all(chunks[name].map(async file=>{const r=await originalFetch(new URL(file,location.href),options);if(!r.ok)throw new Error('Game download failed. Please reload.');return new Uint8Array(await r.arrayBuffer());}));
  const all=new Uint8Array(parts.reduce((n,p)=>n+p.length,0));let offset=0;for(const p of parts){all.set(p,offset);offset+=p.length;}
  return new Response(all,{headers:{'Content-Type':name.endsWith('.wasm')?'application/wasm':'application/octet-stream'}});
 }
 return originalFetch(resource,options);
};
const full=document.getElementById('fullscreen');full.addEventListener('click',()=>{if(document.fullscreenElement)document.exitFullscreen();else document.documentElement.requestFullscreen?.().catch(()=>{});});
if(document.modelContext?.registerTool){try{document.modelContext.registerTool({name:'read_mission_status',description:'Read the current HOVAGI stage, objective, access level, and game state visible in the HUD.',inputSchema:{type:'object',properties:{},additionalProperties:false},annotations:{readOnlyHint:true,untrustedContentHint:false},execute:()=>window.hovagiStatus||{state:'loading'}});}catch(e){console.warn('Mission status tool unavailable');}}
'''.replace('CHUNKS',json.dumps(manifest))
(target/'loader.js').write_text(loader)
p=target/'index.html';s=p.read_text().replace('<title>HOVAGI — Six Stage Mission</title>','<title>HOVAGI · Six Stage Mission</title>')
s=s.replace('<script src="index.js"></script>','<button id="fullscreen" aria-label="Toggle fullscreen">⛶ Fullscreen</button><script src="loader.js"></script><script src="index.js"></script>')
s=s.replace('</style>','''#fullscreen{position:fixed;z-index:10;left:50%;transform:translateX(-50%);top:0;background:#122c36bb;color:#c6e9df;border:1px solid #427b78;border-radius:0 0 8px 8px;padding:4px 12px;font:12px sans-serif;cursor:pointer}#rotate{display:none}@media(orientation:portrait){#rotate{display:flex;position:fixed;z-index:20;inset:0;background:#091820ed;color:#b6e8dc;align-items:center;justify-content:center;text-align:center;font:24px sans-serif;padding:40px}}\n</style>''')
s=s.replace('<body>','<body><div id="rotate">Rotate your phone to landscape<br>for HOVAGI.</div>')
s=s.replace('<meta name="viewport"','<meta name="description" content="Six-stage HOVAGI infiltration prototype. Recover research, rescue the scientist, and escape."><meta name="viewport"')
p.write_text(s)
im=Image.new('RGB',(1000,560),'#091820');d=ImageDraw.Draw(im);font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
d.text((110,160),'HOVAGI',font=ImageFont.truetype(font,88),fill='#72e9df');d.text((116,280),'SIX-STAGE INFILTRATION',font=ImageFont.truetype(font,29),fill='#e6efec');d.text((116,347),'Loading mission assets…',font=ImageFont.truetype(font,23),fill='#a0b9ba');d.text((116,390),'Landscape touch + keyboard  /  Prototype 01',font=ImageFont.truetype(font,19),fill='#a0b9ba');im.save(target/'index.png')
print('Packaged',sum(x.stat().st_size for x in target.iterdir()),'bytes',manifest)
