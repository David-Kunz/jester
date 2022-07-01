local global_options = {
  identifiers = {"test", "it"},
  terminal_cmd = ':vsplit | terminal',
  path_to_jest_debug = 'node_modules/.bin/jest',
  path_to_jest_run = 'jest',
  stringCharacters = {"'", '"'},
  expressions = {"call_expression"},
  prepend = {"describe"},
  regexStartEnd = true,
  escapeRegex = true,
  dap = {
    type = 'node2',
    request = 'launch',
    args = { "--no-cache" },
    sourceMaps = "inline",
    protocol = 'inspector',
    skipFiles = {'<node_internals>/**/*.js'},
    console = 'integratedTerminal',
    port = 9229,
    disableOptimisticBPs = true
  },
  cache = { -- used to store the information about the last run
    last_run = nil,
    last_used_term_buf = nil
  }
}

local ts_utils = require("nvim-treesitter.ts_utils")
local api = vim.api
local parsers = require "nvim-treesitter.parsers"

local function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

-- test
function get_node_at_cursor_or_above(winnr)
  winnr = winnr or 0
  local cursor = api.nvim_win_get_cursor(winnr)
  local cursor_range = { cursor[1] - 1, cursor[2] }

  local buf = vim.api.nvim_win_get_buf(winnr)
  local root_lang_tree = parsers.get_parser(buf)
  if not root_lang_tree then
    return
  end
  local root = ts_utils.get_root_for_position(cursor_range[1], cursor_range[2], root_lang_tree)

  if not root then
    return
  end

  -- Fix because comments won't yield the correct root
  local cur_cursor_line = cursor_range[1]
  while cur_cursor_line > 0 and root:type() ~= "program" do
    cur_cursor_line = cur_cursor_line - 1
    root = ts_utils.get_root_for_position(cur_cursor_line, 0, root_lang_tree)
  end

  local found = root:named_descendant_for_range(cursor_range[1], cursor_range[2], cursor_range[1], cursor_range[2])
  return found
end

local function find_nearest_node_obj(identifiers, prepend, expressions)
  local node = get_node_at_cursor_or_above()
  while node do
    local node_type = node:type()
    if has_value(expressions, node_type) then
      local node_text = vim.treesitter.query.get_node_text(node, 0)
      local identifier = string.match(node_text, "^[a-zA-Z0-9]*")
      if has_value(identifiers, identifier) then
        return { node = node, from_identifier = true }
      elseif has_value(prepend, identifier) then
        return { node = node, from_identifier = false }
      end
    end
    node = node:parent()
  end
end

local function prepend_node(current_node, prepend, expressions)
  local node = current_node:parent()
  if not node then
    return
  end
  while node do
    local node_type = node:type()
    if has_value(expressions, node_type) then
      local node_text = vim.treesitter.query.get_node_text(node, 0)
      local identifier = string.match(node_text, "^[a-zA-Z0-9]*")
      if has_value(prepend, identifier) then
        return node
      end
    end
    node = node:parent()
  end
end

local function remove_quotations(stringCharacters, str)
  local result = str
  for index, value in ipairs(stringCharacters) do
    result = result:gsub("^".. value, ""):gsub(value .. "$", "")
  end
  return result
end

local function get_identifier(node, stringCharacters)
    local child = node:child(1)
    local arguments = child:child(1)
    return remove_quotations(stringCharacters, vim.treesitter.query.get_node_text(arguments, 0))
end

local function regexEscape(str)
    return vim.fn.escape(str, '!"().+-*?^[]')
end


local function get_result(o)
  local result
  local nearest_node_obj = find_nearest_node_obj(o.identifiers, o.prepend, o.expressions)
  if not nearest_node_obj or not nearest_node_obj.node then
    print("Could not find any of the following: " .. table.concat(o.identifiers, ", ") .. ", " .. table.concat(o.prepend, ", "))
    return
  end
  local nearest_node = nearest_node_obj.node
  result = get_identifier(nearest_node, o.stringCharacters)
  if o.prepend then
    local node = prepend_node(nearest_node, o.prepend, o.expressions)
    while node do
      local parent_identifier = get_identifier(node, o.stringCharacters)
      result = parent_identifier .. " " .. result
      node = prepend_node(node, o.prepend, o.expressions)
    end
  end
  if o.escapeRegex then
    result = regexEscape(result)
  end
  if regexStartEnd then
    result = "^" .. result
    if nearest_node_obj.from_identifier then
      result = result .. "$"
    end
  end
  return result
end

