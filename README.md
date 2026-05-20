# trash-inspection-container

Docker container build and CI pipeline for the trash-inspection feature of the
Microting eForm platform. Produces two images:

- **Host image** — Angular frontend (`eform-angular-frontend`) + API
  (`eFormAPI.Web`) with the `TrashInspection.Pn` plugin embedded.
- **Service image** — background worker (`eform-debian-service`) with the
  `ServiceTrashInspectionPlugin` embedded.

## Images produced

- `microtingas/trash-inspection-container:latest` / `:${VERSION}`
- `microtingas/trash-inspection-service-container:latest` / `:${VERSION}`

Tagged builds are also pushed to `registry.microting.com/microtingas/...`.

## Upstream plugin sources

- https://github.com/microting/eform-angular-trash-inspection-plugin
- https://github.com/microting/eform-service-trash-inspection-plugin

## How CI runs

GitHub Actions workflow `.github/workflows/dotnet-core-docker.yml` is
triggered by pushing a tag matching `v*.*.*`. It:

1. Builds both Docker images.
2. Runs Cypress end-to-end tests and WebdriverIO E2E tests against the host
   image (with MariaDB + RabbitMQ containers).
3. Runs xUnit unit tests for the plugin.
4. On success, pushes both images to Docker Hub and to
   `registry.microting.com`.

## Local build examples

Host image:

```
docker build . \
  -f Dockerfile \
  -t microtingas/trash-inspection-container:latest \
  --build-arg GITVERSION=1.0.0 \
  --build-arg PLUGINVERSION=1.0.0
```

Service image:

```
docker build . \
  -f Dockerfile-service \
  -t microtingas/trash-inspection-service-container:latest \
  --build-arg GITVERSION=1.0.0 \
  --build-arg PLUGINVERSION=1.0.0
```

Both builds expect sibling checkouts of `eform-angular-frontend`,
`eform-angular-trash-inspection-plugin`, `eform-debian-service`, and
`eform-service-trash-inspection-plugin` next to this repo (matching the
layout the CI workflow sets up via `actions/checkout`).

## Helper scripts

- `compare-nuget-packages.sh <dir>` — bash script that scans `.csproj` files
  under a directory and reports `PackageReference` entries pinned to
  different versions across projects.
- `extract_packages.py` — Python equivalent of the above, walks the current
  directory tree and prints any NuGet package referenced at more than one
  version.
