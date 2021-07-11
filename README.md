# jester

A [Neovim](https://neovim.io/) plugin to easily run and debug [Jest](https://jestjs.io/) tests.

![jester](https://user-images.githubusercontent.com/1009936/125203183-ba543b00-e277-11eb-83a2-d7fe912cdec8.gif)

## Installation

Requirements: Neovim >= 0.5, [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter), for debugging [nvim-dap](https://github.com/mfussenegger/nvim-dap)

```
Plug 'David-Kunz/jester'
```

## Usage

### Run nearest test(s) under the cursor

```
:lua require"jester".run()
```

### Debug nearest test(s) under the cursor

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
    sourceMaps = true,
    protocol = 'inspector',
    skipFiles = {'<node_internals>/**/*.js'},
    console = 'integratedTerminal',
    port = 9229
  }
}
```

These settings might change in the future.


