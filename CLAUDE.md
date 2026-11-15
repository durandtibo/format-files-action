# CLAUDE.md

Guidance for coding agents working in this repository.

## Repository purpose

A GitHub composite action (`action.yml`) that formats YAML, Makefile, shell, TOML and Markdown
files by running `make format` against the caller's checkout and, in write mode, opens a pull
request with the changes (via `peter-evans/create-pull-request`). In `check` mode it fails instead
and leaves the working tree untouched. The formatting logic lives in the `Makefile` and the shared
`.make/` directory, which the action runs with `make --file="$ACTION_PATH/Makefile" format`. There
is no separate script: the action's steps are inline in `action.yml`, and it is tested end to end by
the `ci-action.yaml` and `nightly-test-released.yaml` workflows.

## Environment

- Use the `Makefile`; run `make help` to list targets.
- Do not edit `.make/`: it is a shared directory synced by `bot-sync-shared-makefile.yaml`.
  Change the root `Makefile` instead (it only includes `.make/*.mk` and defines `install-tools`,
  `format` and `lint`).
- Run `make format` and `make lint` before committing. Fix what they report instead of disabling
  rules.
- There is no local test suite. The action is tested by `ci-action.yaml` and `nightly-test-released.yaml`,
  which cannot be run locally; say so in the PR instead of claiming they pass.

## Git workflow

- One branch and one PR per logical change, branched from an up-to-date `main`. Never commit or
  push to `main`.
- Name branches `<type>/<short-description>` in kebab-case, with type one of: `feat`, `bugfix`,
  `hotfix`, `docs`, `refactor`, `perf`, `test`, `chore`, `ci`.
- Write commit messages and PR titles as a short imperative sentence starting with a verb such as
  `Add`, `Fix`, `Update`, `Remove` or `Improve` (e.g. `Add CLAUDE.md`, `Update readme`). Do not use
  conventional-commit prefixes like `docs:` or `feat:` (the type prefix is only for branch names).
  The squash-merge appends the PR number, so do not add one.
- PR descriptions cover what changed, what was deliberately left alone, and any behaviour change.
- On conflicts with `main`, merge `origin/main` into the branch; do not rebase and force-push.
- Update `README.md` when inputs, outputs, behaviour, or workflows change.
- Releases are immutable exact version tags (`v0.0.2`, ...). Do not create or move floating tags
  (`v0`, `latest`) and do not document them as an option.

## Action rules (`action.yml`)

- Keep input and output names, defaults, and descriptions consistent with `README.md`. Renaming or
  removing an input or output is a breaking change and must be flagged.
- Pass inputs to scripts through `env:` (e.g. `CHECK`, `ACTION_PATH`), never by interpolating them
  in `run:`.
- Every `run:` step sets `shell: bash`.
- Pin third-party actions (in `action.yml` and in workflows) to commit SHAs with a
  `# ratchet:<owner>/<repo>@<tag>` comment, never to tags or branches.
- Keep `check` semantics: in check mode, revert changes with `git checkout -- .`, fail the step,
  and never open a pull request.
- Only Linux and macOS runners are supported; do not introduce Windows-only assumptions or
  GNU-only/BSD-only tool flags in the Makefile targets.
- Workflows use least-privilege `permissions` and set `timeout-minutes` on jobs.

## Makefile rules (`Makefile`, `.make/`)

- Formatting targets (`format-yaml`, `format-makefile`, `format-shell`, `format-toml`,
  `format-markdown`) are what the action runs; linters (`make lint`) are not part of the action.
- Tools are installed on demand by the `install-*` targets; keep that working on Linux and macOS
  and keep the tool table in `README.md` accurate.
- Code must pass `make lint` (yamllint, checkmake, shellcheck, markdownlint, actionlint) and
  `make format`.

## Workflow structure (`.github/workflows/`)

Files are prefixed by role:

- `ci.yaml`: entry point for pull requests, pushes to `main`, a nightly schedule and manual runs. It
  holds no steps, only jobs that call the reusable workflows below.
  - `lib-get-test-matrix.yaml`: loads the OS list (Linux and macOS runners) once from
    `durandtibo/workflow-config-action` and passes it to the test jobs as `test-matrix`. The
    supported OS list lives in that action, never hardcoded in this repo.
  - `ci-format.yaml`: runs the `make lint-*` / `make check-format-shell` targets.
  - `ci-action.yaml`: runs the action from this checkout (`uses: ./`), i.e. the version not
    released yet, on the Linux/macOS matrix. Covers write mode (reformats, `changed=true`,
    idempotent) and check mode (fails and leaves the tree untouched on unformatted input,
    succeeds on formatted input). Badly formatted fixtures are generated at runtime so the format
    bot never "fixes" them.
- `nightly.yaml`: nightly entry point that calls `nightly-test-released.yaml`, the same tests
  against the last released tag.
- `ci-verify-workflows.yaml`: lints the workflow files themselves. It has its own triggers and is
  not called from `ci.yaml`.
- `security-*.yaml`: dependency review on pull requests and OSSF Scorecard.
- `bot-*.yaml`: scheduled automation that opens PRs (`bot-format-files` formats this repo with the
  last released action, `bot-pin-action` pins actions with ratchet, `bot-sync-shared-makefile` syncs
  `.make/`, `bot-cancel-stale-queued-runs` cancels stale queued runs).

Conventions:

- Set `permissions` on every job (including jobs that call a reusable workflow). Every workflow
  has `permissions: {}` at the workflow level (it grants nothing), never a grant.
- Reusable checks are `workflow_call` workflows that also have `workflow_dispatch`, so they can be
  run alone. Add a new check as a new workflow plus a job in `ci.yaml`.
- Put `make` targets in the steps rather than duplicating commands, so local runs and CI match.
- Start each file with a comment saying what it does, and update it when the behaviour changes.
- When the stable tag tested in `nightly-test-released.yaml` changes, update the comment at the top of that
  file too.

## Tests

- Test behaviour through the `ci-action.yaml` / `nightly-test-released.yaml` workflows: one behaviour per
  job or step, covering success, failure, and edge cases (already formatted input, check mode,
  no changes, each file type).
- Every bug fix needs a regression case that fails without the fix.
- If a check fails for a real reason, report it rather than weakening the test.

## Reporting

- State which checks ran (`make lint`, `make format`) and which did not (the workflow tests).
- Note that CI was not awaited.
- Report failures that already exist on `main` rather than hiding them.
