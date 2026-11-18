---
paths:
  - ".github/workflows/**"
  - ".github/actions/**"
  - "**/action.{yml,yaml}"
---

## GitHub Actions security

A workflow runs with a token and often with secrets, on input that strangers can control through forks, pull
requests, branch names, and issue text, and it executes code from every action it references. These rules are the
floor for every workflow and composite action, whatever else the project decides.

1. Declare `permissions:` at the top level with the least the workflow needs, usually `contents: read`. Once any
   permission is declared, every undeclared one is `none`. Grant more on the job that needs it, never workflow-wide,
   and never `write-all`.

2. Never interpolate an expression that can carry attacker-controlled text (anything from `github.event`,
   `github.head_ref`, `inputs`, or step outputs derived from them) directly into `run:` or into the `script:` of
   `actions/github-script`. The expression is expanded into the script source before it runs. Pass the value
   through `env:` and read it as a quoted shell variable (`"$PR_TITLE"`).

3. Never build, test, or otherwise execute pull request code in a workflow triggered by `pull_request_target` or by
   a `workflow_run` that follows a pull request. Those run with a privileged token, the base repository's secrets,
   and its cache. Use `pull_request` for anything that runs contributed code, treat artifacts produced from it as
   untrusted data, and never set `allow-unsafe-pr-checkout` on `actions/checkout` to get around this.

4. Lock every action to an immutable commit, because a tag can be moved to malicious code by anyone who gains write
   access to the action's repository.
   - When the repository has `.github/workflows/actions.lock`, keep it in sync with `gh actions-lock` and never edit it
     by hand. It records the commit of every action, transitive ones included, and rejects commits that exist only in
     a fork.
   - Without a lockfile, pin each action you add or change to a full commit SHA with the version in a trailing
     comment (`actions/checkout@<sha> # v7.0.1`). Take the SHA from the action's own repository, from a tag or branch
     there, never from a fork, since GitHub resolves a fork's commit under the parent's name.
   - Pin reusable workflows (`jobs.<id>.uses`) to a full commit SHA even with a lockfile, which does not cover them,
     and `docker://` images to a digest.
   - When you touch a workflow that still references actions by tag, name them to the user instead of rewriting
     lines outside the change.

5. Set `persist-credentials: false` on `actions/checkout` unless a later step in the same job runs an authenticated
   Git command with that token. Otherwise the token stays on the runner for every later step and every uploaded
   artifact that includes it.

6. Pass each secret only to the step that uses it, through that step's `env:` or `with:`, and pass named secrets to
   reusable workflows rather than `secrets: inherit`. Never store structured data (JSON, YAML) as one secret, and
   mask any sensitive value derived from a secret with `::add-mask::` before it can reach a log.

7. Give every job a `timeout-minutes`, so a hung step does not hold a runner for the six-hour default.
