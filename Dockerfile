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

# --- TEMPORARY: known-vulnerable deps to prove the Trivy gate. Remove after the screenshot. ---
COPY vuln-test/requirements.txt /tmp/requirements.txt

COPY --from=builder /podinfo/bin/podinfo .
COPY --from=builder /podinfo/bin/podcli /usr/local/bin/podcli
COPY ./ui ./ui
RUN chown -R app:app ./

USER app

CMD ["./podinfo"]