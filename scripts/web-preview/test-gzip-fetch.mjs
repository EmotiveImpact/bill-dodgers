import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import { gzipSync } from 'node:zlib';
const template=fs.readFileSync(new URL('./chunk-fetch-template.js',import.meta.url),'utf8');
const bytes=new Uint8Array(130041).map((_,i)=>(i*23)%251);
const raw=[bytes.slice(0,64000),bytes.slice(64000)];
const zipped=raw.map(part=>gzipSync(part));
const manifest={'index.pck':{size:bytes.length,type:'application/octet-stream',parts:raw.map((part,i)=>({file:`pack.part${i}.gz`,size:part.length,compressedSize:zipped[i].length,encoding:'gzip',prefix:Buffer.from(part.subarray(0,16)).toString('hex')}))}};
function harness(mode='normal') {
 const events=[];const calls=[];
 const window={dispatchEvent:event=>events.push(event),fetch:async(input,options)=>{
  calls.push(String(input));
  if(mode==='cancel')return new Promise((resolve,reject)=>options.signal.addEventListener('abort',()=>reject(new DOMException('Cancelled','AbortError')),{once:true}));
  const i=Number(/part(\d)\.gz$/.exec(String(input))[1]);
  if(mode==='http'&&i===1)return new Response('Not found',{status:404});
  if(mode==='html')return new Response('Please sign in',{headers:{'Content-Type':'text/html'}});
  let payload=zipped[i];const headers={'Content-Length':String(payload.length),'Content-Type':'application/gzip'};
  if(mode==='auto-decoded'){payload=raw[i];headers['Content-Encoding']='gzip';}
  if(mode==='extra-http-gzip')headers['Content-Encoding']='gzip'; // Fetch removed only the outer HTTP layer.
  if(mode==='corrupt'){payload=Uint8Array.from(payload);payload[payload.length-8]^=255;}
  if(mode==='truncated'){payload=payload.subarray(0,payload.length-5);headers['Content-Length']=String(payload.length);}
  if(mode==='wrong-header')headers['Content-Length']='17';
  if(mode==='raw-unlabelled'){payload=raw[i];delete headers['Content-Length'];}
  return new Response(payload,{headers});
 }};
 vm.runInNewContext(template.replace('__CHUNK_MANIFEST__',JSON.stringify(manifest)),{window,document:{currentScript:{src:'https://test.example/chunk-loader.js'},baseURI:'https://test.example/'},URL,Map,Headers,Response,ReadableStream,AbortController,DOMException,CustomEvent,DecompressionStream});
 return{fetch:window.fetch,events,calls};
}
for(const mode of ['normal','auto-decoded','extra-http-gzip']){
 const run=harness(mode);const response=await run.fetch('index.pck');assert.equal(response.headers.get('Content-Length'),String(bytes.length));assert.deepEqual(new Uint8Array(await response.arrayBuffer()),bytes);assert.equal(run.events.length,0);
}
for(const mode of ['http','html','corrupt','truncated','wrong-header','raw-unlabelled']){
 const run=harness(mode);await assert.rejects(async()=> (await run.fetch('index.pck')).arrayBuffer());assert.equal(run.events.length,1);assert.equal(run.events[0].type,'bill-dodgers-download-error');
}
const cancelled=harness('cancel');await (await cancelled.fetch('index.pck')).body.cancel('consumer cancelled');await new Promise(r=>setTimeout(r,10));assert.equal(cancelled.events.length,0);
console.log('PASS: native gzip stream byte identity; identity/auto-decoded/additional HTTP layer; CRC/truncation/HTTP/HTML/wire-length errors emit recovery event; consumer cancellation is quiet.');
