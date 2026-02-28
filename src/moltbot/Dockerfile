# OpenClaw runtime image.
# Built on top of the pre-compiled base image for fast iteration (~10 sec).
# The base image (Dockerfile.base) contains OS deps, OpenClaw source, and the
# full pnpm build.  It is rebuilt only when OPENCLAW_VERSION or patches change.

ARG BASE_IMAGE
FROM ${BASE_IMAGE}

COPY entrypoint.sh /app/entrypoint.sh
COPY init-workspace.sh /app/init-workspace.sh
COPY azure-stt.sh /app/azure-stt.sh
COPY chmod-shim.cjs /app/chmod-shim.cjs
COPY start-browser-cdp.sh /app/start-browser-cdp.sh
RUN chmod +x /app/entrypoint.sh /app/init-workspace.sh /app/azure-stt.sh /app/start-browser-cdp.sh

ENV NODE_ENV=production
ENV GATEWAY_PORT=18789
ENV GATEWAY_BIND=0.0.0.0
ENV HOME=/home/node
ENV OPENCLAW_WORKSPACE=/workspace
ENV TERM=xterm-256color
ENV PATH=/home/linuxbrew/.linuxbrew/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:18789/health || exit 1

EXPOSE 18789

ENTRYPOINT ["/app/entrypoint.sh"]
