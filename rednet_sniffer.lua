-- Rednet/modem sniffer -- listens on channels rednet itself wouldn't show you.
-- Usage: rednet_sniffer [startChannel] [endChannel]
--   Always listens on broadcast (65535). Add a range to also catch
--   channel-specific traffic (e.g. computer-ID-addressed messages).

local modem = peripheral.find("modem")
if not modem then error("No modem found.") end

local args = { ... }
local startCh = tonumber(args[1])
local endCh = tonumber(args[2])

modem.open(65535)
if startCh and endCh then
    for ch = startCh, endCh do
        if ch ~= 65535 then modem.open(ch) end
    end
end

local count = 0
local w, h = term.getSize()

local function drawHeader()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clearLine()
    local range = "bcast" .. ((startCh and endCh) and ("+" .. startCh .. "-" .. endCh) or "")
    local text = (" %s %d"):format(range, count)
    if #text > w then text = text:sub(1, w) end
    term.write(text)
    term.setBackgroundColor(colors.black)
end

local function short(v, maxLen)
    local s
    if type(v) == "table" then
        s = textutils.serialize(v, { compact = true })
    else
        s = tostring(v)
    end
    s = s:gsub("%s+", " ")
    if #s > maxLen then s = s:sub(1, maxLen - 1) .. "~" end
    return s
end

-- Detects the standard rednet envelope shape: {nSender=, nRecipient=,
-- sProtocol=, message=, nMessageID=} -- vs. raw/unknown modem traffic.
local function isRednetEnvelope(msg)
    return type(msg) == "table" and msg.nSender ~= nil and msg.message ~= nil
end

local function describePayload(payload)
    if type(payload) == "table" and payload.type then
        return tostring(payload.type)
    end
    return short(payload, 30)
end

-- Builds ONE plain-text line, pre-truncated to the real screen width, so a
-- single term.write can never wrap mid-field.
local function buildLine(channel, message, isEnv)
    local line
    if isEnv then
        line = ("#%d>%d %s: %s"):format(
            message.nSender, message.nRecipient,
            tostring(message.sProtocol or "?"),
            describePayload(message.message))
    else
        line = ("ch%d: %s"):format(channel, short(message, 30))
    end
    if #line > w then
        line = line:sub(1, math.max(1, w - 1)) .. "~"
    end
    return line
end

term.clear()
drawHeader()
term.setCursorPos(1, 2)

while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    count = count + 1

    local y = select(2, term.getCursorPos())
    if y >= h then
        term.scroll(1)
        term.setCursorPos(1, h)
        y = h
    end

    local isEnv = isRednetEnvelope(message)
    term.setTextColor(isEnv and colors.cyan or colors.white)
    term.write(buildLine(channel, message, isEnv))

    drawHeader()
    term.setCursorPos(1, math.min(y + 1, h))
end
