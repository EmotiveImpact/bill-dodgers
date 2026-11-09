import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import crypto from 'node:crypto';
import { Readable } from 'node:stream';
import assert from 'node:assert/strict';
const root=path.resolve(process.argv[2]);
const inventory=JSON.parse(fs.readFileSync(root+'/export-inventory.json'));
const engine=fs.readFileSync(root+'/dist/index.js','utf8');
const start=engine.indexOf('function getTrackedResponse(');const end=engine.indexOf('\n\tfunction loadFetch(',start);
assert.ok(start>=0&&end>start);
const wrap=vm.runInNewContext('('+engine.slice(start,end).trim()+')',{Response,ReadableStream});
const events=[];
const window={fetch:async input=>{
 const name=new URL(input).pathname.slice(1);
 assert.ok(!name.includes('/'));
 const filename=path.join(root,'dist',name);
 return new Response(Readable.toWeb(fs.createReadStream(filename)),{headers:{'Content-Length':String(fs.statSync(filename).size),'Content-Type':'application/gzip'}});
},dispatchEvent:event=>events.push(event)};
vm.runInNewContext(fs.readFileSync(root+'/dist/chunk-loader.js','utf8'),{window,document:{currentScript:{src:'https://test.example/chunk-loader.js'},baseURI:'https://test.example/'},URL,Map,Headers,Response,ReadableStream,AbortController,DOMException,CustomEvent,DecompressionStream});
for(const name of ['index.pck','index.wasm']){
 const tracker={loaded:0,done:false};
 const response=wrap(await window.fetch(name),tracker);
 const hash=crypto.createHash('sha256');let count=0;
 for await(const data of response.body){hash.update(data);count+=data.length;}
 const expected=inventory.sourceFiles.find(entry=>entry.name===name);
 assert.equal(count,expected.size);assert.equal(hash.digest('hex'),expected.sha256);assert.equal(tracker.loaded,count);assert.equal(tracker.done,true);
 console.log('PASS '+name+': complete native gzip decode + exact Godot progress wrapper, byte count/SHA256/progress identity.');
}
const wasm=await WebAssembly.compileStreaming(wrap(await window.fetch('index.wasm'),{loaded:0,done:false}));
assert.ok(wasm instanceof WebAssembly.Module);assert.equal(events.length,0);
console.log('PASS application/wasm streaming compilation in Node; this is transport/compiler validation, not browser gameplay.');
