#!/usr/bin/env node
// Static checks for the mpv config. Runs here and in .github/workflows/ci.yml:
//   node tools/check-config.mjs
// Lua syntax itself is checked with luac5.1 in CI; everything else (bindings,
// script targets, duplicate options, line endings) is done here so it stays
// dependency-free and also catches the mistakes this repo has shipped before.

import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import { join, dirname, relative, extname } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const cfgDir = join(root, "portable_config");
const scriptsDir = join(cfgDir, "scripts");
const optsDir = join(cfgDir, "script-opts");

const errors = [];
const notes = [];
const fail = (file, line, message) =>
  errors.push(`${relative(root, file)}${line ? `:${line}` : ""}: ${message}`);

// ---------------------------------------------------------------- line endings
const TEXT_EXT = new Set([
  ".lua", ".conf", ".md", ".yml", ".yaml", ".mjs", ".js", ".json",
  ".txt", ".glsl", ".hook", ".gitattributes", ".gitignore", "",
]);
const SKIP_DIRS = new Set([".git", "node_modules", ".freebuff"]);

function walk(dir, out = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name)) continue;
      walk(join(dir, entry.name), out);
    } else {
      out.push(join(dir, entry.name));
    }
  }
  return out;
}

const files = walk(root);
for (const file of files) {
  if (!TEXT_EXT.has(extname(file).toLowerCase())) continue;
  const buf = readFileSync(file);
  if (buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf) {
    fail(file, 1, "UTF-8 BOM (mpv and Lua ignore the first line when it is present)");
  }
  if (buf.includes(0x0d)) {
    const line = buf.subarray(0, buf.indexOf(0x0d)).toString().split("\n").length;
    fail(file, line, "CRLF line ending; this repo is LF-only (see .gitattributes)");
  }
}

// -------------------------------------------------------------------- mpv.conf
const mpvConf = join(cfgDir, "mpv.conf");
const PROFILE_KEYWORDS = new Set(["profile", "profile-desc", "profile-cond", "profile-restore", "include"]);

function balanced(str) {
  const pairs = { ")": "(", "]": "[" };
  const stack = [];
  let quote = null;
  for (const ch of str) {
    if (quote) {
      if (ch === quote) quote = null;
      continue;
    }
    if (ch === '"' || ch === "'") quote = ch;
    else if (ch === "(" || ch === "[") stack.push(ch);
    else if (ch === ")" || ch === "]") {
      if (stack.pop() !== pairs[ch]) return false;
    }
  }
  return stack.length === 0 && quote === null;
}

{
  const lines = readFileSync(mpvConf, "utf8").split("\n");
  let section = "(global)";
  const seen = new Map();

  lines.forEach((raw, i) => {
    const lineNo = i + 1;
    const line = raw.trim();
    if (!line || line.startsWith("#") || line.startsWith(";")) return;
    if (line.startsWith("[")) {
      if (!line.endsWith("]")) fail(mpvConf, lineNo, "unterminated profile header");
      section = line.slice(1, -1).trim();
      return;
    }

    const eq = line.indexOf("=");
    if (eq < 0) {
      fail(mpvConf, lineNo, `expected key=value, got "${line}"`);
      return;
    }
    const key = line.slice(0, eq).trim().toLowerCase();
    const value = line.slice(eq + 1).trim();

    if (value === "" && key !== "profile-cond") {
      fail(mpvConf, lineNo, `option "${key}" has an empty value`);
    }
    if (key === "profile-cond" && !balanced(value)) {
      fail(mpvConf, lineNo, "unbalanced quotes or brackets in profile-cond");
    }
    if (key === "profile-cond" && /\bgoto\b/.test(value)) {
      fail(mpvConf, lineNo, "profile-cond uses goto (needs Lua 5.2, mpv ships LuaJIT/5.1)");
    }

    const id = `${section}\u0000${key}`;
    if (seen.has(id) && !PROFILE_KEYWORDS.has(key)) {
      fail(mpvConf, lineNo, `duplicate option "${key}" in ${section} (already set on line ${seen.get(id)})`);
    } else if (!seen.has(id)) {
      seen.set(id, lineNo);
    }
  });
}

