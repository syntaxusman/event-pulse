// Production build for the Node server (Docker/Coolify and the E2E suite).
// Plain `npm run build` keeps Lovable's default Cloudflare target; this sets the Node preset the
// Dockerfile uses, on any OS.
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const vite = fileURLToPath(new URL("../node_modules/vite/bin/vite.js", import.meta.url));
const { status } = spawnSync(process.execPath, [vite, "build", ...process.argv.slice(2)], {
  stdio: "inherit",
  env: { ...process.env, NITRO_PRESET: "node-server" },
});
process.exit(status ?? 1);
