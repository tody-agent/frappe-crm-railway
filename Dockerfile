# =============================================================
# Frappe CRM on Railway — Single-container with Supervisor
# =============================================================
# Based on official frappe_docker/images/custom/Containerfile
# Adapted for Railway's single-volume-per-service constraint
# =============================================================

ARG PYTHON_VERSION=3.11.9
ARG DEBIAN_BASE=bookworm
FROM python:${PYTHON_VERSION}-slim-${DEBIAN_BASE} AS base

# --- System dependencies ---
ARG WKHTMLTOPDF_VERSION=0.12.6.1-3
ARG WKHTMLTOPDF_DISTRO=bookworm
ARG NODE_VERSION=20.19.0
ENV NVM_DIR=/home/frappe/.nvm
ENV PATH=${NVM_DIR}/versions/node/v${NODE_VERSION}/bin/:${PATH}
ENV NODE_VERSION=${NODE_VERSION}

RUN useradd -ms /bin/bash frappe \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
    curl \
    git \
    vim \
    nginx \
    gettext-base \
    file \
    supervisor \
    # weasyprint dependencies
    libpango-1.0-0 \
    libharfbuzz0b \
    libpangoft2-1.0-0 \
    libpangocairo-1.0-0 \
    # For backups
    restic \
    gpg \
    # MariaDB
    mariadb-client \
    less \
    # For healthcheck
    wait-for-it \
    jq \
    # For MIME type detection
    media-types \
    # NodeJS
    && mkdir -p ${NVM_DIR} \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash \
    && . ${NVM_DIR}/nvm.sh \
    && nvm install ${NODE_VERSION} \
    && nvm use v${NODE_VERSION} \
    && npm install -g yarn \
    && nvm alias default v${NODE_VERSION} \
    && rm -rf ${NVM_DIR}/.cache \
    && echo 'export NVM_DIR="/home/frappe/.nvm"' >>/home/frappe/.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >>/home/frappe/.bashrc \
    && echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >>/home/frappe/.bashrc \
    # Install wkhtmltopdf with patched qt
    && if [ "$(uname -m)" = "aarch64" ]; then export ARCH=arm64; fi \
    && if [ "$(uname -m)" = "x86_64" ]; then export ARCH=amd64; fi \
    && downloaded_file=wkhtmltox_${WKHTMLTOPDF_VERSION}.${WKHTMLTOPDF_DISTRO}_${ARCH}.deb \
    && curl -sLO https://github.com/wkhtmltopdf/packaging/releases/download/$WKHTMLTOPDF_VERSION/$downloaded_file \
    && apt-get install -y ./$downloaded_file \
    && rm $downloaded_file \
    # Clean up
    && rm -rf /var/lib/apt/lists/* \
    && rm -fr /etc/nginx/sites-enabled/default \
    && pip3 install frappe-bench \
    # Fixes for non-root nginx and logs to stdout
    && sed -i '/user www-data/d' /etc/nginx/nginx.conf \
    && ln -sf /dev/stdout /var/log/nginx/access.log && ln -sf /dev/stderr /var/log/nginx/error.log \
    && touch /run/nginx.pid \
    && chown -R frappe:frappe /etc/nginx/conf.d \
    && chown -R frappe:frappe /etc/nginx/nginx.conf \
    && chown -R frappe:frappe /var/log/nginx \
    && chown -R frappe:frappe /var/lib/nginx \
    && chown -R frappe:frappe /run/nginx.pid

# =============================================================
# Builder stage — install Frappe + CRM app
# =============================================================
FROM base AS builder

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    wget \
    libcairo2-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libgif-dev \
    librsvg2-dev \
    libffi-dev \
    liblcms2-dev \
    libldap2-dev \
    libmariadb-dev \
    libsasl2-dev \
    libtiff5-dev \
    libwebp-dev \
    pkg-config \
    redis-tools \
    rlwrap \
    tk8.6-dev \
    cron \
    gcc \
    build-essential \
    libbz2-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy apps.json and encode it
COPY apps.json /opt/frappe/apps.json

USER frappe

ARG FRAPPE_BRANCH=version-15
ARG FRAPPE_PATH=https://github.com/frappe/frappe

# Set Node memory and yarn timeout to avoid build failures
ENV NODE_OPTIONS="--max-old-space-size=4096"

RUN bench init \
    --apps_path=/opt/frappe/apps.json \
    --frappe-branch=${FRAPPE_BRANCH} \
    --frappe-path=${FRAPPE_PATH} \
    --no-procfile \
    --no-backups \
    --skip-redis-config-generation \
    --verbose \
    /home/frappe/frappe-bench \
    && cd /home/frappe/frappe-bench \
    && echo "{}" > sites/common_site_config.json \
    && find apps -mindepth 1 -path "*/.git" | xargs rm -fr

# =============================================================
# Final stage — production image with Supervisor
# =============================================================
FROM base AS production

USER root

# Copy built bench from builder
COPY --from=builder --chown=frappe:frappe /home/frappe/frappe-bench /home/frappe/frappe-bench

# Copy configuration files
COPY nginx.conf /etc/nginx/conf.d/frappe.conf
COPY supervisor.conf /etc/supervisor/conf.d/frappe.conf
COPY entrypoint.sh /home/frappe/entrypoint.sh
COPY railway-setup.sh /home/frappe/railway-setup.sh

RUN chmod +x /home/frappe/entrypoint.sh \
    && chmod +x /home/frappe/railway-setup.sh \
    && mkdir -p /var/log/supervisor \
    && chown -R frappe:frappe /var/log/supervisor

WORKDIR /home/frappe/frappe-bench

# NOTE: VOLUME directive removed — Railway bans VOLUME in Dockerfiles
# Attach a volume via Railway UI at /home/frappe/frappe-bench/sites

# Railway will route traffic to this port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -sf http://localhost:80/api/method/ping || exit 1

ENTRYPOINT ["/home/frappe/entrypoint.sh"]
