#!/usr/bin/env python3
"""Original Bill Dodgers mobile score. No recordings, samples or copied tunes.

Build: python3 scripts/compose_soundtrack.py [--only world1] [--masters /tmp/bd-score]
Requires numpy, scipy and ffmpeg. Writes compact stereo Vorbis plus composition,
provenance and measured QA in godot/assets/music/score_manifest.json. Music is
composed as explicit notes; randomness only gives deterministic percussion texture.
"""
from __future__ import annotations
import argparse, hashlib, json, math, subprocess, tempfile
from pathlib import Path
import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'godot/assets/music'
RATE = 44100
TAU = 2 * math.pi
# Related five-note call: tonic, ninth, fifth, sixth, third. New melody, not the
# web game's C-Am-F-G lead. Six world arrangements share its rhythmic identity.
# Each phrase specifies (eighth-note position, scale degree, duration in eighths).
CALL = [(0,0,1.3),(1.5,1,.7),(3,4,1.4),(5,5,.8),(6.5,2,1.25)]
ANSWER = [(0,1,1),(2,2,.75),(3.5,4,.75),(5,3,1),(6.5,1,1.2)]
LIFT = [(0,4,.8),(1.5,5,.8),(3,7,1.5),(5,6,.8),(6.5,4,1.2)]
HOME = [(0,3,1.1),(2,2,1),(3.5,1,.75),(5,4,.8),(6.5,0,1.4)]
BRIDGE = [(0,5,1.5),(2.5,4,.75),(4,2,1.2),(6,1,1.5)]
TURN = [(0,3,.75),(1,4,.75),(2.5,5,1),(4,4,.75),(5.5,1,.75),(7,-1,.7)]
MAJOR = [0,2,4,5,7,9,11]
DORIAN = [0,2,3,5,7,9,10]
MINOR = [0,2,3,5,7,8,10]
# Chords explicitly voice the major/natural-minor scale by degree. No generated
# imitation of any named composer, artist, game or commercial recording.
CUES = {
 'title': dict(title='House Kitty Heroes',bpm=132,key=62,scale=MINOR,style='street',lead='brass',bars=32,seed=1001),
 'select': dict(title='Pick Your Friend',bpm=118,key=65,scale=MAJOR,style='home',lead='keys',bars=16,seed=1012),
 'map': dict(title='The Island',bpm=104,key=67,scale=MAJOR,style='holiday',lead='mallet',bars=24,seed=1013),
 'story': dict(title='The Kitty Is Gone',bpm=90,key=57,scale=MINOR,style='story',lead='pluck',bars=16,seed=1014),
 'cutscene': dict(title='Comic Panels',bpm=96,key=60,scale=MAJOR,style='underscore',lead='keys',bars=16,seed=1015),
 'party': dict(title='Housemates Night In',bpm=124,key=70,scale=MAJOR,style='moving',lead='chip',bars=24,seed=1016),
 'gameover': dict(title='Skint',bpm=70,key=60,scale=MINOR,style='gameover',lead='brass',bars=2,seed=1017,loop=False),
 'ending': dict(title='Split It Fairly',bpm=112,key=62,scale=MAJOR,style='home',lead='brass',bars=32,seed=1018,loop=False),
 'world1': dict(title='Streetwise Housemates',bpm=132,key=65,scale=MINOR,style='street',lead='chip',bars=32,seed=1002),
 'world2': dict(title='Aisle Be Back',bpm=120,key=63,scale=MAJOR,style='shop',lead='keys',bars=32,seed=1003),
 'world3': dict(title='Housemates in the Field',bpm=130,key=67,scale=MAJOR,style='festival',lead='brass',bars=32,seed=1004),
 'world4': dict(title='Carry-On Sunshine',bpm=118,key=69,scale=MAJOR,style='holiday',lead='mallet',bars=32,seed=1005),
 'world5': dict(title='Pivot! Pivot!',bpm=128,key=70,scale=MAJOR,style='moving',lead='brass',bars=32,seed=1006),
 'world6': dict(title='The Bill Comes Due',bpm=132,key=62,scale=MINOR,style='billing',lead='chip',bars=32,seed=1007),
 'boss': dict(title='Overdue and Outnumbered',bpm=150,key=64,scale=MINOR,style='boss',lead='brass',bars=32,seed=1008),
 'final_boss': dict(title='Sir Charge, Last Notice',bpm=160,key=60,scale=MINOR,style='final',lead='brass',bars=32,seed=1009),
 'bonus': dict(title='Loose Change Chase',bpm=140,key=69,scale=MAJOR,style='bonus',lead='mallet',bars=24,seed=1010),
 'victory': dict(title='Kitty Reclaimed',bpm=130,key=60,scale=MAJOR,style='victory',lead='brass',bars=4,seed=1011,loop=False),
}

