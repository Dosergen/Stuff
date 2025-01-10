#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.1"

int     g_iHealth;
bool    g_bEnabled;
float   g_fTempHealth;
ConVar  g_hHealth,
        g_hEnabled,
        g_hTempHealth;

public Plugin myinfo =
{
	name = "L4D2 BW Closet",
	author = "Crimson_Fox, Dosergen",
	description = "Black & white screen when rescued from closet.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=111367"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("bwcloset_version", PLUGIN_VERSION, "BW Closet Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_hEnabled = CreateConVar("l4d2_bwcloset", "1", "Enable or Disable plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hHealth = CreateConVar("l4d2_bwcloset_health", "1.0", "Amount of a player health.", FCVAR_NOTIFY, true, 1.0, true, 100.0);
	g_hTempHealth = CreateConVar("l4d2_bwcloset_temphealth", "30.0", "Amount of a player temp health.", FCVAR_NOTIFY, true, 0.0, true, 100.0);

	GetCvars();

	g_hEnabled.AddChangeHook(ConVarChanged_Cvars);
	g_hHealth.AddChangeHook(ConVarChanged_Cvars);
	g_hTempHealth.AddChangeHook(ConVarChanged_Cvars);
	
	HookEvent("survivor_rescued", eSurvRescued);
	HookEvent("heal_success", eStopBeat);
	HookEvent("player_death", eStopBeat);
	
	AutoExecConfig(true, "l4d2_bwcloset");
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bEnabled = g_hEnabled.BoolValue;
	g_iHealth = g_hHealth.IntValue;
	g_fTempHealth = g_hTempHealth.FloatValue;
}

void eSurvRescued(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bEnabled)
	{
		int client = GetClientOfUserId(event.GetInt("victim"));
		if (client && IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			int maxinc = FindConVar("survivor_max_incapacitated_count").IntValue;
			SetEntProp(client, Prop_Send, "m_currentReviveCount", maxinc);
			
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 1);
			SetEntProp(client, Prop_Send, "m_isGoingToDie", 1);
			
			EmitSoundToClient(client, "player/heartbeatloop.wav");
			
			SetEntProp(client, Prop_Send, "m_iHealth", g_iHealth);
			SetTempHealth(client, g_fTempHealth);
		}
	}
}

void eStopBeat(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if (client)
	{
		StopSound(client, SNDCHAN_AUTO, "player/heartbeatloop.wav");
	}
}

void SetTempHealth(int &client, float fHp)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fHp);
}