local N={history=setmetatable({},{__mode='k'}),seconds={
 AmmoCount=30,ChamberEmpty=15,GunJammed=15,Hungry=240,Thirst=180,Tired=240,Endurance=90,CantSprint=60,Pain=90,Injured=120,Bleeding=90,
 Hypothermia=180,Hyperthermia=180,Wet=240,Windchill=180,HeavyLoad=180,HasACold=240,
 Sick=180,SickFromFood=180,NoxiousSmell=180,Uncomfortable=180,Stress=180,Unhappy=240,
 Angry=120,Bored=300,Drunk=240,Agoraphobic=180,Claustrophobic=180}}
function N.ordinaryInterval(group,frequency)
 if group and group:match('^Relief') then return 10000 end
 return ({[0]=60000,[1]=30000,[2]=10000})[frequency] or 30000
end
function N.interval(group,level,frequency)
 if group=='GunJammed' then return 15000 end
 local base=N.seconds[group];if not base then return nil end
 local severity=math.max(1,math.min(4,tonumber(level) or 1))
 return base*1000*({1,.8,.6,.4})[severity]*({[0]=2,[1]=1,[2]=.5})[frequency or 1]
end
function N.remaining(player,group,level,frequency,now)
 local interval=N.interval(group,level,frequency);if not interval then return 0 end
 local old=(N.history[player] or {})[group];if not old then return 0 end
 -- Worsening can speak sooner, but never repeat within ten seconds.
 local gap=(level or 1)>old.level and math.min(interval,10000) or interval
 return math.max(0,gap-(now-old.at))
end
function N.mark(player,group,level,now)
 if not N.seconds[group] then return end
 N.history[player]=N.history[player] or {};N.history[player][group]={at=now,level=level or 1}
end
return N
