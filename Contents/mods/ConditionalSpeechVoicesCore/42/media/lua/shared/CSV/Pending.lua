local P={}
function P.status(now,valid,expires,nextAttempt)
 if not valid then return 'cancelled' end
 if expires and now>expires then return 'expired' end
 if nextAttempt and now<nextAttempt then return 'waiting' end
 return 'ready'
end
function P.accepted(attempt,group)
 return attempt~=nil and (group==nil or attempt.group==group) and (attempt.outcome=='played' or attempt.outcome=='local_thought')
end
return P
