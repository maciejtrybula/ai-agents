import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
import { existsSync, unlinkSync, readFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));

function loadConfig() {
  const installed = join(here, 'caveman-config.cjs');
  const target = installed;
  const code = readFileSync(target, 'utf8').replace(/^#![^\n]*\n/, '');
  const mod = { exports: {} };
  new Function('module', 'exports', 'require', '__dirname', '__filename', code)(
    mod, mod.exports, createRequire(pathToFileURL(target).href), dirname(target), target
  );
  return mod.exports;
}
const config = loadConfig();

const { getDefaultMode, safeWriteFlag, readFlag } = config;

function loadParse() {
  const installed = join(here, 'caveman-parse.cjs');
  const target = installed;
  const code = readFileSync(target, 'utf8').replace(/^#![^\n]*\n/, '');
  const mod = { exports: {} };
  new Function('module', 'exports', 'require', '__dirname', '__filename', code)(
    mod, mod.exports, createRequire(pathToFileURL(target).href), dirname(target), target
  );
  return mod.exports;
}
const { parseModeChange, INDEPENDENT_MODES } = loadParse();

function opencodeConfigDir() {
  if (process.env.XDG_CONFIG_HOME) {
    return path.join(process.env.XDG_CONFIG_HOME, 'opencode');
  }
  return path.join(os.homedir(), '.config', 'opencode');
}

const flagPath = path.join(opencodeConfigDir(), '.caveman-active');

function reinforcementLine(mode) {
  return 'CAVEMAN MODE ACTIVE (' + mode + ') - session ruleset applies.';
}

function applyModeChange(change) {
  if (!change) return;
  if (change.action === 'clear') {
    try { if (existsSync(flagPath)) unlinkSync(flagPath); } catch (_e) {}
    return;
  }
  if (change.action === 'set' && change.mode) {
    safeWriteFlag(flagPath, change.mode);
  }
}

function handleSessionCreated() {
  const mode = getDefaultMode();
  if (mode === 'off') {
    try { if (existsSync(flagPath)) unlinkSync(flagPath); } catch (_e) {}
    return;
  }
  safeWriteFlag(flagPath, mode);
}

export const CavemanPlugin = async (_ctx) => {
  handleSessionCreated();

  return {
    event: async ({ event } = {}) => {
      if (event && event.type === 'session.created') handleSessionCreated();
    },
    'chat.message': async (_input, output) => {
      if (!output || !output.parts) return;
      for (const part of output.parts) {
        if (part && part.type === 'text' && part.text) {
          const change = parseModeChange(part.text, { getDefaultMode, expandedTpl: true, unwrapQuotes: true });
          if (change) applyModeChange(change);
        }
      }
    },
    'experimental.chat.system.transform': async (_input, output) => {
      if (!output || !Array.isArray(output.system)) return;
      const active = readFlag(flagPath);
      if (active && !INDEPENDENT_MODES.has(active)) {
        output.system.push(reinforcementLine(active));
      }
    },
  };
};

export default CavemanPlugin;
