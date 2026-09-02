# docker.io/library/alpine:3.22
FROM docker.io/library/alpine@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce

RUN apk add --no-cache curl jq ca-certificates \
 && adduser -D -u 1000 swale

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER swale
WORKDIR /mnt/workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Per-image OCI metadata, and the single source of truth for it. The publish
# workflow reads the title and description out of this file and feeds them to
# docker/metadata-action, because a build --label always overrides a Dockerfile
# LABEL - without that the generated repository-wide description would win.
# The description also becomes the Docker Hub short description, which the
# registry does not read from labels at all.
LABEL org.opencontainers.image.title="curl + jq"
LABEL org.opencontainers.image.description="curl and jq for HTTP requests in Swale workflows. Backs the http-request task."
LABEL org.opencontainers.image.source="https://github.com/swaleio/task-definitions"
LABEL org.opencontainers.image.documentation="https://github.com/swaleio/task-definitions/blob/main/images/curl-jq/README.md"
LABEL org.opencontainers.image.licenses="curl AND MIT"
