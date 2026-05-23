-- anime4k-auto.lua
-- Automatically activates Anime4K Mode A (HQ) shaders when the video path
-- contains "/JP/Media/Anime" or "/JP/Media/Cartoon", mirroring CTRL+1.
--
-- INSTALLATION:
--   Place this file in: ~/.config/mpv/scripts/anime4k-auto.lua

-- ─── Config ──────────────────────────────────────────────────────────────────

local TRIGGERS = {
	"/JP/Media/Anime",
	"/JP/Media/Cartoon",
}

-- Exact shader string used by CTRL+1 in your input.conf
local SHADER_STRING = "~~/shaders/Anime4K_Clamp_Highlights.glsl"
	.. ":~~/shaders/Anime4K_Restore_CNN_VL.glsl"
	.. ":~~/shaders/Anime4K_Upscale_CNN_x2_VL.glsl"
	.. ":~~/shaders/Anime4K_AutoDownscalePre_x2.glsl"
	.. ":~~/shaders/Anime4K_AutoDownscalePre_x4.glsl"
	.. ":~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl"

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function matches_trigger(path)
	if not path then
		return false
	end
	for _, trigger in ipairs(TRIGGERS) do
		if path:find(trigger, 1, true) then
			return true
		end
	end
	return false
end

-- ─── Main hook ───────────────────────────────────────────────────────────────

mp.register_event("file-loaded", function()
	local path = mp.get_property("path")

	if matches_trigger(path) then
		mp.commandv("change-list", "glsl-shaders", "set", SHADER_STRING)
		mp.osd_message("Anime4K: Mode A (HQ)", 3)
		mp.msg.info("[anime4k-auto] Shaders activated for: " .. path)
	else
		mp.commandv("change-list", "glsl-shaders", "clr", "")
		mp.msg.info("[anime4k-auto] Shaders cleared for: " .. (path or "nil"))
	end
end)
