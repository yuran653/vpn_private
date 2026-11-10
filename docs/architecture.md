# Architecture

How Personal VPS located in Thailand is divided and which parts may depend on which. Read this before adding a module or a dependency between modules.

## Modules

| Module | Path | Responsibility | May depend on |
|---|---|---|---|
| [TODO-CLARIFY: initial modules] | | | |

## Dependency rules

- A module depends only on the modules listed in its "May depend on" column. Anything else is a violation, including a transitive shortcut.
- Dependencies point one way. No cycles.
- External resources (network, filesystem, clock, randomness, database, model) are passed in from the outside, not created inside core logic.
- Entry points (UI, CLI, API) call the core and display results. Logic lives in the core.

## Enforcement

[TODO-CLARIFY: dependency-boundary check and the command that runs it]

Until a check exists, these rules are enforced by review only.

## Changing this file

Adding a module, or changing a "May depend on" entry, is a design decision: record it in `docs/decisions/` in the same change.
