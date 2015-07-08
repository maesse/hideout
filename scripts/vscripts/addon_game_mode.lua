_G.nCOUNTDOWNTIMER = 901
_G.nROUNDENDTIMER = 0
_G.SEEKER_TEAM = DOTA_TEAM_GOODGUYS
_G.HIDER_TEAM = DOTA_TEAM_BADGUYS
_G.TEAMNAME = {
    [SEEKER_TEAM] = "Seeker Team",
    [HIDER_TEAM] = "Hider Team"
  }

if CHideoutGameMode == nil then
	CHideoutGameMode = class({})
end

require( "utility_functions" )
require( "timers" )

function Precache( context )
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
			PrecacheResource( "model", "*.vmdl", context )
			PrecacheResource( "soundfile", "*.vsndevts", context )
			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]
  
  PrecacheResource( "particle", "particles/econ/items/warlock/warlock_staff_glory/warlock_upheaval_hellborn_debuff.vpcf", context)
  
  PrecacheResource( "particle", "particles/units/heroes/hero_rattletrap/rattletrap_rocket_flare.vpcf", context)
  PrecacheResource( "particle", "particles/units/heroes/hero_rattletrap/rattletrap_rocket_flare_explosion.vpcf", context)
  PrecacheResource( "particle", "particles/units/heroes/hero_rattletrap/rattletrap_rocket_flare_explosion.vpcf", context)
  

  PrecacheResource( "particle_folder", "particles/units/heroes/hero_rattletrap", context )
  
end

-- Create the game mode when we activate
function Activate()
	CHideoutGameMode:InitGameMode()
end

function CHideoutGameMode:InitGameMode()
	print("Hideout is loaded.")
	
  
  GameRules:SetSameHeroSelectionEnabled(true)
  GameRules:GetGameModeEntity():SetFixedRespawnTime(5)
  
  
  
	GameRules:GetGameModeEntity().CHideoutGameMode = self
	
  -- Countdown starts when game begins
	self.countdownEnabled = false
  self.gameStarted = false;
  self.roundStarted = false;
  self.roundEnded = false;
  self.currentHider = nil;
  self.playerPool = {}
  self.t2Pool = {}
  self.t2PoolIndex = 0
	
--	Set team colors
	self.m_TeamColors = {}
	self.m_TeamColors[DOTA_TEAM_GOODGUYS] = { 0, 0, 255 }	--		Teal
	self.m_TeamColors[DOTA_TEAM_BADGUYS]  = { 255, 0, 0 }		--		Yellow
	self.m_TeamColors[DOTA_TEAM_CUSTOM_1] = { 197, 77, 168 }	--      Pink
	self.m_TeamColors[DOTA_TEAM_CUSTOM_2] = { 255, 108, 0 }		--		Orange
	self.m_TeamColors[DOTA_TEAM_CUSTOM_3] = { 52, 85, 255 }		--		Blue
	self.m_TeamColors[DOTA_TEAM_CUSTOM_4] = { 101, 212, 19 }	--		Green
	self.m_TeamColors[DOTA_TEAM_CUSTOM_5] = { 129, 83, 54 }		--		Brown
	self.m_TeamColors[DOTA_TEAM_CUSTOM_6] = { 27, 192, 216 }	--		Cyan
	self.m_TeamColors[DOTA_TEAM_CUSTOM_7] = { 199, 228, 13 }	--		Olive
	self.m_TeamColors[DOTA_TEAM_CUSTOM_8] = { 140, 42, 244 }	--		Purple
	
	for team = 0, (DOTA_TEAM_COUNT-1) do
		color = self.m_TeamColors[ team ]
		if color then
			SetTeamCustomHealthbarColor( team, color[1], color[2], color[3] )
		end
	end
	
	-- Stuff from overthrow
  self:SetupTeams()
	GameRules:SetCustomGameEndDelay( 0 )
	GameRules:SetCustomVictoryMessageDuration( 10 )
	GameRules:SetPreGameTime( 10 )
	GameRules:GetGameModeEntity():SetLoseGoldOnDeath( false )
