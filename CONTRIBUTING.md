# Contributing

Thanks for taking the time to contribute! This is a small repo with a focused purpose, so the workflow is intentionally light.

## Ground rules

- **Do not hand-edit `README.md` or `os_usage.html`.** They are regenerated from `readme.qmd` and `os_usage.qmd` by the `Render README` GitHub Action on every push to `main`. Any manual changes to the generated files will be silently overwritten on the next run.
- **Do not commit secrets.** The `PEPY_API_KEY` lives only as a GitHub Actions secret. If you need it for local rendering, export it in your shell — never commit it or paste it into a tracked file.
- **Snapshots in `data/` are append-only history.** They are committed by CI and should not be hand-edited. If you need to fix historical data, do it in a clearly-labelled commit and explain why in the message.

## Local development

See the [README](./README.md#local-rendering) for the full setup. The short version:

```bash
Rscript -e "renv::restore()"
quarto render os_usage.qmd --to html --output os_usage.html
```

## Making a change

1. Branch off `main`.
2. Edit `os_usage.qmd` (the report) or `readme.qmd` (the README) — *not* the generated `.html` / `.md` outputs.
3. Render locally to confirm the change works (`quarto render os_usage.qmd`).
4. If you changed dependencies, run `renv::snapshot()` and commit the updated `renv.lock`.
5. Open a pull request describing **what the change is for** and **how you verified it**. Include a screenshot of the rendered report if the change is visual.

## Adding a new data source

If you want to add another download / usage signal:

1. Add a new R chunk in `os_usage.qmd` that fetches the data, handling HTTP failures gracefully (see the existing pypistats chunk for the pattern).
2. Join it into `full_dl_snapshot` so it gets persisted to the next `.rds` snapshot.
3. Document the source in the **Data sources** table in `readme.qmd`, including its coverage window and any quirks.
4. If the source requires authentication, add a clear setup section to the README and a fallback path for runs without the secret.

## Bumping the R version

The workflow pins R 4.4 because `renv.lock` includes packages (e.g. `base64enc 0.1-3`) that fail to load on newer R due to removed C symbols. If you want to move to a newer R:

1. Update `r-version` in `.github/workflows/main.yaml`.
2. Refresh the affected packages: `renv::update("base64enc", ...)` then `renv::snapshot()`.
3. Verify the workflow run is green before merging.

## Reporting an issue

Open a GitHub issue with:
- What you expected vs. what happened.
- A link to the failing Actions run (if applicable).
- The rendered totals you were comparing against.
