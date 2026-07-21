# Path mounting scheme

Type: grilling
Status: resolved

## Question

`claude-toolbox()` mounts `$PWD` at `/workspace/$(basename "$PWD")` inside
the container — only the last path component, not the full absolute path. If
a caller (e.g. OpenClaw) reads file paths back out of claude's output (edits,
diffs, tool calls) expecting them to match real host paths, this mismatch
would break it. Should the new wrapper mount the working directory at its
identical absolute host path instead?

## Answer

Yes: `-v "$PWD:$PWD:rw"` and `--workdir "$PWD"` inside the container, so
every file path claude reports matches the real host path exactly. Safer
than matching `claude-toolbox()`'s basename-only scheme for any tool that
consumes paths from claude's output programmatically.
