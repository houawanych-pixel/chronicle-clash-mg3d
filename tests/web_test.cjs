// Usage: WEB_ROOT=/path/to/export CHROMIUM_BIN=/path/to/chrome node tests/web_test.cjs
// Requires Playwright. Serves the unchanged PCK/WASM; query args enable existing demo fixtures.
const {chromium}=require('playwright');
const http=require('http'),fs=require('fs'),path=require('path');
const root=process.env.WEB_ROOT, out=process.env.WEB_TEST_OUTPUT||'/tmp/mg5-web-results';
fs.mkdirSync(out,{recursive:true});
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://localhost'), file=path.join(root,u.pathname==='/'?'index.html':u.pathname);
 if(!file.startsWith(root+path.sep)||!fs.existsSync(file)){res.writeHead(404);res.end();return;}
 res.setHeader('Cross-Origin-Opener-Policy','same-origin');res.setHeader('Cross-Origin-Embedder-Policy','require-corp');
 const ext=path.extname(file);res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.png':'image/png'})[ext]||'application/octet-stream');
 if(ext==='.html') {const args=['--','--verify-web'];if(u.searchParams.has('demo')) args.push('--demo='+u.searchParams.get('demo'));res.end(fs.readFileSync(file,'utf8').replace('"args":[]','"args":'+JSON.stringify(args)));}
 else fs.createReadStream(file).pipe(res);
});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 let browser;
 try {
 browser=await chromium.launch({executablePath:process.env.CHROMIUM_BIN,headless:true,args:['--no-sandbox','--disable-dev-shm-usage','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'],env:{...process.env,LD_LIBRARY_PATH:path.dirname(process.env.CHROMIUM_BIN)}});
 const base='http://127.0.0.1:'+server.address().port;
 const errors=[];let passes=0;
 for(const spec of [{name:'desktop',size:{width:1280,height:720}},{name:'phone',size:{width:915,height:412}}]) {
  const ctx=await browser.newContext({viewport:spec.size,hasTouch:true});const page=await ctx.newPage();let state;
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',msg=>{const t=msg.text();if(t.startsWith('MG05_STATE '))state=JSON.parse(t.slice(11));if(/SCRIPT ERROR|ERROR:/.test(t))errors.push(t);});
  const waitState=async check=>{const end=Date.now()+45000;while(Date.now()<end){if(state&&check(state))return;await page.waitForTimeout(200);}throw Error(spec.name+' state timeout: '+JSON.stringify(state));};
  await page.goto(base);await waitState(s=>s.mode==='title');
  const tap=async(x,y)=>{const scale=Math.min(spec.size.width/1280,spec.size.height/720),ox=(spec.size.width-1280*scale)/2,oy=(spec.size.height-720*scale)/2;await page.touchscreen.tap(ox+x*scale,oy+y*scale);};
  await tap(300,550);await waitState(s=>s.mode==='brief');await tap(300,550);await waitState(s=>s.mode==='play');
  if(state.meshes>=300||state.drones!==2)throw Error('Scene budget/spawn failure');passes++;console.log('PASS '+spec.name+' real touch start, room running, '+state.meshes+' meshes, two drones');
  await page.screenshot({path:path.join(out,spec.name+'_room.png')});
  await tap(968,647);await waitState(s=>s.prone);passes++;console.log('PASS '+spec.name+' real CRAWL touch');
  await tap(968,647);await waitState(s=>!s.prone);passes++;console.log('PASS '+spec.name+' real STAND touch');
  for(const demo of ['reveal_left','vent','crawl','drones']){
   state=null;await page.goto(base+'/?demo='+demo);await waitState(s=>s.mode==='play' && (demo==='vent'?s.view==='vent':true));
   await page.waitForTimeout(450);await page.screenshot({path:path.join(out,spec.name+'_'+demo+'.png')});
   if(demo==='vent'&&!state.prone)throw Error('Vent stance wrong');passes++;console.log('PASS '+spec.name+' '+demo+' rendered fixture, view='+state.view);
  }
  await ctx.close();
 }
 if(errors.length)throw Error(errors.join('\n'));
 console.log('RESULT: '+passes+' browser checks passed, no script/page errors. Inspect saved images for 3D rendering.');
 }finally{if(browser)await browser.close();server.close();}
})().catch(e=>{console.error(e);process.exitCode=1;server.close();});
