FROM ubuntu:24.04@sha256:562111b88caa79c71391c0c4d3c2114a7d5c35915c20561fd893cb1e07929e6b

# Blender 5.2 LTS, the official Linux build straight from download.blender.org,
# verified against the SHA-256 file Blender publishes beside it. Renovate moves
# BLENDER_VERSION within the 5.2 line and cannot compute a checksum, so the
# build reads the published one rather than pinning it here. The tarball bundles
# Blender's own Python and its render kernels, so the only system packages it
# needs are the X11/GL client libraries the binary links against - required even
# for background rendering, where no display is ever opened.
# renovate: datasource=custom.blender depName=blender packageName=5.2
ARG BLENDER_VERSION=5.2.4

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl xz-utils \
      libx11-6 libxi6 libxxf86vm1 libxfixes3 libxrender1 libxkbcommon0 \
      libsm6 libxext6 libgl1 libegl1 libgomp1 \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL "https://download.blender.org/release/Blender${BLENDER_VERSION%.*}/blender-${BLENDER_VERSION}-linux-x64.tar.xz" \
      -o /tmp/blender.tar.xz \
 && curl -fsSL "https://download.blender.org/release/Blender${BLENDER_VERSION%.*}/blender-${BLENDER_VERSION}.sha256" \
      | grep " blender-${BLENDER_VERSION}-linux-x64.tar.xz$" \
      | sed "s| blender-${BLENDER_VERSION}-linux-x64.tar.xz$| /tmp/blender.tar.xz|" \
      | sha256sum -c - \
 && mkdir -p /opt/blender \
 && tar -xJf /tmp/blender.tar.xz -C /opt/blender --strip-components=1 \
 && rm /tmp/blender.tar.xz \
 && ln -s /opt/blender/blender /usr/local/bin/blender \
 && (userdel --remove ubuntu || true) && useradd --create-home --uid 1000 swale

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Cycles reaches the GPU through the driver the NVIDIA container runtime mounts
# in, which it does only for the capabilities the image asks for. Plain base
# images ask for nothing, so name the two Cycles needs; a CPU compute type has
# no runtime to read this and ignores it.
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Blender keeps its user configuration under the home directory, which the
# platform mounts writable and per-task; the install itself stays read-only.

# The version of the tool this image is built around. Publishing tags the image
# with it, adding -r1, -r2, ... when that version is already published.
RUN blender --version 2>/dev/null | head -n 1 | cut -d' ' -f2 > /usr/share/swale-image-version
USER swale
WORKDIR /mnt/workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Per-image OCI metadata, and the single source of truth for it. The publish
# workflow reads the title and description out of this file and feeds them to
# docker/metadata-action, because a build --label always overrides a Dockerfile
# LABEL - without that the generated repository-wide description would win.
# The description also becomes the Docker Hub short description, which the
# registry does not read from labels at all.
LABEL org.opencontainers.image.title="Blender 5.2 LTS"
LABEL org.opencontainers.image.description="Blender 5.2 LTS for background rendering in Swale workflows. Backs the blender-render-5-2 task."
LABEL org.opencontainers.image.source="https://github.com/swaleio/task-definitions"
LABEL org.opencontainers.image.documentation="https://github.com/swaleio/task-definitions/blob/main/images/blender-5-2/README.md"
LABEL org.opencontainers.image.licenses="GPL-2.0-or-later"
