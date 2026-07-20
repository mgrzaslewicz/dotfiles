# Reset/rebuild UX for the volume

Type: grilling
Status: resolved
Blocked by: 04

## Question

`claude-toolbox-new` today only removes and rebuilds the podman image. Once runtime state lives in a persistent volume, should `claude-toolbox-new` also wipe/recreate the volume, should there be a separate `claude-toolbox-reset` command for that, or something else? Depends on ticket 04's reconciliation strategy — if plugins are physically separated from user-writable state, a full volume wipe may never be necessary; if reconciliation relies on resets, this needs a clear, easy-to-reach command.

## Answer

A separate `claude-toolbox-reset` function, distinct from `claude-toolbox-new`. Since ticket 04's reconciliation strategy already makes plugin/skill updates automatic on every container start (no volume wipe required for that), the two concerns are independent: `claude-toolbox-new` rebuilds the podman image; `claude-toolbox-reset` runs `podman volume rm claude-toolbox-config` to force fresh credentials/session history. Rebuilding the image never forces a re-login, and resetting runtime state never forces an image rebuild.
