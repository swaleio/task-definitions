FROM debian:13-slim@sha256:8aa5a7bf5a1955bddbe7d74fcdd0b91ab30e74362a8b73af672b0481b35b44a0

# PowerShell 7.6 LTS from Microsoft's signed package repository for Debian 13.
# Microsoft no longer publishes PowerShell container images; it ships PowerShell
# inside its .NET SDK image instead, whose tag names the SDK. The signing key is
# fetched over HTTPS and must match the fingerprint below before apt trusts
# anything it signs. Renovate moves POWERSHELL_VERSION within the 7.6 line.
# renovate: datasource=deb depName=powershell-lts registryUrl=https://packages.microsoft.com/debian/13/prod?suite=trixie&components=main&binaryArch=amd64
ARG POWERSHELL_VERSION=7.6.10-1.deb

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gpg \
 && curl -fsSL https://packages.microsoft.com/keys/microsoft-2025.asc \
      | gpg --dearmor -o /usr/share/keyrings/microsoft-2025.gpg \
 && test "$(gpg --show-keys --with-colons /usr/share/keyrings/microsoft-2025.gpg | awk -F: '/^fpr/ {print $10; exit}')" \
      = AA86F75E427A19DD33346403EE4D7792F748182B \
 && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-2025.gpg] https://packages.microsoft.com/debian/13/prod trixie main" \
      > /etc/apt/sources.list.d/microsoft-prod.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends powershell-lts="${POWERSHELL_VERSION}" \
 && apt-get purge -y --auto-remove curl gpg \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --uid 1000 swale

# No ENTRYPOINT: the PowerShell task is a free-form script task, so its
# exec.args are the full command line (`pwsh -NoLogo -NoProfile -Command ...`).

# The version of the tool this image is built around. Publishing tags the image
# with it, adding -r1, -r2, ... when that version is already published.
RUN pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' > /usr/share/swale-image-version
USER swale
WORKDIR /mnt/workspace

# Per-image OCI metadata, and the single source of truth for it. The publish
# workflow reads the title and description out of this file and feeds them to
# docker/metadata-action, because a build --label always overrides a Dockerfile
# LABEL - without that the generated repository-wide description would win.
# The description also becomes the Docker Hub short description, which the
# registry does not read from labels at all.
LABEL org.opencontainers.image.title="PowerShell 7.6 LTS"
LABEL org.opencontainers.image.description="PowerShell 7.6 LTS on Debian 13 slim for Swale workflows. Backs the powershell-7-6 task."
LABEL org.opencontainers.image.source="https://github.com/swaleio/task-definitions"
LABEL org.opencontainers.image.documentation="https://github.com/swaleio/task-definitions/blob/main/images/powershell-7-6/README.md"
LABEL org.opencontainers.image.licenses="MIT"
