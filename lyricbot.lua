-- Ensure the game is loaded
repeat task.wait() until game:IsLoaded()

-- Prevent the script from executing multiple times
if not getgenv().executedHi then
    getgenv().executedHi = true
else
    return
end

-- Define the HTTP request function depending on the executor
local httprequest = (syn and syn.request) or http and http.request or http_request or (fluxus and fluxus.request) or request

local state = "saying"  -- Initial state
local blacklist = {}  -- Dictionary to hold blacklisted users

local function sendMessage(text)
    game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(text, "All")
end

-- GUI setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = game.CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 200)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
MainFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
MainFrame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Text = "Lyrics Bot Control Panel"
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Parent = MainFrame

-- Add Blacklist Button
local BlacklistButton = Instance.new("TextButton")
BlacklistButton.Text = "Blacklist User"
BlacklistButton.Size = UDim2.new(0.5, -10, 0, 30)
BlacklistButton.Position = UDim2.new(0, 5, 0, 40)
BlacklistButton.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
BlacklistButton.TextColor3 = Color3.new(1, 1, 1)
BlacklistButton.Parent = MainFrame

-- Unblacklist Button
local UnblacklistButton = Instance.new("TextButton")
UnblacklistButton.Text = "Unblacklist User"
UnblacklistButton.Size = UDim2.new(0.5, -10, 0, 30)
UnblacklistButton.Position = UDim2.new(0.5, 5, 0, 40)
UnblacklistButton.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
UnblacklistButton.TextColor3 = Color3.new(1, 1, 1)
UnblacklistButton.Parent = MainFrame

-- Stop Singing Button
local StopButton = Instance.new("TextButton")
StopButton.Text = "Stop Singing"
StopButton.Size = UDim2.new(1, -10, 0, 30)
StopButton.Position = UDim2.new(0, 5, 0, 80)
StopButton.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
StopButton.TextColor3 = Color3.new(1, 1, 1)
StopButton.Parent = MainFrame

-- Input field for username
local UserInput = Instance.new("TextBox")
UserInput.PlaceholderText = "Enter Username"
UserInput.Size = UDim2.new(1, -10, 0, 30)
UserInput.Position = UDim2.new(0, 5, 0, 120)
UserInput.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
UserInput.TextColor3 = Color3.new(1, 1, 1)
UserInput.Parent = MainFrame

-- Function to add and remove users from the blacklist
local function addToBlacklist(username)
    blacklist[username] = true
    sendMessage(username .. " has been blacklisted.")
end

local function removeFromBlacklist(username)
    blacklist[username] = nil
    sendMessage(username .. " has been removed from the blacklist.")
end

-- GUI Button Actions
BlacklistButton.MouseButton1Click:Connect(function()
    local username = UserInput.Text
    if username and username ~= "" then
        addToBlacklist(username)
        UserInput.Text = ""
    end
end)

UnblacklistButton.MouseButton1Click:Connect(function()
    local username = UserInput.Text
    if username and username ~= "" then
        removeFromBlacklist(username)
        UserInput.Text = ""
    end
end)

StopButton.MouseButton1Click:Connect(function()
    if state == "singing" then
        state = "saying"
        sendMessage('Stopped singing. You can request songs again.')
    end
end)

-- Function to handle singing lyrics with dynamic pacing
local function singLyrics(lyrics)
    for line in string.gmatch(lyrics, "[^\n]+") do
        if state ~= "singing" then
            break  -- Stop singing if state changes to saying
        end

        sendMessage('🎙️ | ' .. line)

        -- Calculate wait time based on line length
        local lineLength = string.len(line)
        local waitTime = 3  -- Default wait time for short lines

        -- Increase wait time for longer lines
        if lineLength > 50 then  -- Adjust this threshold as needed
            waitTime = 5  -- Extra second for long lines
        end

        task.wait(waitTime)  -- Wait for the calculated time based on line length
    end
end

-- Function to fetch lyrics from the API
local function fetchLyrics(songName, artist)
    local url = "https://lyrist.vercel.app/api/" .. songName:gsub(" ", "%20")
    if artist then
        url = url .. "/" .. artist:gsub(" ", "%%20")
    end
    
    local response
    local success, err = pcall(function()
        response = httprequest({
            Url = url,
            Method = "GET",
        })
    end)

    -- Handle errors during the request
    if not success or not response then
        return 'Error fetching lyrics: ' .. tostring(err)
    end

    local lyricsData
    success, err = pcall(function()
        lyricsData = game:GetService('HttpService'):JSONDecode(response.Body)
    end)

    -- Handle decoding errors
    if not success or not lyricsData or lyricsData.error then
        return 'Error fetching lyrics: ' .. (lyricsData.error or tostring(err))
    end

    return lyricsData.lyrics or "No lyrics found."
end

-- Function to handle user messages
local function onMessage(msgdata)
    -- Ignore messages from the bot itself or blacklisted users
    if msgdata.FromSpeaker == "Decideaside" or blacklist[msgdata.FromSpeaker] then
        return
    end

    if string.lower(msgdata.Message) == '>stop' and state == "singing" then
        state = "saying"  -- Change state to saying
        sendMessage('Stopped singing. You can request songs again.')
        return
    end

    -- Check for song request with or without artist
    local songCommand = string.match(msgdata.Message, '^>play%s*%[([^%]]+)%]%s*{([^}]+)}$')  -- Matches ">play [SongName]{Artist}"
    local songOnlyCommand = string.match(msgdata.Message, '^>play%s*%[([^%]]+)%]$') -- Matches ">play [SongName]"

    local songName, artist
    if songCommand then
        songName, artist = string.match(msgdata.Message, '^>play%s*%[([^%]]+)%]%s*{([^}]+)}$')
    elseif songOnlyCommand then
        songName = string.match(msgdata.Message, '^>play%s*%[([^%]]+)%]$')
        artist = nil  -- No artist specified
    end

    if songName then
        songName = songName:gsub(" ", "%%20"):lower()  -- Format the song name

        -- Fetch lyrics using the new function
        local lyrics = fetchLyrics(songName, artist)
        if lyrics == "No lyrics found." then
            sendMessage('No lyrics available for this song.')
            return
        end

        state = "singing"  -- Change state to singing
        sendMessage('Fetching lyrics for ' .. songName .. ' by ' .. (artist ~= "" and artist or "Unknown") .. '...')
        task.wait(2)  -- Wait before starting to sing
        singLyrics(lyrics)  -- Sing the lyrics
        state = "saying"  -- Return to saying state after singing
        sendMessage('Ended. You can request songs again.')
    end
end

-- Function to remind players about commands
local function remindCommands()
    while task.wait(25) do
        if state == "saying" then
            sendMessage('🤖 | I am a roblox lyrics bot created by gold.js on ykw! Type ">play [SongName]" or ">play [SongName]{Artist}" and I\'ll sing it!')
        end
    end
end

-- Connect the message event
game:GetService('ReplicatedStorage').DefaultChatSystemChatEvents.OnMessageDoneFiltering.OnClientEvent:Connect(onMessage)

-- Start command reminder loop
remindCommands()
