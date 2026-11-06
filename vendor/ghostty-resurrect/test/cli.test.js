"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { spawn, spawnSync } = require("node:child_process");
const cli = path.resolve(__dirname, "../bin/ghostty-resurrect");

test("help and unsupported dry-run flags cannot write a backup", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "ghostty-resurrect-cli-"));
  try {
    const options = { encoding: "utf8", env: { ...process.env, GHOSTTY_RESURRECT_DIR: path.join(dir, "absent") } };
    assert.equal(spawnSync(process.execPath, [cli, "backup", "--help"], options).status, 0);
    const invalid = spawnSync(process.execPath, [cli, "backup", "--dry-run"], options);
    assert.equal(invalid.status, 1);
    assert.match(invalid.stderr, /Unsupported option/);
    assert.deepEqual(fs.readdirSync(dir), []);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test("automatic capture skips a busy writer and the OS releases its lock on exit", { skip: process.platform !== "darwin" }, async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "ghostty-resurrect-lock-"));
  const lock = path.join(dir, ".lock");
  const holder = spawn("/usr/bin/lockf", ["-k", lock, process.execPath, "-e", "process.stdout.write('ready'); setInterval(() => {}, 1000)"], { detached: true, stdio: ["ignore", "pipe", "pipe"] });
  const exited = new Promise((resolve) => holder.once("close", resolve));
  try {
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error("Lock holder did not start")), 5000);
      holder.stdout.once("data", () => { clearTimeout(timeout); resolve(); });
      holder.once("error", (error) => { clearTimeout(timeout); reject(error); });
    });
    const result = spawnSync(process.execPath, [cli, "auto-backup"], {
      encoding: "utf8", env: { ...process.env, GHOSTTY_RESURRECT_DIR: dir, GHOSTTY_RESURRECT_LOCKED: "" }, timeout: 5000,
    });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stderr, "");
    assert.deepEqual(fs.readdirSync(dir), [".lock"]);
  } finally {
    process.kill(-holder.pid, "SIGTERM");
    await exited;
    const released = spawnSync("/usr/bin/lockf", ["-t", "0", "-k", lock, "/usr/bin/true"]);
    fs.rmSync(dir, { recursive: true, force: true });
    assert.equal(released.status, 0);
  }
});
