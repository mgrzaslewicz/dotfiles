# Reconciliation strategy for build-time bake vs runtime volume

Type: grilling
Status: open
Blocked by: 01

## Question

A named volume persists across container runs *and* across image rebuilds. If you rebuild the image with a new/updated plugin baked in, but an existing volume already holds an older `~/.claude`, how does the new bake actually reach the running container? Candidate strategies: physical separation (plugins live outside the volume's mount path, per ticket 01's findings), a merge-on-start step in `setup-and-run-claude.sh` (e.g. copy-if-missing from the baked defaults into the volume), or requiring an explicit reset (see ticket 05) whenever the image changes. Pick the strategy, informed by ticket 01's answer.
