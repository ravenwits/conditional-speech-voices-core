"""Exercise the distributed local authoring workflow."""
from pathlib import Path
import subprocess
import sys
root=Path(__file__).resolve().parents[1]
subprocess.run([sys.executable,"-B","-m","unittest","discover","-s",str(root/"Contents/mods/ConditionalSpeechVoicesCore/authoring/tests"),"-v"],check=True)
