function run(msg,matches)
  if is_sudo(msg) then
   local gps = redis:smembers("bot:users")
        if matches[1] == "brc" and matches[2] then
           for i=1, #gps do
        send_large_msg(gps[i],matches[2],ok_cb,false)
           end  
        return 'پیام به تمامی گروه ها ارسال شد.'
        end
    if matches[1] == 'ping' then
    return 'pong!'
    end
   end
end
local function pre_process(msg)
 if msg then
      local data = load_data(_config.moderation.data)
      local receiver = get_receiver(msg)
      local groups = 'groups'
      if not data[tostring(groups)] then
        data[tostring(groups)] = {}
        save_data(_config.moderation.data, data)
  end
      data[tostring(groups)][tostring(msg.to.id)] = msg.to.id
      save_data(_config.moderation.data, data)
end
  if not msg.text and msg.media then
    msg.text = '['..msg.media.type..']'
  end
   return msg
 end
return {
patterns = {
"^[!/#](brc) (.*)$",
"^[!/#](ping)$",
},
run = run,
  pre_process = pre_process

}