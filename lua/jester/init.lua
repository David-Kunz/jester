local ts_utils = require("nvim-treesitter.ts_utils")

local last_run

local function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

local function find_nearest_node_obj(identifiers, prepend, expressions)
  local node = ts_utils.get_node_at_cursor()
  while node do
    local node_type = node:type()
    if has_value(expressions, node_type) then
      local node_text =ts_utils.get_node_text(node)
      local identifier = string.match(node_text[1], "^[a-zA-Z0-9]*")
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
      local node_text =ts_utils.get_node_text(node)
      local identifier = string.match(node_text[1], "^[a-zA-Z0-9]*")
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
    return remove_quotations(stringCharacters, ts_utils.get_node_text(arguments)[1])
end

local function regexEscape(str, doubleQuote)
		return str:gsub("[%(%)%.%%%+%-%*%?%[%^%$%]]", "%\\%1")
end

local function get_result(o)
  local result
  local identifiers = o.identifiers
  if identifiers == nil then
    identifiers = {"test", "it"}
  end
  local stringCharacters = o.stringCharacters
  if stringCharacters == nil then
    stringCharacters = {"'", '"'}
  end
  local expressions = o.expressions
  if expressions == nil then
    expressions = {"call_expression"}
  end
  local prepend = o.prepend
  if prepend == nil then
    prepend = {"describe"}
  end
  local regexStartEnd = o.regexStartEnd
  if regexStartEnd == nil then
    regexStartEnd = true
  end
  local escapeRegex = o.escapeRegex
  if escapeRegex == nil then
    escapeRegex = true
  end
  local nearest_node_obj = find_nearest_node_obj(identifiers, prepend, expressions)
  local nearest_node = nearest_node_obj.node
  if not nearest_node then
    print("Could not find any of the following: " .. table.concat(identifiers, ", ") .. ", " .. table.concat(prepend, ", "))
    return
  end
  result = get_identifier(nearest_node, stringCharacters)
  if prepend then
    local node = prepend_node(nearest_node, prepend, expressions)
    while node do
      local parent_identifier = get_identifier(node, stringCharacters)
      result = parent_identifier .. " " .. result
      node = prepend_node(node, prepend, expressions)
    end
  end
  if escapeRegex then
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
  if o.dap == nil then
    o.dap = {}
  end
  local type = o.dap.type
  if type == nil then
    type = 'node2'
  end
  local request = o.dap.request
  if request == nil then
    request = 'launch'
  end
  local cwd = o.dap.cwd
  if cwd == nil then
    cwd = vim.fn.getcwd()
  end
  local runtimeArgs = o.dap.runtimeArgs
  local path_to_jest = o.path_to_jest or 'node_modules/.bin/jest'
  if runtimeArgs == nil then
    if result then
      runtimeArgs = { "--inspect-brk", path_to_jest, "--no-coverage", "-t", "$result", "--", "$file" }
    else
      runtimeArgs = { "--inspect-brk", path_to_jest, "--no-coverage", "--", "$file" }
    end
    local prefixed = {}
    if o.yarn then
      prefixed = { "run" }
    end
    -- Adds a prefix to a table
    local prefix = function(toPrefix)
      return function(coreTable)
        for _, item in ipairs(coreTable) do
          table.insert(toPrefix, item)
        end
        return prefixed
      end
    end
    runtimeArgs = prefix(prefixed)(runtimeArgs)
  end
  for key, value in pairs(runtimeArgs) do
    if string.match(value, "$result") then
      runtimeArgs[key] = value:gsub("$result", result)
    end
    if string.match(value, "$file") then
      runtimeArgs[key] = runtimeArgs[key]:gsub("$file", file)
    end
  end
  local sourceMaps = o.dap.sourceMaps
  if sourceMaps == nil then
    sourceMaps = "inline"
  end
  local args = o.dap.args
  if args == nil then
    args = { "--no-cache" }
  end
  local protocol = o.dap.protocol
  if protocol == nil then
    protocol = 'inspector'
  end
  local skipFiles = o.dap.skipFiles
  if skipFiles == nil then
    skipFiles = {'<node_internals>/**/*.js'}
  end
  local console = o.dap.console
  if console == nil then
    console = 'integratedTerminal'
  end
  local port = o.dap.port
  if port == nil then
    port = 9229
  end
  local disableOptimisticBPs = o.dap.disableOptimisticBPs
  if disableOptimisticBPs == nil then
    disableOptimisticBPs = true
  end
  dap.run({
        type = type,
        request = request,
        cwd = cwd,
        runtimeArgs = runtimeArgs,
        args = args,
        sourceMaps = sourceMaps,
        protocol = protocol,
        skipFiles = skipFiles,
        console = console,
        port = port,
        disableOptimisticBPs = disableOptimisticBPs
      })
end

local function adjust_cmd(cmd, result, file)
  local adjusted_cmd = cmd
  if string.match(adjusted_cmd, "$result") then
      adjusted_cmd = cmd:gsub("$result", result)
  end
  if string.match(adjusted_cmd, "$file") then
    adjusted_cmd = adjusted_cmd:gsub("$file", file)
  end
  adjusted_cmd = adjusted_cmd:gsub("\\", "\\\\") -- needs double escaping
  return adjusted_cmd
end

local function run(o)
  local cmd
  local result
  local file
  if not o then
    o = {}
  end
  if o.run_last then
    if last_run == nil then
      print("You must run some test(s) before")
      return
    end
    result = last_run.result
    file = last_run.file
    cmd = last_run.cmd
  end
  if o.cmd then
    cmd = o.cmd
  end
  if cmd == nil then
    if o.run_file == true then
      cmd = "jest -- $file"
    else
      cmd = "jest -t '$result' -- $file"
    end
  end
  if file == nil then
    file = vim.fn.expand('%:p')
  end
  if not o.run_last and not o.run_file then
    result = get_result(o)
  end
  last_run = { result = result, file = file, cmd = cmd }
  if o.func then
    return o.func({ result = result, file = file, dap = o.dap, path_to_jest = o.path_to_jest, yarn = o.yarn })
  end
  local adjusted_cmd = adjust_cmd(cmd, result, file)
  local terminal_cmd = o.terminal_cmd or ':vsplit | terminal'
  vim.cmd(terminal_cmd)
  local command = ':call jobsend(b:terminal_job_id, "' .. adjusted_cmd .. '\\n")'
  vim.cmd(command)
end


local function terminate(cb)
  local dap = require('dap')
  if dap.terminate then
    dap.terminate({}, {}, function()
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

return {
    run = run,
    run_last = run_last,
    run_file = run_file,
    debug = debug,
    debug_last = debug_last,
    debug_file = debug_file
}
