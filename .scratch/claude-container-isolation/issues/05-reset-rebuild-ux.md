# Reset/rebuild UX for the volume

Type: grilling
Status: open
Blocked by: 04

## Question

`claude-toolbox-new` today only removes and rebuilds the podman image. Once runtime state lives in a persistent volume, should `claude-toolbox-new` also wipe/recreate the volume, should there be a separate `claude-toolbox-reset` command for that, or something else? Depends on ticket 04's reconciliation strategy — if plugins are physically separated from user-writable state, a full volume wipe may never be necessary; if reconciliation relies on resets, this needs a clear, easy-to-reach command.
