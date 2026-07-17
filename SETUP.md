# Repository setup

One-time GitHub configuration to enable the automation (CI, Renovate auto-updates,
container image publishing, and the Helm chart repo). No secrets or PATs are
required — every workflow uses the built-in `GITHUB_TOKEN`.

See [RELEASING.md](./RELEASING.md) for how the branches and release flows work once
this is set up.

## 1. Repository basics

- **Make the repo public** (recommended) for free unlimited Actions minutes and free
  GHCR storage. Everything works on a private repo too, just against the limited free
  quotas.
- **Enable Actions** — Settings → Actions → General → "Allow all actions and reusable
  workflows".
- **Workflow token permissions** — Settings → Actions → General → **Workflow
  permissions → "Read and write permissions"**. Required so workflows can push images,
  publish to `gh-pages`, create the `helm-chart-v*` tag, and (on tag releases) create
  the GitHub Release.

## 2. Create the `next` branch

Feature-integration branch; `main` stays the stable release line.

```bash
git branch next && git push origin next
```

## 3. Renovate

- **Install the Renovate GitHub App** (https://github.com/apps/renovate) and grant it
  access to this repo. It reads the committed `renovate.json`.
- Merge Renovate's onboarding PR when it appears.
- **Enable auto-merge** — Settings → General → Pull Requests → check **"Allow
  auto-merge"** (required; `platformAutomerge` uses GitHub's native auto-merge).
- Labels (`dependencies`, `major-update`) are created automatically by Renovate.
- To **hold** a specific auto-merge, mark that PR a **draft** or close it (a label can't
  drive a Renovate rule).

## 4. Branch protection (gates auto-merge)

- First **open one throwaway PR** so the CI checks run once — required-status-check
  names only appear in the dropdown after they have executed.
- Settings → Branches → add rules for **`main`** and **`next`**:
  - **Require status checks to pass** → select **`build-test`**, **`lint`**, **`helm`**
    (the job names from `.github/workflows/ci.yml`).
  - **Do not require pull-request approvals** on `main`, or Renovate auto-merge will
    stall (Renovate cannot approve its own PRs). If you want approvals, you will need to
    approve dependency PRs yourself.

## 5. GHCR (container images)

- The first image push (from a refresh or release) **auto-creates** the
  `ghcr.io/<owner>/calert` package, linked to the repo — no pre-setup.
- To make images publicly pullable: your account/org → **Packages → calert → Package
  settings → Change visibility → Public** (new packages default to private).
- Under the package settings, confirm **"Manage Actions access"** lists this repo with
  **Write** (automatic for repo-created packages).

## 6. Helm chart repo (GitHub Pages)

- The `gh-pages` branch receives packaged charts under `charts/`.
- **Enable Pages** — Settings → Pages → Source: **Deploy from a branch** → Branch:
  **`gh-pages` / (root)**. This serves the Helm repo at
  `https://<owner>.github.io/calert/charts`.
- Update the chart README/install docs to that URL. Consumers add it with:

  ```bash
  helm repo add calert https://<owner>.github.io/calert/charts
  helm repo update
  ```

## 7. Secrets / tokens

**None.** Every workflow uses the automatic `GITHUB_TOKEN`.

## First-run notes

- **golangci-lint**: `ci.yml` runs `version: latest`, which was not enforced before —
  the first PR may surface pre-existing lint findings. If so, add a `.golangci.yml` (or
  pin/relax the linter) to get green.
- **Chart version bootstrap**: the first auto-refresh reads the existing `gh-pages`
  index and patch-bumps above the highest published version — correct out of the box.
- **`values.yaml` registry**: `image.repository` is set to `ghcr.io/kwusen/calert`
  (where GoReleaser publishes). Change it if you publish under a different owner.
- **GoReleaser deprecations**: `goreleaser check` flags pre-existing
  `archives.format` / `dockers` deprecations (not from the automation changes). They
  only warn during `release`; worth cleaning up eventually.

## Smoke test

1. App installed + `renovate.json` present → Renovate opens its first PRs against `main`.
2. A Go/dep patch PR goes green → auto-merges → `refresh.yml` fires → new `:latest` +
   `:<git-describe>` images, a patch-bumped chart on `gh-pages`, and a
   `helm-chart-v*` tag (no GitHub Release).
3. `helm repo update && helm search repo calert --versions` shows the new chart.
