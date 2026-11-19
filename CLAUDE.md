# CLAUDE.md

Guidance for coding agents working in this repository.

## Repository purpose

A GitHub composite action (`action.yml`) that formats YAML, Makefile, shell, TOML and Markdown
files by running `make format` against the caller's checkout and, in write mode, opens a pull
request with the changes (via `peter-evans/create-pull-request`). In `check` mode it fails instead
and leaves the working tree untouched. The formatting logic lives in the `Makefile` and the shared
`.make/` directory, which the action runs with `make --file="$ACTION_PATH/Makefile" format`. There
is no separate script: the action's steps are inline in `action.yml`, and it is tested end to end by
the `ci-action.yaml` workflow (local and released). `dev/` holds maintainer helpers
(`check_export.sh`), not part of the action. `review/target_state.md` lists the
properties the action must have (P1 to P12) and the planned changes; check a change against it.

## Environment

- Use the `Makefile`; run `make help` to list targets.
- Do not edit `.make/`: it is a shared directory synced by `bot-sync-shared-makefile.yaml`.
  Change the root `Makefile` instead (it only includes `.make/*.mk` and defines `install-tools`,
  `format` and `lint`).
- Run `make format` and `make lint` before committing. Fix what they report instead of disabling
  rules.
- There is no local test suite. The action is tested by `ci-action.yaml`,
  which cannot be run locally; say so in the PR instead of claiming they pass.

## Git workflow

- One branch and one PR per logical change, branched from an up-to-date `main`. Never commit or
  push to `main`.
- Name branches `<type>/<short-description>` in kebab-case, with type one of: `feat`, `bugfix`,
  `hotfix`, `docs`, `refactor`, `perf`, `test`, `chore`, `ci`.
- Write commit messages and PR titles as a short imperative sentence starting with a verb such as
  `Add`, `Fix`, `Update`, `Remove` or `Improve`. Do not use conventional-commit prefixes like
  `docs:` or `feat:` (the type prefix is only for branch names). The squash-merge appends the PR
  number, so do not add one.
- PR descriptions cover what changed, what was deliberately left alone, and any behaviour change.
- Do not escape special characters such as the backtick (`` ` ``) in PR titles and descriptions
  (no `\``): the escape characters are not rendered well. Write them as plain Markdown.
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
- Only Linux and macOS runners are supported (Windows is not supported and not tested); do not
  introduce Windows-only assumptions or GNU-only/BSD-only tool flags in the Makefile targets.
- Workflows use least-privilege `permissions` and set `timeout-minutes` on jobs.
- Only ship what the action needs at runtime: `action.yml`, `LICENSE`, the root `Makefile` and
  `.make/` are exported, and `.gitattributes` marks everything else `export-ignore`. Never
  `export-ignore` the `Makefile` or `.make/`. When the action starts using a new file, un-ignore it
  there and add it to `EXPECTED_FILES` in `dev/check_export.sh`. Never make the action read tests,
  fixtures or other repo files that are not exported. Check the exported set with `make check-export`
  (`dev/check_export.sh`, run by `ci-export.yaml`), or by hand with
  `git archive --worktree-attributes HEAD | tar t`.

## Makefile rules (`Makefile`, `.make/`)

- Formatting targets (`format-yaml`, `format-makefile`, `format-shell`, `format-toml`,
  `format-markdown`) are what the action runs; linters (`make lint`) are not part of the action.
- Tools are installed on demand by the `install-*` targets; keep that working on Linux and macOS
  and keep the tool table in `README.md` accurate.
- Code must pass `make lint` (yamllint, checkmake, shellcheck, markdownlint, actionlint) and
  `make format`.

## Shell rules (inline `run:` steps, `Makefile`, `.make/`)

- Must stay portable between GNU and BSD tools (`sed`, `date`, `mktemp`, etc.): Linux and macOS
  runners are both supported.
- Quote all variables; fail early with a clear `::error` message that says what failed and why.
- Code must pass `shellcheck` and `shfmt` via `make lint` / `make format`.
- Never rely on `set -e` alone: a caller in an `||` list turns it off. Check the exit status of
  commands that can fail and `exit 1` explicitly.

## Workflow structure (`.github/workflows/`)

Files are prefixed by role:

