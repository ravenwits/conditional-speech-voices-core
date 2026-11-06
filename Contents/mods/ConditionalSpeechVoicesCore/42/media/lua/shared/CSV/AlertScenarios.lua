local M={}
function M.cases()
 local out={}
 for _,row in ipairs({{'normal',{},'StartleNormal'},{'brave',{brave=true},'StartleBrave'},{'cowardly',{cowardly=true},'StartleCowardly'},{'desensitized',{desensitized=true},'StartleDesensitized'}})do
  for _,hidden in ipairs({false,true})do
   out[#out+1]={name='Native alert '..row[1]..(hidden and ' concealed' or ' standing'),group='Startle',level=1,max=1,
    state={nativeAlert=true,traits=row[2],sneaking=hidden,panic=0,near=1,visible=1,whisperRisk=0},prefs={whisper=true},expect=row[3],mode='spoken',kate='none',newPsychology=true}
  end
 end
 out[#out+1]={name='No native alert evidence',group='Startle',level=1,max=1,state={nativeAlert=false,sneaking=false},expect='none',mode='silent'}
 out[#out+1]={name='Startle cannot reveal position to hidden observer',group='Startle',level=1,max=1,state={nativeAlert=true,sneaking=true,whisperRisk=1,traits={}},prefs={whisper=true},expect='StartleNormal',mode='silent',kate='none',newPsychology=true}
 out[#out+1]={name='Brave character with actual severe panic',group='Startle',level=1,max=1,state={nativeAlert=true,traits={brave=true},panic=4,sneaking=false},expect='StartleCowardly',mode='spoken',kate='none',newPsychology=true}
 out[#out+1]={name='Smoker with verified withdrawal',group='Stress',level=2,max=4,state={traits={smoker=true},nicotineStress=1,near=0,visible=0,recentThreat=false,sneaking=false},prefs={safeSpeech=true},expect='NicotineNeed',mode='spoken',kate='none',newPsychology=true}
 out[#out+1]={name='Blood phobia with own bleeding and panic',group='Stress',level=2,max=4,state={traits={hemophobic=true},bleeding=1,panic=2,near=0,visible=0,recentThreat=false,sneaking=false},prefs={safeSpeech=true},expect='BloodAversion',mode='spoken',kate='none',newPsychology=true}
 out[#out+1]={name='No agoraphobia indoors',group='Agoraphobic',level=2,max=4,state={traits={agoraphobic=true},outside=false,panic=2},expect='none',mode='silent'}
 out[#out+1]={name='No claustrophobia outdoors',group='Claustrophobic',level=2,max=4,state={traits={claustrophobic=true},outside=true,panic=2},expect='none',mode='silent'}
 for _,row in ipairs({{'StartleNormal',{}},{'StartleBrave',{brave=true}},{'StartleCowardly',{cowardly=true}},{'StartleDesensitized',{desensitized=true}}})do
  local seed={};for i=1,6 do seed[#seed+1]=row[1]..'_'..i end
  out[#out+1]={name='New defensive shout after startle alternatives: '..row[1],group='Startle',level=1,max=1,seedSeen=seed,state={nativeAlert=true,traits=row[2],panic=0,sneaking=false,activePursuit=1,near=1,visible=1},expect=row[1]..'_7',mode='spoken',newPsychology=true,kate='none'}
 end
 out[#out+1]={name='Severe exhaustion away from danger',group='Endurance',level=3,max=4,state={endurance=3,pain=0,bleeding=0,drunk=0,coldSymptoms=0,sneaking=false,near=0,visible=0,recentThreat=false},prefs={safeSpeech=true},expect='ExhaustedCoping',mode='spoken',newPsychology=true,kate='none'}
 return out
end
return M
