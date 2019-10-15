--Basic operations plugin
local botAPI, discord, pluginName, pluginPath, pluginDir = ...

local ffi = require("ffi")
local dataStorage = require("bot.data_storage")
local pluginsManager = require("bot.plugins_manager")
local commandsManager = require("bot.commands_manager")

local plugin = {}

--== Plugin Meta ==--

plugin.name = "Owner" --The visible name of the plugin
plugin.version = "V1.0.0" --The visible version string of the plugin
plugin.description = "Contains commands available only to the owners of the bot" --The description of the plugin
plugin.author = "Rami#8688" --Usually the discord tag of the author, but could be anything else
plugin.authorEmail = "ramilego4game@gmail.com" --The email of the auther, could be left empty

--== Commands ==--

--Shared embed, could be used by any command
local ownerEmbed = discord.embed()
ownerEmbed:setTitle("This command could be only used by the bot's owners :warning:")

plugin.commands = {}; local commands = plugin.commands

--Reload command
do
    local reloadEmbedSuccess = discord.embed()
    reloadEmbedSuccess:setTitle("Reloaded successfully :white_check_mark:")
    local reloadEmbedFailure = discord.embed()
    reloadEmbedFailure:setTitle("Failed to reload :warning:")

    function commands.reload(message, reply, commandName, ...)
        if not botAPI:isFromOwner(message) then reply:send(false, ownerEmbed) return end

        local ok, err = pluginsManager:reload()
        if ok then
            commandsManager:reloadCommands()
            reply:send(false, reloadEmbedSuccess)
        else
            reloadEmbedFailure:setDescription("||```\n"..err:gsub("plugin: ","plugin:\n").."\n```||")
            reply:send(false, reloadEmbedFailure)
        end
    end
end

function commands.stop(message, reply, commandName, ...)
    if not botAPI:isFromOwner(message) then reply:send(false, ownerEmbed) return end
    reply:send("Goodbye :wave:")
    love.event.quit()
end

--Restart command
do
    local restartEmbed = discord.embed()
    restartEmbed:setTitle(":gear: Restarting :gear:")
    restartEmbed:setDescription("This might take a while...")
    function commands.restart(message, reply, commandName, ...)
        if not botAPI:isFromOwner(message) then reply:send(false, ownerEmbed) return end
        
        love.event.quit("restart")

        local pdata = dataStorage["plugins/basic/restart"]
        pdata.channelID = tostring(message:getChannelID())
        pdata.timestamp = os.time()
        dataStorage["plugins/basic/restart"] = pdata

        reply:send(false, restartEmbed)
    end
end

function commands.dumpdata(message, reply, commandName, dname)
    if not botAPI:isFromOwner(message) then reply:send(false, ownerEmbed) return end
    if not dname then reply:send("Missing package name!") end

    local data = discord.json:encode_pretty(dataStorage[dname])
    local message = table.concat({
        "```json",
        data,
        "```"
    },"\n")
    
    if #message > 2000 then
        reply:send("Data too large, uploaded in a file :wink:", false, {dname:gsub("/","_")..".json",data})
    else
        reply:send(message)
    end
end

function commands.data(message, reply, commandName, action, dname)
    if not botAPI:isFromOwner(message) then reply:send(false, ownerEmbed) return end
end

