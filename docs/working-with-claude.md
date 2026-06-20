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
claude-shell        # = sudo -iu claude, starting in /srv/dev
```
A login shell **as** `claude`. Run `claude` there and Claude Code operates as the
agent — committing and signing as itself, **unable to read your home** (`~` is
`0750`; claude has no ACL into it).

## The collaboration model: two clones, sync via git

- **`claude`** clones a project into **`/srv/dev`** (its workspace; you can read it
  for inspection, but you don't co-edit it):
  ```sh
  claude-shell
  cd /srv/dev && git clone git@github.com:dimitrios-git/<project>.git
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

## The dotfiles repo specifically

`estia` is the one repo whose working copy is **live**: its files are
symlinked into `~`/`~/.config`, so **your clone at `~/Development/estia` is the
deployment source** — editing it changes your running system.

So: claude works in its **own** clone under `/srv/dev/estia`, pushes changes,
and they reach your live system only when **you pull** (i.e. after review). 

> **Keep straight:** the symlinks point at `~/Development/estia` and must stay
> that way. Never make `/srv/dev/estia` (claude's clone) the deployment
> source.

## Isolation (what claude can and can't touch)

- ✅ `/srv/dev` and its own home — its workspace.
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
| Give claude a project | it clones into `/srv/dev`; you sync via git |
| Get claude's work | review its pushed branch/PR, merge, `git pull` |
| Update your live dotfiles | pull into `~/Development/estia` (the symlink source) |
| Co-edit a home path (rare) | `claude-access grant <path>` |
| Confirm isolation holds | `sudo -u claude ls ~` → Permission denied |
