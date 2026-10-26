# syntax=docker/dockerfile:1.7
# Seanime v3.10.4 — multi-stage. Contexto: raíz del repo 5rahim/seanime.
# Docs: ~/Documents/Knowledge/learning/projects/seanime-docker

FROM node:24.22.1-alpine AS frontend
WORKDIR /build
COPY seanime-web/package.json seanime-web/package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --no-audit --no-fund
COPY seanime-web/ ./
RUN npm run build

FROM golang:1.27.3-alpine3.24 AS backend
WORKDIR /build
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download
COPY . .
COPY --from=frontend /build/out ./web

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build -o seanime -trimpath -ldflags="-s -w" .

FROM alpine:3.24

# hadolint ignore=DL3018
RUN apk add --no-cache ffmpeg ca-certificates tzdata curl sqlite \
 && addgroup -S -g 1000 seanime \
 && adduser  -S -u 1000 -G seanime -s /sbin/nologin seanime

WORKDIR /app
COPY --from=backend --chown=1000:1000 /build/seanime /app/seanime
COPY --from=seed --chown=1000:1000 . /opt/seed/
RUN chmod +x /opt/seed/entrypoint.sh

USER 1000
EXPOSE 43211

# hadolint ignore=DL3025
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD wget -qO- http://127.0.0.1:43211/api/v1/status >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/opt/seed/entrypoint.sh"]
CMD ["/app/seanime"]
