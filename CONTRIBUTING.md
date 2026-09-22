# Contributing to `format-files-action`

We want to make contributing to this project as easy and transparent as possible.

## Overview

We welcome contributions from anyone, even if you are new to open source.

- If you are planning to contribute back bug-fixes, please do so without any further discussion.
- If you plan to contribute new features (e.g. a new formatter, a new input) or changes to the
  core behavior, please first open an issue and discuss the feature with us.

Once you implement and test your feature or bug-fix, please submit a Pull Request.

## Development Setup

### Prerequisites

- Git
- `make`
- The formatters used by the action (Prettier, mbake, shfmt, markdownlint) if you want to run
  `format`/`lint` locally instead of relying on CI — see [action.yml](action.yml) and
  [`.make`](.make) for how each one is installed

### Setting Up Your Development Environment

1. **Fork and clone the repository:**

   ```shell
   git clone https://github.com/YOUR-USERNAME/format-files-action.git
   cd format-files-action
   ```

2. **List the available Makefile targets:**

   ```shell
   make help
   ```

## Development Workflow

### Formatting and Linting

**Format all files:**

```shell
make format
```

**Lint all files:**

```shell
make lint
```

Both targets run the per-file-type targets defined in [`.make`](.make) (YAML, Makefile, shell,
Markdown).

### Testing Your Changes

This is a composite action, so the most reliable way to validate a change is to exercise it in a
real workflow:

1. Push your branch and point a test workflow's `uses:` at your fork/branch (or run it via
   `workflow_dispatch` in a scratch repo).
2. Exercise both **check mode** (`check: true`) and **write mode** (default) if your change
   touches either path.
3. Confirm the `changed` output and, in write mode, the opened pull request look as expected.

If you change the CI/release workflows themselves, validate them with
[`actionlint`](https://github.com/rhysd/actionlint) and by watching a run on your fork.

## Pull Requests

We actively welcome your pull requests.

### Pull Request Process

1. **Fork the repo and create your branch from `main`:**

   ```shell
   git checkout -b feature/my-new-feature
   ```

2. **Make your changes:**
   - Update `action.yml` and/or the relevant file(s) under `.make/`
   - Update `README.md` if you change inputs, outputs, or behavior
   - Format and lint your changes (`make format`, `make lint`)

3. **Commit your changes:**

   ```shell
   git add .
   git commit -m "Add feature: description of feature"
   ```

4. **Push to your fork:**

   ```shell
   git push origin feature/my-new-feature
   ```

5. **Submit a Pull Request** through GitHub

### Pull Request Guidelines

- **Write clear commit messages:** Follow the format "Add/Fix/Update: description"
- **Keep changes focused:** One feature or bug fix per PR
- **Pin any new GitHub Actions to a commit SHA:** see existing steps in `action.yml` and the
  workflows under `.github/workflows` for the convention
- **Update documentation:** If you change inputs, outputs, or behavior, update `README.md`
- **Follow code style:** Run `make format` and `make lint` before committing
- **Link related issues:** Reference any related issues in your PR description

### What to Include in Your PR

- **Description:** Clear explanation of what you changed and why
- **Validation:** How you tested the change (e.g. a link to a workflow run on your fork)
- **Documentation:** Updates to `README.md` if you changed behavior

## Issues

We use GitHub issues to track public bugs or feature requests.

### Reporting Bugs

When reporting bugs, please include:

1. **Clear title:** Brief description of the issue
2. **Environment information:**
   - Action version/ref used (tag or commit SHA)
   - Runner OS (e.g. `ubuntu-latest`, `macos-latest`)
   - Relevant `action.yml` inputs you passed
3. **Steps to reproduce:** Minimal workflow YAML that triggers the issue
4. **Expected behavior:** What you expected to happen
5. **Actual behavior:** What actually happened
6. **Logs:** Relevant excerpt from the workflow run logs

**Example bug report:**

````markdown
## Bug: `check: true` doesn't revert Markdown changes

**Environment:**

- Action ref: `v1.2.0`
- Runner: `ubuntu-latest`

**Workflow to reproduce:**

```yaml
- uses: actions/checkout@v4
- uses: durandtibo/format-files-action@v1.2.0
  with:
    check: true
```

**Expected:** Unformatted Markdown files are reverted and the step fails.

**Actual:** The step fails but the Markdown changes remain in the working tree.

**Logs:**

```text
...
```
````

### Requesting Features

For feature requests, please include:

1. **Clear title:** Brief description of the feature
2. **Motivation:** Why this feature would be useful
3. **Proposed solution:** How you envision it working (e.g. new input/output)
4. **Alternatives considered:** Other approaches you've thought about
5. **Example:** A sample workflow snippet showing how it would be used

## Coding Standards

### Style

- Format YAML, Makefiles, shell scripts, and Markdown with `make format` before committing
  (the same formatters this action runs on caller repos: Prettier, mbake, shfmt, markdownlint)
- Pin third-party GitHub Actions to a full commit SHA, not a mutable tag
- Keep `action.yml` inputs/outputs documented in `README.md`

## Commit Message Guidelines

Follow these conventions:

- **Add:** New feature or functionality
- **Fix:** Bug fix
- **Update:** Changes to existing functionality
- **Remove:** Removal of code or features
- **Refactor:** Changes that don't fix bugs or add features
- **Docs:** Documentation changes
- **Build:** Changes to workflows, `Makefile`, or `.make` targets

**Examples:**

- `Add: Support for formatting JSON files`
- `Fix: Handle repos with no changes in write mode`
- `Update: Bump pinned action SHAs`

## Community

### Code of Conduct

Please note that this project is released with a [Code of Conduct](CODE_OF_CONDUCT.md).
By participating in this project you agree to abide by its terms.

### Getting Help

- **Documentation:** [README.md](README.md)
- **Issues:** https://github.com/durandtibo/format-files-action/issues

## License

By contributing to `format-files-action`, you agree that your contributions will be licensed
under the BSD 3-Clause License as specified in the [LICENSE](LICENSE) file in the root directory
of this source tree.

## Questions?

If you have questions about contributing, feel free to open an issue with the "question" label.

Thank you for contributing to `format-files-action`! 🎉
