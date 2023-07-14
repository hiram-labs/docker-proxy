FROM node:10.1.0-alpine

WORKDIR /usr/home/localtunnel

RUN apk update && \
    apk --no-cache add \
    git

RUN git clone --depth 1 https://github.com/localtunnel/server.git . \
    && yarn install --production \
    && yarn cache clean

# this may break the build in future if the maintainer of the repo fixes the issue
# where a wrong shebang instruction is attach on the first line of `./bin/server`
RUN sed -i '1d' ./bin/server

RUN apk del \
    git \
    && rm -rf /var/cache/apk/*

ENTRYPOINT [ "node", "-r", "esm", "./bin/server" ]