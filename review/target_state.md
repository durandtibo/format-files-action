# Target state of `format-files-action`

Review date: 2026-11-15. Scope: `action.yml`, `Makefile`, `.make/`, workflows, `README.md`.
Breaking changes are accepted. The future state matters more than the current one.

## 1. Properties of the action

These are the properties the action must have. Section 4 lists the changes that make them true.

| #   | Property           | Definition                                                                                                                                                                                                                           |
| --- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| P1  | **Purpose**        | Format YAML, Makefile, shell, TOML and Markdown files of the caller's checkout with one step.                                                                                                                                        |
| P2  | **Zero setup**     | The caller needs only `actions/checkout`. No config file, no tool installed. It works in any repo, not just this one.                                                                                                                |
| P3  | **Two modes**      | _Write_ (default): reformat, then open a PR. _Check_: fail on unformatted files, change nothing, open no PR.                                                                                                                         |
| P4  | **Deterministic**  | Same input and same action version give the same output. Every formatter is pinned, so the action's version is the only thing that changes output.                                                                                   |
| P5  | **Idempotent**     | A second run on the output of the first reports `changed=false`.                                                                                                                                                                     |
| P6  | **Fast**           | Install only the tools whose file types exist in the repo. Install with no package-manager update and no `sudo`. One Prettier run.                                                                                                   |
| P7  | **Safe**           | Inputs go through `env:`. Third-party actions are pinned to SHAs. Least privilege. Check mode never writes. No `sudo`. Downloads are verified.                                                                                       |
| P8  | **Portable**       | Linux and macOS runners. No GNU-only or BSD-only flags. Windows is out of scope.                                                                                                                                                     |
| P9  | **Observable**     | Outputs `changed`, `pull-request-number`, `pull-request-url`. In check mode, the log and annotations list the files that are not formatted.                                                                                          |
| P10 | **Simple**         | Few inputs, one script path, one Makefile, tested end to end by CI. Docs, defaults and behaviour agree.                                                                                                                              |
| P11 | **Immutable pins** | Consumers pin an exact release tag or SHA. No floating tags.                                                                                                                                                                         |
| P12 | **Fails loudly**   | Every failure stops the action with a non-zero exit, an `::error` annotation and a message that says what failed, why, and where to start fixing it. Nothing fails silently, and nothing is reported as success when it was skipped. |

## 2. Review of the current state

### 2.1 Bugs and contradictions (fix first)

| #   | Finding                                                                                                                                                                                                                                                                                                                                                            | Violates |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- |
| B1  | **The action is broken outside this repo.** `Makefile` does `include .make/help.mk`, which resolves against the _current directory_, not the Makefile's directory. I checked: running `make --file=<action>/Makefile` in a repo without `.make/` fails with `.make/help.mk: No such file or directory`. The README promises "carries its own `Makefile`/`.make/`". | P1, P2   |
| B2  | **CI cannot see B1.** `ci-action.yaml` and `nightly-test-released.yaml` run the action on a checkout of this repo, which has its own `.make/`. No test uses a consumer-like repo.                                                                                                                                                                                  | P10      |
| B3  | **README says tools are "pinned". They are not.** Prettier, mbake and taplo install at `latest`, and shfmt via `go install ...@latest`. A new Prettier release changes formatting of every consumer with no change in this action. The bot PRs then churn.                                                                                                         | P4       |
| B4  | **README examples use `@v1`**, a floating tag. The repo policy says releases are exact tags only, and `v1` does not exist.                                                                                                                                                                                                                                         | P11      |
| B5  | **Defaults use conventional-commit prefixes** (`style: format files`), against the repo's own Git rules. The default `body` omits TOML. `description` in `action.yml` omits TOML. `node-version` says it is needed by markdownlint, which the action never runs.                                                                                                   | P10      |
| B6  | **Change detection ignores untracked files** (`git diff --quiet`) and needs a git repo. Check mode "reverts" by `git checkout -- .`, so it _does_ write to the tree before reverting.                                                                                                                                                                              | P3, P7   |
| B7  | **Prettier errors are matched by grepping its output** for `No files matching the pattern`. Prettier has `--no-error-on-unmatched-pattern`.                                                                                                                                                                                                                        | P10      |

