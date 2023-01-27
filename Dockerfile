# syntax=docker/dockerfile:1

# Use latest Alpine version by default
ARG ALPINE_VERSION=""
ARG ALPINE_TAG="${ALPINE_VERSION:-latest}"

ARG GO_VERSION
ARG NODE_VERSION

ARG OPENVPN_VERSION
ARG OPENVPN_PACKAGE_IDENTIFIER="r0"
ARG OPENVPN_PACKAGE_VERSION="${OPENVPN_VERSION}-${OPENVPN_PACKAGE_IDENTIFIER}"

# Frontend-builder
# ------------------------------------------------
FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS frontend-builder

WORKDIR /build

# Install npm dependencies
COPY --link frontend/package.json frontend/package-lock.json ./
RUN npm install

# Build frontend assets
COPY --link frontend/ ./
RUN npm run build

# Backend-builder
# ------------------------------------------------
FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS backend-builder

WORKDIR /build

# Install go dependencies
COPY --link go.mod go.sum ./
RUN go mod download && go install github.com/gobuffalo/packr/v2/packr2@latest

COPY --link --from=frontend-builder /build/static/ ./frontend/static/
COPY . ./
RUN \
    apk add --no-cache build-base && \
    packr2 && \
    env CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -a -tags netgo -ldflags '-linkmode external -extldflags -static -s -w' -o ovpn-admin && \
    packr2 clean

# Web UI final image
# ------------------------------------------------
FROM alpine:${ALPINE_TAG} AS admin-webui

ARG OPENVPN_PACKAGE_VERSION

WORKDIR /app

COPY --link --from=backend-builder /build/ovpn-admin/ ./

RUN \
    apk add --no-cache bash coreutils easy-rsa "openvpn=${OPENVPN_PACKAGE_VERSION}" && \
    ln -s /usr/share/easy-rsa/easyrsa /usr/local/bin
