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

local function sendMessage(text)
    game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(text, "All")
end

-- Function to handle singing lyrics with dynamic pacing
local function singLyrics(lyrics)
    for line in string.gmatch(lyrics, "[^\n]+") do
        if state ~= "singing" then
            break  -- Stop singing if state changes to saying
        end

        sendMessage('🎙️ | ' .. line)

        -- Calculate wait time based on line length
        local lineLength = string.len(line)
        local waitTime = 1  -- Default wait time for short lines

        -- Increase wait time for longer lines
        if lineLength > 50 then  -- Adjust this threshold as needed
            waitTime = 2  -- Extra second for long lines
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
    if msgdata.FromSpeaker == "Decideaside" then
        return  -- Ignore messages from the bot itself
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
    while task.wait(10) do
        if state == "saying" then
            sendMessage('🤖 | Lyrics bot! Type ">play [SongName]" or ">play [SongName]{Artist}" and I will sing it!')
        end
    end
end

-- Connect the message event
game:GetService('ReplicatedStorage').DefaultChatSystemChatEvents.OnMessageDoneFiltering.OnClientEvent:Connect(onMessage)

-- Start the reminder function in a separate thread
task.spawn(remindCommands)

-- Initial bot message
sendMessage('🤖 | Lyrics bot! Type ">play [SongName]" or ">play [SongName]{Artist}" and I will sing it!')
