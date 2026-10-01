# format-files-action

[![CI](https://github.com/durandtibo/format-files-action/actions/workflows/ci.yaml/badge.svg)](https://github.com/durandtibo/format-files-action/actions/workflows/ci.yaml)
[![License](https://img.shields.io/badge/license-BSD--3--Clause-blue)](LICENSE)
[![Latest release](https://img.shields.io/github/v/tag/durandtibo/format-files-action?label=release)](https://github.com/durandtibo/format-files-action/tags)

A composite GitHub Action that formats YAML, Makefile, shell, TOML, and Markdown files with `make format`
and, if anything changed, opens a pull request with the result.

Point it at any checked-out repo — it doesn't need its own formatting config or tooling installed.
The action carries its own `Makefile`/`.make/` and installs each formatter on demand, so a caller
only needs `actions/checkout` before it.

## Why use it

Keeping YAML, Makefiles, shell scripts, and Markdown consistently formatted usually means wiring up
several separate tools (Prettier, mbake, shfmt, taplo, ...) in every repo and remembering to
keep their versions and configs in sync. This action centralizes that:

- One step formats all five file types, instead of one workflow step per tool.
- Formatters are pinned and installed by the action itself — nothing to install in the caller.
- It can run in **check mode** to fail CI on unformatted files without touching the working tree.
- It can run in **write mode** and open a pull request with the changes, so formatting never gets
  pushed straight to a protected branch.

## How it works

1. Installs Node.js ([`actions/setup-node`](https://github.com/actions/setup-node)), needed by
   Prettier (and by taplo on Linux).
2. Runs `make --file="$GITHUB_ACTION_PATH/Makefile" format` against the caller's checkout. That
   target runs, in order:
   - [`format-yaml`](.make/yaml.mk) — Prettier
   - [`format-makefile`](.make/makefile.mk) — mbake
   - [`format-shell`](.make/shell.mk) — shfmt
   - [`format-toml`](.make/toml.mk) — taplo
   - [`format-markdown`](.make/markdown.mk) — Prettier

   Each tool is installed on demand if it isn't already on the runner:

   | Tool     | Linux                                    | macOS                     |
   | -------- | ---------------------------------------- | ------------------------- |
   | Prettier | `npm install -g prettier`                | `npm install -g prettier` |
   | mbake    | `pipx install mbake` (or `pip3 install`) | `pipx install mbake`      |
   | shfmt    | `go install`, else release binary        | `brew install shfmt`      |
   | taplo    | `npm install -g @taplo/cli`              | `brew install taplo`      |

3. Diffs the working tree with `git diff` to determine the `changed` output.
4. **Check mode** (`check: true`): if anything changed, reverts it with `git checkout -- .` and
   fails the step. No pull request is opened.
5. **Write mode** (default): if anything changed and `create-pull-request` is `true`, generates a
   token and opens a pull request with the changes via
   [`peter-evans/create-pull-request`](https://github.com/peter-evans/create-pull-request):
   - By default it uses `token` (the job's `GITHUB_TOKEN`), which does **not** trigger downstream
     workflows (e.g. CI) on the resulting PR — a GitHub limitation.
   - If `github-app-client-id`/`github-app-private-key` are set instead, it exchanges them for an
     installation token via
     [`actions/create-github-app-token`](https://github.com/actions/create-github-app-token) and
     uses that, so the PR runs through normal CI/review.

## What gets formatted

| Type     | Tool     | Files                                        |
| -------- | -------- | -------------------------------------------- |
| YAML     | Prettier | `**/*.yml`, `**/*.yaml`                      |
| Makefile | mbake    | `Makefile` and `*.mk` in the repository root |
| Shell    | shfmt    | `*.sh`, found recursively                    |
| TOML     | taplo    | `*.toml`, found recursively                  |
| Markdown | Prettier | `**/*.md`                                    |

Notes:

- A `.make/` directory is skipped by the shell and TOML formatters (it is treated as a vendored
  shared-Makefiles subtree). Prettier respects the caller's own `.prettierignore`/`.gitignore`
  conventions, so use those to exclude paths such as `node_modules`.
- Only the formatting targets run; the linters in the Makefile (`make lint`) are not part of the
  action.
- Linux and macOS runners are supported (tested in CI); Windows runners are not.

## Requirements

| Requirement            | Notes                                                                                               |
| ---------------------- | --------------------------------------------------------------------------------------------------- |
| `actions/checkout`     | Must run before this action so there are files (and a git repo) to format.                          |
| `make`                 | Must be available on the runner (present by default on GitHub-hosted `ubuntu-*`/`macos-*` runners). |
| `contents: write`      | Needed on the job if a pull request should be opened (write mode).                                  |
| `pull-requests: write` | Needed on the job if a pull request should be opened (write mode).                                  |

## Inputs

| Name                     | Description                                                                                                         | Required | Default                                             |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------- | -------- | --------------------------------------------------- |
| `node-version`           | Version of Node.js to use (needed by Prettier and markdownlint).                                                    | No       | `lts/*`                                             |
| `check`                  | Check formatting without writing changes; fails the action if any file is not formatted.                            | No       | `false`                                             |
| `create-pull-request`    | Open a pull request with the changes using peter-evans/create-pull-request. Ignored when `check` is `true`.         | No       | `true`                                              |
| `token`                  | Token used by peter-evans/create-pull-request to create the pull request. Ignored if `github-app-client-id` is set. | No       | `${{ github.token }}`                               |
| `github-app-client-id`   | Client ID of a GitHub App used to generate a token for creating the pull request, instead of `token`.               | No       | (none)                                              |
| `github-app-private-key` | Private key of the GitHub App identified by `github-app-client-id`.                                                 | No       | (none)                                              |
| `branch`                 | Branch name used by peter-evans/create-pull-request.                                                                | No       | `bot/format-files`                                  |
| `commit-message`         | Commit message used by peter-evans/create-pull-request.                                                             | No       | `style: format files`                               |
| `title`                  | Pull request title used by peter-evans/create-pull-request.                                                         | No       | `style: format files`                               |
| `body`                   | Pull request body used by peter-evans/create-pull-request.                                                          | No       | `Format YAML, Makefile, shell, and Markdown files.` |

## Outputs

| Name                  | Description                                                                               |
| --------------------- | ----------------------------------------------------------------------------------------- |
| `changed`             | Whether any file was reformatted (write mode) or is not correctly formatted (check mode). |
| `pull-request-number` | Number of the pull request created with the formatting changes, if any.                   |
| `pull-request-url`    | URL of the pull request created with the formatting changes, if any.                      |

## Usage

### Basic (format via pull request)

```yaml
permissions:
  contents: write
  pull-requests: write

steps:
  - uses: actions/checkout@v4
  - uses: durandtibo/format-files-action@v1
```

### Check formatting in CI

Fails the job if any file isn't already formatted, without leaving any changes behind:

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: durandtibo/format-files-action@v1
    with:
      check: true
```

### Reading the outputs

```yaml
- name: Format files
  id: format
  uses: durandtibo/format-files-action@v1

- name: Show result
  run: echo "changed=${{ steps.format.outputs.changed }} pr=${{ steps.format.outputs.pull-request-url }}"
```

### Using a GitHub App token so the PR runs CI

```yaml
permissions:
  contents: write
  pull-requests: write

steps:
  - uses: actions/checkout@v4
  - uses: durandtibo/format-files-action@v1
    with:
      github-app-client-id: ${{ secrets.APP_CLIENT_ID }}
      github-app-private-key: ${{ secrets.APP_PRIVATE_KEY }}
```

### Custom branch, commit message, and PR title/body

```yaml
- uses: durandtibo/format-files-action@v1
  with:
    branch: bot/reformat
    commit-message: "chore: reformat files"
    title: "chore: reformat files"
    body: Automated formatting pass.
```

### Scheduled formatting workflow

Runs weekly and opens a pull request if anything drifted out of format:

```yaml
name: Format

on:
  schedule:
    - cron: "0 6 * * 1"
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  format:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - uses: durandtibo/format-files-action@v1
        with:
          github-app-client-id: ${{ secrets.APP_CLIENT_ID }}
          github-app-private-key: ${{ secrets.APP_PRIVATE_KEY }}
```

## Development

The repository's own `Makefile` includes the shared targets in [`.make/`](.make). Run `make help`
to list them, and `make format` / `make lint` to format or lint locally. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow, [SECURITY.md](SECURITY.md) for reporting
vulnerabilities, and the [Code of Conduct](CODE_OF_CONDUCT.md).

Workflows in [`.github/workflows`](.github/workflows) test the action on Linux and macOS in write
mode (including idempotency) and check mode, and run it weekly against this repo.

## License

Distributed under the [BSD 3-Clause License](LICENSE).