--	GameRules:GetGameModeEntity():SetTopBarTeamValuesOverride( true )
--	GameRules:GetGameModeEntity():SetTopBarTeamValuesVisible( false )
	GameRules:SetHideKillMessageHeaders( true )
	GameRules:SetUseUniversalShopMode( true )
  
  -- Game event listeners
  ListenToGameEvent( "game_rules_state_change", Dynamic_Wrap( CHideoutGameMode, 'OnGameRulesStateChange' ), self )
  ListenToGameEvent( "player_say", Dynamic_Wrap(CHideoutGameMode, 'PlayerSay'), self)
  ListenToGameEvent( "entity_killed", Dynamic_Wrap(CHideoutGameMode, 'EntityKilled'), self)
  ListenToGameEvent( "npc_spawned", Dynamic_Wrap(CHideoutGameMode, 'NPCSpawned'), self)
  
  
  -- Console commands
  Convars:RegisterCommand( "hide_init", function(name, param) self:InitHideout(param) end, "Setup hideout.", FCVAR_CHEAT )
  Convars:RegisterCommand( "hide_nextround", function(name, param) self:NextRound(param) end, "Go to next round.", FCVAR_CHEAT )
  Convars:RegisterCommand( "spawnhero", function(name, param) self:TestFunc(param) end, "Spawns a hero.", FCVAR_CHEAT )
	
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )
	print("Finished init.")
end

