-- sub-copy.lua
--
-- Automatically copies primary subtitle lines to clipboard.
-- Supports Linux clipboard systems:
--
--   - xclip (X11)
--   - wl-copy (Wayland)
--
-- Features:
--
-- - Strips ASS/SSA formatting tags
-- - Strips HTML formatting tags
-- - Skips duplicate subtitle lines
--
-- Controls:
--
-- n : prepend previous subtitle line
-- N : remove oldest prepended line
-- m : reset clipboard to anchor line
-- M : toggle anchor exclusion
--
-- OSD behavior:
--
-- - prepend actions show for 10 seconds
-- - reset action shows for 3 seconds

-------------------------------------------------------------------------------
-- Config
-------------------------------------------------------------------------------

local HISTORY_LIMIT       = 10
local OSD_PREPEND_TIMEOUT = 10
local OSD_RESET_TIMEOUT   = 3

local ANCHOR_GLYPH = "󰀱"

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

-- Rolling subtitle history
-- Newest line is at #history
local history = {}

-- Current anchor subtitle
local anchor = ""

-- Number of prepended lines
local prepend_count = 0

-- Whether anchor is excluded
local anchor_excluded = false

-- OSD timer handle
local osd_timer = nil

-------------------------------------------------------------------------------
-- Formatting cleanup
-------------------------------------------------------------------------------

local function strip_ass(text)
    return text:gsub("{[^}]*}", "")
end

local function strip_html(text)
    return text:gsub("<[^>]*>", "")
end

local function normalize_whitespace(text)
    text = text:gsub("\\N", " ")
    text = text:gsub("\\n", " ")
    text = text:gsub("%s+", " ")

    return text:match("^%s*(.-)%s*$")
end

local function clean(text)
    return normalize_whitespace(
        strip_html(
            strip_ass(text)
        )
    )
end

-------------------------------------------------------------------------------
-- Clipboard
-------------------------------------------------------------------------------

local function copy_to_clipboard(text)
    local escaped =
        text:gsub("'", "'\\''")

    local cmd

    if os.getenv("WAYLAND_DISPLAY") then
        cmd =
            ("printf '%%s' '%s' | wl-copy")
            :format(escaped)
    else
        cmd =
            ("printf '%%s' '%s' | xclip -selection clipboard")
            :format(escaped)
    end

    local ok = os.execute(cmd)

    if not ok then
        mp.msg.warn(
            "sub-copy: clipboard command failed. " ..
            "Is xclip/wl-copy installed?"
        )
    end
end

-------------------------------------------------------------------------------
-- OSD
-------------------------------------------------------------------------------

local function dismiss_osd()
    mp.osd_message("", 0)

    if osd_timer then
        osd_timer:kill()
        osd_timer = nil
    end
end

local function show_osd(text, duration)

    if osd_timer then
        osd_timer:kill()
        osd_timer = nil
    end

    mp.osd_message(text, duration)

    osd_timer =
        mp.add_timeout(duration, function()
            osd_timer = nil
        end)
end

-------------------------------------------------------------------------------
-- Selection building
-------------------------------------------------------------------------------

local function build_selection()
    local available = #history
    local parts = {}

    ---------------------------------------------------------------------------
    -- Prepended lines
    ---------------------------------------------------------------------------

    for i = available - prepend_count + 1, available do
        table.insert(parts, history[i])
    end

    ---------------------------------------------------------------------------
    -- Anchor
    ---------------------------------------------------------------------------

    if not anchor_excluded then
        table.insert(parts, anchor)
    end

    return table.concat(parts, " ")
end

-------------------------------------------------------------------------------
-- OSD label builder
-------------------------------------------------------------------------------

local function build_osd_label()

    ---------------------------------------------------------------------------
    -- Anchor excluded
    ---------------------------------------------------------------------------

    if anchor_excluded then

        if prepend_count == 1 then
            return (
                "Sub-Copy: 1 prev (no %s)"
            ):format(ANCHOR_GLYPH)
        end

        return (
            "Sub-Copy: %d prev (no %s)"
        ):format(prepend_count, ANCHOR_GLYPH)
    end

    ---------------------------------------------------------------------------
    -- Anchor included
    ---------------------------------------------------------------------------

    if prepend_count == 0 then
        return (
            "Sub-Copy: %s"
        ):format(ANCHOR_GLYPH)

    elseif prepend_count == 1 then
        return (
            "Sub-Copy: %s + 1 prev"
        ):format(ANCHOR_GLYPH)
    end

    return (
        "Sub-Copy: %s + %d prev"
    ):format(
        ANCHOR_GLYPH,
        prepend_count
    )
