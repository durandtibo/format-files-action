# format-yaml-action

A GitHub Action that formats (or checks the formatting of) YAML files used as
GitHub Actions workflows and actions in `.github/`, using [Prettier](https://prettier.io/).

## Usage

The action **rewrites** YAML files in place.

```yaml
- uses: actions/checkout@v4
- uses: <owner>/format-yaml-action@v1

- name: Commit changes
  run: |
    git config user.name 'github-actions[bot]'
    git config user.email 'github-actions[bot]@users.noreply.github.com'
    git diff --quiet || (git add -A && git commit -m 'style: format yaml files' && git push)
```

## Inputs

| Name               | Description                                         | Required | Default                              |
| ------------------ | ----------------------------------------------------- | -------- | -------------------------------------- |
| `path`              | Path(s)/glob patterns to format, space-separated       | No       | `.github/**/*.yml .github/**/*.yaml`   |
| `prettier-version`  | Version (or dist-tag) of Prettier to use, e.g. `latest` | No       | `latest`                               |
| `node-version`      | Version of Node.js to use                              | No       | `lts/*`                                |
| `config-path`       | Path to a Prettier config file to use                  | No       | `${{ github.action_path }}/.prettierrc.yml` |
| `check`             | Check formatting without writing changes; fails the action if any file is not formatted | No | `false` |

By default, `config-path` points at this repo's [`.prettierrc.yml`](.prettierrc.yml), so the
action enforces the same style regardless of whether the consuming repository defines its own
Prettier config. Pass a different `config-path` (or point it at a config in the consumer's
checkout) to override it.

Set `check: true` to only verify formatting (e.g. in a PR check) instead of rewriting files in
place; the action fails if any matched file is not already formatted.

## Outputs

| Name      | Description                                                                             |
| --------- | ---------------------------------------------------------------------------------------- |
| `changed` | Whether any file was reformatted (write mode) or is not correctly formatted (check mode) |

## Development

This repository dogfoods itself: [`.github/workflows/format-yaml.yml`](.github/workflows/format-yaml.yml)
runs the action against its own `.github` directory and commits any changes on push to `main`.

Pull requests are validated by [`.github/workflows/ci.yaml`](.github/workflows/ci.yaml), which runs
[`.github/workflows/test-local.yaml`](.github/workflows/test-local.yaml) — a matrix of Linux/macOS
runners that exercises the action against fixtures in [`test-data/`](test-data) to check that
badly-formatted YAML gets fixed, already-formatted YAML is left untouched, and `config-path` is
honored.
