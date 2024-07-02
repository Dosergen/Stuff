#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>

#define SAYTEXT_MAX_LENGTH 192

ConVar g_hCvarCvarChange, g_hCvarNameChange, g_hCvarSpecNameChange,
       g_hCvarSpecSeeChat, g_hCvarVocalDelay;
bool   g_bCvarChange, g_bNameChange, g_bSpecNameChange, g_bSpecSeeChat;
float  g_fLastVocalTime[MAXPLAYERS + 1];
int    g_iVocalDelay;

public Plugin myinfo = 
{
	name = "BeQuiet",
	author = "Sir, Dosergen",
	description = "Please be Quiet!",
	version = "1.34.0",
	url = "https://github.com/SirPlease/SirCoding"
}

public void OnPluginStart()
{
	g_hCvarCvarChange = CreateConVar("bq_cvar_change_suppress", "1", "Silence server cvars being changed, this makes for a clean chat with no disturbances.");
	g_hCvarNameChange = CreateConVar("bq_name_change_suppress", "1", "Silence player name changes.");
	g_hCvarSpecNameChange = CreateConVar("bq_name_change_spec_suppress", "1", "Silence spectating player name changes.");
	g_hCvarSpecSeeChat = CreateConVar("bq_show_player_team_chat_spec", "1", "Show spectators survivors and infected team chat?");
	g_hCvarVocalDelay = CreateConVar("bq_vocalize_guard_vdelay", "3", "Delay before a player can call another vocalize command.");

	GetCvars();

	g_hCvarCvarChange.AddChangeHook(CvarChanged);
	g_hCvarNameChange.AddChangeHook(CvarChanged);
	g_hCvarSpecNameChange.AddChangeHook(CvarChanged);
	g_hCvarSpecSeeChat.AddChangeHook(CvarChanged);
	g_hCvarVocalDelay.AddChangeHook(CvarChanged);

	AddCommandListener(Say_Callback, "say");
	AddCommandListener(TeamSay_Callback, "say_team");
	AddCommandListener(Vocal_Callback, "vocalize");

	HookEvent("server_cvar", evtServerConVar, EventHookMode_Pre);
	HookEvent("player_changename", evtNameChange, EventHookMode_Pre);
	HookEvent("player_disconnect", evtPlayerDisconnect, EventHookMode_Post);

	AutoExecConfig(true, "bequiet");
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bCvarChange = g_hCvarCvarChange.BoolValue;
	g_bNameChange = g_hCvarNameChange.BoolValue;
	g_bSpecNameChange = g_hCvarSpecNameChange.BoolValue;
	g_bSpecSeeChat = g_hCvarSpecSeeChat.BoolValue;
	g_iVocalDelay = g_hCvarVocalDelay.IntValue;
}

public void OnMapStart()
{
	ResetVocalTimes();
}

void ResetVocalTimes()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_fLastVocalTime[i] = 0.0;
	}
}

Action Say_Callback(int client, char[] command, int args)
{
	char sayWord[SAYTEXT_MAX_LENGTH];
	GetCmdArg(1, sayWord, sizeof(sayWord));
	if (sayWord[0] == '!' || sayWord[0] == '/')
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

Action TeamSay_Callback(int client, char[] command, int args)
{
	char sChat[SAYTEXT_MAX_LENGTH];
	GetCmdArg(1, sChat, sizeof(sChat));
	if (sChat[0] == '!' || sChat[0] == '/')
	{
		return Plugin_Handled;
	}
	if (g_bSpecSeeChat && GetClientTeam(client) >= 2)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && GetClientTeam(i) == 1)
			{
				CPrintToChat(i, GetClientTeam(client) == 2 ? "{default}(Survivor) {blue}%N {default}: %s" : "{default}(Infected) {red}%N {default}: %s", client, sChat);
			}
		}
	}
	return Plugin_Continue;
}

Action Vocal_Callback(int client, char[] command, int args)
{
	if (g_iVocalDelay > 0)
	{
		float currentTime = GetEngineTime();
		if (g_fLastVocalTime[client] >= (currentTime - g_iVocalDelay))
		{
			int iTimeLeft = RoundToNearest(g_iVocalDelay - (currentTime - g_fLastVocalTime[client]));
			PrintToChat(client, "\x04[SM] \x01Wait \x03%d\x01 seconds before vocalizing", iTimeLeft);
			return Plugin_Handled;
		}
		g_fLastVocalTime[client] = currentTime;
	}
	return Plugin_Continue;
}

Action evtServerConVar(Event event, const char[] name, bool dontBroadcast)
{
	if (!dontBroadcast && g_bCvarChange)
	{
		SetEventBroadcast(event, true);
	}
	return Plugin_Continue;
}

Action evtNameChange(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && !dontBroadcast && IsEnv(client))
	{
		SetEventBroadcast(event, true);
	}
	return Plugin_Continue;
}

Action evtPlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_fLastVocalTime[client] = 0.0;
	return Plugin_Continue;
}

stock bool IsEnv(int client)
{
	return g_bSpecNameChange && GetClientTeam(client) == 1 || g_bNameChange;
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}