FROM python:3.12-slim@sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=secret,id=proxy_ca PIP_CERT=${PIP_CERT:-/run/secrets/proxy_ca} sh -c 'if [ ! -f "$PIP_CERT" ]; then unset PIP_CERT; fi; pip install --no-cache-dir -r requirements.txt'
COPY --chown=65534:65534 . .
USER 65534:65534
EXPOSE 18120
CMD ["python", "app.py"]
