-- Import the wezterm module
local wezterm = require 'wezterm'
-- Creates a config object which we will be adding our config to
local config = wezterm.config_builder()

-- (This is where our config will go)
-- wezterm.log_info("hello world! my name is " .. wezterm.hostname())
-- Returns our config to be evaluated. We must always do this at the bottom of this file


local wezterm = require 'wezterm'
local config = wezterm.config_builder()


function docker_list()
  local docker_list = {}
  local docker_command = {
    '/usr/bin/env',
    'docker',
    'container',
    'ls',
    '--format',
    '{{.ID}}:{{.Names}}',
  }

  wezterm.log_info("Running Docker command: " .. table.concat(docker_command, " "))

  local success, stdout, stderr = wezterm.run_child_process(docker_command)

  for _, line in ipairs(wezterm.split_by_newlines(stdout)) do
    local id, name = line:match '(.-):(.+)'
    if id and name then
      docker_list[id] = name
    end
  end
  return docker_list
end

function make_docker_label_func(id)
  return function(name)
    local success, stdout, stderr = wezterm.run_child_process {
      'docker',
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

function make_docker_fixup_func(id)
  return function(cmd)
    cmd.args = cmd.args or { '/bin/sh' }
    local wrapped = {
      'docker',
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
