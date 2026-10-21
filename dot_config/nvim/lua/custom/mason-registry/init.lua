-- Local Mason registry: package definitions that override the upstream mason-registry.
-- Each value is a module returning a package spec (same schema as mason-registry's package.yaml).
-- Remove an entry once the upstream fix is released, so Mason picks up upstream updates again.
return {
  -- https://github.com/mason-org/mason-registry/pull/17323
  'custom.mason-registry.kotlin-lsp',
}
