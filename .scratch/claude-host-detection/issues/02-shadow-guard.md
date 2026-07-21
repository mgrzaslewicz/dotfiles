# Guarding against a real claude install

Type: grilling
Status: resolved

## Question

The wrapper should only take effect when no "real" (natively installed)
`claude` exists. How should it avoid shadowing a real install if the user
ever adds one later — rely on `PATH` ordering, or have the script itself
search `PATH` at runtime for another `claude` binary and re-exec that one?

## Answer

Rely on `PATH` ordering: place the wrapper in `~/.local/bin` and ensure that
directory is ordered after wherever a native install would land (npm global
bin, mise shims, etc.) in the host's `PATH`. No logic needed in the script —
standard PATH resolution picks a real binary first if one ever exists.
Simpler and avoids self-reference edge cases in a runtime PATH-search
approach. Depends on the host's actual PATH order, which this session cannot
inspect directly — see
[09-path-order-verification.md](09-path-order-verification.md).
