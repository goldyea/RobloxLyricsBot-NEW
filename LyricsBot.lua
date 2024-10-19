repeat task.wait() until game:IsLoaded()

if not getgenv().executedHi then
    getgenv().executedHi = true
else
    return
end

local httprequest = (syn and syn.request) or http and http.request or http_request or (fluxus and fluxus.request) or request

local songName, plr
local debounce = false

getgenv().stopped = false

local function sendMessage(text)
    game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(text, "All")
end

game:GetService('ReplicatedStorage').DefaultChatSystemChatEvents:WaitForChild('OnMessageDoneFiltering').OnClientEvent:Connect(function(msgdata)
    if plr ~= nil and (msgdata.FromSpeaker == plr or msgdata.FromSpeaker == game:GetService('Players').LocalPlayer.Name) then
        if string.lower(msgdata.Message) == '>stop' then
            getgenv().stopped = true
            debounce = true
            task.wait(3)
            debounce = false
        end
    end

    if debounce or not string.match(msgdata.Message, '>lyrics ') or string.gsub(msgdata.Message, '>lyrics', '') == '' or game:GetService('Players')[msgdata.FromSpeaker] == game:GetService('Players').LocalPlayer then
        return
    end

    debounce = true
    local speaker = msgdata.FromSpeaker
    local msg = string.lower(msgdata.Message):gsub('>lyrics ', ''):gsub('"', ''):gsub(' by ', '/')
    local speakerDisplay = game:GetService('Players')[speaker].DisplayName
    plr = game:GetService('Players')[speaker].Name
    local songName, artist = string.match(msg, "(.-)/(.-)$")

    if songName and artist then
        songName = songName:gsub(" ", "%20"):lower()
        artist = artist:gsub(" ", "%20"):lower()
    else
        sendMessage('Invalid command format. Please use ">lyrics SongName by Artist"')
        task.wait(3)
        debounce = false
        return
    end

    local response
    local suc, er = pcall(function()
        response = httprequest({
            Url = "https://lyrist.vercel.app/api/" .. songName .. "/" .. artist,
            Method = "GET",
        })
    end)

    if not suc or not response or not response.Body then
        sendMessage('Unexpected error or empty response. Please retry.')
        task.wait(3)
        debounce = false
        return
    end

    local lyricsData = game:GetService('HttpService'):JSONDecode(response.Body)

    if not lyricsData or not lyricsData.lyrics then
        sendMessage('Failed to fetch lyrics. Please check the song and artist names.')
        task.wait(3)
        debounce = false
        return
    end

    local lyricsTable = {}

    if lyricsData.error and lyricsData.error == "Lyrics Not found" then
        debounce = true
        sendMessage('Lyrics were not found')
        task.wait(3)
        debounce = false
        return
    end

    for line in string.gmatch(lyricsData.lyrics, "[^\n]+") do
        table.insert(lyricsTable, line)
    end

    sendMessage('Fetched lyrics')
    task.wait(2)
    sendMessage('Playing song requested by ' .. speakerDisplay .. '. They can stop it by saying ">stop"')
    task.wait(3)

    for i, line in ipairs(lyricsTable) do
        if getgenv().stopped then
            getgenv().stopped = false
            break
        end

        sendMessage('🎙️ | ' .. line)
        task.wait(4.7)
    end

    task.wait(3)
    debounce = false
    sendMessage('Ended. You can request songs again.')
end)

task.spawn(function()
    while task.wait(60) do
        if not debounce then
            sendMessage('I am a lyrics bot! Type ">lyrics SongName" and I will sing the song for you!')
            task.wait(2)
            if not debounce then
                sendMessage('You can also do ">lyrics SongName by Artist"')
            end
        end
    end
end)

sendMessage('I am a lyrics bot! Type ">lyrics SongName" and I will sing the song for you!')
task.wait(2)
sendMessage('You can also do ">lyrics SongName by Artist"')
