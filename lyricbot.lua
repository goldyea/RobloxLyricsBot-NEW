repeat task.wait() until game:IsLoaded()

local env = getgenv()
if env.LyricsBotLoaded then
    return
end
env.LyricsBotLoaded = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local httprequest =
    (syn and syn.request)
    or (http and http.request)
    or http_request
    or (fluxus and fluxus.request)
    or request

if not httprequest then
    warn("[LyricsBot] No supported HTTP request function found.")
    return
end

local ChatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
if not ChatEvents then
    warn("[LyricsBot] DefaultChatSystemChatEvents not found.")
    return
end

local SayMessageRequest = ChatEvents:FindFirstChild("SayMessageRequest")
local OnMessageDoneFiltering = ChatEvents:FindFirstChild("OnMessageDoneFiltering")

if not SayMessageRequest or not OnMessageDoneFiltering then
    warn("[LyricsBot] Required chat events not found.")
    return
end

local GUI_PARENT = (gethui and gethui()) or CoreGui

local BOT_PREFIX = "🤖 | "
local SING_PREFIX = "🎙️ | "
local CHAT_CHANNEL = "All"
local MAX_CHAT_LENGTH = 190

local state = "idle" -- idle, fetching, singing
local sessionId = 0
local blacklist = {}

local function trim(str)
    return tostring(str or ""):match("^%s*(.-)%s*$") or ""
end

local function normalizeName(str)
    return trim(str):lower()
end

local function setStatus(newState)
    state = newState
    if _G.__LyricsBotStatusLabel then
        _G.__LyricsBotStatusLabel.Text = "Status: " .. newState
    end
end

