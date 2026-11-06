"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { randomUUID } = require("node:crypto");
const { UUID } = require("./sessions");

function prepareStore(store) {
  fs.mkdirSync(store, { recursive: true, mode: 0o700 });
  fs.chmodSync(store, 0o700);
}

// Only call whilst holding the writer lock: these are interrupted atomic writes.
function cleanInterruptedWrites(store) {
  for (const name of fs.readdirSync(store)) {
    if (/^\.[\w.-]+\.json\.[0-9a-f-]{36}\.tmp$/i.test(name)) fs.unlinkSync(path.join(store, name));
  }
}

function snapshotPath(store, name) {
  if (!/^[a-z0-9][a-z0-9._-]{0,63}$/i.test(name)) throw new Error("Invalid backup name");
  return path.join(store, `${name}.json`);
}

function readJSON(file, missing = null) {
  try { return JSON.parse(fs.readFileSync(file, "utf8")); }
  catch (error) { if (error.code === "ENOENT") return missing; throw error; }
}

function atomicJSON(file, value) {
  const temp = path.join(path.dirname(file), `.${path.basename(file)}.${randomUUID()}.tmp`);
  let fd;
  try {
    fd = fs.openSync(temp, "wx", 0o600);
    fs.writeFileSync(fd, `${JSON.stringify(value, null, 2)}\n`);
    fs.fsyncSync(fd);
    fs.closeSync(fd);
    fd = undefined;
    fs.renameSync(temp, file);
    const directory = fs.openSync(path.dirname(file), "r");
    try { fs.fsyncSync(directory); } finally { fs.closeSync(directory); }
  } finally {
    if (fd !== undefined) fs.closeSync(fd);
    try { fs.unlinkSync(temp); } catch (error) { if (error.code !== "ENOENT") throw error; }
  }
}

function panes(snapshot) {
  return snapshot.windows.flatMap((window) => window.tabs.flatMap((tab) => tab.panes));
}

function validateSnapshot(snapshot) {
  if (snapshot?.schemaVersion !== 2 || !Array.isArray(snapshot.windows) || !snapshot.windows.length) {
    throw new Error("Backup has no verified session identities; take a new backup");
  }
  for (const window of snapshot.windows) {
    if (!Array.isArray(window.tabs) || !window.tabs.length) throw new Error("Invalid saved window");
    for (const tab of window.tabs) {
      if (!Array.isArray(tab.panes) || !tab.panes.length) throw new Error("Invalid saved tab");
      for (const pane of tab.panes) {
        if (!path.isAbsolute(pane.cwd || "") || !["shell", "codex", "claude"].includes(pane.tool)) throw new Error("Invalid saved pane");
        if (pane.tool !== "shell" && (!UUID.test(pane.sessionId || "") || !path.isAbsolute(pane.sessionFile || ""))) {
          throw new Error("Saved agent lacks an exact conversation ID and transcript");
        }
      }
    }
  }
  const ids = panes(snapshot).filter((pane) => pane.sessionId).map((pane) => pane.sessionId);
  if (new Set(ids).size !== ids.length) throw new Error("Duplicate saved conversation IDs");
  return snapshot;
}

function sameInstance(a, b) {
  return a && b && a.bootId === b.bootId && a.ghosttyPid === b.ghosttyPid && a.ghosttyStarted === b.ghosttyStarted;
}

function sessionIds(snapshot) {
  return panes(snapshot).flatMap((pane) => pane.sessionId ? [pane.sessionId] : []);
}

function identities(snapshot) {
  return panes(snapshot).map((pane) => `${pane.terminalId}:${pane.sessionId || "shell"}`).sort();
}

// A short settling period protects against windows closing one by one during
// shutdown. A new boot/app instance requires recovery or an explicit backup.
function autoDecision(previous, current, state = {}, now = Date.now()) {
  if (!previous) return { save: true, state: {}, reason: "Initial backup" };
  const currentIds = new Set(sessionIds(current));
  if (state.awaiting?.some((id) => !currentIds.has(id))) {
    return { save: false, state, reason: "Restore is awaiting its saved conversations" };
  }
  const oldIds = sessionIds(previous);
  if (!sameInstance(previous.context, current.context)) {
    if (!oldIds.length || oldIds.some((id) => !currentIds.has(id))) {
      return { save: false, state: {}, recoveryPending: true, reason: "Previous Ghostty session protected; run restore or backup" };
    }
    return { save: true, state: {}, reason: "Saved conversations are running again" };
  }
  if (oldIds.length && !currentIds.size) {
    return { save: false, state: {}, recoveryPending: true, reason: "Agent conversations have closed; previous backup retained" };
  }
  const currentKeys = identities(current);
  const removed = identities(previous).some((key) => !currentKeys.includes(key));
  if (removed) {
    const candidate = JSON.stringify(currentKeys);
    if (state.candidate !== candidate) {
      return { save: false, state: { candidate, since: now }, reason: "Waiting for closed panes to settle" };
    }
    if (now - state.since < 60000) return { save: false, state, reason: "Waiting for closed panes to settle" };
  }
  return { save: true, state: {}, reason: "Backup current" };
}

module.exports = { prepareStore, cleanInterruptedWrites, snapshotPath, readJSON, atomicJSON, panes, validateSnapshot,
  sameInstance, sessionIds, autoDecision };
