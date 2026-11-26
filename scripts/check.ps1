# The one NeuroHID check. CI runs exactly this; run it locally before you push.
#
#   pwsh scripts/check.ps1              # everything except the Rust coverage gate
#   pwsh scripts/check.ps1 -Coverage    # also the Rust line-coverage gate (CI does this)
#   pwsh scripts/check.ps1 -SkipPython  # Rust only
#
# Needs: Rust stable with clippy and rustfmt, cargo-nextest, cargo-deny, uv,
# and cargo-llvm-cov for -Coverage. On Linux, liblsl and the keyring packages
# (see .github/scripts/install-liblsl-linux.sh and ci.yml).

param(
    [switch]$Coverage,
    [switch]$SkipPython
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

$PythonCoverageMin = 50
$RustCoverageMin = 32

function Step {
    param([string]$Name, [scriptblock]$Run)
    Write-Host "==> $Name"
    & $Run
    if ($LASTEXITCODE -ne 0) { throw "check failed: $Name" }
}

# Tests that touch the keyring need a session bus on Linux.
$bus = @()
if ($IsLinux -and -not $env:DBUS_SESSION_BUS_ADDRESS -and (Get-Command dbus-run-session -ErrorAction SilentlyContinue)) {
    $bus = @('dbus-run-session', '--')
}

Step 'fmt' { cargo fmt --check }
Step 'clippy (unsafe blocks must be documented)' {
    cargo clippy --workspace -- -A missing_docs -A unsafe_code `
        -D clippy::undocumented_unsafe_blocks -D clippy::missing_safety_doc
}
Step 'docs' {
    $env:RUSTDOCFLAGS = '-D warnings -A missing_docs'
    try { cargo doc --workspace --no-deps } finally { Remove-Item Env:RUSTDOCFLAGS }
}
Step 'framework boundary' { pwsh -File ./.github/scripts/check-framework-boundary.ps1 }
Step 'protocol doc present' {
    if (-not (Test-Path docs/protocol-and-api.md)) { throw 'docs/protocol-and-api.md is missing' }
}
Step 'dependencies (cargo-deny)' { cargo deny check }

if ($Coverage) {
    Step "tests + Rust coverage >= $RustCoverageMin%" {
        New-Item -ItemType Directory -Force target/llvm-cov | Out-Null
        if ($bus) { & $bus[0] $bus[1] cargo llvm-cov nextest --workspace --lcov --output-path target/llvm-cov/lcov.info --fail-under-lines $RustCoverageMin }
        else { cargo llvm-cov nextest --workspace --lcov --output-path target/llvm-cov/lcov.info --fail-under-lines $RustCoverageMin }
    }
}
else {
    Step 'tests' {
        if ($bus) { & $bus[0] $bus[1] cargo nextest run --workspace }
        else { cargo nextest run --workspace }
    }
}

if (-not $SkipPython) {
    Step 'python deps (builds the Rust extension)' { uv sync --directory python --extra dev }
    Step 'ruff' { uv run --project python ruff check python/src }
    Step 'black' { uv run --project python black --check python/src }
    Step 'mypy' { uv run --project python mypy python/src }
    Step "pytest + coverage >= $PythonCoverageMin%" {
        uv run --project python pytest python/tests -q --cov=neurohid_ml --cov-branch `
            --cov-report=term-missing --cov-fail-under=$PythonCoverageMin
    }
}

Write-Host 'check passed'
