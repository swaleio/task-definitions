# Base: debian:13-slim (pin the digest; tag kept for humans)
FROM debian@sha256:28de0877c2189802884ccd20f15ee41c203573bd87bb6b883f5f46362d24c5c2

# Debian's own ffmpeg build: signed packages, a full CPU codec set (libx264,
# libx265, libvpx, libaom, libopus, ...), and a version Debian keeps patched.
# Nothing is compiled here, so the image is the base plus what apt resolves.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --uid 1000 swale

# No ENTRYPOINT: the ffmpeg task is a free-form script task, so its exec.args
# are the full command line (`bash -lc <script>`), exactly like the bash task,
# with ffmpeg and ffprobe on PATH.
USER swale
WORKDIR /mnt/workspace

# Per-image OCI metadata, and the single source of truth for it. The publish
# workflow reads the title and description out of this file and feeds them to
# docker/metadata-action, because a build --label always overrides a Dockerfile
# LABEL - without that the generated repository-wide description would win.
# The description also becomes the Docker Hub short description, which the
# registry does not read from labels at all.
LABEL org.opencontainers.image.title="FFmpeg"
LABEL org.opencontainers.image.description="FFmpeg and ffprobe for Swale workflows. Backs the ffmpeg task."
LABEL org.opencontainers.image.source="https://github.com/swaleio/task-definitions"
LABEL org.opencontainers.image.documentation="https://github.com/swaleio/task-definitions/blob/main/images/ffmpeg/README.md"
LABEL org.opencontainers.image.licenses="GPL-2.0-or-later"
