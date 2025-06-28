ARG DESKDEV_BUILD_VERSION=dev
FROM node:24.3.0-bookworm-slim AS frontend-builder

WORKDIR /app

COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci

COPY frontend ./
RUN npm run build

FROM python:3.12.10-slim AS base
FROM base AS backend-builder

WORKDIR /app
ENV PYTHONPATH='/app'

ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    POETRY_CACHE_DIR=/tmp/poetry_cache

RUN apt-get update -y \
    && apt-get install -y curl make git build-essential \
    && python3 -m pip install poetry --break-system-packages

COPY pyproject.toml poetry.lock ./
RUN touch README.md
RUN export POETRY_CACHE_DIR && poetry install --no-root && rm -rf $POETRY_CACHE_DIR

FROM base AS deskdev-app

WORKDIR /app

# re-declare for this section
ARG DESKDEV_BUILD_VERSION

ENV RUN_AS_DESKDEV=true
# A random number--we need this to be different from the user's UID on the host machine
ENV DESKDEV_USER_ID=42420
ENV SANDBOX_LOCAL_RUNTIME_URL=http://host.docker.internal
ENV USE_HOST_NETWORK=false
ENV WORKSPACE_BASE=/opt/workspace_base
ENV DESKDEV_BUILD_VERSION=$DESKDEV_BUILD_VERSION
ENV SANDBOX_USER_ID=0
ENV FILE_STORE=local
ENV FILE_STORE_PATH=/.deskdev
RUN mkdir -p $FILE_STORE_PATH
RUN mkdir -p $WORKSPACE_BASE

RUN apt-get update -y \
    && apt-get install -y curl ssh sudo \
    && rm -rf /var/lib/apt/lists/*

# Default is 1000, but OSX is often 501
RUN sed -i 's/^UID_MIN.*/UID_MIN 499/' /etc/login.defs
# Default is 60000, but we've seen up to 200000
RUN sed -i 's/^UID_MAX.*/UID_MAX 1000000/' /etc/login.defs

RUN groupadd app
RUN useradd -l -m -u $DESKDEV_USER_ID -s /bin/bash deskdev && \
    usermod -aG app deskdev && \
    usermod -aG sudo deskdev && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN chown -R deskdev:app /app && chmod -R 770 /app
RUN sudo chown -R deskdev:app $WORKSPACE_BASE && sudo chmod -R 770 $WORKSPACE_BASE
USER deskdev

ENV VIRTUAL_ENV=/app/.venv \
    PATH="/app/.venv/bin:$PATH" \
    PYTHONPATH='/app'

COPY --chown=deskdev:app --chmod=770 --from=backend-builder ${VIRTUAL_ENV} ${VIRTUAL_ENV}

COPY --chown=deskdev:app --chmod=770 ./microagents ./microagents
COPY --chown=deskdev:app --chmod=770 ./deskdev ./deskdev
COPY --chown=deskdev:app --chmod=777 ./deskdev/runtime/plugins ./deskdev/runtime/plugins
COPY --chown=deskdev:app pyproject.toml poetry.lock README.md MANIFEST.in LICENSE ./

# This is run as "deskdev" user, and will create __pycache__ with deskdev:deskdev ownership
RUN python deskdev/core/download.py # No-op to download assets
# Add this line to set group ownership of all files/directories not already in "app" group
# deskdev:deskdev -> deskdev:app
RUN find /app \! -group app -exec chgrp app {} +

COPY --chown=deskdev:app --chmod=770 --from=frontend-builder /app/build ./frontend/build
COPY --chown=deskdev:app --chmod=770 ./containers/app/entrypoint.sh /app/entrypoint.sh

USER root

WORKDIR /app

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["uvicorn", "deskdev.server.listen:app", "--host", "0.0.0.0", "--port", "3000"]
