#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "2.3b"

ConVar g_hCvarColor, g_hCvarFlash;
bool g_bFlash, g_bLateLoad, g_bAdded[MAXPLAYERS + 1];
int g_iColor[3];

GlobalForward g_hForward_OnAdded;
GlobalForward g_hForward_OnRemoved;

public Plugin myinfo =
{
	name = "[L4D/2] Rescue Glow",
	author = "little_froy, Dosergen",
	description = "Fixes the original glow that becomes invisible when capturing another survival bot.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=348762"
}

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "This plugin is for Left 4 Dead 2 only.");
		return APLRes_SilentFailure;
	}

	g_hForward_OnAdded = new GlobalForward("RescueGlow_OnAdded", ET_Ignore, Param_Cell);
	g_hForward_OnRemoved = new GlobalForward("RescueGlow_OnRemoved", ET_Ignore, Param_Cell);

	CreateNative("RescueGlow_HasGlow", Native_HasGlow);

	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("rescue_glow_version", PLUGIN_VERSION, "[L4D/2] Rescue Glow plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hCvarColor = CreateConVar("rescue_glow_color", "255 102 0", "Color of glow, split by space.");
	g_hCvarFlash = CreateConVar("rescue_glow_flash", "1", "Will the glow flash?");

	g_hCvarColor.AddChangeHook(OnConVarChanged);
	g_hCvarFlash.AddChangeHook(OnConVarChanged);
	
	GetCvars();
	
	HookEvent("player_spawn", OnPlayerEvent);
	HookEvent("player_team", OnPlayerEvent);
	HookEvent("player_death", OnPlayerEvent);
	HookEvent("round_start", OnRoundStart);
	
	AutoExecConfig(true, "l4d2_rescue_glow");
	
	if (g_bLateLoad)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
				OnClientPutInServer(client);
		}
	}
}

public void OnPluginEnd()
{
	ResetAllGlows();
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	ParseColor(g_hCvarColor, g_iColor);
	g_bFlash = g_hCvarFlash.BoolValue;
}

void ParseColor(ConVar convar, int output[3])
{
	char cvar_colors[13], colors_get[3][4];
	convar.GetString(cvar_colors, sizeof(cvar_colors));
	ExplodeString(cvar_colors, " ", colors_get, 3, 4);
	for (int i = 0; i < 3; i++)
		output[i] = Clamp(StringToInt(colors_get[i]), 0, 255);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

void OnPostThinkPost(int entity)
{
	if (GetClientTeam(entity) == 2 && !IsPlayerAlive(entity))
	{
		int rescue = -1;
		while ((rescue = FindEntityByClassname(rescue, "info_survivor_rescue")) != -1)
		{
			if (GetEntPropEnt(rescue, Prop_Send, "m_survivor") == entity)
			{
				if (!g_bAdded[entity])
				{
					g_bAdded[entity] = true;
					SetGlow(entity, 3, g_iColor, 0, 0, g_bFlash);
					Call_StartForward(g_hForward_OnAdded);
					Call_PushCell(entity);
					Call_Finish();
				}
				return;
			}
		}
		if (g_bAdded[entity])
		{
			g_bAdded[entity] = false;
			SetGlow(entity);
			Call_StartForward(g_hForward_OnRemoved);
			Call_PushCell(entity);
			Call_Finish();
		}
	}
}

public void OnClientDisconnect(int client)
{
	g_bAdded[client] = false;
	SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetAllGlows();
}

void OnPlayerEvent(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client != 0)
		RemoveGlow(client);
}

void SetGlow(int entity, int type = 0, const int color[3] = {0, 0, 0}, int range = 0, int range_min = 0, bool flash = false)
{
	SetEntProp(entity, Prop_Send, "m_iGlowType", type);
	SetEntProp(entity, Prop_Send, "m_glowColorOverride", color[0] + color[1] * 256 + color[2] * 65536);
	SetEntProp(entity, Prop_Send, "m_nGlowRange", range);
	SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", range_min);
	SetEntProp(entity, Prop_Send, "m_bFlashing", flash ? 1 : 0);
}

void RemoveGlow(int client)
{
	if (g_bAdded[client])
	{
		g_bAdded[client] = false;
		if (IsClientInGame(client))
		{
			SetGlow(client);
			Call_StartForward(g_hForward_OnRemoved);
			Call_PushCell(client);
			Call_Finish();
		}
	}
}

void ResetAllGlows()
{
	for (int client = 1; client <= MaxClients; client++)
		RemoveGlow(client);
}

any Native_HasGlow(Handle plugin, int numParams)
{
	return g_bAdded[GetNativeCell(1)];
}

stock int Clamp(int value, int min, int max)
{
	return value < min ? min : (value > max ? max : value);
}