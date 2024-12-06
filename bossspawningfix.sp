#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define	PROHIBIT_BOSSES 1 // false (0) turns on tanks and witches
#define	THREAT_TYPE     8 // ZOMBIE_WITCH = 7, ZOMBIE_TANK = 8 
#define TANK_LIMIT      0

bool g_bPluginEnable, g_bSkipStaticMaps, g_bFinalMap;
ConVar g_hCvarEnabled, g_hCvarSkipStaticMaps;

public Plugin myinfo =
{
	name = "Versus Boss Spawn Persuasion",
	author = "ProdigySim, Dosergen",
	description = "subj",
	version = "1.6",
	url = "https://github.com/Dosergen/Stuff"
}

public void OnPluginStart()
{
	g_hCvarEnabled = CreateConVar("l4d_obey_boss_spawn_cvars", "1", "Enable forcing boss spawns to obey boss spawn cvars (ignores the final maps)", _, true, 0.0, true, 1.0);
	g_hCvarSkipStaticMaps = CreateConVar("l4d_obey_boss_spawn_except_static", "1", "Don't override boss spawning rules on Static Tank Spawn maps (c7m1, c13m2)", _, true, 0.0, true, 1.0);

	g_hCvarEnabled.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSkipStaticMaps.AddChangeHook(ConVarChanged_Cvars);
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bPluginEnable = g_hCvarEnabled.BoolValue;
	g_bSkipStaticMaps = g_hCvarSkipStaticMaps.BoolValue;
}

public void OnMapStart()
{	
	g_bFinalMap = L4D_IsMissionFinalMap(true);
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
	if (g_bPluginEnable) 
	{
		if (!g_bFinalMap) 
		{
			int val = retVal;
			if (StrEqual(key, "ProhibitBosses"))
				val = PROHIBIT_BOSSES;
			else if (StrEqual(key, "DisallowThreatType"))
				val = THREAT_TYPE;
			else if (StrEqual(key, "TankLimit"))
				val = TANK_LIMIT;
			if (val != retVal)
			{
				retVal = val;
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public Action L4D_OnGetMissionVSBossSpawning(float &spawn_pos_min, float &spawn_pos_max, float &tank_chance, float &witch_chance)
{
	if (g_bPluginEnable) 
	{
		if (g_bSkipStaticMaps) 
		{
			char sMapName[32];
			GetCurrentMap(sMapName, sizeof(sMapName));
			if (strcmp(sMapName, "c7m1_docks") == 0 || strcmp(sMapName, "c13m2_southpinestream") == 0)
				return Plugin_Continue;
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}