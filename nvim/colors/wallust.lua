local ok, c = pcall(dofile, vim.fn.expand("~/.cache/wal/wallust.nvim.lua"))
if not ok then
  vim.notify("wallust colors missing; run set-wallpaper", vim.log.levels.WARN)
  return
end

vim.cmd("highlight clear")
vim.o.termguicolors = true
vim.o.background = "dark"
vim.g.colors_name = "wallust"

local p = {
  bg = c.background,
  panel = c.color0,
  fg = c.foreground,
  soft = c.color7,
  muted = c.color8,
  dim = c.color0,
}

local hi = vim.api.nvim_set_hl
local function h(group, opts)
  hi(0, group, opts)
end

h("Normal", { fg = p.fg, bg = "NONE" })
h("NormalFloat", { fg = p.fg, bg = p.panel })
h("FloatBorder", { fg = p.muted, bg = p.panel })
h("Cursor", { fg = p.bg, bg = p.fg })
h("CursorLine", { bg = "NONE" })
h("Visual", { bg = p.dim })
h("Search", { fg = p.bg, bg = p.soft })
h("IncSearch", { fg = p.bg, bg = p.fg })
h("LineNr", { fg = p.muted })
h("CursorLineNr", { fg = p.soft, bold = true })
h("StatusLine", { fg = p.fg, bg = p.panel })
h("StatusLineNC", { fg = p.muted, bg = p.bg })
h("Pmenu", { fg = p.fg, bg = p.panel })
h("PmenuSel", { fg = p.bg, bg = p.soft })
h("WinSeparator", { fg = p.dim })

h("Comment", { fg = p.muted, italic = true })
h("String", { fg = p.soft })
h("Function", { fg = p.fg })
h("Identifier", { fg = p.fg })
h("Statement", { fg = p.soft, bold = true })
h("Keyword", { fg = p.soft, bold = true })
h("Type", { fg = p.soft })
h("Constant", { fg = p.soft })
h("PreProc", { fg = p.soft })
h("Special", { fg = p.soft })
h("Title", { fg = p.fg, bold = true })
h("Todo", { fg = p.bg, bg = p.soft, bold = true })

h("DiagnosticError", { fg = p.soft })
h("DiagnosticWarn", { fg = p.soft })
h("DiagnosticInfo", { fg = p.muted })
h("DiagnosticHint", { fg = p.muted })

for _, group in ipairs({
  "@markup.heading",
  "@markup.heading.1",
  "@markup.heading.2",
  "@markup.heading.3",
  "@markup.heading.4",
  "@markup.heading.5",
  "@markup.heading.6",
  "markdownH1",
  "markdownH2",
  "markdownH3",
  "markdownH4",
  "markdownH5",
  "markdownH6",
}) do
  h(group, { fg = p.fg, bold = true })
end

for _, group in ipairs({
  "markdownHeadingDelimiter",
  "markdownListMarker",
  "markdownBlockquote",
  "@markup.list",
  "@markup.quote",
  "RenderMarkdownBullet",
  "RenderMarkdownDash",
  "RenderMarkdownQuote",
}) do
  h(group, { fg = p.muted })
end

for _, group in ipairs({
  "markdownCode",
  "markdownCodeBlock",
  "markdownCodeDelimiter",
  "@markup.raw",
  "RenderMarkdownCode",
  "RenderMarkdownCodeInline",
}) do
  h(group, { fg = p.soft, bg = p.panel })
end

for _, group in ipairs({
  "markdownLinkText",
  "markdownUrl",
  "@markup.link",
  "@markup.link.label",
  "@markup.link.url",
  "RenderMarkdownLink",
}) do
  h(group, { fg = p.soft, underline = true })
end

for _, group in ipairs({
  "@markup.strong",
  "markdownBold",
}) do
  h(group, { fg = p.fg, bold = true })
end

for _, group in ipairs({
  "@markup.italic",
  "markdownItalic",
}) do
  h(group, { fg = p.fg, italic = true })
end

for _, group in ipairs({
  "RenderMarkdownH1",
  "RenderMarkdownH2",
  "RenderMarkdownH3",
  "RenderMarkdownH4",
  "RenderMarkdownH5",
  "RenderMarkdownH6",
}) do
  h(group, { fg = p.fg, bold = true })
end

for _, group in ipairs({
  "RenderMarkdownH1Bg",
  "RenderMarkdownH2Bg",
  "RenderMarkdownH3Bg",
  "RenderMarkdownH4Bg",
  "RenderMarkdownH5Bg",
  "RenderMarkdownH6Bg",
}) do
  h(group, { bg = p.panel })
end
