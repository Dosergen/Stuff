#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "0.8.3"
#define MAX_DOORS 128
#define MAX_SIZE 2048
#define DEBUG 0

ConVar  g_hCvarEnable, g_hCvarNearestDistance, g_hCvarEntitiesToRemove;
bool    g_bPluginEnable, g_bLoaded, g_bHookedEvents,
        g_bIsRescueMainEntity[MAX_SIZE], g_bIsRescueNearDelEntity[MAX_SIZE];
int     g_iEntitiesToRemove, g_iForRescueProp[MAXPLAYERS + 1];
float   g_fNearestDistance;

public Plugin myinfo =
{
	name = "[L4D/2] Limited Rescue",
	author = "Electr0, Dosergen",
	description = "subj",
	version = PLUGIN_VERSION,
	url = "https://github.com/Dosergen/Stuff"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead && test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d_limited_rescue_version", PLUGIN_VERSION, "Plugin version.", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_hCvarEnable = CreateConVar("l4d_limited_rescue_enable", "1", "Enable the plugin?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarNearestDistance = CreateConVar("l4d_limited_rescue_nearest_distance", "200.0", "Maximum distance to find nearby rescue entities.", FCVAR_NOTIFY, true, 100.0, true, 300.0);
	g_hCvarEntitiesToRemove = CreateConVar("l4d_limited_rescue_entities_to_remove", "2", "How many entities to remove?", FCVAR_NOTIFY, true, 1.0, true, 2.0);

	g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarNearestDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarEntitiesToRemove.AddChangeHook(ConVarChanged_Cvars);
    
	AutoExecConfig(true, "l4d_limited_rescue");
    
	IsAllowed();
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bPluginEnable = g_hCvarEnable.BoolValue;
	g_fNearestDistance = g_hCvarNearestDistance.FloatValue;
	g_iEntitiesToRemove = g_hCvarEntitiesToRemove.IntValue;
}

void IsAllowed()
{
	GetCvars();
	if (g_bPluginEnable)
	{
		if (!g_bHookedEvents)
		{
			HookEvent("survivor_call_for_help", EvtCallRescue);
			HookEvent("survivor_rescued", EvtSurvRescued);
			HookEvent("round_start", EvtRoundStart);
			HookEvent("round_end", EvtRoundEnd);
			g_bHookedEvents = true;
		}
	}
	else if (!g_bPluginEnable)
	{
		if (g_bHookedEvents)
		{
			UnhookEvent("survivor_call_for_help", EvtCallRescue);
			UnhookEvent("survivor_rescued", EvtSurvRescued);
			UnhookEvent("round_start", EvtRoundStart);
			UnhookEvent("round_end", EvtRoundEnd);
			g_bHookedEvents = false;
		}
	}
}

void EvtRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bPluginEnable)
		return;
	g_bLoaded = false;
	CreateTimer(1.0, LeftSafeArea, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void EvtRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	// This can be used to perform any clean-up at the end of a round
}

void EvtCallRescue(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bPluginEnable)
		return;
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	int iSubject = event.GetInt("subject");
	#if DEBUG
	PrintToChatAll("EvtCallRescue: Client %N called for help on rescue prop %i", iClient, iSubject);
	#endif
	if (IsClientInGame(iClient) && GetClientTeam(iClient) == 2)
		g_iForRescueProp[iClient] = EntIndexToEntRef(iSubject);
}

void EvtSurvRescued(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bPluginEnable)
		return;
	int iVictim = GetClientOfUserId(event.GetInt("victim"));
	#if DEBUG
	PrintToChatAll("EvtSurvRescued: Survivor %N was rescued", iVictim);
	#endif
	if (IsClientInGame(iVictim) && GetClientTeam(iVictim) == 2)
	{
		if (IsValidEntRef(g_iForRescueProp[iVictim]))
		{
			RemoveEntity(g_iForRescueProp[iVictim]);
			#if DEBUG
			PrintToChatAll("EvtSurvRescued: Removed rescue prop with index %i", EntRefToEntIndex(g_iForRescueProp[iVictim]));
			#endif
		}
	}
}

