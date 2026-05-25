-- sub-mark.lua
-- Word-marking mode for sentence mining.
--
-- Controls:
--
-- b      : activate / cancel mode (toggle)
-- B      : reset markers
-- k      : move cursor forward
-- j      : move cursor backward
-- SPACE  : insert/remove marker automatically
-- h      : place/remove trim_right marker (delete everything after cursor)
-- H      : place/remove trim_left  marker (delete everything before cursor)
-- ENTER  : confirm + copy to clipboard

-------------------------------------------------------------------------------
-- Config
-------------------------------------------------------------------------------

local OSD_FONT_SIZE  = 34
local OSD_WRAP_CHARS = 60

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

local tokens          = {}
local punct_suffix    = {}
local markers         = {}

local cursor_pos      = 1
local active          = false
local expecting_close = false

local osd_w           = 0
local osd_h           = 0

-------------------------------------------------------------------------------
-- Clipboard
-------------------------------------------------------------------------------

local function read_clipboard()
    local cmd

    if os.getenv("WAYLAND_DISPLAY") then
        cmd = "wl-paste --no-newline 2>/dev/null"
    else
        cmd = "xclip -selection clipboard -o 2>/dev/null"
    end

    local handle = io.popen(cmd)

    if not handle then
        return ""
    end

    local result = handle:read("*a")

    handle:close()

    return result or ""
end

local function write_clipboard(text)
    local escaped = text:gsub("'", "'\\''")

    local cmd

    if os.getenv("WAYLAND_DISPLAY") then
        cmd = ("printf '%%s' '%s' | wl-copy"):format(escaped)
    else
        cmd = ("printf '%%s' '%s' | xclip -selection clipboard"):format(escaped)
    end

    local ok = os.execute(cmd)

    if not ok then
        mp.msg.warn("sub-mark: clipboard write failed")
    end
end

-------------------------------------------------------------------------------
-- Text helpers
-------------------------------------------------------------------------------

local function split_trailing_punct(word)
    local core, punct = word:match("^(.-)([%p]*)$")

    if not core or core == "" then
        return word, ""
    end

    return core, punct
end

-------------------------------------------------------------------------------
-- Tokenizer
-------------------------------------------------------------------------------

local function tokenize(text)
    local result  = {}
    local psuffix = {}

    local pos = 1
    local len = #text

    while pos <= len do

        -----------------------------------------------------------------------
        -- GAP
        -----------------------------------------------------------------------

        local gap_start = pos

        while pos <= len and text:sub(pos, pos):match("%s") do
            pos = pos + 1
        end

        table.insert(result, text:sub(gap_start, pos - 1))

        if pos > len then
            break
        end

        -----------------------------------------------------------------------
        -- WORD
        -----------------------------------------------------------------------

        local word_start = pos

        while pos <= len and not text:sub(pos, pos):match("%s") do
            pos = pos + 1
        end

        local raw_word = text:sub(word_start, pos - 1)

        local core, punct = split_trailing_punct(raw_word)

        local word_idx = #result + 1

        table.insert(result, core)

        psuffix[word_idx] = punct
    end

    ---------------------------------------------------------------------------
    -- Ensure trailing gap exists
    ---------------------------------------------------------------------------

    if #result % 2 == 0 then
        table.insert(result, "")
    end

    return result, psuffix
end

-------------------------------------------------------------------------------
-- Gap helpers
-------------------------------------------------------------------------------