def degree(n, key, scale):
    octave, step = divmod(n,7)
    return key + scale[step] + 12*octave

def env(t, duration, attack=.006, decay=4.0, sustain=.0):
    a = np.minimum(1,t/attack)
    e = sustain + (1-sustain)*np.exp(-decay*t/max(duration,.01))
    return a*e*np.minimum(1,np.maximum(0,(duration-t)/.025))

def voice(note, duration, kind, rng):
    t=np.arange(max(1,int(duration*RATE)))/RATE
    f=440*2**((note-69)/12)
    # All tonal oscillators are additive and stop below Nyquist; no naive
    # square/saw aliasing. Soft attack/release avoids note-edge clicks.
    if kind == 'bass':
        x=sum(np.sin(TAU*f*h*t)*a for h,a in [(1,1),(2,.32),(3,.16),(4,.06)])
        return x*env(t,duration,.004,2.4,.22)*.7
    if kind == 'keys':
        x=sum(np.sin(TAU*f*h*t)*a*np.exp(-t*h*1.5) for h,a in [(1,1),(2,.28),(3,.16),(4,.09),(7,.035)])
        return x*env(t,duration,.003,2.5,.08)*.72
    if kind == 'mallet':
        # Synthetic bell/mallet, no sampled instrument or third-party source.
        x=np.sin(TAU*f*t)+.34*np.sin(TAU*f*2*t)*np.exp(-9*t)+.16*np.sin(TAU*f*3.99*t)*np.exp(-17*t)
        return x*env(t,duration,.002,4)*.8
    if kind == 'pluck':
        x=sum(np.sin(TAU*f*h*t)*np.exp(-t*(h+1)*3)/h**1.4 for h in range(1,min(12,int(16000/f))))
        return x*env(t,duration,.002,2.8)*.85
    if kind == 'pad':
        x=np.sin(TAU*f*t)+.2*np.sin(TAU*f*2*t)+.08*np.sin(TAU*f*3*t)
        return x*env(t,duration,.12,1.8,.3)*.6
    if kind == 'brass':
        phase=TAU*f*t + .009*np.sin(TAU*5.4*t)*np.minimum(t*6,1)
        x=sum(np.sin(h*phase)*np.exp(-t*h*.65)/h for h in range(1,min(10,int(15000/f))))
        return x*env(t,duration,.018,1.7,.2)*.7
    # rounded pulse lead, harmonic rolloff keeps small phone speakers comfortable
    x=sum(np.sin(TAU*f*h*t)*np.exp(-h/8)/h for h in range(1,min(16,int(16000/f)),2))
    return x*env(t,duration,.005,2,.15)*.85

