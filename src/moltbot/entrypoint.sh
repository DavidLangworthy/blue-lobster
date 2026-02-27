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
const rawFallbackModels = splitCsv(env.OPENCLAW_MODEL_FALLBACKS || "");
const azureOpenAiEndpoint = (env.AZURE_OPENAI_ENDPOINT || "").trim().replace(/\/+$/, "");
const azureOpenAiDeployment = (env.AZURE_OPENAI_DEPLOYMENT || "gpt-5-2").trim();
const azureOpenAiReasoning = (env.AZURE_OPENAI_REASONING || "false").trim().toLowerCase() === "true";
const explicitModel = (env.OPENCLAW_MODEL || "").trim();
const anthropicApiKey = (env.ANTHROPIC_API_KEY || "").trim();
const hasAnthropicKey = anthropicApiKey !== "" && anthropicApiKey !== "not-set";
const fallbackModels = rawFallbackModels.filter((model) => {
  if (model.toLowerCase().startsWith("anthropic/") && !hasAnthropicKey) {
    return false;
  }
  return true;
});
const hasAllowFrom = allowFrom.length > 0;
const whatsappDmPolicy = (env.WHATSAPP_DM_POLICY || (hasAllowFrom ? "allowlist" : "pairing")).trim();
const whatsappGroupPolicy = (env.WHATSAPP_GROUP_POLICY || (hasAllowFrom ? "allowlist" : "disabled")).trim();
const controlUiHostHeaderFallback =
  (env.OPENCLAW_CONTROLUI_HOST_HEADER_FALLBACK || "true").trim().toLowerCase() === "true";
const controlUiDisableDeviceAuth =
  (env.OPENCLAW_CONTROLUI_DISABLE_DEVICE_AUTH || "true").trim().toLowerCase() === "true";

const defaultAllow = hasAllowFrom ? allowFrom : [];
const primaryModel =
  explicitModel || (azureOpenAiEndpoint ? `azure-openai/${azureOpenAiDeployment}` : "openai/gpt-5.2");

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
  agents: {
    defaults: {
      workspace,
      model: {
        primary: primaryModel,
        fallbacks: fallbackModels,
      },
      heartbeat: {
        every: env.OPENCLAW_HEARTBEAT_EVERY || "1h",
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
      dmPolicy: whatsappDmPolicy,
      allowFrom: defaultAllow,
      groupPolicy: whatsappGroupPolicy,
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
      dangerouslyAllowHostHeaderOriginFallback: controlUiHostHeaderFallback,
      dangerouslyDisableDeviceAuth: controlUiDisableDeviceAuth,
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

if (azureOpenAiEndpoint) {
  const azureModelConfig = {
    id: azureOpenAiDeployment,
    name: `Azure ${azureOpenAiDeployment}`,
    input: ["text", "image"],
  };

  if (azureOpenAiReasoning) {
    azureModelConfig.reasoning = true;
  }

  config.models = {
    mode: "merge",
    providers: {
      "azure-openai": {
        baseUrl: `${azureOpenAiEndpoint}/openai/v1`,
        apiKey: env.AZURE_OPENAI_API_KEY || "",
        api: "openai-responses",
        models: [azureModelConfig],
      },
    },
  };
}

process.stdout.write(`${JSON.stringify(config, null, 2)}\n`);
NODE

echo "OpenClaw configuration written to ${CONFIG_FILE}"

if [[ "${OPENCLAW_IGNORE_CHMOD_ERRORS:-true}" == "true" ]]; then
  if [[ -n "${NODE_OPTIONS:-}" ]]; then
    export NODE_OPTIONS="--require=/app/chmod-shim.cjs ${NODE_OPTIONS}"
  else
    export NODE_OPTIONS="--require=/app/chmod-shim.cjs"
  fi
fi

exec node dist/index.js gateway --bind lan --port "${GATEWAY_PORT:-18789}" --allow-unconfigured "$@"
