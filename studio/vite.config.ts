import { isIPv4 } from "node:net";
import { existsSync } from "node:fs";
import { fileURLToPath, URL } from "node:url";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig, type Plugin, type ProxyOptions } from "vite";

const root = fileURLToPath(new URL("..", import.meta.url));
const core = existsSync(root + "/Contents/mods") ? "../Contents/mods" : "../mods";
const tools = core + "/ConditionalSpeechVoicesCore/authoring/tools";

const devHost = "127.0.0.1";
const devPort = 5173;
const devAddress = `${devHost}:${devPort}`;
const lanHost = process.env.STUDIO_LAN_HOST;
if (lanHost && !isIPv4(lanHost)) {
  throw new Error("STUDIO_LAN_HOST requires an IPv4 address.");
}
const lanAddress = lanHost && `${lanHost}:${devPort}`;
function lanAccess(): Plugin {
  return {
    name: "studio-lan-access",
    configureServer(server) {
      server.middlewares.use((request, response, next) => {
        const peer = request.socket.remoteAddress;
        if (request.headers.host === devAddress &&
            (peer === "127.0.0.1" || peer === "::1" || peer === "::ffff:127.0.0.1")) return next();
        if (request.headers.host === lanAddress) return next();
        response.writeHead(403);
        response.end("Invalid Studio host.");
      });
    },
  };
}

const apiOrigin = process.env.STUDIO_API_ORIGIN || "http://127.0.0.1:46487";
const apiRoutes = "^/(?:session|project|projects|recording-list|schema|duration|audio|import|save|profanity|review|undo-review|metadata|update|jobs|process|create|remove-project|open|open-pack|browse-pack-folders|measure|package)(?:[?]|$)|^/studio/(?:flag|cover)/|^/(?:dialogue/|elevenlabs/|audio/elevenlabs[?])";

const workbenchProxy: ProxyOptions = {
  target: apiOrigin,
  changeOrigin: true,
  bypass(request) {
    const { host, origin } = request.headers;
    if (!host || (host !== devAddress && host !== lanAddress) || (origin && origin !== `http://${host}`)) return false;
  },
  configure(proxy) {
    proxy.on("proxyReq", (outgoing, incoming) => {
      if (incoming.headers.origin) outgoing.setHeader("Origin", apiOrigin);
      outgoing.removeHeader("Authorization");
    });
  },
};

export default defineConfig(({ command }) => ({
  plugins: [tailwindcss(), ...(command === "serve" && lanHost ? [lanAccess()] : [])],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
      "@studio-languages": fileURLToPath(new URL(tools + "/artwork/language-names.json", import.meta.url)),
    },
  },
  base: command === "serve" ? "/" : "/studio/",
  server: {
    host: devHost,
    hmr: lanHost ? false : undefined,
    port: devPort,
    strictPort: true,
    cors: false,
    watch: { usePolling: true },
    proxy: { [apiRoutes]: workbenchProxy },
  },
  build: { outDir: tools + "/studio", emptyOutDir: true, assetsInlineLimit: 0 },
}));
