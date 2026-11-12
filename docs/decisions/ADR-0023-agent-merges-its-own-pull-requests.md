# ADR-0023: The agent opens, pushes and merges its own pull requests

- Status: accepted
- Date: 2026-11-12
- Supersedes: none (rewords rule C-02 of `docs/constitution.md`)
- Change: none

## Context

Rule C-02 said that `main` changes only through a pull request "whose checks pass". No checks exist: the commands in `AGENTS.md` are undefined and there is no branch protection. Read strictly, nothing could be merged; read loosely, the condition meant nothing. Since 2026-11-10 `AGENTS.md` has said that the agent merges its own pull requests without a separate review. The owner confirmed that as the rule on 2026-11-12: pull request, push and merge to `main` are automatic.

## Decision

C-02 reads: `main` changes only through a pull request. The agent opens it, pushes it and merges it itself, without a separate review. When checks exist, they must pass before the merge.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Keep "whose checks pass" as it was | It can be read as blocking every merge or as meaning nothing. |
| Commit straight to `main` | A pull request is the record of what changed and why, and the place where a check will run once one exists. |
| Wait for the owner's review of each pull request | The owner asked for tasks to be finished end to end. |

## Consequences

- Nothing stands between a mistake and `main` except the agent's own checks and what it reports. The owner reviews after the merge.
- When a lint, test or secret-scan command is defined, it becomes a condition of the merge without another decision.
- The rule stays `discipline-only` until branch protection exists.

## Do not

- Do not commit directly to `main`: every change arrives through a pull request, so it has a record. (ADR-0023)
