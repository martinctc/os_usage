

# Open Source Usage Automated Workflow

[![](https://github.com/martinctc/os_usage/actions/workflows/main.yaml/badge.svg)](https://github.com/martinctc/os_usage/actions/workflows/main.yaml)

This repository produces an automatically-updated download/usage report
for the [`vivainsights`](https://microsoft.github.io/vivainsights/) R
package and the
[`vivainsights`](https://microsoft.github.io/vivainsights-py/) Python
package, using publicly available data from CRAN and PyPI.

The full report is rendered to [`os_usage.html`](./os_usage.html) and
refreshed by GitHub Actions on the 1st and 15th of every month (and on
every push to `main`).

This file was last rendered at 10/06/2026 10:18.

## What the report shows

- Lifetime download totals from CRAN (via the `cranlogs` API) and PyPI
  (via [pepy.tech](https://pepy.tech/)).
- Rolling 30-day download totals (excluding the last two days, which are
  typically incomplete).
- A daily time series chart of downloads from both registries.

## Data sources

| Source | Endpoint | Coverage | Notes |
|----|----|----|----|
| CRAN | `https://cranlogs.r-pkg.org/downloads/total/...` | Full lifetime from package’s first release | Counts each download from RStudio’s CRAN mirror; does not include other mirrors. |
| PyPI (daily) | `https://pypistats.org/api/packages/{pkg}/overall` | Rolling ~180 days | Returns two rows per date (`with_mirrors` and `without_mirrors`); the report uses `with_mirrors` only to avoid double-counting. |
| PyPI (lifetime) | `https://api.pepy.tech/api/v2/projects/{pkg}` | Full lifetime | Backed by the `bigquery-public-data.pypi.file_downloads` dataset. Requires an API key (see below). Falls back to summing accumulated daily snapshots if the key is missing. |

Daily snapshots are persisted to `data/*.rds` on every successful run so
that the historical series survives the rolling pypistats window.

## Repository layout

    .
    ├── os_usage.qmd            # The report source (R + Quarto)
    ├── readme.qmd              # Source for this README
    ├── data/                   # Accumulated daily download snapshots (.rds)
    ├── renv.lock               # Pinned R package versions
    ├── .github/workflows/      # CI: setup R, render, commit
    └── os_usage.html           # Rendered HTML report (auto-generated)

## Setup

### `PEPY_API_KEY` secret (required for accurate PyPI lifetime totals)

The report uses [pepy.tech](https://pepy.tech/) for the PyPI lifetime
figure because PyPI’s own API only exposes ~180 days of history.

1.  Create a free account at <https://pepy.tech/>.
2.  Generate an API key on your [user profile](https://pepy.tech/user).
    The free tier allows 5 requests/minute, which is ample for this
    twice-monthly schedule.
3.  In this repo: **Settings → Secrets and variables → Actions → New
    repository secret**, name it `PEPY_API_KEY`, and paste the key.

Without the key the workflow still runs; the PyPI lifetime card will
simply read *“(Lifetime, snapshots)”* and use the (potentially
incomplete) sum of accumulated snapshots instead of the true total.

To rotate the key, generate a new one on pepy.tech, update the GitHub
secret, then revoke the old key.

### Local rendering

You need R (4.4 is what CI uses), Quarto, and the packages in
`renv.lock`.

``` bash
# 1. Restore R dependencies
Rscript -e "renv::restore()"

# 2. (Optional) export your pepy.tech key for lifetime PyPI totals
export PEPY_API_KEY=...           # PowerShell: $env:PEPY_API_KEY = '...'

# 3. Render
quarto render os_usage.qmd --to html --output os_usage.html
quarto render readme.qmd   --to gfm  --output README.md
```

**Windows note:** `renv::restore()` can fail with `Access is denied`
while installing `stringi` if OneDrive or an antivirus tool is scanning
the renv cache. Close R, retry, or temporarily pause OneDrive on the
`renv/` folder.

## Caveats

- **CRAN noise around releases.** Download spikes around release dates
  partly reflect automated archiving and mirror sync, not user installs.
- **pypistats 180-day window.** The daily time series for PyPI prior to
  ~180 days ago is reconstructed from accumulated `.rds` snapshots in
  `data/`. Any gap in the snapshot history (e.g., the period when the
  workflow was failing in late 2024 / 2025) will appear as missing PyPI
  days in the plot. The pepy.tech lifetime total is unaffected.
- **Historical PyPI inflation.** Prior to commit `555bf76` the report
  mistakenly summed both `with_mirrors` and `without_mirrors` rows from
  pypistats, inflating daily PyPI values by ~3×. Snapshots written
  before that commit retain the inflated values; new snapshots will
  overwrite them as the rolling window advances.
- **Lifetime totals exclude bots only as far as the upstream sources
  do.** Neither cranlogs nor pepy.tech filter all CI/mirror traffic.

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md). In short: **do not hand-edit
`README.md` or `os_usage.html`** — they are regenerated from
`readme.qmd` and `os_usage.qmd` by CI.

## License

Released under the [MIT License](./LICENSE).