// ------------------------------------------------------------------ input.conf
const MPV_COMMANDS = new Set([
  "add", "cycle", "cycle-values", "multiply", "set", "del", "change-list",
  "define-section", "enable-section", "disable-section", "screenshot",
  "screenshot-to-file", "screenshot-raw", "playlist-next", "playlist-prev",
  "playlist-play-index", "playlist-move", "playlist-clear", "playlist-remove",
  "playlist-shuffle", "playlist-unshuffle", "loadfile", "loadlist", "seek",
  "revert-seek", "quit", "quit-watch-later", "stop", "play", "pause",
  "frame-step", "frame-back-step", "show-text", "show-progress", "show-times",
  "print-text", "expand-text", "expand-path", "run", "sub-add", "sub-remove",
  "sub-reload", "audio-add", "audio-remove", "audio-reload", "video-add",
  "video-remove", "video-reload", "rescan-external-files", "ab-loop",
  "script-binding", "script-message", "script-message-to", "keypress", "mouse",
  "keybind", "mousebind", "apply-profile", "load-script", "vf", "af",
  "ao-reload", "change-window-title", "expand-path",
]);
// modifiers/prefixes an input.conf binding may start with (mpv's cmd_flags)
const MODIFIERS = new Set([
  "no-osd", "osd-auto", "osd-bar", "osd-msg", "osd-msg-bar", "repeatable",
  "nonrepeatable", "nonscalable", "async", "sync", "expand-properties", "raw",
]);

// mpv's script_name_from_filename() (player/scripting.c) replaces every
// non-alphanumeric character with "_", so quality-menu.lua is the client name
// "quality_menu" and reads quality_menu options. Script bindings and implicit
// option identifiers must use that sanitized form.
const sanitize = (name) => name.replace(/[^A-Za-z0-9]/g, "_");

const luaSources = (() => {
  const out = [];
  for (const name of readdirSync(scriptsDir)) {
    if (name.endsWith(".lua")) {
      const base = name.slice(0, -4);
      out.push({
        name: base,
        id: sanitize(base),
        file: join(scriptsDir, name),
        text: readFileSync(join(scriptsDir, name), "utf8"),
      });
    }
  }
  return out;
})();

// script-opts values count as evidence too (playlistmanager builds names from conf keys)
const confText = (() => {
  if (!existsSync(optsDir)) return "";
  return readdirSync(optsDir)
    .filter((n) => n.endsWith(".conf"))
    .map((n) => readFileSync(join(optsDir, n), "utf8"))
    .join("\n");
})();

function scriptKnows(script, identifier) {
  const entry = luaSources.find((s) => s.id === script);
  if (!entry) {
    return {
      known: false,
      why: `no script named "${script}" (mpv's sanitized form of the file name) in scripts/`,
    };
  }
  const literal = entry.text.includes(`"${identifier}"`) || entry.text.includes(`'${identifier}'`);
  const viaConf = confText.includes(identifier);
  if (literal || viaConf) return { known: true };
  return { known: false, why: `"${identifier}" is not registered by ${script}.lua` };
}

