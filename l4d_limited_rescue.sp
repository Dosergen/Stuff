#pragma	semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "0.8.2"
#define MAX_DOORS 128
#define MAX_SIZE 2048
#define DEBUG 0

ConVar  g_hCvarEnable, g_hCvarRescuePlayers;
int     g_iRescuePlayers, g_iForRescueProp[MAXPLAYERS + 1];
bool    g_bPluginEnable, g_bLoaded, g_bHookedEvents, 
        g_bIsRescueMainEntity[MAX_SIZE], g_bIsRescueNearDelEntity[MAX_SIZE];

#if DEBUG
int     g_iRescueTotal, 
        g_iForRescueClosets[MAX_DOORS];
#endif

public Plugin myinfo =
{
	name = "[L4D/2] Limited Rescue",
	author = "Electr0, Tabun, Dosergen",
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
	CreateConVar("l4d_limited_rescue_version", PLUGIN_VERSION, "Plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_hCvarEnable = CreateConVar("l4d_limited_rescue_enable", "1", "Enable the plugin?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarRescuePlayers = CreateConVar("l4d_limited_rescue_players", "1", "How many players spawn in the rescue closet?", FCVAR_NOTIFY, true, 0.0, true, 2.0);

	g_hCvarEnable.AddChangeHook(ConVarChanged_Allow);
	g_hCvarRescuePlayers.AddChangeHook(ConVarChanged_Cvars);
	
	AutoExecConfig(true, "l4d_limited_rescue");
	
	IsAllowed();
}

public void OnConfigsExecuted()
{
	IsAllowed();
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
	g_bPluginEnable = g_hCvarEnable.BoolValue;
	g_iRescuePlayers = g_hCvarRescuePlayers.IntValue;
}

void IsAllowed()
{	
	GetCvars();
	if (g_bPluginEnable)
	{
		if (!g_bHookedEvents)
		{
			HookEvent("survivor_call_for_help", Event_CallRescue);
			HookEvent("survivor_rescued", Event_SurvRescued);
			HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
			HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
			g_bHookedEvents = true;
		}
	}
	else if (!g_bPluginEnable)
	{
		if (g_bHookedEvents)
		{
			UnhookEvent("survivor_call_for_help", Event_CallRescue);
			UnhookEvent("survivor_rescued", Event_SurvRescued);
			UnhookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
			UnhookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
			g_bHookedEvents = false;
		}
	}
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bLoaded = false;
	CreateTimer(1.0, LeftSafeArea, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
}

void Event_CallRescue(Event event, const char[] name, bool dontBroadcast)
{
	if (event && g_bPluginEnable)
	{
		int iClient = GetClientOfUserId(event.GetInt("userid"));
		int iSubject = event.GetInt("subject");
		if (iClient && IsClientInGame(iClient) && GetClientTeam(iClient) == 2)
		{
			#if DEBUG
			int HammerID = GetEntProp(iSubject, Prop_Data, "m_iHammerID");
			PrintToChatAll("\x04Survivor_call_for_help \x03|| \x04client \x05%N \x03() \x04rescue prop \x05%i \x04(m_iHammerID %i)", iClient, iSubject, HammerID);
			#endif
			g_iForRescueProp[iClient] = EntIndexToEntRef(iSubject);
		}
	}
}

void Event_SurvRescued(Event event, const char[] name, bool dontBroadcast)
{
	if (event && g_bPluginEnable)
	{
		int iVictim = GetClientOfUserId(event.GetInt("victim"));
		if (iVictim && IsClientInGame(iVictim) && GetClientTeam(iVictim) == 2)
		{
			#if DEBUG
			int iRescuer = GetClientOfUserId(event.GetInt("rescuer"));
			PrintToChatAll("\x04Survivor_rescued \x03|| \x04survivor \x05%N \x03() \x04salvable \x05%N", iRescuer, iVictim);
			#endif
			if (IsValidEntRef(g_iForRescueProp[iVictim]))
			{
				RemoveEntity(g_iForRescueProp[iVictim]);
				#if DEBUG
				PrintToChatAll("\x04Survivor_rescued \x03|| \x04rescue prop with an index \x05%i \x04has been removed", EntRefToEntIndex(g_iForRescueProp[iVictim]));
				#endif
			}
		}
	}
}

Action LeftSafeArea(Handle Timer)
{
	if (!g_bLoaded)	
	{
		if (SurvLeftSafe())
		{
			g_bLoaded = true;
			ScriptInit();
			return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}

void ScriptInit()
{
	if (!g_bPluginEnable) 
	{
		return;
	}
	#if DEBUG
	PrintToChatAll("\x04ScriptInit has started - Survivors left the safe zone");
	SearchingRescueClosets();
	#endif
	for (int i = 0; i < MAX_SIZE; i++)
	{
		g_bIsRescueMainEntity[i] = false;
		g_bIsRescueNearDelEntity[i] = false;
	}
	#if DEBUG
	LogMessage("ScriptInit || LOOP INITIATION");
	int mainLoopCount = 0, subLoopCount = 0;
	#endif
	int rescueEntity = INVALID_ENT_REFERENCE, rescueEntities[MAX_SIZE], rescueEntityCount = 0;
	float rescuePositions[MAX_SIZE][3], nearestDistance = 200.0;
	while ((rescueEntity = FindEntityByClassname(rescueEntity, "info_survivor_rescue")) != INVALID_ENT_REFERENCE)
	{
		if (rescueEntityCount < MAX_SIZE)
		{
			rescueEntities[rescueEntityCount] = rescueEntity;
			GetEntPropVector(rescueEntity, Prop_Data, "m_vecOrigin", rescuePositions[rescueEntityCount]);
			rescueEntityCount++;
		}
	}
	for (int i = 0; i < rescueEntityCount; i++)
	{
		int mainEntity = rescueEntities[i];
		if (g_bIsRescueNearDelEntity[mainEntity]) 
		{
			continue;
		}
		g_bIsRescueMainEntity[mainEntity] = true;
		int nearbyEntityCount = 0;
		#if DEBUG
		mainLoopCount++;
		LogMessage("ScriptInit || Loop %i", mainLoopCount);
		#endif
		for (int j = 0; j < rescueEntityCount; j++)
		{
			if (i == j) 
			{
				continue;
			}
			int secondaryEntity = rescueEntities[j];
			if (g_bIsRescueMainEntity[secondaryEntity]) 
			{
				continue;
			}
			float distance = GetVectorDistance(rescuePositions[i], rescuePositions[j], false);
			if (distance < nearestDistance)
			{
				nearbyEntityCount++;
				g_bIsRescueNearDelEntity[secondaryEntity] = true;
				#if DEBUG
				LogMessage("ScriptInit || Found Near %i Entity - Distance %f, Count Nears %i, ConVar Count Players %i", secondaryEntity, distance, nearbyEntityCount, g_iRescuePlayers);
				LogMessage("First Entity Position (%f %f %f) - Next Entity Position (%f %f %f) - Distance %f", rescuePositions[i][0], rescuePositions[i][1], rescuePositions[i][2], rescuePositions[j][0], rescuePositions[j][1], rescuePositions[j][2], distance);
				subLoopCount++;
				LogMessage("ScriptInit || Sub Loop %i", subLoopCount);
				#endif
				if (g_iRescuePlayers > 0 && nearbyEntityCount >= g_iRescuePlayers)
				{
					RemoveEntity(secondaryEntity);
					#if DEBUG
					LogMessage("ScriptInit || Remove %i Entity - Distance %f", secondaryEntity, distance);
					#endif
				}
			}
		}
	}
	#if DEBUG
	LogMessage("ScriptInit || END OF LOOP");
	#endif
}

#if DEBUG
void SearchingRescueClosets()
{
	g_iRescueTotal = 0;
	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "info_survivor_rescue")) != INVALID_ENT_REFERENCE)
	{
		int nearest = GetNearestEntity(entity, "prop_door_rotating");
		if (nearest != INVALID_ENT_REFERENCE && !IsMarkedAsRescueCloset(nearest))
		{
			g_iForRescueClosets[g_iRescueTotal++] = nearest;
		}
	}
	PrintToChatAll("\x04Detected \x03%d \x04door(s) as belonging to rescue closets", g_iRescueTotal);
}

int GetNearestEntity(int startEntity, const char[] sClassname)
{
	int nearest = INVALID_ENT_REFERENCE;
	int entity = INVALID_ENT_REFERENCE;
	float fFirstVecOrigin[3], fNearestVecOrigin[3];
	float fNearestDistance = -1.0;
	GetEntPropVector(startEntity, Prop_Data, "m_vecOrigin", fFirstVecOrigin);
	while ((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
	{
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", fNearestVecOrigin);
		float fDistance = GetVectorDistance(fFirstVecOrigin, fNearestVecOrigin);
		if (fDistance < fNearestDistance || fNearestDistance == -1.0)
		{
			nearest = entity;
			fNearestDistance = fDistance;
		}
	}
	return nearest;
}

bool IsMarkedAsRescueCloset(int door)
{
	for (int i = 0; i < g_iRescueTotal; i++) 
	{
		if (g_iForRescueClosets[i] == door) 
		{
			return true;
		}
	}
	return false;
}
#endif

static int g_iEntTerrorPlayerManager = INVALID_ENT_REFERENCE;
bool SurvLeftSafe()
{
	int entity = EntRefToEntIndex(g_iEntTerrorPlayerManager);
	if (entity == INVALID_ENT_REFERENCE)
	{
		entity = FindEntityByClassname(-1, "terror_player_manager");
		if (entity == INVALID_ENT_REFERENCE)
		{
			g_iEntTerrorPlayerManager = INVALID_ENT_REFERENCE;
			return false;
		}
		g_iEntTerrorPlayerManager = EntIndexToEntRef(entity);
	}
	return GetEntProp(entity, Prop_Send, "m_hasAnySurvivorLeftSafeArea") == 1;
}

bool IsValidEntRef(int entity)
{
	return entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE;
}