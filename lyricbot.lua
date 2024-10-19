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

-- Function to fetch lyrics from the API
local function fetchLyrics(songName, artist)
    local url = "https://lyrist.vercel.app/api/" .. songName:gsub(" ", "%20") .. "/" .. (artist and artist:gsub(" ", "%20") or "")
    
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

    -- Check for song request
    local songCommand = string.match(msgdata.Message, '^>play%s*%[([^%]]+)%]%s*{([^}]+)}$')  -- Matches ">play [SongName]{Artist}"
    
    if songCommand then
        local songName, artist = string.match(msgdata.Message, '^>play%s*%[([^%]]+)%]%s*{([^}]+)}$')
        songName = songName:gsub(" ", "%20"):lower()  -- Format the song name
        artist = artist and artist:gsub(" ", "%20"):lower() or ""  -- Format the artist name, if present

        -- Fetch lyrics using the new function
        local lyrics = fetchLyrics(songName, artist)
        if not lyrics or lyrics == "No lyrics found." then
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
            sendMessage('🤖 | Lyrics bot! Type ">play [SongName]" or ">play "[SongName]{Artist}" and I will sing it!')
        end
    end
end

-- Connect the message event
game:GetService('ReplicatedStorage').DefaultChatSystemChatEvents.OnMessageDoneFiltering.OnClientEvent:Connect(onMessage)

-- Start the reminder function in a separate thread
task.spawn(remindCommands)

-- Initial bot message
sendMessage('🤖 | Lyrics bot! Type ">play [SongName]" or ">play "[SongName]{Artist}" and I will sing it!')

-- Example call to fetch lyrics for "Clarity" by Zedd
local exampleSong = "Clarity"
local exampleArtist = "Zedd"
local lyrics = fetchLyrics(exampleSong, exampleArtist)
sendMessage(lyrics)  -- Send the fetched lyrics as a message
