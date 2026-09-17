# Tailscale

A single Tailscale node running in Docker, joining your tailnet using an auth key.

## Services

| Service    | Purpose                                              |
|------------|--------------------------------------------------------|
| tailscale  | Tailscale node - joins your tailnet under `TS_HOSTNAME`  |

## Requirements

- Docker Engine + the Docker Compose plugin
- A Tailscale account
- An auth key generated from the [Tailscale admin console](https://console.tailscale.com/admin/settings/keys)

## Setup

1. Place `docker-compose.yml` and `.env` in the same folder.
2. Edit `.env` and fill in every blank value - none of them have a fallback in the compose file:
   - `TS_AUTHKEY` - an auth key from the Tailscale admin console.
   - `TS_HOSTNAME` - the name this node will show up as on your tailnet and be reachable at (e.g. `server`).
   - `CONFIG_ROOT` - see [CONFIG_ROOT gotcha](#config_root-gotcha) below before setting this.
3. Start the stack:

   ```bash
   docker compose up -d
   ```

4. Check that the node joined your tailnet:

   ```bash
   docker compose logs -f tailscale
   ```

   You should also see it appear under `TS_HOSTNAME` in your [Tailscale admin console's machine list](https://login.tailscale.com/admin/machines).

5. From another device on your tailnet, you should be able to reach this host at `http://<TS_HOSTNAME>` (or its Tailscale IP) - useful once you add other services that share this container's network via `network_mode: service:tailscale`.

## Configuration

| Variable      | Default                  | Description                                                          |
|---------------|-----------------------------|--------------------------------------------------------------------------|
| `TS_AUTHKEY`  | *(required, no default)*    | Tailscale auth key used to authenticate this node onto your tailnet         |
| `TS_HOSTNAME` | *(required, no default)*    | Name this node registers under on your tailnet                              |
| `CONFIG_ROOT` | *(required, no default)*    | Parent folder for Tailscale's persistent state - see below                    |

### CONFIG_ROOT gotcha

The compose file mounts `${CONFIG_ROOT}/ts` as Tailscale's state directory. That means `CONFIG_ROOT` should be the parent folder, not the `ts` folder itself:

- Correct: `CONFIG_ROOT=/home/user/config` -> state ends up at `/home/user/config/ts`
- Wrong: `CONFIG_ROOT=/home/user/config/ts` -> state ends up at `/home/user/config/ts/ts` (nested one level too deep)

If you're already using `CONFIG_ROOT` for other stacks (e.g. a shared config directory with subfolders per service), point it at that same shared parent - Tailscale will just add its own `ts` subfolder inside it.

### Auth key type

Consider what kind of key you generate:

- **Reusable** - lets you tear down and recreate the container without generating a new key each time.
- **Ephemeral** - the node is automatically removed from your tailnet when the container stops. Useful for short-lived or disposable nodes.
- **Tagged** - if your tailnet uses ACL tags, a key tied to a tag can pre-authorize the node, avoiding manual approval in the admin console.

## Notes

- `TS_USERSPACE=false` combined with `/dev/net/tun` and `NET_ADMIN` gives Tailscale full kernel-level networking, which is what allows other containers to share its network via `network_mode: service:tailscale` if you add them later.
- Tailscale's state (its identity/keys on the tailnet) persists at `${CONFIG_ROOT}/ts` on the host. As long as that folder isn't deleted, the container resumes its existing tailnet identity on restart without needing `TS_AUTHKEY` again.
- If you change `TS_HOSTNAME` after the node has already registered, Tailscale treats it as a new device rather than renaming the old one - you may need to remove the stale entry manually from your admin console.
- Since `TS_AUTHKEY` is a credential, make sure `.env` isn't committed to version control (add it to `.gitignore` if this folder is in a git repo).