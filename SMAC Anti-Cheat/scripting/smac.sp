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

/* Globals */
#define SOURCEBANS_AVAILABLE() (GetFeatureStatus(FeatureType_Native, "SBBanPlayer") == FeatureStatus_Available)
#define SOURCEIRC_AVAILABLE() (GetFeatureStatus(FeatureType_Native, "IRC_MsgFlaggedChannels") == FeatureStatus_Available)
#define IRCRELAY_AVAILABLE() (GetFeatureStatus(FeatureType_Native, "IRC_Broadcast") == FeatureStatus_Available)

enum IrcChannel
{
	IrcChannel_Public = 1,
	IrcChannel_Private = 2,
	IrcChannel_Both = 3
}

// Logfile path var
char g_szLogFile[PLATFORM_MAX_PATH];
char g_szLogPath[PLATFORM_MAX_PATH];

native int SBBanPlayer(int iClient, int iTarget, int iTime, char[] szReason);
native int IRC_MsgFlaggedChannels(const char[] szFlag, const char[] szFormat, any ...);
native int IRC_Broadcast(IrcChannel cType, const char[] szFormat, any ...);

GameType g_Game = Game_Unknown;

ConVar g_cvVersion;

ConVar g_cvWelcomeMsg;
bool g_bWelcomeMsg;

ConVar g_cvBanDuration;
int g_iBanDuration;

ConVar g_cvLogVerbose;
bool g_bLogVerbose;

ConVar g_cvIrcMode;
int g_iIrcMode;

/* Plugin Info */
public Plugin myinfo =
{
	name        = "SourceMod Anti-Cheat",
	author      = SMAC_AUTHOR,
	description = "Open source anti-cheat plugin for SourceMod",
	version     = SMAC_VERSION,
	url         = SMAC_URL
}

/* Plugin Functions */
public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax)
{
	// Detect game.
	char szGame[64];
	GetGameFolderName(szGame, sizeof(szGame));

	if      (strcmp(szGame, "cstrike")          == 0) g_Game = Game_CSS;
	else if (strcmp(szGame, "cstrike_beta")     == 0) g_Game = Game_CSS;
	else if (strcmp(szGame, "tf")               == 0) g_Game = Game_TF2;
	else if (strcmp(szGame, "tf_beta")          == 0) g_Game = Game_TF2;
	else if (strcmp(szGame, "dod")              == 0) g_Game = Game_DODS;
	else if (strcmp(szGame, "left4dead")        == 0) g_Game = Game_L4D;
	else if (strcmp(szGame, "left4dead2")       == 0) g_Game = Game_L4D2;
	else if (strcmp(szGame, "hl2mp")            == 0) g_Game = Game_HL2DM;
	else if (strcmp(szGame, "fistful_of_frags") == 0) g_Game = Game_FOF;
	else if (strcmp(szGame, "hl2ctf")           == 0) g_Game = Game_HL2CTF;
	else if (strcmp(szGame, "hidden")           == 0) g_Game = Game_HIDDEN;
	else if (strcmp(szGame, "nucleardawn")      == 0) g_Game = Game_ND;
	else if (strcmp(szGame, "csgo")             == 0) g_Game = Game_CSGO;

	// Path used for logging.
	BuildPath(Path_SM, g_szLogPath, sizeof(g_szLogPath), "logs/SMAC.log");

	// Optional dependencies.
	MarkNativeAsOptional("SBBanPlayer");
	MarkNativeAsOptional("IRC_MsgFlaggedChannels");
	MarkNativeAsOptional("IRC_Broadcast");

	API_Init();
	RegPluginLibrary("smac");
	return APLRes_Success;
}

