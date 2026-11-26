# Development Guide

This guide is the canonical reference for local development setup, build/test workflows, and
automation-oriented quality gates.

## Prerequisites

- Rust `1.85+`
- Python `3.12+`
- `uv` for Python environment and command execution
- PowerShell (`pwsh`) for repository automation scripts under `.github/scripts/`

If you are working with LSL-backed device paths, install platform LSL tooling and note that
workspace builds pin `lsl-sys` via `[patch.crates-io]` to a shared git source for reproducible
cross-app behavior.

## Local Setup

From repository root:

```bash
cargo build --workspace
uv sync --directory python
```

## Build Commands

```bash
# Full workspace (debug)
cargo build --workspace

# Full workspace (release)
cargo build --release

# Build a single crate
cargo build -p neurohid-core

# Example no-LSL build for device crate
cargo build -p neurohid-device --no-default-features
```

## Common Local Run Commands

```bash
# GUI hub
cargo run -p neuroide

# Headless service
cargo run -p neurohid-service

# Validation harness
cargo run -p neurohid-validate -- --help

# Python ML bridge
uv run --directory python neurohid-ml bridge
```

## Validation and Testing

For definitions of **unit vs integration vs E2E** and how to avoid flakiness (isolation policy, condition-based waits, retries), see [Test tiers and isolation](testing.md).

### Rust

```bash
cargo test --workspace
cargo clippy --workspace -- -D warnings
cargo fmt --check
```

For native UI and lab realism testing guidance, including `egui_kittest`
semantic checks and opt-in LSL simulator / hardware-in-the-loop commands, see
[Testing: Tiers, Isolation, and Flakiness](testing.md).

### Python

```bash
uv run --project python pytest python/tests -q
uv run --project python ruff check python/src python/tests
uv run --project python black --check python/src python/tests
uv run --project python mypy python/src
```

### Retries and flakiness policy

- Retries are used only for identified flaky tests (e.g. `nextest.toml` and optional `pytest-rerunfailures` where configured); broad reruns are avoided so flakiness is fixed at root cause.
- CI passing means safe-to-merge for the scope exercised; flakiness is not masked by broad retries.
- See the test tiers doc (when available) for isolation and flakiness-avoidance guidance.

## The Check

One script runs every gate, locally and in CI:

```bash
pwsh scripts/check.ps1              # everything except the Rust coverage gate
pwsh scripts/check.ps1 -Coverage    # also the Rust coverage gate, as CI runs it
pwsh scripts/check.ps1 -SkipPython  # Rust only
```

It runs fmt, clippy (undocumented `unsafe` is an error), rustdoc with warnings denied, the
framework boundary check, `cargo deny check` (see `deny.toml`), the full nextest suite, and the
Python ruff, black, mypy and pytest gates. CI runs it on `ubuntu-24.04` and runs the test suite
alone on Windows and macOS.

## CI Runner Policy

- Private phase uses self-hosted GitHub Actions runners with dedicated labels:
  - Linux: `self-hosted`, `linux`, `neurohid-ci`
  - Windows: `self-hosted`, `windows`, `neurohid-ci`
  - macOS: `self-hosted`, `macos`, `neurohid-ci`
- The Linux `Check` job is pinned to `ubuntu-24.04` because liblsl publishes `.deb` packages
  for jammy and noble only.
- `ci.yml` controls optional macOS execution with repository variable `ENABLE_MACOS`.
- If macOS support is dropped temporarily, set `ENABLE_MACOS=false` in repo variables and align
  required checks in branch protection.
- At release/public transition, change workflow runner mappings to GitHub-hosted labels
  (`ubuntu-latest`, `windows-latest`, `macos-latest`).

### Self-hosted runner setup

To register self-hosted runners for NeuroHID CI:

1. **Repository:** GitHub → Settings → Actions → Runners → New self-hosted runner.
2. **OS:** Follow the displayed commands for the runner OS (Linux, Windows, or macOS).
3. **Labels:** Use the labels above so workflows can select them:
   - Linux: `self-hosted`, `linux`, `neurohid-ci`
   - Windows: `self-hosted`, `windows`, `neurohid-ci`
   - macOS: `self-hosted`, `macos`, `neurohid-ci`
4. **Linux:** Install build deps (e.g. `liblsl-dev`) and Rust/Python/uv so that `cargo build
   --workspace`, `cargo test --workspace`, and `uv sync --directory python` succeed.
5. **Windows:** Install Visual Studio Build Tools (or MSVC) and LSL if needed; ensure PowerShell
   and Git are available.
6. **macOS:** Install Xcode Command Line Tools and LSL; ensure `cargo` and `uv` are on the PATH.

After registration, jobs in `.github/workflows/ci.yml` that use the corresponding `runs-on` labels
will run on these runners. See [GitHub: Adding self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners).

## Coverage Gates in CI

- Python line coverage must stay at or above `50`% and Rust at or above `32`%.
- **Source of truth:** `$PythonCoverageMin` and `$RustCoverageMin` at the top of
  `scripts/check.ps1`.

## Branch Protection Required Checks

Require these status checks on `main`:

- `Check`
- `Test (Windows)`
- `Test (macOS)` (drop it if you set `ENABLE_MACOS=false`)

PR-only updates to `main` are enforced by the repository ruleset, not by a workflow.

```bash
gh api --method PATCH repos/{owner}/{repo}/branches/main/protection/required_status_checks \
  -H "Accept: application/vnd.github+json" \
  -F strict=false \
  -f "contexts[]=Check" \
  -f "contexts[]=Test (Windows)" \
  -f "contexts[]=Test (macOS)"
```
