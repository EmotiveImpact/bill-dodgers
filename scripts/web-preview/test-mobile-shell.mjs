import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const html=fs.readFileSync(process.argv[2]+'/dist/index.html','utf8');
const script=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(x=>x[1]).find(x=>x.includes('const GODOT_CONFIG'));
function harness({missing=[],maxTexture=8192,decompression=true}={}){
 let downloads=0,reloads=0,losses=0,focuses=0,blurs=0,callbacks=null,reserve=null;
 const nodes={}; const docEvents={};const windowEvents={};
 for(const id of ['canvas','game-frame','gate','start','progress','load-status','error','storage-warning'])nodes[id]={style:{},hidden:false,disabled:false,events:{},addEventListener(name,fn){this.events[name]=fn;},getBoundingClientRect(){return{width:390,height:id==='storage-warning'?36:844};},removeAttribute(name){delete this[name];},focus(){focuses++;},blur(){blurs++;}};
 nodes['storage-warning'].hidden=true;
 const document={documentElement:{style:{setProperty(name,value){if(name==='--storage-reserve')reserve=value;}}},hidden:false,getElementById:id=>nodes[id],addEventListener:(name,fn)=>docEvents[name]=fn,createElement:()=>({getContext:()=>({MAX_TEXTURE_SIZE:3379,getParameter:()=>maxTexture,getExtension:()=>({loseContext:()=>losses++})})})};
 const window={devicePixelRatio:2,addEventListener:(name,fn)=>windowEvents[name]=fn,location:{reload(){reloads++;}},indexedDB:{}};
 class Engine{static getMissingFeatures(){return[...missing];}startGame(config){callbacks=config;downloads++;return Promise.resolve();}}
 vm.runInNewContext(script,{document,window,Engine,ReadableStream,DecompressionStream:decompression?DecompressionStream:undefined,ResizeObserver:class{observe(){}},console});
 return{nodes,document,docEvents,windowEvents,click:()=>nodes.start.events.click(),storageFailure:()=>callbacks.onPrint('IndexedDB not available'),counts:()=>({downloads,reloads,losses,focuses,blurs,reserve})};
}
const absent=harness({missing:['WebGL2']});absent.click();assert.equal(absent.counts().downloads,0);assert.match(absent.nodes.error.textContent,/WebGL2/);absent.click();assert.equal(absent.counts().reloads,1);
const oldSafari=harness({decompression:false});oldSafari.click();assert.equal(oldSafari.counts().downloads,0);assert.match(oldSafari.nodes.error.textContent,/16.4/);
const small=harness({maxTexture:4096});small.click();assert.equal(small.counts().downloads,0);assert.equal(small.counts().losses,1);assert.match(small.nodes.error.textContent,/5591/);
const supported=harness();supported.click();supported.click();assert.equal(supported.counts().downloads,1);assert.equal(supported.counts().losses,1);await new Promise(r=>setImmediate(r));assert.equal(supported.nodes.gate.hidden,true);assert.equal(supported.nodes.canvas.width,780);assert.equal(supported.nodes.canvas.height,1688);supported.storageFailure();assert.equal(supported.nodes['storage-warning'].hidden,false);assert.equal(supported.counts().reserve,'60px');
supported.document.hidden=true;supported.docEvents.visibilitychange();supported.windowEvents.pagehide();supported.windowEvents.blur();assert.equal(supported.counts().blurs,3);
supported.document.hidden=false;supported.docEvents.visibilitychange();assert.equal(supported.counts().focuses,1);
assert.ok(html.indexOf('id="storage-warning"')>html.indexOf('</section>'));
assert.ok(html.includes('var(--storage-reserve,0px)'));
supported.windowEvents['bill-dodgers-download-error']({detail:{message:'Test interrupted download'}});assert.equal(supported.nodes.gate.hidden,false);assert.equal(supported.nodes.start.disabled,false);assert.match(supported.nodes.error.textContent,/Test interrupted download/);
const late=harness();late.click();late.windowEvents['bill-dodgers-download-error']({detail:{message:'Late test error'}});await new Promise(r=>setImmediate(r));assert.equal(late.nodes.gate.hidden,false);assert.equal(late.nodes.start.disabled,false);assert.equal(late.counts().focuses,0);
console.log('PASS: no download on missing WebGL2/texture cap, context released, idempotent start, retry, DPR/safe frame dimensions, background blur/no auto-refocus, storage warning outside hidden gate.');
