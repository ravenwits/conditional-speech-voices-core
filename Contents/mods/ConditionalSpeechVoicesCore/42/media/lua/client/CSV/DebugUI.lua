local U={}
function U.text(key)return getText('UI_CSV_Short_'..key)end
function U.playback(entry)
 if not entry then return U.text('Ready')end
 local reason=entry.finishedReason or entry.outcome
 if reason=='engine_finished' then return U.text('Finished')end
 if reason=='preview_stopped' or reason=='remote_stop' then return U.text('Stopped')end
 if reason then return U.text('Blocked')end
 return entry.started and U.text('Playing') or getText('UI_CSV_Aud_Queued')
end
return U
