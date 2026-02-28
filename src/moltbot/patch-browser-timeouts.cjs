#!/usr/bin/env node
/*
 * Hotfix for OpenClaw browser tool on ACA:
 * increase short browser action timeouts in src/browser/client.ts from
 * 15s -> 60s to tolerate slower cold starts under constrained container CPU.
 */
const fs = require("node:fs");

const targetPath = process.argv[2] || "/app/src/browser/client.ts";
let source = "";

try {
  source = fs.readFileSync(targetPath, "utf8");
} catch (err) {
  console.error(`Failed to read ${targetPath}: ${err}`);
  process.exit(1);
}

const oldPattern = /timeoutMs:\s*15000/g;
const existingOldMatches = source.match(oldPattern) || [];

if (existingOldMatches.length === 0) {
  if (source.includes("timeoutMs: 60000")) {
    console.log("Browser timeout patch already applied.");
    process.exit(0);
  }
  console.error(
    "Browser timeout patch target not found in client.ts; upstream source changed unexpectedly.",
  );
  process.exit(1);
}

source = source.replace(oldPattern, "timeoutMs: 60000");
fs.writeFileSync(targetPath, source, "utf8");
console.log(`Applied browser timeout patch (${existingOldMatches.length} replacements).`);
