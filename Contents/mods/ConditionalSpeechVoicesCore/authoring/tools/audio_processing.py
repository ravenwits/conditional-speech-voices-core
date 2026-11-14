"""Reversible, offline edits of imported takes. Never synthesize speech."""
from array import array
import math
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid
import voice_project as project
import studio_schema
from recording_limits import MAX_SECONDS

def original_duration(manifest,slot,ffmpeg):
    config=project.read(manifest);clip=project.slots(config)[slot]
    edit=config.get('authoring',{}).get('audioEdits',{}).get(slot,{})
    path=project.contained(manifest.parent,edit.get('original') or config['assets'][clip['sound']]['source'])
    raw=subprocess.run([ffmpeg,'-nostdin','-v','error','-i',str(path),'-t',str(MAX_SECONDS+1),'-f','s16le','-ac','1','-ar','8000','pipe:1'],capture_output=True,check=True,timeout=30).stdout
    return len(raw)/16000

def process(manifest,slot,ffmpeg,gain_db=0,semitones=0,restore=False,speed=1,trim_start=0,trim_end=0):
    if isinstance(gain_db,bool) or isinstance(semitones,bool) or isinstance(speed,bool): raise ValueError('Use numeric audio settings')
    gain_db=float(gain_db);semitones=float(semitones);speed=float(speed)
    if not math.isfinite(speed) or not 0.25<=speed<=2: raise ValueError("Speed must be between 0.25 and 2 times")
    if not math.isfinite(gain_db) or not -12<=gain_db<=12: raise ValueError('Gain must be between -12 and +12 dB')
    if not math.isfinite(semitones) or not -4<=semitones<=4: raise ValueError('Pitch must be between -4 and +4 semitones')
    trim_start=float(trim_start);trim_end=float(trim_end)
    if not all(math.isfinite(v) and 0<=v<MAX_SECONDS for v in (trim_start,trim_end)): raise ValueError("Trim must be a finite number of seconds within the recording limit")
    revision=project.digest(manifest);config=project.read(manifest);studio_schema.validate(config)
    clip=project.slots(config).get(slot)
    if not clip: raise ValueError('Unknown Core recording slot')
    asset=config['assets'][clip['sound']];root=manifest.parent
    current=project.contained(root,asset['source'])
    if not current.is_file(): raise ValueError('Import audio before editing it')
    authoring=config.setdefault('authoring',{});edits=authoring.setdefault('audioEdits',{})
    previous=edits.get(slot)
    if previous:
        if project.digest(current)!=previous['renderedHash']: raise ValueError('This take changed outside Studio. Import it again before editing.')
        original=project.contained(root,previous['original'])
        if not original.is_file() or project.digest(original)!=previous['originalHash']: raise ValueError('The preserved original is missing or changed. Import a new take.')
    else: original=current
    if restore: gain_db=0;semitones=0;speed=1;trim_start=0;trim_end=0
    if (not previous and not gain_db and not semitones and speed==1 and not trim_start and not trim_end) or (previous and previous['gainDb']==gain_db and previous['semitones']==semitones and previous.get('speed',1)==speed and previous.get('trimStart',0)==trim_start and previous.get('trimEnd',0)==trim_end):
        return dict(message='These settings are already saved.')
    if trim_start or trim_end:
        if trim_start+trim_end>=original_duration(manifest,slot,ffmpeg): raise ValueError("Trim must leave audio within the original recording")
    original_hash=project.digest(original)
    audio_dir=project.contained(root,'audio');audio_dir.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=audio_dir) as directory:
        temporary=Path(directory)/'edited.mp3'
        if gain_db or semitones or speed!=1 or trim_start or trim_end:
            filters=[]
            if trim_start: filters.extend(["atrim=start="+str(trim_start),"asetpts=PTS-STARTPTS"])
            if trim_end: filters.extend(["areverse","atrim=start="+str(trim_end),"areverse","asetpts=PTS-STARTPTS"])
            if semitones or speed!=1: filters.append('rubberband=tempo='+str(speed)+':pitch='+str(2**(semitones/12)))
            if gain_db: filters.append('volume='+str(gain_db)+'dB')
            raw=subprocess.run([ffmpeg,'-nostdin','-v','error','-i',str(original),'-t',str(MAX_SECONDS+1),'-vn','-ac','1','-ar','44100',
                                '-af',','.join(filters),'-f','f32le','pipe:1'],capture_output=True,check=True,timeout=90).stdout
            samples=array('f');samples.frombytes(raw)
            if not 0<len(samples)<=MAX_SECONDS*44100: raise ValueError(f'Edited recording must be at most {MAX_SECONDS} seconds. Increase speed or use a shorter take.')
            peak=max(abs(sample) for sample in samples)
            if not math.isfinite(peak) or peak<=0: raise ValueError('Recording contains no usable audio')
            if peak>10**(-1/20):
                safe_gain=gain_db+(-1-20*math.log10(peak))
                raise ValueError(f'This gain would leave too little headroom. Try {safe_gain:.1f} dB or lower. Nothing was changed.')
            subprocess.run([ffmpeg,'-nostdin','-v','error','-f','f32le','-ar','44100','-ac','1','-i','pipe:0',
                            '-map_metadata','-1','-codec:a','libmp3lame','-q:a','2',str(temporary)],input=raw,capture_output=True,check=True,timeout=90)
        if project.digest(manifest)!=revision: raise ValueError('Project changed during processing. Reload before applying settings.')
        # Each edit starts from an immutable original. A failed manifest save
        # cannot overwrite the previous active take.
        if not previous:
            preserved=project.contained(root,'originals/'+project.voice_id(config)+'_'+slot+'_'+original_hash[:16]+'.mp3')
            preserved.parent.mkdir(exist_ok=True)
            if not preserved.exists(): shutil.copy2(original,preserved)
            elif project.digest(preserved)!=original_hash: raise ValueError('Preserved original conflicts with this recording')
            original=preserved
        if gain_db or semitones or speed!=1 or trim_start or trim_end:
            target=audio_dir/(project.voice_id(config)+'_'+slot+'_'+uuid.uuid4().hex[:12]+'.mp3')
            temporary.replace(target)
        else: target=original
        asset['source']=target.relative_to(root.resolve()).as_posix()
        clip['duration']=0;config['bank']['peaklimits'].pop(project.voice_id(config)+'_'+slot,None)
        authoring.setdefault('reviews',{}).pop(slot,None);authoring.setdefault('measurements',{}).pop(clip['sound'],None)
        edits[slot]=dict(original=original.relative_to(root).as_posix(),originalHash=original_hash,
                         renderedHash=project.digest(target),gainDb=gain_db,semitones=semitones,speed=speed,trimStart=trim_start,trimEnd=trim_end)
        project.write(manifest,config)
    return dict(message='Original restored. Listen before approving.' if restore else 'Audio settings saved to the recording. Listen before approving.')
