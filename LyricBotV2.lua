-- TESTING SCRIPTS
repeat task.wait() until game:IsLoaded()

if not getgenv().executedHi then
    getgenv().executedHi = true
else
    return
end

local httprequest = (syn and syn.request) or http and http.request or http_request or (fluxus and fluxus.request) or request

local plr
local state = "saying"  -- Initial state

local function sendMessage(text)
    game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(text, "All")
end

game:GetService('ReplicatedStorage').DefaultChatSystemChatEvents:WaitForChild('OnMessageDoneFiltering').OnClientEvent:Connect(function(msgdata)
    if state == "singing" then
        return  -- Don't process commands while singing
    end

    if plr ~= nil and (msgdata.FromSpeaker == plr or msgdata.FromSpeaker == game:GetService('Players').LocalPlayer.Name) then
        if string.lower(msgdata.Message) == '>stop' then
            state = "saying"  -- Change state to saying
            sendMessage('Stopped singing. You can request songs again.')
        end
    end

    if state == "saying" and string.match(msgdata.Message, '>lyrics "?.-"') then
        state = "singing"  -- Change state to singing
        plr = game:GetService('Players')[msgdata.FromSpeaker].Name

        local msg = string.lower(msgdata.Message):gsub('>lyrics ', ''):gsub('"', '')
        local songName, artist = string.match(msg, "(.-) by (.*)")

        if artist and artist ~= "" then
            artist = artist:gsub(" ", "%20"):lower()
        else
            songName = msg:gsub(" ", "%20"):lower()  -- If no artist provided, use songName
        end
        
        songName = songName:gsub(" ", "%20"):lower()  -- Ensure songName is formatted correctly

        local response
        local suc, er = pcall(function()
            response = httprequest({
                Url = "https://lyrist.vercel.app/api/" .. songName .. (artist and "/" .. artist or ""),
                Method = "GET",
            })
        end)

        if not suc or not response or not response.Body then
            sendMessage('Unexpected error or empty response. Please retry.')
            state = "saying"  -- Change state back to saying
            return
        end

        local lyricsData = game:GetService('HttpService'):JSONDecode(response.Body)

        if not lyricsData or not lyricsData.lyrics then
            sendMessage('Failed to fetch lyrics. Please check the song and artist names.')
            state = "saying"  -- Change state back to saying
            return
        end

        local lyricsTable = {}

        if lyricsData.error and lyricsData.error == "Lyrics Not found" then
            sendMessage('Lyrics were not found')
            state = "saying"  -- Change state back to saying
            return
        end

        sendMessage('Fetched lyrics')
        task.wait(2)
        sendMessage('Playing song requested by ' .. game:GetService('Players')[msgdata.FromSpeaker].DisplayName .. '. They can stop it by saying ">stop"')
        task.wait(3)

        for i, line in ipairs(string.gmatch(lyricsData.lyrics, "[^\n]+")) do
            if state == "saying" then
                break  -- Stop singing if state changes to saying
            end

            sendMessage('🎙️ | ' .. line)
            task.wait(4.7)
        end

        task.wait(3)
        state = "saying"  -- Change state back to saying
        sendMessage('Ended. You can request songs again.')
    end
end)

task.spawn(function()
    while task.wait(20) do
        if state == "saying" then
            sendMessage('I am a lyrics bot! Type ">lyrics "SongName"" and I will sing the song for you!')
            task.wait(2)
            sendMessage('Example: ">lyrics "SongName"" or ">lyrics "SongName" by "Artist""')
        end
    end
end)

sendMessage('I am a lyrics bot! Type ">lyrics "SongName"" and I will sing the song for you!')
task.wait(2)
sendMessage('Example: ">lyrics "SongName"" or ">lyrics "SongName" by "Artist""')
