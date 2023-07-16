FROM node:10.1.0-alpine

WORKDIR /usr/home/globaltunnel

RUN apk update && \
    apk --no-cache add \
    git

RUN git clone --depth 1 https://github.com/nanacnote/globaltunnel.git . \
    && npm ci --production \
    && npm cache clean --force

RUN apk del \
    git \
    && rm -rf /var/cache/apk/*

ENTRYPOINT [ "node", "./server/index" ]
