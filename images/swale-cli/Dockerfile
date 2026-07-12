# docker.io/library/debian:13-slim
FROM docker.io/library/debian@sha256:28de0877c2189802884ccd20f15ee41c203573bd87bb6b883f5f46362d24c5c2

# ca-certificates for HTTPS to the Swale service; a non-root runtime user.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates; \
    rm -rf /var/lib/apt/lists/*; \
    useradd --create-home --user-group --uid 1000 swale

# ---------------------------------------------------------------------------
# TODO: install the swale CLI (release binary / package) — pin method at build
# time. The finalized step MUST land an executable at /usr/local/bin/swale.
# The distribution method (vendored binary vs downloaded release vs package) is
# not yet decided, so this is a placeholder — pick ONE of the following, pin it
# (version + checksum/digest), and delete the rest:
#
#   # (a) vendored release binary checked into the build context:
#   COPY swale /usr/local/bin/swale
#   RUN chmod 0755 /usr/local/bin/swale
#
#   # (b) download a pinned release and verify its checksum
#   #     (also add `curl` to the apt-get install layer above):
#   RUN set -eux; \
#       url="https://REPLACE.ME/swale-<version>-linux-amd64"; \
#       curl -fsSL "$url" -o /usr/local/bin/swale; \
#       echo "<sha256>  /usr/local/bin/swale" | sha256sum -c -; \
#       chmod 0755 /usr/local/bin/swale
#
# Until this is finalized no `swale` binary exists, so the image builds but
# fails at runtime. That is intentional: the placeholder is not shippable as-is.
# ---------------------------------------------------------------------------

COPY entrypoint.sh /opt/swale-cli/entrypoint.sh
RUN chmod +x /opt/swale-cli/entrypoint.sh

ENV PATH="/usr/local/bin:${PATH}"
USER swale
WORKDIR /mnt/workspace
ENTRYPOINT ["/opt/swale-cli/entrypoint.sh"]