end

-------------------------------------------------------------------------------
-- Subtitle observer
-------------------------------------------------------------------------------

local function on_sub_text_changed(_, text)

    ---------------------------------------------------------------------------
    -- Ignore empty subtitle events
    ---------------------------------------------------------------------------

    if not text or text == "" then
        return
    end

    local cleaned = clean(text)

    ---------------------------------------------------------------------------
    -- Ignore duplicates
    ---------------------------------------------------------------------------

    if cleaned == "" or cleaned == anchor then
        return
    end

    ---------------------------------------------------------------------------
    -- Push old anchor into history
    ---------------------------------------------------------------------------

    if anchor ~= "" then
        table.insert(history, anchor)

        if #history > HISTORY_LIMIT then
            table.remove(history, 1)
        end
    end

    ---------------------------------------------------------------------------
    -- Reset session state
    ---------------------------------------------------------------------------

    anchor = cleaned

    prepend_count  = 0
    anchor_excluded = false

    dismiss_osd()

    copy_to_clipboard(anchor)
end

-------------------------------------------------------------------------------
-- Key bindings
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- n : prepend previous line
-------------------------------------------------------------------------------

mp.add_key_binding(
    "n",
    "sub-copy-prepend",
    function()

        if anchor == "" then
            return
        end

        local available = #history

        if prepend_count >= available then
            mp.msg.info(
                "sub-copy: no more lines to prepend"
            )

            return
        end

        prepend_count = prepend_count + 1

        copy_to_clipboard(build_selection())

        show_osd(
            build_osd_label(),
            OSD_PREPEND_TIMEOUT
        )
    end
)

-------------------------------------------------------------------------------
-- N : remove oldest prepended line
-------------------------------------------------------------------------------

mp.add_key_binding(
    "N",
    "sub-copy-unprepend",
    function()

        if anchor == "" or prepend_count == 0 then
            return
        end

        prepend_count = prepend_count - 1

        local selection = build_selection()

        -----------------------------------------------------------------------
        -- Prevent empty clipboard
        -----------------------------------------------------------------------

        if selection == "" then
            mp.msg.info(
                "sub-copy: selection would be empty, ignoring"
            )

            prepend_count = prepend_count + 1

            return
        end

        copy_to_clipboard(selection)

        if prepend_count == 0 and not anchor_excluded then
            show_osd(
                build_osd_label(),
                OSD_RESET_TIMEOUT
            )
        else
            show_osd(
                build_osd_label(),
                OSD_PREPEND_TIMEOUT
            )
        end
    end
)

-------------------------------------------------------------------------------
-- m : reset to anchor
-------------------------------------------------------------------------------

mp.add_key_binding(
    "m",
    "sub-copy-reset",
    function()

        if anchor == "" then
            return
        end

        prepend_count  = 0
        anchor_excluded = false

        copy_to_clipboard(anchor)

        show_osd(
            build_osd_label(),
            OSD_RESET_TIMEOUT
        )
    end
)

-------------------------------------------------------------------------------
-- M : toggle anchor exclusion
-------------------------------------------------------------------------------

mp.add_key_binding(
    "M",
    "sub-copy-toggle-anchor",
    function()

        if anchor == "" or prepend_count == 0 then
            return
        end

        anchor_excluded =
            not anchor_excluded

        local selection = build_selection()

        -----------------------------------------------------------------------
        -- Prevent empty clipboard
        -----------------------------------------------------------------------

        if selection == "" then
            anchor_excluded =
                not anchor_excluded

            mp.msg.info(
                "sub-copy: selection would be empty, ignoring"
            )

            return
        end

        copy_to_clipboard(selection)

        show_osd(
            build_osd_label(),
            OSD_PREPEND_TIMEOUT
        )
    end
)

-------------------------------------------------------------------------------
-- Observe subtitle property
-------------------------------------------------------------------------------

mp.observe_property(
    "sub-text",
    "string",
    on_sub_text_changed
)