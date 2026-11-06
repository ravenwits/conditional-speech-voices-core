local C={}
-- Only these policies permit the content but restrict public speech.
local privateOnly={concealment=true,whisper_would_reveal=true}
local upstream={source_mood_filters=true,unknown_concealment=true,unmanaged_group=true}
function C.resolve(policy,activity,prefs,volume)
 policy=policy or {};prefs=prefs or {}
 if activity=='sleeping' then return {allowed=false,channel='none',reason='sleeping'} end
 local allowed=policy.mode=='spoken' or policy.mode=='upstream' and upstream[policy.reason] or policy.mode=='silent' and privateOnly[policy.reason]
 if not allowed then return {allowed=false,channel='none',reason=policy.reason or 'unknown_policy'} end
 local private=activity=='consuming' or privateOnly[policy.reason] or volume==0
 if private then return {allowed=true,channel=prefs.thoughts and 'private' or 'none',reason=activity=='consuming' and 'consuming' or 'private_only'} end
 return {allowed=true,channel=policy.mode=='upstream' and volume==nil and 'upstream' or 'public',reason=policy.reason}
end
return C
