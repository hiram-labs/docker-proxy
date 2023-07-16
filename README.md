## Networking and proxies

1. caddy
2. globaltunnel
3. wireguard

### Requirements

- docker
- docker compose

---

### Dev setup

```
start your docker client
git clone https://github.com/hiram-labs/docker-proxy.git
docker-proxy
```

---

### Commands

**_HINT_** `chmod 700 run`

Use the `./run` shell script to execute the following commands:

- start the docker-compose file in detach mode

```
./run start
```

- stop the docker-compose file

```
./run stop
```

- get shell into caddy container

```
./run cdy:shell
```

- reload Caddyfile after changes

```
./run cdy:reload
```

- format Caddyfile

```
./run cdy:fmt
```

- get shell into globaltunnel container

```
./run gt:shell
```
