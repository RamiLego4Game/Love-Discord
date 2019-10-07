--Discörd Böt - A Basic Bot System

--Set the custom error handler
require("bot.error_handler")
--Load Discörd Library
local discord = require("discord")
--Load JSON library from the Discörd library
local json = require("discord.third-party.JSON")

--Load bot sub-systems
local pluginsManager = require("bot.plugins_manager")
local commandsManager = require("bot.commands_manager")
local dataStorage = require("bot.data_storage")

--BOT API
local botAPI = {}

--Initialize the bot and connect into Discord
function botAPI:initialize(args)
    self.args = args

    print("Loading configuration...")

    if not love.filesystem.getInfo("/bot/config.json") then error("Please create the bot configuration file at /bot/config.json, based on the file in /bot/config_template.json") end
    self.config = json:decode(love.filesystem.read("/bot/config.json"))

    print("Initializing...")

    self.discord = discord("Bot", self.config.bot.token, false, {
        payloadCompression = true, --Enable payload compression
        transportCompression = false, --Not implemented
        encoding = "json", --Only json is implemented for now
        autoReconnect = true,
        largeTreshold = 50,
        guildSubscriptions = false, --We don't want presence updates

        presence = {
            game = {
                name = "you 👀",
                type = 3 --Watching
            },
            status = "online",
            afk = false
        }
    })

    --Hook to get the bot user object
    self.discord:hookEvent("READY", function(data)
        self.me = data.user

        local gdata = dataStorage["bot/gateway"]
        
        gdata.url = self.discord.gateway.gatewayURL
        gdata.info = self.discord.gateway.gatewayInfo

        dataStorage["bot/gateway"] = gdata
    end)

    --Write a list of the guilds the bot is in
    self.discord:hookEvent("GUILD_CREATE", function(guild)
        local GLIST = dataStorage["bot/guilds"]

        local id, name = tostring(guild:getID()), tostring(guild)
        if not GLIST[id] or GLIST[id] ~= name then
            GLIST[id] = name
            dataStorage["bot/guilds"] = GLIST
        end
    end)

    pluginsManager:initialize()
    commandsManager:initialize()

    local gdata = dataStorage["bot/gateway"]

    if gdata.url and gdata.info then
        print("Using cached gateway url ;)")
        self.discord.gateway.gatewayURL = gdata.url
        self.discord.gateway.gatewayInfo = gdata.info
    end

    print("Connecting...")
    self.discord:connect()
    print("Connected :)")
end

--Tells if a provided snowflake is a developer one
function botAPI:isDeveloper(id)
    for k, devid in pairs(self.config.bot.developers) do
        if devid == id then return true end
    end
    return false
end

--Tells if a message is from a developer
function botAPI:isFromDeveloper(message)
    local authorID = tostring(message:getAuthor():getID())
    return self:isDeveloper(authorID)
end

--Update the bot
function botAPI:update(dt)
    dataStorage(dt)
    self.discord:update(dt)
end

--Quit the bot properly with the data saved
function botAPI:quit(a, ...)
    dataStorage(-2)
    self.discord:disconnect()
end

--Pass the BOT API
return botAPI