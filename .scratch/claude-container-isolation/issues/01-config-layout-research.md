# Claude Code config layout & plugin shadowing

Type: research
Status: open

## Question

How does Claude Code lay out its config under `~/.claude` / `$XDG_CONFIG_HOME` (plugins, marketplaces, skills, MCP config, session history, project memory)? Is there a system-wide or non-`$HOME` location plugins/skills can be installed to (e.g. a directory Claude Code reads in addition to the user config dir) so that build-time-baked plugins aren't shadowed by a runtime volume mounted over the user config dir? If no such separate location exists, what does Claude Code's own precedence/merge behavior look like when both a system config and a user config are present?

This answer determines whether ticket 04 (reconciliation strategy) can rely on physical separation (bake outside the volume path) versus needing an explicit merge/sync step.
