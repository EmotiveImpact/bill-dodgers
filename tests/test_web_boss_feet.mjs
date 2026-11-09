// Executes the shipped boss/ability functions against isolated, deterministic
// fixtures. No DOM, rendering, teleported gameplay run, or balance assertion.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
function fn(source,name){const start=source.indexOf('function '+name+'(');assert.ok(start>=0,name);let pos=source.indexOf('{',start),depth=1;const begin=pos;while(depth){pos++;if(source[pos]==='{')depth++;else if(source[pos]==='}')depth--;assert.ok(pos<source.length,name+' closes');}return source.slice(start,pos+1);}
function declaration(source,name){const line=source.split('\n').find(line=>line.trimStart().startsWith('const '+name+' = '));assert.ok(line,name);return line.trim();}
function fixture(source,world){
 const p={k:'maya',x:3500,y:0,face:1,onG:true,vy:0,pops:0,cd:200};
 const state={GROUND:520,WORLD_W:4000,WV:740,VH:540,cam:3260,camY:0,camLock:null,boss:null,banner:null,bossMusic:false,jar:null,levelT:0,
 players:[p],bots:[],foes:[],fliers:[],bills:[],shots:[],crates:[],items:[],coins:[],fees:[],parts:[],floats:[],CFG:{water:490},LV:{king:true},META:{txt:{}},CH:Object.fromEntries(['jp','maya','ama','leo','theo','mei'].map(k=>[k,{shot:'coin',name:k}])),AB:{t:0,fx:[]},RAINBOW:['#fff'],
 SFX:new Proxy({},{get:()=>()=>{}}),FOES:{jet:{spawn(){}},ring:{spawn(){}}},pow:()=>1,charH:()=>180,sfx(){},puff(){},burst(){},playMusic(){},say(){},shakeIt(){},bits(){},dropCoins(){},floatTxt(){},killBot(){},foeDie(){},makeBot(){},spawnFlier(){},hurtPlayer(){},w6Hit:()=>false,insideWall:()=>false,landOn:()=>null,viewTop:()=>0,fallY:()=>10000,rnd:(a,b)=>(a+b)/2,below:()=>({top:520}),setTimeout(){},bossDown(){this.boss.state='down';},alive:()=>[p],nearest:()=>p};
 const context=vm.createContext(state);
 const functions=world===4?['startW4Boss','bossBox','bossShot','updateW4Boss','w4BossDown']:world===5?['kingShape','startKing','setPhase','kingHurt','updateKing','updateShots']:['startBoss','bossHitTest','bossHurt','updateBoss','bossAttack','updateShots'];
 let code=world===5?declaration(source,'KING')+'\n':'';
 code+=functions.map(name=>fn(source,name)).join('\n');
 code+='\n'+['zap','bubbleAll','specialTick','pound','ballTick'].map(name=>fn(source,name)).join('\n');
 code+='\n'+['feet','live','inView','bossOn','hitBot','hitBoss'].map(name=>declaration(source,name)).join('\n');
 vm.runInContext(code,context);state.W5={kingHurt:state.kingHurt};
 vm.runInContext(world===4?'startW4Boss()':world===5?'startKing()':'startBoss()',context);
 return {state,context,p,run:code=>vm.runInContext(code,context)};
}
let checked=0;
for(const world of [4,5,6])for(const stage of ['1','2','3','4','5','6','S']){
 const source=readFileSync(new URL(`../game/${world}-${stage}/index.html`,import.meta.url),'utf8');const f=fixture(source,world),b=f.state.boss;
 assert.equal(b.fy,520);assert.ok(Number.isFinite(b.fy));
 b.x=3500;b.state=world===6?'fight':'walk';
 // All phase gates still use the source collision code. Helpers produce a
 // target shot, not bypass damage/armor or inventing special damage multipliers.
 for(const phase of (world===5?[0,1,2]:[1,2,3])){
  if(world===5)f.run(`setPhase(${phase})`);else b.phase=phase;
  b.hp=100;b.dizzy=0;b.armour=false;b.yo=0;
  f.state.shots=[];f.run('hitBoss(3,players[0])');const shot=f.state.shots[0];assert.ok(Number.isFinite(shot.y));assert.equal(shot.y,b.fy-120);
  const before=b.hp;if(world===4)f.state.bossShot(shot,shot.x-1);else f.state.updateShots(0);
  assert.equal(before-b.hp,1,`${world}-${stage} phase ${phase}: body hit stays one`);
  if(world===5){b.armour=true;f.state.shots=[];f.run('hitBoss(3,players[0])');const hp=b.hp;f.state.updateShots(0);assert.equal(b.hp,hp,'King armor rejects helper hits');b.armour=false;}
 }
 if(world===4){
  b.phase=3;b.hp=100;f.state.bossShot({x:b.x+70,y:b.y-120,owner:f.p},b.x+69);assert.equal(b.hp,97,'Captain endpoint valve remains triple');
  b.state='down';b.t=0;f.state.updateW4Boss(100);assert.equal(b.fy,b.y);assert.equal(b.fy,523,'Captain sinking feet follow y');b.y=520;
 }else if(world===5){
  b.hp=100;b.dizzy=200;f.state.shots=[{x:b.x,y:b.crownY-1,vx:0,vy:0,t:1,owner:f.p}];f.state.updateShots(0);assert.equal(b.hp,96,'King dizzy crown stays four');
  b.state='collapse';b.t=2300;f.state.updateKing(1);assert.equal(b.state,'rebuild');assert.equal(b.fy,520);
 }else{
  for(const state of ['fight','down']){b.state=state;b.t=0;b.yo=-180;b.dizzy=100;b.at=0;b.hp=b.max*0.5;f.state.updateBoss(16);assert.equal(b.fy,520+b.yo,'Sir Charge live feet in '+state);}
  b.state='fight';b.yo=-180;b.hp=b.max*0.5;b.dizzy=0;b.at=0;b.feeT=b.mailT=10000;f.state.updateBoss(16);assert.equal(b.fy,520+b.yo,'Sir Charge floating feet');
  b.hp=100;b.dizzy=200;f.state.shots=[];f.run('hitBoss(3,players[0])');f.state.updateShots(0);assert.equal(b.hp,98,'Sir Charge dizzy body stays two');b.yo=0;
 }
 // Exercise the actual shared Maya shield, Ama bubble, ground-pound and Theo
 // ball predicates that previously produced NaN or missed the boss entirely.
 b.hp=100;b.state=world===6?'fight':'walk';b.dizzy=0;b.armour=false;f.p.x=b.x;f.p.y=b.fy-520;
 for(const action of ['specialTick(players[0],{sp:"maya",bossT:0},16,{})','bubbleAll(players[0])','pound(players[0])','ballTick({p:players[0],x:boss.x,y:boss.fy-120,vx:0,vy:0,t:0,life:3600,spin:0,free:180,trail:[]},0)']){
  f.state.shots=[];f.run(action);assert.ok(f.state.shots.length>0,action);assert.ok(f.state.shots.every(s=>Number.isFinite(s.x)&&Number.isFinite(s.y)),action+' finite');
 }
 // These three branches did not use boss.fy and remain finite/unchanged.
 for(const kind of ['jp','leo','mei']){f.p.k=kind;f.state.shots=[];f.run(`specialTick(players[0],{sp:'${kind}',next:0,k:0,spT0:1000,gy0:520},16,{})`);assert.ok(f.state.shots.every(s=>Number.isFinite(s.x)&&Number.isFinite(s.y)));}
 b.state='down';f.state.shots=[];f.run('bubbleAll(players[0])');assert.equal(f.state.shots.length,0,'down boss is not targeted');
 if(world===6){b.state='fight';b.yo=-180;f.p.y=0;f.state.shots=[];f.run('pound(players[0])');assert.equal(f.state.shots.length,0,'airborne boss remains outside pound reach');}
 f.state.players.push({...f.p,k:'ama'});f.run(world===4?'startW4Boss()':world===5?'startKing()':'startBoss()');
 assert.equal(f.state.boss.max,world===4?120:world===5?34:150,'paired starting HP unchanged');assert.ok(Number.isFinite(f.state.boss.fy));
 checked++;
}
console.log(`PASS: ${checked} boss controller copies; live feet/sink/float/down; source phase, armor, valve/crown/dizzy damage; actual shared ability targeting.`);
