# jester

A [Neovim](https://neovim.io/) plugin to easily run and debug [Jest](https://jestjs.io/) tests.

![jester](https://user-images.githubusercontent.com/1009936/125203183-ba543b00-e277-11eb-83a2-d7fe912cdec8.gif)

## Installation

Requirements: [Neovim](https://neovim.io/) >= 0.5, [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter), for debugging [nvim-dap](https://github.com/mfussenegger/nvim-dap)

Use your favorite package manager, e.g. [vim-plug](https://github.com/junegunn/vim-plug)
```
Plug 'David-Kunz/jester'
```

## Usage

### Run nearest test(s) under the cursor

```
:lua require"jester".run()
```

### Run current file

```
:lua require"jester".run_file()
```

### Run last test(s)

```
:lua require"jester".run_last()
```

### Debug nearest test(s) under the cursor

```
:lua require"jester".debug()
```

### Debug current file

```
:lua require"jester".debug_file()
```

### Debug last test(s)

```
:lua require"jester".debug_last()
```

## Options

You can specify options for all functions, these are the defaults:

```lua
{
  cmd = "jest -t '$result' -- $file", -- run command
  identifiers = {"test", "it"}, -- used to identify tests
  prepend = {"describe"}, -- prepend describe blocks
  expressions = {"call_expression"}, -- tree-sitter object used to scan for tests/describe blocks
  path_to_jest = './node_modules/bin/jest' -- used only for debugging
  dap = { -- debug adapter configuration
    type = 'node2',
    request = 'launch',
    cwd = vim.fn.getcwd(),
    runtimeArgs = {'--inspect-brk', 'node_modules/.bin/jest', '--no-coverage', '-t', '$result', '--', '$file'},
    sourceMaps = true,
    protocol = 'inspector',
    skipFiles = {'<node_internals>/**/*.js'},
    console = 'integratedTerminal',
    port = 9229
  }
}
```
