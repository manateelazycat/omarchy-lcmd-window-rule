-- SPDX-FileCopyrightText: 2026 Andy Stewart (ManateeLazyCat)
-- SPDX-License-Identifier: GPL-3.0-only

-- Runtime-only rules: the Omarchy service owns their lifetime.
local M = {}
local VERSION = "0.1.1"
local KEY = "omarchy_lcmd_window_rule"
local REMOTE_TITLE = "微信 on cloud.lazycat.catlink.wechat-cde"

function M.is_launcher(window)
  local title = window.initial_title or ""
  return window.class == "lzc-client-desktop"
    and (title == "Remote WeChat" or title:match("^Remote WeChat%-") ~= nil)
end

function M.is_remote_wechat(window)
  if window == nil then return false end
  local tags = window.tags or {}
  if type(tags) == "string" then
    local parsed = {}
    for tag in tags:gmatch("[^,%s]+") do parsed[#parsed + 1] = tag end
    tags = parsed
  end
  for _, tag in ipairs(tags) do
    if tag == "omarchy-startup-map" or tag == "omarchy-startup-map*" then return false end
  end
  return window.class == "wechat" and window.initial_title == REMOTE_TITLE
end

function M.choose_workspace(window)
  local monitors = {}
  for _, monitor in ipairs(hl.get_monitors()) do
    if monitor.dpms_status and not monitor.is_mirror then
      monitors[#monitors + 1] = monitor
    end
  end
  if #monitors < 2 then return nil end

  table.sort(monitors, function(a, b) return a.id < b.id end)
  local windows = hl.get_windows()
  local target
  for _, monitor in ipairs(monitors) do
    local workspace = monitor.active_workspace
    if workspace and not monitor.active_special_workspace then
      local occupied = false
      for _, other in ipairs(windows) do
        -- Ignore only the opening window and the short-lived connecting page.
        if other.mapped and other.address ~= window.address and not M.is_launcher(other) then
          if (other.workspace and other.workspace.id == workspace.id)
            or (other.pinned and other.monitor and other.monitor.id == monitor.id) then
            occupied = true
            break
          end
        end
      end
      if not occupied then
        -- Keep its existing position when it already has an empty screen.
        if window.workspace and window.workspace.id == workspace.id then return workspace end
        target = target or workspace
      end
    end
  end
  return target
end

function M.disable(owner)
  local state = rawget(_G, KEY)
  if not state or state.owner ~= owner then return false end
  if state.subscription then
    state.subscription:remove()
    state.subscription = nil
  end
  for _, rule in ipairs(state.rules) do rule:set_enabled(false) end
  state.enabled = false
  state.owner = nil
  return true
end

function M.enable(owner)
  assert(type(owner) == "string" and owner ~= "", "a service owner token is required")
  local state = rawget(_G, KEY)
  if state and state.enabled and state.owner == owner and state.version == VERSION then return state end
  if state then state.disable(state.owner) end
  if not state or state.version ~= VERSION then
    state = { version = VERSION, enabled = false, rules = {}, moves = 0 }
    _G[KEY] = state
    state.rules[1] = hl.window_rule({
      name = "lcmd-app-workspaces-" .. VERSION,
      match = {
        class = "^lzc-client-desktop$",
        initial_title = "negative:^Remote WeChat(-.*)?$",
      },
      workspace = "emptyn",
    })
    state.rules[2] = hl.window_rule({
      name = "lcmd-remote-wechat-focus-" .. VERSION,
      match = {
        class = "^wechat$",
        initial_title = "^微信 on cloud\\.lazycat\\.catlink\\.wechat-cde$",
      },
      no_initial_focus = true,
      focus_on_activate = false,
      suppress_event = "activate activatefocus",
    })
  end
  state.owner = owner
  state.disable = M.disable
  for _, rule in ipairs(state.rules) do rule:set_enabled(true) end
  state.subscription = hl.on("window.open", function(window)
    if not state.enabled or not M.is_remote_wechat(window) then return end
    local workspace = M.choose_workspace(window)
    if workspace and (not window.workspace or workspace.id ~= window.workspace.id) then
      hl.dispatch(hl.dsp.window.move({ window = window, workspace = workspace, follow = false }))
      state.moves = state.moves + 1
      state.last_placement = { address = window.address, workspace = workspace.id }
    end
  end)
  state.enabled = true
  return state
end

return M
