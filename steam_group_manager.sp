/*
*	The expected input is the result of groupID64 % 4294967296
*	You can get a group's groupID64 by visiting : https://steamcommunity.com/groups/ADDYOURGROUPSNAMEHERE/memberslistxml/?xml=1
*	To convert the groupID64, follow the link : https://gugy.eu/tools/groupid64/
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <steamworks>

#define PLUGIN_VERSION "0.2.3"

ConVar g_hGroupIds,
       g_hNotify,
       g_hKick,
       g_hKickReason,
       g_hMessage,
       g_hMessDelay;

int    g_iNumGroups,
       g_iGroupIds[128];

char   g_sMessage[256],
       g_sKickReason[256],
       g_sGroupIds[1024];
	   
bool   g_bNotify,
       g_bKick,
       g_bInGroup[MAXPLAYERS+1];

Handle g_hDelayTimer[MAXPLAYERS+1];

float  g_fMessDelay;

public Plugin myinfo = 
{
	name = "Steam Group Manager",
	author = "Impact, Dosergen",
	description = "Manage player access based on their membership in specified Steam groups.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=320707"
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
	CreateConVar("sm_steamgroupmanager_version", PLUGIN_VERSION, "Plugin version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_hGroupIds   = CreateConVar("sm_steamgroupmanager_ids", "", "Comma-separated list of Steam group IDs (using groupID64 % 4294967296 format) to control server access.", FCVAR_PROTECTED);
	g_hNotify     = CreateConVar("sm_steamgroupmanager_notify", "1", "Enable notifications for administrators about players not in the specified groups (1 = enabled, 0 = disabled).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hMessage    = CreateConVar("sm_steamgroupmanager_message", "Welcome, Comrade. Get involved in our community and stay up-to-date.", "Message displayed to non-group players upon connection.", FCVAR_NOTIFY);
	g_hMessDelay  = CreateConVar("sm_steamgroupmanager_message_delay", "180.0", "Delay in seconds before sending a message to non-group players.", FCVAR_NOTIFY, true, 30.0, true, 300.0);
	g_hKick       = CreateConVar("sm_steamgroupmanager_kick", "0", "Automatically kick players who are not in any specified group (1 = enabled, 0 = disabled).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hKickReason = CreateConVar("sm_steamgroupmanager_kick_reason", "You are not a member of this server's group.", "Reason shown to players who are kicked for not being in the specified group.", FCVAR_NOTIFY);

	g_hGroupIds.AddChangeHook(OnCvarChanged);
	g_hNotify.AddChangeHook(OnCvarChanged);
	g_hMessage.AddChangeHook(OnCvarChanged);
	g_hMessDelay.AddChangeHook(OnCvarChanged);
	g_hKick.AddChangeHook(OnCvarChanged);
	g_hKickReason.AddChangeHook(OnCvarChanged);

	AutoExecConfig(true, "steam_group_manager");
}

public void OnConfigsExecuted()
{
	GetCvars();
	RefreshGroupIds();
}

void OnCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_hGroupIds.GetString(g_sGroupIds, sizeof(g_sGroupIds));
	g_bNotify = g_hNotify.BoolValue;
	g_hMessage.GetString(g_sMessage, sizeof(g_sMessage));
	g_fMessDelay = g_hMessDelay.FloatValue;
	g_bKick = g_hKick.BoolValue;
	g_hKickReason.GetString(g_sKickReason, sizeof(g_sKickReason));
}

void RefreshGroupIds()
{
	int count = 0;
	char g_sGroupBuf[sizeof(g_iGroupIds)][16];
	int explodes = ExplodeString(g_sGroupIds, ",", g_sGroupBuf, sizeof(g_sGroupBuf), sizeof(g_sGroupBuf[]));
	if (explodes > sizeof(g_iGroupIds))
	{
		SetFailState("Group Limit of %d reached", sizeof(g_iGroupIds));
		return;
	}
	for (int i = 0; i < explodes; i++)
	{
		TrimString(g_sGroupBuf[i]);
		int tmp = StringToInt(g_sGroupBuf[i]);
		if (tmp > 0)
			g_iGroupIds[count++] = tmp;
	}
	g_iNumGroups = count;
	LogMessage("Group IDs refreshed: %d groups loaded.", g_iNumGroups);
}

public void OnClientPutInServer(int client)
{
	if (IsClientInGame(client) && !IsFakeClient(client))
	{
		int accountId = GetSteamAccountID(client);
		SteamWorks_OnValidateClient(accountId, accountId);
	}
	g_bInGroup[client] = false;
}

public void OnClientDisconnect(int client)
{
	DeleteTimer(g_hDelayTimer[client]);
}

public void SteamWorks_OnValidateClient(int ownerauthid, int authid)
{
	for (int i = 0; i < g_iNumGroups; i++)
		SteamWorks_GetUserGroupStatusAuthID(authid, g_iGroupIds[i]);
}

public void SteamWorks_OnClientGroupStatus(int accountId, int groupId, bool isMember, bool isOfficer)
{
	int client = GetClientOfAccountId(accountId);
	if (client == -1)
		return;
	LogMessage("Account ID %d checked for Group ID %d - Status: %s", 
	accountId, groupId, (isMember ? (isOfficer ? "Officer" : "Member") : "Unknown"));
	g_bInGroup[client] = isMember || isOfficer;
	DeleteTimer(g_hDelayTimer[client]);
	if (!g_bInGroup[client])
	{
		if (g_bNotify)
			MessageToAdmins(client, groupId);
		if (g_bKick)
			KickClient(client, g_sKickReason);
		else
			g_hDelayTimer[client] = CreateTimer(g_fMessDelay, Timer_Display, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

int GetClientOfAccountId(int accountId)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (GetSteamAccountID(i) == accountId)
				return i;
		}
	}
	return -1;
}

void MessageToAdmins(int client, int groupId)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && CheckCommandAccess(i, "sm_admin", ADMFLAG_ROOT))
			PrintToChat(i, "\x04[SGM]\x03 %N\x01 is not a member of the required steam group (ID: \x03%d\x01)", client, groupId);
	}
}

Action Timer_Display(Handle timer, int client)
{
	if (IsClientInGame(client))
	{
		PrintHintText(client, g_sMessage);
		return Plugin_Continue;		
	}
	g_hDelayTimer[client] = null;
	return Plugin_Stop;
}

void DeleteTimer(Handle &timer)
{
	if (timer != null)
	{
		delete timer;
		timer = null;
	}
}