public void OnPluginStart()
{
	// Convars.
	g_cvVersion = CreateConVar("smac_version", SMAC_VERSION, "SourceMod Anti-Cheat", FCVAR_NOTIFY|FCVAR_DONTRECORD, false, 0.0, false, 0.0);
	g_cvVersion.AddChangeHook(OnVersionChanged);

	g_cvWelcomeMsg = CreateConVar("smac_welcomemsg", "0", "Display a message saying that your server is protected.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bWelcomeMsg = g_cvWelcomeMsg.BoolValue;
	g_cvWelcomeMsg.AddChangeHook(ConVarChanged);

	g_cvLogVerbose = CreateConVar("smac_log_verbose", "1", "Include extra information about a client being logged.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bLogVerbose = g_cvLogVerbose.BoolValue;
	g_cvLogVerbose.AddChangeHook(ConVarChanged);

	g_cvIrcMode = CreateConVar("smac_irc_mode", "1", "Which messages should be sent to IRC plugins. (1 = Admin notices, 2 = Mimic log)", FCVAR_NONE, true, 1.0, true, 2.0);
	g_iIrcMode = g_cvIrcMode.IntValue;
	g_cvIrcMode.AddChangeHook(ConVarChanged);

	g_cvBanDuration = CreateConVar("smac_ban_duration", "0", "The duration in minutes used for automatic bans. (0 = Permanent)", FCVAR_NONE, true, 0.0);
	g_iBanDuration = g_cvBanDuration.IntValue;
	g_cvBanDuration.AddChangeHook(ConVarChanged);

	BuildPath(Path_SM, g_szLogFile, sizeof(g_szLogFile), "logs/SMAC_errors.log");

	// Commands.
	RegAdminCmd("smac_status", Command_Status, ADMFLAG_GENERIC, "View the server's player status.");
	LoadTranslations("smac.phrases");
}

void OnVersionChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal)
{
	if (strcmp(szNewVal, SMAC_VERSION) == 0)
		return;
	g_cvVersion.SetString(SMAC_VERSION);
}

void ConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal)
{
	g_bWelcomeMsg = g_cvWelcomeMsg.BoolValue;
	g_bLogVerbose = g_cvLogVerbose.BoolValue;
	g_iIrcMode = g_cvIrcMode.IntValue;
	g_iBanDuration = g_cvBanDuration.IntValue;
}

public void OnAllPluginsLoaded()
{
	// Don't clutter the config if they aren't using IRC anyway.
	if (!SOURCEIRC_AVAILABLE() && !IRCRELAY_AVAILABLE())
		g_cvIrcMode.Flags = g_cvIrcMode.Flags | FCVAR_DONTRECORD;
	// Wait for other modules to create their convars.
	AutoExecConfig(true, "smac");
	PrintToServer("SourceMod Anti-Cheat %s has been successfully loaded.", SMAC_VERSION);
}

public void OnClientPutInServer(int iClient)
{
	if (!g_bWelcomeMsg)
		return;
	CreateTimer(10.0, Timer_WelcomeMsg, GetClientSerial(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_WelcomeMsg(Handle hTimer, any aSerial)
{
	int iClient = GetClientFromSerial(aSerial);
	if (!IS_CLIENT(iClient))
		return Plugin_Stop;
	if (!IsClientInGame(iClient))
		return Plugin_Stop;
	PrintToChat(iClient, "%t%t", "SMAC_Tag", "SMAC_WelcomeMsg");
	return Plugin_Stop;
}

Action Command_Status(int iClient, int iArgs)
{
	PrintToConsole(iClient, "%s  %-40s %s", "UserID", "AuthID", "Name");
	char szAuthID[MAX_AUTHID_LENGTH];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i))
			continue;
		if (!GetClientAuthId(i, AuthId_Steam2, szAuthID, sizeof(szAuthID), true))
		{
			if (GetClientAuthId(i, AuthId_Steam2, szAuthID, sizeof(szAuthID), false))
				Format(szAuthID, sizeof(szAuthID), "%s (Not Validated)", szAuthID);
			else
				strcopy(szAuthID, sizeof(szAuthID), "Unknown");
		}
		PrintToConsole(iClient, "%6d  %-40s %N", GetClientUserId(i), szAuthID, i);
	}
	return Plugin_Handled;
}

void SMAC_RelayToIRC(const char[] szFormat, any ...)
{
	char szBuffer[256];
	SetGlobalTransTarget(LANG_SERVER);
	VFormat(szBuffer, sizeof(szBuffer), szFormat, 2);
	if (SOURCEIRC_AVAILABLE())
		IRC_MsgFlaggedChannels("ticket", szBuffer);
	if (IRCRELAY_AVAILABLE())
		IRC_Broadcast(IrcChannel_Private, szBuffer);
}

/* API - Natives & Forwards */

GlobalForward g_fwdOnCheatDetected;

void API_Init()
{
	CreateNative("SMAC_GetGameType",      Native_GetGameType);
	CreateNative("SMAC_Log",              Native_Log);
	CreateNative("SMAC_LogAction",        Native_LogAction);
	CreateNative("SMAC_Ban",              Native_Ban);
	CreateNative("SMAC_PrintAdminNotice", Native_PrintAdminNotice);
	CreateNative("SMAC_CreateConVar",     Native_CreateConVar);
	CreateNative("SMAC_CheatDetected",    Native_CheatDetected);
	g_fwdOnCheatDetected = new GlobalForward("SMAC_OnCheatDetected", ET_Event, Param_Cell, Param_String, Param_Cell, Param_Cell);
}

