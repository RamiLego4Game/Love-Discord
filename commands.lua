local discord = ...

local http = require("socket.http")

local commands = {}

function commands.whatami(chid)
  discord.channels.createMessage(chid, "I'm a Discord bot written and running in LÖVE")
end

function commands.say(chid, data, ...)
  local msg = table.concat({...}," ")
  if msg:gsub("%s","") == "" then
    discord.channels.createMessage(chid, "[Invalid Message]")
  else
    discord.channels.createMessage(chid, msg)
  end
end

function commands.commands(chid)
  local cs = {}
  for k,v in pairs(commands) do
    table.insert(cs,k)
  end
  cs[#cs + 1] = "reload"
  local msg = "```\n"..table.concat(cs,", ").."\n```"
  discord.channels.createMessage(chid, msg)
end

function commands.stop(chid, data)
  if data.author.id == "207435670854041602" then
    discord.channels.createMessage(chid, "Goodbye !")
    print("Bot shutdown")
    discord.gateway.disconnect()
    love.event.quit()
  else
    discord.channels.createMessage(chid, "Only Rami can stop the bot !")
  end
end

function commands.urbanup(chid,data, ...)
  local term = table.concat({...}, " ")
  if term == "" then
    discord.channels.createMessage(chid, "Usage: `.urbanup <term\\>`")
    return
  end
  
  local res,code,headers,status = http.request("http://api.urbandictionary.com/v0/define?term="..discord.tools.urlEscape(term))
  
  --print(res,code,headers,status)
  
  if res then
    local res = discord.json:decode(res)
    if res.result_type == "no_results" then
      discord.channels.createMessage(chid, "No results found.")
    else
      local best = 1
      local best_score = res.list[1].thumbs_up - res.list[1].thumbs_down
      for k,v in ipairs(res.list) do
        local score = v.thumbs_up - v.thumbs_down
        if score > best_score then
          best = k
          best_score = score
        end
      end
    
    local def = res.list[best]
    local deftext = def.definition
    if #deftext > 512 then deftext = deftext:sub(1,512).."..." end
    
    discord.channels.createMessage(chid, "", {
      title='"'..def.word..'" #'..def.defid,
      type="rich",
      description=deftext,
      url=def.permalink,
      color = 0x23A9E0,
      author = {name="Author: "..def.author,url="https://www.urbandictionary.com/author.php?author="..discord.tools.urlEscape(def.author)},
      fields = {{name="Example:",value=def.example or "[NONE]"},
        {name="Tags:",value=table.concat(res.tags, ", ")},
        {name="Thumbs Up 👍:",value=def.thumbs_up,inline=true},
        {name="Thumbs Down 👎:",value=def.thumbs_down,inline=true}}
      })
    end
  else
    discord.channels.createMessage(chid, "Failed ! `"..tostring(code).."`")
  end
end

return commands