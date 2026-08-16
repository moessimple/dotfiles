---
paths:
  - "**/*.{php,js,jsx,ts,tsx,vue,sh,bash,zsh,py,rb,go,java,kt,swift,c,cpp,h,hpp,cs,rs}"
  - "**/.{zshrc,bashrc,bash_profile,zprofile,profile,aliases,exports,functions,paths}"
---

## Code comments

Write no comment unless it earns its place. Surrounding comment density is never the target. A comment never
compensates for an unclear name or unnecessarily complicated code. When improving the code is within the scope
of the current task, prefer making the code clearer instead of explaining it with a comment. Broader reuse raises
the importance of preserving a non-obvious contract, but never lowers the bar for comments that merely restate
clear code.

Comments or documentation required or interpreted by the language, framework, static analysis, linting,
code generation, or other tooling are outside the explanatory-comment rules below. Preserve or add them only
when the project requires them. Do not add suppression directives merely to make tooling pass; prefer fixing the
underlying issue when that is within the scope of the current task, and keep necessary suppressions as narrow as
possible.

For human-facing explanatory comments, only two kinds earn their place:

- **Contract**, at a declaration: what a non-obvious function, class, or module is for and how to use it
  correctly. Skip it where name and signature already say it, unless declaration documentation is required by
  the language, project, public API, or documentation tooling.

- **Constraint**, inside an implementation: a business rule, invariant, external limitation, compatibility or
  algorithmic requirement, ordering, locking, concurrency or idempotency requirement, or deliberate trade-off
  that applies to the code as it now stands, is not clear enough from naming, types, or structure, and whose
  absence would let the next maintainer make a plausible wrong change.

Never write a comment that:

- narrates statements, calls, conditions, or return values
- describes code that is not there: hypothetical mistakes, rejected alternatives, future plans (a plain
  `TODO:`/`FIXME:` marker for real, current work is not this, it stays allowed)
- records the task, ticket, PR, review, or debugging session, or narrates how the implementation came about
  (a one-line example of a real failure mode a Constraint prevents is not this, it stays allowed)
- explains the change to me or to a reviewer instead of to whoever reads the file next year
- repeats a name, a type, a test, or the repository documentation unless a short local statement is necessary
  to understand a non-obvious Contract or Constraint at that exact location
- adds drive-by commentary to code unrelated to the current task or change

**Write comments for the missing knowledge, not for the visible mechanics.** State the concrete, non-obvious
contract or constraint first, in plain language a maintainer can understand without mentally executing the code.
Then state the reason, consequence, or failure mode when that information is necessary to understand why the
contract or constraint matters.

Be specific and direct. Prefer concrete nouns, conditions, and consequences over vague descriptions. Keep one
thought per sentence and keep the comment no longer than the knowledge it needs to preserve. Do not use vague
verbs such as `handles`, `manages`, or `processes` as substitutes for saying what actually matters.

Never explain how the code was arrived at, only the contract or constraint and its consequence. Before finishing,
reread every explanatory comment you added and delete the ones that are neither a contract nor a constraint.

Do not clean up or rewrite comments that originate from a third-party template or generator unless the current
task, project convention, or regeneration itself requires it.