// native GameType:SMAC_GetGameType();
any Native_GetGameType(Handle hPlugin, int iNumParams)
{
	return view_as<int>(g_Game);
}

// native SMAC_Log(const String:format[], any:...);
any Native_Log(Handle hPlugin, int iNumParams)
{
	char szFilename[64];
	GetPluginBasename(hPlugin, szFilename, sizeof(szFilename));
	char szBuffer[256];
	FormatNativeString(0, 1, 2, sizeof(szBuffer), _, szBuffer);
	LogToFileEx(g_szLogPath, "[%s] %s", szFilename, szBuffer);
	// Relay log to IRC.
	if (g_iIrcMode == 2)
		SMAC_RelayToIRC("[%s] %s", szFilename, szBuffer);
	return 0;
}

// native SMAC_LogAction(client, const String:format[], any:...);
any Native_LogAction(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (!IS_CLIENT(iClient))
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", iClient);
	if (!IsClientConnected(iClient))
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is not connected", iClient);
	// Get client STEAM ID
	char szAuthID[MAX_AUTHID_LENGTH];
	if (!GetClientAuthId(iClient, AuthId_Steam2, szAuthID, sizeof(szAuthID), true))
	{
		if (GetClientAuthId(iClient, AuthId_Steam2, szAuthID, sizeof(szAuthID), false))
			Format(szAuthID, sizeof(szAuthID), "%s (Not Validated)", szAuthID);
		else
			strcopy(szAuthID, sizeof(szAuthID), "Unknown");
	}
	// Get client IP
	char szIP[17];
	if (!GetClientIP(iClient, szIP, sizeof(szIP)))
		strcopy(szIP, sizeof(szIP), "Unknown");
	// Get plugin version
	char szVersion[16];
	GetPluginInfo(hPlugin, PlInfo_Version, szVersion, sizeof(szVersion));
	// Get plugin name
	char szFilename[64];
	GetPluginBasename(hPlugin, szFilename, sizeof(szFilename));
	// Get message
	char szBuffer[512];
	FormatNativeString(0, 2, 3, sizeof(szBuffer), _, szBuffer);
	// Verbose client logging.
	if (g_bLogVerbose && IsClientInGame(iClient))
	{
		// Get current map
		char szMap[MAX_MAPNAME_LENGTH];
		GetCurrentMap(szMap, sizeof(szMap));
		// Get position
		float vOrigin[3];
		GetClientAbsOrigin(iClient, vOrigin);
		// Get angles
		float vAngles[3];
		GetClientEyeAngles(iClient, vAngles);
		// Get weapon
		char szWeapon[32];
		GetClientWeapon(iClient, szWeapon, sizeof(szWeapon));
		// Get team and ping
		int iTeam    = GetClientTeam(iClient);
		int iLatency = RoundToNearest(GetClientAvgLatency(iClient, NetFlow_Outgoing) * 1000.0);
		// Log it to file
		LogToFileEx(g_szLogPath,
			"[%s | %s] %N (ID: %s | IP: %s) %s\n\tMap: %s | Origin: %.0f %.0f %.0f | Angles: %.0f %.0f %.0f | Weapon: %s | Team: %i | Latency: %ims", szFilename,
																																					  szVersion,
																																					  iClient,
																																					  szAuthID,
																																					  szIP,
																																					  szBuffer,
																																					  szMap,
																																					  vOrigin[0],
																																					  vOrigin[1],
																																					  vOrigin[2],
																																					  vAngles[0],
																																					  vAngles[1],
																																					  vAngles[2],
																																					  szWeapon,
																																					  iTeam,
																																					  iLatency);
	} 
	else
		LogToFileEx(g_szLogPath, "[%s | %s] %N (ID: %s | IP: %s) %s", szFilename, szVersion, iClient, szAuthID, szIP, szBuffer);
	// Relay minimal log to IRC.
	if (g_iIrcMode == 2)
		SMAC_RelayToIRC("[%s | %s] %N (ID: %s | IP: %s) %s", szFilename, szVersion, iClient, szAuthID, szIP, szBuffer);
	return 0;
}

