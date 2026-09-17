# Forgejo

Self-hosted Git service (Forgejo) backed by MySQL.

## Services

| Service | Purpose                              |
|---------|----------------------------------------|
| server  | Forgejo — the Git hosting/web UI         |
| db      | MySQL database backing Forgejo            |

`server` waits for `db` to report healthy (via its `mysqladmin ping` healthcheck) before starting.

## Requirements

- Docker Engine + the Docker Compose plugin
- A domain/hostname pointed at this host if you want SSH clone URLs to resolve correctly (`SSH_DOMAIN`)

## Setup

1. Place `docker-compose.yml` and `.env` in the same folder.
2. Edit `.env` and fill in every blank value — `CONFIG_ROOT`, `SSH_DOMAIN`, and all four database fields have no fallback in the compose file, so the stack won't come up correctly (or at all) until they're set:
   - Set `CONFIG_ROOT` to where you want Forgejo's data and the MySQL database stored.
   - Set `SSH_DOMAIN` to your actual domain.
   - Set `MYSQL_ROOT_PASSWORD`, `MYSQL_USER`, `MYSQL_PASSWORD`, and `MYSQL_DATABASE` — pick real, unique passwords here rather than something like `forgejo` or `password`.
3. Start the stack:

   ```bash
   docker compose up -d
   ```

4. Watch the logs while the database initializes and Forgejo starts:

   ```bash
   docker compose logs -f
   ```

5. Visit `http://<host>:<WEB_PORT>` to complete Forgejo's first-run setup.

## Configuration

### Storage layout

Both services store their data under one root:

```
CONFIG_ROOT/
├── forgejo/   → mounted at /data           (repos, config, Forgejo state)
└── mysql/     → mounted at /var/lib/mysql  (database files)
```

| Variable      | Default | Description                                                    |
|---------------|---------|------------------------------------------------------------------|
| `CONFIG_ROOT` | *(required, no default)* | Parent folder for Forgejo data and the MySQL database |

### Versions

| Variable          | Default | Description                     |
|-------------------|---------|------------------------------------|
| `FORGEJO_VERSION` | `14`    | Forgejo image tag                    |
| `MYSQL_VERSION`   | `8`     | MySQL image tag                       |

### Forgejo

| Variable       | Default                   | Description                                                    |
|----------------|----------------------------|-----------------------------------------------------------------|
| `FORGEJO_UID`  | `1000`                      | User ID Forgejo runs as inside the container                       |
| `FORGEJO_GID`  | `1000`                      | Group ID Forgejo runs as inside the container                       |
| `WEB_PORT`     | `5000`                      | Host port mapped to Forgejo's web UI (container port 3000)           |
| `SSH_PORT`     | `223`                       | Host port for git-over-SSH, mapped to container port 22                |
| `SSH_DOMAIN`   | *(required, no default)*   | Domain shown in SSH clone URLs — set to your real domain                |

### Database

All four of these are required — there's no fallback, and no value should be left as a guessable default:

| Variable               | Default                    | Description                                        |
|------------------------|------------------------------|--------------------------------------------------------|
| `MYSQL_ROOT_PASSWORD`  | *(required, no default)*    | MySQL root password — pick something strong and unique    |
| `MYSQL_USER`           | *(required, no default)*    | Database user Forgejo connects as                            |
| `MYSQL_PASSWORD`       | *(required, no default)*    | Password for that user — pick something strong and unique   |
| `MYSQL_DATABASE`       | *(required, no default)*    | Database name Forgejo uses                                    |

## Notes

- Nothing in `.env` has a working fallback anymore — `CONFIG_ROOT`, `SSH_DOMAIN`, and all four database fields must be filled in before `docker compose up`, or you'll get broken paths, a broken SSH domain, or a MySQL container that won't initialize.
- `SSH_PORT` is used in two places (the `server` environment and the `ports` mapping) so they always match — you only need to change it once in `.env`.
- **Pick good passwords.** `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD` are exactly the kind of thing that ends up hardcoded and forgotten — generate real random passwords (e.g. `openssl rand -base64 24`) rather than reusing something short or memorable.
- Since `.env` holds real database credentials, make sure it isn't committed to version control (add it to `.gitignore` if this folder is in a git repo).
- Forgejo's first-run web setup lets you configure the admin account and site title — the database connection fields will already be filled in from the environment variables above, so you shouldn't need to re-enter them there.