--Execute command
do
    local executeUsage = discord.embed()
    executeUsage:setTitle("Usage: :notepad_spiral:")
    executeUsage:setDescription(table.concat({
        "```css",
        "execute <lua_code_block> [no_log]",
        "```"
    },"\n"))

    local errorEmbed = discord.embed()
    errorEmbed:setTitle("Failed to execute lua code :warning:")

    local outputEmbed = discord.embed()
    outputEmbed:setTitle("Executed successfully :white_check_mark:")

    function commands.execute(message, reply, commandName, luaCode, nolog, ...)
        if not botAPI:isFromOwner(message) then reply:send(false, ownerEmbed) return end
        if not luaCode then reply:send(false, executeUsage) return end

        local chunk, err = loadstring(luaCode, "codeblock")
        if not chunk then
            errorEmbed:setField(1, "Compile Error:", "```\n"..err:gsub('%[string "codeblock"%]', "").."\n```")
            reply:send(false, errorEmbed)
            return
        end

        local showOutput = false
        local output = {"```"}

        local env = {}
        local superEnv = _G
        setmetatable(env, { __index = function(t,k) return superEnv[k] end })

        env.botAPI, env.discord = botAPI, discord
        env.pluginsManager, env.commandsManager, env.dataStorage = pluginsManager, commandsManager, dataStorage
        env.message, env.reply = message, reply
        env.bit, env.http, env.rest = discord.utilities.bit, discord.utilities.http, discord.rest
        env.band, env.bor, env.lshift, env.rshift, env.bxor = env.bit.band, env.bit.bor, env.bit.lshift, env.bit.rshift, env.bit.bxor
        env.ffi = ffi
        env.print = function(...)
            local args = {...}; for k,v in pairs(args) do args[k] = tostring(v) end
            local msg = table.concat(args, " ")
            output[#output + 1] = msg
            showOutput = true
        end

        setfenv(chunk, env)

        local ok, rerr = pcall(chunk, ...)
        if not ok then
            errorEmbed:setField(1, "Runtime Error:", "```\n"..rerr:gsub('%[string "codeblock"%]', "").."\n```")
            reply:send(false, errorEmbed)
            return
        end

        if showOutput then
            env.print("```")
            outputEmbed:setField(1, "Output:", table.concat(output, "\n"))
        else
            outputEmbed:setField(1)
        end

        if tostring(nolog) == "true" then
            if message:getGuildID() then pcall(message.delete, message) end
        else
            reply:send(false, outputEmbed)
        end
    end
end

--Pulls the bot's git repository
do
    --Executes a command, and returns it's output
    local function capture(cmd, raw)
        local f = assert(io.popen(cmd, 'r'))
        local s = assert(f:read('*a'))
        f:close()
        if raw then return s end
        s = string.gsub(s, '^%s+', '')
        s = string.gsub(s, '%s+$', '')
        s = string.gsub(s, '[\n\r]+', ' ')
        return s
    end

    local resultEmbed = discord.embed()
    resultEmbed:setTitle("Execution output: :scroll:")

    function commands.gitpull(message, reply, commandName, ...)
        if not botAPI:isFromOwner(message) then reply:send(false, ownerEmbed) return end
        local output = capture("git -C "..love.filesystem.getSource().." pull")
        resultEmbed:setDescription("```\n"..output.."\n```")
        reply:send(false, resultEmbed)
    end
end

--CMD command
do
    --Executes a command, and returns it's output
    local function capture(cmd, raw)
        local f = assert(io.popen(cmd, 'r'))
        local s = assert(f:read('*a'))
        f:close()
        if raw then return s end
        s = string.gsub(s, '^%s+', '')
        s = string.gsub(s, '%s+$', '')
        s = string.gsub(s, '[\n\r]+', ' ')
        return s
    end

    local resultEmbed = discord.embed()
    resultEmbed:setTitle("Execution output: :scroll:")

    function commands.cmd(message, reply, commandName, ...)
        if not botAPI:isFromOwner(message) then reply:send(false, ownerEmbed) return end
        local cmd = table.concat({...}, " ")
        local output = capture(cmd)
        resultEmbed:setDescription("```\n"..output.."\n```")
        reply:send(false, resultEmbed)
    end
end

--== Plugin Events ==--

plugin.events = {}; local events = plugin.events

do
    local restartedEmbed = discord.embed()
    restartedEmbed:setTitle("Restarted Successfully :white_check_mark:")

    function events.READY(data)
        local pdata = dataStorage["plugins/basic/restart"]
        if pdata.channelID then
            local replyChannel = discord.channel{
                id = pdata.channelID,
                type = discord.enums.channelTypes["GUILD_TEXT"]
            }

            local delay = os.time() - pdata.timestamp
            restartedEmbed:setDescription("Operation took "..delay.." seconds:stopwatch:")

            pdata.channelID = nil
            pdata.timestamp = nil
            dataStorage["plugins/basic/restart"] = pdata

            pcall(replyChannel.send, replyChannel, false, restartedEmbed)
        end
    end
end

return plugin