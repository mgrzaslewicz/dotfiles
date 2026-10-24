# Layer B: session restore

Type: task
Status: open
Blocked by: 15

## What

Spec decision 19 row 8.

- In gradle-java: open files in splits plus panels (neo-tree, quickfix), quit, start a new child in the
  same cwd; assert buffers/splits restored, jdtls attached, no empty panel windows.

## Acceptance

gradle-java green.
