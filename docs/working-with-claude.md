# Working with the `claude` agent user

Day-to-day guide for collaborating with Claude Code running as its own
unprivileged `claude` Linux user (the trust-boundary setup in
`claude-user-design.md`).

> **The mental model:** if the agent has real intelligence, treat it as a
> *collaborator*, not a subprocess. `claude` is a separate Linux user with its own
> SSH key, git identity, and GitHub account. So you collaborate the way two people
> do — **each has their own clone, and you sync through git** (push / pull / review
> / merge). You don't share a working directory; that's what the remote is for.

## Entering claude's context

```sh
claude-shell        # = sudo -iu claude, starting in /srv/devshare
```
A login shell **as** `claude`. Run `claude` there and Claude Code operates as the
agent — committing and signing as itself, **unable to read your home** (`~` is
`0750`; claude has no ACL into it).

## The collaboration model: two clones, sync via git

- **`claude`** clones a project into **`/srv/devshare`** (its workspace; you can read it
  for inspection, but you don't co-edit it):
  ```sh
  claude-shell
  cd /srv/devshare && git clone git@github.com:dimitrios-git/<project>.git
  ```
- **You** keep your **own** clone wherever you normally work (e.g.
  `~/Development/<project>`).
- You collaborate **through GitHub**: claude commits as the bot
  (`dimitrios-claude`, **Verified**) and pushes a branch; you review the diff / PR,
  merge, and `git pull` into your clone. Two principals, normal git flow, full
  history and review.

This is slower than co-editing one copy — by design. The friction *is* the
feature: version control, review-before-merge, and a clean audit trail of who did
what.

## The PR loop (how a change actually lands)

Branches sync the two clones; **pull requests are where review and attribution
become durable.** A bare pushed branch *could* be merged locally, but the PR is
the point — it records that the bot proposed a change, you reviewed it, and you
merged it (the audit trail this whole setup exists for). The loop:

1. **claude** — works on a topic branch, commits (signed as the bot), then:
   ```sh
   git push -u origin <branch>
   gh pr create --base main --fill      # PR authored by dimitrios-claude
   ```
2. **you** — review the diff on GitHub, or pull it down to actually run it:
   ```sh
   gh pr checkout <n>                    # in ~/Development/estia
   ```
   Need changes? claude pushes more commits to the same branch; the PR updates.
3. **you** — merge with a **merge commit**, using the admin bypass:
   ```sh
   gh pr merge <n> --merge --admin       # or the UI's "merge without waiting / bypass rules"
   ```
   A merge commit keeps claude's individual GPG-signed commits intact (squash and
   rebase both re-write the commits and drop the signatures). The `--admin` flag is
   required — see the ruleset note below; plain `gh pr merge` is refused with
   *"base branch policy prohibits the merge."* claude **never** merges its own PR —
   that is the review gate, and the ruleset enforces it.
4. **you** — make it live:
   ```sh
   git checkout main && git pull         # in ~/Development/estia
   ```
   For **estia** this pull *is the deployment* — it repoints the live symlinked
   configs. Other repos have no deploy step.
5. delete the merged branch (local + remote).

`main` is protected by a GitHub **ruleset** (*Restrict updates*) whose only bypass
actor is **Repository admin** — i.e. you. So **only you can update `main`**: claude
(a non-admin collaborator) is blocked from **both** direct pushes *and* PR merges
(verified — both are rejected server-side), and its sole route is opening a PR for
you to merge. Because *Restrict updates* routes every write through the bypass,
even your own merges go through the admin override — hence the `--admin` flag. That
override needs real admin rights, which claude doesn't have, so it is structurally
unavailable to the agent. (Trade-off accepted on purpose: the alternative,
*Require a pull request before merging*, drops the per-merge `--admin` but would let
any write-collaborator — including claude — merge, breaking "only dimitrios writes
`main`.")

claude's `gh` is authenticated as the bot via a classic PAT (`repo` + `read:org`)
in `~claude/.config/gh/` — distinct from the SSH push key `id_claude`: the token
drives the API (opening PRs), SSH carries the git transport.

## The dotfiles repo specifically

`estia` is the one repo whose working copy is **live**: its files are
symlinked into `~`/`~/.config`, so **your clone at `~/Development/estia` is the
deployment source** — editing it changes your running system.

So: claude works in its **own** clone under `/srv/devshare/estia`, pushes changes,
and they reach your live system only when **you pull** (i.e. after review). 

> **Keep straight:** the symlinks point at `~/Development/estia` and must stay
> that way. Never make `/srv/devshare/estia` (claude's clone) the deployment
> source.

## Isolation (what claude can and can't touch)

- ✅ `/srv/devshare` and its own home — its workspace.
- ✅ GitHub, as the bot — push/pull/PR.
- ❌ Your home (`~`), your `~/.ssh`, `~/.gnupg`, `~/.bash_secrets` — fully walled
  off (different UID, `0750` home, no ACLs). Confirm any time:
  ```sh
  sudo -u claude ls ~        # expect: Permission denied
  ```

## Escape hatch: co-editing a path in your home

The clone model means claude needs **no** access to your home. For the rare case
you genuinely want claude to work *in place* on a path under your home (not via a
separate clone), the `claude-access` tool grants/revokes it and tracks it:

```sh
claude-access grant  ~/Development/foo
claude-access list
claude-access revoke ~/Development/foo
```
Prefer the clone model; reach for this only when in-place editing is truly needed.

## Quick reference

| Want to… | Do |
|---|---|
| Enter claude's context | `claude-shell`, then `claude` |
| Give claude a project | it clones into `/srv/devshare`; you sync via git |
| Get claude's work | review its pushed branch/PR, merge, `git pull` |
| Update your live dotfiles | pull into `~/Development/estia` (the symlink source) |
| Co-edit a home path (rare) | `claude-access grant <path>` |
| Confirm isolation holds | `sudo -u claude ls ~` → Permission denied |
