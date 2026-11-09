// Simulation-only runtime regression. Canvas/DOM/audio/assets are stubbed;
// this is deliberately separate from real-browser/presentation acceptance.
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import vm from 'node:vm';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=new URL('../game/',import.meta.url), helper=readFileSync(new URL('party.js',root),'utf8');
const levels=readdirSync(root).filter(n=>/^[1-6]-[1-6S]$/.test(n)).sort();
function events(base={}) {const listeners=new Map();return Object.assign(base,{addEventListener(t,cb){if(!listeners.has(t))listeners.set(t,[]);listeners.get(t).push(cb);},removeEventListener(){},dispatchEvent(e){for(const cb of listeners.get(e.type)||[])cb(e);return true;}});}
function storage(seed={}) {const values=new Map(Object.entries(seed).map(([k,v])=>[k,JSON.stringify(v)]));return {getItem:k=>values.get(k)??null,setItem:(k,v)=>values.set(k,v)};}
async function boot(id,party){
 const raf=[],timers=[];let activeScene=null,resolveScene=null;
 const ctx=new Proxy({measureText:s=>({width:String(s).length*8}),getImageData:()=>({data:new Uint8ClampedArray(4)}),createLinearGradient:()=>({addColorStop(){}}),createRadialGradient:()=>({addColorStop(){}})}, {get:(obj,key)=>key in obj?obj[key]:(()=>{})});
 const element=()=>events({style:{setProperty(){}},classList:{add(){},remove(){},toggle(){},contains(){return false;}},width:960,height:540,textContent:'',innerHTML:'',appendChild(){},insertBefore(){},prepend(){},getContext(){return ctx;},getBoundingClientRect(){return {left:0,top:0,width:960,height:540};},setAttribute(){},setPointerCapture(){},releasePointerCapture(){},querySelector(){return null;},querySelectorAll(){return [];},focus(){},blur(){},toDataURL(){return '';}});
 const elements=new Map();const document=events({getElementById(id){if(!elements.has(id))elements.set(id,element());return elements.get(id);},createElement:element,querySelector(){return null;},querySelectorAll(){return [];},fonts:{load:()=>Promise.resolve()},body:element(),head:element(),documentElement:element(),activeElement:null,hidden:false});
 const localStorage=storage({'bd-party':party,'bd-save':{coins:91,cleared:{'1-1':1},seen:{}},'bd-mode':party?.mode});
 const sandbox=events({document,localStorage,sessionStorage:storage(),console,innerWidth:960,innerHeight:540,devicePixelRatio:1,navigator:{maxTouchPoints:0},location:{href:id+'/index.html',search:'',hash:''},performance:{now:()=>0},matchMedia:()=>({matches:false,addEventListener(){}}),getComputedStyle:()=>({getPropertyValue:()=>0}),requestAnimationFrame:cb=>{raf.push(cb);return raf.length;},cancelAnimationFrame(){},setTimeout:cb=>{timers.push(cb);return timers.length;},clearTimeout(){},setInterval(){},clearInterval(){},CustomEvent:class{constructor(type,args={}){this.type=type;Object.assign(this,args);}},Image:class{constructor(){this.width=this.naturalWidth=1024;this.height=this.naturalHeight=540;this.complete=true;}set src(value){this._src=value;Promise.resolve().then(()=>this.onload?.());}},BD:{parallax(){},band:element,keyOut:element,splitSky:()=>({sky:element(),land:element(),skyline:0}),wipe(_kind,mid){mid();}},BDCutscenes:{base:'',playing:()=>activeScene,play(id){activeScene=id;return new Promise(resolve=>resolveScene=resolve);},stop(){activeScene=null;resolveScene?.({stopped:true});resolveScene=null;}},Path2D:class{rect(){}},URL,URLSearchParams});
 sandbox.window=sandbox;const context=vm.createContext(sandbox);vm.runInContext(helper,context);
 const html=readFileSync(new URL(id+'/index.html',root),'utf8');
 for(const script of html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)) vm.runInContext(script[1],context,{filename:id+'/index.html'});
 await Promise.resolve();await Promise.resolve();await Promise.resolve();
 let time=0;
 function frame(){const current=raf.splice(0);time+=34;for(const cb of current)cb(time);}
 function runTimers(){for(const cb of timers.splice(0))cb();}
 return {sandbox,context,frame,runTimers,storage:localStorage,async settle(){await Promise.resolve();await Promise.resolve();}};
}
if(!process.argv.includes('--level')) {
 for(const id of levels){const result=spawnSync(process.execPath,['--max-old-space-size=192',fileURLToPath(import.meta.url),'--level',id],{stdio:'inherit'});assert.equal(result.status,0,'stage process '+id+' ('+result.signal+')');}
 for(const world of [1,2,3,4,5,6])for(const mode of ['solo','p2']){const id=world+'-2';const result=spawnSync(process.execPath,['--max-old-space-size=192',fileURLToPath(import.meta.url),'--level',id,'--mode',mode],{stdio:'inherit'});assert.equal(result.status,0,id+' '+mode);}
 console.log('PASS: 42 actual stage scripts auto-start saved parties and preserve campaign data (stub DOM/canvas, not browser rendering).');
} else for(const id of [process.argv[process.argv.indexOf('--level')+1]]){
 const mode=process.argv.includes('--mode')?process.argv[process.argv.indexOf('--mode')+1]:'cpu';const expected={p1:'theo',p2:'mei',mode};const test=await boot(id,expected);const w=test.sandbox;
 test.frame();
 if(w.BDStageStoryPending){assert.equal(w.__bd.state,'loading');assert.equal(w.__bd.players.length,0);test.runTimers();assert.ok(w.BDCutscenes.playing());test.frame();assert.equal(w.__bd.state,'loading');w.BDCutscenes.stop();await test.settle();}
 test.frame();assert.equal(w.__bd.state,'play',id+' resumes into play');
 assert.deepEqual(JSON.parse(JSON.stringify(w.__bd.players.map(p=>({k:p.k,cpu:p.cpu})))),mode==='solo'?[{k:'theo',cpu:false}]:[{k:'theo',cpu:false},{k:'mei',cpu:mode==='cpu'}],id+' party');
 const save=JSON.parse(test.storage.getItem('bd-save'));assert.equal(save.coins,91);assert.equal(save.cleared['1-1'],1);
 assert.ok(w.__flow.way.endsWith(id==='6-6'?'#credits':'#map&next'));
 if(id==='1-2'){
  w.__flow.clear();for(let n=0;n<62;n++)test.frame();w.__bd.cont();test.frame();w.__bd.cont();test.frame();assert.ok(w.location.href.endsWith('#map&next'),'clear keyboard route');
 }
 console.log('PASS runtime '+id+' '+mode);if(global.gc)global.gc();
}