### 2.2 Weaknesses

| #   | Finding                                                                                                                                                                                                                                                                                                                           | Violates |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| W1  | **The action reuses the developer Makefile.** It parses 12 `.mk` files, including `uv.mk`, `git.mk` and `github.mk`, which the action never uses. A shared-file sync (`bot-sync-shared-makefile`) can change consumer behaviour silently.                                                                                         | P4, P10  |
| W2  | **Every tool is installed even if unused.** A repo with no `.toml` still installs taplo. `setup-node` always runs, though hosted runners ship Node.                                                                                                                                                                               | P6       |
| W3  | **Install paths are slow and risky.** `sudo apt-get update`, `go install` then `sudo cp`, `curl` to a fixed `/tmp/<tool>` then `sudo mv`, `brew install` (runs `brew update`), `pip3 --break-system-packages`. No checksum on downloaded binaries.                                                                                | P6, P7   |
| W4  | **Prettier runs twice** (YAML, then Markdown) with two startups.                                                                                                                                                                                                                                                                  | P6       |
| W5  | **Scope is inconsistent.** Prettier formats `.make/` and `.github/`, while shell and TOML skip `.make/`. Shell files are found only by `*.sh`, so extensionless scripts with a shebang are skipped. Makefiles are only the root `Makefile` and root `*.mk`.                                                                       | P1, P10  |
| W6  | **Check-mode UX is poor.** The failure is `exit 1` with no list of files and no annotation. The caller must read the formatter log.                                                                                                                                                                                               | P9       |
| W7  | **Missing PR hygiene inputs.** The branch is never deleted after merge (`delete-branch`). There is no way to run only some formatters.                                                                                                                                                                                            | P6, P10  |
| W8  | **Test gaps.** Check mode is tested with YAML only. Write mode has no TOML fixture. No test for: consumer repo without `.make/`, no matching files, untracked output, extensionless shell script, `.prettierignore`. The PR-creation path is untested (cannot be, locally; see 4.7).                                              | P10      |
| W9  | **Duplicated test workflow.** `nightly-test-released.yaml` copies `ci-action.yaml` job for job. A new test must be added twice, and the copies drift.                                                                                                                                                                             | P10      |
| W10 | **Failures are silent or cryptic.** `show-tool` only warns (`⚠️ x is not on the PATH`) and the build goes on. Prettier output is captured, echoed late, and errors are filtered by `grep`. A failed download or install surfaces as a raw `curl`/`npm` error with no hint. Check mode ends with a bare `exit 1`. No step summary. | P9, P12  |

### 2.3 What is already good (keep)

- Inputs pass through `env:`. Actions are pinned to SHAs with ratchet comments. Every `run:` sets `shell: bash`.
- The app token is generated only when a PR will be created, with minimal permissions.
- `changed` and the PR outputs are a good, small interface.
- Fixtures are generated at runtime, so the format bot never "fixes" them.
- The matrix of OSes comes from one external place.

## 3. Design decisions

1. **The action keeps reusing the repo `Makefile` and the shared `.make/*.mk`** (maintainer decision). There is no second Makefile.
   - The root `Makefile` anchors its includes with `$(dir $(lastword $(MAKEFILE_LIST)))`, so it works from any directory (fixes B1). This is a root `Makefile` change, which CLAUDE.md allows.
   - `.make/` is not edited in this repo (CLAUDE.md). Changes to `.make/*.mk` described below land in the upstream shared-Makefile repository and reach this repo through `bot-sync-shared-makefile`. See "Where each change lands" below.
   - The sync coupling (W1) is accepted. It is reduced by the regression tests: a synced change that breaks consumers fails the consumer-directory tests before release.
