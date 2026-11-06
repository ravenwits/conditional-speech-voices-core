local P={
 familiarity={zombie=25,human=5,injury=5,raid=5},
 perceptionInterval=250,knownHumanThreat=12000,safetyPeriod=15000,
 severeHealth=35,recoveredHealth=65,injuryEvidenceAge=10000,
 repeatInterval=45000,queueLimit=8,aftermathLifetime=90000,eventLifetime=12000,
 trackLifetime=180000,lostSightDelay=3000,trackRange=25,
}

function P.killInterval(frequency)return ({[0]=60000,[1]=30000,[2]=15000})[frequency] or 30000 end
return P
