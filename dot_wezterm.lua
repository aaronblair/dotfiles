-- Pull in the wezterm API
local wezterm = require("wezterm")
local act = wezterm.action

-- This will hold the configuration.
local config = wezterm.config_builder()

-- General
config.automatically_reload_config = true
config.enable_scroll_bar = true
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.scrollback_lines = 100000

-- Visual Bell
config.visual_bell = {
	fade_in_function = "Constant",
	fade_in_duration_ms = 0,
	fade_out_function = "EaseOut",
	fade_out_duration_ms = 300,
}
config.audible_bell = "Disabled"

-- Fonts
config.font = wezterm.font("MesloLGS NF")
config.color_scheme = "Catppuccin Macchiato"
config.font_size = 12.0

config.adjust_window_size_when_changing_font_size = false

-- Workable Tomorrow Night Eighties theme
-- local TMEcolor = wezterm.color.get_builtin_schemes()["Tomorrow Night Eighties"]
-- TMEcolor.ansi[1] = "#333333"
-- TMEcolor.brights[1] = "#3d3d3d"
-- config.color_schemes = {
-- 	["TME"] = TMEcolor,
-- }
-- config.color_scheme = "TME"

-- Tab Bar Config
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = false
config.switch_to_last_active_tab_when_closing_tab = true
config.tab_max_width = 32

-- -- Setup muxing by default
-- config.unix_domains = {
-- 	{
-- 		name = "unix",
-- 	},
-- }
-- config.default_gui_startup_args = { "connect", "unix" }

-- -- Used for smart-splits.vim for seamless panel moves
-- local function is_vim(pane)
-- 	-- this is set by the plugin, and unset on ExitPre in Neovim
-- 	return pane:get_user_vars().IS_NVIM == "true"
-- end
--
-- local direction_keys = {
-- 	h = "Left",
-- 	j = "Down",
-- 	k = "Up",
-- 	l = "Right",
-- }
--
-- local function split_nav(resize_or_move, key)
-- 	return {
-- 		key = key,
-- 		mods = resize_or_move == "resize" and "META" or "CTRL",
-- 		action = wezterm.action_callback(function(win, pane)
-- 			if is_vim(pane) then
-- 				-- pass the keys through to vim/nvim
-- 				win:perform_action({
-- 					SendKey = { key = key, mods = resize_or_move == "resize" and "META" or "CTRL" },
-- 				}, pane)
-- 			else
-- 				if resize_or_move == "resize" then
-- 					win:perform_action({ AdjustPaneSize = { direction_keys[key], 3 } }, pane)
-- 				else
-- 					win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
-- 				end
-- 			end
-- 		end),
-- 	}
-- end
--
-- -- Helper function to passthrough bound shortcuts using the leader key
-- local function send_key(key, mod)
-- 	return {
-- 		key = key,
-- 		mods = "LEADER|" .. mod,
-- 		action = wezterm.action.SendKey({ key = key, mods = mod }),
-- 	}
-- end

-- Custom Key Bindings
-- config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 2000 }
config.keys = {
	-- -- move to panes
	-- split_nav("move", "h"),
	-- split_nav("move", "j"),
	-- split_nav("move", "k"),
	-- split_nav("move", "l"),
	-- -- resize panes
	-- split_nav("resize", "h"),
	-- split_nav("resize", "j"),
	-- split_nav("resize", "k"),
	-- split_nav("resize", "l"),
	-- -- allow typing the original shortcut using the leader key
	-- send_key("h", "CTRL"),
	-- send_key("j", "CTRL"),
	-- send_key("k", "CTRL"),
	-- send_key("l", "CTRL"),
	-- send_key("h", "META"),
	-- send_key("j", "META"),
	-- send_key("k", "META"),
	-- send_key("l", "META"),
	-- -- pass through leader when needed - working with old TMUX
	-- {
	-- 	key = "a",
	-- 	mods = "LEADER|CTRL",
	-- 	action = act.SendKey({ key = "a", mods = "CTRL" }),
	-- },
	-- -- switch back to most recent tab
	-- {
	-- 	key = "a",
	-- 	mods = "LEADER",
	-- 	action = wezterm.action.ActivateLastTab,
	-- },
	-- -- toggle pane zoom
	-- {
	-- 	key = "z",
	-- 	mods = "LEADER",
	-- 	action = act.TogglePaneZoomState,
	-- },
	-- -- pane select shortcut
	-- {
	-- 	key = "q",
	-- 	mods = "LEADER",
	-- 	action = act.PaneSelect,
	-- },
	-- -- pane select and swap with active
	-- {
	-- 	key = "Q",
	-- 	mods = "LEADER|SHIFT",
	-- 	action = act.PaneSelect({
	-- 		mode = "SwapWithActiveKeepFocus",
	-- 	}),
	-- },
	-- -- fuzzy search workspaces
	-- {
	-- 	key = "w",
	-- 	mods = "LEADER",
	-- 	action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }),
	-- },
	-- vertical split
	{
		mods = "CTRL",
		key = "-",
		action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
	{
		mods = "CTRL",
		key = "\\",
		action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	-- split pane from top level - disabled as there is a bug with it:
	-- https://github.com/wez/wezterm/issues/2579
	-- {
	-- 	mods = "LEADER|SHIFT",
	-- 	key = "_",
	-- 	action = act.SplitPane({
	-- 		direction = "Down",
	-- 		size = { Percent = 50 },
	-- 		top_level = true,
	-- 	}),
	-- },
	-- {
	-- 	mods = "LEADER|SHIFT",
	-- 	key = "|",
	-- 	action = act.SplitPane({
	-- 		direction = "Right",
	-- 		size = { Percent = 50 },
	-- 		top_level = true,
	-- 	}),
	-- },

	--  {
	-- 	key = "[",
	-- 	mods = "LEADER",
	-- 	action = act.ActivateCopyMode,
	-- },
	-- {
	-- 	key = ",",
	-- 	mods = "LEADER",
	-- 	action = act.PromptInputLine({
	-- 		description = "Enter new name for tab",
	-- 		action = wezterm.action_callback(function(window, pane, line)
	-- 			if line then
	-- 				window:active_tab():set_title(line)
	-- 			end
	-- 		end),
	-- 	}),
	-- },
	-- {
	-- 	key = "n",
	-- 	mods = "LEADER",
	-- 	action = act.ActivateTabRelative(1),
	-- },
	-- {
	-- 	key = "p",
	-- 	mods = "LEADER",
	-- 	action = act.ActivateTabRelative(-1),
	-- },
}

-- -- Insert standard tab shortcuts w/ leader. Similar to in TMUX.
-- for i = 1, 9 do
-- 	table.insert(config.keys, {
-- 		key = tostring(i),
-- 		mods = "LEADER",
-- 		action = wezterm.action.ActivateTab(i - 1),
-- 	})
-- end

-- and finally, return the configuration to wezterm
return config
