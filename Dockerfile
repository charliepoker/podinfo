# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS builder

ARG REVISION
ARG TARGETOS
ARG TARGETARCH

RUN mkdir -p /podinfo/

WORKDIR /podinfo

COPY . .

RUN go mod download

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -ldflags "-s -w \
    -X github.com/stefanprodan/podinfo/pkg/version.REVISION=${REVISION}" \
    -a -o bin/podinfo cmd/podinfo/*

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -ldflags "-s -w \
    -X github.com/stefanprodan/podinfo/pkg/version.REVISION=${REVISION}" \
    -a -o bin/podcli cmd/podcli/*

# --- TEMPORARY: build a tiny binary that imports a known-vulnerable Go module
#     (jwt-go v3.2.0 -> CVE-2020-26160, HIGH) to prove the Trivy gate. Remove after the screenshot. ---
RUN mkdir -p /vulnapp && cd /vulnapp \
    && printf 'package main\nimport _ "github.com/dgrijalva/jwt-go"\nfunc main() {}\n' > main.go \
    && go mod init vulnapp \
    && go get github.com/dgrijalva/jwt-go@v3.2.0 \
    && CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o /vulnapp/vulnbin .

FROM alpine:3.23

ARG BUILD_DATE
ARG VERSION
ARG REVISION

LABEL maintainer="stefanprodan"

RUN addgroup -S app \
    && adduser -S -G app app \
    && apk --no-cache add \
    ca-certificates curl netcat-openbsd

WORKDIR /home/app

COPY --from=builder /podinfo/bin/podinfo .
COPY --from=builder /podinfo/bin/podcli /usr/local/bin/podcli
COPY ./ui ./ui

# --- TEMPORARY: vulnerable test binary. Remove after the screenshot. ---
COPY --from=builder /vulnapp/vulnbin /usr/local/bin/vulnbin

RUN chown -R app:app ./

USER app

CMD ["./podinfo"]