# Security Policy

## Supported Versions

Security fixes are only released for the latest tagged release. Older tags are not patched, so
please point at the latest release before reporting an issue.

## Reporting a Vulnerability

The `format-files-action` team takes security bugs seriously. We appreciate your efforts to
responsibly disclose your findings.

### Where to Report

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report security vulnerabilities privately using
[GitHub Security Advisories](https://github.com/durandtibo/format-files-action/security/advisories/new).

### What to Expect

- We will acknowledge receipt of your report within **5 business days**.
- We will provide an initial assessment (including whether the report is accepted, and an
  estimated timeline for a fix) within **10 business days** of acknowledgment.

### What to Include

Please include the following information in your report:

- Type of issue (e.g., command injection, privilege escalation, secret exposure, etc.)
- Full paths of source file(s) related to the manifestation of the issue
- The location of the affected source code (tag/branch/commit or direct URL)
- Any special workflow configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

This information will help us triage your report more quickly.

### Security Update Policy

- Security updates will be released as soon as possible
- Security updates will be clearly marked in release notes
- We will notify users through GitHub releases and other appropriate channels

## Known Security Considerations

`format-files-action` is a composite GitHub Action that checks out a caller's repo, runs
formatters against it, and, in write mode, opens a pull request with the result. It does not
process untrusted external input on its own, but running it still has some security implications
you should be aware of:

- **It runs formatters against your checked-out working tree.** Only use this action on
  repositories and refs you trust, and pin the action to a full commit SHA (not a mutable tag)
  as recommended in [GitHub's hardening guide](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions).
- **Tokens with write access.** In write mode, the action uses a `GITHUB_TOKEN` or a GitHub App
  installation token (via `github-app-client-id`/`github-app-private-key`) to open a pull request.
  Scope these credentials as narrowly as possible (contents/pull-requests write only) and never
  pass a personal access token with broader permissions than required.
- **Workflow triggers on untrusted PRs.** If you invoke this action from a workflow triggered by
  `pull_request_target` or that otherwise runs with elevated permissions on third-party code,
  make sure you understand the risks of checking out and formatting attacker-controlled content
  before merging its output. Prefer `pull_request` for untrusted forks.
- **Formatter installation.** The action installs formatters on demand (via Homebrew/apt/npm/pipx)
  if they aren't already on the runner. These installs pull from upstream package registries;
  review [action.yml](action.yml) and the [`.make`](.make) directory if you need to audit exactly
  what gets installed and from where.
