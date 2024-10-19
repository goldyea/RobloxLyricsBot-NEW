-- TESTING SCRIPTS
repeat task.wait() until game:IsLoaded()

if not getgenv().executedHi then
    getgenv().executedHi = true
else
    return
end

local httprequest = (syn and syn.request) or http and http.request or http_request or (fluxus and fluxus.request) or request
local httpService = game:GetService('HttpService')
local state = "saying"  -- Initial state

local function sendMessage(text)
    game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(text, "All")
end

-- Function to handle singing lyrics
local function singLyrics(lyrics)
    for line in string.gmatch(lyrics, "[^\n]+") do
        if state ~= "singing" then
            break  -- Stop singing if state changes to saying
        end
        sendMessage('🎙️ | ' .. line)
        task.wait(4.7)  -- Adjust the delay for pacing between lines
    end
end

-- Function to handle user messages
local function onMessage(msgdata)
    if msgdata.FromSpeaker == "Decideaside" then
        return  -- Ignore messages from the bot itself
    end

    -- Stop singing if requested
    if string.lower(msgdata.Message) == '>stop' and state == "singing" then
        state = "saying"  -- Change state to saying
        sendMessage('🎶 | Stopped singing. You can request songs again.')
        return
    end

    -- Match the song request command
    local songCommand = string.match(msgdata.Message, '^>play%s*%[([^%]]+)%]%s*{([^}]+)}$') 
    if songCommand then
        local songName, artist = string.match(msgdata.Message, '^>play%s*%[([^%]]+)%]%s*{([^}]+)}$')
        songName = songName:gsub(" ", "%20"):lower()  -- Format the song name
        artist = artist and artist:gsub(" ", "%20"):lower() or ""  -- Format the artist name, if present

        local response
        local success, err = pcall(function()
            response = httprequest({
                Url = "https://lyrist.vercel.app/api/" .. songName .. (artist ~= "" and "/" .. artist or ""),
                Method = "GET",
            })
        end)

        -- Error handling
        if not success or not response or not response.Body then
            sendMessage('⚠️ | Error fetching lyrics: ' .. (err or 'No response from the API.'))
            state = "saying"  -- Reset state to saying
            return
        end

        local lyricsData
        local success, decodeErr = pcall(function()
            lyricsData = httpService:JSONDecode(response.Body)
        end)

        if not success or not lyricsData or lyricsData.error or not lyricsData.lyrics then
            sendMessage('⚠️ | Error fetching lyrics. Please check the song and artist names.')
            state = "saying"  -- Reset state to saying
            return
        end

        state = "singing"  -- Change state to singing
        sendMessage('🎶 | Fetching lyrics for ' .. songName .. ' by ' .. (artist ~= "" and artist or "Unknown") .. '...')
        task.wait(2)  -- Wait before starting to sing
        singLyrics(lyricsData.lyrics)  -- Sing the lyrics
        state = "saying"  -- Return to saying state after singing
        sendMessage('🎶 | Ended. You can request songs again.')
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
