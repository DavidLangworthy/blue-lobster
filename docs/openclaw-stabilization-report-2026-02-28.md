# OpenClaw Stabilization Report

Date: February 28, 2026 (UTC)
Repo: `BandaruDheeraj/blue-lobster`

## Scope
This report summarizes the main deployment/runtime issues worked through for the Azure Container Apps OpenClaw environment and the current state after live debugging.

## Issues Worked Through

### 1. Azure OpenAI auth and model wiring failures
Symptoms:
- `401 Access denied due to invalid subscription key or wrong API endpoint`
- `404 The API deployment for this resource does not exist`
- `400 Encrypted content is not supported with this model`

Work completed:
- Wired AOAI endpoint/key into ACA secrets/env.
- Added AOAI liveness checks in scripts.
- Set reasoning compatibility to avoid encrypted-content mismatch (`AZURE_OPENAI_REASONING=false`).
- Confirmed direct AOAI completion call returns `200` from inside container.

Status:
- Resolved for current runtime.

### 2. Dashboard auth and gateway connectivity
Symptoms:
- Control UI showed `gateway token missing` / disconnected state.

Work completed:
- Standardized tokenized dashboard access path.
- Ensured gateway token mode and Control UI settings were correctly applied.

Status:
- Resolved for current runtime.

### 3. Persistent storage permission errors
Symptoms:
- `EPERM: operation not permitted, chmod '/home/node/.openclaw/.../sessions.json'`

Work completed:
- Added runtime shim/handling for chmod behavior on mounted Azure Files paths.
- Revalidated session write/read behavior from mounted persistent storage.

Status:
- Resolved for current runtime.

### 4. Browser runtime startup failures (CDP)
Symptoms:
- `Failed to start Chrome CDP on port 18800 for profile 'openclaw'`

Work completed:
- Added explicit Chromium prestart script (`start-browser-cdp.sh`).
- Configured attach-only browser profile with fixed `cdpPort: 18800`.
- Added required profile field (`color`) to avoid config validation failure.
- Verified in-container CDP endpoint (`http://127.0.0.1:18800/json/version`) returns successfully.

Status:
- Resolved for current runtime.

### 5. WhatsApp channel instability
Symptoms:
- Frequent disconnects / `status 440` conflict / logged-out state.

Work completed:
- Forced single replica mode to reduce multi-session conflict risk.
- Updated docs/runbook with relink expectations and conflict behavior.

Status:
- Partially mitigated. Pairing/linking behavior still needs E2E validation in a stable session window.

## Current High-Priority Open Issue

### `Unknown error` after/around web-browsing tasks
Observed behavior:
- Browser tool can succeed (tool returns valid page target), but assistant response intermittently fails with `Unknown error`.
- Reproduced on February 28, 2026 with prompt patterns requesting broader sourcing/browsing output.
- Also observed successful runs in same session (for example, browser prompt returning `Example Domain`).

What is known:
- This is not a Chrome startup failure in current revision.
- It occurs in the model run stage (`azure-openai-responses/gpt-5-2`) after prompt/tool processing in some flows.
- Gateway logs currently expose only `isError=true error=Unknown error` without upstream provider detail.

Impact:
- Intermittent UX failure despite healthy gateway and working browser CDP.

## Verification Performed

### Passed
- Gateway websocket connect/auth (Control UI compatible client flow).
- Chat send/receive for simple prompt.
- Browser tool execution and response for deterministic check (`Example Domain`) from live container session.

### Failed / Intermittent
- Complex sourcing prompts intermittently fail with `Unknown error`.
- WhatsApp channel stable linked/running state still intermittent due prior 440 conflict behavior.

## Recommended Next Actions
1. Patch provider error surfacing so upstream AOAI response body/status is always logged (no silent `Unknown error`).
2. Add a temporary mitigation in agent instructions/tool policy to avoid multi-URL parallel browsing in one turn.
3. Re-run Web UX E2E using a clean/new session after step 1 to confirm whether failures are provider-side validation vs orchestration bug.
4. Re-run WhatsApp E2E (pair -> inbound -> outbound) once model error visibility is improved.

## Operator Notes
- Revision currently validated live for CDP/browser startup.
- This report is intended as handoff context for the next debugging pass and for final clean-redeploy readiness.
