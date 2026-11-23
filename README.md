# docker-multistage-stack

A small Flask app and a PostgreSQL database run with Docker Compose. The app
image is built in two stages and runs as a non-root user. The database is only
reachable from the app over a private bridge network and publishes no port to
the host. The image is scanned with Trivy for High and Critical CVEs before the
stack starts.

## Run

    bash setup.sh

Needs Docker with the Compose plugin and a user that can run `docker`. The
script creates `.env` with a random database password, builds the image, scans
it, starts the stack, and runs `scripts/verify.sh`. If the scan finds a High or
Critical vulnerability that has a fix, it stops before starting anything.

The app listens on `http://127.0.0.1:8000`:

    curl http://127.0.0.1:8000/        visit counter stored in Postgres
    curl http://127.0.0.1:8000/health  checks the database connection
    curl http://127.0.0.1:8000/info    shows the uid the process runs as

Stop and remove everything, including the database volume:

    docker compose down -v

## Layout

    Dockerfile               two stages: builder and runtime
    docker-compose.yml       web, db, and two networks
    app/                     Flask app and requirements
    db/init.sql              creates the visits table on first start
    scripts/scan.sh          Trivy scan, exits 1 on findings
    scripts/verify.sh        checks non-root, network isolation, health
    scripts/compare-size.sh  builds a single-stage image to compare size
    docs/                    scan report, check output, size comparison

## Image

The builder stage has gcc and the PostgreSQL headers to compile `psycopg2`
into a virtualenv. The runtime stage starts from a clean `python:3.12-alpine`,
adds only `libpq`, removes pip, and copies the virtualenv across, so no
compiler or package manager ships in the final image. The process runs as uid
10001 (`USER 10001:10001`).

At run time the container also has a read-only root filesystem with a tmpfs
for `/tmp`, all Linux capabilities dropped, and `no-new-privileges` set.

## Networking

- `frontend`: normal bridge, only the web container is attached, port 8000 is
  published on 127.0.0.1.
- `backend`: bridge with `internal: true`, web and db are attached. It has no
  route to the outside world, so the database cannot reach the internet either.
- `db` has no `ports:` entry. `scripts/verify.sh` checks that nothing is
  published and nothing listens on host port 5432.

## Secrets

Database settings come from `.env`, which is git-ignored. `.env.example` has
placeholders only. `docker-compose.yml` fails early if a value is missing.

## Scanning

    bash scripts/scan.sh

Uses a local `trivy` if installed, otherwise runs the `aquasec/trivy` image.
Defaults to HIGH and CRITICAL with unfixed vulnerabilities ignored. Override
with `TRIVY_SEVERITY`. The report is saved to `docs/trivy-report.txt`.
