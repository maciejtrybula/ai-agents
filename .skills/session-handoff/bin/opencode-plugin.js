'use strict';

// OpenCode plugin glue for the session-handoff skill.
//
// Snapshots the mechanical handoff when OpenCode compacts a session or the
// server (re)connects, so no work is lost when the window closes.
//
// Constraints honored here:
//   - Never throws, never blocks the main process: everything is wrapped in
//     try/catch, the spawned child is `detached:false` AND `.unref()`ed so it
//     never keeps the main process alive, and all console output goes to
//     stderr only when SESSION_HANDOFF_DEBUG is set (stdout stays clean).
//   - Spawn-race guard: on connect/compact with no session id and no opencode
//     transcript store yet, there is nothing to snapshot, so we do not spawn.
//   - The plugin is copied alongside the skill (same directory as
//     context-autohandoff.sh). We resolve the wrapper relative to THIS file
//     first, then fall back to a `.skills/session-handoff` walk up from
//     process.cwd() so the file also works from an un-copied repo checkout.
//   - Session id: taken from ctx/event when exposed, otherwise left to the
//     lib/paths.sh fallback scan (opencode session store).
//
// Module format: plain CommonJS (`module.exports`). This passes `node --check`
// and `require()` on stock Node (the smoke path), and OpenCode's Bun host
// loads it fine -- Bun's `import()` of a CJS module yields
// default === module.exports, which OpenCode reads as the plugin factory.
// Smoke:  node --check bin/opencode-plugin.js
//         node -e 'const m=require("./bin/opencode-plugin.js"); ...'

const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');
const { spawn } = require('node:child_process');

// OpenCode emits these types on compaction / (re)connect / session start.
const SNAPSHOT_EVENTS = new Set([
  'session.compacted',
  'experimental.session.compacting',
  'server.connected',
]);

// --- path resolution ----------------------------------------------------------

// Absolute path of the shell wrapper, or null if not resolvable.
function resolveHandoffScript() {
  // 1) Copied slot: wrapper sits next to this file.
  try {
    const candidate = path.join(__dirname, 'context-autohandoff.sh');
    if (fs.existsSync(candidate)) return candidate;
  } catch (_e) {
    /* keep trying */
  }
  // 2) Repo checkout / relocated tree: walk up from process.cwd().
  try {
    let dir = process.cwd();
    for (let i = 0; i < 64; i++) {
      const hit = path.join(dir, '.skills', 'session-handoff', 'bin', 'context-autohandoff.sh');
      if (fs.existsSync(hit)) return hit;
      const parent = path.dirname(dir);
      if (parent === dir) break;
      dir = parent;
    }
  } catch (_e) {
    /* unreachable dir */
  }
  return null;
}

// OpenCode transcript root, mirroring lib/paths.sh's opencode case.
function opencodeDataRoot() {
  if (process.env.XDG_DATA_HOME) return path.join(process.env.XDG_DATA_HOME, 'opencode');
  return path.join(os.homedir(), '.local', 'share', 'opencode');
}

// True when the opencode session store has at least one session with messages
// (guards the spawn race where server.connected fires before any session
// exists). Bounded, non-throwing, best-effort.
function hasAnyTranscript() {
  const root = opencodeDataRoot();
  try {
    if (!fs.existsSync(root)) return false;
    const top = fs.readdirSync(root);
    const meaningful = (dir) => {
      try {
        return fs.readdirSync(dir).filter((n) => n !== 'info').length > 0;
      } catch (_e) {
        return false;
      }
    };
    if (top.includes('session') && meaningful(path.join(root, 'session'))) return true;
    if (top.includes('project')) {
      let projects = [];
      try {
        projects = fs.readdirSync(path.join(root, 'project'));
      } catch (_e) {
        projects = [];
      }
      for (const p of projects) {
        if (meaningful(path.join(root, 'project', p, 'storage', 'session'))) return true;
      }
    }
  } catch (_e) {
    return false;
  }
  return false;
}

// --- ctx/event extraction -----------------------------------------------------