local function gap_count()
    return math.ceil(#tokens / 2)
end

local function gap_to_idx(gap_num)
    return gap_num * 2 - 1
end

local function idx_to_gap(idx)
    return (idx + 1) / 2
end

-------------------------------------------------------------------------------
-- ASS helpers
-------------------------------------------------------------------------------

local function ass_escape(text)
    return text
        :gsub("\\", "\\\\")
        :gsub("{", "\\{")
        :gsub("}", "\\}")
end

local function red(text)
    return "{\\c&H0000FF&}" .. text .. "{\\c}"
end

local function yellow(text)
    return "{\\c&H00FFFF&}" .. text .. "{\\c}"
end

-------------------------------------------------------------------------------
-- Marker helpers
-------------------------------------------------------------------------------

local function marker_visual(marker)
    if marker == "open" then
        return red("[")
    elseif marker == "close" then
        return red("]")
    elseif marker == "trim_left" then
        return red("<")
    elseif marker == "trim_right" then
        return red(">")
    end

    return ""
end

local function recompute_expectation()
    local count = 0

    for _, marker in pairs(markers) do
        if marker == "open" or marker == "close" then
            count = count + 1
        end
    end

    expecting_close = (count % 2 == 1)
end

local function toggle_marker(idx)

    ---------------------------------------------------------------------------
    -- Remove existing marker
    ---------------------------------------------------------------------------

    if markers[idx] ~= nil then
        markers[idx] = nil

        recompute_expectation()

        return
    end

    ---------------------------------------------------------------------------
    -- Insert automatically
    ---------------------------------------------------------------------------

    if expecting_close then
        markers[idx] = "close"
    else
        markers[idx] = "open"
    end

    expecting_close = not expecting_close
end

local function toggle_trim(idx, kind)

    ---------------------------------------------------------------------------
    -- Remove if same kind already placed here
    ---------------------------------------------------------------------------

    if markers[idx] == kind then
        markers[idx] = nil
        return
    end

    ---------------------------------------------------------------------------
    -- Remove any existing trim marker of this kind anywhere
    ---------------------------------------------------------------------------

    for k, v in pairs(markers) do
        if v == kind then
            markers[k] = nil
        end
    end

    ---------------------------------------------------------------------------
    -- Place marker (overwrite open/close if present at same gap)
    ---------------------------------------------------------------------------

    markers[idx] = kind
    recompute_expectation()
end



local function build_ass_display()
    local segments = {}

    for i, token in ipairs(tokens) do

        -----------------------------------------------------------------------
        -- GAP
        -----------------------------------------------------------------------

        if i % 2 == 1 then
            local space  = ass_escape(token)
            local marker = marker_visual(markers[i])

            local cursor = ""

            if i == cursor_pos then
                cursor = yellow("|")
            end

            table.insert(
                segments,
                space .. marker .. cursor
            )

        -----------------------------------------------------------------------
        -- WORD
        -----------------------------------------------------------------------

        else
            local suffix = ass_escape(punct_suffix[i] or "")

            table.insert(
                segments,
                ass_escape(token) .. suffix
            )
        end
    end

    ---------------------------------------------------------------------------
    -- Wrapping
    ---------------------------------------------------------------------------

    local lines    = {}
    local line     = {}
    local line_len = 0

    for _, seg in ipairs(segments) do
        local display_len =
            #(seg:gsub("{[^}]*}", ""))

        if OSD_WRAP_CHARS > 0
            and line_len > 0
            and line_len + display_len > OSD_WRAP_CHARS
        then
            table.insert(lines, table.concat(line, ""))

            line     = {}
            line_len = 0
        end

        table.insert(line, seg)

        line_len = line_len + display_len
    end

    if #line > 0 then
        table.insert(lines, table.concat(line, ""))
    end

    local body = table.concat(lines, "\\N")

    local header =
        "{\\an8\\fs" ..
        (OSD_FONT_SIZE + 2) ..
        "\\b1}Mark target words:{\\b0}\\N"

    local sentence =
        "{\\fs" ..
        OSD_FONT_SIZE ..
        "}" ..
        body

    return header .. sentence
end

-------------------------------------------------------------------------------
-- Output builder
-------------------------------------------------------------------------------

local function build_output()

    ---------------------------------------------------------------------------
    -- Determine trim boundaries
    ---------------------------------------------------------------------------

    local first_gap = 1
    local last_gap  = gap_count()

    for idx, marker in pairs(markers) do
        if marker == "trim_left" then
            -- trim_left placed at gap idx: delete everything before this gap
            local g = idx_to_gap(idx)
            if g > first_gap then
                first_gap = g
            end
        elseif marker == "trim_right" then
            -- trim_right placed at gap idx: delete everything after this gap
            local g = idx_to_gap(idx)
            if g < last_gap then
                last_gap = g
            end
        end
    end

    local out = {}

    local i = gap_to_idx(first_gap)

    while i <= gap_to_idx(last_gap) do

        -----------------------------------------------------------------------
        -- GAP
        -----------------------------------------------------------------------

        local gap    = tokens[i] or ""
        local marker = markers[i]

        -- Suppress the leading whitespace at the trim boundary
        local is_first = (i == gap_to_idx(first_gap))

        if marker == "open" then
            table.insert(out, is_first and "" or gap)
            table.insert(out, "*")
        else
            table.insert(out, is_first and "" or gap)
        end

        -----------------------------------------------------------------------
        -- WORD
        -----------------------------------------------------------------------

        local word_idx = i + 1

        if word_idx <= gap_to_idx(last_gap) then
            local word  = tokens[word_idx]
            local punct = punct_suffix[word_idx] or ""

            table.insert(out, word)

            -------------------------------------------------------------------
            -- Closing marker goes before punctuation
            -------------------------------------------------------------------

            local next_gap_idx = word_idx + 1

            if markers[next_gap_idx] == "close" then
                table.insert(out, "*")
            end

            table.insert(out, punct)
        end

        i = i + 2
    end

    return table.concat(out, "")
end

-------------------------------------------------------------------------------
-- OSD
-------------------------------------------------------------------------------

mp.add_hook("on_load", 50, function()
    osd_w = mp.get_property_number("osd-width")  or 1920
    osd_h = mp.get_property_number("osd-height") or 1080
end)

local function refresh_osd()
    local w =
        mp.get_property_number("osd-width")
        or osd_w
        or 1920

    local h =
        mp.get_property_number("osd-height")
        or osd_h
        or 1080

    mp.set_osd_ass(
        w,
        h,
        build_ass_display()
    )
end

local function clear_osd()
    local w =
        mp.get_property_number("osd-width")
        or 1920

    local h =
        mp.get_property_number("osd-height")
        or 1080

    mp.set_osd_ass(w, h, "")
end

-------------------------------------------------------------------------------
-- Default binding management
-------------------------------------------------------------------------------

local DISABLED_KEYS = {
    "UP", "DOWN", "LEFT", "RIGHT",
    "ENTER", "SPACE", "ESC",

    "p", "P",
    "BS", "DEL",
    "HOME", "END",
    "PGUP", "PGDWN",

    "[", "]", "{", "}",

    "s", "S",
    "d", "D",
    "f", "F",
    "g", "G",
    "m", "M",
    "n", "N",
    "l", "L",
    "h", "H",
    "u", "U",
    "i", "I",
    "o", "O",
    "a", "A",
    "c", "C",
    "x", "X",
    "z", "Z",
    "r", "R",
    "t", "T",
    "y", "Y",
    "e", "E",
    "w", "W",

    "+", "-", "=", "_",

    "1", "2", "3", "4", "5",
    "6", "7", "8", "9", "0"
}

local function disable_default_bindings()
    local noop = function() end

    for _, key in ipairs(DISABLED_KEYS) do
        mp.add_forced_key_binding(
            key,
            "disable_" .. key,
            noop
        )
    end
end

local function enable_default_bindings()
    for _, key in ipairs(DISABLED_KEYS) do
        mp.remove_key_binding("disable_" .. key)
    end
end

-------------------------------------------------------------------------------
-- Mode key registration
-------------------------------------------------------------------------------

local function unregister_mode_keys()
    mp.remove_key_binding("sub-mark-forward")
    mp.remove_key_binding("sub-mark-backward")
    mp.remove_key_binding("sub-mark-marker-toggle")
    mp.remove_key_binding("sub-mark-confirm")
    mp.remove_key_binding("sub-mark-reset")
    mp.remove_key_binding("sub-mark-trim-right")
    mp.remove_key_binding("sub-mark-trim-left")
end

local function register_mode_keys()

    disable_default_bindings()

    ---------------------------------------------------------------------------
    -- FORWARD
    ---------------------------------------------------------------------------

    mp.add_forced_key_binding(
        "k",
        "sub-mark-forward",
        function()
            local cur_gap = idx_to_gap(cursor_pos)

            if cur_gap < gap_count() then
                cursor_pos = gap_to_idx(cur_gap + 1)

                refresh_osd()
            end
        end
    )

    ---------------------------------------------------------------------------
    -- BACKWARD
    ---------------------------------------------------------------------------

    mp.add_forced_key_binding(
        "j",
        "sub-mark-backward",
        function()
            local cur_gap = idx_to_gap(cursor_pos)

            if cur_gap > 1 then
                cursor_pos = gap_to_idx(cur_gap - 1)

                refresh_osd()
            end
        end
    )

    ---------------------------------------------------------------------------
    -- TOGGLE MARKER
    ---------------------------------------------------------------------------

    mp.add_forced_key_binding(
        "SPACE",
        "sub-mark-marker-toggle",
        function()
            toggle_marker(cursor_pos)

            refresh_osd()
        end
    )

    ---------------------------------------------------------------------------
    -- TRIM RIGHT  (h)
    ---------------------------------------------------------------------------

    mp.add_forced_key_binding(
        "h",
        "sub-mark-trim-right",
        function()
            toggle_trim(cursor_pos, "trim_right")
            refresh_osd()
        end
    )

    ---------------------------------------------------------------------------
    -- TRIM LEFT  (H)
    ---------------------------------------------------------------------------

    mp.add_forced_key_binding(
        "H",
        "sub-mark-trim-left",
        function()
            toggle_trim(cursor_pos, "trim_left")
            refresh_osd()
        end
    )

    ---------------------------------------------------------------------------
    -- RESET
    ---------------------------------------------------------------------------

    mp.add_forced_key_binding(
        "B",
        "sub-mark-reset",
        function()
            markers = {}
            cursor_pos = 1
            expecting_close = false

            refresh_osd()
        end
    )

    ---------------------------------------------------------------------------
    -- CONFIRM
    ---------------------------------------------------------------------------

    mp.add_forced_key_binding(
        "ENTER",
        "sub-mark-confirm",
        function()

            active = false

            enable_default_bindings()
            unregister_mode_keys()
            clear_osd()

            local output = build_output()

            write_clipboard(output)

            mp.osd_message(
                "sub-mark: copied ✓",
                2
            )

            mp.msg.info(
                "sub-mark: wrote to clipboard: "
                .. output
            )
        end
    )
end

-------------------------------------------------------------------------------
-- Mode lifecycle
-------------------------------------------------------------------------------

local function enter_mode()
    local text = read_clipboard()

    if text == "" then
        mp.osd_message(
            "sub-mark: clipboard is empty",
            2
        )

        return
    end

    tokens, punct_suffix = tokenize(text)

    cursor_pos      = 1
    markers         = {}
    expecting_close = false
    active          = true

    register_mode_keys()

    refresh_osd()

    mp.msg.info("sub-mark: activated")
end

local function exit_mode()
    if not active then
        return
    end

    active = false

    enable_default_bindings()
    unregister_mode_keys()
    clear_osd()

    mp.msg.info("sub-mark: cancelled")
end

-------------------------------------------------------------------------------
-- Global bindings
-------------------------------------------------------------------------------

mp.add_key_binding(
    "b",
    "sub-mark-toggle",
    function()
        if active then
            exit_mode()
        else
            enter_mode()
        end
    end
)