function CHideoutGameMode:GetHeroesControlled(playerid)
  local results = {}
  local heroes = HeroList:GetAllHeroes()
  for _,hero in pairs(heroes) do
    if playerid == hero:GetPlayerID() then
      results[#results+1] = hero
    end
  end
  return results
end

-- Setup up for the first game
function CHideoutGameMode:InitHideout(keys)
  print("Initializing hideout")
  
  
  -- Full reset of gamestate values
  self.gameStarted = false
  self.roundEnded = false;
  self.currentHider = nil
  self.t2PoolIndex = 1
  self.t2Pool = {}
  self.playerPool = {}
  
  -- Find all players and set up a hiderteam queue
  for _, player in pairs( Entities:FindAllByClassname( "player" ) ) do
		print("Found a player! id: " .. player:GetPlayerID() .. ", #self.t2Pool: " .. #self.t2Pool)
    --self.t2Pool[#self.t2Pool + 1] = player:GetPlayerID()
    self.playerPool[#self.playerPool + 1] = player:GetPlayerID()
	end
--  print("Found " .. #self.t2Pool .. " players")
  
  -- Shuffle and print playerlist
--  self.t2pool = ShuffledList(self.t2Pool)
--  print("Players will be selected in this order:")
--  for i, player in pairs( self.t2Pool ) do
--		print(i .. ": " .. PlayerResource:GetPlayerName(player))
--    local herolist = self:GetHeroesControlled(player)
--    for _,hero in pairs(herolist) do
--      print("-- controlling hero: " .. hero:GetClassname())
--    end
--	end
  
  -- Move all players to seeker team
--  for _,player in pairs( self.playerPool ) do
--    self:MoveToTeam(player, SEEKER_TEAM)
--  end
end

-- Continue to the next round
function CHideoutGameMode:NextRound(keys)
  -- Finish previous round
  self:PostRound()
  
  self.gameStarted = true
  
  --Add abilities:
  print("Adding abilities - #self.playerPool: " .. #self.playerPool)
  for _, playerID in pairs( self.playerPool ) do
    local herolist = self:GetHeroesControlled(playerID)
    for _,hero in pairs(herolist) do
      print("adding abilities for hero: " .. hero:GetClassname())
      
      --Get team
      team = PlayerResource:GetTeam(playerID)
      if (team == SEEKER_TEAM) then
        CHideoutGameMode:AddSeekerAbilities(hero)
      elseif (team == HIDER_TEAM) then
        CHideoutGameMode:AddHiderAbilities(hero)
      end
    end
  end
  
  --self.currentHider = self.t2Pool[self.t2PoolIndex]

 -- print("self.t2PoolIndex: " .. self.t2PoolIndex)
 -- print("next player index:" .. self.t2PoolIndex .. ", obj: " .. self.currentHider)
  --self:MoveToTeam(self.currentHider, HIDER_TEAM)
  
  -- Begin next round
  self:PreRound()
end


function CHideoutGameMode:AddSeekerAbilities(hero)
  --hero:AddAbility("templar_assassin_refraction_holdout")
  
  for i=0,15 do
--    hero:RemoveAbility("")
  end

  hero:AddAbility("rattletrap_rocket_flare")
  hero:AddAbility("naga_siren_ensnare")
  hero:AddAbility("mirana_arrow")
  hero:AddAbility("mirana_invis")
  
  
end


function CHideoutGameMode:AddHiderAbilities(hero)
  
  
end


function CHideoutGameMode:MoveToTeam(playerid, team)
  print("Moving player " .. playerid .. " to team " .. TEAMNAME[team])
  PlayerResource:SetCustomTeamAssignment(playerid, team)
  local heroes = self:GetHeroesControlled(playerid)
  for _,hero in pairs(heroes) do
    hero:SetTeam(team)
  end
end

-- Initializes a round
function CHideoutGameMode:PreRound()
  print("Setting up next round")
  self.roundStarted = true
  self.roundEnded = false
  
  -- Setup hider and seekers here (abilities etc)
end

-- Finishes a round
function CHideoutGameMode:PostRound()
  print("Finishing current round")
  
  -- move the hider to the seeker team
  if self.gameStarted and self.currentHider ~= nil then
    -- TODO: Calculate scores here?
    
    --self:MoveToTeam(self.currentHider, SEEKER_TEAM)
    --self.currentHider = nil
    
    -- Select next player in queue and make sure player is valid (still connected?)
--    repeat
--      self.t2PoolIndex = (self.t2PoolIndex % #self.t2Pool) + 1
--    until(PlayerResource:IsValidPlayer(self.t2Pool[self.t2PoolIndex]))
    
  end
  
  self.roundStarted = false
end


-- Ends a round
function CHideoutGameMode:EndRound()
  print("Ending current round")  
  self.roundEnded = true
  nROUNDENDTIMER = 5
end


-- Evaluate the state of the game
function CHideoutGameMode:OnThink()
	-- Stop thinking if game is paused
	if GameRules:IsGamePaused() == true then
        return 1
    end
  
  --Testing
  local allHeroes = HeroList:GetAllHeroes()
  for _,entity in pairs( allHeroes) do
    --Say(entity, "Hello there", false)
  end
	  
  --Round end timer
  if (self.roundEnded) then
    nROUNDENDTIMER = nROUNDENDTIMER - 1
    if (nROUNDENDTIMER <= 0) then
      CHideoutGameMode:NextRound(nil)
    end
    
    print("nROUNDENDTIMER: " .. nROUNDENDTIMER)
  end
    
  --Game timer
	if self.countdownEnabled == true then
		CountdownTimer()
		if nCOUNTDOWNTIMER == 30 then
			CustomGameEventManager:Send_ServerToAllClients( "timer_alert", {} )
		end
		if nCOUNTDOWNTIMER <= 0 then
			--Check to see if there's a tie
			if self.isGameTied == false then
				GameRules:SetCustomVictoryMessage( self.m_VictoryMessages[self.leadingTeam] )
				COverthrowGameMode:EndGame( self.leadingTeam )
				self.countdownEnabled = false
			else
				self.TEAM_KILLS_TO_WIN = self.leadingTeamScore + 1
				local broadcast_killcount = 
				{
					killcount = self.TEAM_KILLS_TO_WIN
				}
				CustomGameEventManager:Send_ServerToAllClients( "overtime_alert", broadcast_killcount )
			end
    end
	end
	
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		--print( "Template addon script is running." )
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	
	return 1
end



---------------------------------------------------------------------------
-- Setup teams
---------------------------------------------------------------------------
function CHideoutGameMode:SetupTeams()
  
	for team = 0, (DOTA_TEAM_COUNT-1) do
    if (team == DOTA_TEAM_GOODGUYS) then GameRules:SetCustomGameTeamMaxPlayers( team, 5 ) 
    elseif (team == DOTA_TEAM_BADGUYS) then GameRules:SetCustomGameTeamMaxPlayers( team, 5 ) else
    GameRules:SetCustomGameTeamMaxPlayers( team, 0 ) end
	end
end



---------------------------------------------------------------------------
-- Get the color associated with a given teamID
---------------------------------------------------------------------------
function CHideoutGameMode:ColorForTeam( teamID )
	local color = self.m_TeamColors[ teamID ]
	if color == nil then
		color = { 255, 255, 255 } -- default to white
	end
	return color
end


function CHideoutGameMode:TestFunc(text)
  local cl = Convars:GetDOTACommandClient()
  
  local result = CreateHeroForPlayer("npc_dota_hero_" .. text, cl)
  result:RespawnUnit()
  result:SetTeam(DOTA_TEAM_NEUTRALS)
  print(result:GetHealth())
  
  
end



----------------------------------------
--EVENTS--------------------------------
----------------------------------------
function CHideoutGameMode:PlayerSay(keys)
  print("Should work but doesn't.")
end

function CHideoutGameMode:EntityKilled(tbl) --(entindex_killed, entindex_attacker, entindex_inflictor, damagebits)
  print("EntityKilled - entindex_killed: " .. tbl.entindex_killed)
  --Was hider killder?
  local hiderHeroEntid = 0
  local herolist = self:GetHeroesControlled(self.currentHider)
  for _,hero in pairs(herolist) do
    if (hero ~= nil) then
      hiderHeroEntid = hero:GetEntityIndex()
    end
  end

  if (tbl.entindex_killed == hiderHeroEntid) then
    print("Hider was killed!")
    CHideoutGameMode:EndRound()
  end
end

function CHideoutGameMode:NPCSpawned(tbl)
  print("NPCSpawned - entindex: " .. tbl.entindex)
  
  local entity = EntIndexToHScript(tbl.entindex)
  print("entity:")
  PrintTable(entity)
  print(entity:GetOrigin())
  
  
  --
  --MoveToSomePosition maybe?
 --  	Vector GetGroundPosition(Vector Vector_1, handle handle_2) 
 -- 	void FindClearSpaceForUnit(handle handle_1, Vector Vector_2, bool bool_3) 
end


function CHideoutGameMode:OnGameRulesStateChange() -- Event: Game state change handler
	local nNewState = GameRules:State_Get()
	print( "OnGameRulesStateChange: " .. nNewState )

	if nNewState == DOTA_GAMERULES_STATE_HERO_SELECTION then

	end

	if nNewState == DOTA_GAMERULES_STATE_PRE_GAME then
		local numberOfPlayers = PlayerResource:GetPlayerCount()
		if numberOfPlayers > 7 then
			--self.TEAM_KILLS_TO_WIN = 25
			nCOUNTDOWNTIMER = 901
		elseif numberOfPlayers > 4 and numberOfPlayers <= 7 then
			--self.TEAM_KILLS_TO_WIN = 20
			nCOUNTDOWNTIMER = 721
		else
			--self.TEAM_KILLS_TO_WIN = 15
			nCOUNTDOWNTIMER = 601
		end

		CustomNetTables:SetTableValue( "game_state", "victory_condition", { kills_to_win = 10 } );

		self._fPreGameStartTime = GameRules:GetGameTime()
	end

	if nNewState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		--print( "OnGameRulesStateChange: Game In Progress" )
		self.countdownEnabled = true
		CustomGameEventManager:Send_ServerToAllClients( "show_timer", {} )
	end
end




