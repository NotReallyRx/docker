# Caddy

A [Caddy](https://caddyserver.com/) reverse proxy / web server container running in host network mode.

## Requirements

- Docker Engine + the Docker Compose plugin

## Setup

1. Place `docker-compose.yml` and `.env` in the same folder.
2. Edit `.env` to match your setup — at minimum, check `CONF_PATH`.
3. Under `CONF_PATH`, make sure you have three subfolders: `conf` (must contain your Caddyfile), `certs`, and `site`.
4. Start the container:

```bash
   docker compose up -d
```

5. Watch the logs:

```bash
   docker compose logs -f
```

6. Stop it:

```bash
   docker compose down
```

   (Your config, certs, site files, and Caddy's internal data/config volumes persist — `down` does not delete them.)

## Configuration

All settings live in `.env`. Nothing needs to be edited in `docker-compose.yml` itself.

| Variable         | Description                                                                                     |
|------------------|---------------------------------------------------------------------------------------------------|
| `CONTAINER_NAME` | Name of the Docker container                                                                     |
| `CADDY_VERSION`  | Tag of the `caddy` image to use                                                                  |
| `CONF_PATH`      | Host folder containing `conf/` (→ `/etc/caddy`), `certs/` (→ `/certs`), and `site/` (→ `/srv`)    |

## Notes

- `network_mode: host` and `cap_add: NET_ADMIN` are fixed in `docker-compose.yml` since they're structural, not per-deployment settings — host networking is what lets Caddy bind privileged ports directly and handle things like automatic HTTPS without extra port mapping.
- `caddy_data` and `caddy_config` are named Docker volumes (not host paths) holding Caddy's internal state (certificates it obtains, its runtime config) — they persist across `docker compose down` and container recreation.
- For full configuration options (Caddyfile syntax, TLS settings, etc.), see the [Caddy documentation](https://caddyserver.com/docs/).


## Example Config entry

```Caddyfile
service.example.com {
    reverse_proxy localhost:1234
    tls /certs/fullchain.pem /certs/privkey.pem
}
```
P.S. For me i had a wilcard cert from LetsEncyrpt or smth for my domain which had a wildcard set for my machine's tailscale ip so /certs/*.pem was used for every entry as they all used the same domain but a different subdomain