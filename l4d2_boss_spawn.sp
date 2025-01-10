#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define DEBUG 0

#define PLUGIN_VERSION "1.3.2"

ConVar  g_hCvarPluginEnable,
        g_hCvarDirectorNoBosses,
        g_hCvarTotalTanks,
        g_hCvarTotalTanksRandom,
        g_hCvarTanks,
        g_hCvarTanksRandom,
        g_hCvarTanksChance,
        g_hCvarCheckTanks,
        g_hCvarStartTanks,
        g_hCvarFinaleTanks,
        g_hCvarRangeMinTank,
        g_hCvarRangeMaxTank,
        g_hCvarTotalWitches,
        g_hCvarTotalWitchesRandom,
        g_hCvarWitches,
        g_hCvarWitchesRandom,
        g_hCvarWitchesChance,
        g_hCvarCheckWitches,
        g_hCvarStartWitches,
        g_hCvarFinaleWitches,
        g_hCvarRangeMinWitch,
        g_hCvarRangeMaxWitch,
        g_hCvarRangeRandom,
        g_hCvarInterval;

bool    g_bPluginEnable,
        g_bCheckTanks,
        g_bCheckWitches,
        g_bStartTanks,
        g_bStartWitches,
        g_bRangeRandom,
        g_bFinaleStarts,
        g_bAllowSpawnTanks,
        g_bAllowSpawnWitches,
        g_bChekingFlow,
        g_bIsFirstMap,
        g_bIsFinalMap;	

int     g_iFinaleTanks,
        g_iFinaleWitches,
        g_iTanks,
        g_iTanksRandom,
        g_iTanksChance,
        g_iWitches,
        g_iWitchesRandom,
        g_iWitchesChance,
        g_iTotalTanks,
        g_iTotalTanksRandom,
        g_iTotalWitches,
        g_iTotalWitchesRandom,
        g_iTankCounter,
        g_iWitchCounter,
        g_iMaxTanks,
        g_iMaxWitches,
        g_iPlayerHighestFlow;

float   g_fFlowMaxMap,
        g_fFlowPlayers,
        g_fFlowRangeMinTank,
        g_fFlowRangeMinWitch,
        g_fFlowRangeMaxWitch,
        g_fFlowRangeMaxTank,
        g_fFlowRangeSpawnTank,
        g_fFlowRangeSpawnWitch,
        g_fFlowSpawnTank,
        g_fFlowSpawnWitch,
        g_fFlowCanSpawnTank,
        g_fFlowCanSpawnWitch,
        g_fFlowPercentMinTank,
        g_fFlowPercentMaxTank,
        g_fFlowPercentMinWitch,
        g_fFlowPercentMaxWitch,
        g_fInterval;

Handle  g_hTimerCheckFlow;

public Plugin myinfo =
{
	name = "[L4D2] Boss Spawn",
	author = "xZk, Dosergen",
	description = "Spawn bosses (Tank or Witch) depending on the progress of the map.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=323402"
}

