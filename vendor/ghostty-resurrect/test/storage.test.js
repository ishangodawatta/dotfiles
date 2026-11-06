"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { prepareStore, cleanInterruptedWrites, atomicJSON, readJSON, snapshotPath, validateSnapshot, autoDecision } = require("../lib/storage");
const { restoreSelection, parseLayout, activeSessionIds } = require("../bin/ghostty-resurrect");

const ids = ["01234567-1111-4222-8333-123456789abc", "01234567-2222-4222-8333-123456789abc"];
const context = { bootId: "boot-a", ghosttyPid: 1, ghosttyStarted: "start-a" };
function snapshot(selected = ids, extra = {}) {
  return { schemaVersion: 2, name: "latest", context, windows: [{ tabs: [{ selected: true, panes: selected.map((id) => ({
    tool: "codex", sessionId: id, sessionFile: `/sessions/rollout-date-${id}.jsonl`, cwd: "/project", terminalId: `terminal-${id}`,
  })) }] }], ...extra };
}
function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "ghostty-resurrect-storage-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  prepareStore(dir);
  return dir;
}

test("atomic replacement creates private complete files and leaves no temporary history", (t) => {
  const dir = fixture(t), file = snapshotPath(dir, "latest");
  atomicJSON(file, snapshot());
  atomicJSON(file, snapshot([ids[1]]));
  assert.deepEqual(readJSON(file), snapshot([ids[1]]));
  assert.equal(fs.statSync(dir).mode & 0o777, 0o700);
  assert.equal(fs.statSync(file).mode & 0o777, 0o600);
  assert.deepEqual(fs.readdirSync(dir), ["latest.json"]);
});

test("a failed serialisation preserves the previous backup and cleans its temporary file", (t) => {
  const dir = fixture(t), file = snapshotPath(dir, "latest");
  atomicJSON(file, snapshot());
  const circular = {}; circular.circular = circular;
  assert.throws(() => atomicJSON(file, circular));
  assert.deepEqual(readJSON(file), snapshot());
  assert.deepEqual(fs.readdirSync(dir), ["latest.json"]);
});

test("corrupt backups are reported rather than treated as absent", (t) => {
  const dir = fixture(t), file = snapshotPath(dir, "latest");
  fs.writeFileSync(file, "{");
  assert.throws(() => readJSON(file), SyntaxError);
  assert.equal(readJSON(path.join(dir, "absent")), null);
});

test("recovery removes interrupted writes while preserving checkpoints and unrelated files", (t) => {
  const dir = fixture(t);
  const temporary = `.latest.json.${ids[0]}.tmp`;
  for (const name of [temporary, "latest.json", "notes.tmp", ".lock"]) fs.writeFileSync(path.join(dir, name), "retained");
  cleanInterruptedWrites(dir);
  assert.deepEqual(fs.readdirSync(dir).sort(), [".lock", "latest.json", "notes.tmp"]);
});

test("names cannot escape the store and legacy guessed identities cannot be restored", () => {
  for (const name of ["../outside", "/absolute", ".hidden", "a/b"]) assert.throws(() => snapshotPath("/store", name), /Invalid/);
  assert.throws(() => validateSnapshot({ windows: snapshot().windows }), /verified session identities/);
  assert.throws(() => validateSnapshot(snapshot([ids[0], ids[0]])), /Duplicate/);
  const invalid = snapshot(); delete invalid.windows[0].tabs[0].panes[0].sessionFile;
  assert.throws(() => validateSnapshot(invalid), /exact conversation/);
});

test("unchanged and newly opened conversations are saved immediately", () => {
  assert.equal(autoDecision(null, snapshot()).save, true);
  assert.equal(autoDecision(snapshot(), snapshot()).save, true);
  assert.equal(autoDecision(snapshot([ids[0]]), snapshot()).save, true);
});

test("gradual shutdown cannot immediately replace the full layout with fewer panes", () => {
  const previous = snapshot(), current = snapshot([ids[0]]);
  const first = autoDecision(previous, current, {}, 1000);
  assert.equal(first.save, false);
  assert.equal(autoDecision(previous, current, first.state, 60999).save, false);
  assert.equal(autoDecision(previous, current, first.state, 61000).save, true);
  const changed = autoDecision(previous, snapshot([ids[1]]), first.state, 61000);
  assert.equal(changed.save, false);
  assert.equal(changed.state.since, 61000);
});

test("losing all agents keeps the last backup regardless of how long shutdown takes", () => {
  const shell = { tool: "shell", cwd: "/project", terminalId: "shell" };
  const current = snapshot(); current.windows[0].tabs[0].panes = [shell];
  const decision = autoDecision(snapshot(), current, {}, 10000000);
  assert.equal(decision.save, false);
  assert.equal(decision.recoveryPending, true);
});

test("a new boot or Ghostty instance never overwrites unrecovered conversations", () => {
  for (const nextContext of [{ ...context, bootId: "boot-b" }, { ...context, ghosttyPid: 2 }, { ...context, ghosttyStarted: "start-b" }]) {
    const decision = autoDecision(snapshot(), snapshot([ids[0]], { context: nextContext }), {}, 10000000);
    assert.equal(decision.save, false);
    assert.equal(decision.recoveryPending, true);
  }
});

test("successful recovery releases the new-instance protection", () => {
  assert.equal(autoDecision(snapshot(), snapshot(ids, { context: { ...context, bootId: "boot-b" } })).save, true);
});

test("partially started restores remain protected beyond the settling period", () => {
  const state = { awaiting: ids };
  const decision = autoDecision(snapshot(), snapshot([ids[0]]), state, 10000000);
  assert.equal(decision.save, false);
  assert.deepEqual(decision.state.awaiting, ids);
  assert.equal(autoDecision(snapshot(), snapshot(), state, 10000000).save, true);
});

test("restoration refuses live duplicates and can select only missing conversations", () => {
  const live = new Set([ids[0]]);
  assert.throws(() => restoreSelection(snapshot(), live, new Set(), false), /already running/);
  const selected = restoreSelection(snapshot(), live, new Set(), true);
  assert.deepEqual(selected.windows[0].tabs[0].panes.map((p) => p.sessionId), [ids[1]]);
  assert.deepEqual(restoreSelection(snapshot(), new Set(ids), new Set(), true).windows, []);
});

test("duplicate protection notices transcripts opened by child processes", () => {
  assert.deepEqual([...activeSessionIds(new Map([[10, { files: [`/root/sessions/rollout-date-${ids[0]}.jsonl`, `/config/projects/a/${ids[1]}.jsonl`] }]]))].sort(), [...ids].sort());
});

test("layout parsing rejects truncated, empty and delimiter-corrupted captures", () => {
  const us = String.fromCharCode(31);
  const valid = `W\nT${us}1${us}tab\nP${us}/project${us}title${us}terminal${us}10${us}/dev/ttys001\n\n`;
  assert.equal(parseLayout(valid)[0].tabs[0].panes[0].pid, 10);
  assert.throws(() => parseLayout(""), /No Ghostty/);
  assert.throws(() => parseLayout(valid.replace(`${us}terminal`, `${us}extra${us}terminal`)), /Invalid/);
  assert.throws(() => parseLayout("unexpected\n"), /Invalid/);
});
