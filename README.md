# jester

A Neovim plugin to easily run and debug Jest tests.

## Installation

Requirements: Neovim >= 0.5, [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter), for debugging [`nvim-dap`](https://github.com/mfussenegger/nvim-dap)

```
Plug 'David-Kunz/jester'
```

## Usage

### Run nearest test(s) under the cursor

```
:lua require"jester".run()
```

### Debug nearest test under the cursor

```
:lua require"jester".debug()
```

## Options

These defaults can be overwritten:

```lua
{
  cmd = "jest -t '$result' -- $file", -- run command
  identifiers = {"test", "it"}, -- used to identify tests
  prepend = {"describe"}, -- prepend describe blocks
  expressions = {"call_expression"}, -- used to scan for tests/describe blocks
  dap = {
    type = 'node2',
    request = 'launch',
    cwd = vim.fn.getcwd(),
    runtimeArgs = {'--inspect-brk', 'node_modules/.bin/jest', '--no-coverage', '-t', '$result', '--', '$file'},
  }
}
```

These settings might change in the future.


