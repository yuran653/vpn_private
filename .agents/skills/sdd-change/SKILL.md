---
name: sdd-change
description: The change cycle for this repository - how to classify, propose, get approval for, implement, verify and archive a change, and how to record a reversed approach. Use when a task adds, changes or removes observable behavior, fixes a bug, or refactors across modules.
metadata:
  version: "0.1.0"
---

# Change cycle

Two kinds of files, never mixed:

- **State:** `specs/<capability>/spec.md` says what the capability does now. It changes only in step 7.
- **Change:** `changes/<slug>/` describes one unit of work against that state.

Templates are in `assets/` next to this file.

## 1. Classify the work

| The work is | Path |
|---|---|
| Typo, formatting, comment, mechanical rename | No cycle. Make the edit. |
| **Bug:** code disagrees with an existing acceptance criterion | Fix the code. Add or repair the test for that criterion and update its status in the spec. No change folder, no delta. |
| **Refactor:** no observable behavior changes | No delta. Write `design.md` in a change folder only if it crosses module boundaries. Write a decision record if it replaces an approach (see "Decisions"). |
| **Behavior change:** adds, changes or removes what a user or caller can observe | Full cycle, steps 2 to 8. |
| **Spec gap:** the code does something, or a bug report expects something, that no spec states | A behavior change. The delta writes the requirement down for the first time. |

If you cannot tell which row applies, ask.

## 2. Read

`specs/INDEX.md`, the spec of each capability you will touch, `docs/decisions/INDEX.md`, and the neighboring code and tests. Read `docs/architecture.md` if modules or their dependencies change.

## 3. Propose

Create `changes/<slug>/`, where `<slug>` is a short kebab-case phrase starting with a verb (`add-csv-export`). Fill it from `assets/`:

| File | Content |
|---|---|
| `proposal.md` | Why, what changes as observable behavior, capabilities affected, out of scope, open questions. |
| `specs/<capability>/spec.md` | The delta for each affected capability: ADDED, MODIFIED, REMOVED requirements only. Not a copy of the whole spec. |
| `design.md` | How: modules and files touched, contract and data changes, alternatives rejected, and which test verifies each criterion. |
| `tasks.md` | Ordered tasks of one to three files each, every one with its own check. |

Writing requirements:

- One requirement is one statement, observable from outside: condition, behavior, result. "Improve", "optimize" and "make robust" are not requirements; restate them as something a test can fail.
- No implementation detail in a spec or delta. Class names, functions and libraries belong in `design.md`.
- IDs: requirement `R-<capability>-NN`, criterion `R-<capability>-NN.a`, `.b`, and so on. Take the next free number in that capability's spec. IDs are never reused.
- Every requirement has at least one acceptance criterion written as WHEN / THEN.
- Unknowns are written `[TODO-CLARIFY: <question>]` and asked, not assumed.
- The spec is not rewritten to match existing code. If they disagree, that is a bug or a proposed change, and you say which.

## 4. Approval gate

Do not stop here for approval. Write the change folder, then continue to step 5 in the same task. Stop only if the proposal has an open `[TODO-CLARIFY]` whose answer would change what gets built; ask that one question, once. The owner reviews the finished change after archiving (step 7) and can request changes, which then go through the cycle again.

## 5. Implement

One task at a time, smallest sufficient change. Tick tasks off in `tasks.md`.

**Everything discovered while the change is open stays in this change.** Debugging, rework and a changed approach amend this folder's delta, `design.md` and `tasks.md`. Never open a second change folder or write another spec for the same unit of work. If the observable behavior in the delta has to change, go back to step 4.

Problems outside the change's scope are reported, not fixed.

## 6. Verify

- Run the commands in `AGENTS.md`. A check you invented does not count.
- Each new or modified criterion has a test that fails when the criterion is violated. Name the test after the behavior and cite the criterion ID in its docstring or comment, so searching for the ID finds the test.
- Tests are deterministic: control network, time and randomness.
- Never weaken or delete a test to make it pass. If a test looks wrong, establish whether the spec or the test is wrong, and say so.

## 7. Archive

Do this in the same branch as the code, after verification.

1. Merge each delta into `specs/<capability>/spec.md`:
   - **ADDED:** append the requirement. For a new capability, create the spec from `assets/spec.md` and add its row to `specs/INDEX.md`.
   - **MODIFIED:** replace the whole requirement block with the same ID.
   - **REMOVED:** delete the block.
   - Leave everything the delta does not mention untouched.
2. Set the status and test reference of each affected criterion from what step 6 actually showed:
   - `verified`: the named test fails when the criterion is violated.
   - `untested`: no such test yet. Give the reason.
   - `drift`: the code is known to disagree with the criterion and the fix is pending. Give the reason.
3. Move the folder to `changes/archive/YYYY-MM-DD-<slug>/`.

After archiving, the spec is the only description of current behavior. The archive answers when and why it changed; do not read it to learn what the system does.

## 8. Report

Requirements touched, what changed, how it was verified, what is `untested` or `drift` and why, open `[TODO-CLARIFY]` items, and unrelated problems noticed.

## Decisions

Write a decision record `docs/decisions/ADR-NNNN-<slug>.md` from `assets/adr.md`, and add its row to `docs/decisions/INDEX.md`, when either holds:

- **A real choice:** the design picks between alternatives that a later session could plausibly choose differently.
- **A reversal:** an implemented approach is being replaced. Also add a "Do not" line to the index naming the replaced approach and the reason, and mark any decision it overturns as superseded.

Before proposing a design, check it against the "Do not" list. If the best design contradicts a line there, do not proceed: propose a new decision that supersedes it and wait for approval.

## Drift found along the way

If you find the spec, code and tests disagreeing outside your current change, do not fix it silently and do not edit the spec to match the code. Report it. If it is not fixed now, set the criterion's status to `drift` with a one-line reason.
