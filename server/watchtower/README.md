# Watchtower

Watches your other containers and automatically pulls/updates their images.

## Requirements

- Docker Engine + the Docker Compose plugin

## Setup

1. Place `docker-compose.yml` and `.env` in this folder.
2. Edit `.env` if you want to change the defaults (optional — works out of the box).
3. Start it:

```bash
   docker compose up -d
```

4. Check logs:

```bash
   docker compose logs -f
```

## Configuration

| Variable                    | Default | Description                                                        |
|------------------------------|---------|------------------------------------------------------------------------|
| `WATCHTOWER_POLL_INTERVAL`   | `86400` | How often (in seconds) watchtower checks for image updates             |
| `WATCHTOWER_LABEL_ENABLE`    | `false` | If `true`, only updates containers labeled `com.centurylinklabs.watchtower.enable=true` |

## Notes

- Watchtower is given access to the Docker socket (`/var/run/docker.sock`) so it can see and update every container on the host — not just the ones in this stack. If you only want it managing specific containers, set `WATCHTOWER_LABEL_ENABLE=true` above and add the label `com.centurylinklabs.watchtower.enable=true` to those containers.
- By default, watchtower checks for updates once every 24 hours (`86400` seconds). Lower `WATCHTOWER_POLL_INTERVAL` for more frequent checks.