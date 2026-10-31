-- SPDX-FileCopyrightText: 2026 Andy Stewart (ManateeLazyCat)
-- SPDX-License-Identifier: GPL-3.0-only

-- Behavioural tests for placement and runtime subscription ownership.
local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."
local monitors, windows, moves, rules, subscriptions
local key = "omarchy_lcmd_window_rule"
hl = {
  get_monitors = function() return monitors end,
  get_windows = function() return windows end,
  window_rule = function(spec)
    local handle = { enabled = true, spec = spec }
    function handle:set_enabled(enabled) self.enabled = enabled end
    rules[#rules + 1] = handle
    return handle
  end,
  on = function(event, callback)
    assert(event == "window.open")
    local subscription = { active = true, callback = callback }
    function subscription:remove() self.active = false end
    subscriptions[#subscriptions + 1] = subscription
    return subscription
  end,
  dsp = { window = { move = function(args) return args end } },
  dispatch = function(args) moves[#moves + 1] = args end,
}
local module = dofile(root .. "/rules.lua")
local function monitor(id, workspace)
  return { id = id, dpms_status = true, is_mirror = false, active_workspace = { id = workspace } }
end
local function window(address, workspace, class, title)
  return { address = address, workspace = { id = workspace }, mapped = true,
    class = class or "app", initial_title = title or "App" }
end
local function reset()
  _G[key] = nil
  monitors = { monitor(0, 7), monitor(1, 1), monitor(2, 10) }
  local wechat = window("wechat", 7, "wechat", "微信 on cloud.lazycat.catlink.wechat-cde")
  windows = { wechat, window("browser", 7), window("terminal", 10) }
  moves, rules, subscriptions = {}, {}, {}
  return wechat
end
local count = 0
local function test(name, fn)
  reset()
  fn()
  count = count + 1
  print("PASS " .. name)
end
local function placement(name, setup, expected)
  test(name, function()
    local wechat = windows[1]
    setup(wechat)
    module.enable("test")
    subscriptions[1].callback(wechat)
    assert(#moves == (expected and 1 or 0), "unexpected move count")
    if expected then
      assert(moves[1].workspace.id == expected, "wrong destination")
      assert(moves[1].window == wechat and moves[1].follow == false, "wrong window/focus")
    end
  end)
end
placement("move only WeChat to an already-visible empty screen", function() end, 1)
placement("single display retains default position", function() monitors = { monitors[1] } end)
placement("no empty screen retains default position", function() windows[#windows + 1] = window("other", 1) end)
placement("already empty current screen stays in place", function(w) w.workspace.id = 1 end)
placement("temporary launcher does not occupy a screen", function()
  windows[#windows + 1] = window("launcher", 1, "lzc-client-desktop", "Remote WeChat-manateelazycat")
end, 1)
placement("pinned windows occupy their screen", function()
  local pinned = window("pinned", 9); pinned.pinned = true; pinned.monitor = monitors[2]
  windows[#windows + 1] = pinned
end)
placement("skip a monitor with a special workspace", function() monitors[2].active_special_workspace = { id = -99 } end)
placement("skip powered-off monitor", function() monitors[2].dpms_status = false end)
placement("skip mirrored monitor", function() monitors[2].is_mirror = true end)
placement("do not relocate ordinary apps", function(w) w.class = "browser" end)
placement("do not relocate local WeChat", function(w) w.initial_title = "微信" end)
placement("hidden group members still occupy a workspace", function()
  local grouped = window("grouped", 1); grouped.hidden = true; windows[#windows + 1] = grouped
end)
placement("ignore windows on inactive workspaces", function() windows[#windows + 1] = window("inactive", 2) end, 1)
placement("do not count unmapped windows", function()
  local old = window("old", 1); old.mapped = false; windows[#windows + 1] = old
end, 1)
placement("choose deterministic monitor order", function()
  monitors = { monitors[3], monitors[2], monitors[1] }; windows[3].workspace.id = 11
end, 1)
test("two named rules cover app workspaces and remote activation", function()
  module.enable("test")
  assert(#rules == 2)
  assert(rules[1].spec.workspace == "emptyn")
  assert(rules[1].spec.match.initial_title == "negative:^Remote WeChat(-.*)?$")
  assert(rules[2].spec.no_initial_focus and rules[2].spec.focus_on_activate == false)
  assert(rules[2].spec.suppress_event == "activate activatefocus")
end)
test("repeated enable is idempotent", function()
  module.enable("one"); module.enable("one")
  assert(#rules == 2 and #subscriptions == 1)
end)
test("replacement instance retires the old listener", function()
  module.enable("one"); module.enable("two")
  assert(#rules == 2 and not subscriptions[1].active and subscriptions[2].active)
  assert(not module.disable("one"))
  assert(rules[1].enabled and subscriptions[2].active)
end)
test("disable removes subscription and rules", function()
  module.enable("one")
  assert(module.disable("one"))
  assert(not rules[1].enabled and not rules[2].enabled and not subscriptions[1].active)
  subscriptions[1].callback(windows[1])
  assert(#moves == 0)
  module.enable("two")
  assert(#rules == 2 and rules[1].enabled and subscriptions[2].active)
end)
test("fresh compositor state rebuilds the runtime rules", function()
  module.enable("one")
  _G[key] = nil -- config reload destroys the Lua state and subscriptions
  module.enable("one")
  assert(#rules == 4 and _G[key].enabled)
end)
test("launcher recognition is limited to the documented title", function()
  assert(module.is_launcher(window("a", 1, "lzc-client-desktop", "Remote WeChat")))
  assert(not module.is_launcher(window("b", 1, "lzc-client-desktop", "Remote WeChat Settings")))
  assert(not module.is_launcher(window("c", 1, "browser", "Remote WeChat")))
end)
print("Passed " .. count .. " scenarios")