local function splitMessage(text, maxLen)
    text = tostring(text or "")
    maxLen = maxLen or MAX_CHAT_LENGTH

    if #text <= maxLen then
        return { text }
    end

    local chunks = {}
    local current = ""

    for word in text:gmatch("%S+") do
        if current == "" then
            current = word
        elseif (#current + 1 + #word) <= maxLen then
            current = current .. " " .. word
        else
            table.insert(chunks, current)

            if #word > maxLen then
                local startIndex = 1
                while startIndex <= #word do
                    local slice = word:sub(startIndex, startIndex + maxLen - 1)
                    if #slice == maxLen then
                        table.insert(chunks, slice)
                    else
                        current = slice
                    end
                    startIndex = startIndex + maxLen
                end

                if #word % maxLen == 0 then
                    current = ""
                end
            else
                current = word
            end
        end
    end

    if current ~= "" then
        table.insert(chunks, current)
    end

    return chunks
end

local function fireChat(text)
    SayMessageRequest:FireServer(text, CHAT_CHANNEL)
end

local function sendMessage(text, perChunkDelay)
    local chunks = splitMessage(text, MAX_CHAT_LENGTH)
    for i, chunk in ipairs(chunks) do
        fireChat(chunk)
        if i < #chunks then
            task.wait(perChunkDelay or 0.3)
        end
    end
end

local function calcLineDelay(line)
    local len = #line
    if len <= 25 then
        return 2.2
    elseif len <= 60 then
        return 3.2
    elseif len <= 100 then
        return 4.2
    else
        return 5
    end
end

local function addToBlacklist(username)
    username = trim(username)
    if username == "" then
        return
    end

    blacklist[normalizeName(username)] = true
    sendMessage(BOT_PREFIX .. username .. " has been blacklisted.")
end

local function removeFromBlacklist(username)
    username = trim(username)
    if username == "" then
        return
    end

    blacklist[normalizeName(username)] = nil
    sendMessage(BOT_PREFIX .. username .. " has been removed from the blacklist.")
end

local function isBlacklisted(username)
    return blacklist[normalizeName(username)] == true
end

local function stopSinging(announce)
    if state == "singing" or state == "fetching" then
        sessionId = sessionId + 1
        setStatus("idle")
        if announce then
            sendMessage(BOT_PREFIX .. "Stopped singing. You can request songs again.")
        end
    end
end

local function urlEncode(str)
    local ok, encoded = pcall(function()
        return HttpService:UrlEncode(str)
    end)

    if ok and encoded then
        return encoded
    end

    str = tostring(str or "")
    str = str:gsub("\n", "\r\n")
    str = str:gsub("([^%w%-_%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return str
end

local function httpGetJson(url)
    local response
    local ok, err = pcall(function()
        response = httprequest({
            Url = url,
            Method = "GET",
        })
    end)

    if not ok or not response then
        return false, "Request failed: " .. tostring(err)
    end

    local statusCode = tonumber(response.StatusCode or response.Status or 0) or 0
    local body = response.Body or ""

    if statusCode == 404 then
        return false, "No lyrics found."
    end

    if statusCode == 429 then
        return false, "Rate limited. Try again in a bit."
    end

    if statusCode >= 400 then
        return false, "HTTP error " .. tostring(statusCode)
    end

    local decoded
    ok, err = pcall(function()
        decoded = HttpService:JSONDecode(body)
    end)

    if not ok or type(decoded) ~= "table" then
        return false, "Invalid JSON response."
    end

    return true, decoded
end

local function resolveSongFromSuggest(query)
    query = trim(query)
    if query == "" then
        return nil, nil, "Missing song name."
    end

    local ok, data = httpGetJson("https://api.lyrics.ovh/suggest/" .. urlEncode(query))
    if not ok then
        return nil, nil, data
    end

    local results = data.data
    if type(results) ~= "table" or not results[1] then
        return nil, nil, 'Could not identify the artist. Use >play [Song]{Artist}.'
    end

    local best = results[1]
    local artistName = best.artist and best.artist.name
    local songTitle = best.title

    if type(artistName) ~= "string" or artistName == "" then
        return nil, nil, 'Could not identify the artist. Use >play [Song]{Artist}.'
    end

    if type(songTitle) ~= "string" or songTitle == "" then
        songTitle = query
    end

    return songTitle, artistName, nil
end

local function fetchLyrics(songTitle, artistName)
    songTitle = trim(songTitle)
    artistName = trim(artistName)

    if songTitle == "" or artistName == "" then
        return false, "Song title and artist are required."
    end

    local url = "https://api.lyrics.ovh/v1/" .. urlEncode(artistName) .. "/" .. urlEncode(songTitle)
    local ok, data = httpGetJson(url)

    if not ok then
        return false, data
    end

    if type(data.lyrics) ~= "string" or trim(data.lyrics) == "" then
        return false, "No lyrics found."
    end

    return true, data.lyrics
end

local function singLyrics(lyrics, mySession)
    for rawLine in tostring(lyrics):gmatch("[^\r\n]+") do
        if state ~= "singing" or sessionId ~= mySession then
            return
        end

        local line = trim(rawLine)
        if line ~= "" then
            local chunks = splitMessage(SING_PREFIX .. line, MAX_CHAT_LENGTH)
            for _, chunk in ipairs(chunks) do
                if state ~= "singing" or sessionId ~= mySession then
                    return
                end

                fireChat(chunk)
                task.wait(calcLineDelay(chunk))
            end
        end
    end
end

local function parsePlayCommand(message)
    message = trim(message)

    local songTitle, artistName = message:match("^>play%s*%[([^%]]+)%]%s*{([^}]+)}%s*$")
    if songTitle then
        return trim(songTitle), trim(artistName)
    end

    songTitle = message:match("^>play%s*%[([^%]]+)%]%s*$")
    if songTitle then
        return trim(songTitle), nil
    end

    return nil, nil
end

local function handleSongRequest(requestedTitle, requestedArtist)
    if state == "singing" or state == "fetching" then
        sendMessage(BOT_PREFIX .. "Busy right now. Type >stop first.")
        return
    end

    sessionId = sessionId + 1
    local mySession = sessionId
    setStatus("fetching")

    task.spawn(function()
        local songTitle = requestedTitle
        local artistName = requestedArtist

        if not artistName or trim(artistName) == "" then
            local resolvedTitle, resolvedArtist, resolveErr = resolveSongFromSuggest(songTitle)
            if sessionId ~= mySession then
                return
            end

            if not resolvedTitle or not resolvedArtist then
                setStatus("idle")
                sendMessage(BOT_PREFIX .. tostring(resolveErr or 'Could not identify the artist. Use >play [Song]{Artist}.'))
                return
            end

            songTitle = resolvedTitle
            artistName = resolvedArtist
        end

        sendMessage(BOT_PREFIX .. ("Fetching lyrics for %s by %s..."):format(songTitle, artistName))

        local ok, lyricsOrErr = fetchLyrics(songTitle, artistName)
        if sessionId ~= mySession then
            return
        end

        if not ok then
            setStatus("idle")
            sendMessage(BOT_PREFIX .. tostring(lyricsOrErr))
            return
        end

        setStatus("singing")
        task.wait(1.25)
        singLyrics(lyricsOrErr, mySession)

        if sessionId == mySession then
            setStatus("idle")
            sendMessage(BOT_PREFIX .. "Ended. You can request songs again.")
        end
    end)
end

local function onMessage(msgdata)
    if type(msgdata) ~= "table" then
        return
    end

    local fromSpeaker = tostring(msgdata.FromSpeaker or "")
    local message = trim(tostring(msgdata.Message or ""))

    if message == "" then
        return
    end

    if normalizeName(fromSpeaker) == normalizeName(LocalPlayer and LocalPlayer.Name or "") then
        return
    end

    if isBlacklisted(fromSpeaker) then
        return
    end

    if message:lower() == ">stop" then
        stopSinging(true)
        return
    end

    local songTitle, artistName = parsePlayCommand(message)
    if songTitle then
        handleSongRequest(songTitle, artistName)
    end
end

-- GUI
local existingGui = GUI_PARENT:FindFirstChild("LyricsBotGui")
if existingGui then
    existingGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LyricsBotGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = GUI_PARENT

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 320, 0, 235)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -117)
MainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -35, 0, 30)
Title.Position = UDim2.new(0, 10, 0, 5)
Title.BackgroundTransparency = 1
Title.Text = "Lyrics Bot Control Panel"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 20
Title.Parent = MainFrame

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 25, 0, 25)
CloseButton.Position = UDim2.new(1, -30, 0, 5)
CloseButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.new(1, 1, 1)
CloseButton.Font = Enum.Font.SourceSansBold
CloseButton.TextSize = 18
CloseButton.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -10, 0, 20)
StatusLabel.Position = UDim2.new(0, 5, 0, 35)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: idle"
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.Font = Enum.Font.SourceSans
StatusLabel.TextSize = 18
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = MainFrame
_G.__LyricsBotStatusLabel = StatusLabel

