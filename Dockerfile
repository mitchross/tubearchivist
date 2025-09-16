# multi stage to build tube archivist
# build python wheel, download and extract ffmpeg, copy into final image

FROM node:lts-alpine AS npm-builder
COPY frontend/package.json frontend/package-lock.json /
RUN npm i

FROM node:lts-alpine AS node-builder

# RUN npm config set registry https://registry.npmjs.org/

COPY --from=npm-builder ./node_modules /frontend/node_modules
COPY ./frontend /frontend
WORKDIR /frontend

RUN npm run build:deploy

WORKDIR /

# First stage to build python wheel
FROM python:3.11.13-slim-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc libldap2-dev libsasl2-dev libssl-dev git \
    && rm -rf /var/lib/apt/lists/*

# create a virtual environment and install requirements into it
RUN python -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH
COPY ./backend/requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

# build ffmpeg
FROM python:3.11.13-slim-bookworm AS ffmpeg-builder

ARG TARGETPLATFORM

COPY docker_assets/ffmpeg_download.py ffmpeg_download.py
RUN python ffmpeg_download.py $TARGETPLATFORM

# build final image
FROM python:3.11.13-slim-bookworm AS tubearchivist

ARG INSTALL_DEBUG

ENV PYTHONUNBUFFERED=1

# copy python virtualenv with app dependencies
COPY --from=builder /opt/venv /opt/venv
# ensure venv and user-local bin are on PATH for non-root user
ENV PATH=/opt/venv/bin:/home/ta/.local/bin:/app/.local/bin:$PATH

# copy ffmpeg
COPY --from=ffmpeg-builder ./ffmpeg/ffmpeg /usr/bin/ffmpeg
COPY --from=ffmpeg-builder ./ffprobe/ffprobe /usr/bin/ffprobe

# install distro packages needed
RUN apt-get clean && apt-get -y update && apt-get -y install --no-install-recommends \
    nginx \
    atomicparsley \
    curl && rm -rf /var/lib/apt/lists/*

# install debug tools for testing environment
RUN if [ "$INSTALL_DEBUG" ] ; then \
    apt-get -y update && apt-get -y install --no-install-recommends \
    vim htop bmon net-tools iputils-ping procps lsof \
    && pip install --user ipython pytest pytest-django \
    ; fi

# create non-root user and group
RUN groupadd -g 10001 ta && useradd -u 10001 -g ta -m -s /usr/sbin/nologin ta

# make folders
RUN mkdir -p /cache /youtube /app /app/.local/bin \
    /var/cache/nginx /var/log/nginx /var/run/nginx \
    /var/lib/nginx/body \
    && chown -R ta:ta /cache /youtube /app /var/cache/nginx /var/log/nginx /var/run/nginx /var/lib/nginx

# copy config files
COPY docker_assets/nginx.conf /etc/nginx/sites-available/default
# run nginx as non-root user 'ta' (port 8000 is unprivileged)
RUN sed -i 's/^user www\-data\;$/user ta\;/' /etc/nginx/nginx.conf \
    && sed -i 's|pid /run/nginx.pid;|pid /var/run/nginx/nginx.pid;|' /etc/nginx/nginx.conf

# copy application into container
COPY ./backend /app
COPY ./docker_assets/run.sh /app
COPY ./docker_assets/backend_start.py /app
COPY ./docker_assets/beat_auto_spawn.sh /app

COPY --from=node-builder ./frontend/dist /app/static

# volumes
VOLUME /cache
VOLUME /youtube

# start
WORKDIR /app
EXPOSE 8000

RUN chmod +x ./run.sh

# switch to non-root
USER ta:ta

CMD ["./run.sh"]
