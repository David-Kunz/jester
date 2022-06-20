# jester

A [Neovim](https://neovim.io/) plugin to easily run and debug [Jest](https://jestjs.io/) tests.

![jester](https://user-images.githubusercontent.com/1009936/125203183-ba543b00-e277-11eb-83a2-d7fe912cdec8.gif)

## Installation

Requirements: [Neovim](https://neovim.io/) >= 0.5, [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter), for debugging [nvim-dap](https://github.com/mfussenegger/nvim-dap)
Make sure that the JavaScript/TypeScript parser for [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) is installed and enabled.

For [vim-plug](https://github.com/junegunn/vim-plug):
```
Plug 'David-Kunz/jester'
```
For [packer](https://github.com/wbthomason/packer.nvim):
```
use 'David-Kunz/jester'
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

You can specify global options using the `setup` function.

Example:

```lua
require("jester").setup({
  dap = {
    console = "externalTerminal"
  }
})
```

These are the defaults:

```lua
{
  cmd = "jest -t '$result' -- $file", -- run command
  identifiers = {"test", "it"}, -- used to identify tests
  prepend = {"describe"}, -- prepend describe blocks
  expressions = {"call_expression"}, -- tree-sitter object used to scan for tests/describe blocks
  path_to_jest_run = 'jest' -- used to run tests
  path_to_jest_debug = './node_modules/bin/jest' -- used for debugging
  terminal_cmd = ":vsplit | terminal" -- used to spawn a terminal for running tests, for debugging refer to nvim-dap's config
  dap = { -- debug adapter configuration
    type = 'node2',
    request = 'launch',
    cwd = vim.fn.getcwd(),
    runtimeArgs = {'--inspect-brk', '$path_to_jest', '--no-coverage', '-t', '$result', '--', '$file'},
    args = { '--no-cache' },
    sourceMaps = 'inline',
    protocol = 'inspector',
    skipFiles = {'<node_internals>/**/*.js'},
    console = 'integratedTerminal',
    port = 9229,
    disableOptimisticBPs = true
  }
}
```

You can also overwrite the options for each function call, for example

```lua
:lua require"jester".debug({ dap = { console = "externalTerminal" } })
```
