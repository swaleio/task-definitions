# Base: python:3.13-slim (pin the digest; tag kept for humans)
FROM python@sha256:eb43ff125d8d58d7449dcba7d336c23bcac412f526d861db493b9994d8010280

RUN pip install --no-cache-dir "huggingface_hub[cli,hf_xet]" \
 && useradd --create-home --uid 1000 swale

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# The Hub cache stays at its default under the user's home. A caller that wants
# blobs to survive across tasks can relocate it onto the mounted workspace via
# the INPUT_HF_HOME input (see entrypoint.sh); the image does not force it.

USER swale
WORKDIR /mnt/workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
