#!/bin/bash
# Azure Speech-to-Text adapter for OpenClaw media CLI integration.
set -euo pipefail

MEDIA_PATH="${1:-}"
if [ -z "${MEDIA_PATH}" ]; then
  echo "azure-stt: missing media path argument" >&2
  exit 2
fi
if [ ! -f "${MEDIA_PATH}" ]; then
  echo "azure-stt: file not found: ${MEDIA_PATH}" >&2
  exit 2
fi

SPEECH_KEY="${AZURE_SPEECH_KEY:-}"
SPEECH_REGION="${AZURE_SPEECH_REGION:-}"
SPEECH_LANGUAGE="${AZURE_SPEECH_LANGUAGE:-en-US}"

if [ -z "${SPEECH_KEY}" ] || [ -z "${SPEECH_REGION}" ]; then
  echo "azure-stt: AZURE_SPEECH_KEY and AZURE_SPEECH_REGION are required" >&2
  exit 3
fi

EXT="${MEDIA_PATH##*.}"
EXT_LOWER="$(echo "${EXT}" | tr '[:upper:]' '[:lower:]')"
CONTENT_TYPE="application/octet-stream"
case "${EXT_LOWER}" in
  ogg) CONTENT_TYPE="audio/ogg; codecs=opus" ;;
  opus) CONTENT_TYPE="audio/ogg; codecs=opus" ;;
  wav) CONTENT_TYPE="audio/wav" ;;
  mp3) CONTENT_TYPE="audio/mpeg" ;;
  m4a) CONTENT_TYPE="audio/mp4" ;;
  webm) CONTENT_TYPE="audio/webm" ;;
esac

URL="https://${SPEECH_REGION}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=${SPEECH_LANGUAGE}&format=detailed"

RESPONSE="$(curl -sS --fail-with-body -X POST "${URL}" \
  -H "Ocp-Apim-Subscription-Key: ${SPEECH_KEY}" \
  -H "Content-Type: ${CONTENT_TYPE}" \
  --data-binary "@${MEDIA_PATH}")"

TRANSCRIPT="$(printf '%s' "${RESPONSE}" | node -e '
let raw="";
process.stdin.on("data", c => (raw += c));
process.stdin.on("end", () => {
  try {
    const d = JSON.parse(raw);
    const text = (d.DisplayText || d.NBest?.[0]?.Display || "").trim();
    if (!text) {
      process.stderr.write("azure-stt: no transcript returned\n");
      process.exit(4);
    }
    process.stdout.write(text);
  } catch (err) {
    process.stderr.write(`azure-stt: invalid response: ${err.message}\n`);
    process.exit(5);
  }
});
')"

printf '%s\n' "${TRANSCRIPT}"
