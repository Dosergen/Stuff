#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "1.1"

#define INVALID_STEAM_ID_1 ""
#define INVALID_STEAM_ID_2 "STEAM_ID_PENDING"
#define INVALID_STEAM_ID_3 "STEAM_ID_STOP_IGNORING_RETVALS"

#define MAX_STEAM_ID_LENGTH 64
#define MAX_IP_LENGTH 64

char LogFile[PLATFORM_MAX_PATH];
ConVar g_hEnable, g_hBanDuration, g_hErrorMessage;
Handle AuthClientTimer[MAXPLAYERS+1];

public Plugin myinfo =
{
	name        = "SteamID Blocker",
	author      = "Dosergen",
	description = "Ban Players with Invalid SteamIDs",
	version     = PLUGIN_VERSION,
	url         = "https://github.com/Dosergen/Stuff"
}

public void OnPluginStart()
{
	BuildPath(Path_SM, LogFile, sizeof(LogFile), "logs/steamid_bans.log");

	g_hEnable = CreateConVar("steamid_blocker_enabled", "1", "Enable or disable plugin");
	g_hBanDuration = CreateConVar("steamid_blocker_ban_duration", "1440", "Ban duration in minutes");
	g_hErrorMessage = CreateConVar("steamid_blocker_error_message", "Your SteamID is not valid and you have been blocked from connecting", "Custom error message for banned players");

	AutoExecConfig(true, "steamid_blocker");
}

public void OnClientPutInServer(int client)
{
	if (!g_hEnable.BoolValue || !IsValidClient(client))
		return;
	char SteamID[MAX_STEAM_ID_LENGTH], IP[MAX_IP_LENGTH];
	GetClientIP(client, IP, sizeof(IP));
	GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID));
	if (IsNotValidSteamID(SteamID))
	{
		LogToFile(LogFile, "Detected invalid SteamID for player %N during connection: %s | IP: %s", client, SteamID, IP);
		if (AuthClientTimer[client] != null)
			delete AuthClientTimer[client];
		AuthClientTimer[client] = CreateTimer(20.0, AuthCheckTimer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnClientDisconnect(int client)
{
	delete AuthClientTimer[client];
}

Action AuthCheckTimer(Handle timer, any data)
{
	int client = GetClientOfUserId(data);
	if (!g_hEnable.BoolValue || !IsValidClient(client))
		return Plugin_Continue;
	char SteamID[MAX_STEAM_ID_LENGTH], IP[MAX_IP_LENGTH], Name[MAX_NAME_LENGTH];
	GetClientIP(client, IP, sizeof(IP));
	GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID));
	GetClientName(client, Name, sizeof(Name));
	if (IsNotValidSteamID(SteamID))
	{
		char errorMessage[MAX_NAME_LENGTH];
		g_hErrorMessage.GetString(errorMessage, sizeof(errorMessage));
		KickClient(client, "%s", errorMessage);
		int nums[4];
		char pieces[4][16];
		// Split the IP address into its components
		ExplodeString(IP, ".", pieces, sizeof(pieces), sizeof(pieces[]));
		// Use the first two parts of the IP (for a /16 subnet ban)
		for (int i = 0; i < 2; i++) 
			nums[i] = StringToInt(pieces[i]);
		int duration = g_hBanDuration.IntValue;
		ServerCommand("addip %d %d.%d.0.0", duration, nums[0], nums[1]);
		ServerCommand("writeip");
		LogToFile(LogFile, "Applied IP range ban to player %s for invalid SteamID: %s | IP: %s", Name, SteamID, IP);
	}
	else
		LogToFile(LogFile, "Player %N no longer flagged for invalid SteamID: %s | IP: %s", client, SteamID, IP);
	AuthClientTimer[client] = null;
	return Plugin_Stop;
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}

bool IsNotValidSteamID(const char[] SteamID)
{
	return StrEqual(SteamID, INVALID_STEAM_ID_1) || StrEqual(SteamID, INVALID_STEAM_ID_2) || StrEqual(SteamID, INVALID_STEAM_ID_3);
}