2. **Check mode uses each tool's check flag, not "write then revert"** (fixes B6, W6): `prettier --check`, `shfmt -d`/`-l`, `taplo format --check`, `mbake format --check`. Nothing is written, no git is needed, and the unformatted files are listed.
3. **Write mode keeps the git diff**, but with `git status --porcelain`, so untracked files count. This is what `create-pull-request` itself sees.
4. **Pinned tool versions** as Makefile variables (`PRETTIER_VERSION`, `SHFMT_VERSION`, `TAPLO_VERSION`, `MBAKE_VERSION`), updated by Dependabot-style bumps or the bot. Output depends only on the action tag (P4).
5. **Install by release binary into a user directory, no `sudo`, no brew, no apt.**
   - `$(HOME)/.cache/format-files-action/bin` is prepended to `PATH` inside the Makefile.
   - shfmt and taplo: pinned GitHub release binary for `Linux|Darwin` × `x86_64|arm64`, checksum-verified, `mktemp` for downloads.
   - Prettier: `npm install --prefix <cache> prettier@$(PRETTIER_VERSION)`, using the Node preinstalled on hosted runners.
   - mbake: `pipx`/`uv tool install mbake==$(MBAKE_VERSION)`. Preinstalled `pipx` exists on hosted runners.
6. **Detect before installing.** For each type, `git ls-files`-style detection (including untracked, respecting `.gitignore`) decides whether the tool is installed and run. No `.toml` means no taplo (P6).
7. **Drop `setup-node` and the `node-version` input** (maintainer decision: the simplest and most robust option). Hosted runners have Node. A runner without Node gets a clear error (`node is required`, exit 69, see 4.8). Callers that need a specific Node version run `actions/setup-node` themselves before the action.
8. **One scope rule** (maintainer decision: follow the recommendation). Format tracked and untracked non-ignored files. The action excludes nothing, so a `.make/` directory in a consumer is formatted like any other. Consumers exclude paths with `.prettierignore`, `.gitignore` and the tools' own ignore files. This drops the special-casing in the README notes.
   - Wrinkle for this repo: its `.make/` is synced and must not drift. Once the upstream prune of `.make` is removed, this repo excludes `.make/` itself, with `.prettierignore` and a `.taplo.toml` `exclude`.
9. **No `tools` input** (maintainer decision: detection only). A formatter runs only if files of its type exist (decision 6). A consumer that wants to leave files alone uses ignore files. Adding an input later is non-breaking.

### Where each change lands

| Change                                                                 | Decision | Lands in                                                    |
| ---------------------------------------------------------------------- | -------- | ----------------------------------------------------------- |
| Anchored includes; `format` and `check-format` entry targets           | 1, 2     | this repo, root `Makefile`                                  |
| `action.yml` (steps, inputs, outputs, `delete-branch`, no setup-node)  | 4.1, 7   | this repo                                                   |
| Pinned versions, checksum-verified installs, no `sudo`                 | 4, 5     | upstream `.make/*.mk`                                       |
| Detection with `git ls-files`, shell shebang support                   | 6        | upstream `.make/*.mk`                                       |
| One Prettier run for YAML and Markdown                                 | 4.3      | upstream `.make/*.mk` (shared `prettier.mk` target)         |
| Check targets (`check-format-yaml`, `-toml`, `-markdown`, `-makefile`) | 2        | upstream `.make/*.mk` (`check-format-shell` already exists) |
| Failure messages and exit codes                                        | 4.8      | upstream `.make/*.mk` and the `action.yml` step             |
| Drop the `.make` prune in shell and TOML targets                       | 8        | upstream `.make/*.mk`                                       |
| Tests, README, workflows                                               | 4.5, 4.6 | this repo                                                   |

Until an upstream change is synced, this repo can ship the parts that live in the root `Makefile` and `action.yml`. The upstream changes are plan items 3 and 4 and must be released upstream first.

## 4. Target state

### 4.1 Interface (`action.yml`)

Inputs (breaking changes marked):

