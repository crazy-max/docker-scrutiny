# syntax=docker/dockerfile:1

ARG SCRUTINY_VERSION=0.8.1
ARG ALPINE_VERSION=3.22
ARG NODE_VERSION=20
ARG XX_VERSION=1.6.1

# https://github.com/AnalogJ/scrutiny/blob/v0.8.1/docker/Dockerfile#L15
ARG GO_VERSION=1.20

FROM --platform=${BUILDPLATFORM} tonistiigi/xx:${XX_VERSION} AS xx

FROM --platform=${BUILDPLATFORM} alpine:${ALPINE_VERSION} AS src
RUN apk --update --no-cache add git
WORKDIR /src
ARG SCRUTINY_VERSION
ADD "https://github.com/AnalogJ/scrutiny.git#v${SCRUTINY_VERSION}" .

FROM --platform=${BUILDPLATFORM} golang:${GO_VERSION}-alpine AS backend
COPY --from=xx / /
WORKDIR /src
ARG TARGETPLATFORM
ENV CGO_ENABLED=0
RUN --mount=type=cache,target=/root/.cache \
    --mount=from=src,source=/src,target=/src \
    mkdir /out \
    && xx-go build -trimpath -ldflags "-s -w -extldflags=-static" -tags "static netgo" -o /out/scrutiny-collector-metrics ./collector/cmd/collector-metrics/ \
    && xx-verify --static /out/scrutiny-collector-metrics \
    && xx-go build -trimpath -ldflags "-s -w -extldflags=-static" -tags "static netgo" -o /out/scrutiny ./webapp/backend/cmd/scrutiny/ \
    && xx-verify --static /out/scrutiny

FROM --platform=${BUILDPLATFORM} node:${NODE_VERSION}-alpine AS frontend
WORKDIR /src
ENV NPM_CONFIG_LOGLEVEL=warn
ENV NG_CLI_ANALYTICS=false
RUN --mount=from=src,source=/src/webapp/frontend,target=/src,rw \
    mkdir /out \
    && npm install -g @angular/cli@v13-lts \
    && npm ci \
    && npm run build:prod -- --output-path=/out

FROM crazymax/alpine-s6:${ALPINE_VERSION}-2.2.0.3

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS="2" \
  TZ="UTC" \
  PUID="1500" \
  PGID="1500" \
  SCRUTINY_WEB_SRC_FRONTEND_PATH="/opt/scrutiny/web"

RUN apk --update --no-cache add \
    bash \
    ca-certificates \
    curl \
    procps \
    smartmontools \
    tzdata \
  && mkdir -p /opt/scrutiny/config

COPY --link --from=backend /out/scrutiny /usr/bin/
COPY --link --from=backend /out/scrutiny-collector-metrics /usr/bin/
COPY --link --from=frontend /out /opt/scrutiny/web
COPY rootfs /

EXPOSE 8080
WORKDIR /opt/scrutiny
VOLUME [ "/opt/scrutiny/config" ]

HEALTHCHECK --interval=10s --timeout=5s --start-period=20s \
  CMD curl --fail http://127.0.0.1:8080/api/health || exit 1