// native SMAC_Ban(client, const String:reason[], any:...);
any Native_Ban(Handle hPlugin, int iNumParams)
{
	int iClient   = GetNativeCell(1);
	int iDuration = g_iBanDuration;
	// Get version
	char szVersion[16];
	GetPluginInfo(hPlugin, PlInfo_Version, szVersion, sizeof(szVersion));
	// Prepare reason
	char szReason[256];
	FormatNativeString(0, 2, 3, sizeof(szReason), _, szReason);
	Format(szReason, sizeof(szReason), "SMAC %s: %s", szVersion, szReason);
	// Do Action
	if (SOURCEBANS_AVAILABLE())
		SBBanPlayer(0, iClient, iDuration, szReason);
	else
	{
		char szKickMsg[256];
		FormatEx(szKickMsg, sizeof(szKickMsg), "%T", "SMAC_Banned", iClient);
		BanClient(iClient, iDuration, BANFLAG_AUTO, szReason, szKickMsg, "SMAC");
	}
	KickClient(iClient, szReason);
	return 0;
}

// native SMAC_PrintAdminNotice(const String:format[], any:...);
any Native_PrintAdminNotice(Handle hPlugin, int iNumParams)
{
	char szBuffer[192];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		if (!CheckCommandAccess(i, "smac_admin_notices", ADMFLAG_GENERIC, true)) continue;
		SetGlobalTransTarget(i);
		FormatNativeString(0, 1, 2, sizeof(szBuffer), _, szBuffer);
		PrintToChat(i, "%t%s", "SMAC_Tag", szBuffer);
	}
	// Relay admin notice to IRC.
	if (g_iIrcMode == 1)
	{
		SetGlobalTransTarget(LANG_SERVER);
		FormatNativeString(0, 1, 2, sizeof(szBuffer), _, szBuffer);
		Format(szBuffer, sizeof(szBuffer), "%t%s", "SMAC_Tag", szBuffer);
		SMAC_RelayToIRC(szBuffer);
	}
	return 0;
}

// native Handle:SMAC_CreateConVar(const String:name[], const String:defaultValue[], const String:description[]="", flags=0, bool:hasMin=false, Float:min=0.0, bool:hasMax=false, Float:max=0.0);
any Native_CreateConVar(Handle hPlugin, int iNumParams)
{
	char szName[64];
	GetNativeString(1, szName, sizeof(szName));
	char szDefaultValue[16];
	GetNativeString(2, szDefaultValue, sizeof(szDefaultValue));
	char szDescription[192];
	GetNativeString(3, szDescription, sizeof(szDescription));
	int iFlags = GetNativeCell(4);
	bool bHasMin = view_as<bool>(GetNativeCell(5));
	float fMin = view_as<float>(GetNativeCell(6));
	bool bHasMax = view_as<bool>(GetNativeCell(7));
	float fMax = view_as<float>(GetNativeCell(8));
	char szFilename[64];
	GetPluginBasename(hPlugin, szFilename, sizeof(szFilename));
	Format(szDescription, sizeof(szDescription), "[%s] %s", szFilename, szDescription);
	return view_as<int>(CreateConVar(szName, szDefaultValue, szDescription, iFlags, bHasMin, fMin, bHasMax, fMax));
}

// native Action:SMAC_CheatDetected(client, DetectionType:type = Detection_Unknown, Handle:info = null);
any Native_CheatDetected(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (!IS_CLIENT(iClient))
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", iClient);
	if (!IsClientConnected(iClient))
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is not connected", iClient);
	// Block duplicate detections.
	if (IsClientInKickQueue(iClient))
		return view_as<int>(Plugin_Handled);
	char szFilename[64];
	GetPluginBasename(hPlugin, szFilename, sizeof(szFilename));
	DetectionType dType = Detection_Unknown;
	Handle hInfo = null;
	if (iNumParams == 3)
	{
		// caller is using newer cheat detected native
		dType = view_as<DetectionType>(GetNativeCell(2));
		hInfo = view_as<Handle>(GetNativeCell(3));
	}
	// forward Action:SMAC_OnCheatDetected(client, const String:module[], DetectionType:type, Handle:info);
	Action aResult = Plugin_Continue;
	Call_StartForward(g_fwdOnCheatDetected);
	Call_PushCell(iClient);
	Call_PushString(szFilename);
	Call_PushCell(dType);
	Call_PushCell(hInfo);
	Call_Finish(aResult);
	return view_as<int>(aResult);
}