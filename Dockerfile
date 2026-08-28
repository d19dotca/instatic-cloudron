# syntax=docker/dockerfile:1.7

ARG BUN_IMAGE=oven/bun:1.3.11@sha256:0733e50325078969732ebe3b15ce4c4be5082f18c4ac1a0f0ca4839c2e4e42a7
FROM ${BUN_IMAGE} AS source

ARG INSTATIC_VERSION=0.0.16
ARG INSTATIC_ARCHIVE_SHA256=c8806c1f487c81b34090e25d9bb17f6bff2b2c02c4025d90fb3e7edbfb15e430

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl patch \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /build
RUN curl -fsSL --retry 5 --retry-all-errors \
      "https://github.com/CoreBunch/Instatic/archive/refs/tags/v${INSTATIC_VERSION}.tar.gz" \
      -o /tmp/instatic.tar.gz \
    && echo "${INSTATIC_ARCHIVE_SHA256}  /tmp/instatic.tar.gz" | sha256sum -c - \
    && mkdir /build/instatic \
    && tar -xzf /tmp/instatic.tar.gz --strip-components=1 -C /build/instatic \
    && rm /tmp/instatic.tar.gz
COPY patches/ /tmp/patches/
RUN cd /build/instatic \
    && for patch_file in /tmp/patches/*.patch; do patch -p1 < "${patch_file}"; done

FROM source AS build
WORKDIR /build/instatic
RUN bun install --frozen-lockfile
RUN bun test \
      src/__tests__/server/formMail.test.ts \
      src/__tests__/forms/formValidation.test.ts \
      src/__tests__/db/createDbClient.test.ts \
      src/__tests__/server/serverConfig.test.ts
RUN bun run build

FROM source AS production-dependencies
WORKDIR /build/instatic
RUN bun install --frozen-lockfile --production

FROM cloudron/base:5.1.0@sha256:1c0666c9abe9e2090d33686826d4e97769b799124573118d41e0d7485135748e

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends msmtp-mta \
    && rm -rf /var/lib/apt/lists/*

COPY --from=source /usr/local/bin/bun /usr/local/bin/bun
WORKDIR /app/code
COPY --from=production-dependencies /build/instatic/node_modules ./node_modules
COPY --from=build /build/instatic/dist ./dist
COPY --from=source /build/instatic/package.json /build/instatic/bun.lock ./
COPY --from=source /build/instatic/tsconfig.json /build/instatic/tsconfig.app.json /build/instatic/tsconfig.node.json ./
COPY --from=source /build/instatic/server ./server
COPY --from=source /build/instatic/src ./src
COPY start.sh healthcheck.sh ./

RUN chmod 0755 /app/code/start.sh /app/code/healthcheck.sh \
    && mkdir -p /app/data \
    && chown -R cloudron:cloudron /app/code /app/data

ENV NODE_ENV=production \
    PORT=3001 \
    STATIC_DIR=/app/code/dist \
    UPLOADS_DIR=/app/data/uploads \
    INSTATIC_SENDMAIL_PATH=/usr/sbin/sendmail

EXPOSE 3001
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 CMD ["/app/code/healthcheck.sh"]
CMD ["/app/code/start.sh"]
