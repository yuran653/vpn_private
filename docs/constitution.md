# Constitution

Rules Personal VPS located in Thailand does not trade off. Each rule names what enforces it.

- **Status `enforced`:** a check fails when the rule is broken. Breaking it is a failed build, not a judgment call.
- **Status `discipline-only`:** nothing fails automatically. If a task seems to require breaking the rule, stop and ask; never break it silently.
- Rules are added, changed or removed only with explicit human approval, recorded as a decision in `docs/decisions/`.
- An approved exception is recorded in the "Exceptions" section below, with the date and who approved it.

## Rules

| ID | Rule | Enforced by | Status |
|---|---|---|---|
| C-01 | No secrets (keys, tokens, passwords, certificates, `.env` contents) in the repository or its history. | [TODO-CLARIFY: secret scanner] | discipline-only |
| C-02 | `main` changes only through a pull request whose checks pass. | [TODO-CLARIFY: branch protection] | discipline-only |
| C-03 | A change to observable behavior has a spec delta, and every new acceptance criterion has a test or is marked `untested` with a reason. | Review of the change folder | discipline-only |
| C-04 | Dependencies between modules follow `docs/architecture.md`. | [TODO-CLARIFY: dependency-boundary check] | discipline-only |
| C-05 | When an implemented approach is replaced, the reason is recorded as a decision with a "Do not" line in `docs/decisions/INDEX.md`. | Review of the change folder | discipline-only |
| C-06 | Tests are not weakened or deleted to make them pass. A test changes only when the spec it verifies changed. | Review | discipline-only |

Add project-specific rules below C-06. IDs are never reused.

## Exceptions

None.
