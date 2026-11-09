local UI=require 'CSV/DebugUI'
local function tr(key)return UI.text(key)end
local T={cases={
 {name='Ammo in magazine, empty chamber',group='OutOfAmmo',level=1,max=1,state={empty=false,hasChamber=true,rounds=5,chamber=false},expect='none'},
 {name='Gun fully empty',group='OutOfAmmo',level=1,max=1,state={empty=true,rounds=0,chamber=false},expect='OutOfAmmo'},
 {name='Chambered last round',group='OutOfAmmo',level=1,max=1,state={empty=false,rounds=0,chamber=true},expect='none'},
 {name='Bleeding, no bandage',group='Bleeding',level=2,max=4,state={bandages=0,dirty=0,bleeding=1},expect='Bleeding_1'},
 {name='Dirty bandage (not proof of soaked blood)',group='Bleeding',level=2,max=4,state={bandages=1,dirty=1,bleeding=1},expect='Bleeding_1'},
 {name='One zombie, repeated hits',group='MultiHit',level=1,max=1,state={crowd=1,near=1},expect='none'},
 {name='Three visible zombies within 3 tiles',group='MultiHit',level=1,max=1,state={crowd=3,reactiveCrowd=3,near=3},expect='MultiHit'},
 {name='Container generated, no pickup',group='FoundLoot',level=1,max=1,state={pickup=false},expect='Explore_2'},
 {name='Item transfer confirmed',group='FoundLoot',level=1,max=1,state={pickup=true},expect='FoundLoot_3'},
 {name='Tree still standing',group='ChopTree',level=1,max=1,state={treeDown=false},expect='ChopTree'},
 {name='Tree removed after your axe hit',group='ChopTree',level=1,max=1,state={treeDown=true},expect='ChopTree_3'},
 {name='Wet but warm',group='Wet',level=4,max=4,state={cold=0},expect='Wet_2'},
 {name='Wet and hypothermic',group='Wet',level=4,max=4,state={cold=3},expect='Wet_3'},
 {name='High panic, no external threat',group='Panic',level=4,max=4,state={fire=false,visible=0,recentThreat=false,near=0},expect='PanicGrounding_1',limited='Panic_3'},
 {name='High panic, visible close zombie',group='Panic',level=4,max=4,state={fire=false,visible=1,recentThreat=true,near=1},expect='PanicEscape_1',limited='Panic_3'},
 {name='On fire, no zombies',group='Panic',level=4,max=4,state={fire=true,visible=0,recentThreat=false,near=0},expect='Panic_3'},
 {name='Severe thirst',group='Thirst',level=4,max=4,state={},expect='ThirstCritical_1',limited='Thirst_2'},
 {name='Unknown weapon API',group='OutOfAmmo',level=1,max=1,state={},expect='none'}
}}
-- Delivery checks exercise the same policy as gameplay. They do not fake player state.
local function add(c)T.cases[#T.cases+1]=c end
add{name='Hidden, high panic, two close zombies',group='Panic',level=4,max=4,state={sneaking=true,panic=4,near=2,visible=2,recentThreat=true},expect='PanicEscape_1',limited='Panic_3',mode='silent'}
add{name='Standing, high panic, two close zombies',group='Panic',level=4,max=4,state={sneaking=false,panic=4,near=2,visible=2,recentThreat=true},expect='PanicEscape_1',limited='Panic_3',mode='spoken',radius=15}
add{name='No panic moodle, close threat warning',group='Threat',level=1,max=4,state={sneaking=false,panic=0,near=2,visible=2,recentThreat=true},expect='Panic_2',mode='spoken',radius=6}
add{name='Hidden, no panic, close threat',group='Threat',level=1,max=4,state={sneaking=true,panic=0,near=2,visible=2,recentThreat=true},expect='Panic_2',mode='silent'}
add{name='Distant zombies do not trigger close warning',group='Threat',level=1,max=4,state={sneaking=false,panic=0,near=0,visible=2},expect='none',mode='silent'}
add{name='Low panic near threat gives tense warning',group='Panic',level=1,max=4,state={sneaking=false,panic=1,near=2,visible=2,recentThreat=true},expect='Panic_1',mode='spoken'}
add{name='Unknown panic cannot invent calm warning',group='Threat',level=1,max=4,state={sneaking=false,near=2,visible=2},expect='none',mode='silent'}
add{name='Unknown concealment cannot force speech',group='Panic',level=4,max=4,state={panic=4,near=2,visible=2,recentThreat=true},expect='PanicEscape_1',limited='Panic_3',mode='upstream'}
add{name='Agoraphobic: Safe',group='Agoraphobic',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Agoraphobic: Hidden',group='Agoraphobic',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Agoraphobic: Close threat',group='Agoraphobic',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Angry: Safe',group='Angry',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Angry: Hidden',group='Angry',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Angry: Close threat',group='Angry',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='AnimalTracks: Safe',group='AnimalTracks',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='AnimalTracks: Hidden',group='AnimalTracks',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='AnimalTracks: Close threat',group='AnimalTracks',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Bleeding: Safe',group='Bleeding',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Bleeding: Hidden',group='Bleeding',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Bleeding: Close threat',group='Bleeding',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='spoken'}
add{name='Bored: Safe',group='Bored',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Bored: Hidden',group='Bored',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Bored: Close threat',group='Bored',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='CantSprint: Safe',group='CantSprint',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='CantSprint: Hidden',group='CantSprint',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='CantSprint: Close threat',group='CantSprint',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='spoken'}
add{name='ChopTree: Safe',group='ChopTree',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='ChopTree: Hidden',group='ChopTree',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='ChopTree: Close threat',group='ChopTree',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Claustrophobic: Safe',group='Claustrophobic',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Claustrophobic: Hidden',group='Claustrophobic',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Claustrophobic: Close threat',group='Claustrophobic',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Drunk: Safe',group='Drunk',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Drunk: Hidden',group='Drunk',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Drunk: Close threat',group='Drunk',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Endurance: Safe',group='Endurance',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Endurance: Hidden',group='Endurance',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Endurance: Close threat',group='Endurance',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='spoken'}
add{name='Explore: Safe',group='Explore',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Explore: Hidden',group='Explore',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Explore: Close threat',group='Explore',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='FoodEaten: Safe',group='FoodEaten',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='FoodEaten: Hidden',group='FoodEaten',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='FoodEaten: Close threat',group='FoodEaten',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='FoodRaw: Safe',group='FoodRaw',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='FoodRaw: Hidden',group='FoodRaw',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='FoodRaw: Close threat',group='FoodRaw',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='FoodRotten: Safe',group='FoodRotten',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='FoodRotten: Hidden',group='FoodRotten',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='FoodRotten: Close threat',group='FoodRotten',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Foraged: Safe',group='Foraged',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Foraged: Hidden',group='Foraged',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Foraged: Close threat',group='Foraged',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='FoundLoot: Safe',group='FoundLoot',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='FoundLoot: Hidden',group='FoundLoot',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='FoundLoot: Close threat',group='FoundLoot',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='GunJammed: Safe',group='GunJammed',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='GunJammed: Hidden',group='GunJammed',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='GunJammed: Close threat',group='GunJammed',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='spoken'}
add{name='HasACold: Safe',group='HasACold',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='HasACold: Hidden',group='HasACold',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='HasACold: Close threat',group='HasACold',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='HeavyLoad: Safe',group='HeavyLoad',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='HeavyLoad: Hidden',group='HeavyLoad',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='HeavyLoad: Close threat',group='HeavyLoad',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Holes: Safe',group='Holes',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Holes: Hidden',group='Holes',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Holes: Close threat',group='Holes',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Hungry: Safe',group='Hungry',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Hungry: Hidden',group='Hungry',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Hungry: Close threat',group='Hungry',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Hyperthermia: Safe',group='Hyperthermia',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Hyperthermia: Hidden',group='Hyperthermia',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Hyperthermia: Close threat',group='Hyperthermia',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Hypothermia: Safe',group='Hypothermia',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Hypothermia: Hidden',group='Hypothermia',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Hypothermia: Close threat',group='Hypothermia',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Injured: Safe',group='Injured',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Injured: Hidden',group='Injured',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Injured: Close threat',group='Injured',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='spoken'}
add{name='Kill: Safe',group='Kill',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Kill: Hidden',group='Kill',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Kill: Close threat',group='Kill',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='LevelUp: Safe',group='LevelUp',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='LevelUp: Hidden',group='LevelUp',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='LevelUp: Close threat',group='LevelUp',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='LowAmmo: Safe',group='LowAmmo',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='LowAmmo: Hidden',group='LowAmmo',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='LowAmmo: Close threat',group='LowAmmo',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='spoken'}
add{name='MultiHit: Safe',group='MultiHit',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=1,reactiveCrowd=0,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='none'}
add{name='MultiHit: Hidden',group='MultiHit',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=1,reactiveCrowd=0,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='none'}
add{name='MultiHit: Close threat',group='MultiHit',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,reactiveCrowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='spoken'}
add{name='NoxiousSmell: Safe',group='NoxiousSmell',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='NoxiousSmell: Hidden',group='NoxiousSmell',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='NoxiousSmell: Close threat',group='NoxiousSmell',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='OnDawn: Safe',group='OnDawn',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='OnDawn: Hidden',group='OnDawn',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='OnDawn: Close threat',group='OnDawn',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='OnDusk: Safe',group='OnDusk',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='OnDusk: Hidden',group='OnDusk',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='OnDusk: Close threat',group='OnDusk',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='OutOfAmmo: Safe',group='OutOfAmmo',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='OutOfAmmo: Hidden',group='OutOfAmmo',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='OutOfAmmo: Close threat',group='OutOfAmmo',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='spoken'}
add{name='Pain: Safe',group='Pain',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Pain: Hidden',group='Pain',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Pain: Close threat',group='Pain',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='spoken'}
add{name='Panic: Safe',group='Panic',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Panic: Hidden',group='Panic',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Panic: Close threat',group='Panic',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='spoken'}
add{name='PanicCallback: Safe',group='PanicCallback',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='PanicCallback: Hidden',group='PanicCallback',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='PanicCallback: Close threat',group='PanicCallback',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='spoken'}
add{name='Sick: Safe',group='Sick',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Sick: Hidden',group='Sick',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Sick: Close threat',group='Sick',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='SickFromFood: Safe',group='SickFromFood',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='SickFromFood: Hidden',group='SickFromFood',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='SickFromFood: Close threat',group='SickFromFood',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Stress: Safe',group='Stress',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Stress: Hidden',group='Stress',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Stress: Close threat',group='Stress',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Thirst: Safe',group='Thirst',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Thirst: Hidden',group='Thirst',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Thirst: Close threat',group='Thirst',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Tired: Safe',group='Tired',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Tired: Hidden',group='Tired',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Tired: Close threat',group='Tired',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Uncomfortable: Safe',group='Uncomfortable',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Uncomfortable: Hidden',group='Uncomfortable',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Uncomfortable: Close threat',group='Uncomfortable',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Unhappy: Safe',group='Unhappy',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Unhappy: Hidden',group='Unhappy',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Unhappy: Close threat',group='Unhappy',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='VehicleDamage: Safe',group='VehicleDamage',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='VehicleDamage: Hidden',group='VehicleDamage',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='VehicleDamage: Close threat',group='VehicleDamage',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='spoken'}
add{name='Wet: Safe',group='Wet',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Wet: Hidden',group='Wet',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Wet: Close threat',group='Wet',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Windchill: Safe',group='Windchill',level=4,max=4,state={sneaking=false,panic=0,near=0,visible=0,recentThreat=false,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='upstream'}
add{name='Windchill: Hidden',group='Windchill',level=4,max=4,state={sneaking=true,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Windchill: Close threat',group='Windchill',level=4,max=4,state={sneaking=false,panic=4,near=3,visible=3,recentThreat=true,crowd=3,empty=true,pickup=true,treeDown=true,cold=3,fire=false},expect='eligible_or_none',mode='silent'}
add{name='Fire while hidden is involuntary',group='Panic',level=4,max=4,state={sneaking=true,fire=true,panic=4,near=0},expect='Panic_3',mode='spoken',radius=15}
add{name='Fresh injury while hidden is involuntary',group='AcutePain',level=4,max=4,state={sneaking=true,acute=true,panic=0,near=0},expect='Pain_3',mode='spoken',radius=8}
add{name='Stale injury is not a fresh cry',group='AcutePain',level=4,max=4,state={sneaking=true,acute=false},expect='none',mode='silent'}
add{name='Window blocks close warning',group='Threat',level=1,max=4,state={sneaking=false,panic=0,near=1,accessibleNear=0,blockedNear=1,visible=1},expect='none',mode='silent'}
add{name='Safe comments enabled',group='Thirst',level=1,max=4,state={sneaking=false,near=0,visible=0,recentThreat=false},prefs={safeSpeech=true},expect='Thirst_1',mode='spoken',radius=4}
add{name='Whisper unavailable stays silent',group='Threat',level=1,max=4,state={sneaking=true,panic=0,near=1},prefs={whisper=true},expect='Panic_2',mode='silent'}
add{name='Transition: calm, threat, panic, hiding, fire',steps={
 {group='FoundLoot',level=1,max=1,state={sneaking=false,near=0,visible=0,recentThreat=false,pickup=true},prefs={safeSpeech=true},expect='FoundLoot_3',mode='spoken'},
 {group='Threat',level=1,max=4,state={sneaking=false,panic=0,near=2,visible=2},expect='Panic_2',mode='spoken'},
 {group='Threat',level=2,max=4,state={sneaking=false,panic=2,near=2,visible=2},expect='Panic_2',mode='spoken'},
 {group='Panic',level=4,max=4,state={sneaking=false,panic=4,near=2,visible=2,recentThreat=true},expect='PanicEscape_1',limited='Panic_3',mode='spoken'},
 {group='Panic',level=4,max=4,state={sneaking=true,panic=4,near=2,visible=2,recentThreat=true},expect='PanicEscape_1',limited='Panic_3',mode='silent'},
 {group='Panic',level=4,max=4,state={sneaking=true,fire=true,panic=4,near=2},expect='Panic_3',mode='spoken'}
}}
-- Explicit measured zombie behavior. These are selection tests, not fabricated live events.
add{name='Nearby zombie observed, no pursuit',group='Threat',level=1,max=4,state={sneaking=false,panic=0,near=1,visible=1,accessibleNear=1,reactiveNear=0,targeted=0,approaching=0,attacking=0},expect='ThreatCalm',limited='Panic_2',mode='spoken',radius=4}
add{name='High panic but zombie not pursuing',group='Panic',level=4,max=4,state={sneaking=false,panic=4,near=1,visible=1,accessibleNear=1,reactiveNear=0,targeted=0,approaching=0,attacking=0},expect='eligible_or_none',mode='silent'}
add{name='Attacking player with high panic',group='Panic',level=4,max=4,state={sneaking=false,panic=4,near=1,visible=1,accessibleNear=1,reactiveNear=1,targeted=1,approaching=0,attacking=1},expect='PanicEscape_1',limited='Panic_3',mode='spoken',radius=15}
add{name='Threat motion not measured yet',group='Threat',level=1,max=4,state={sneaking=false,panic=0,near=1,accessibleNear=1,targeted=0},expect='eligible_or_none',mode='silent'}
add{name='Recovered: Hungry',group='ReliefHunger',level=1,max=1,state={sneaking=false,near=0,visible=0,recentThreat=false,hunger=0},expect='ReliefHunger',limited='none'}
add{name='Recovered: Hypothermia',group='ReliefCold',level=1,max=1,state={sneaking=false,near=0,visible=0,recentThreat=false,cold=0},expect='ReliefCold',limited='none'}
add{name='Recovered: Hyperthermia',group='ReliefHeat',level=1,max=1,state={sneaking=false,near=0,visible=0,recentThreat=false,heat=0},expect='ReliefHeat',limited='none'}
add{name='Recovered: Tired',group='ReliefRest',level=1,max=1,state={sneaking=false,near=0,visible=0,recentThreat=false,tired=0},expect='ReliefRest',limited='none'}
add{name='Recovered: Pain',group='ReliefPain',level=1,max=1,state={sneaking=false,near=0,visible=0,recentThreat=false,pain=0},expect='ReliefPain',limited='none'}
add{name='Recovered: Stress',group='ReliefStress',level=1,max=1,state={sneaking=false,near=0,visible=0,recentThreat=false,stress=0},expect='ReliefStress',limited='none'}
add{name='Recovered: Wet',group='ReliefWet',level=1,max=1,state={sneaking=false,near=0,visible=0,recentThreat=false,wet=0},expect='ReliefWet',limited='none'}
add{name='Recovered: HeavyLoad',group='ReliefLoad',level=1,max=1,state={sneaking=false,near=0,visible=0,recentThreat=false,load=0},expect='ReliefLoad',limited='none'}
add{name='Recovered: Sick',group='ReliefSickness',level=1,max=1,state={sneaking=false,near=0,visible=0,recentThreat=false,sick=0},expect='ReliefSickness',limited='none'}
add{name='Recovered: HasACold',group='ReliefColdSymptoms',level=1,max=1,state={sneaking=false,near=0,visible=0,recentThreat=false,coldSymptoms=0},expect='ReliefColdSymptoms',limited='none'}
add{name='Recovered: Unhappy',group='ReliefMood',level=1,max=1,state={sneaking=false,near=0,visible=0,recentThreat=false,unhappy=0},expect='ReliefMood',limited='none'}
add{name='Recovered: Uncomfortable',group='ReliefDiscomfort',level=1,max=1,state={sneaking=false,near=0,visible=0,recentThreat=false,discomfort=0},expect='ReliefDiscomfort',limited='none'}
function T.each(fn)
 for i,c in ipairs(T.cases)do for _,voice in ipairs(require('CSV/Pack').voiceOrder)do for step=1,#(c.steps or {c})do fn(i,voice,step)end end end
end
function T.totalChecks()local count=0;T.each(function()count=count+1 end);return count end
for _,item in ipairs({{'Anger','anger'},{'Boredom','boredom'},{'Sobriety','drunk'}})do
 add{name='Recovered: '..item[1],group='Relief'..item[1],level=1,max=1,state={sneaking=false,near=0,visible=0,recentThreat=false,[item[2]]=0},expect='Relief'..item[1],limited='none'}
end
add{name='Weapon jam, calm and safe',group='GunJammed',level=1,max=1,state={jammed=true,sneaking=false,panic=0,near=0,visible=0,recentThreat=false},expect='GunJammed',mode='spoken',prefs={safeSpeech=true}}
add{name='Weapon jam, high panic under attack',group='GunJammed',level=1,max=1,state={jammed=true,sneaking=false,panic=4,near=1,reactiveNear=1,targeted=1,attacking=1},expect='GunJammed',mode='spoken'}
add{name='Weapon jam, angry but no panic',group='GunJammed',level=1,max=1,state={jammed=true,sneaking=false,panic=0,anger=3,near=1,reactiveNear=1},expect='GunJammed',mode='spoken'}
add{name='Weapon jam while hidden',group='GunJammed',level=1,max=1,state={jammed=true,sneaking=true,panic=4,near=1,reactiveNear=1},expect='GunJammed',prefs={whisper=true}}
add{name='Empty gun is not a jam',group='GunJammed',level=1,max=1,state={jammed=false,empty=true},expect='none'}
add{name='Jammed and empty prioritizes jam',group='OutOfAmmo',level=1,max=1,state={jammed=true,empty=true},expect='none'}
add{name='Cleared jam cannot announce jam',group='GunJammed',level=1,max=1,state={jammed=false},expect='none'}
for _,n in ipairs({1,5,30,100,150})do
 add{name='Magazine count '..n,group='AmmoCount',level=1,max=1,state={rounds=n,jammed=false,sneaking=false,near=1,reactiveNear=1,panic=0},expect=require('CSV/AmmoCounts').contains(n) and ('AmmoCount_'..n) or 'AmmoReserve',limited='none',newConditions=true}
end
add{name='Empty chamber with rounds available',group='ChamberEmpty',level=1,max=1,state={hasChamber=true,chamber=false,rounds=5,jammed=false,sneaking=false,near=1,panic=0},expect='ChamberEmpty',limited='none',newConditions=true}
add{name='Three nearby zombies without pursuit after hits',group='MultiHit',level=1,max=1,state={crowd=3,reactiveCrowd=0,near=3,targeted=0,approaching=0,sneaking=false,panic=0},expect='RepeatedHit',limited='none',newConditions=true}
add{name='Drunk safe exploration',group='Explore',level=1,max=1,state={drunk=3,sneaking=false,near=0,visible=0,recentThreat=false,panic=0},expect='eligible_or_none',prefs={safeSpeech=true},newConditions=true}
add{name='Congested food sickness without claiming cause',group='SickFromFood',level=3,max=4,state={coldSymptoms=2,sneaking=false,near=0,visible=0,recentThreat=false,panic=0},expect='FoodSuspect',limited='SickFromFood',prefs={safeSpeech=true},newConditions=true}
for _,case in ipairs(require('CSV/LootScenarios').cases())do add(case)end
for _,case in ipairs(require('CSV/OutcomeScenarios').cases())do add(case)end
for _,case in ipairs(require('CSV/TraitScenarios').cases())do add(case)end
for _,case in ipairs(require('CSV/PsychologyScenarios').cases())do add(case)end
for _,case in ipairs(require('CSV/AlertScenarios').cases())do add(case)end
for _,case in ipairs(require('CSV/ConcealmentScenarios').cases())do add(case)end
for _,case in ipairs(require('CSV/EngagementScenarios').cases())do add(case)end
local function evaluate(player,voice,index,live,step)
 local V=require 'CSV/Core';local parent=T.cases[index];step=step or 1;local c=parent.steps and parent.steps[step] or parent
 if not V.available() then return {pass=false,skipped=true,line=nil,facts=c.state,expected=c.expect,live=live,case=c,decision={mode='silent',reason='voice_pack_unavailable'},name=parent.name,step=step,stepCount=#(parent.steps or {parent})}end
 if c.newLoot and not require('CSV/Extras').approved then return {pass=false,skipped=true,line=nil,facts=c.state,expected='loot bank disabled',live=live,case=c,decision={mode='silent',reason='loot_bank_disabled'},name=parent.name,step=step,stepCount=1} end
 if c.newConditions and not require('CSV/Conditions').enabled then return {line=nil,facts=c.state,expected='new conditions disabled',pass=false,skipped=true,live=live,case=c,decision={mode='silent',reason='new_conditions_disabled'},name=parent.name,step=step,stepCount=1} end
 if (c.newOutcomes or c.newPsychology) and not require('CSV/Extras').approved then return {pass=false,skipped=true,line=nil,facts=c.state,expected='outcome bank disabled',live=live,case=c,decision={mode='silent',reason='outcome_bank_disabled'},name=parent.name,step=step,stepCount=1} end
 if c.newTraits and (not V.extended(voice) or not require('CSV/Extras').approved or c.state.sneaking and not require('CSV/Whispers').approved) then return {pass=false,skipped=true,line=nil,facts=c.state,expected=c.expect,live=live,case=c,decision={mode='silent',reason='trait_bank_disabled'},name=parent.name,step=step,stepCount=1}end
 local facts=live and require('CSV/State').capture(player) or c.state
 local savedHistory=V.client.history[player]
 if not live then
  V.client.history[player]={}
  for _,id in ipairs(c.seedSeen or {})do local entry=require('CSV/Extras').catalog[id];if entry then V.client.remember(player,id,entry)end end
 end
 local ok,line,decision=pcall(V.client.plan,player,voice,c.group,c.level,c.max,facts,live and V.client.preferences() or c.prefs)
 if not live then V.client.history[player]=savedHistory end
 if not ok then error(line)end
 if not line then decision={mode='silent',reason='no_eligible_recording'} end
 if c.newConcealment then
  local available=V.extended(voice) and require('CSV/Whispers').approved and require('CSV/Extras').approved
  local whisper=line and V.delivery(voice,line.id)=='whisper'
  local pass=available and line~=nil and decision.mode==c.mode and decision.radius==c.radius and whisper==c.expectWhisper and (not c.sharedDanger or line.id:match('^MortalFear_')~=nil)
  return {line=line,facts=facts,expected=(c.expectWhisper and 'whisper' or 'normal')..', radius '..tostring(c.radius),pass=pass==true,skipped=not available,live=live,case=c,decision=decision,name=parent.name,step=step,stepCount=1}
 end
 local expected=not V.extended(voice) and (c.limited or c.expect) or c.expect
 if c.expect=='ThreatCalm' and not require('CSV/Extras').approved then expected='Panic_2' end
 if (c.name or ''):match('^Recovered:') and not require('CSV/Extras').approved then expected='none' end
 if V.extended(voice) and require('CSV/Conditions').enabled and c.group=='OutOfAmmo' and facts.hasChamber==true and facts.chamber==false and (facts.rounds or 0)>0 and facts.jammed~=true then expected='ChamberEmpty' end
 local expectedMode=c.mode
 if (c.newLoot or c.newOutcomes or c.newPsychology) and (not V.extended(voice) or (facts.sneaking and not require('CSV/Whispers').approved)) then expectedMode=(not V.extended(voice) and c.legacyMode) or 'silent' end
 if not c.newTraits and V.extended(voice) and require('CSV/Extras').approved then
  if c.group=='Panic' and facts.fire then expected='Fire'
  elseif c.group=='AcutePain' and facts.acute then expected='InjuryAcute'
  elseif c.group=='Threat' and type(facts.panic)=='number' and facts.panic<3 and (facts.accessibleNear or facts.near or 0)>0 then expected=facts.panic==0 and 'ThreatCalm' or 'ThreatTense'
  elseif c.group=='Panic' and (facts.near or 0)>0 and (facts.panic or 0)>0 and facts.panic<3 then expected='ThreatTense'
  elseif c.group=='MultiHit' and (facts.reactiveCrowd or 0)<3 then expected='RepeatedHit'
  elseif c.group=='Uncomfortable' and c.mode=='silent' and facts.sneaking==false and facts.near==0 then expectedMode='upstream' end
  if c.prefs and c.prefs.whisper and facts.sneaking and (facts.near or 0)>0 and (c.group=='Threat' or c.group=='Panic') then expected='ThreatWhisper';expectedMode='spoken' end
 end
 if V.extended(voice) and require('CSV/Extras').approved then expected=expected:gsub('ThirstCritical_1$','ThirstCritical'):gsub('PanicGrounding_1$','PanicGrounding'):gsub('PanicEscape_1$','PanicEscape') end
 local compatibility=c.expect=='eligible_or_none' or facts.sneaking==true and not (c.newLoot or c.newOutcomes or c.newPsychology or c.newConcealment or c.newTraits)
 local selected=line and (require('CSV/Expressions').source(line.id) or line.id)
 -- New exact fixtures declare whisper intent themselves. Never derive expectations
 -- from the production decision reason.
 local expectsWhisper=(c.newLoot or c.newOutcomes or c.newPsychology or c.newTraits) and facts.sneaking==true and c.prefs and c.prefs.whisper==true and expectedMode=='spoken'
 if expectsWhisper and selected then selected=selected:gsub('^Whisper_','') end
 local pass=expected=='eligible_or_none' or expected=='none' and line==nil or line and (selected==expected or selected:sub(1,#expected+1)==expected..'_')
 if expectedMode then pass=pass and decision.mode==expectedMode end
 if c.radius then pass=pass and decision.radius==c.radius end
 if expectsWhisper then pass=pass and line~=nil and V.delivery(voice,line.id)=='whisper' end
 return {line=line,facts=facts,expected=expected,pass=pass==true,compatibility=compatibility==true,live=live,case=c,decision=decision,name=parent.name,step=step,stepCount=#(parent.steps or {parent})}
end
-- A simulated match, an unavailable configuration and a live snapshot are different evidence.
function T.evaluate(player,voice,index,live,step)
 local result=evaluate(player,voice,index,live,step);result.voice=voice
 if result.skipped then result.status='skipped';result.pass=false
 elseif live then result.status='live';result.pass=false
 elseif result.compatibility then result.status='compatibility';result.pass=false
 else result.status=result.pass and 'pass' or 'fail' end
 return result
end
function T.summary(player,visit)
 local counts={passed=0,failed=0,skipped=0,compatibility=0}
 T.each(function(i,voice,step)
  local result=T.evaluate(player,voice,i,false,step)
  if result.status=='skipped' then counts.skipped=counts.skipped+1
  elseif result.status=='compatibility' then counts.compatibility=counts.compatibility+1
  elseif result.pass then counts.passed=counts.passed+1 else counts.failed=counts.failed+1 end
  if visit then visit(result,voice,step)end
 end)
 return counts
end
function T.export(f,player)
 f:write('\nSCENARIOS: simulated selection, not proof of live events.\n')
 local function emit(fn)if type(f)=='table' and f.defer then f:defer(fn)else f:write(fn())end end
 local counts={passed=0,failed=0,skipped=0,compatibility=0}
 -- Evaluation itself belongs inside the writer's time budget, not just formatting.
 T.each(function(index,voice,step)
  emit(function()
   local result=T.evaluate(player,voice,index,false,step)
   local key=({pass='passed',fail='failed'})[result.status] or result.status
   counts[key]=counts[key]+1
   return voice..' | '..result.name..' step '..step..' | '..string.upper(result.status)..' | '..(result.line and result.line.id or 'none')..' | '..result.decision.mode..' | '..result.decision.reason..'\n'
  end)
 end)
 emit(function()return 'SCENARIO_SUMMARY passed='..counts.passed..' failed='..counts.failed..' skipped='..counts.skipped..' compatibility='..counts.compatibility..' total='..T.totalChecks()..'\n'end)
 local result=T.panel and T.panel.result
 if result then
  f:write('Last scenario '..result.name..' live='..tostring(result.live)..'\n')
  for key,value in pairs(result.facts)do if type(value)~='table' then f:write(key..'='..tostring(value)..'\n')end end
 end
end
function T.open(player)
 require 'ISUI/ISPanel';require 'ISUI/ISComboBox';require 'ISUI/ISButton'
 local V=require 'CSV/Core'
 if T.panel then if T.panel.stopPreview then T.panel.stopPreview()end;T.panel:removeFromUIManager()end
 local panel=ISPanel:new(100,80,900,425);panel:initialise();panel:instantiate();panel.moveWithMouse=true
 panel.backgroundColor={r=.06,g=.06,b=.06,a=.97};T.panel=panel
 local choice=ISComboBox:new(20,55,490,28,panel,nil);choice:initialise();panel:addChild(choice)
 for i,c in ipairs(T.cases)do local event=c.group or (c.steps and c.steps[1].group) or '?';choice:addOption(tostring(i)..' - '..event)end
 local voice=ISComboBox:new(530,55,210,28,panel,nil);voice:initialise();panel:addChild(voice);for _,id in ipairs(require('CSV/Pack').voiceOrder)do voice:addOption(require('CSV/Pack').voices[id].name)end
 panel.message=tr('Ready')
 local function stopPreview()
  for _,e in ipairs(V.client.active)do if e==panel.playback and e.preview then V.client.cancel(e,'preview_stopped',false);break end end
  panel.playback=nil
 end
 panel.stopPreview=stopPreview
 local function evaluate(live,advance)
  panel.summary=nil
  if not advance then panel.step=1 end
  panel.result=T.evaluate(player,require('CSV/Pack').voiceOrder[voice.selected],choice.selected,live,panel.step)
  panel.result.voice=require('CSV/Pack').voiceOrder[voice.selected]
  panel.message=panel.result.status=='compatibility' and tr('Compatibility') or panel.result.status=='live' and tr('Live') or panel.result.skipped and getText('UI_CSV_Aud_Unavailable') or panel.result.pass and tr('Pass') or tr('Fail')
 end
 local function button(x,y,w,label,fn)local o=ISButton:new(x,y,w,30,label,panel,fn);o:initialise();panel:addChild(o)end
 button(20,100,210,tr('Run'),function()evaluate(false)end)
 button(240,100,240,tr('Live'),function()evaluate(true)end)
 button(490,100,250,getText('UI_CSV_Aud_Listen'),function()
  stopPreview()
  evaluate(panel.result and panel.result.live or false,true)
  if not panel.result.line then panel.message=getText('UI_CSV_Aud_NoMatch');return end
  if panel.result.decision.mode=='silent' then panel.message=tr('Blocked');return end
  local ok,reason=V.client.preview(player,panel.result.line.id,panel.result.voice,panel.result.decision.radius,nil,{contextFacts=panel.result.facts})
  if ok then for _,e in ipairs(V.client.active)do if e.player==player and e.preview then panel.playback=e end end end
  panel.message=ok and getText('UI_CSV_Aud_Queued') or (getText('UI_CSV_Aud_NotStarted'))
 end)
 button(20,375,260,tr('All'),function()
  local counts=T.summary(player);panel.summary=counts
  panel.message=tr('Pass')..': '..counts.passed..' - '..tr('Fail')..': '..counts.failed
 end)
 button(730,375,150,getText('UI_CSV_Aud_Close') ,function()stopPreview();panel:removeFromUIManager();T.panel=nil end)
 button(20,330,230,tr('Next'),function()
  local c=T.cases[choice.selected];panel.step=((panel.step or 1)%#(c.steps or {c}))+1;evaluate(false,true)
 end)
 choice.onChange=function()evaluate(false)end
 voice.onChange=function()stopPreview();evaluate(false)end
 panel.prerender=function(self)
  ISPanel.prerender(self);self:drawText(getText('UI_CSV_Scenarios'),20,15,1,1,1,1,UIFont.Medium)
  self:drawText(self.message,20,145,1,1,1,1,UIFont.Small)
  self:drawText(tr('SelectionOnly'),20,175,.8,.8,.8,1,UIFont.Small)
  if self.playback then local e=self.playback;self:drawText(getText('UI_CSV_Playback')..': '..e.line..' / '..UI.playback(e),270,335,.8,.8,.8,1,UIFont.Small) end
  if self.summary then
   self:drawText(tr('Compatibility')..': '..self.summary.compatibility,20,205,1,1,1,1,UIFont.Small)
   self:drawText(getText('UI_CSV_Aud_Unavailable')..': '..self.summary.skipped,20,235,1,1,1,1,UIFont.Small)
   return
  end
  local r=self.result;if not r then return end
  local status=r.status=='compatibility' and tr('Compatibility') or r.status=='live' and tr('Live') or r.skipped and getText('UI_CSV_Aud_Unavailable') or r.pass and tr('Pass') or tr('Fail')
  self:drawText(status..' - '..tostring(choice.selected)..' - '..r.case.group..' - '..r.step..'/'..r.stepCount,20,205,1,1,1,1,UIFont.Small)
  self:drawText(getText('UI_CSV_Clip')..': '..(r.line and r.line.id or '-'),20,235,1,1,1,1,UIFont.Small)
  self:drawText(r.line and r.line.text or getText('UI_CSV_Aud_NoMatch'),20,265,1,1,1,1,UIFont.Small)

 end
 panel:addToUIManager()
end
return T
