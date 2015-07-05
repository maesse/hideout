_G.nCOUNTDOWNTIMER = 901
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

function Precache( context )
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
			PrecacheResource( "model", "*.vmdl", context )
			PrecacheResource( "soundfile", "*.vsndevts", context )
			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]
end

-- Create the game mode when we activate
function Activate()
	CHideoutGameMode:InitGameMode()
end

function CHideoutGameMode:InitGameMode()
	print("Hideout is loaded.")
	
	GameRules:GetGameModeEntity().CHideoutGameMode = self
	
  -- Countdown starts when game begins
	self.countdownEnabled = false
  self.gameStarted = false;
  self.roundStarted = false;
  self.currentHider = nil;
  self.playerPool = {}
  self.t2Pool = {}
  self.t2PoolIndex = 0
	
--	Set team colors
	self.m_TeamColors = {}
	self.m_TeamColors[DOTA_TEAM_GOODGUYS] = { 61, 210, 150 }	--		Teal
	self.m_TeamColors[DOTA_TEAM_BADGUYS]  = { 243, 201, 9 }		--		Yellow
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
  self:GatherAndRegisterValidTeams()
	GameRules:SetCustomGameEndDelay( 0 )
	GameRules:SetCustomVictoryMessageDuration( 10 )
	GameRules:SetPreGameTime( 10 )
	GameRules:GetGameModeEntity():SetLoseGoldOnDeath( false )
	GameRules:GetGameModeEntity():SetTopBarTeamValuesOverride( true )
	GameRules:GetGameModeEntity():SetTopBarTeamValuesVisible( false )
	GameRules:SetHideKillMessageHeaders( true )
	GameRules:SetUseUniversalShopMode( true )
  
  -- Game event listeners
  ListenToGameEvent( "game_rules_state_change", Dynamic_Wrap( CHideoutGameMode, 'OnGameRulesStateChange' ), self )
  ListenToGameEvent( "player_say", Dynamic_Wrap(CHideoutGameMode, 'PlayerSay'), self)
  
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
  self.currentHider = nil
  self.t2PoolIndex = 1
  self.t2Pool = {}
  self.playerPool = {}
  
  -- Find all players and set up a hiderteam queue
  for _, player in pairs( Entities:FindAllByClassname( "player" ) ) do
		print("Found a player! id: " .. player:GetPlayerID())
    self.t2Pool[#self.t2Pool+1] = player:GetPlayerID()
    self.playerPool[#self.playerPool+1] = player:GetPlayerID()
	end
  print("Found " .. #self.t2Pool .. " players")
  
  -- Shuffle and print playerlist
  self.t2pool = ShuffledList(self.t2Pool)
  print("Players will be selected in this order:")
  for i, player in pairs( self.t2Pool ) do
		print(i .. ": " .. PlayerResource:GetPlayerName(player))
    local herolist = self:GetHeroesControlled(player)
    for _,hero in pairs(herolist) do
      print("-- controlling hero: " .. hero:GetClassname())
    end
	end
  
  -- Move all players to seeker team
  for _,player in pairs( self.playerPool ) do
    self:MoveToTeam(player, SEEKER_TEAM)
  end
end

-- Continue to the next round
function CHideoutGameMode:NextRound(keys)
  -- Finish previous round
  self:PostRound()
  
  -- Move next player to hider team
  self.gameStarted = true
  
  self.currentHider = self.t2Pool[self.t2PoolIndex]
  print("t2len: " .. #self.t2Pool)
  print("next player index:" .. self.t2PoolIndex .. "obj:" .. self.currentHider)
  self:MoveToTeam(self.currentHider, HIDER_TEAM)
  
  -- Begin next round
  self:PreRound()
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
  
  -- Setup hider and seekers here (abilities etc)
end

-- Finishes a round
function CHideoutGameMode:PostRound()
  print("Finishing current round")
  
  -- move the hider to the seeker team
  if self.gameStarted and self.currentHider ~= nil then
    -- TODO: Calculate scores here?
    
    self:MoveToTeam(self.currentHider, SEEKER_TEAM)
    self.currentHider = nil
    
    -- Select next player in queue and make sure player is valid (still connected?)
    repeat
      self.t2PoolIndex = (self.t2PoolIndex + 1) % #self.t2Pool
    until(PlayerResource:IsValidPlayer(self.t2Pool[self.t2PoolIndex]))
    
  end
  
  self.roundStarted = false
end

function CHideoutGameMode:PlayerSay(keys)
  print("Should work but doesn't.")
end

function CHideoutGameMode:TestFunc(text)
  local cl = Convars:GetDOTACommandClient()
  
  local result = CreateHeroForPlayer("npc_dota_hero_" .. text, cl)
  result:RespawnUnit()
  result:SetTeam(DOTA_TEAM_NEUTRALS)
  print(result:GetHealth())
  
  
end



-- Evaluate the state of the game
function CHideoutGameMode:OnThink()
	-- Stop thinking if game is paused
	if GameRules:IsGamePaused() == true then
        return 1
    end
  
  local allHeroes = HeroList:GetAllHeroes()
  for _,entity in pairs( allHeroes) do
    --Say(entity, "Hello there", false)
  end
	
  self:UpdateScoreboard()
  
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
-- Event: Game state change handler
---------------------------------------------------------------------------
function CHideoutGameMode:OnGameRulesStateChange()
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

---------------------------------------------------------------------------
-- Scan the map to see which teams have spawn points
---------------------------------------------------------------------------
function CHideoutGameMode:GatherAndRegisterValidTeams()
--	print( "GatherValidTeams:" )

	local foundTeams = {}
	for _, playerStart in pairs( Entities:FindAllByClassname( "info_player_start_dota" ) ) do
		foundTeams[  playerStart:GetTeam() ] = true
	end

	local numTeams = TableCount(foundTeams)
	print( "GatherValidTeams - Found spawns for a total of " .. numTeams .. " teams" )
	
	local foundTeamsList = {}
	for t, _ in pairs( foundTeams ) do
		table.insert( foundTeamsList, t )
	end

	if numTeams == 0 then
		print( "GatherValidTeams - NO team spawns detected, defaulting to GOOD/BAD" )
		table.insert( foundTeamsList, DOTA_TEAM_GOODGUYS )
		table.insert( foundTeamsList, DOTA_TEAM_BADGUYS )
		numTeams = 2
	end

	local maxPlayersPerValidTeam = math.floor( 10 / numTeams )

	self.m_GatheredShuffledTeams = ShuffledList( foundTeamsList )

	print( "Final shuffled team list:" )
	for _, team in pairs( self.m_GatheredShuffledTeams ) do
		print( " - " .. team .. " ( " .. GetTeamName( team ) .. " )" )
	end

	print( "Setting up teams:" )
	for team = 0, (DOTA_TEAM_COUNT-1) do
		local maxPlayers = 0
		if ( nil ~= TableFindKey( foundTeamsList, team ) ) then
			maxPlayers = maxPlayersPerValidTeam
		end
		print( " - " .. team .. " ( " .. GetTeamName( team ) .. " ) -> max players = " .. tostring(maxPlayers) )
		GameRules:SetCustomGameTeamMaxPlayers( team, maxPlayers )
	end
end

---------------------------------------------------------------------------
-- Simple scoreboard using debug text
---------------------------------------------------------------------------
function CHideoutGameMode:UpdateScoreboard()
	local sortedTeams = {}
	for _, team in pairs( self.m_GatheredShuffledTeams ) do
		table.insert( sortedTeams, { teamID = team, teamScore = GetTeamHeroKills( team ) } )
	end

	-- reverse-sort by score
	table.sort( sortedTeams, function(a,b) return ( a.teamScore > b.teamScore ) end )

	for _, t in pairs( sortedTeams ) do
		local clr = self:ColorForTeam( t.teamID )

		-- Scaleform UI Scoreboard
		local score = 
		{
			team_id = t.teamID,
			team_score = t.teamScore
		}
		FireGameEvent( "score_board", score )
	end
	-- Leader effects (moved from OnTeamKillCredit)
	local leader = sortedTeams[1].teamID
	--print("Leader = " .. leader)
	self.leadingTeam = leader
	self.runnerupTeam = sortedTeams[2].teamID
	self.leadingTeamScore = sortedTeams[1].teamScore
	self.runnerupTeamScore = sortedTeams[2].teamScore
	if sortedTeams[1].teamScore == sortedTeams[2].teamScore then
		self.isGameTied = true
	else
		self.isGameTied = false
	end
	local allHeroes = HeroList:GetAllHeroes()
	for _,entity in pairs( allHeroes) do
		if entity:GetTeamNumber() == leader and sortedTeams[1].teamScore ~= sortedTeams[2].teamScore then
			if entity:IsAlive() == true then
				-- Attaching a particle to the leading team heroes
				local existingParticle = entity:Attribute_GetIntValue( "particleID", -1 )
       			if existingParticle == -1 then
       				local particleLeader = ParticleManager:CreateParticle( "particles/leader/leader_overhead.vpcf", PATTACH_OVERHEAD_FOLLOW, entity )
					ParticleManager:SetParticleControlEnt( particleLeader, PATTACH_OVERHEAD_FOLLOW, entity, PATTACH_OVERHEAD_FOLLOW, "follow_overhead", entity:GetAbsOrigin(), true )
					entity:Attribute_SetIntValue( "particleID", particleLeader )
				end
			else
				local particleLeader = entity:Attribute_GetIntValue( "particleID", -1 )
				if particleLeader ~= -1 then
					ParticleManager:DestroyParticle( particleLeader, true )
					entity:DeleteAttribute( "particleID" )
				end
			end
		else
			local particleLeader = entity:Attribute_GetIntValue( "particleID", -1 )
			if particleLeader ~= -1 then
				ParticleManager:DestroyParticle( particleLeader, true )
				entity:DeleteAttribute( "particleID" )
			end
		end
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
