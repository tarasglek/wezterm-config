-- Import the wezterm module
local wezterm = require 'wezterm'
-- Creates a config object which we will be adding our config to
local config = wezterm.config_builder()

-- (This is where our config will go)
-- wezterm.log_info("hello world! my name is " .. wezterm.hostname())
-- Returns our config to be evaluated. We must always do this at the bottom of this file


local wezterm = require 'wezterm'
local config = wezterm.config_builder()


-- Utility function to run a command via the default shell
function run_via_default_shell(command)
  local shell = os.getenv("SHELL") or "/bin/bash"
  local shell_command = { shell, '-l', '-c', command }

  wezterm.log_info("Running command via shell: " .. table.concat(shell_command, " "))

  local success, stdout, stderr = wezterm.run_child_process(shell_command)
  if not success then
    error("Failed to run command via shell: " .. stderr)
  end
  return success, stdout, stderr
end

-- Utility function to find the absolute path of a command using 'which'
function which(command)
  local which_command = 'which ' .. command
  local success, stdout, stderr = run_via_default_shell(which_command)
  if success and stdout then
    return stdout:match("^%s*(.-)%s*$") -- Trim any leading/trailing whitespace
  else
    error("Command not found: " .. command)
  end
end

-- Function to list Docker containers
function docker_list()
  local docker_list = {}
  local docker_path = which('docker')
  local docker_command = docker_path .. ' container ls --format "{{.ID}}:{{.Names}}-{{.Image}}"'

  wezterm.log_info("Running Docker command: " .. docker_command)

  local success, stdout, stderr = run_via_default_shell(docker_command)

  for _, line in ipairs(wezterm.split_by_newlines(stdout)) do
    local id, name = line:match '(.-):(.+)'
    if id and name then
      docker_list[id] = name
    end
  end
  return docker_list
end

-- Function to create a Docker label function
function make_docker_label_func(id)
  local docker_path = which('docker')
  return function(name)
    local success, stdout, stderr = wezterm.run_child_process {
      docker_path,
      'inspect',
      '--format',
      '{{.State.Running}}',
      id,
    }
    local running = stdout == 'true\n'
    local color = running and 'Green' or 'Red'
    return wezterm.format {
      { Foreground = { AnsiColor = color } },
      { Text = 'docker container named ' .. name },
    }
  end
end

-- Function to create a Docker fixup function
function make_docker_fixup_func(id)
  local docker_path = which('docker')
  return function(cmd)
    cmd.args = cmd.args or { '/bin/sh' }
    local wrapped = {
      docker_path,
      'exec',
      '-it',
      id,
    }
    for _, arg in ipairs(cmd.args) do
      table.insert(wrapped, arg)
    end

    cmd.args = wrapped
    return cmd
  end
end

function compute_exec_domains()
  local exec_domains = {}
  for id, name in pairs(docker_list()) do
    table.insert(
      exec_domains,
      wezterm.exec_domain(
        'docker:' .. name,
        make_docker_fixup_func(id),
        make_docker_label_func(id)
      )
    )
  end
  return exec_domains
end

config.exec_domains = compute_exec_domains()

return config
