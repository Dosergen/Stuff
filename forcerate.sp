#pragma semicolon 1

#include <sourcemod>

#pragma newdecls required

ConVar hRate, hCmdRate, hUpdateRate, hMsg;

char CmdString[192], Msg[192];

public Plugin myinfo = 
{
	name = "Forcerate",
	author = "Lomaka [Edited by Dosergen]",
	description = "Automatically corrects rates of client",
	version = "2.2",
	url = ""
}

public void OnPluginStart()
{
	hRate = CreateConVar("fr_rate", "100000", "Forcerate default rate.", 0, true, 10.0, true, 100000.0);
	hCmdRate = CreateConVar("fr_cl_cmdrate", "100", "Forcerate default cl_cmdrate.", 0, true, 10.0, true, 1000.0);
	hUpdateRate = CreateConVar("fr_cl_updaterate", "100", "Forcerate default cl_updaterate.", 0, true, 10.0, true, 1000.0);

	hMsg = CreateConVar("sm_msg", "", "URL to Message file.", 0);
	
	HookEvent("player_spawn", PlayerSpawn, EventHookMode_Post);
	
	AutoExecConfig(true, "forcerate");
}

public void OnConfigsExecuted()
{
	Format(CmdString, sizeof(CmdString), "rate %d;cl_cmdrate %d;cl_updaterate %d", GetConVarInt(hRate), GetConVarInt(hCmdRate), GetConVarInt(hUpdateRate));
	
	GetConVarString(hMsg, Msg, sizeof(Msg));
}

public void PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event,"userid"));
	if(client != 0 && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) > 2)
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

public void ClientConVar(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	char rate[10], cmdrate[10], updaterate[10];
	GetConVarString(hRate, rate, sizeof(rate));
	GetConVarString(hCmdRate, cmdrate, sizeof(cmdrate));
	GetConVarString(hUpdateRate, updaterate, sizeof(updaterate));
	
	if(StrEqual("rate",cvarName,false))
	{
		if(!StrEqual(rate,cvarValue,false))
		{
			EnforceRates(client);
		}
	}
		
	if(StrEqual("cl_cmdrate",cvarName,false))
	{
		if(!StrEqual(cmdrate,cvarValue,false))
		{
			EnforceRates(client);
		}
	}
	
	if(StrEqual("cl_updaterate",cvarName,false))
	{
		if(!StrEqual(updaterate,cvarValue,false))
		{
			EnforceRates(client);
		}
	}
}

void EnforceRates(int client)
{
	Handle ForcerateMsg = CreateKeyValues("data");
	
	KvSetString(ForcerateMsg, "title", "Rates has been updated to optimal values");
	KvSetString(ForcerateMsg, "type", "2");
	KvSetString(ForcerateMsg, "msg", Msg);
	KvSetString(ForcerateMsg, "cmd", CmdString);
	
	ShowVGUIPanel(client, "info", ForcerateMsg);
	
	CloseHandle(ForcerateMsg);
}

public void OnClientSettingsChanged(int client)
{
	if(IsClientInGame(client) && GetClientTeam(client))
	{
		CheckRates(client);
	}
}