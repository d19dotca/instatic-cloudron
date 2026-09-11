FROM cloudron/base:5.1.0@sha256:1c0666c9abe9e2090d33686826d4e97769b799124573118d41e0d7485135748e

ARG INSTATIC_VERSION=0.0.19
ARG INSTATIC_ARTIFACT_SHA256=d458d18175030b0af87b5ef404b674248814150fb698e8d7d912cbe99ce1e750

LABEL org.opencontainers.image.source="https://github.com/d19dotca/instatic-cloudron" \
      org.opencontainers.image.description="Instatic packaged for Cloudron" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app/code
RUN curl -fsSL --retry 5 --retry-all-errors \
      "https://github.com/CoreBunch/Instatic/releases/download/v${INSTATIC_VERSION}/instatic-server-${INSTATIC_VERSION}-linux-x64.tar.gz" \
      -o /tmp/instatic.tar.gz \
    && echo "${INSTATIC_ARTIFACT_SHA256}  /tmp/instatic.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/instatic.tar.gz --strip-components=1 -C /app/code \
    && rm /tmp/instatic.tar.gz \
    && chown -R cloudron:cloudron /app/code \
    && chmod 0755 /app/code/instatic-server

COPY start.sh healthcheck.sh ./
RUN chmod 0755 start.sh healthcheck.sh

ENV NODE_ENV=production \
    PORT=3001 \
    STATIC_DIR=/app/code/dist \
    UPLOADS_DIR=/app/data/uploads

EXPOSE 3001
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 CMD ["/app/code/healthcheck.sh"]
CMD ["/app/code/start.sh"]
