#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <geoip>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
    name        = "Connect Announce - lite",
    author      = "Dosergen",
    description = "Connect Announce Info",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/Dosergen"
}

public void OnPluginStart()
{
	HookEvent("player_disconnect", evtPlayerDisconnect, EventHookMode_Pre);
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		return;
	char ip[16], country[46];
	GetClientIP(client, ip, sizeof(ip));
	if (!GeoipCountry(ip, country, sizeof(country)))
		strcopy(country, sizeof(country), "Unknown Country");
	if (CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, true))
		return;
	PrintToChatAll("\x01Comrade \x04%N \x01connected from \x04%s", client, country);
}

void evtPlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	event.BroadcastDisabled = true;
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client <= 0)
		return;
	if (!IsClientInGame(client))
		return;
	if (IsFakeClient(client))
		return;
	char reason[128];
	if (!event.GetString("reason", reason, sizeof(reason)))
		strcopy(reason, sizeof(reason), "No reason specified");
	PrintToChatAll("\x01Comrade \x04%N \x01-> \x05%s", client, reason);
}