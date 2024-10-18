#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

ConVar g_hRate, g_hCmdRate, g_hUpdateRate, g_hMsg;
char g_sCmdString[192], g_sMsg[192];

public Plugin myinfo = 
{
	name = "Forcerate",
	author = "Lomaka [Edited by Dosergen]",
	description = "Automatically corrects rates of client",
	version = "2.3",
	url = "https://forums.alliedmods.net/forumdisplay.php?f=52"
}

public void OnPluginStart()
{
	g_hRate = CreateConVar("fr_rate", "30000", "Forcerate default rate.", FCVAR_NOTIFY, true, 10.0, true, 30000.0);
	g_hCmdRate = CreateConVar("fr_cl_cmdrate", "100", "Forcerate default cl_cmdrate.", FCVAR_NOTIFY, true, 10.0, true, 100.0);
	g_hUpdateRate = CreateConVar("fr_cl_updaterate", "100", "Forcerate default cl_updaterate.", FCVAR_NOTIFY, true, 10.0, true, 100.0);
	g_hMsg = CreateConVar("sm_msg", "", "URL to Message file.");
	
	HookEvent("player_spawn", PlayerSpawn, EventHookMode_Post);
	AutoExecConfig(true, "forcerate");
}

public void OnConfigsExecuted()
{
	Format(g_sCmdString, sizeof(g_sCmdString), "rate %d;cl_cmdrate %d;cl_updaterate %d", g_hRate.IntValue, g_hCmdRate.IntValue, g_hUpdateRate.IntValue);
	g_hMsg.GetString(g_sMsg, sizeof(g_sMsg));
}

void PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client != 0 && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) > 2)
	{
		CheckRates(client);
	}
}

void CheckRates(int client)
{
	QueryClientConVar(client, "rate", ClientConVar, client);
	QueryClientConVar(client, "cl_cmdrate", ClientConVar, client);
	QueryClientConVar(client, "cl_updaterate", ClientConVar, client);
}

void ClientConVar(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	char rate[10], cmdrate[10], updaterate[10];
	g_hRate.GetString(rate, sizeof(rate));
	g_hCmdRate.GetString(cmdrate, sizeof(cmdrate));
	g_hUpdateRate.GetString(updaterate, sizeof(updaterate));
	if (StrEqual("rate", cvarName, false))
	{
		if (!StrEqual(rate, cvarValue, false))
		{
			EnforceRates(client);
		}
	}
	if (StrEqual("cl_cmdrate", cvarName, false))
	{
		if (!StrEqual(cmdrate, cvarValue, false))
		{
			EnforceRates(client);
		}
	}
	if (StrEqual("cl_updaterate", cvarName, false))
	{
		if (!StrEqual(updaterate, cvarValue, false))
		{
			EnforceRates(client);
		}
	}
}

void EnforceRates(int client)
{
	KeyValues kv = CreateKeyValues("data");
	kv.SetString("title", "Rates has been updated to optimal values");
	kv.SetString("type", "2");
	kv.SetString("msg", g_sMsg);
	kv.SetString("cmd", g_sCmdString);
	ShowVGUIPanel(client, "info", kv);
	delete kv;
}

public void OnClientSettingsChanged(int client)
{
	if (IsClientInGame(client) && GetClientTeam(client))
	{
		CheckRates(client);
	}
}