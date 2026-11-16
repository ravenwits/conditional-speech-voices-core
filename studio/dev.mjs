import { spawn, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const launcher = fileURLToPath(new URL(
  "../Contents/mods/ConditionalSpeechVoicesCore/authoring/tools/launch_studio.py",
  import.meta.url,
));
const args = ["-B", launcher, "--dev"];
if (process.env.WSL_DISTRO_NAME && !process.argv.includes("--project") && !process.argv.includes("--projects")) {
  const profile = spawnSync("cmd.exe", ["/c", "echo %USERPROFILE%"], { encoding: "utf8", timeout: 5000 });
  if (profile.status === 0) {
    const home = spawnSync("wslpath", ["-u", profile.stdout.trim()], { encoding: "utf8", timeout: 5000 });
    if (home.status === 0) {
      const projects = join(home.stdout.trim(), "Zomboid", "VoiceProjects");
      if (existsSync(projects)) args.push("--projects", projects);
    }
  }
}

const children = new Set();
let stopping = false;
function stop(code) {
  if (stopping) return;
  stopping = true;
  process.exitCode = code;
  for (const child of children) child.kill();
  setTimeout(() => {
    for (const child of children) child.kill("SIGKILL");
  }, 3000).unref();
}

function start(command, options, stdio, env = process.env) {
  const child = spawn(command, options, { stdio, env });
  children.add(child);
  child.on("error", (error) => {
    console.error(error.message);
    children.delete(child);
    stop(1);
  });
  child.on("exit", (code) => {
    children.delete(child);
    stop(code ?? 1);
  });
  return child;
}

process.on("SIGINT", () => stop(130));
process.on("SIGTERM", () => stop(143));

const python = process.env.STUDIO_PYTHON || (process.platform === "win32" ? "python" : "python3");
const api = start(python, [...args, ...process.argv.slice(2)], ["ignore", "pipe", "inherit"]);
let startup = "";
api.stdout.setEncoding("utf8");
api.stdout.on("data", (chunk) => {
  process.stdout.write(chunk);
  if (stopping || startup === null) return;
  startup += chunk;
  const address = startup.match(/^http:\/\/127\.0\.0\.1:\d+\//m);
  if (!address) return;
  startup = null;
  const vite = fileURLToPath(new URL("./node_modules/vite/bin/vite.js", import.meta.url));
  start(process.execPath, [vite], "inherit", {
    ...process.env,
    STUDIO_API_ORIGIN: new URL(address[0]).origin,
  });
});
