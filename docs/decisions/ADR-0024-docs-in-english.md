# ADR-0024: Documentation and specifications are written in English

- Status: accepted
- Date: 2026-11-13
- Supersedes: none
- Change: none

## Context

The repository's documentation, specifications and decision records have been written in English from the start, but the rule was never written down. An agent working from the repository alone could not discover it. The owner stated it explicitly on 2026-11-13: English is a strict condition for all documentation and specifications.

## Decision

All written content of the repository is in English: `AGENTS.md`, `README.md`, `docs/` (including decision records), `specs/` and `changes/`. Rule C-07 of `docs/constitution.md` records this.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Leave the rule unwritten | It cannot be discovered from the repository, so any new contributor or agent can silently break it. |
| Allow a second language alongside English | Two language versions drift apart; one language keeps a single source of truth. |

## Consequences

- Documentation or a specification written in another language violates C-07 and is rewritten in English.
- The rule covers repository content, not conversation: chat with the owner stays in the owner's language.
- Commit messages and pull request texts follow the same convention, so that the project history is readable by the same audience as its documents.

## Do not

- Do not commit documentation, specifications or decision records in a language other than English: English is the single language of the repository's written record. (ADR-0024)
