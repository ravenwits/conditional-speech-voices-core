import { existsSync } from "node:fs";
import { fileURLToPath, URL } from "node:url";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig, type ProxyOptions } from "vite";

const root = fileURLToPath(new URL("..", import.meta.url));
const core = existsSync(root + "/Contents/mods") ? "../Contents/mods" : "../mods";
const tools = core + "/ConditionalSpeechVoicesCore/authoring/tools";

const devHost = "127.0.0.1";
const devPort = 5173;
const devAddress = `${devHost}:${devPort}`;
const apiOrigin = process.env.STUDIO_API_ORIGIN || "http://127.0.0.1:46487";
const apiRoutes = "^/(?:session|project|projects|recording-list|schema|duration|audio|import|save|review|undo-review|metadata|update|jobs|process|create|remove-project|open|open-pack|browse-pack-folders|measure|package)(?:[?]|$)|^/studio/(?:flag|cover)/";

const workbenchProxy: ProxyOptions = {
  target: apiOrigin,
  changeOrigin: true,
  bypass(request) {
    const { host, origin } = request.headers;
    if (host !== devAddress || (origin && origin !== `http://${devAddress}`)) return false;
  },
  configure(proxy) {
    proxy.on("proxyReq", (outgoing, incoming) => {
      if (incoming.headers.origin) outgoing.setHeader("Origin", apiOrigin);
    });
  },
};

export default defineConfig(({ command }) => ({
  plugins: [tailwindcss()],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
      "@studio-languages": fileURLToPath(new URL(tools + "/artwork/language-names.json", import.meta.url)),
    },
  },
  base: command === "serve" ? "/" : "/studio/",
  server: {
    host: devHost,
    port: devPort,
    strictPort: true,
    cors: false,
    watch: { usePolling: true },
    proxy: { [apiRoutes]: workbenchProxy },
  },
  build: { outDir: tools + "/studio", emptyOutDir: true, assetsInlineLimit: 0 },
}));
