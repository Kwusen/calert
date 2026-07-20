# Releasing & automation

calert uses a two-branch flow with automated Go/dependency refreshes and manual,
parameterized app/chart releases. Everyone runs the newest version; old releases
are not maintained.

> One-time GitHub configuration (Actions, Renovate, GHCR, Pages, branch protection)
> lives in [SETUP.md](./SETUP.md).

## Branches

- **`main`** — the current stable release line. **Go toolchain and dependency
  updates land here directly** (Renovate → CI → auto-merge). Refreshes build
  `main`, so they always carry the latest Go + patched deps. Features are *not* on
  `main`, so a refresh can never surface unreleased work.
- **`next`** — feature integration. Feature branches → PR → `next`. Features reach
  `main` only when you cut a release (merge `next` → `main`, then tag).

## What's automated

| Trigger | Result | How to stop it |
|---|---|---|
| Any PR to `main`/`next` | CI: build, vet, test, lint, helm lint (required checks) | — |
| Renovate Go/dep PR → `main` | Auto-merge patch/minor on green (major deps = manual) | mark the PR a **draft** or close it |
| Go/dep change on `main` (`go.mod`/`go.sum`) | **Refresh**: rebuild `main` → `:latest` + immutable `:<git-describe>` + `:<tag>-go<ver>` images + a Helm chart release + `helm-chart-v*` tag | `[skip refresh]` in the commit message |

A refresh does **not** bump the app version, create app tags, or make a GitHub Release.

## Cutting an app release (manual)

1. Merge `next` → `main` (bring in the finished features). Resolve any `go.mod`
   conflicts by keeping `main`'s newer versions, then `go mod tidy`.
2. Tag `main` HEAD: `git tag vX.Y.Z && git push origin vX.Y.Z`.
   - This triggers `release.yml`: GoReleaser builds images **and creates the GitHub
     Release**, then a Helm chart is published. Suppress with `[skip release]` in the
     tagged commit if you want to craft it manually instead.
3. Or, for full control, run the **App release** workflow (`app-release.yml`) with
   inputs: `ref`, `app_version` (e.g. `v2.4.0`), `publish_chart`, `chart_version`,
   `go_version`, `create_github_release`. This builds artifacts to your parameters and
   does **not** create git tags. A GitHub Release is only created if you set
   `create_github_release: true` (otherwise create it manually if you want one). Both this and
   `release.yml` share the reusable `_release.yml`.

## Chart-only release / overhaul (manual)

The Helm chart version is **independent** of the app version (`appVersion` carries the
deployed identity). Automated refreshes only ever patch-bump the chart above the
highest published version, so they never collide with a deliberate bump.

- Bump `contrib/helm/calert/Chart.yaml` `version` (minor/major for an overhaul) and
  edit templates in a PR (CI guards it). Merge.
- Run the **Chart release** workflow (`chart-release.yml`). It publishes exactly your
  `Chart.yaml` version (it must exceed the highest published version) and pushes a
  `helm-chart-v<version>` tag. No GitHub Release.

## Version schemes

- **Images:** `:latest` (moving), `:vX.Y.Z` (release, immutable), `:<git-describe>`
  (refresh, immutable exact build), `:<tag>-go<ver>` (convenience).
- **Chart:** independent, monotonically increasing; `appVersion` = the image tag it
  deploys. Each chart release gets a `helm-chart-v<version>` git tag (a tag, **not** a
  GitHub Release), which cannot trigger the `v*` app-release path.
