/*
	The expected input is the result of groupID64 % 4294967296
	You can get a group's groupID64 by visiting : https://steamcommunity.com/groups/ADDYOURGROUPSNAMEHERE/memberslistxml/?xml=1
	To convert the groupID64 , follow the link : https://gugy.eu/tools/groupid64/
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <steamworks>

#define PLUGIN_VERSION "0.2.1"

ConVar g_hGroupIds;
ConVar g_hNotify;
ConVar g_hMessage;
ConVar g_hMessDelay;

bool g_bNotify;
bool g_bInGroup[66];
float g_fMessDelay;
int g_iNumGroups;
int g_iGroupIds[100];
char g_sMessage[256];
char g_sGroupIds[1024];
Handle g_hDelayTimer[66];

public Plugin myinfo = 
{
	name = "Steam Group Invitation",
	author = "Impact, Dosergen",
	description = "An invitation to join the steam group for non-members.",
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
	CreateConVar("sm_steagi_version", PLUGIN_VERSION, "Plugin version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_hGroupIds  = CreateConVar("sm_steagi_ids", "", "List of group id's separated by comma. Use (groupd64 % 4294967296) to convert to expected input data.", FCVAR_PROTECTED);
	g_hNotify    = CreateConVar("sm_steagi_notify", "1", "Notify administrators about members who are not in the group.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hMessage   = CreateConVar("sm_steagi_message", "Greetings, Comrade. Join our steam group to keep up to date with news.", "Message displayed to client.");
	g_hMessDelay = CreateConVar("sm_steagi_message_delay", "180.0", "After how many seconds to repeat the message.", FCVAR_NOTIFY, true, 30.0, true, 300.0);
	
	g_hGroupIds.AddChangeHook(OnCvarChanged);
	g_hNotify.AddChangeHook(OnCvarChanged);
	g_hMessage.AddChangeHook(OnCvarChanged);
	g_hMessDelay.AddChangeHook(OnCvarChanged);

	AutoExecConfig(true, "steam_group_invitation");
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
}

void RefreshGroupIds()
{
	int count = 0;
	char g_sGroupBuf[sizeof(g_iGroupIds)][12];
	int explodes = ExplodeString(g_sGroupIds, ",", g_sGroupBuf, sizeof(g_sGroupBuf), sizeof(g_sGroupBuf[]));
	for (int i = 0; i <= explodes; i++)
	{
		TrimString(g_sGroupBuf[i]);
		if (explodes >= sizeof(g_iGroupIds))
		{
			SetFailState("Group Limit of %d reached", sizeof(g_iGroupIds));
			break;
		}
		int tmp = StringToInt(g_sGroupBuf[i]);
		if (tmp > 0)
		{
			g_iGroupIds[count] = tmp;
			count++;
		}
	}
	g_iNumGroups = count;
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
    delete g_hDelayTimer[client];
}

public void OnMapEnd()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        delete g_hDelayTimer[i];
    }
}

public void SteamWorks_OnValidateClient(int ownerauthid, int authid)
{
	for (int i = 0; i < g_iNumGroups; i++)
	{
		SteamWorks_GetUserGroupStatusAuthID(authid, g_iGroupIds[i]);
	}
}

public void SteamWorks_OnClientGroupStatus(int accountId, int groupId, bool isMember, bool isOfficer)
{
	int client = GetClientOfAccountId(accountId);
	if (client != -1)
	{
		if (isMember || isOfficer)
		{
			g_bInGroup[client] = true;
		}
		else if (!isMember)
		{
			if (g_bNotify)
			{
				MessageToAdmins(client, groupId);
			}
			g_hDelayTimer[client] = CreateTimer(g_fMessDelay, Timer_Display, client, TIMER_REPEAT);
		}
	}
}

void MessageToAdmins(int client, int groupId)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && CheckCommandAccess(i, "sm_steagi_admin", ADMFLAG_ROOT))
		{
			PrintToChat(i, "\x04[SGI]\x03 %N is not a member of the group \x01: \x03%d", client, groupId);
		}
	}
}

Action Timer_Display(Handle timer, int client)
{
	if (IsClientInGame(client) && !g_bInGroup[client])
	{
		PrintHintText(client, g_sMessage);
		return Plugin_Continue;		
	}
	g_hDelayTimer[client] = null;
	return Plugin_Stop;
}

int GetClientOfAccountId(int accountId)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (GetSteamAccountID(i) == accountId)
			{
				return i;
			}
		}
	}
	return -1;
}