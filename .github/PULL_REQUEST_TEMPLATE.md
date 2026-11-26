# Pull Request Summary

## Summary

-

## Scope

- [ ] In scope and out-of-scope are clear.

## Governance Checks

- [ ] I updated documentation impacted by this change.
- [ ] I confirmed no generated/local artifacts are committed (`target/`, coverage outputs, local logs).
- [ ] I updated `CHANGELOG.md` when behavior or public surface changed.
- [ ] I evaluated whether an ADR is required.
- [ ] If required, I linked an ADR in `docs/adr/`.
- [ ] I ran a docs-freshness pass and resolved blockers.
- [ ] I updated `docs/crate-boundaries.md` when crate ownership or dependency direction changed.

## Testing / TDD

- [ ] I added or updated tests for behavior changes.
- [ ] I described the failing test intent that guided implementation.
- [ ] `pwsh scripts/check.ps1` passes.

## Risk and Rollout

- [ ] I documented migration/compatibility implications.
- [ ] I documented rollback/fallback plan if risk is non-trivial.

## Commit Hygiene

- [ ] I grouped commits by concern (code/tests/docs/ci).
- [ ] I used clear commit messages for each commit group.
