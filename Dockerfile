# syntax=docker/dockerfile:1.7

# Cloudron's base image is linux/amd64. Pin Bun's amd64 leaf manifest so an
# Apple-silicon build cannot silently copy an arm64 Bun binary into it.
ARG BUN_IMAGE=oven/bun:1.3.11@sha256:38919894db4e117a37f74e3dca503e84f24d97f19cabc5f499a289c2a5d0db7c
FROM ${BUN_IMAGE} AS source

ARG INSTATIC_VERSION=0.0.17
ARG INSTATIC_ARCHIVE_SHA256=53a9ca19f798db7459d81ca96c15d1fe9000a970bde6f544adf660b292ee5bae

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

FROM ${BUN_IMAGE} AS dependencies
WORKDIR /build/instatic
COPY --from=source /build/instatic/package.json /build/instatic/bun.lock ./
COPY --from=source /build/instatic/vendor ./vendor
RUN bun install --frozen-lockfile

FROM dependencies AS build
COPY --from=source /build/instatic ./
RUN bun test \
      src/__tests__/server/formMail.test.ts \
      src/__tests__/forms/formValidation.test.ts \
      src/__tests__/db/createDbClient.test.ts \
      src/__tests__/server/serverConfig.test.ts
RUN bun run build

FROM ${BUN_IMAGE} AS production-dependencies
WORKDIR /build/instatic
COPY --from=source /build/instatic/package.json /build/instatic/bun.lock ./
COPY --from=source /build/instatic/vendor ./vendor
RUN bun install --frozen-lockfile --production

FROM source AS runtime-source
RUN find /build/instatic/src /build/instatic/server \
      -type d -name __tests__ -prune -exec rm -rf '{}' + \
    && find /build/instatic/src /build/instatic/server -type f \
      \( -name '*.test.ts' -o -name '*.test.tsx' -o -name '*.spec.ts' -o -name '*.spec.tsx' \) \
      -delete

FROM cloudron/base:5.1.0@sha256:1c0666c9abe9e2090d33686826d4e97769b799124573118d41e0d7485135748e

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends msmtp-mta \
    && rm -rf /var/lib/apt/lists/*

COPY --from=source /usr/local/bin/bun /usr/local/bin/bun
WORKDIR /app/code
COPY --chown=cloudron:cloudron --from=production-dependencies /build/instatic/node_modules ./node_modules
COPY --chown=cloudron:cloudron --from=build /build/instatic/dist ./dist
COPY --chown=cloudron:cloudron --from=runtime-source /build/instatic/package.json /build/instatic/bun.lock ./
COPY --chown=cloudron:cloudron --from=runtime-source /build/instatic/tsconfig.json /build/instatic/tsconfig.app.json /build/instatic/tsconfig.node.json ./
COPY --chown=cloudron:cloudron --from=runtime-source /build/instatic/server ./server
COPY --chown=cloudron:cloudron --from=runtime-source /build/instatic/src ./src
COPY --chown=cloudron:cloudron start.sh healthcheck.sh ./
RUN chmod 0755 /app/code/start.sh /app/code/healthcheck.sh

ENV NODE_ENV=production \
    PORT=3001 \
    STATIC_DIR=/app/code/dist \
    UPLOADS_DIR=/app/data/uploads \
    INSTATIC_SENDMAIL_PATH=/usr/sbin/sendmail

EXPOSE 3001
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 CMD ["/app/code/healthcheck.sh"]
CMD ["/app/code/start.sh"]