| Name                     | Default                                                  | Change                                                                              |
| ------------------------ | -------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `check`                  | `false`                                                  | Unchanged. Validate the value: only `true`/`false`, else fail with a clear message. |
| `create-pull-request`    | `true`                                                   | Unchanged.                                                                          |
| `token`                  | `${{ github.token }}`                                    | Unchanged.                                                                          |
| `github-app-client-id`   | `""`                                                     | Unchanged.                                                                          |
| `github-app-private-key` | `""`                                                     | Unchanged.                                                                          |
| `branch`                 | `bot/format-files`                                       | Unchanged (matches the repo branch convention).                                     |
| `commit-message`         | `Format files`                                           | **Changed default** (no `style:` prefix).                                           |
| `title`                  | `Format files`                                           | **Changed default.**                                                                |
| `body`                   | `Format YAML, Makefile, shell, TOML and Markdown files.` | **Changed default** (adds TOML).                                                    |
| `node-version`           | -                                                        | **Removed** (decision 7).                                                           |

Always passed to `create-pull-request`: `delete-branch: true`.

Outputs: `changed`, `pull-request-number`, `pull-request-url` (unchanged). In check mode `changed=true` is still set before the step fails, as today.

Metadata: description lists all five types. Branding unchanged.

### 4.2 Steps (`action.yml`)

1. **Format files** (`id: format`, `shell: bash`, env `CHECK`, `ACTION_PATH`):
   `make --file="$ACTION_PATH/Makefile" --no-print-directory $TARGET`, where `TARGET` is `check-format` or `format` (both defined in the root `Makefile`). The script then sets `changed` from `git status --porcelain` (write mode) or from the Makefile's exit status (check mode, exit 2 means unformatted). In check mode it prints `::error file=<path>::not formatted` per file.
2. **Generate GitHub App token**: unchanged. Condition: write mode, PR enabled, `changed`, and both app inputs set.
3. **Create pull request**: unchanged, plus `delete-branch: true`.

Sketch of the shell part:

```bash
set -euo pipefail
if [ "$CHECK" = 'true' ]; then
  if make --file="$ACTION_PATH/Makefile" --no-print-directory check-format; then
    echo 'changed=false' >>"$GITHUB_OUTPUT"
  else
    echo 'changed=true' >>"$GITHUB_OUTPUT"
    exit 1
  fi
else
  make --file="$ACTION_PATH/Makefile" --no-print-directory format
  if [ -n "$(git status --porcelain)" ]; then
    echo 'changed=true' >>"$GITHUB_OUTPUT"
  else
    echo 'changed=false' >>"$GITHUB_OUTPUT"
  fi
fi
```

