#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.2"
#define TICKRATE 0.0333333333
#define MAX_FORWARD_TIME 2.0

bool g_bLateLoad;

bool Allow[MAXPLAYERS + 1] = { false };
float ForwardTime[MAXPLAYERS + 1] = { 0.0 };

ConVar hDmg, hEnable, hSpeed, hTime;
Handle survivorAllowCrawling, survivorCrawlSpeed;

public Plugin myinfo = 
{
	name = "[L4D/2] Crawl Balancer",
	author = "McFlurry",
	description = "Increases damage while crawling",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=1567332"
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
	survivorAllowCrawling = FindConVar("survivor_allow_crawling");
	survivorCrawlSpeed = FindConVar("survivor_crawl_speed");

	CreateConVar("l4d2_crawlbalancer_version", PLUGIN_VERSION, "Version of Crawl Balancer on this server", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	hEnable = CreateConVar("l4d2_crawlbalancer_enable", "1", "Enable Crawl Balancer on this server", FCVAR_NOTIFY);
	hDmg = CreateConVar("l4d2_crawlbalancer_damage", "1.3", "Multiplier for damage taken by crawling", FCVAR_NOTIFY);
	hSpeed = CreateConVar("l4d2_crawlbalancer_speed", "15", "Speed of crawling for survivors", FCVAR_NOTIFY);
	hTime = CreateConVar("l4d2_crawlbalancer_time", "1.0", "Time before additional damage is applied", FCVAR_NOTIFY);

	hEnable.AddChangeHook(OnConVarChanged);
	hSpeed.AddChangeHook(OnConVarChanged);

	HookEvent("lunge_pounce", OnStateChange);
	HookEvent("pounce_end", OnStateChange);
	HookEvent("revive_begin", OnStateChange);
	HookEvent("revive_end", OnStateChange);
	HookEvent("revive_success", OnReviveSuccess);

	if (g_bLateLoad) 
	{
		for (int i = 1; i <= MaxClients; i++) 
		{
			if (IsValidClient(i))
				OnClientPutInServer(i);
		}
	}

	AutoExecConfig(true, "l4d2_crawlbalancer");
}

public void OnConfigsExecuted()
{
	UpdateCvars();
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	UpdateCvars();
}

void UpdateCvars()
{
	SetConVarBool(survivorAllowCrawling, hEnable.BoolValue);
	SetConVarInt(survivorCrawlSpeed, hSpeed.IntValue);
}

public void OnClientPutInServer(int client)
{
	ResetClientState(client);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	ResetClientState(client);
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if (!hEnable.BoolValue || !IsPlayerAlive(victim)) 
		return Plugin_Continue;
	if (IsValidClient(victim) && IsIncapacitated(victim) && damagetype & DMG_POISON)
	{
		if (ForwardTime[victim] >= hTime.FloatValue)
		{
			ForwardTime[victim] -= hTime.FloatValue;
			damage *= hDmg.FloatValue;
			damage = float(RoundToCeil(damage));
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon)
{
	if (!hEnable.BoolValue || !IsPlayerAlive(client)) 
		return Plugin_Continue;
	if (buttons & IN_FORWARD && IsIncapacitated(client) && Allow[client])
		return Plugin_Handled;
	if (buttons & IN_FORWARD && IsIncapacitated(client) && !IsHangingFromLedge(client) && GetClientTeam(client) == 2)
		ForwardTime[client] = Min(ForwardTime[client] + TICKRATE, MAX_FORWARD_TIME);
	return Plugin_Continue;
}

// Consolidated event hooks
void OnStateChange(Event event, const char[] name, bool dontBroadcast)
{
	int userId = event.GetInt("userid");
	ClientAllowState(userId, IsStartEvent(name));
}

void OnReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client))
		ResetClientState(client);
}

// Helper functions
float Min(float a, float b)
{
	return (a < b) ? a : b;
}

bool IsIncapacitated(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0;
}

bool IsHangingFromLedge(int client)
{
	return GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0;
}

bool IsStartEvent(const char[] name)
{
	return (strcmp(name, "lunge_pounce") == 0 || strcmp(name, "revive_begin") == 0);
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

void ClientAllowState(int userId, bool state)
{
	int client = GetClientOfUserId(userId);
	if (IsValidClient(client))
		Allow[client] = state;
}

void ResetClientState(int client)
{
	ForwardTime[client] = 0.0;
	Allow[client] = false;
}