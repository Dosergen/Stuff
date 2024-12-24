/*
	SourceMod Anti-Cheat
	Copyright (C) 2011-2016 SMAC Development Team
	Copyright (C) 2007-2011 CodingDirect LLC

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#pragma semicolon 1
#pragma newdecls required

/* SM Includes */
#include <sourcemod>
#include <sdktools>
#include <smac>

#undef REQUIRE_EXTENSIONS
#include <connecthook>
#define REQUIRE_EXTENSIONS

/* Globals */
int g_iNameChanges[MAXPLAYERS + 1];
int g_iAchievements[MAXPLAYERS + 1];

bool g_bMapStarted;

float g_fTeamJoinTime[MAXPLAYERS + 1][6];

ConVar g_cvConnectSpam;
float g_fConnectSpam;

ConVar g_cvAuthValidate;
bool g_bAuthValidate;

StringMap g_smClientConnections;
StringMap g_smLogList;

/* Plugin Functions */
public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax)
{
	g_bMapStarted = bLate;
	return APLRes_Success;
}

/* Plugin Info */
public Plugin myinfo =
{
	name        = "SMAC Client Protection",
	author      = SMAC_AUTHOR,
	description = "Blocks general client exploits",
	version     = SMAC_VERSION,
	url         = SMAC_URL
}

public void OnPluginStart()
{
	// Convars.
	g_cvConnectSpam = SMAC_CreateConVar("smac_antispam_connect", "2", "Block reconnection attempts for X seconds. (0 = Disabled)", FCVAR_NONE, true, 0.0, false, 0.0);
	g_fConnectSpam = g_cvConnectSpam.FloatValue;
	g_cvConnectSpam.AddChangeHook(ConVarChanged);

	g_cvAuthValidate = SMAC_CreateConVar("smac_validate_auth", "1", "Kick clients that fail to authenticate within 10 seconds of joining the server.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bAuthValidate = g_cvAuthValidate.BoolValue;
	g_cvAuthValidate.AddChangeHook(ConVarChanged);

	g_smClientConnections = new StringMap();
	g_smLogList = new StringMap();

	// Hooks.
	if (SMAC_GetGameType() == Game_CSS || SMAC_GetGameType() == Game_TF2)
		HookUserMessage(GetUserMessageId("TextMsg"), Hook_TextMsg, true);

	HookEventEx("player_team", Event_PlayerTeam, EventHookMode_Pre);
	HookEventEx("achievement_earned", Event_AchievementEarned, EventHookMode_Pre);

	HookEvent("player_changename", Event_PlayerChangeName, EventHookMode_Post);

	CreateTimer(10.0, Timer_DecreaseCount, _, TIMER_REPEAT);

	LoadTranslations("smac.phrases");
}

void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fConnectSpam  = g_cvConnectSpam.FloatValue;
	g_bAuthValidate = g_cvAuthValidate.BoolValue;
}

