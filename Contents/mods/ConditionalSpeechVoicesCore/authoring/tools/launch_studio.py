"""Double-click entry point. Uses installed Python and FFmpeg; never installs tools."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True

def update_checkout():
    """Only fast-forward the official, clean checkout. Offline use remains available."""
    import os
    if os.environ.get('CSV_STUDIO_UPDATED') == '1': return
    root=next((p for p in Path(__file__).resolve().parents if (p/'.git').exists()),None)
    if root is None or not shutil.which('git'):
        print('Automatic updates require a Git clone of the Core repository.')
        return
    def git(*args):
        return subprocess.run(['git','-C',str(root),*args],capture_output=True,text=True,timeout=30,check=True).stdout.strip()
    try:
        remote=git('remote','get-url','origin').removesuffix('.git')
        if remote not in ('https://github.com/ravenwits/conditional-speech-voices-core','git@github.com:ravenwits/conditional-speech-voices-core'): return
        if git('status','--porcelain'):
            print('Local source changes found. Automatic update skipped; your changes are untouched.')
            return
        branch=git('symbolic-ref','--short','HEAD')
        if git('rev-parse','--abbrev-ref','@{upstream}') != 'origin/'+branch: return
        before=git('rev-parse','HEAD')
        git('fetch','origin',branch)
        git('merge','--ff-only','origin/'+branch)
        if git('rev-parse','HEAD') != before:
            print('Core and Studio updated. Restarting Studio.')
            raise SystemExit(subprocess.call([sys.executable,str(Path(__file__).resolve()),*sys.argv[1:]],env={**os.environ,'CSV_STUDIO_UPDATED':'1'}))
    except (OSError,subprocess.SubprocessError):
        print('Update unavailable. Using the installed Core and Studio.')

def prerequisites(ffmpeg=None):
    if sys.version_info < (3,11): raise ValueError("Python 3.11 or newer is required.")
    executable=ffmpeg or shutil.which('ffmpeg')
    if not executable: raise ValueError("FFmpeg is required. Add ffmpeg.exe to PATH, then start Studio again.")
    result=subprocess.run([str(executable),'-version'],capture_output=True,timeout=10)
    if result.returncode: raise ValueError("FFmpeg could not start. Check its installation.")
    return str(executable)

def workspace(root):
    from prepare_voice_pack import initialize
    path=Path(root)/'my_voice'/'project.json'
    fresh=not path.exists()
    if fresh: initialize(path,'my_voice','EN')
    return path,fresh

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',type=Path)
    parser.add_argument('--ffmpeg')
    parser.add_argument('--projects',type=Path,default=Path.home()/'Zomboid'/'VoiceProjects')
    args=parser.parse_args()
    try:
        update_checkout()
        ffmpeg=prerequisites(args.ffmpeg)
        manifest,fresh=(args.project,False) if args.project else workspace(args.projects)
        from voice_workbench import make_server
        import webbrowser
        server,url=make_server(manifest,ffmpeg,Path(__file__).resolve().parents[2])
        print("CONDITIONAL SPEECH VOICES STUDIO")
        print("Keep this window open. Close it or press Ctrl+C when finished.")
        print(url,flush=True)
        webbrowser.open(url+('?new=1' if fresh else ''))
        try: server.serve_forever()
        except KeyboardInterrupt: pass
        finally: server.server_close()
        return 0
    except (ValueError,OSError,subprocess.SubprocessError) as error:
        print(f"Studio could not start: {error}",file=sys.stderr)
        return 1

if __name__=='__main__': raise SystemExit(main())
