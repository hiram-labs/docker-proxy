FROM alpine:3.21

RUN apk add --no-cache bash curl jq coreutils

WORKDIR /app

COPY scripts/dyndns.sh .
RUN chmod +x dyndns.sh

CMD ["sh", "-c", "while true; do /app/dyndns.sh >> /proc/1/fd/1 2>&1; sleep 300; done"]
