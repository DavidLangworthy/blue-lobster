# OpenClaw on Azure Container Apps
# Builds OpenClaw from source and applies Azure-focused runtime defaults.

FROM node:22-bookworm

# Install runtime dependencies (Chromium for browser tool + ffmpeg for media handling).
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    ffmpeg \
    git \
    chromium \
    fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ARG OPENCLAW_VERSION=main
RUN git clone --depth 1 --branch ${OPENCLAW_VERSION} https://github.com/openclaw/openclaw.git .

RUN corepack enable
RUN pnpm install --frozen-lockfile
RUN pnpm build
RUN pnpm ui:install
RUN pnpm ui:build

# Persistent directories (mounted via Azure Files in ACA).
RUN mkdir -p /home/node/.openclaw /workspace /workspace/canvas

COPY entrypoint.sh /app/entrypoint.sh
COPY init-workspace.sh /app/init-workspace.sh
COPY azure-stt.sh /app/azure-stt.sh
RUN chmod +x /app/entrypoint.sh /app/init-workspace.sh /app/azure-stt.sh

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
