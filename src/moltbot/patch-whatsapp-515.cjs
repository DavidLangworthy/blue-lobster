#!/usr/bin/env node
/*
 * Hotfix for OpenClaw WhatsApp QR pairing on v2026.2.26:
 * unwrap wrapped Boom errors ({ error: { output.statusCode } }) so 515
 * restart-required can be detected by login-qr flow.
 */
const fs = require("node:fs");

const targetPath = process.argv[2] || "/app/src/web/session.ts";
let source = "";

try {
  source = fs.readFileSync(targetPath, "utf8");
} catch (err) {
  console.error(`Failed to read ${targetPath}: ${err}`);
  process.exit(1);
}

if (source.includes("wrapped?.output?.statusCode")) {
  console.log("WhatsApp 515 patch already applied.");
  process.exit(0);
}

const pattern =
  /export function getStatusCode\(err: unknown\)\s*{\s*return \(\s*\(err as \{ output\?: \{ statusCode\?: number \} \}\)\?\.output\?\.statusCode \?\?\s*\(err as \{ status\?: number \}\)\?\.status\s*\);\s*}/m;

const replacement = `export function getStatusCode(err: unknown) {
  const wrapped = (err as { error?: { output?: { statusCode?: number }; status?: number } })?.error;
  return (
    wrapped?.output?.statusCode ??
    wrapped?.status ??
    (err as { output?: { statusCode?: number } })?.output?.statusCode ??
    (err as { status?: number })?.status
  );
}`;

if (!pattern.test(source)) {
  console.error(
    "WhatsApp 515 patch target not found in session.ts; upstream source changed unexpectedly.",
  );
  process.exit(1);
}

source = source.replace(pattern, replacement);
fs.writeFileSync(targetPath, source, "utf8");
console.log("Applied WhatsApp 515 patch.");
