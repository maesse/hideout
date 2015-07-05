if CDotaFunctions == nil then
	CDotaFunctions = class({})
end

intTest = 0
intTestTeamIncr = 2

function CDotaFunctions:TestStuff()
  
  
  local allHeroes = HeroList:GetAllHeroes()
	for _,hero in pairs( allHeroes) do
    print(hero)
    if (hero ~= nil) then
      
      
      if (intTest % 5 == 0) then
        intTestTeamIncr = (intTestTeamIncr + 1) % 10
        if (intTestTeamIncr < 2) then intTestTeamIncr = 2 end
        if (intTestTeamIncr == 4 or intTestTeamIncr == 5) then intTestTeamIncr = 6 end
          
        CDotaFunctions:SetPlayerToTeam(hero, intTestTeamIncr)
        CDotaFunctions:SetHeroTeam(hero, intTestTeamIncr)
        
        print ("setting hero and player to team: " .. intTestTeamIncr);
      end      
    end
  end

end

function CDotaFunctions:SetPlayerToTeam(hero, intTeamID)
  PlayerResource:SetCustomTeamAssignment (hero:GetPlayerID(), intTeamID)
end

function CDotaFunctions:SetHeroTeam(hero, intTeamID)
  hero:SetTeam(intTeamID)
end

