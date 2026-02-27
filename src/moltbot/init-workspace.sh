#!/bin/bash
# Initialize persistent workspace content on first boot.
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-/workspace}"
ROOMS_RAW="${OPENCLAW_ROOMS:-living-room,master-bedroom}"

mkdir -p "${WORKSPACE}" "${WORKSPACE}/canvas"

if [ ! -f "${WORKSPACE}/SYSTEM_PROMPT.md" ]; then
  cat > "${WORKSPACE}/SYSTEM_PROMPT.md" <<'PROMPT'
You are an interior design and procurement assistant.

Mission:
- Help the user design rooms and source furniture/decor.
- Prioritize practical, purchasable options with clear pricing.
- Keep recommendations aligned to the user's style, room constraints, and budget.

Rules:
- Stay strictly within interior design and procurement support.
- Do not take irreversible financial actions without explicit user approval.
- Keep a clear audit trail of sourcing decisions in SOURCING_LEDGER.csv.
PROMPT
fi

if [ ! -f "${WORKSPACE}/SOURCING_LEDGER.csv" ]; then
  cat > "${WORKSPACE}/SOURCING_LEDGER.csv" <<'CSV'
item,room,vendor,link,unit_price,qty,total_price,status,notes,updated_at
CSV
fi

if [ ! -f "${WORKSPACE}/HEARTBEAT.md" ]; then
  cat > "${WORKSPACE}/HEARTBEAT.md" <<'HB'
# Heartbeat Checklist

- Check vendor reply inbox and summarize actionable updates.
- Continue pending sourcing tasks for active rooms.
- Update SOURCING_LEDGER.csv when new pricing or availability is found.
- If no urgent updates, reply with HEARTBEAT_OK.
HB
fi

IFS=',' read -r -a ROOMS <<< "${ROOMS_RAW}"
for room in "${ROOMS[@]}"; do
  room_trimmed="$(echo "${room}" | xargs)"
  if [ -z "${room_trimmed}" ]; then
    continue
  fi
  room_slug="$(echo "${room_trimmed}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  room_dir="${WORKSPACE}/canvas/${room_slug}"
  mkdir -p "${room_dir}"
  if [ ! -f "${room_dir}/index.html" ]; then
    cat > "${room_dir}/index.html" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${room_trimmed} Canvas</title>
  <style>
    body { font-family: ui-sans-serif, system-ui, sans-serif; margin: 2rem; background: #f7f6f2; color: #222; }
    h1 { margin-bottom: 0.5rem; }
    p { color: #555; }
    .card { background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 1rem; }
  </style>
</head>
<body>
  <h1>${room_trimmed}</h1>
  <div class="card">
    <p>Canvas initialized. The agent can update this room dashboard over time.</p>
  </div>
</body>
</html>
HTML
  fi
done
