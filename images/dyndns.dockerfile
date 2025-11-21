FROM alpine:3.21

RUN apk add --no-cache bash curl jq coreutils dcron

WORKDIR /app

COPY scripts/dyndns.sh .

RUN chmod +x dyndns.sh

RUN echo "*/5 * * * * /app/dyndns.sh >> /proc/1/fd/1 2>&1" > /etc/crontabs/root

CMD ["crond", "-f", "-d", "8"]