Action LeftSafeArea(Handle Timer)
{
	if (SurvLeftSafe())    
	{
		if (!g_bLoaded)
		{
			g_bLoaded = true;
			ScriptInit();
			#if DEBUG
			PrintToChatAll("LeftSafeArea: Script initialization started.");
			#endif
			return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}

void ScriptInit()
{
	#if DEBUG
	LogMessage("ScriptInit: Starting script initialization");
	#endif
	if (!g_bPluginEnable) 
	{
		#if DEBUG
		LogMessage("ScriptInit: Plugin is disabled, exiting");
		#endif
		return;
	}
	for (int i = 0; i < MAX_SIZE; i++)
	{
		g_bIsRescueMainEntity[i] = false;
		g_bIsRescueNearDelEntity[i] = false;
	}
	int rescueEntityCount = 0;
	int rescueEntities[MAX_SIZE];
	int rescueEntity = INVALID_ENT_REFERENCE;
	float rescuePositions[MAX_SIZE][3];
	#if DEBUG
	LogMessage("ScriptInit: Searching for rescue entities...");
	#endif
	while ((rescueEntity = FindEntityByClassname(rescueEntity, "info_survivor_rescue")) != INVALID_ENT_REFERENCE)
	{
		if (rescueEntityCount < MAX_SIZE)
		{
			rescueEntities[rescueEntityCount] = rescueEntity;
			GetEntPropVector(rescueEntity, Prop_Data, "m_vecOrigin", rescuePositions[rescueEntityCount]);
			#if DEBUG
			LogMessage("ScriptInit: Found rescue entity with index %i at position (%.2f, %.2f, %.2f)", rescueEntity, rescuePositions[rescueEntityCount][0], rescuePositions[rescueEntityCount][1], rescuePositions[rescueEntityCount][2]);
			#endif
			rescueEntityCount++;
		}
	}
	#if DEBUG
	LogMessage("ScriptInit: Processing %i rescue entities", rescueEntityCount);
	#endif
	for (int i = 0; i < rescueEntityCount; i++)
	{
		int mainEntity = rescueEntities[i];
		if (g_bIsRescueNearDelEntity[mainEntity]) 
		{
			#if DEBUG
			LogMessage("ScriptInit: Skipping entity with index %i, already marked for deletion", mainEntity);
			#endif
			continue;
		}
		g_bIsRescueMainEntity[mainEntity] = true;
		int nearbyEntityCount = 0;
		for (int j = 0; j < rescueEntityCount; j++)
		{
			float distance = GetVectorDistance(rescuePositions[i], rescuePositions[j]);
			if (i != j && distance < g_fNearestDistance && nearbyEntityCount < g_iEntitiesToRemove)
			{
				nearbyEntityCount++;
				g_bIsRescueNearDelEntity[rescueEntities[j]] = true;
				RemoveEntity(rescueEntities[j]);
				#if DEBUG
				LogMessage("ScriptInit: Removed rescue entity with index %i at distance %.2f", rescueEntities[j], distance);
				#endif
			}
		}
	}
	#if DEBUG
	LogMessage("ScriptInit: Completed processing of rescue entities");
	#endif
}

// Checks if survivors have left the safe area by checking the terror player manager entity
static int g_iEntTerrorPlayerManager = INVALID_ENT_REFERENCE; // Reference for the terror player manager
bool SurvLeftSafe()
{
	int entity = EntRefToEntIndex(g_iEntTerrorPlayerManager); // Get the index of the terror player manager
	// Find the terror player manager entity if not already stored
	if (entity == INVALID_ENT_REFERENCE)
	{
		entity = FindEntityByClassname(-1, "terror_player_manager"); // Search for the entity
		if (entity == INVALID_ENT_REFERENCE)
		{
			g_iEntTerrorPlayerManager = INVALID_ENT_REFERENCE; // Reset if not found
			return false; // Return false if not found
		}
		g_iEntTerrorPlayerManager = EntIndexToEntRef(entity); // Store the entity reference
	}
	// Return true if any survivors have left the safe area
	return GetEntProp(entity, Prop_Send, "m_hasAnySurvivorLeftSafeArea") == 1; // Check if survivors have left
}

bool IsValidEntRef(int entity)
{
	return entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE;
}