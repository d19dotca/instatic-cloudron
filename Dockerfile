FROM cloudron/base:6.0.1@sha256:7b1e729960c3ca312d26e886917ba89483241bba0219ff292858e10d9d5768ee

ARG INSTATIC_VERSION=0.0.20
ARG INSTATIC_ARTIFACT_SHA256=061c8190a264e2927d57c3520c62af7687da82457119e9f2213687718082a019

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
