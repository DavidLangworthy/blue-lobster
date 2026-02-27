#!/bin/bash
# OpenClaw Azure Container Apps entrypoint.
# Generates config from environment, initializes workspace, then starts gateway.
set -euo pipefail

CONFIG_DIR="${HOME:-/home/node}/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"

mkdir -p "${CONFIG_DIR}"

/app/init-workspace.sh

node <<'NODE' > "${CONFIG_FILE}"
const env = process.env;

function splitCsv(value) {
  if (!value) return [];
  return value
    .split(",")
    .map((v) => v.trim())
    .filter(Boolean);
}

function slugify(value) {
  return String(value)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-+|-+$)/g, "");
}

function titleCase(input) {
  return String(input)
    .split(/[-_\s]+/)
    .filter(Boolean)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ");
}

const workspace = env.OPENCLAW_WORKSPACE || "/workspace";
const allowFrom = splitCsv(env.WHATSAPP_ALLOW_FROM);
const rooms = splitCsv(env.OPENCLAW_ROOMS || "living-room,master-bedroom");
const fallbackModels = splitCsv(env.OPENCLAW_MODEL_FALLBACKS || "anthropic/claude-sonnet-4-6");

const defaultAllow = allowFrom.length > 0 ? allowFrom : ["+15550000000"];
const roomAgents = rooms
  .map((r) => ({ id: slugify(r), name: titleCase(r) }))
  .filter((r) => r.id && r.id !== "main")
  .map((r) => ({
    id: r.id,
    identity: {
      name: `${r.name} Assistant`,
      theme: "interior design and procurement",
      emoji: "🏠",
    },
    workspace,
  }));

const config = {
  identity: {
    name: env.OPENCLAW_PERSONA_NAME || "Clawd",
    theme: "interior design and procurement assistant",
    emoji: "🦞",
  },
  agents: {
    defaults: {
      workspace,
      model: {
        primary: env.OPENCLAW_MODEL || "openai/gpt-5.2",
        fallbacks: fallbackModels,
      },
      heartbeat: {
        every: env.OPENCLAW_HEARTBEAT_EVERY || "2h",
        target: "last",
        directPolicy: "allow",
      },
    },
    list: [
      {
        id: "main",
        identity: {
          name: env.OPENCLAW_PERSONA_NAME || "Clawd",
          theme: "interior design and procurement assistant",
          emoji: "🦞",
        },
      },
      ...roomAgents,
    ],
  },
  channels: {
    whatsapp: {
      dmPolicy: "allowlist",
      allowFrom: defaultAllow,
      groupPolicy: "allowlist",
      groupAllowFrom: defaultAllow,
      groups: {
        "*": {
          requireMention: true,
        },
      },
      sendReadReceipts: true,
      textChunkLimit: 4000,
    },
  },
  messages: {
    tts: {
      auto: env.OPENCLAW_TTS_AUTO || "inbound",
      provider: env.OPENCLAW_TTS_PROVIDER || "edge",
    },
  },
  tools: {
    allow: [
      "group:fs",
      "group:runtime",
      "group:sessions",
      "group:memory",
      "group:ui",
      "group:automation",
      "group:messaging",
      "message",
      "browser",
      "canvas",
      "cron",
      "gateway",
      "exec",
      "process",
    ],
    deny: ["discord", "telegram"],
    exec: {
      ask: env.OPENCLAW_EXEC_ASK || "always",
    },
    elevated: {
      enabled: true,
      allowFrom: {
        whatsapp: defaultAllow,
      },
    },
    media: {
      audio: {
        enabled: true,
        models: [
          {
            type: "cli",
            command: "/app/azure-stt.sh",
            args: ["{{MediaPath}}"],
            timeoutSeconds: 90,
          },
          {
            type: "provider",
            provider: "openai",
            model: "gpt-4o-mini-transcribe",
            timeoutSeconds: 90,
          },
        ],
      },
    },
  },
  approvals: {
    exec: {
      enabled: true,
      mode: "session",
      sessionFilter: ["whatsapp"],
      agentFilter: ["main"],
    },
  },
  browser: {
    enabled: true,
    defaultProfile: "openclaw",
    executablePath: "/usr/bin/chromium",
    headless: true,
    noSandbox: true,
  },
  canvasHost: {
    enabled: true,
    root: `${workspace}/canvas`,
    liveReload: false,
  },
  gateway: {
    port: Number(env.GATEWAY_PORT || 18789),
    bind: "lan",
    controlUi: {
      enabled: true,
    },
    auth: {
      mode: "token",
      token: env.OPENCLAW_GATEWAY_TOKEN || "",
    },
  },
  logging: {
    level: env.OPENCLAW_LOG_LEVEL || "info",
    consoleLevel: env.OPENCLAW_LOG_LEVEL || "info",
    consoleStyle: "pretty",
  },
};

process.stdout.write(`${JSON.stringify(config, null, 2)}\n`);
NODE

echo "OpenClaw configuration written to ${CONFIG_FILE}"

exec node dist/index.js gateway --bind lan --port "${GATEWAY_PORT:-18789}" --allow-unconfigured "$@"