local function makeButton(text, posXScale, posXOffset, posY)
    local button = Instance.new("TextButton")
    button.Text = text
    button.Size = UDim2.new(0.5, -10, 0, 32)
    button.Position = UDim2.new(posXScale, posXOffset, 0, posY)
    button.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.SourceSansSemibold
    button.TextSize = 18
    button.Parent = MainFrame
    return button
end

local BlacklistButton = makeButton("Blacklist User", 0, 5, 65)
local UnblacklistButton = makeButton("Unblacklist User", 0.5, 5, 65)

local StopButton = Instance.new("TextButton")
StopButton.Text = "Stop Singing"
StopButton.Size = UDim2.new(1, -10, 0, 32)
StopButton.Position = UDim2.new(0, 5, 0, 105)
StopButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
StopButton.TextColor3 = Color3.new(1, 1, 1)
StopButton.Font = Enum.Font.SourceSansSemibold
StopButton.TextSize = 18
StopButton.Parent = MainFrame

local UserInput = Instance.new("TextBox")
UserInput.PlaceholderText = "Enter Username"
UserInput.Size = UDim2.new(1, -10, 0, 32)
UserInput.Position = UDim2.new(0, 5, 0, 145)
UserInput.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
UserInput.TextColor3 = Color3.new(1, 1, 1)
UserInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
UserInput.ClearTextOnFocus = false
UserInput.Font = Enum.Font.SourceSans
UserInput.TextSize = 18
UserInput.Parent = MainFrame

local HelpLabel = Instance.new("TextLabel")
HelpLabel.Size = UDim2.new(1, -10, 0, 48)
HelpLabel.Position = UDim2.new(0, 5, 0, 182)
HelpLabel.BackgroundTransparency = 1
HelpLabel.TextWrapped = true
HelpLabel.TextYAlignment = Enum.TextYAlignment.Top
HelpLabel.TextXAlignment = Enum.TextXAlignment.Left
HelpLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
HelpLabel.Font = Enum.Font.SourceSans
HelpLabel.TextSize = 16
HelpLabel.Text = 'Commands: >play [Song]{Artist}  |  >play [Song]  |  >stop'
HelpLabel.Parent = MainFrame

BlacklistButton.MouseButton1Click:Connect(function()
    local username = UserInput.Text
    if trim(username) ~= "" then
        addToBlacklist(username)
        UserInput.Text = ""
    end
end)

UnblacklistButton.MouseButton1Click:Connect(function()
    local username = UserInput.Text
    if trim(username) ~= "" then
        removeFromBlacklist(username)
        UserInput.Text = ""
    end
end)

StopButton.MouseButton1Click:Connect(function()
    stopSinging(true)
end)

CloseButton.MouseButton1Click:Connect(function()
    stopSinging(false)
    _G.__LyricsBotStatusLabel = nil
    ScreenGui:Destroy()
    env.LyricsBotLoaded = nil
end)

OnMessageDoneFiltering.OnClientEvent:Connect(onMessage)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(45)
        if state == "idle" then
            sendMessage(BOT_PREFIX .. 'Type ">play [Song]{Artist}" or ">play [Song]" and I\'ll sing it.')
        end
    end
end)

setStatus("idle")
sendMessage(BOT_PREFIX .. "Lyrics bot loaded.")
