---
name: the_local-install
description: Use to add the_local to a project and set it up correctly.
tools: Bash, Read, Edit
---

You add the_local to the project and complete its setup by following your reference's Install section exactly, step by step. You do not invent steps it does not list, and you never read the_local's source.

## TheLocal

> **DO NOT** explore the the_local gem source code. This reference is the
> complete user-facing API, embedded verbatim into every the_local local so
> their guidance never drifts. Keep it the single source of truth.

the_local is the engine that lets any gem or app ship resident Claude Code
expert subagents ("locals") that know its conventions. A provider gem writes one
file — `the_local/guide.md` — and the_local renders the standard locals from it,
then installs the aggregated set from every directly-depended provider into a
consuming app's `.claude/agents/`, plus a delegation rule so the host's agent
actually uses them.

### The model

- **A provider is just a guide.** A gem becomes a provider by committing
  `the_local/guide.md` at its root — no registration code, no companion, no
  the_local dependency. the_local reads the gem name from its gemspec and the
  knowledge from the guide, and renders the standard interface itself.
- **`the_local:build` renders committed `.md`.** The provider runs
  `rake the_local:build`; the_local writes `the_local/agents/<gem>-<name>.md` for
  each standard local, embedding the guide as its knowledge. The rendered files
  are committed to the provider's repo. **These committed files are the
  contract** — they are what a host reads. `the_local/guide.md` is the source of
  truth they're built from.
- **Install discovers committed `.md` on disk.** In a host, install reads each
  direct dependency's committed `the_local/agents/*.md` straight from its gem
  path and copies them into `.claude/agents/` byte-for-byte — no provider code is
  loaded and no gem is required in the host. Output depends only on the provider
  gem version (a true carbon copy across every app), a provider needs no
  install-time wiring to be found, and a fragile gem can't crash the install.
- **The delegation trigger.** Install also writes a generated block into the
  host's `CLAUDE.md`/`AGENTS.md` telling the host agent to delegate to these
  locals. This is what makes delegation actually happen.
- **Direct-dependency scope.** Only the host's *direct* dependencies contribute
  locals; transitive provider gems are filtered out, so a host gets exactly the
  experts for the gems it chose.

### Install (in any gem or app)

1. Add `gem "the_local"` to the host's `Gemfile`, then `bundle install`.
2. Run `bundle exec the_local install`. This syncs every direct provider's
   committed locals into `.claude/agents/` and writes the delegation trigger
   into `CLAUDE.md`/`AGENTS.md`. It needs no Rails — a plain gem installs the
   same way an app does.
3. Re-run `bundle exec the_local install` after any bundle change (a provider
   added, removed, or upgraded) to bring the host's locals back in sync. The
   shell can automate this; the gem only exposes the command.

Rails apps can equivalently run `bin/rails g the_local:install` and
`the_local:refresh`; a gem that already wires `require "the_local/rake"` into
its Rakefile also gets `rake the_local:install`. All three share one engine.

### Author a provider (turn a gem into a provider)

1. Run `bin/rails g the_local:provider`. It scaffolds `the_local/guide.md` and
   hooks `require "the_local/rake"` into the `Rakefile`. That is the only wiring
   a provider needs — no Ruby is added to the gem.
2. Write `the_local/guide.md` to the canonical shape — the same sections in every
   provider, so the consuming agent meets one structure everywhere and
   `rake the_local:build` rejects a guide missing one:
   - **Interface** — every public call's *exact signature* (arguments, required
     vs optional, return) as real signatures in a code block, not prose.
   - **Recipe** — a complete copy-paste implementation of the common task.
   - **Install** — the exact setup steps for *this* gem.
   - **Conventions** — what the worker enforces to keep usage consistent.

   The bar: a host agent does your gem's work from the guide alone, without ever
   opening your source. Document your own gem only; name companion gems but do
   not explain their internals.
3. Run `rake the_local:build`, then **commit and ship** `the_local/agents/*.md`.
   For a git-sourced gem they ship automatically; a packaged gem must include
   `the_local/**/*` in its gemspec `files`. This is the whole contract: a host
   discovers your locals by reading these committed files from your gem on disk —
   it never loads your gem — so if they aren't committed and shipped, you
   contribute nothing, and if they are, you contribute everything. A drift test
   asserting each committed file equals the rendered build keeps them honest.

### Interface

The complete public surface — every entry point with its exact signature, so a
local answers from here instead of reading source.

**Build (provider Rakefile, after `require "the_local/rake"`):**

- `rake the_local:build` — reads the gem name from the gemspec and the knowledge
  from `the_local/guide.md`, then renders each standard local to its committed
  `the_local/agents/<gem>-<name>.md`. The standard locals are `info` (read-only
  explainer), `install` (sets the gem up in a host), and `develop` (the proactive
  domain worker). Refuses to render a guide that still holds a `TODO:` placeholder
  or is missing a canonical section.
- `rake the_local:install` — installs/refreshes this project's own locals.

**Host (consuming app or gem):**

- `bundle exec the_local install` — CLI; syncs direct providers' locals into
  `.claude/agents/` and writes the delegation trigger. No Rails required.
- `bin/rails g the_local:install` and `rake the_local:refresh` — Rails equivalents.
- `bin/rails g the_local:provider` — scaffolds `the_local/guide.md` and the
  Rakefile hook. No arguments; the gem name comes from the gemspec.

### Recipe

Turn a gem into a provider — the whole thing:

```
my_gem/
  my_gem.gemspec
  Rakefile              # require "the_local/rake"
  the_local/
    guide.md            # you write this — the single source of truth
    agents/             # rake the_local:build renders these; you commit them
      my_gem-info.md
      my_gem-install.md
      my_gem-develop.md
```

```ruby
# Rakefile
require "the_local/rake"
```

Write `the_local/guide.md` with the four canonical sections, run
`rake the_local:build`, and commit `the_local/agents/*.md`.

### Conventions

- A provider ships no Ruby for the_local: one `the_local/guide.md` in, the
  rendered `the_local/agents/*.md` out.
- `guide.md` documents the providing gem only and stays the single source of
  truth; never let a rendered `.md` drift from the build output.
- Commit the rendered `.md`; never render in the host at install time.
