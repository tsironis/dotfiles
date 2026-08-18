--[[
  MODERN KICKSTART (v0.13 Custom)
  - Plugin Manager: lazy.nvim
  - Completion: blink.cmp
  - LSP: Native + nvim-lspconfig
  - Picker: mini.pick
  - UI: mini.nvim + which-key + snacks (utilities)
]]

-- 1. PREAMBLE & OPTIONS
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Performance
vim.loader.enable()

-- UI Options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.showmode = false
vim.opt.clipboard = 'unnamedplus'
vim.opt.breakindent = true
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = 'yes'
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.opt.scrolloff = 10
vim.opt.cursorline = true
vim.opt.directory = vim.fn.stdpath('state') .. '/swap//'

-- Indentation
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2

-- 2. PLUGIN BOOTSTRAP
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    '--branch=stable',
    'https://github.com/folke/lazy.nvim.git',
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

-- 3. PLUGINS
require('lazy').setup {
  -- Colorscheme is applied via mini.base16 (Tango Dark palette) in the mini.nvim
  -- config block below, to keep the whole stack on one theme.
  {
    'folke/trouble.nvim',
    opts = {}, -- Use defaults
    cmd = 'Trouble',
    keys = {
      { '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', desc = 'Diagnostics (Trouble)' },
    },
  },

  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = {
      'MunifTanjim/nui.nvim',
      -- 'rcarriga/nvim-notify', -- OPTIONAL: Uncomment for fancy notifications
    },
    opts = {
      lsp = {
        override = {
          ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
          ['vim.lsp.util.stylize_markdown'] = true,
          -- We do NOT override 'cmp.entry.get_documentation' because you use blink.cmp
        },
      },
      presets = {
        bottom_search = true, -- Classic bottom search bar
        command_palette = true, -- Position command line in the center
        long_message_to_split = true, -- Long messages go to a split window
      },
    },
  },
  {
    'MeanderingProgrammer/render-markdown.nvim',
    -- Pinned: v8.12.0 regressed heading/code rendering when `backgrounds = false`
    -- (appends a `false` entry to the extmark hl-group list, which Neovim rejects
    -- with "Invalid hl_group"). v8.11.0 is the last release that renders cleanly.
    version = '~8.11.0',
    ft = { 'markdown', 'codecompanion' },
    opts = {
      heading = {
        backgrounds = false,
        icons = { '# ', '## ', '### ', '#### ', '##### ', '###### ' },
      },
      code = {
        style = 'language',
        border = 'thin',
      },
      anti_conceal = { enabled = true },
    },
  },
  {
    'selimacerbas/markdown-preview.nvim',
    dependencies = { 'selimacerbas/live-server.nvim' },
    config = function()
      require('markdown_preview').setup {
        port = 8421,
        open_browser = true,
        debounce_ms = 300,
      }
    end,
  },
  {
    -- Live, in-browser preview for .typ files (updates as you type).
    'chomosuke/typst-preview.nvim',
    ft = 'typst',
    version = '1.*',
    -- Fetches the preview backend binary on install/update.
    build = function()
      require('typst-preview').update()
    end,
    opts = {},
  },

  -- UI Ecosystem (Mini)
  {
    'stevearc/oil.nvim',
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {},
    -- Optional dependencies
    dependencies = { { 'nvim-mini/mini.icons', opts = {} } },
    -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
    -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
    lazy = false,
    config = function()
      require('oil').setup()
    end,
  },
  {
    'echasnovski/mini.nvim',
    version = '*',
    config = function()
      -- Colorscheme: Tango Dark (matches Ghostty / sketchybar / borders / zellij).
      -- base00 (#000000) equals the terminal background, so a solid bg is visually
      -- identical to the previous transparent setup.
      require('mini.base16').setup {
        palette = {
          base00 = '#000000',
          base01 = '#2e3436',
          base02 = '#555753',
          base03 = '#888a85',
          base04 = '#babdb6',
          base05 = '#d3d7cf',
          base06 = '#eeeeec',
          base07 = '#ffffff',
          base08 = '#ef2929',
          base09 = '#f57900',
          base0A = '#fce94f',
          base0B = '#8ae234',
          base0C = '#34e2e2',
          base0D = '#729fcf',
          base0E = '#ad7fa8',
          base0F = '#ce5c00',
        },
      }

      require('mini.pick').setup {
        mappings = {
          choose_all = {
            char = '<C-q>',
            func = function()
              local mappings = MiniPick.get_picker_opts().mappings
              vim.api.nvim_input(mappings.mark_all .. mappings.choose_marked)
            end,
          },
        },
      }
      require('mini.statusline').setup()
      require('mini.icons').setup()
      require('mini.pairs').setup()
      require('mini.surround').setup()
      require('mini.indentscope').setup()
      require('mini.ai').setup { n_lines = 500 }
      require('mini.comment').setup()

      -- Git integration
      require('mini.git').setup()
      require('mini.diff').setup {
        view = {
          style = 'sign',
          signs = { add = '▎', change = '▎', delete = '' },
        },
        mappings = {
          apply = '<leader>gh', -- [G]it [H]unk apply
          reset = '<leader>gr', -- [G]it [R]eset hunk
        },
      }

      -- Colors
      require('mini.hipatterns').setup {
        highlighters = {
          hex_color = require('mini.hipatterns').gen_highlighter.hex_color(),
        },
      }
    end,
  },
  {
    'windwp/nvim-ts-autotag',
    opts = {},
  },

  -- Which-Key (Keybinding Helper)
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
      preset = 'modern', -- 'classic', 'modern', 'helix'
      delay = 200,
      spec = {
        { '<leader>c', group = '[C]ode', mode = { 'n', 'x' } },
        { '<leader>d', group = '[D]ocument', mode = { 'n', 'x' } },
        { '<leader>g', group = '[G]it', mode = { 'n', 'x' } },
        { '<leader>s', group = '[S]earch', mode = { 'n', 'x' } },
        { '<leader>t', group = '[T]odo', mode = { 'n', 'x' } },
        { '<leader>w', group = '[W]orkspace', mode = { 'n', 'x' } },
      },
    },
  },

  -- Snacks (Utilities)
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    opts = {
      -- 1. UTILITIES
      bigfile = { enabled = true }, -- Prevent freezes on large files
      quickfile = { enabled = true }, -- Load first file faster
      zen = { enabled = true }, -- Load first file faster

      -- 2. GIT
      lazygit = { enabled = true }, -- Floating git terminal
      gitbrowse = {
        enabled = true,
        url_patterns = {
          ['github%.com'] = {
            branch = '/tree/{branch}',
            file = '/blob/{branch}/{file}#L{line}',
            blame = '/blame/{branch}/{file}#L{line}',
            commit = '/commit/{commit}',
          },
          ['gitlab%.com'] = {
            branch = '/-/tree/{branch}',
            file = '/-/blob/{branch}/{file}#L{line}',
            blame = '/-/blame/{branch}/{file}#L{line}',
            commit = '/-/commit/{commit}',
          },
        },
      }, -- Open in browser

      -- 3. DISABLE OTHERS (To respect your Mini setup)
      dashboard = { enabled = false },
      indent = { enabled = false },
      input = { enabled = false },
      picker = { enabled = false },
      scope = { enabled = false },
      scroll = { enabled = false },
      statuscolumn = { enabled = false },
      words = { enabled = false },
    },
    keys = {
      {
        '<leader>z',
        function()
          Snacks.zen()
        end,
        desc = 'Toggle Zen Mode',
      },
      {
        '<leader>lg',
        function()
          Snacks.lazygit()
        end,
        desc = 'Lazygit',
      },
      {
        '<leader>gB',
        function()
          Snacks.gitbrowse { what = 'file' }
        end,
        desc = 'Git Browse (Open)',
      },
      {
        '<leader>gb',
        function()
          Snacks.git.blame_line()
        end,
        desc = 'Git Blame Line',
      },
    },
  },

  -- Treesitter (main branch — required for Neovim 0.12; the frozen master
  -- branch is incompatible). No configs.setup/ensure_installed here: parsers are
  -- installed via install(), highlighting is started per-buffer in a FileType
  -- autocmd, and missing parsers are fetched on demand (replaces auto_install).
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false, -- does not support lazy-loading
    build = ':TSUpdate',
    config = function()
      -- Curated set covering the languages this config actually edits.
      require('nvim-treesitter').install {
        'lua', 'c', 'vim', 'vimdoc', 'query',
        'markdown', 'markdown_inline', -- markdown_inline is needed for injections
        'typst', 'nix', 'bash', 'python', 'go', 'rust', 'toml',
        'json', 'yaml', 'javascript', 'typescript', 'tsx', 'html', 'css',
      }

      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter-start', { clear = true }),
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
          if not lang then
            return
          end
          if pcall(vim.treesitter.language.add, lang) then
            -- Highlighting (Neovim built-in) + experimental TS indentation.
            pcall(vim.treesitter.start, ev.buf, lang)
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          else
            -- Parser not installed yet: fetch it (async) so it's ready next open.
            pcall(function()
              require('nvim-treesitter').install(lang)
            end)
          end
        end,
      })
    end,
  },

  -- Formatting
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    opts = {
      formatters_by_ft = {
        lua = { 'stylua' },
        javascript = { 'prettier' },
        typescript = { 'prettier' },
        markdown = { 'markdown_prettier' },
        nix = { 'alejandra' },
        sh = { 'shfmt' },
        bash = { 'shfmt' },
      },
      formatters = {
        -- Prose is hard-wrapped at 80 on every save, so editing mid-paragraph
        -- never leaves ragged trailing lines. The flags are passed on the CLI
        -- (rather than via a .prettierrc) so the width wins over whatever
        -- prettier config the surrounding repo happens to ship.
        markdown_prettier = {
          command = 'prettier',
          args = {
            '--stdin-filepath',
            '$FILENAME',
            '--parser',
            'markdown',
            '--prose-wrap',
            'always',
            '--print-width',
            '80',
          },
          stdin = true,
        },
      },
      format_on_save = {
        -- Generous: prettier is a cold node start, not a daemon.
        timeout_ms = 3000,
        lsp_format = 'fallback',
      },
    },
  },

  -- LSP Configuration
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'saghen/blink.cmp',
    },
    config = function()
      require('mason').setup()

      -- Global Defaults (Capabilities)
      vim.lsp.config('*', {
        root_markers = { '.git' },
        capabilities = require('blink.cmp').get_lsp_capabilities(),
      })

      -- Specific Server Configurations
      vim.lsp.config['lua_ls'] = {
        settings = {
          Lua = {
            diagnostics = { globals = { 'vim' } },
            hint = { enable = true },
          },
        },
      }

      -- tinymist: enable typstyle formatting so conform's lsp_format fallback
      -- formats .typ on save (tinymist ships formatting disabled by default).
      vim.lsp.config['tinymist'] = {
        settings = {
          formatterMode = 'typstyle',
          exportPdf = 'never',
        },
      }

      -- Mason installs the binaries; mason-lspconfig auto-enables every installed
      -- server via vim.lsp.enable (automatic_enable, default true). rust_analyzer is
      -- excluded because rustaceanvim owns its client — enabling both double-attaches.
      require('mason-lspconfig').setup {
        ensure_installed = { 'lua_ls', 'ts_ls', 'pyright', 'gopls', 'rust_analyzer', 'tinymist' },
        automatic_enable = {
          exclude = { 'rust_analyzer' },
        },
      }

      -- nixd is installed via Nix (not Mason); enable it directly.
      vim.lsp.enable 'nixd'
    end,
  },
  {
    'mrcjkb/rustaceanvim',
    version = '^8', -- v9 requires Neovim 0.12; v8 supports the pinned 0.11
    lazy = false, -- plugin lazy-loads itself on the rust filetype
    init = function()
      vim.g.rustaceanvim = {
        server = {
          -- rustaceanvim does not read the global vim.lsp.config('*'), so pass blink caps explicitly.
          capabilities = require('blink.cmp').get_lsp_capabilities(),
          on_attach = function(_, bufnr)
            local map = function(keys, fn, desc)
              vim.keymap.set({ 'n', 'x' }, keys, fn, { buffer = bufnr, silent = true, desc = desc })
            end
            -- Code fixes (grouped rust-analyzer code actions)
            map('<leader>ca', function()
              vim.cmd.RustLsp 'codeAction'
            end, '[C]ode [A]ction')
            map('<leader>ce', function()
              vim.cmd.RustLsp 'explainError'
            end, '[C]ode [E]xplain error')
            map('<leader>cd', function()
              vim.cmd.RustLsp 'renderDiagnostic'
            end, '[C]ode render [D]iagnostic')
            -- Hover with actions (overrides default K in rust buffers)
            vim.keymap.set('n', 'K', function()
              vim.cmd.RustLsp { 'hover', 'actions' }
            end, { buffer = bufnr, silent = true, desc = 'Hover actions' })
          end,
        },
      }
    end,
  },
  {
    'folke/todo-comments.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = { signs = false },
  },
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts = {},
    keys = {
      {
        's',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').jump()
        end,
        desc = 'Flash',
      },
      {
        'S',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').treesitter()
        end,
        desc = 'Flash Treesitter',
      },
      {
        'r',
        mode = 'o',
        function()
          require('flash').remote()
        end,
        desc = 'Remote Flash',
      },
    },
  },
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = { { path = '${3rd}/luv/library', words = { 'vim%.uv' } } },
    },
  },

  -- Completion (Blink)
  {
    'saghen/blink.cmp',
    dependencies = 'rafamadriz/friendly-snippets',
    version = 'v0.*',
    opts = {
      keymap = { preset = 'default' },
      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = 'mono',
      },
      sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
      },
    },
  },
}