class Render:
    def __init__(self, config):
        self.c=config; self.beat=60/config['bpm']; self.loop=config.get('loop',True)
        self.seconds=config['bars']*4*self.beat+(0 if self.loop else 2)
        self.n=round(self.seconds*RATE); self.mix=np.zeros((self.n,2),np.float64)
        self.rng=np.random.default_rng(config['seed']); self.events=[]
    def add(self,data,beat,amp=1,pan=0):
        start=round(beat*self.beat*RATE)
        gains=np.array([math.cos((pan+1)*math.pi/4), math.sin((pan+1)*math.pi/4)])*amp
        stereo=data[:,None]*gains
        if self.loop:
            idx=(start+np.arange(len(data)))%self.n
            self.mix[idx]+=stereo
        else:
            count=min(len(data),self.n-start)
            if count>0:self.mix[start:start+count]+=stereo[:count]
    def note(self,note,beat,length,kind,amp=.1,pan=0):
        self.add(voice(note,length*self.beat,kind,self.rng),beat,amp,pan)
        self.events.append([round(beat,4),note,round(length,4),kind])
    def drum(self,kind,beat,amp=1,pan=0):
        dur={'kick':.3,'snare':.19,'hat':.07,'open':.22,'wood':.085,'shaker':.08,'clap':.16,'tom':.21}[kind]
        t=np.arange(int(dur*RATE))/RATE
        noise=self.rng.standard_normal(len(t))
        if kind=='kick':
            phase=TAU*(45*t+(130-45)*.021*(1-np.exp(-t/.021)))
            x=np.sin(phase)*np.exp(-t*16)+noise*.06*np.exp(-t*180)
        elif kind=='snare':
            high=signal.sosfilt(signal.butter(2,1700,fs=RATE,btype='high',output='sos'),noise)
            x=.45*high*np.exp(-t*32)+.32*np.sin(TAU*185*t)*np.exp(-t*35)
        elif kind in ('hat','open','shaker'):
            high=signal.sosfilt(signal.butter(3,6500,fs=RATE,btype='high',output='sos'),noise)
            x=high*np.exp(-t*(50 if kind=='hat' else 22 if kind=='open' else 36))*.24
        elif kind=='clap':
            high=signal.sosfilt(signal.butter(2,[800,8000],fs=RATE,btype='band',output='sos'),noise)
            e=sum(np.where(t>=s,np.exp(-np.maximum(0,t-s)*70),0) for s in [0,.011,.024])
            x=high*e*.23
        elif kind=='wood':
            x=(np.sin(TAU*820*t)+.55*np.sin(TAU*1277*t))*np.exp(-t*95)*.5
        else:
            phase=TAU*(80*t+60*.028*(1-np.exp(-t/.028)))
            x=np.sin(phase)*np.exp(-t*20)
        x*=np.minimum(1,t/.0015)*np.minimum(1,(dur-t)/.008)
        self.add(x,beat,amp,pan)
    def arrange(self):
        c=self.c; key=c['key']; scale=c['scale']; style=c['style']; bars=c['bars']; aggressive=style in ['billing','boss','final']
        prog=[0,5,1,4,0,3,1,4] if not aggressive else [0,5,3,4,0,3,5,4]
        for bar in range(bars):
            b=bar*4; section=(bar//8)%4; degree_root=prog[bar%8]; root=degree(degree_root,key,scale)
            if style=='victory': root=degree([3,4,0,0][bar],key,scale)
            busy=section in [1,3] or aggressive
            breakdown=(section==2 and bar%8<4 and style not in ['boss','final','bonus']) or style in ['story','underscore','gameover']
            # Full four-part arrangements: theme, developed theme, contrast,
            # return/cadence. Percussion drops in the contrast for breathing room.
            if not breakdown:
                for pos in ([0,1.5,2,3.25] if style in ['festival','boss','final','bonus'] else [0,1.75,2.5]):
                    self.drum('kick',b+pos,.39 if aggressive else .32)
                for pos in [1,3]:
                    self.drum('snare',b+pos,.23)
                    if style in ['festival','bonus','final']:self.drum('clap',b+pos+.012,.14,-.15)
            else:
                self.drum('kick',b,.25); self.drum('wood',b+3,.18,.25)
            for j in range(8):
                swing=.055 if j%2 and style in ['street','shop','moving','home'] else 0
                self.drum('shaker' if style=='holiday' else 'hat',b+j*.5+swing,.42 if j%2 else .25,.3 if j%2 else -.25)
            if busy and bar%4==3:
                for j in range(4):self.drum('tom',b+3+j*.25,.12+j*.02,(j-1.5)*.3)
                self.drum('open',b+3.5,.35,.35)
            # Syncopated bass uses both low fundamental and upper partials, so
            # rhythm remains audible on a mono phone speaker.
            bass=root-24
            while bass>48:bass-=12
            for pos,offset,length in [(0,0,.7),(.75,12,.3),(1.5,7,.4),(2,0,.65),(2.75,12,.3),(3.5,7,.35)]:
                self.note(bass+offset,b+pos,length,'bass',.22 if aggressive else .19)
            # Close, extended chord voicing (root/third/seventh/ninth); restrained
            # upper mid-range leaves action sounds easy to distinguish.
            chord=[degree(degree_root+d,key,scale) for d in [0,2,6,8]]
            chord=[n-12 if n>78 else n for n in chord]
            for pos in ([.5,1.5,2.5,3.5] if style in ['holiday','festival','moving'] else [.75,2.5]):
                for k,n in enumerate(chord): self.note(n,b+pos,.38,'keys' if style!='moving' else 'pluck',.055,(k-1.5)*.2)
            if section==2 or style=='home':
                for k,n in enumerate(chord[:3]):self.note(n-12,b,3.9,'pad',.035,(k-1)*.45)
            # Explicit motif phrases. Long notes answer short calls; every second
            # bar responds rather than presenting uninterrupted arpeggios.
            phrases=[CALL,ANSWER,LIFT,HOME,CALL,BRIDGE,LIFT,TURN]
            phrase=phrases[bar%8]
            if style=='underscore':phrase=BRIDGE[:2] if bar%2==0 else []
            if style=='gameover':phrase=[(0,4,1.8),(2,3,1.8),(4,2,1.8),(6,0,1.8)] if bar==0 else [(0,-3,7)]
            if section==2:phrase=[BRIDGE,HOME,ANSWER,TURN][bar%4]
            transpose=7 if section==3 and bar%8>=4 else 0
            for pos,deg,length in phrase:
                if breakdown and bar%2:continue
                n=degree(deg+transpose,key+12,scale)
                while n>91:n-=12
                self.note(n,b+pos/2,length/2,c['lead'],.115 if c['lead']=='brass' else .125,-.07)
                # Beat-synced quiet stereo echo, wrapped at the musical loop edge.
                self.note(n,b+pos/2+.75,length/2,c['lead'],.020,.48)
                if busy and pos>=5:
                    self.note(degree(deg-2+transpose,key+12,scale),b+pos/2,length/2,'keys',.036,.16)
            # Each setting has a distinct timbral/rhythmic signature.
            if style=='moving':
                for pos in [.5,1.25,2.5,3.75]:self.drum('wood',b+pos,.27,-.3)
            elif style=='holiday':
                for pos,d in [(1.25,2),(2.75,4)]: self.note(degree(degree_root+d,key+12,scale),b+pos,.7,'mallet',.065,.45)
            elif style=='shop':
                for pos,d in [(1.25,6),(3.25,8)]:self.note(degree(degree_root+d,key,scale),b+pos,.25,'mallet',.065,.4)
            elif aggressive:
                for j in range(8):self.note(degree(degree_root+[0,4,2,6][j%4],key,scale),b+j*.5,.22,'pluck',.045,-.4)
        if not self.loop and style!='gameover':
            # Resolved final major-sixth chord and natural tail, no abrupt stop.
            at=(bars-1)*4
            for d in [0,2,4,5]:self.note(degree(d,key+12,MAJOR),at,5.5,'keys',.14,(d-2)*.12)
        return self.master()
    def master(self):
        x=self.mix
        # Tiny circular room/delay field: continuous across the loop boundary.
        wet=np.zeros_like(x)
        for seconds,gain in [(.037,.055),(.061,.04),(.113,.025)]:
            shift=round(seconds*RATE)
            shifted=np.roll(x[:,::-1],shift,axis=0)
            if not self.loop:shifted[:shift]=0
            wet+=shifted*gain
        x=x+wet
        x-=x.mean(axis=0)
        # Mild saturation, not hard clipping. A constant gain, not AGC, preserves
        # arrangement dynamics. Runtime attenuation leaves room for source SFX.
        x=np.tanh(x*1.15)
        rms=np.sqrt(np.mean(x*x))
        x*=min(.125/max(rms,1e-9),.79/max(np.max(np.abs(x)),1e-9))
        if not self.loop:
            fade=round(.8*RATE);x[-fade:]*=np.linspace(1,0,fade)[:,None]
        return x

def encode(name,c,masters):
    render=Render(c);x=render.arrange()
    pcm=np.rint(np.clip(x,-1,1)*32767).astype('<i2')
    wav=masters/f'{name}.wav';wavfile.write(wav,RATE,pcm)
    dest=OUT/f'{name}.ogg'
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','5','-map_metadata','-1','-metadata',f'title={c["title"]}','-metadata','artist=Bill Dodgers Original Score','-metadata','comment=Original composition and synthesized instruments; no external samples',str(dest)],check=True)
    decoded=masters/f'{name}-decoded.wav'
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(dest),'-c:a','pcm_s16le',str(decoded)],check=True)
    sr,check=wavfile.read(decoded);check=check.astype(np.float64)/32768
    edge=float(np.max(np.abs(check[0]-check[-1])))
    # Vorbis decoder trim may return a few fewer end samples. Runtime length and
    # musical seam are measured explicitly rather than assuming encoded accuracy.
    stats=dict(id=name,title=c['title'],bpm=c['bpm'],bars=c['bars'],key_midi=c['key'],scale=c['scale'],loop=render.loop,sample_rate=RATE,channels=2,duration_seconds=render.n/RATE,decoded_samples=len(check),peak_dbfs=round(20*np.log10(np.max(np.abs(check))),2),rms_dbfs=round(20*np.log10(np.sqrt(np.mean(check*check))),2),seam_step=edge,mono_correlation=round(float(np.corrcoef(check.T)[0,1]),4),note_events=len(render.events),size_bytes=dest.stat().st_size,sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),file=f'{name}.ogg')
    assert sr==RATE and check.shape[1]==2 and np.max(np.abs(check))<.999,stats
    assert np.sqrt(np.mean(check*check))>.02,stats
    assert not render.loop or edge<.07,stats
    print(json.dumps(stats),flush=True)
    return stats

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--only',choices=CUES);ap.add_argument('--masters',type=Path,default=Path('/tmp/bill-dodgers-score-masters'));a=ap.parse_args()
    OUT.mkdir(parents=True,exist_ok=True);a.masters.mkdir(parents=True,exist_ok=True)
    path=OUT/'score_manifest.json';old=json.loads(path.read_text()) if path.exists() else {}; tracks={x['id']:x for x in old.get('tracks',[])}
    for name,c in CUES.items():
        if a.only and name!=a.only:continue
        tracks[name]=encode(name,c,a.masters)
    result=dict(version=1,provenance='Original notes and deterministic synthesized instruments composed for Bill Dodgers. No external recordings, samples, named-artist imitation or licensed music used.',toolchain='Python / NumPy / SciPy additive synthesis and ffmpeg Vorbis encoding',runtime_gameplay_gain_db=-18,runtime_screen_gain_db=-9,tracks=[tracks[x] for x in CUES if x in tracks])
    path.write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__': main()
