local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local bot = script.Parent -- Assuming this script is a child of the bot model
local state = "saying" -- Initial state
local singing = false -- Flag to indicate if the bot is currently singing

-- Function to announce the bot's presence
local function announce()
    bot:Chat("🤖 | Lyrics bot! Type '>play [SongName]' or '>play [SongName]{Artist}' and I will sing it!")
end

-- Function to handle the singing of lyrics
local function singLyrics(lyrics)
    local lines = lyrics:split("\n") -- Split lyrics into lines
    singing = true -- Set singing flag
    for _, line in ipairs(lines) do
        if not singing then break end -- Exit if singing is stopped
        bot:Chat("🎙️ | " .. line)
        wait(2) -- Wait 2 seconds between lines
    end
    singing = false -- Reset singing flag
end

-- Function to handle commands
local function onPlayerChatted(player, message)
    if message == "" then return end -- Ignore empty messages

    -- Check if already singing
    if singing and message:lower() ~= ">stop" then
        bot:Chat("🎶 | I'm already singing! Use '>stop' to stop before playing a new song.")
        return
    end

    if state == "saying" then
        local songName, artist = message:match("^>play%s%[(.-)%]%{(.-)%}$")
        if songName and artist then
            local url = "https://lyrist.vercel.app/api/" .. HttpService:UrlEncode(songName) .. "/" .. HttpService:UrlEncode(artist)
            
            -- Fetch lyrics from the API
            local success, response = pcall(function()
                return HttpService:GetAsync(url)
            end)

            if not success then
                bot:Chat("⚠️ | Error fetching lyrics. Please try again.")
                return
            end

            local success, data = pcall(function()
                return HttpService:JSONDecode(response)
            end)

            if not success or not data.lyrics then
                bot:Chat("⚠️ | No lyrics found for that song.")
                return
            end

            -- Start singing
            state = "singing"
            singLyrics(data.lyrics)
            state = "saying" -- Return to saying state after singing
            announce()
        else
            bot:Chat("⚠️ | Invalid command format. Use '>play [SongName]{Artist}'.")
        end
    elseif state == "singing" and message:lower() == ">stop" then
        -- Stop singing immediately
        singing = false -- Stop singing
        bot:Chat("🎶 | Stopped singing. You can now request a new song.")
        state = "saying"
        announce()
    end
end

-- Connect player chat events
Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        onPlayerChatted(player, message)
    end)
end)

-- Announce bot on load
announce()

-- Repeat the announcement every 10 seconds
while true do
    wait(10)
    if state == "saying" then
        announce()
    end
end
