FROM alpine:3.21

RUN apk add --no-cache bash curl jq coreutils

WORKDIR /app

COPY scripts/dyndns.sh .
RUN chmod +x dyndns.sh

# Run the DYNDNS script every 5 minutes using bash
CMD ["bash", "-c", "while true; do /app/dyndns.sh >> /proc/1/fd/1 2>&1; sleep 300; done"]