public void OnMapStart()
{
	// Give time for players to connect before we start checking for spam.
	CreateTimer(20.0, Timer_MapStarted, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_MapStarted(Handle hTimer)
{
	g_bMapStarted = true;
	return Plugin_Stop;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
	g_smClientConnections.Clear();
	g_smLogList.Clear();
}

public Action OnClientPreConnect(const char[] szName, const char[] szPw, const char[] szIp, const char[] szSteamId, char szRejectReason[255])
{
	if (IsConnectSpamming(szIp))
	{
		if (ShouldLogIP(szIp))
			SMAC_Log("%s (ID: %s | IP: %s) was temporarily banned for connection spam.", szName, szSteamId, szIp);
		BanIdentity(szIp, 1, BANFLAG_IP, "Spam Connecting", "SMAC");
		FormatEx(szRejectReason, sizeof(szRejectReason), "%T", "SMAC_PleaseWait", LANG_SERVER);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public void OnClientPutInServer(int iClient)
{
	if (IsClientNew(iClient))
	{
		g_iNameChanges [iClient] = 0;
		g_iAchievements[iClient] = 0;
	}
	// Give the client 10s to fully authenticate.
	if (!IsFakeClient(iClient) && !IsClientAuthorized(iClient) && g_bAuthValidate)
		CreateTimer(10.0, Timer_ValidateAuth, GetClientSerial(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ValidateAuth(Handle hTimer, any aSerial)
{
	int iClient = GetClientFromSerial(aSerial);
	if (IS_CLIENT(iClient) && !IsClientAuthorized(iClient))
		KickClient(iClient, "%t", "SMAC_FailedAuth");
	return Plugin_Stop;
}

public void OnClientDisconnect(int iClient)
{
	for (int i = 0; i < sizeof(g_fTeamJoinTime[]); i++)
		g_fTeamJoinTime[iClient][i] = 0.0;
}

public Action Hook_TextMsg(UserMsg MsgId, Handle hBf, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	// Name spam notices will only be sent to the offending client.
	if (!bReliable || iPlayersNum != 1)
		return Plugin_Continue;
	// The message we are looking for is sent to chat.
	int iDestination = BfReadByte(hBf);
	if (iDestination != 3)
		return Plugin_Continue;
	char szBuffer[64];
	BfReadString(hBf, szBuffer, sizeof(szBuffer));
	if (StrEqual(szBuffer, "#Name_change_limit_exceeded"))
	{
		int iClient = iPlayers[0];
		if (!IsFakeClient(iClient) && SMAC_CheatDetected(iClient, Detection_NameChangeSpam, null) == Plugin_Continue)
		{
			SMAC_LogAction(iClient, "was kicked for name change spam.");
			KickClient(iClient, "%t", "SMAC_CommandSpamKick");
		}
	}
	return Plugin_Continue;
}

void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	if (bDontBroadcast)
		return;
	// Don't broadcast team changes if they're being spammed.
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	int iTeam = eEvent.GetInt("team");
	if (IS_CLIENT(iClient))
	{
		float fGameTime = GetGameTime();
		if (iTeam < 0 || iTeam >= sizeof(g_fTeamJoinTime[]))
			iTeam = 0;
		if (g_fTeamJoinTime[iClient][iTeam] > fGameTime)
			eEvent.BroadcastDisabled = true;
		g_fTeamJoinTime[iClient][iTeam] = fGameTime + 30.0;
	}
}

void Event_PlayerChangeName(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	if (IS_CLIENT(iClient) && IsClientInGame(iClient) && !IsFakeClient(iClient) && ++g_iNameChanges[iClient] >= 5)
	{
		if (SMAC_CheatDetected(iClient, Detection_NameChangeSpam, null) == Plugin_Continue)
		{
			SMAC_LogAction(iClient, "was kicked for name change spam.");
			KickClient(iClient, "%t", "SMAC_CommandSpamKick");
		}
		g_iNameChanges[iClient] = 0;
	}
}

Action Event_AchievementEarned(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = eEvent.GetInt("player");
	if (IS_CLIENT(iClient) && ++g_iAchievements[iClient] >= 5)
		return Plugin_Stop;
	return Plugin_Continue;
}

Action Timer_DecreaseCount(Handle hTimer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iNameChanges[i])
			g_iNameChanges[i]--;
		if (g_iAchievements[i])
			g_iAchievements[i]--;
	}

	return Plugin_Continue;
}

bool IsConnectSpamming(const char[] szIp)
{
	if (!g_bMapStarted)
		return false;
	if (!IsServerProcessing())
		return false;
	float fSpamTime = g_fConnectSpam;
	if (fSpamTime > 0.0)
	{
		int iDummy;
		if (g_smClientConnections.GetValue(szIp, iDummy))
			return true;
		else if (g_smClientConnections.SetValue(szIp, 1))
			CreateTimer(fSpamTime, Timer_AntiSpamConnect, IPToLong(szIp));
	}
	return false;
}

bool ShouldLogIP(const char[] szIp)
{
	/* Only log each IP once to prevent log spam. */
	int iDummy;
	if (g_smLogList.GetValue(szIp, iDummy))
		return false;
	g_smLogList.SetValue(szIp, 1);
	return true;
}

Action Timer_AntiSpamConnect(Handle hTimer, any aIp)
{
	char szIP[17];
	LongToIP(aIp, szIP, sizeof(szIP));
	g_smClientConnections.Remove(szIP);
	return Plugin_Stop;
}