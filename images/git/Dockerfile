# Base: alpine/git:latest (digest-pinned; tag kept for humans)
FROM alpine/git@sha256:697cb1c85aefc5724febaec2202a974e0d66f6abb6be91a9a86d0c8757af692a

RUN apk add --no-cache git-lfs openssh-client ca-certificates \
 && git lfs install --system \
 && adduser -D -u 1000 swale

COPY entrypoint.sh /opt/git/entrypoint.sh
RUN chmod +x /opt/git/entrypoint.sh

USER swale
WORKDIR /mnt/workspace
ENTRYPOINT ["/opt/git/entrypoint.sh"]
