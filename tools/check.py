"""Standalone Core checks. Requires Python 3 and Lua 5.1 or LuaJIT."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
CORE = ROOT / "Contents/mods/ConditionalSpeechVoicesCore"
lua = os.environ.get("LUA") or shutil.which("lua5.1") or shutil.which("luajit") or shutil.which("lua")
nvim = os.environ.get("NVIM")
if lua:
    command = [lua]
elif nvim:
    command = [nvim, "-i", "NONE", "--headless", "-l"]
else:
    raise SystemExit("Install Lua 5.1 or set LUA to its executable.")

def run(path):
    result = subprocess.run(command + [str(path)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    output = result.stdout + result.stderr
    print(output.strip())
    if result.returncode or "E5113" in output or "stack traceback" in output or "PASS" not in output:
        raise SystemExit("Failed: " + str(path))

files = sorted(CORE.rglob("*.lua"))
with tempfile.TemporaryDirectory() as directory:
    syntax = Path(directory) / "syntax.lua"
    syntax.write_text("\n".join("assert(loadfile(" + json.dumps(str(f.relative_to(ROOT)).replace("\\", "/")) + "))" for f in files) + '\nprint("PASS Lua syntax")\n', encoding="utf-8")
    run(syntax)
locales = list(CORE.glob("42/media/lua/shared/Translate/*/UI.json"))
for path in locales:
    json.loads(path.read_text(encoding="utf-8-sig"))
form = json.loads((ROOT / ".github/ISSUE_TEMPLATE/bug-report.yml").read_text(encoding="utf-8"))
ids = [item["id"] for item in form["body"] if "id" in item]
assert len(ids) == len(set(ids)) and len(ids) == 5
assert not list(CORE.rglob("*.mp3")), "Core must not bundle voice recordings"
for test in sorted((ROOT / "tests").glob("*.lua")):
    run(test.relative_to(ROOT))
for test in sorted((ROOT / "tests").glob("*.py")):
    subprocess.run([sys.executable, str(test)], check=True)
print(f"PASS {len(files)} Lua files parsed, {len(locales)} locale files, issue form and isolated Core tests")
