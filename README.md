

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

This file was last rendered at 15/06/2026 00:34.

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

## Methodology

### CRAN (`cranlogs`)

`cranlogs.r-pkg.org` aggregates download logs from RStudio’s CRAN mirror
(`cloud.r-project.org`). Each row is one HTTP fetch of a package tarball
or binary.

- **Lifetime totals** are computed by querying from `2013-01-01` to
  today (`cranlogs` keeps logs from late 2012 onwards). For packages
  first released after 2013 the query still returns the correct count —
  pre-release dates simply report zero.
- **Inflation factors to be aware of:** new releases trigger a download
  spike from automated builds, R install scripts, and Bioconductor/CI
  mirroring. Spikes the day after a release rarely reflect real user
  installs.
- **Mirror coverage:** cranlogs only sees the RStudio mirror, not the
  dozens of other CRAN mirrors worldwide. The reported number is
  therefore a *lower bound* on actual CRAN downloads.

### PyPI (daily — `pypistats`)

`pypistats.org/api/packages/{pkg}/overall` returns a rolling
**~180-day** window of daily counts, broken down into two categories:

| Category | What it counts |
|----|----|
| `with_mirrors` | All download requests, including those routed via known mirror networks (e.g. Bandersnatch). |
| `without_mirrors` | Same, with traffic from known mirror IP ranges subtracted. |

**This report uses `with_mirrors` only** to match the convention
pypistats.org displays on its own dashboards and badges. Summing both
categories (as the report did prior to commit `555bf76`) double-counts
and inflates the numbers by ~3×.

Because the API only covers ~180 days, the daily series for older dates
is reconstructed from `data/*.rds` snapshots written on each run. If
snapshots are missing for a period (e.g. the late-2024 / 2025 outage),
that period will appear as gaps in the plot.

### PyPI (lifetime — `pepy.tech`)

[pepy.tech](https://pepy.tech/) backs its totals with Google BigQuery’s
`bigquery-public-data.pypi.file_downloads`, which contains every PyPI
download event since mid-2016. The `total_downloads` field returned by
`/api/v2/projects/{pkg}` is the lifetime sum across all categories.

- **Authentication:** requires a free API key (`X-API-Key` header). See
  the [setup section
  above](#pepy_api_key-secret-required-for-accurate-pypi-lifetime-totals).
- **Fallback:** if `PEPY_API_KEY` is unset, the lifetime card shows the
  sum of accumulated daily snapshots and is labelled
  `(Lifetime, snapshots)` to make the reduced fidelity obvious.
- **Bot filtering:** pepy.tech does *not* exclude CI traffic (pip
  installs from GitHub Actions, GitLab, etc. all count). This is the
  same caveat as pypistats, just over a longer window.

### Snapshot retention

Each render writes a snapshot named
`data/{pkg}_{min_date}_{max_date}.rds`. To keep the directory bounded,
the report prunes everything except the `keep_snapshots`
most-recently-modified snapshots per package (default 26 ≈ one year of
bi-monthly runs). Adjust via the `keep_snapshots` Quarto parameter in
`os_usage.qmd`.

### Reusing this report for another package

The report is parameterized. Render it for any other CRAN+PyPI package
by overriding the Quarto parameters:

``` bash
quarto render os_usage.qmd \
  -P pkg_name:somepackage \
  -P start_date:2020-01-01 \
  --to html --output some_report.html
```

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md). In short: **do not hand-edit
`README.md` or `os_usage.html`** — they are regenerated from
`readme.qmd` and `os_usage.qmd` by CI.

## License

Released under the [MIT License](./LICENSE).
