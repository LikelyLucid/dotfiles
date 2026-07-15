local function desktop_colors()
  local ok, colors = pcall(dofile, vim.fn.expand("~/.cache/wal/wallust.nvim.lua"))
  if not ok then
    return {
      accent = "#82aaff",
      foreground = "#c8d3f5",
      muted = "#636da6",
    }
  end

  return {
    accent = colors.color3,
    foreground = colors.foreground,
    muted = colors.color8,
    blue = colors.color4,
    cyan = colors.color6,
    green = colors.color2,
    purple = colors.color5,
    soft = colors.color7,
  }
end

return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "moon",
      transparent = true,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = false },
        sidebars = "dark",
        floats = "dark",
      },
      on_colors = function(colors)
        local desktop = desktop_colors()
        colors.blue = desktop.accent
        colors.blue0 = desktop.blue
        colors.blue1 = desktop.cyan
        colors.blue2 = desktop.blue
        colors.blue5 = desktop.accent
        colors.blue6 = desktop.cyan
        colors.blue7 = desktop.soft
        colors.cyan = desktop.cyan
        colors.green = desktop.green
        colors.green1 = desktop.cyan
        colors.magenta = desktop.purple
        colors.magenta2 = desktop.blue
        colors.purple = desktop.purple
        colors.teal = desktop.cyan
        colors.fg = desktop.foreground
        colors.fg_dark = desktop.muted
      end,
      on_highlights = function(hl, colors)
        local desktop = desktop_colors()
        local panel = colors.bg_dark
        local selection = colors.bg_highlight

        hl.CursorLine = { bg = selection }
        hl.CursorColumn = { bg = selection }
        hl.ColorColumn = { bg = panel }
        hl.Visual = { bg = colors.bg_visual }
        hl.LineNr = { fg = colors.dark5 }
        hl.CursorLineNr = { fg = desktop.accent, bold = true }
        hl.WinSeparator = { fg = colors.bg_highlight }
        hl.FloatBorder = { fg = desktop.accent, bg = panel }
        hl.FloatTitle = { fg = desktop.foreground, bg = panel, bold = true }
        hl.PmenuSel = { fg = colors.bg, bg = desktop.accent, bold = true }
        hl.Search = { fg = colors.bg, bg = desktop.accent, bold = true }
        hl.IncSearch = { fg = colors.bg, bg = desktop.foreground, bold = true }
        hl.MatchParen = { fg = desktop.foreground, bg = selection, bold = true }

        hl.NeoTreeNormal = { fg = colors.fg, bg = panel }
        hl.NeoTreeNormalNC = { fg = colors.fg_dark, bg = panel }
        hl.NeoTreeEndOfBuffer = { fg = panel, bg = panel }
        hl.NeoTreeWinSeparator = { fg = colors.bg_highlight, bg = panel }
        hl.NeoTreeDirectoryIcon = { fg = desktop.accent }
        hl.NeoTreeDirectoryName = { fg = colors.blue1 }
        hl.NeoTreeRootName = { fg = desktop.foreground, bold = true }
        hl.NeoTreeCursorLine = { bg = selection }

        hl.SnacksPickerBorder = { fg = colors.bg_highlight, bg = panel }
        hl.SnacksPickerTitle = { fg = desktop.accent, bg = panel, bold = true }
        hl.SnacksInputBorder = { fg = desktop.accent, bg = panel }
        hl.TelescopeBorder = { fg = colors.bg_highlight, bg = panel }
        hl.TelescopeTitle = { fg = desktop.accent, bg = panel, bold = true }

        hl.TabLine = { fg = colors.fg_dark, bg = panel }
        hl.TabLineSel = { fg = desktop.foreground, bg = colors.bg_highlight, bold = true }
        hl.TabLineFill = { bg = colors.bg }
        hl.StatusLine = { fg = colors.fg, bg = panel }
        hl.StatusLineNC = { fg = colors.dark5, bg = panel }

        local heading_colors = {
          desktop.cyan,
          desktop.accent,
          desktop.purple,
          desktop.soft,
          desktop.blue,
          desktop.muted,
        }
        for level = 1, 6 do
          local color = heading_colors[level]
          hl["RenderMarkdownH" .. level] = { fg = color, bold = true }
          hl["RenderMarkdownH" .. level .. "Bg"] = { bg = panel }
          hl["@markup.heading." .. level .. ".markdown"] = { fg = color, bold = true }
          hl["markdownH" .. level] = { fg = color, bold = true }
        end
        hl.RenderMarkdownBullet = { fg = desktop.accent }
        hl.RenderMarkdownDash = { fg = desktop.muted }
        hl.RenderMarkdownTableHead = { fg = desktop.cyan }
        hl.RenderMarkdownTableRow = { fg = desktop.blue }
        hl["@markup.list.markdown"] = { fg = desktop.accent }
        hl["@markup.link.label.markdown_inline"] = { fg = desktop.cyan }
        hl["@markup.link.url.markdown_inline"] = { fg = desktop.muted, underline = true }
      end,
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local desktop = desktop_colors()
      local panel = "#1e2030"
      local transparent = "NONE"
      local theme = {
        normal = {
          a = { fg = panel, bg = desktop.accent, gui = "bold" },
          b = { fg = desktop.foreground, bg = panel },
          c = { fg = desktop.muted, bg = transparent },
        },
        insert = {
          a = { fg = panel, bg = desktop.accent, gui = "bold" },
        },
        visual = {
          a = { fg = panel, bg = desktop.foreground, gui = "bold" },
        },
        replace = {
          a = { fg = panel, bg = "#ff757f", gui = "bold" },
        },
        command = {
          a = { fg = panel, bg = "#ffc777", gui = "bold" },
        },
        inactive = {
          a = { fg = desktop.muted, bg = panel },
          b = { fg = desktop.muted, bg = panel },
          c = { fg = desktop.muted, bg = transparent },
        },
      }

      opts.options = opts.options or {}
      opts.options.theme = theme
      opts.options.section_separators = { left = "", right = "" }
      opts.options.component_separators = { left = "│", right = "│" }
      return opts
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },
}