local function debug_jest(o)
  local result = o.result
  local file = o.file
  local dap = require('dap')
  local type = o.dap.type
  local request = o.dap.request
  local cwd = o.dap.cwd
  if cwd == nil then
    cwd = vim.fn.getcwd()
  end
  local runtimeArgs = o.dap.runtimeArgs
  local path_to_jest = o.path_to_jest or o.path_to_jest_debug -- o.path_to_jest is only for backwards compatibility
  if runtimeArgs == nil then
    if result then
      runtimeArgs = {'--inspect-brk', '$path_to_jest', '--no-coverage', '-t', '$result', '--', '$file'}
    else
      runtimeArgs = {'--inspect-brk', '$path_to_jest', '--no-coverage', '--', '$file'}
    end
  end
  for key, value in pairs(runtimeArgs) do
    if string.match(value, "$result") then
      runtimeArgs[key] = value:gsub("$result", result)
    end
    if string.match(value, "$file") then
      runtimeArgs[key] = runtimeArgs[key]:gsub("$file", file)
    end
    if string.match(value, "$path_to_jest") then
      runtimeArgs[key] = value:gsub("$path_to_jest", path_to_jest)
    end
  end
  local config = vim.tbl_deep_extend('force', o.dap, { type = type, request = request, cwd = cwd, runtimeArgs = runtimeArgs })
  dap.run(config)
end

local function adjust_cmd(cmd, result, file)
  local adjusted_cmd = cmd
  if result and string.match(adjusted_cmd, "$result") then
      adjusted_cmd = cmd:gsub("$result", result)
  end
  if string.match(adjusted_cmd, "$file") then
    adjusted_cmd = adjusted_cmd:gsub("$file", file)
  end
  -- adjusted_cmd = adjusted_cmd:gsub("\\", "\\\\") -- needs double escaping
  return adjusted_cmd
end

local function run(o)
  local cmd
  local result
  local file
  if not o then
    o = {}
  end
  local options = vim.tbl_deep_extend('force', global_options, o)
  if options.run_last then
    if options.cache.last_run == nil then
      print("You must run some test(s) before")
      return
    end
    result = options.cache.last_run.result
    file = options.cache.last_run.file
    cmd = options.cache.last_run.cmd
  end
  if options.cmd then
    cmd = options.cmd
  end
  if cmd == nil then
    if options.run_file == true then
      cmd = (options.path_to_jest or options.path_to_jest_run) .. " -- $file"
    else
      cmd = (options.path_to_jest or options.path_to_jest_run) .. " -t '$result' -- $file"
    end
  end
  if file == nil then
    file = vim.fn.expand('%:p')
  end
  if not options.run_last and not options.run_file then
    result = get_result(options)
    if not result then return end
  end
  global_options.cache.last_run = { result = result, file = file, cmd = cmd }
  file = regexEscape(file)
  if options.func then
    return options.func(vim.tbl_deep_extend('force', options, { result = result, file = file }))
  end

  -- local adjusted_cmd = vim.fn.escape(vim.fn.escape(adjust_cmd(cmd, result, file), "\\"), '\\')
  local adjusted_cmd = vim.fn.escape(adjust_cmd(cmd, result, file), '\\')
  local terminal_cmd = options.terminal_cmd
  if global_options.cache.last_used_term_buf ~= nil and api.nvim_buf_is_valid(global_options.cache.last_used_term_buf) then
    local term_buf_win = false
    for _, win in pairs(api.nvim_tabpage_list_wins(0)) do
      if api.nvim_win_get_buf(win) == global_options.cache.last_used_term_buf then
        term_buf_win = true
        api.nvim_set_current_win(win)
      end
    end
    if not term_buf_win then
      api.nvim_buf_delete(global_options.cache.last_used_term_buf, {force=true})
      api.nvim_command(terminal_cmd)
      global_options.cache.last_used_term_buf = vim.api.nvim_get_current_buf()
    end
  else
    api.nvim_command(terminal_cmd)
    global_options.cache.last_used_term_buf = vim.api.nvim_get_current_buf()
  end
  local chan_id
  for _, chan in pairs(vim.api.nvim_list_chans()) do
    if chan.buffer == global_options.cache.last_used_term_buf then
      chan_id = chan.id
    end
  end
  vim.api.nvim_chan_send(chan_id, adjusted_cmd .. '\n')
end


-- options = vim.tbl_deep_extend('force', options, opts)

local function terminate(cb)
  local dap = require('dap')
  if dap.terminate then
    dap.terminate(nil, nil, function()
      cb()
    end)
  else
    dap.disconnect({ terminateDebuggee = true })
    dap.close()
  end
end

local function debug(o)
  if o == nil then
    o = {}
  end
  if o.func == nil then
    o.func = debug_jest
  end
  terminate(function()
    return run(o)
  end)
end

local function debug_last(o)
  -- dap.run_last() would also work, but we want freely exchange it with run
  if o == nil then
    o = {}
  end
  if o.func == nil then
    o.func = debug_jest
  end
  o.run_last = true
  terminate(function()
    return run(o)
  end)
end

local function run_file(o)
  if o == nil then
    o = {}
  end
  o.run_file = true
  return run(o)
end

local function debug_file(o)
  if o == nil then
    o = {}
  end
  if o.func == nil then
    o.func = debug_jest
  end
  o.run_file = true
  return run(o)
end

local function run_last(o)
  if o == nil then
    o = {}
  end
  o.run_last = true
  return run(o)
end

local function setup(o)
  global_options = vim.tbl_deep_extend('force', global_options, o)
end

return {
    setup = setup,
    run = run,
    run_last = run_last,
    run_file = run_file,
    debug = debug,
    debug_last = debug_last,
    debug_file = debug_file,
}