public void OnPluginStart()
{
	CreateConVar("boss_spawn_version", PLUGIN_VERSION, "[L4D2] Boss Spawn plugin version.", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_hCvarPluginEnable       = CreateConVar("boss_spawn", "1", "0: Disable, 1: Enable Plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarInterval           = CreateConVar("boss_spawn_interval", "1.0", "Set interval time check to spawn", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarTanks              = CreateConVar("boss_spawn_tanks", "1", "Set Tanks to spawn simultaneously", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarTanksRandom        = CreateConVar("boss_spawn_tanks_rng", "0", "Set max random Tanks to spawn simultaneously, 0: Disable Random value", FCVAR_NOTIFY, true, 0.0, true, 10.0);
	g_hCvarTanksChance        = CreateConVar("boss_spawn_tanks_chance", "30", "Setting chance (0-100)% to spawn Tanks", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_hCvarWitches            = CreateConVar("boss_spawn_witches", "1", "Set Witches to spawn simultaneously", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarWitchesRandom      = CreateConVar("boss_spawn_witches_rng", "0", "Set max random Witches to spawn simultaneously, 0: Disable Random value", FCVAR_NOTIFY, true, 0.0, true, 10.0);
	g_hCvarWitchesChance      = CreateConVar("boss_spawn_witches_chance", "70", "Setting chance (0-100)% to spawn Witches", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_hCvarTotalTanks         = CreateConVar("boss_spawn_total_tanks", "2", "Set total Tanks to spawn on map", FCVAR_NOTIFY, true, 1.0, true, 10.0);
	g_hCvarTotalTanksRandom   = CreateConVar("boss_spawn_total_tanks_rng", "0", "Set max random value total Tanks on map, 0: Disable Random value", FCVAR_NOTIFY, true, 0.0, true, 10.0);
	g_hCvarTotalWitches       = CreateConVar("boss_spawn_total_witches", "2", "Set total Witches to spawn on map", FCVAR_NOTIFY, true, 1.0, true, 10.0);
	g_hCvarTotalWitchesRandom = CreateConVar("boss_spawn_total_witches_rng", "0", "Set max random value total Witches on map, 0: Disable Random value", FCVAR_NOTIFY, true, 0.0, true, 10.0);
	g_hCvarCheckTanks         = CreateConVar("boss_spawn_check_tanks", "0", "0: Checking any Tanks spawned on map, 1: Checking only boss spawn Tanks", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarCheckWitches       = CreateConVar("boss_spawn_check_witches", "0", "0: Checking any Witches spawned on map, 1: Checking only boss spawn Witches", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarStartTanks         = CreateConVar("boss_spawn_start_tanks", "1", "0: Disable Tanks in first map, 1: Allow Tanks in first map", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarFinaleTanks        = CreateConVar("boss_spawn_finale_tanks", "0", "0: Disable plugin tanks in finale map and activating VScript scenario, 1: Allow before finale starts, 2: Allow after finale starts, 3: Both", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	g_hCvarStartWitches       = CreateConVar("boss_spawn_start_witches", "1", "0: Disable Witches in first map, 1: Allow Witches in first map", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarFinaleWitches      = CreateConVar("boss_spawn_finale_witches", "0", "0: Disable plugin witches in the final map and activating VScript scenario, 1: Allow before finale starts, 2: Allow after finale starts, 3: Both", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	g_hCvarRangeMinTank       = CreateConVar("boss_spawn_range_min_tank", "25.0", "Set progress (0-100)% max of the distance map to can spawn Tank", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_hCvarRangeMaxTank       = CreateConVar("boss_spawn_range_max_tank", "80.0", "Set progress (0-100)% max of the distance map to can spawn Tank", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_hCvarRangeMinWitch      = CreateConVar("boss_spawn_range_min_witch", "10.0", "Set progress (0-100)% min of the distance map to can spawn Witch", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_hCvarRangeMaxWitch      = CreateConVar("boss_spawn_range_max_witch", "95.0", "Set progress (0-100)% max of the distance map to can spawn Witch", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_hCvarRangeRandom        = CreateConVar("boss_spawn_range_random", "1", "0: Set distribute spawning points evenly between each, 1: Set random range between spawning points", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, "l4d2_boss_spawn");
	
	g_hCvarPluginEnable.AddChangeHook(ConVarChanged_Allow);
	g_hCvarInterval.AddChangeHook(ConVarChanged_Cvars);    
	g_hCvarTanks.AddChangeHook(ConVarChanged_Cvars);        
	g_hCvarTanksRandom.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTanksChance.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarWitches.AddChangeHook(ConVarChanged_Cvars);        
	g_hCvarWitchesRandom.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarWitchesChance.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTotalTanks.AddChangeHook(ConVarChanged_Cvars);        
	g_hCvarTotalTanksRandom.AddChangeHook(ConVarChanged_Cvars);  
	g_hCvarCheckTanks.AddChangeHook(ConVarChanged_Cvars);   
	g_hCvarTotalWitches.AddChangeHook(ConVarChanged_Cvars);      
	g_hCvarTotalWitchesRandom.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarCheckWitches.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarStartTanks.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarFinaleTanks.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarStartWitches.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarFinaleWitches.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRangeMinTank.AddChangeHook(ConVarChanged_Cvars);  
	g_hCvarRangeMaxTank.AddChangeHook(ConVarChanged_Cvars);  
	g_hCvarRangeMinWitch.AddChangeHook(ConVarChanged_Cvars); 
	g_hCvarRangeMaxWitch.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRangeRandom.AddChangeHook(ConVarChanged_Cvars);

	g_hCvarDirectorNoBosses = FindConVar("director_no_bosses");
}

public void OnPluginEnd()
{
	g_hCvarDirectorNoBosses.SetInt(0);
}

public void OnConfigsExecuted()
{
	IsAllowed();
	g_hCvarDirectorNoBosses.SetInt(1);
}

void ConVarChanged_Allow(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bRangeRandom = g_hCvarRangeRandom.BoolValue;
	g_bCheckTanks = g_hCvarCheckTanks.BoolValue;
	g_bCheckWitches = g_hCvarCheckWitches.BoolValue;
	g_bStartTanks = g_hCvarStartTanks.BoolValue;
	g_bStartWitches = g_hCvarStartWitches.BoolValue;
	g_iTanks = g_hCvarTanks.IntValue;
	g_iTanksRandom = g_hCvarTanksRandom.IntValue;
	g_iTanksChance = g_hCvarTanksChance.IntValue;
	g_iWitches = g_hCvarWitches.IntValue;
	g_iWitchesRandom = g_hCvarWitchesRandom.IntValue;
	g_iWitchesChance = g_hCvarWitchesChance.IntValue;
	g_iTotalTanks = g_hCvarTotalTanks.IntValue;
	g_iTotalTanksRandom = g_hCvarTotalTanksRandom.IntValue;
	g_iTotalWitches = g_hCvarTotalWitches.IntValue;
	g_iTotalWitchesRandom = g_hCvarTotalWitchesRandom.IntValue;
	g_iFinaleTanks = g_hCvarFinaleTanks.IntValue;
	g_iFinaleWitches = g_hCvarFinaleWitches.IntValue;
	g_fFlowPercentMinTank = g_hCvarRangeMinTank.FloatValue;
	g_fFlowPercentMaxTank = g_hCvarRangeMaxTank.FloatValue;
	g_fFlowPercentMinWitch = g_hCvarRangeMinWitch.FloatValue;
	g_fFlowPercentMaxWitch = g_hCvarRangeMaxWitch.FloatValue;
	g_fInterval = g_hCvarInterval.FloatValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarPluginEnable.BoolValue;
	GetCvars();
	if (g_bPluginEnable == false && bCvarAllow == true)
	{
		g_bPluginEnable = true;
		HookEvent("round_start", Event_RoundStart);
		HookEvent("round_end", Event_RoundEnd);
		HookEvent("player_left_checkpoint", Event_PlayerLeftCheckpoint);
		HookEvent("player_left_start_area", Event_PlayerLeftCheckpoint);
		//HookEvent("finale_start", Event_FinaleStart);//doesn't work all finales
		HookEvent("tank_spawn", Event_TankSpawn);
		HookEvent("witch_spawn", Event_WitchSpawn);
		HookEntityOutput("trigger_finale", "FinaleStart", EntityOutput_FinaleStart);
	}
	else if (g_bPluginEnable == true && bCvarAllow == false)
	{
		g_bPluginEnable = false;
		UnhookEvent("round_start", Event_RoundStart);
		UnhookEvent("round_end", Event_RoundEnd);
		UnhookEvent("player_left_checkpoint", Event_PlayerLeftCheckpoint);
		UnhookEvent("player_left_start_area", Event_PlayerLeftCheckpoint);
		//UnhookEvent("finale_start", Event_FinaleStart);
		UnhookEvent("tank_spawn", Event_TankSpawn);
		UnhookEvent("witch_spawn", Event_WitchSpawn);
		UnhookEntityOutput("trigger_finale", "FinaleStart", EntityOutput_FinaleStart);
		delete g_hTimerCheckFlow;
	}
}

public void OnMapStart()
{
	g_bIsFinalMap = L4D_IsMissionFinalMap();
	g_bIsFirstMap = L4D_IsFirstMapInScenario();
}

public void OnMapEnd()
{
	Reset();
}

void EntityOutput_FinaleStart(const char[] output, int caller, int activator, float time)
{
	g_bFinaleStarts = true;
	g_bAllowSpawnTanks = (g_iFinaleTanks == 3 || g_bFinaleStarts && g_iFinaleTanks == 2);
	g_bAllowSpawnWitches = (g_iFinaleWitches == 3 || g_bFinaleStarts && g_iFinaleWitches == 2); 
	g_hCvarDirectorNoBosses.SetInt((g_iFinaleTanks > 0 && g_iFinaleWitches > 0) ? 1 : 0);
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bCheckTanks)
		g_iTankCounter++;
	#if DEBUG
	PrintToChatAll("[DEBUG] TankCounter: %d", g_iTankCounter);
	#endif
}

void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bCheckWitches)
		g_iWitchCounter++;
	#if DEBUG
	PrintToChatAll("[DEBUG] WitchCounter: %d", g_iWitchCounter);
	#endif
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

void Reset()
{
	g_bFinaleStarts = false;
	g_bChekingFlow = false;
	// Reset counters for tanks and witches
	g_iTankCounter = 0;
	g_iWitchCounter = 0;
	// Reset flow distances for tank and witch spawning
	g_fFlowSpawnTank = 0.0;
	g_fFlowSpawnWitch = 0.0;
	delete g_hTimerCheckFlow;
}

void Event_PlayerLeftCheckpoint(Event event, const char[] name, bool dontBroadcast)
{
	// Exit early if the flow-checking process is already active
	if (g_bChekingFlow) 
		return;
	// Check if spawning is disallowed on the first or final map
	bool isFirstMapNoSpawns = g_bIsFirstMap && !g_bStartTanks && !g_bStartWitches;
	bool isFinalMapNoSpawns = g_bIsFinalMap && !g_iFinaleTanks && !g_iFinaleWitches;
	// If no spawning is allowed for the current map conditions, delete the timer and exit
	if (isFirstMapNoSpawns || isFinalMapNoSpawns) 
	{
		delete g_hTimerCheckFlow;
		return;
	}
	// Get the client ID based on the event's user ID
	int client = GetClientOfUserId(event.GetInt("userid"));
	// Ensure the client is a valid survivor before proceeding
	if (!IsValidSurvivor(client)) 
		return;
	// Determine whether tanks can spawn based on map conditions and settings
	g_bAllowSpawnTanks = (g_bStartTanks && g_bIsFirstMap || !g_bIsFirstMap) && (g_iFinaleTanks == 3 || !g_bIsFinalMap || (!g_bFinaleStarts && g_iFinaleTanks == 1));
	// Determine whether witches can spawn based on map conditions and settings
	g_bAllowSpawnWitches = (g_bStartWitches && g_bIsFirstMap || !g_bIsFirstMap) && (g_iFinaleWitches == 3 || !g_bIsFinalMap || (!g_bFinaleStarts && g_iFinaleWitches == 1));
	// Start the flow-checking process by creating a timer
	CreateTimer(0.1, StartCheckFlow, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action StartCheckFlow(Handle timer)
{
	// Exit early if the flow-checking process is already active or no survivor has left the safe area
	if (g_bChekingFlow || !L4D_HasAnySurvivorLeftSafeArea()) 
		return Plugin_Continue;
	// Mark the flow-checking process as active
	g_bChekingFlow = true;
	g_bFinaleStarts = false;
	// Get the maximum flow distance for the current map
	g_fFlowMaxMap = L4D2Direct_GetMapMaxFlowDistance();
//	int maxTanks = g_iTotalTanks;
//	if (g_bIsFirstMap)
//		maxTanks = 1;
    	// Determine the maximum number of tanks and witches based on settings and randomization
	g_iMaxTanks = (g_iTotalTanksRandom > 0) ? GetRandomIntEx(g_iTotalTanks, g_iTotalTanksRandom) : g_iTotalTanks;
	g_iMaxWitches = (g_iTotalWitchesRandom > 0) ? GetRandomIntEx(g_iTotalWitches, g_iTotalWitchesRandom) : g_iTotalWitches;
	// Calculate flow ranges for tank spawning
	g_fFlowRangeMinTank = g_fFlowMaxMap * (g_fFlowPercentMinTank / 100.0);
	g_fFlowRangeMaxTank = g_fFlowMaxMap * (g_fFlowPercentMaxTank / 100.0);
	g_fFlowRangeSpawnTank = (g_fFlowRangeMaxTank - g_fFlowRangeMinTank) / float(g_iMaxTanks);
	g_fFlowCanSpawnTank = g_fFlowRangeMinTank;
	// Calculate flow ranges for witch spawning
	g_fFlowRangeMinWitch = g_fFlowMaxMap * (g_fFlowPercentMinWitch / 100.0);
	g_fFlowRangeMaxWitch = g_fFlowMaxMap * (g_fFlowPercentMaxWitch / 100.0);
	g_fFlowRangeSpawnWitch = (g_fFlowRangeMaxWitch - g_fFlowRangeMinWitch) / float(g_iMaxWitches);
	g_fFlowCanSpawnWitch = g_fFlowRangeMinWitch;
	// Delete the previous timer if it exists and create a new repeating timer for flow-checking
	delete g_hTimerCheckFlow;
	g_hTimerCheckFlow = CreateTimer(g_fInterval, TimerCheckFlow, _, TIMER_REPEAT);
	return Plugin_Stop;
}

// Timer function to check flow and handle spawning logic
Action TimerCheckFlow(Handle timer)
{
	#if DEBUG
	PrintToChatAll("[DEBUG] TimerCheckFlow called.");
	#endif
	// Stop the timer if the maximum number of Tanks and Witches has been reached
	if (g_iTankCounter >= g_iMaxTanks && g_iWitchCounter >= g_iMaxWitches)
	{
		#if DEBUG
		PrintToChatAll("[DEBUG] Maximum Tanks and Witches reached. Stopping timer.");
		#endif
		g_hTimerCheckFlow = null;
		return Plugin_Stop;
	}
	// Update the highest flow survivor and calculate player flow
	g_iPlayerHighestFlow = L4D_GetHighestFlowSurvivor();
	g_fFlowPlayers = IsValidSurvivor(g_iPlayerHighestFlow) ? L4D2Direct_GetFlowDistance(g_iPlayerHighestFlow) : L4D2_GetFurthestSurvivorFlow();
	// Handle spawning of Tanks
	if (g_bAllowSpawnTanks && g_iTankCounter < g_iMaxTanks && g_fFlowPlayers >= g_fFlowRangeMinTank && g_fFlowPlayers <= g_fFlowRangeMaxTank)
	{
		// Calculate the flow threshold for spawning Tanks if not already set
		if (!g_fFlowSpawnTank)
			g_fFlowSpawnTank = g_bRangeRandom ? GetRandomFloatEx(g_fFlowCanSpawnTank, g_fFlowCanSpawnTank + g_fFlowRangeSpawnTank) : g_fFlowCanSpawnTank + (g_iTankCounter ? g_fFlowRangeSpawnTank : float(0));
		// Spawn Tanks if player flow meets the threshold
		if (g_fFlowPlayers >= g_fFlowSpawnTank)
		{
			int tanks = g_iTanksRandom ? GetRandomIntEx(g_iTanks, g_iTanksRandom) : g_iTanks;
			for (int i = 0; i < tanks; i++)
			{
				float spawnpos[3];
				if (GetSpawnPosition(8, 30, spawnpos, "tank") && g_iTanksChance >= GetRandomIntEx(1, 100))
				{
					if (SpawnEntity(spawnpos, "tank") > 0)
					{
						g_fFlowCanSpawnTank += g_fFlowRangeSpawnTank; // Update the flow range for the next spawn
						g_fFlowSpawnTank = 0.0;
						if (g_bCheckTanks)
							g_iTankCounter++; // Increment the Tank counter
						#if DEBUG
						PrintToChatAll("[DEBUG] Tank counter incremented to %d.", g_iTankCounter);
						#endif
					}
				}
			}
		}
	}
	// Handle spawning of Witches
	if (g_bAllowSpawnWitches && g_iWitchCounter < g_iMaxWitches && g_fFlowPlayers >= g_fFlowRangeMinWitch && g_fFlowPlayers <= g_fFlowRangeMaxWitch)
	{
		// Calculate the flow threshold for spawning Witches if not already set
		if (!g_fFlowSpawnWitch)
			g_fFlowSpawnWitch = GetRandomFloatEx(g_fFlowCanSpawnWitch, g_fFlowCanSpawnWitch + g_fFlowRangeSpawnWitch);
		// Spawn Witches if player flow meets the threshold
		if (g_fFlowPlayers >= g_fFlowSpawnWitch)
		{
			int witches = g_iWitchesRandom ? GetRandomIntEx(g_iWitches, g_iWitchesRandom) : g_iWitches;
			for (int i = 0; i < witches; i++)
			{
				float spawnpos[3];
				if (GetSpawnPosition(7, 30, spawnpos, "witch") && g_iWitchesChance >= GetRandomIntEx(1, 100))
				{
					if (SpawnEntity(spawnpos, "witch") > 0)
					{
						g_fFlowCanSpawnWitch += g_fFlowRangeSpawnWitch; // Update the flow range for the next spawn
						g_fFlowSpawnWitch = 0.0;
						if (g_bCheckWitches)
							g_iWitchCounter++; // Increment the Witch counter
						#if DEBUG
						PrintToChatAll("[DEBUG] Witch counter incremented to %d.", g_iWitchCounter);
						#endif
					}
				}
			}
		}
	}
	// Continue the timer to check again
	return Plugin_Continue;
}

// Function to get a valid spawn position within a specified range
bool GetSpawnPosition(int zombieClass, int attempts, float spawnpos[3], const char[] entityType)
{
	// Try to find a spawn position near the survivor with the highest flow
	if (IsValidClient(g_iPlayerHighestFlow))
	{
		if (L4D_GetRandomPZSpawnPosition(g_iPlayerHighestFlow, zombieClass, attempts, spawnpos))
			return true;
	}
	// If no position was found, iterate through all survivors
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidSurvivor(i) && L4D_GetRandomPZSpawnPosition(i, zombieClass, attempts, spawnpos))
			return true;
	}
	// Log a warning if no valid spawn position was found
	LogMessage("No valid spawn position found for %s.", entityType);
	return false;
}

// Function to spawn an entity (Tank or Witch) at the given position
int SpawnEntity(float spawnpos[3], const char[] entityType)
{
	if (StrEqual(entityType, "tank"))
		return L4D2_SpawnTank(spawnpos, NULL_VECTOR); // Spawn a tank
	else if (StrEqual(entityType, "witch"))
		return L4D2_SpawnWitch(spawnpos, NULL_VECTOR); // Spawn a witch
	// Log an error if an invalid entity type was passed
	#if DEBUG
	LogMessage("Invalid entity type: %s", entityType);
	#endif
	return 0; // Return 0 if the entity type is invalid
}

stock int GetRandomIntEx(int min, int max)
{
	return GetURandomInt() % (max - min + 1) + min;
}

stock float GetRandomFloatEx(float min, float max)
{
	return GetURandomFloat() * (max - min) + min;
}

stock bool IsValidSpect(int client)
{ 
	return IsValidClient(client) && GetClientTeam(client) == 1;
}

stock bool IsValidSurvivor(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == 2;
}

stock bool IsValidInfected(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == 3;
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock bool IsValidEnt(int entity)
{
	return entity > MaxClients && IsValidEntity(entity) && entity != INVALID_ENT_REFERENCE;
}