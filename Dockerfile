FROM ubuntu:24.04
RUN apt-get -y update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY bin/calert.bin .
COPY static/ /app/static/
COPY config.sample.toml config.toml

ARG CALERT_GID="999"
ARG CALERT_UID="999"

RUN groupadd --system --gid $CALERT_GID calert && \
    useradd --uid $CALERT_UID --system --gid calert calert && \
    chown -R calert:calert /app

USER calert
EXPOSE 6000

ENTRYPOINT [ "./calert.bin" ]