- `ci.yaml`: entry point for pull requests, pushes to `main`, a nightly schedule and manual runs. It
  holds no steps, only jobs that call the reusable workflows below.
  - `lib-get-test-matrix.yaml`: loads the OS list (Linux and macOS runners) once from
    `durandtibo/workflow-config-action`, with the same keys in every action repository (`os_matrix`,
    `os_macos`, `os_latest`, `python_versions`, `python_versions_standard`) and passes it to the test jobs as
    `test-matrix`. The supported OS list lives in that action, never hardcoded in this repo.
  - `ci-export.yaml`: runs `make check-export`: the files shipped by `git archive` are exactly the
    files the action needs (`uses: ./` hides an `export-ignore` mistake).
  - `ci-format.yaml`: runs the `make lint-*` / `make check-format-shell` targets.
  - `ci-action.yaml`: runs the action from this checkout (`uses: ./`), i.e. the version not
    released yet, on the Linux/macOS matrix. Covers write mode (reformats, `changed=true`,
    idempotent) and check mode (fails and leaves the tree untouched on unformatted input,
    succeeds on formatted input), plus `test-export`, which runs the action from the `git archive`
    output (local only). Jobs are named `test` (default usage), `test-<usage>` and
    `test-<edge case>`. Every negative check-mode job first runs a positive control on the same
    runner. Badly formatted fixtures are generated at runtime so the format bot never "fixes" them.
- `nightly.yaml`: nightly entry point that calls `ci-action.yaml` with `use-released: true`, the
  same tests against the last released tag. It is not part of `ci.yaml`.
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
- When the stable tag tested in `ci-action.yaml` (the released steps) changes, update the comment
  at the top of that file too.

## Tests

- Test behaviour through the `ci-action.yaml` workflow: one behaviour per
  job or step, covering success, failure, and edge cases (already formatted input, check mode,
  no changes, each file type).
- Every bug fix needs a regression case that fails without the fix.
- If a check fails for a real reason, report it rather than weakening the test.

## Testing strategy

The strategy is the same for all the action repositories of `durandtibo`. This repository has no
script of its own, so the action is tested end to end and there is no code level (bats, pytest).

Two levels:

1. **Local action**: the action from this checkout (`uses: ./`) in a real workflow
   (`ci-action.yaml`, called by `ci.yaml`).
2. **Released action**: the latest stable release (`uses: durandtibo/format-files-action@<sha>`),
   run nightly with the same cases as level 1 (`ci-action.yaml` with `use-released: true`,
   called by `nightly.yaml`). Never run it on pull requests.

Rules:

- Never write an OS in a workflow: read the list from `durandtibo/workflow-config-action` through
  `lib-get-test-matrix.yaml`. The same matrix runs on pull requests, pushes and the schedule.
- General behaviour (write mode, check mode, idempotency) runs on the full OS matrix
  (`os_matrix`); edge cases (one input, one unusual file) run on `os_latest` only. Local and
  released runs share one file: every action step exists twice (`if: !inputs.use-released` and
  `if: inputs.use-released`). A job the released version cannot pass yet gets
  `if: ${{ !inputs.use-released }}` and a comment saying why. `ci.yaml` calls `ci-action.yaml`
  with `false`, `nightly.yaml` with `true`. A verify step reads the outcome of whichever step ran
  (`inputs.use-released && steps.format-released.outcome || steps.format.outcome`).
- The action tests use the real action, real tools and the real `git`, never a fake. Fixtures are
  throwaway files created at runtime under the runner, so the format bot never "fixes" them.
- Failure paths use `continue-on-error: true`, an `id`, and a step that asserts `steps.<id>.outcome`.
  Assert exact outputs (`changed`) and file contents, not log messages. A negative test needs a
  positive run on the same runner before it, so it cannot pass for the wrong reason.
- Tests have no side effects outside the runner: check mode never opens a pull request, and tests
  never push or open one. If something cannot be tested in CI (the pull request creation), write
  down which check covers it.
- Set `timeout-minutes` and `fail-fast: false` on matrix jobs.
- Test a behaviour at the cheapest level that can show it. The action tests check the contract
  and the wiring: inputs reach the Makefile and `create-pull-request`, outputs are set, check mode
  fails. Do not re-test a formatter's own behaviour there.
- Every input that changes what the action does (`check`, `create-pull-request`) has a case that
  proves it reached the action. Inputs only forwarded to `peter-evans/create-pull-request`
  (`token`, `branch`, `title`, ...) cannot be tested in CI without side effects: say so in the PR.
- Check what is shipped: the exported set (`make check-export`) must contain every file the action
  needs, because `uses: ./` runs the whole checkout and hides a missing file.
- Keep the README inputs, outputs and tool table in step with `action.yml`.

## Reporting

- State which checks ran (`make lint`, `make format`) and which did not (the workflow tests).
- Note that CI was not awaited.
- Report failures that already exist on `main` rather than hiding them.
