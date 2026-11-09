"""Validate a built provider with the actual Core registry. No audio playback."""
import argparse, json, os, shutil, subprocess, tempfile
from pathlib import Path

def verify(pack, core):
    shared=pack.resolve()/'42/media/lua/shared'
    providers=list((shared/'CSV_Packs').glob('*.lua'))
    if not providers: raise ValueError('No provider modules found')
    lua=os.environ.get('LUA') or shutil.which('lua5.1') or shutil.which('luajit')
    nvim=os.environ.get('NVIM') or shutil.which('nvim')
    if not lua and not nvim: raise ValueError('Install Lua 5.1 or Neovim for runtime validation')
    quote=lambda p: json.dumps(str(p).replace('\\','/'))
    script='package.path='+quote(core.resolve()/'42/media/lua/shared/?.lua')+"..';'.."+quote(shared/'?.lua')+"..';'..package.path\nlocal R=require 'CSV/Registry'\n"
    for provider in providers:
        script+='R.register('+quote(provider.stem)+',require('+quote('CSV_Packs/'+provider.stem)+'))\n'
    script+='print("PASS runtime registry")\n'
    with tempfile.TemporaryDirectory() as temp:
        path=Path(temp)/'verify.lua';path.write_text(script,encoding='utf-8')
        result=subprocess.run(([lua] if lua else [nvim,'-i','NONE','--headless','-l'])+[str(path)],capture_output=True,text=True,encoding='utf-8',errors='replace')
    output=result.stdout+result.stderr
    if result.returncode or 'PASS runtime registry' not in output or 'E511' in output: raise ValueError(output)
    return output
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('pack',type=Path);p.add_argument('core',type=Path);a=p.parse_args();print(verify(a.pack,a.core))
