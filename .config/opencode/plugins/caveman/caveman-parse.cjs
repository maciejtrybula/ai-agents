#!/usr/bin/env node
let cavemanConfig;
try {
  cavemanConfig = require('./caveman-config');
} catch (_e) {
  cavemanConfig = require('./caveman-config.cjs');
}
const { VALID_MODES } = cavemanConfig;

const INDEPENDENT_MODES = new Set(['commit', 'review', 'compress']);

function parseModeChange(promptRaw, options) {
  options = options || {};
  const getDefaultMode = options.getDefaultMode || cavemanConfig.getDefaultMode;

  let prompt = (promptRaw || '').trim();
  if (options.unwrapQuotes) {
    const wrapped = /^("|'|`)([\s\S]*)\1$/.exec(prompt);
    if (wrapped) prompt = wrapped[2].trim();
  }
  const firstLine = prompt.toLowerCase().split(/\r?\n/, 1)[0];
  prompt = prompt.toLowerCase().replace(/\s+/g, ' ');
  if (!prompt) return null;

  const wantsOff = !options.skipNaturalLanguage && (
    /\b(stop|disable|deactivate|quit|exit|kill)\s+(the\s+)?caveman\b/.test(prompt) ||
    /\bcaveman(\s+mode)?\s+(off|stop|disabled?)\b/.test(prompt) ||
    /\bturn\s+off\s+(the\s+)?caveman\b/.test(prompt) ||
    /^(please\s+)?(go\s+|back\s+to\s+|switch\s+(back\s+)?to\s+|return\s+to\s+)?normal\s+mode\b/.test(prompt) ||
    (/\bnormal\s+mode\b/.test(prompt) && /\bcaveman\b/.test(prompt))
  );
  if (wantsOff) return { action: 'clear' };

  if (options.expandedTpl) {
    if (/^generate a commit message for the current staged changes\b/.test(prompt)) {
      return { action: 'set', mode: 'commit' };
    }
    if (/^review the current diff\b/.test(prompt)) {
      return { action: 'set', mode: 'review' };
    }
    if (/^compress the file at:/.test(prompt)) {
      return { action: 'set', mode: 'compress' };
    }
    const tpl = /^activate caveman mode:[ \t]*(\S*)/.exec(firstLine);
    if (tpl) {
      const arg = tpl[1] || '';
      if (!arg) {
        const mode = getDefaultMode();
        return mode === 'off' ? { action: 'clear' } : { action: 'set', mode };
      }
      if (arg === 'off' || arg === 'stop' || arg === 'disable') return { action: 'clear' };
      if (arg === 'wenyan-full') return { action: 'set', mode: 'wenyan' };
      if (VALID_MODES.includes(arg) && !INDEPENDENT_MODES.has(arg)) return { action: 'set', mode: arg };
      return null;
    }
  }

  if (!options.skipNaturalLanguage) {
    const isQuestion =
      /^(what|whats|what's|how|why|when|where|who|does|do|did|is|are|can|could|would|should|tell me|explain)\b/.test(prompt);

    if (!isQuestion) {
      if (/\b(activate|enable|start|turn on|use|switch to|want|give me)\b[^.]{0,40}\bcaveman\b/.test(prompt) ||
          /\btalk like\b[^.]{0,40}\bcaveman\b/.test(prompt) ||
          /\bcaveman\s+mode\s+(on|please|now)\b/.test(prompt) ||
          /^caveman(\s+mode)?\s*[.!]*$/.test(prompt) ||
          /\b(less tokens|fewer tokens|be brief|be terse|shorter answers)\b(?!\s+(in|for|on|about|when|during|with)\b)/.test(prompt)) {
        const mode = getDefaultMode();
        return mode !== 'off' ? { action: 'set', mode } : null;
      }
    }
  }

  if (prompt.startsWith('/caveman')) {
    const parts = prompt.split(/\s+/);
    const cmd = parts[0];
    const arg = parts[1] || '';

    if (cmd === '/caveman-commit' || cmd === '/caveman:caveman-commit') {
      return { action: 'set', mode: 'commit' };
    }
    if (cmd === '/caveman-review' || cmd === '/caveman:caveman-review') {
      return { action: 'set', mode: 'review' };
    }
    if (cmd === '/caveman-compress' || cmd === '/caveman:caveman-compress') {
      return { action: 'set', mode: 'compress' };
    }
    if (cmd === '/caveman' || cmd === '/caveman:caveman') {
      if (!arg) {
        const mode = getDefaultMode();
        return mode === 'off' ? { action: 'clear' } : { action: 'set', mode };
      }
      if (arg === 'off' || arg === 'stop' || arg === 'disable') return { action: 'clear' };
      if (arg === 'wenyan-full') return { action: 'set', mode: 'wenyan' };
      if (VALID_MODES.includes(arg) && !INDEPENDENT_MODES.has(arg)) return { action: 'set', mode: arg };
      return null;
    }
  }

  return null;
}

module.exports = { parseModeChange, INDEPENDENT_MODES };
