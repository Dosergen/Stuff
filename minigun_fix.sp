#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

bool g_bLateLoad = false;
bool g_bInMinigun[MAXPLAYERS+1];

public Plugin myinfo =
{
	name =          "[L4D/2] Minigun fix",
	author =        "SMAC, Kyle Sanderson, Dosergen",
	description =   "Prevents players to fly long distances",
	version =       "1.2.1",
	url =           "https://github.com/Dosergen/Stuff"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead && test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	if (g_bLateLoad)
	{
		char sClassname[32];
		int maxEdicts = GetEntityCount();
		for (int i = MaxClients + 1; i < maxEdicts; i++)
		{
			if (IsValidEdict(i) && GetEdictClassname(i, sClassname, sizeof(sClassname)))
			{
				OnEntityCreated(i, sClassname);
			}
		}
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				g_bInMinigun[i] = true;
			}
		}
	}
}

public void OnClientDisconnect(int client)
{
	g_bInMinigun[client] = false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "prop_minigun") == 0 
	|| strcmp(classname, "prop_minigun_l4d1") == 0 
	|| strcmp(classname, "prop_mounted_machine_gun") == 0)
	{
		SDKHook(entity, SDKHook_Use, OnUse);
	}
}

Action OnUse(int entity, int activator, int caller, UseType type, float value)
{
	int iGround = GetEntPropEnt(caller, Prop_Send, "m_hGroundEntity");
	if (iGround == 0 || type != Use_Toggle)
	{
		if (IsValidClient(activator) && type == Use_Set)
		{
			g_bInMinigun[activator] = true;
			SDKHook(caller, SDKHook_PreThink, OnPreThink);
		}
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

Action OnPreThink(int client)
{
	int iButtons = GetClientButtons(client);
	if (!(iButtons & IN_JUMP) || !(GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONGROUND))
	{
		return Plugin_Continue;
	}
	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
	if (GetVectorLength(fVelocity) >= (GetEntPropFloat(client, Prop_Data, "m_flMaxspeed") * 1.2))
	{
		ScaleVector(fVelocity, GetRandomFloat(0.45, 0.72));
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
	}
	SDKUnhook(client, SDKHook_PreThink, OnPreThink);
	return Plugin_Continue;
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}