{
  const inputConf = join(cfgDir, "input.conf");
  const lines = readFileSync(inputConf, "utf8").split("\n");
  const seen = new Map();

  lines.forEach((raw, i) => {
    const lineNo = i + 1;
    const line = raw.trim();
    if (!line || line.startsWith("#") || line.startsWith(";")) return;

    const space = line.search(/\s/);
    if (space < 0) {
      fail(inputConf, lineNo, `binding "${line}" has no command`);
      return;
    }
    // mpv keys are case-sensitive: `l` and `L` are different bindings
    const key = line.slice(0, space).trim();
    const args = line.slice(space).trim().split(/\s+/);

    const id = key;
    const dup = seen.get(id);
    if (dup) fail(inputConf, lineNo, `key "${key}" is bound twice (also line ${dup})`);
    else seen.set(id, lineNo);

    while (args.length && MODIFIERS.has(args[0])) args.shift();
    if (!args.length) {
      fail(inputConf, lineNo, `key "${key}" has modifiers but no command`);
      return;
    }

    // mpv's find_cmd() rewrites '_' to '-' (input/cmd.c), so both spellings work
    const command = args[0].replace(/_/g, "-");
    if (!MPV_COMMANDS.has(command)) {
      fail(inputConf, lineNo, `unknown mpv command "${args[0]}"`);
      return;
    }
    args[0] = command;

    if (command === "script-binding") {
      const target = args[1];
      if (!target) return; // listing bindings is valid
      const [script, name] = target.split("/");
      if (!name) {
        fail(inputConf, lineNo, `script-binding "${target}" needs script/name`);
        return;
      }
      const result = scriptKnows(script, name);
      if (!result.known) fail(inputConf, lineNo, result.why);
    } else if (command === "script-message" || command === "script-message-to") {
      const name = command === "script-message" ? args[1] : args[2];
      if (!name) {
        fail(inputConf, lineNo, `${command} needs a message name`);
        return;
      }
      const known = luaSources.some((s) => s.text.includes(`"${name}"`) || s.text.includes(`'${name}'`));
      if (!known) fail(inputConf, lineNo, `no script registers script message "${name}"`);
    }

    // every ~~/... path must exist, or the binding silently does nothing
    for (const token of line.match(/~~\/[^\s"']+/g) || []) {
      const target = join(cfgDir, token.replace(/^~~\//, ""));
      if (!existsSync(target)) fail(inputConf, lineNo, `referenced file does not exist: ${token}`);
    }
  });
}

// ------------------------------------------------------- script-opts pairing
// mp.options.read_options(opts, id) loads script-opts/<id>.conf. When id is
// omitted (or a variable), mpv falls back to the sanitized script name, which
// is the file name with every non-alphanumeric character turned into "_".
{
  const identifiers = new Map(); // id -> script name
  for (const script of luaSources) {
    const calls = script.text.matchAll(/read_options\s*\(([^)]*)\)/g);
    for (const call of calls) {
      const arg = (call[1].split(",")[1] || "").trim();
      if (/^["'].*["']$/.test(arg)) {
        identifiers.set(arg.slice(1, -1), script.name);
      } else {
        // omitted, nil, or a variable left nil -> mpv uses the sanitized name
        identifiers.set(script.id, script.name);
      }
    }
  }

  const confDir = existsSync(optsDir) ? readdirSync(optsDir) : [];
  for (const fileName of confDir) {
    if (!fileName.endsWith(".conf")) continue;
    const base = fileName.slice(0, -5);
    if (identifiers.has(base)) continue;

    const near = [...identifiers.keys()].find(
      (id) => id.toLowerCase() === sanitize(base).toLowerCase(),
    );
    if (near) {
      fail(
        join(optsDir, fileName),
        0,
        `mpv never loads this file: the script reads "${near}", so rename it to ${near}.conf`,
      );
    } else {
      fail(join(optsDir, fileName), 0, `no script reads script-opts/${base}.conf`);
    }
  }
}

// ---------------------------------------------------------------- Lua 5.1 scan
// mpv ships LuaJIT (Lua 5.1): `goto` and `::labels::` are syntax errors there.
for (const script of luaSources) {
  script.text.split("\n").forEach((raw, i) => {
    const line = raw.replace(/--.*$/, "");
    if (/\bgoto\s+[A-Za-z_]/.test(line)) {
      fail(script.file, i + 1, "uses goto, which is Lua 5.2+ only (mpv uses LuaJIT/5.1)");
    }
    if (/::[A-Za-z_]\w*::/.test(line)) {
      fail(script.file, i + 1, "uses a label, which is Lua 5.2+ only (mpv uses LuaJIT/5.1)");
    }
  });
}

// ---------------------------------------------------------------------- report
for (const note of notes) console.log(`note: ${note}`);

if (errors.length) {
  console.error(`\n${errors.length} problem(s) found:\n`);
  for (const error of errors) console.error(`  ${error}`);
  process.exitCode = 1;
} else {
  console.log(`ok: ${files.length} files scanned, ${luaSources.length} scripts, no problems found`);
}
