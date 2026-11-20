# Building and Generating HTML

- To build the project and check for errors, run `lake build`.

- To generate HTML, run `lake exe generate-site`. The HTML ends up in
  `_site`.

- HTML needs to be served with a local web server to work correctly.
  Run `lake exe verso-serve` to serve `_site` as configured in
  `verso-serve.toml`.

# Checks on Pull Requests

Run `npm ci` once to install the pinned JavaScript tools. CI runs
these checks on every pull request:

- Prettier: `npx --no-install prettier --check .`
- ESLint: `npm run lint`
- Ruff, for the Python browser tests:
  `uvx ruff@0.17.6 format --check .` (the version that `ruff.toml`
  requires)
- actionlint, on the workflows: `actionlint`
- The browser tests, after `lake exe generate-site`:
  `uv run --project browser-tests --extra test pytest browser-tests`
