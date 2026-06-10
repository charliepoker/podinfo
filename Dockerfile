FROM ubuntu:20.04

ARG BUILD_DATE
ARG VERSION
ARG REVISION

LABEL maintainer="stefanprodan"

RUN groupadd -r app \
    && useradd -r -g app app \
    && apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home/app

COPY --from=builder /podinfo/bin/podinfo .
COPY --from=builder /podinfo/bin/podcli /usr/local/bin/podcli
COPY ./ui ./ui
RUN chown -R app:app ./

USER app

CMD ["./podinfo"]