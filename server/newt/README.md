# Newt

Pangolin tunnel client — gives this host secure remote access via Pangolin.

## Requirements

- Docker Engine + the Docker Compose plugin
- A Pangolin account, with a site set up to get your `NEWT_ID` and `NEWT_SECRET`

## Setup

1. Place `docker-compose.yml` and `.env` in this folder.
2. Edit `.env` and fill in `NEWT_ID` and `NEWT_SECRET` from your Pangolin site's setup page. Leave `PANGOLIN_ENDPOINT` as-is unless you're self-hosting Pangolin.
3. Start it:

```bash
   docker compose up -d
```

4. Check logs if it isn't connecting:

```bash
   docker compose logs -f
```

## Configuration

| Variable            | Default                    | Description                                                   |
|---------------------|-------------------------------|-----------------------------------------------------------------|
| `PANGOLIN_ENDPOINT` | `https://app.pangolin.net`   | The Pangolin instance to connect to — only change this if self-hosting Pangolin |
| `NEWT_ID`           | *(required, no default)*     | Newt client ID, from your Pangolin site's setup page             |
| `NEWT_SECRET`       | *(required, no default)*     | Newt client secret, from your Pangolin site's setup page          |

## Notes

- `NEWT_ID` and `NEWT_SECRET` are credentials — make sure `.env` isn't committed to version control (add it to `.gitignore` if this folder is in a git repo).