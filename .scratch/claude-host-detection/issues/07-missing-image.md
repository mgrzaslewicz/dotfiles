# Missing image handling

Type: grilling
Status: resolved

## Question

If `claude-toolbox:latest` doesn't exist yet, should the new wrapper build
it automatically (mirroring `claude-toolbox()`), or fail fast with an
instruction to run `claude-toolbox` interactively first?

## Answer

Auto-build, matching `claude-toolbox()`: if `podman image inspect` fails,
run `podman build` (same `--build-arg USER_ID`/`GROUP_ID`) before proceeding.
Keeps behavior consistent between the two entry points, at the cost of a
slow first invocation if the image hasn't been built yet.
