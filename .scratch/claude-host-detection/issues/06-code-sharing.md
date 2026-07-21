# Code sharing with claude-toolbox()

Type: grilling
Status: resolved

## Question

Both the existing interactive `claude-toolbox()` zsh function and the new
non-interactive wrapper need to build the image if missing, create the
volumes, and run podman with mostly the same flags. Should they share that
logic (e.g. via a common script both source/call), or stay independent?

## Answer

Independent, with some duplication accepted. `executable_claude.zsh` stays
as-is (interactive, zsh-only, human-driven); the new
`dot_local/bin/executable_claude` is a fully separate bash script. They live
in different runtimes (zsh function vs. real host executable) and now have
diverging concerns (TTY auto-detection, absolute-path mounts) — sharing
logic across that boundary was judged to add more indirection than the saved
code was worth.
