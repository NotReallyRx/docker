# Media Stack

Jellyfin + the *arr apps, all behind a single AirVPN WireGuard tunnel via `gluetun`.

## Services

| Service      | Purpose                                              | Behind VPN? |
|--------------|-------------------------------------------------------|:-----------:|
| gluetun      | WireGuard VPN tunnel (AirVPN) other containers route through | —    |
| sonarr       | TV show management                                     | Yes         |
| radarr       | Movie management                                       | Yes         |
| bazarr       | Subtitle management                                    | No          |
| prowlarr     | Indexer manager for Sonarr/Radarr                       | Yes         |
| flaresolverr | Cloudflare-bypass helper for indexers                   | Yes         |
| qbittorrent  | Download client                                         | Yes         |
| jellyfin     | Media server                                            | No          |
| jellyseerr   | Request management for Jellyfin                         | No          |
| wizarr       | Invite/onboarding portal for Jellyfin                    | No          |
| newt         | Pangolin tunnel client (remote access)                   | No          |
| watchtower   | Auto-updates container images                           | No          |

Services marked "Yes" use `network_mode: "service:gluetun"`, so all their traffic — including the ports they expose — actually goes through `gluetun`'s network namespace. That's why their ports are published on the `gluetun` service rather than on the services themselves.

## Requirements

- Docker Engine + the Docker Compose plugin
- An AirVPN account with a WireGuard configuration generated (for the private key, preshared key, and address)


## Setup

1. Place `docker-compose.yml` and `.env` in the same folder.
2. Edit `.env`:
   - Set `CONFIG_ROOT`, `DATA_ROOT`, and `HDD1_ROOT` to match your host's folder layout.
   - Fill in `AIRVPN_PRIVATE_KEY`, `AIRVPN_PRESHARED_KEY`, and `AIRVPN_ADDRESS` from AirVPN's WireGuard config generator.
3. Start the stack:

   ```bash
   docker compose up -d
   ```

4. Check logs, especially for `gluetun` (VPN connection) and any service that depends on it:

   ```bash
   docker compose logs -f gluetun
   ```

## Configuration

### Storage layout

Rather than a separate path variable per service, each container's config folder is a subdirectory under one root:

```
CONFIG_ROOT/
├── sonarr/
├── radarr/
├── prowlarr/
├── jellyfin/
├── jellyseerr/
├── qbittorrent/
├── wizarr/
└── bazarr/
```

So you only need to set `CONFIG_ROOT`, `DATA_ROOT`, and `HDD1_ROOT` once in `.env` — everything else derives from those.

| Variable      | Default                    | Description                                              |
|---------------|------------------------------|------------------------------------------------------------|
| `CONFIG_ROOT` | `N/A`   | Parent folder for every service's config; each gets its own subfolder |
| `DATA_ROOT`   | `N/A`     | Shared media/download data, mounted as `/data` in each container |
| `HDD1_ROOT`   | `N/A`                 | Extra storage volume, mounted as `/hdd1`                    |

### Ports

All ports are configurable in `.env` (`SONARR_PORT`, `RADARR_PORT`, `QBIT_WEBUI_PORT`, etc.) with the same defaults as your original file. If you change one, docker compose picks it up on the next `up -d`.

### PUID / PGID

Most services share `PGID` (default `13000`), with each service getting its own `PUID` so file ownership stays separated per app. `wizarr` and `bazarr` use their own separate `PGID` (`1000` by default) — that matches your original setup, which used a different group for those two.



If any of those becomes true later, a natural split would be `core.yml` (gluetun, sonarr, radarr, prowlarr, flaresolverr, qbittorrent, bazarr) plus `extras.yml` (jellyfin, jellyseerr, wizarr, newt, watchtower), run together with:

```bash
docker compose -f core.yml -f extras.yml up -d
```

## Notes

- Since `sonarr`, `radarr`, `prowlarr`, `flaresolverr`, and `qbittorrent` all share `gluetun`'s network namespace, they can reach each other via `localhost` rather than their container names (e.g. Sonarr talking to qBittorrent should use `localhost:8080`, not `qbittorrent:8080`).