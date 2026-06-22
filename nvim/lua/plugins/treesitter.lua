-- treesitter overrides for NixOS
-- parsers are already provided by Nix, so skip TS.update and ensure_installed
-- which require the tree-sitter CLI (dynamically linked, can't run on NixOS)
return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- ponytail: NixOS can't run tree-sitter CLI, parsers come from Nix
    build = function() end,
    opts = {
      auto_install = false,
      ensure_installed = {},
    },
  },
}
