# PATH order verification

Type: grilling
Status: resolved

## Question

The shadow-guard decision ([02](02-shadow-guard.md)) depends on `~/.local/bin`
being ordered after any native-install location (npm global bin, mise shims,
etc.) in the host's `PATH`. This session runs inside the `claude-toolbox`
container itself and has no way to inspect the actual host shell
environment or its `PATH` construction (not found in this repo's tracked
dotfiles — likely comes from oh-my-zsh defaults or mise's shell activation).
Can the user confirm this ordering on the real host?

## Answer

Confirmed by the user: `~/.local/bin` is already ordered late enough on
their host `PATH` that a native `claude` install elsewhere would take
precedence automatically.
