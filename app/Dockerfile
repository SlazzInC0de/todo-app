# syntax=docker/dockerfile:1

# ---- dependencies: cached until package*.json changes ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ---- runtime ----
FROM node:22-alpine
ENV NODE_ENV=production \
    PORT=3000
WORKDIR /app

COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src
COPY --chown=node:node public ./public

# CI passes the commit SHA so /version shows exactly what is running
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}

# Numeric UID (the 'node' user in the base image) so Kubernetes'
# runAsNonRoot check can verify the container is not root
USER 1000:1000
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/healthz || exit 1
CMD ["node", "src/server.js"]
