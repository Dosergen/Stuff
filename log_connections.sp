/*	Copyright (C) 2017 IT-KiLLER | Copyright (C) 2023 Dosergen
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <geoip>

#define PLUGIN_VERSION "1.4"

#define ADMIN_LOG_PATH "logs/connections/admin"
#define PLAYER_LOG_PATH "logs/connections/player"

char admin_filepath[PLATFORM_MAX_PATH];
char player_filepath[PLATFORM_MAX_PATH];
bool clientIsAdmin[MAXPLAYERS+1] = { false , ... };
bool clientConnected[MAXPLAYERS+1] = { false , ... };

public Plugin myinfo =
{
	name = "Log Connections",
	author = "Xander, IT-KiLLER, Dosergen",
	description = "This plugin logs players' connect and disconnect times along with their Name, SteamID, and IP Address.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=201967"
}

public void OnPluginStart()
{
	CreateConVar("sm_log_connections_version", PLUGIN_VERSION, "Log Connections version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	// ADMIN
	BuildPath(Path_SM, admin_filepath, sizeof(admin_filepath), ADMIN_LOG_PATH);
	if (!DirExists(admin_filepath))
	{
		CreateDirectory(admin_filepath, 511, true);
		if (!DirExists(admin_filepath))
		{
			LogMessage("Failed to create directory at %s - Please manually create that path and reload this plugin.", ADMIN_LOG_PATH);
		}
	}
	// PLAYER
	BuildPath(Path_SM, player_filepath, sizeof(player_filepath), PLAYER_LOG_PATH);
	if (!DirExists(player_filepath))
	{
		CreateDirectory(player_filepath, 511, true);
		if (!DirExists(player_filepath))
		{
			LogMessage("Failed to create directory at %s - Please manually create that path and reload this plugin.", PLAYER_LOG_PATH);
		}
	}
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			clientConnected[client] = true;
			if (IsPlayerAdmin(client))
			{
				clientIsAdmin[client] = true;
			}
		}
	}
}

public void OnMapStart()
{
	char FormatedTime[100];
	char MapName[100];
	int CurrentTime = GetTime();
	GetCurrentMap(MapName, sizeof(MapName));
	FormatTime(FormatedTime, sizeof(FormatedTime), "%d_%b_%Y", CurrentTime); //name the file 'day month year'
	BuildPath(Path_SM, admin_filepath, sizeof(admin_filepath), "%s/%s_admin.log", ADMIN_LOG_PATH, FormatedTime);
	BuildPath(Path_SM, player_filepath, sizeof(player_filepath), "%s/%s_player.log", PLAYER_LOG_PATH, FormatedTime);
	File admin = OpenFile(admin_filepath, "a+");
	File player = OpenFile(player_filepath, "a+");
	FormatTime(FormatedTime, sizeof(FormatedTime), "%X", CurrentTime);
	// ADMIN
	admin.WriteLine("");
	admin.WriteLine("%s - ===== Map change to %s =====", FormatedTime, MapName);
	admin.WriteLine("");
	admin.Flush();
	delete admin;
	// PLAYER
	player.WriteLine("");
	player.WriteLine("%s - ===== Map change to %s =====", FormatedTime, MapName);
	player.WriteLine("");
	player.Flush();
	delete player;
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAdmin(client))
		{
			clientIsAdmin[client] = true;
		}
	}
}

public void OnClientPostAdminCheck(int client) 
{
	if (!client)
	{
		// console or unknown client
	} 
	else if (IsFakeClient(client))
	{
		// bot
	}	
	else if (clientConnected[client])
	{
		// Already connected
	}
	else if (IsPlayerAdmin(client))
	{ 	// ADMIN
		clientConnected[client] = true;
		clientIsAdmin[client] = true;
		char PlayerName[64];
		char Authid[64];
		char IPAddress[64];
		char Country[64];
		char FormatedTime[64];
		GetClientName(client, PlayerName, sizeof(PlayerName));
		GetClientAuthId(client, AuthId_Steam2, Authid, sizeof(Authid), false);
		GetClientIP(client, IPAddress, sizeof(IPAddress));
		FormatTime(FormatedTime, sizeof(FormatedTime), "%X", GetTime());
		if (!GeoipCountry(IPAddress, Country, sizeof(Country)))
		{
			Format(Country, sizeof(Country), "Unknown");
		}
		File admin = OpenFile(admin_filepath, "a+");
		admin.WriteLine("%s - <%s> <%s> <%s> CONNECTED from <%s>",
								FormatedTime,
								PlayerName,
								Authid,
								IPAddress,
								Country);
		admin.Flush();
		delete admin;
	}
	else // PLAYER
	{
		clientConnected[client] = true;
		clientIsAdmin[client] = false;
		char PlayerName[64];
		char Authid[64];
		char IPAddress[64];
		char Country[64];
		char FormatedTime[64];
		GetClientName(client, PlayerName, sizeof(PlayerName));
		GetClientAuthId(client, AuthId_Steam2, Authid, sizeof(Authid), false);
		GetClientIP(client, IPAddress, sizeof(IPAddress));
		FormatTime(FormatedTime, sizeof(FormatedTime), "%X", GetTime());
		if (!GeoipCountry(IPAddress, Country, sizeof(Country)))
		{
			Format(Country, sizeof(Country), "Unknown");
		}
		File player = OpenFile(player_filepath, "a+");
		player.WriteLine("%s - <%s> <%s> <%s> CONNECTED from <%s>",
								FormatedTime,
								PlayerName,
								Authid,
								IPAddress,
								Country);
		player.Flush();
		delete player;
	}
}

public void Event_PlayerDisconnect(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!clientConnected[client])
	{
		return;
	}
	clientConnected[client] = false;
	if (!client)
	{
		// console or unknown client
	}
	else if (IsFakeClient(client))
	{
		// bot
	}	
	else if (clientIsAdmin[client]) 
	{	// ADMIN
		int ConnectionTime = -1;
		File admin = OpenFile(admin_filepath, "a+");
		char PlayerName[64];
		char Authid[64];
		char IPAddress[64];
		char FormatedTime[64];
		char Reason[128];
		GetClientName(client, PlayerName, sizeof(PlayerName));
		GetClientIP(client, IPAddress, sizeof(IPAddress));
		FormatTime(FormatedTime, sizeof(FormatedTime), "%X", GetTime());
		event.GetString("reason", Reason, sizeof(Reason));
		if (!GetClientAuthId(client, AuthId_Steam2, Authid, sizeof(Authid), false))
		{
			Format(Authid, sizeof(Authid), "Unknown SteamID");
		}
		if (IsClientInGame(client))
		{
			ConnectionTime = RoundToCeil(GetClientTime(client) / 60);
		}
		admin.WriteLine("%s - <%s> <%s> <%s> DISCONNECTED after %d minutes. <%s>",
								FormatedTime,
								PlayerName,
								Authid,
								IPAddress,
								ConnectionTime,
								Reason);
		admin.Flush();
		delete admin;
	}	
	else
	{	// PLAYER
		int ConnectionTime = -1;
		File player = OpenFile(admin_filepath, "a+");
		char PlayerName[64];
		char Authid[64];
		char IPAddress[64];
		char FormatedTime[64];
		char Reason[128];
		GetClientName(client, PlayerName, sizeof(PlayerName));
		GetClientIP(client, IPAddress, sizeof(IPAddress));
		FormatTime(FormatedTime, sizeof(FormatedTime), "%X", GetTime());
		event.GetString("reason", Reason, sizeof(Reason));
		if (!GetClientAuthId(client, AuthId_Steam2, Authid, sizeof(Authid), false))
		{
			Format(Authid, sizeof(Authid), "Unknown SteamID");
		}
		if (IsClientInGame(client))
		{
			ConnectionTime = RoundToCeil(GetClientTime(client) / 60);
		}
		player.WriteLine("%s - <%s> <%s> <%s> DISCONNECTED after %d minutes. <%s>",
								FormatedTime,
								PlayerName,
								Authid,
								IPAddress,
								ConnectionTime,
								Reason);
		player.Flush();
		delete player;
	}
	clientIsAdmin[client] = false;
}

// Checking if a client is admin
stock bool IsPlayerAdmin(int client)
{
	if (CheckCommandAccess(client, "Generic_admin", ADMFLAG_GENERIC, false))
	{
		return true;
	}
	return false;
}