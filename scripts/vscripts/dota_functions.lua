if CDotaFunctions == nil then
	CDotaFunctions = class({})
end

intTest = 0
intTestTeamIncr = 2


--function CDotaFunctions:AddAbility(hero)
--    hero:AddAbility("templar_assassin_refraction_holdout") 
--end

function CDotaFunctions:SetPlayerToTeam(hero, intTeamID)
  PlayerResource:SetCustomTeamAssignment (hero:GetPlayerID(), intTeamID)
end

function CDotaFunctions:SetHeroTeam(hero, intTeamID)
  hero:SetTeam(intTeamID)
end