Note: `make` failing for a tool error (not "unformatted") must not be reported as `changed=true`. The `check-format` target therefore exits `1` for "unformatted" only after all tools ran, and exits `2`+ (make's own error code) for real errors. The script maps only the former.

### 4.3 Makefile layering (root `Makefile` + shared `.make/`)

Root `Makefile` (this repo):

- Includes `.make/*.mk` through anchored paths.
- Keeps `install-tools`, `format`, `lint`. Adds `check-format`: runs every `check-format-*` target, collects all failures, then exits 1.
- `format` and `check-format` are the only targets the action calls.

Shared `.make/*.mk` (upstream), target behaviour:

| Target                | Role                                                               |
| --------------------- | ------------------------------------------------------------------ |
| `format-<type>`       | Format one file type in write mode.                                |
| `check-format-<type>` | Same files, check flag, nothing written, unformatted files listed. |
| `install-<tool>`      | Install one pinned tool into the cache dir if missing. Idempotent. |

Rules:

- Variables, all overridable: `PRETTIER_VERSION`, `SHFMT_VERSION`, `TAPLO_VERSION`, `MBAKE_VERSION`, `BIN_DIR`.
- Files are found once with `git ls-files --cached --others --exclude-standard -z -- '*.yaml' '*.yml' '*.md' ...` and passed to each tool. This honours `.gitignore`, includes new files and skips `node_modules` when ignored. It replaces `find` and its GNU/BSD differences. A non-git directory falls back to `find`.
- Shell detection: `*.sh` plus extensionless files with a `#!` shebang for `sh|bash` (`shfmt -f` on the file list).
- Prettier is called once with the YAML and Markdown files together (`--write` or `--check`, `--no-error-on-unmatched-pattern`).
- Makefiles: root `Makefile`, `GNUmakefile`, `*.mk` at any depth, with the shared `bake.toml` (stays in `.make/`) unless the caller has its own.
- Empty file list for a type: print `no <type> files`, skip install, succeed.
- `$(HOME)/.cache/format-files-action/bin` is prepended to `PATH` for the make run.
- Portable shell only: no `sed -i`, no `xargs -r`, no `find -print0` dependence beyond POSIX `-exec ... +` or the git NUL list through `xargs -0` guarded by a non-empty check.

Tool table for the README (target):

| Tool     | Pinned by          | Installed with                         | Installed when         |
| -------- | ------------------ | -------------------------------------- | ---------------------- |
| Prettier | `PRETTIER_VERSION` | `npm install --prefix <cache>`         | YAML or Markdown files |
| mbake    | `MBAKE_VERSION`    | `pipx install` (fallback `pip --user`) | Makefile files         |
| shfmt    | `SHFMT_VERSION`    | release binary, checksum verified      | shell files            |
| taplo    | `TAPLO_VERSION`    | release binary, checksum verified      | TOML files             |

Already-installed tools are used only if their version equals the pin. Otherwise the pinned one is installed in the cache dir and wins on `PATH`.

### 4.4 Repo layout

```text
action.yml
Makefile               # anchored includes; install-tools, format, check-format, lint
.make/                 # shared, synced from upstream, not edited here (includes bake.toml)
```

No new directory. The bot, the developer and the action all run the same `make format` (CLAUDE.md: "put make targets in the steps").

### 4.5 Workflows

- **One test workflow body for both ci and nightly** (fixes W9). Make `ci-action.yaml` and `nightly-test-released.yaml` share a reusable `lib-test-action.yaml` taking the action reference. Because `uses:` cannot be an expression, keep two thin jobs only if GitHub still forbids it; the test steps themselves live once in a composite action under `.github/actions/assert-*` (e.g. `assert-changed`, `assert-clean-tree`). If this proves heavier than the duplication, keep the two files but generate the second from the first by a `make` target and have CI fail on drift.
- **Run the tests in a consumer-like directory** (fixes B2). Use a fresh `git init` dir under `$RUNNER_TEMP` as the working directory, not the repo checkout. The action path stays this repo. This alone would have caught B1.
- **New and extended cases**, one behaviour per job or step:

| Case                                                      | Mode            | Expect                                                                    |
| --------------------------------------------------------- | --------------- | ------------------------------------------------------------------------- |
| Each of YAML, Makefile, shell, TOML, Markdown unformatted | write           | file reformatted, `changed=true`                                          |
| Second run                                                | write           | `changed=false` (idempotent)                                              |
| Each type unformatted                                     | check           | fails, `changed=true`, tree untouched, file named in the log              |
| All formatted                                             | check           | success, `changed=false`                                                  |
| Empty repo (no matching files)                            | both            | success, `changed=false`, no tool installed                               |
| Extensionless shell script with shebang                   | write           | reformatted                                                               |
| File listed in `.prettierignore` / `.gitignore`           | write           | untouched                                                                 |
| Untracked new unformatted file                            | check           | fails                                                                     |
| Invalid `check` value                                     | -               | fails with a clear message                                                |
| Prettier syntax error in a YAML file                      | write and check | fails with exit 65, names the file, no `changed` output, no PR            |
| Checksum mismatch (tampered pin)                          | -               | fails with exit 70 and the install hint                                   |
| Failure messages                                          | all             | log contains the `::error` title, the cause and the "where to start" line |
| Run from a repo with no `.make/`                          | write           | works (regression for B1; fails on `main` today)                          |
| Tool version is the pinned one                            | -               | `prettier --version` etc. printed in the log match the pins               |

- **PR creation** cannot run against this repo in CI without side effects. Cover it by the weekly `bot-format-files.yaml` (uses the released action) and say so in the README and PR descriptions. Do not claim it is tested by the matrix.
- `ci-format.yaml` runs `make lint-*` as now, plus lints `action.yml` with actionlint's composite checks where supported.
- `bot-format-files.yaml` keeps using the last released tag, which is correct (it dogfoods the release).
- Update the header comments of `ci-action.yaml` and `nightly-test-released.yaml` when the tests change, and the pinned tag comment in `nightly-test-released.yaml` on each release.

### 4.6 Documentation

- README: lead with the properties (section 1), then usage. Examples pin an exact tag (`@v0.1.0`) or a SHA. Remove `@v1` everywhere.
- Inputs and outputs tables regenerated from `action.yml` in the same PR (no drift).
- State plainly: the default `GITHUB_TOKEN` PR does not trigger CI; "Allow GitHub Actions to create and approve pull requests" must be enabled in the repo settings.
- Document the scope rule (decision 8), how to exclude files (`.prettierignore`, `.gitignore`, `.taplo.toml`), and that Node must be on the runner (decision 7).
- Document the migration (4.9).

### 4.7 Security

- No `sudo`. No writes outside `$HOME/.cache/format-files-action` and the workspace.
- Downloaded binaries are verified by SHA-256 pinned in the Makefile next to the version.
- Temporary files via `mktemp`, never fixed `/tmp/<name>`.
- Inputs are never interpolated in `run:`. The only input read by the Makefile path is `check`, validated in the step before use.
- The App token keeps the minimal permissions. Keep `permission-workflows: write` only because the action may reformat `.github/workflows/*.yaml`. Document why.

### 4.8 Failing loudly (P12)

Principle: the first red line in the log must tell the user what happened and what to do next. A failure is never swallowed, downgraded to a warning, or reported as `changed=false`.

**Error contract.** Every failure goes through one Makefile macro and one shell helper that print, in this order:

1. `::error title=<short title>::<what failed>` (GitHub annotation, visible on the run summary page).
2. **Cause**: the command and its exit code, plus the last lines of its output.
3. **Where to start**: one concrete next step (a command to run locally, an input to change, a doc anchor).

**Failure classes** (each has a distinct exit code and a message):

| Class                     | Example                                            | Message must say                                                                                 | Exit                       |
| ------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------------ | -------------------------- |
| Invalid input             | `check: yes`                                       | The input, the received value, the allowed values.                                               | 64                         |
| Missing prerequisite      | no `git`, no `node`, not a git repo for write mode | The missing tool and how to provide it (`actions/setup-node`, `actions/checkout`).               | 69                         |
| Tool install failed       | download 404, checksum mismatch, `npm` error       | The tool, pinned version, URL or package, and "run `make --file=<path> install-<tool>`".         | 70                         |
| Formatter crashed         | Prettier syntax error in `bad.yaml`                | The tool, the file and line it printed, and "fix the syntax, the formatter cannot run".          | 65                         |
| Unformatted files (check) | `check: true` with drift                           | The list of files, one annotation per file, and "run `make format` or `<action>` in write mode". | 1                          |
| PR creation failed        | token lacks permission, Actions cannot create PRs  | The permission or repo setting to change (see README), the token source used.                    | from `create-pull-request` |

Rules:

- **No silent skips.** Skipping a type because it has no files is logged (`no toml files, skipping`). Skipping because of an error is a failure.
- **No warning where a failure is meant.** `show-tool` fails when the tool is not on `PATH` after install.
- **Never swallow output.** Formatter output streams live to the log, grouped per tool with `::group::`. Remove the `grep "No files matching"` filter (B7).
- **Errors distinguish "your files" from "the action".** Unformatted files and syntax errors in the caller's files are the caller's to fix. Install and prerequisite failures say so and point at the action's issue tracker with the action version and runner OS/arch printed.
- **Fail early.** Validate inputs and prerequisites before any install or write, so a typo fails in seconds.
- **`changed` is only set when known.** On a crash it is unset, never `false`.
- **Step summary.** Write a short table to `$GITHUB_STEP_SUMMARY`: mode, tools run or skipped, files changed or unformatted, action version, tool versions. On failure it also holds the "where to start" text.
- **Check-mode failure text** includes the exact reproduction: `Run 'make format' locally, or run this action without 'check' to open a pull request.`
- **README** gets a "Troubleshooting" table mapping each class and message to its cause and fix.

### 4.9 Breaking changes and migration

| Change                                                  | Impact                                                                                        | Migration                                              |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| `node-version` input removed, `setup-node` step removed | Callers passing it get a warning for an unknown input. Self-hosted runners without Node fail. | Remove the input. Install Node in the job if needed.   |
| Default commit message and title are `Format files`     | PR titles change                                                                              | Set `title` and `commit-message` to keep the old text. |
| Tools pinned to specific versions                       | Output may differ from `latest` once                                                          | Accept the first diff. Later runs are stable.          |
| Scope includes `.make/` for shell and TOML              | More files formatted in repos with a `.make/`                                                 | Add the paths to `.gitignore`/`.prettierignore`.       |
| Check mode no longer touches the tree                   | None for callers                                                                              | -                                                      |

Release as a new minor/major exact tag. Do not create floating tags.

## 5. Implementation plan

One logical change per PR, in this order (each branched from an up-to-date `main`):

1. `bugfix/action-makefile-path` — fix B1 (anchor the includes in the root `Makefile`) and add the consumer-directory regression test (B2). Highest value, smallest diff. **Ship first.**
2. `docs/fix-readme-and-defaults` — B4, B5 (README `@v1`, defaults, TOML in body and description).
3. `refactor/shared-makefile-installs` (upstream `.make/`, then sync) — decisions 4, 5, 6, 8: pinned and verified installs, detection, one Prettier run, shell shebang support, no `.make` prune.
4. `feat/check-mode-without-writes` — decision 2 and 3, `check-format` targets (upstream) and the root `check-format`, annotations (W6, B6, B7).
   4b. `feat/fail-loudly` — error contract, exit codes, step summary, troubleshooting docs (W10, P12).
5. `feat/delete-branch` — pass `delete-branch: true` to `create-pull-request` (W7).
6. `refactor/remove-node-setup` — decision 7.
7. `test/extend-action-tests` — the table in 4.5 and the dedupe of the nightly workflow (W8, W9).

## 6. Decisions of the maintainer

| #   | Question                                               | Decision                                                                     |
| --- | ------------------------------------------------------ | ---------------------------------------------------------------------------- |
| 1   | Keep or remove `setup-node`                            | Remove it, the simplest and most robust option (decision 7).                 |
| 2   | Self-contained `action/Makefile` or reuse `.make/*.mk` | Keep reusing `.make/*.mk` (decision 1). Upstream carries the shared changes. |
| 3   | Format `.make/` in consumer repos                      | Yes, one scope rule with no exclusion (decision 8).                          |
| 4   | `tools` input or detection only                        | Detection only, no `tools` input (decision 9).                               |

Open point from these decisions: the upstream shared-Makefile repository must accept the changes in "Where each change lands". If it does not, the fallback is a thin action-owned layer in the root `Makefile` that overrides the shared targets, which keeps the coupling but adds local code.

## 7. What was and was not verified in this review

- Verified: B1, by running `make --file=<repo>/Makefile -n format` from a fresh temporary git repo. It fails on the first `include`.
- Not run: `make lint`, `make format`, and the workflows. This review changes no code. The CI workflows cannot be run locally. The other findings come from reading the files.
- Not verified: that `shfmt -f` skips hidden directories, and the exact release asset names and checksums for shfmt and taplo. Check both during implementation.