-- 4. KEYMAPS
vim.keymap.set('n', '<leader>w', '<cmd>write<cr>', { desc = 'Save File' })
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })

-- oil.nvim
vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })
-- todo-comments
vim.keymap.set('n', '<leader>tp', function()
  require('todo-comments').jump_prev()
end, { desc = 'Next Todo' })
vim.keymap.set('n', '<leader>tn', function()
  require('todo-comments').jump_next()
end, { desc = 'Next Todo' })
vim.keymap.set('n', '<leader>sT', ':TodoLocList<cr>', { desc = 'Search Todos' })

-- Mini.Pick
vim.keymap.set('n', '<leader>sf', function()
  require('mini.pick').builtin.files()
end, { desc = 'Search Files' })
vim.keymap.set('n', '<leader>sg', function()
  require('mini.pick').builtin.grep_live()
end, { desc = 'Search Grep' })
vim.keymap.set('n', '<leader>sh', function()
  require('mini.pick').builtin.help()
end, { desc = 'Search Help' })
vim.keymap.set('n', '<leader><space>', function()
  require('mini.pick').builtin.buffers()
end, { desc = 'Find Buffer' })

-- LSP Keymaps
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
      vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
    end
  end,
})

-- Diagnostics UI
vim.diagnostic.config {
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = '✘',
      [vim.diagnostic.severity.WARN] = '▲',
      [vim.diagnostic.severity.HINT] = '⚑',
      [vim.diagnostic.severity.INFO] = '»',
    },
  },
  virtual_text = { prefix = '●' },
  float = { border = 'rounded' },
}

vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic Error' })
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Previous Diagnostic' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Next Diagnostic' })

-- Typst: buffer-local live-preview toggle ([C]ode [P]review)
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'typst',
  group = vim.api.nvim_create_augroup('typst-keymaps', { clear = true }),
  callback = function(ev)
    vim.keymap.set('n', '<leader>cp', '<cmd>TypstPreviewToggle<cr>', { buffer = ev.buf, desc = 'Typst Preview Toggle' })
  end,
})

-- Highlight on Yank
vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})
