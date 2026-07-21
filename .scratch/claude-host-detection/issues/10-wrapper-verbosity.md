# Wrapper verbosity

Type: grilling
Status: resolved

## Question

Should the wrapper print anything (to stderr) indicating it's routing
through the container, or stay completely silent and pass claude's own
output straight through?

## Answer

Completely silent. No extra output at all — stdout/stderr/exit code are
exactly what the containerized claude produces, indistinguishable from a
native install from a calling tool's perspective. Safer for tools that might
be strict about unexpected stderr content.