function deriveCwd(ctx, evt) {
  const buckets = [evt, ctx];
  for (const obj of buckets) {
    if (!obj || typeof obj !== 'object') continue;
    if (typeof obj.directory === 'string' && obj.directory) return obj.directory;
    if (typeof obj.cwd === 'string' && obj.cwd) return obj.cwd;
    if (typeof obj.workspace === 'string' && obj.workspace && fs.existsSync(obj.workspace)) {
      return obj.workspace;
    }
    if (obj.workspace && typeof obj.workspace === 'object') {
      for (const k of ['current_dir', 'path', 'dir', 'cwd']) {
        if (typeof obj.workspace[k] === 'string' && obj.workspace[k]) return obj.workspace[k];
      }
    }
    if (obj.session && typeof obj.session === 'object' && !Array.isArray(obj.session)) {
      for (const k of ['cwd', 'directory']) {
        if (typeof obj.session[k] === 'string' && obj.session[k]) return obj.session[k];
      }
    }
  }
  return process.cwd();
}

function deriveSessionId(ctx, evt) {
  const buckets = [evt, ctx];
  for (const obj of buckets) {
    if (!obj || typeof obj !== 'object') continue;
    const props = obj.properties && typeof obj.properties === 'object' ? obj.properties : null;
    if (props) {
      for (const k of ['sessionID', 'sessionId', 'session_id', 'id']) {
        if (typeof props[k] === 'string' && props[k]) return props[k];
      }
    }
    if (typeof obj.session === 'string' && obj.session) return obj.session;
    if (obj.session && typeof obj.session === 'object' && !Array.isArray(obj.session)) {
      for (const k of ['id', 'sessionID', 'sessionId', 'session_id', 'uuid']) {
        if (typeof obj.session[k] === 'string' && obj.session[k]) return obj.session[k];
      }
    }
  }
  return '';
}

// --- spawning ----------------------------------------------------------------

// Spawn context-autohandoff.sh with the merged env. Returns true when a child
// was spawned. Never throws.
function spawnHandoff({ cwd, sessionId }) {
  const script = resolveHandoffScript();
  if (!script) {
    if (process.env.SESSION_HANDOFF_DEBUG) console.error('[session-handoff] no context-autohandoff.sh found; skipping');
    return false;
  }
  const env = Object.assign({}, process.env, { SESSION_HANDOFF_PLATFORM: 'opencode' });
  if (sessionId) env.OPENCODE_SESSION_ID = sessionId;
  if (cwd) env.SESSION_HANDOFF_PROJECT_DIR = cwd;
  try {
    const child = spawn('bash', [script], {
      env,
      cwd: cwd || process.cwd(),
      stdio: 'ignore', // wrapper is silent on success; never pollute stdout
      detached: false,
    });
    child.unref();
    if (process.env.SESSION_HANDOFF_DEBUG) console.error('[session-handoff] spawned', script);
    return true;
  } catch (err) {
    if (process.env.SESSION_HANDOFF_DEBUG) console.error('[session-handoff] spawn failed:', err && err.message);
    return false;
  }
}

// Debounce so a compact+compacting pair (or rapid session changes) only
// produces one snapshot per second.
let lastSpawnAt = 0;

function fireOnce(type, ctx, evt) {
  const cwd = deriveCwd(ctx, evt);
  const sessionId = deriveSessionId(ctx, evt);
  // Spawn-race guard: no session and no transcript store -> nothing to snapshot.
  if (!sessionId && !hasAnyTranscript()) return false;
  const now = Date.now();
  if (now - lastSpawnAt < 1000) return false;
  lastSpawnAt = now;
  return spawnHandoff({ cwd, sessionId });
}

// --- plugin spec --------------------------------------------------------------

const Plugin = async (ctx) => ({
  event: async ({ event: evt } = {}) => {
    try {
      if (!evt || typeof evt !== 'object' || typeof evt.type !== 'string') return;
      if (!SNAPSHOT_EVENTS.has(evt.type)) return;
      fireOnce(evt.type, ctx, evt);
    } catch (err) {
      if (process.env.SESSION_HANDOFF_DEBUG) console.error('[session-handoff] event handler error:', err && err.message);
    }
  },
});

// CommonJS exports: the plugin factory is the module itself (module.exports)
// and is also exposed as .default / .Plugin so both bun `import()` and node
// `require()` consumers get the same object. Helpers are exported for tests.
module.exports = Plugin;
module.exports.Plugin = Plugin;
module.exports.default = Plugin;
module.exports.resolveHandoffScript = resolveHandoffScript;
module.exports.spawnHandoff = spawnHandoff;
module.exports.deriveCwd = deriveCwd;
module.exports.deriveSessionId = deriveSessionId;
module.exports.hasAnyTranscript = hasAnyTranscript;
module.exports.opencodeDataRoot = opencodeDataRoot;
