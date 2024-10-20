#
```
loadstring(game:HttpGet("https://raw.githubusercontent.com/goldyea/RobloxLyricsBot-NEW/refs/heads/main/lyricbot.lua",true))()
```

# Lyrics Bot Script

This Lua script is designed for a lyrics bot in a game. The bot fetches lyrics using an external API and plays them in the game chat.

- **Support or help with the script**: [Join our Discord](https://discord.gg/XC96e3m36c)
- **Status of the script**: ❎ Currently under maintenance and fixing

## Setup

1. Copy the script provided.
2. Integrate it into your game as needed.
3. Ensure the API endpoint in the script is correct and functional.

## Usage

Players can interact with the lyrics bot using the following commands in the game chat:

- `>lyrics "SongName"`: Fetch and play the lyrics for the specified song.
- `>lyrics "SongName" by "Artist"`: Fetch and play the lyrics for the song. (artist name is optional).
- `>stop`: Stop the lyrics playback at any time.

**Examples**:
- `>lyrics Shape of You`
- `>lyrics Shape of You" by "Ed Sheeran`

## API Endpoint

The script uses the Lyrist API to fetch lyrics. Make sure the API endpoint in the script is up-to-date and reachable. Please note that the artist's name is optional.

- **API Limit**: You can make up to 150 requests per hour to prevent abuse of the API.

## Notes

- Spaces in commands are handled automatically by the script.
- The bot sends status messages to the game chat, such as when lyrics are being fetched, when playback starts, or when an error occurs.
- Customize the script as needed to better fit your game environment.

## License

This script is provided under the [MIT License](LICENSE).
