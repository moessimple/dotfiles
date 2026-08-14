---
paths:
  - "**/*.{php,js,jsx,ts,tsx,vue,sh,bash,zsh,py,rb,go,java,kt,swift,c,cpp,h,hpp,cs,rs}"
  - "**/.{zshrc,bashrc,bash_profile,zprofile,profile,aliases,exports,functions,paths}"
---

## Code comments

Write no comment unless it earns its place. Surrounding comment density is never the target, and a comment never
compensates for an unclear name or complicated code, fix those first. Weigh the bar by reuse scope: a library, a
shared utility, code many different callers or readers will depend on over time, earns a comment more readily
than code used in exactly one place. Only two kinds earn their place:

- **Contract**, at a declaration: what a non-obvious function, class, or module is for and how to use it
  correctly. Skip it where name and signature already say it.
- **Constraint**, inside an implementation: a business rule, invariant, external limitation, ordering, locking,
  concurrency or idempotency requirement, or deliberate trade-off that applies to the code as it now stands,
  cannot be carried by naming, types, or structure, and whose absence would let the next maintainer make a
  plausible wrong change.

Never write a comment that:

- narrates statements, calls, conditions, or return values
- describes code that is not there: hypothetical mistakes, rejected alternatives, future plans (a plain
  `TODO:`/`FIXME:` marker for real, current work is not this, it stays allowed)
- records the task, ticket, PR, review, or debugging session, or narrates how the implementation came about
  (a one-line example of a real failure mode a Constraint prevents is not this, it stays allowed)
- explains the change to me or to a reviewer instead of to whoever reads the file next year
- repeats a name, a type, a test, or the repository documentation (an exception: a one- to three-line
  restatement placed exactly where code branches on that documented behavior is not this, it stays allowed,
  since it saves a context switch a reader would otherwise have to make)
- sits on code the current change did not otherwise touch

**Write it so a human can actually follow it.** Lead with the plain, concrete account of what the code does or
what condition it handles, the way you would say it out loud, then add the technical why next to it, never
instead of it. A reader should not need to already know the mechanism to parse the sentence. One thought per
sentence. No hedge verb (handles, manages, processes) standing in for a real description of what happens.

Never how the code was arrived at, only the constraint and its consequence. Before finishing, reread every
comment you added and delete the ones that are neither a contract nor a constraint.

One exception to all of the above: a file that originates from a third-party template or generator rather than
being authored by you (a scaffolded config, a framework-generated file) keeps its own original comments exactly
as they came, even where they would fail every bar above. Trimming another tool's template is not your call.
