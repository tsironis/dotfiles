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

  -- Treesitter
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs',
    opts = {
      ensure_installed = { 'lua', 'c', 'vim', 'vimdoc', 'query', 'markdown' },
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
    },
  },

  -- Formatting
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    opts = {
      formatters_by_ft = {
        lua = { 'stylua' },
        javascript = { 'prettierd', 'prettier', stop_after_first = true },
        typescript = { 'prettierd', 'prettier', stop_after_first = true },
        markdown = { 'prettierd', 'prettier', stop_after_first = true },
        nix = { 'alejandra' },
        sh = { 'shfmt' },
        bash = { 'shfmt' },
      },
      format_on_save = {
        timeout_ms = 500,
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

      -- Mason Handlers
      require('mason-lspconfig').setup {
        ensure_installed = { 'lua_ls', 'ts_ls', 'pyright', 'gopls', 'rust_analyzer' },
        handlers = {
          function(server_name)
            vim.lsp.enable(server_name)
          end,
        },
      }

      -- nixd is installed via Nix (not Mason); enable it directly.
      vim.lsp.enable 'nixd'
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

-- Highlight on Yank
vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})
