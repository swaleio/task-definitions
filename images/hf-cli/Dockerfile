# Base: python:3.13-slim (pin the digest; tag kept for humans)
FROM python@sha256:eb43ff125d8d58d7449dcba7d336c23bcac412f526d861db493b9994d8010280

RUN pip install --no-cache-dir "huggingface_hub[cli,hf_xet]" \
 && useradd --create-home --uid 1000 swale

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Keep the Hub cache on the shared workspace volume so blobs survive across
# tasks in a run instead of filling the container's ephemeral layer.
ENV HF_HOME=/mnt/workspace/.hf-cache

USER swale
WORKDIR /mnt/workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
