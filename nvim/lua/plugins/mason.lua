-- mason overrides for NixOS
-- mason downloads dynamically linked binaries that can't run on NixOS
-- Use Nix-provided LSP servers and tools instead
return {
  -- Clear ensure_installed (opts_extend concatenates, so we clear via config)
  {
    "mason-org/mason.nvim",
    config = function(_, opts)
      opts.ensure_installed = {}
      require("mason").setup(opts)
      local mr = require("mason-registry")
      mr:on("package:install:success", function()
        vim.defer_fn(function()
          require("lazy.core.handler.event").trigger({
            event = "FileType",
            buf = vim.api.nvim_get_current_buf(),
          })
        end, 100)
      end)
    end,
  },

  -- Mark LSP servers that can't run on NixOS as non-mason
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        marksman = {
          mason = false,
        },
        r_language_server = {
          mason = false,
        },
      },
    },
  },
}
