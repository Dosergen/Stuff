#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.1"

bool Allow[MAXPLAYERS];
float forwardtime[MAXPLAYERS+1];

ConVar hDmg, hEnable, hSpeed, hTime;

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
	if( test != Engine_Left4Dead && test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d2_crawlbalancer_version", PLUGIN_VERSION, "Version of crawlbalancer on this server", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_REPLICATED);

	hEnable = CreateConVar("l4d2_crawlbalancer_enable", "1", "Enable Crawlbalancer on this server", FCVAR_NOTIFY);
	hDmg = CreateConVar("l4d2_crawlbalancer_damage", "1.3", "Multiplier for damage taken by crawling", FCVAR_NOTIFY);
	hSpeed = CreateConVar("l4d2_crawlbalancer_speed", "15", "Speed of crawling for survivors", FCVAR_NOTIFY);
	hTime = CreateConVar("l4d2_crawlbalancer_time", "1.0", "After how much crawling time will the bonus damage be added", FCVAR_NOTIFY);

	hEnable.AddChangeHook(OnEnabled);
	hSpeed.AddChangeHook(OnSpeedChanged);
	
	HookEvent("lunge_pounce", PounceStart);
	HookEvent("pounce_end", PounceEnd);
	HookEvent("revive_begin", BRevive);
	HookEvent("revive_end", ERevive);
	HookEvent("revive_success", SRevive);
	
	AutoExecConfig(true, "l4d2_crawlbalancer");
}

public void OnEnabled(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(!StringToInt(newValue))  
	{
		SetConVarInt(FindConVar("survivor_allow_crawling"), 0);
	}
	else 
	{
		SetConVarInt(FindConVar("survivor_allow_crawling"), 1);
	}
}

public void OnSpeedChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetConVarInt(FindConVar("survivor_crawl_speed"), StringToInt(newValue));
}

public void OnConfigsExecuted()
{
	if(GetConVarBool(hEnable))
	{
		SetConVarInt(FindConVar("survivor_allow_crawling"), 1);
	}
}	

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	forwardtime[client] = 0.0;
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if(GetConVarBool(hEnable) && IsClientInGame(victim) && IsPlayerAlive(victim) && GetEntProp(victim, Prop_Send, "m_isIncapacitated") && damagetype & DMG_POISON && forwardtime[victim] >= GetConVarInt(hTime))
	{
		forwardtime[victim] -= GetConVarInt(hTime);
		damage *= GetConVarFloat(hDmg);
		damage = float(RoundToCeil(damage));
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void OnMapStart()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		forwardtime[i] = 0.0;
		Allow[i] = false;
	}	
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon)
{
	if(GetConVarBool(hEnable) && Allow[client] && GetEntProp(client, Prop_Send, "m_isIncapacitated") && buttons & IN_FORWARD)
	{
		return Plugin_Handled;
	}

	if(GetConVarBool(hEnable) && buttons & IN_FORWARD && IsPlayerAlive(client) && GetClientTeam(client) == 2 && GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
	{
		forwardtime[client] += 0.0333333333; //this is a tick in l4d and l4d2.
	}
	return Plugin_Continue;
}

public void PounceStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "victim"));
	Allow[client] = true;
}	

public void PounceEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "victim"));
	Allow[client] = false;
}

public void BRevive(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	Allow[client] = true;
}

public void ERevive(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	Allow[client] = false;
}

public void SRevive(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	Allow[client] = false;
	forwardtime[client] = 0.0;
}