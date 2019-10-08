local discord = ... --Passed as an argument.
local class = discord.class --Middleclass.
local bit = discord.utilities.bit --Universal bit API.

local band = bit.band

local message = class("discord.structures.Message")

--A function for verifying the arguments types of a method
local function Verify(value, name, ...)
    local vt, types = type(value), {...}
    for _, t in pairs(types) do if vt == t or (t=="nil" and not v) then return end end --Verified successfully
    types = table.concat(types, "/")
    local emsg = string.format("%s should be %s, provided: %s", name, types, vt)
    error(emsg, 3)
end

--REST Request with proper error handling (uses error level 3)
local function Request(endpoint, data, method, headers, useMultipart)
    local response_body, response_headers, status_code, status_line, failure_code, failure_line = discord.rest:request(endpoint, data, method, headers, useMultipart)
    if not response_body then
        error(response_headers, 3)
    else
        return response_body, response_headers, status_code, status_line
    end
end

--https://discordapp.com/developers/docs/resources/channel#message-object-message-flags
local messageFlags = {
    [1] = "CROSSPOSTED",
    [2] = "IS_CROSSPOST",
    [4] = "SUPPRESS_EMBEDS"
}

--New message object
function message:initialize(data, messageID)
    Verify(data, "data", "table", "string")

    if type(data) == "string" then
        Verify(messageID, "messageID", "string")

        local endpoint = string.format("/channels/%s/messages/%s", data, messageID)
        data = Request(endpoint)
    end

    --== Basic Fields ==--

    self.id = discord.snowflake(data.id) --ID of the message (snowflake)
    self.channelID = discord.snowflake(data.channel_id) --ID of the channel the message was sent in (snowflake)
    self.content = data.content --Contents of the message (string)
    self.timestamp = data.timestamp --When the message was sent (number)
    self.tts = data.tts --Whether this was a TTS message (boolean)
    self.mentionEveryone = data.mention_everyone --Where this message mentions everyone (boolean)
    self.pinned = data.pinned --Whether this message is pinned (boolean)
    self.type = discord.enums.messageTypes[data.type] --Type of message (string)

    --== Optional Fields ==--

    --The author of this message (not guaranteed to be a valid user) (user)
    if data.author then self.author = discord.user(data.author) end
    --ID of the guild the message was sent in (snowflake)
    if data.guild_id then self.guildID = discord.snowflake(data.guild_id) end
    --Member properties for this message's author (guild member)
    if data.member then self.member = discord.guildMember(data.member) end
    self.editedTimestamp = data.edited_timestamp --When the message was edited (or null if never) (number)
    if data.mentions then --Users specifically mentioned in the message (array of user objects)
        self.mentions = {}
        for id, udata in pairs(data.mentions) do
            self.mentions[id] = discord.user(udata)
        end
    end
    if data.mention_roles then --Roles specifically mentioned in this message (array of snowflake objects)
        self.mentionRoles = {}
        for id, snowflake in pairs(data.mention_roles) do
            self.mentionRoles[id] = discord.snowflake(snowflake)
        end
    end
    if data.attachments then --Any attached files (array of attachment objects)
        self.attachments = {}
        for id, adata in pairs(data.attachments) do
            self.attachments[id] = discord.attachment(adata)
        end
    end
    if data.embeds then --Any embedded (array of embed objects)
        self.embeds = {}
        for id, edata in pairs(data.embeds) do
            self.embeds = discord.embed(edata)
        end
    end
    if data.mention_channels then --Channels specifically mentioned in this message (array of channel mention objects)
        self.mentionChannels = {}
        for id, cmdata in pairs(data.mention_channels) do
            self.mentionChannels[id] = discord.channelMention(cmdata)
        end
    end
    if data.reactions then --Reactions to the message (array of reaction objects)
        self.reactions = {}
        for id, rdata in pairs(data.reactions) do
            self.reactions[id] = discord.reaction(rdata)
        end
    end
    --Used for validating a message was sent (snowflake)
    if data.nonce then self.nonce = discord.snowflake(data.nonce) end
    --If the message is generated by a webhook, this is the webhook's id (snowflake)
    if data.webhook_id then self.webhookID = discord.snowflake(data.webhook_id) end
    self.activity = data.activity --TODO: MESSAGE ACTIVITY OBJECT
    self.application = data.application --TODO: MESSAGE APPLICATION OBJECT
    self.messageReference = data.message_reference --TODO: MESSAGE REFERENCE OBJECT
    if data.flags then --Message flags, describes extra features of the message (array of strings)
        self.flags = {}
        for b, flag in pairs(messageFlags) do
            if band(data.flags,b) > 0 then
                self.flags[#self.flags + 1] = flag
            end
        end
    end
end

--== Methods ==--

--Adds a reaction
function message:addReaction(emoji)
    Verify(emoji, "emoji", "table", "string")
    if type(emoji) == "string" then
        emoji = discord.utilities.message.emojis[emoji] or emoji
    else
        emoji = emoji:getName()..":"..emoji:getID()
    end

    local endpoint = string.format("/channels/%s/messages/%s/reactions/%s/@me", tostring(self.channelID), tostring(self.id), emoji)
    Request(endpoint, nil, "PUT")
end

--Deletes the mesage
function message:delete()
    local endpoint = string.format("/channels/%s/messages/%s", tostring(self.channelID), tostring(self.id))
    Request(endpoint, nil, "DELETE")
end

--Edits the message
function message:edit(content, embed)
    Verify(content, "content", "string", "nil")
    Verify(embed, "embed", "table", "nil")

    if content and #content > 2000 then return error("Messages content can't be longer than 2000 characters!") end
    if content then content = discord.utilities.message.patchEmojis(content) end
    if embed then embed = embed:getAll() end

    local endpoint = string.format("/channels/%s/messages/%s", tostring(self.channelID), tostring(self.id))
    return discord.message(Request(endpoint, {content = content or nil, embed = embed or nil}, "PATCH"))
end

--Tells if a message is pinned or not
function message:isPinned() return self.pinned end

--Tells if the message has the text to speech
function message:isTTS() return self.tts end

--Tells if the user id is mentioned
function message:isUserMentioned(user)
    Verify(user, "user", "table")
    if not self.mentions then return false end --Can't know
    for k,v in pairs(self.mentions) do
        if v == user then return true end
    end
    return false
end

--Returns the author user object
function message:getAuthor() return self.author end

--Returns channel ID of which the message was sent in
function message:getChannelID() return self.channelID end

--Returns the message content
function message:getContent() return self.content end

--Returns the guild ID of the channel the message is sent in, would return nil for DM channels
function message:getGuildID() return self.guildID end

--Returns the ID of the message
function message:getID() return self.id end

--Returns the guild member of the message
function message:getMember() return self.member end

--Returns the list of specifically mentioned users ids
function message:getMentions()
    if not self.mentions then return {} end --Can't know
    local mentions = {}
    for k,v in pairs(self.mentions) do
        mentions[k] = v
    end
    return mentions
end

--Returns a basic channel object for ONLY replying
--Only the id field has a proper value, and the channel type is just set into GUILD_TEXT for messages with guild ID, and into DM for other messages
--Other channel fields are just nil
function message:getReplyChannel()
    return discord.channel{
        id = tostring(self.channelID),
        type = discord.enums.channelTypes[self.guildID and "GUILD_TEXT" or "DM"]
    }
end

--Returns the timestamp of the message
function message:getTimestamp() return self.timestamp end

--Returns the type of the message
function message:getType() return self.type end

return message