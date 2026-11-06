local M={}
function M.cases()
 local result={}
 local rows={
  {'Active attack overrides nearby unaware zombie',4,1,0,1,12,'spoken'},
  {'Approaching targeted zombie overrides crouching',3,0,1,1,12,'spoken'},
  {'Calm character under attack uses controlled warning',0,1,0,1,6,'spoken'},
  {'Confirmed rear attack does not require player vision',4,1,0,0,12,'spoken'},
  {'Old distant pursuer cannot override hiding',4,0,0,1,2,'spoken'},
 }
 for _,r in ipairs(rows)do
  result[#result+1]={name=r[1],group='GunJammed',level=1,max=1,state={jammed=true,sneaking=true,panic=r[2],directAttack=r[3],activePursuit=r[4],concealmentRisk=r[5],near=0,visible=0,recentThreat=true},expect='GunJammed',mode=r[7],radius=r[6],expectWhisper=r[3]+r[4]==0,newConcealment=true,newConditions=true,prefs={whisper=true}}
 end
 for _,row in ipairs({{'Pinpoint hearing: unaware zombie five tiles away',1,2,true},{'Normal hearing: unaware zombie five tiles away',0,4,false},{'Poor hearing: unaware zombie five tiles away',0,4,false}})do
  result[#result+1]={name=row[1],group='GunJammed',level=1,max=1,state={jammed=true,sneaking=true,panic=0,near=1,visible=1,exposureChecked=true,exposedZombie=1,concealmentRisk=row[2],whisperRisk=row[2]},expect='GunJammed',mode=row[2]>0 and 'silent' or 'spoken',radius=row[2]==0 and row[3] or nil,expectWhisper=false,newConcealment=true,newConditions=true,prefs={whisper=true}}
 end
 result[#result+1]={name='Shared mortal fear after zombie warnings were used',group='Panic',level=4,max=4,state={sneaking=true,panic=4,near=1,visible=1,directAttack=1,concealmentRisk=1},expect='MortalFear',mode='spoken',radius=12,expectWhisper=false,newConcealment=true,newConditions=true,sharedDanger=true,seedSeen={'PanicEscape_1','PanicEscape_2','PanicEscape_3'},prefs={whisper=true}}
 return result
end
return M
