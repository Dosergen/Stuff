/*
 *	"weapon_smg", "weapon_smg_mp5", "weapon_smg_silenced", "weapon_rifle", 
 *	"weapon_rifle_ak47", "weapon_rifle_sg552", "weapon_rifle_desert", "weapon_hunting_rifle", 
 *	"weapon_sniper_military", "weapon_sniper_awp", "weapon_sniper_scout", "weapon_pumpshotgun", 
 *	"weapon_autoshotgun", "weapon_shotgun_chrome", "weapon_shotgun_spas", "weapon_pistol_magnum"
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define DEBUG 0

#define PLUGIN_VERSION "0.7"
#define WEAPON_WAIT_TIME 1.0
#define MAX_WEAPONS 32

WeaponData g_WeaponData[MAXPLAYERS + 1];
bool g_bWeaponTaken[MAX_WEAPONS] = { false };
char g_sWeaponNames[MAX_WEAPONS][32];
int g_iWeaponCount = 0;

enum struct WeaponData
{
	bool taken[MAX_WEAPONS];
	int count;
	float availableTime[MAX_WEAPONS];
}

bool g_bLateLoad, g_bLeft4Dead2, g_bHookedEvents, g_bPluginEnable, g_bChatMessages;
ConVar g_hPluginEnable, g_hWeaponLimit, g_hChatMessages, g_hWeaponList;
int g_iWeaponLimit;

public Plugin myinfo =
{
	name = "[L4D/2] Each With Gun",
	author = "Dosergen",
	description = "Players can choose only one weapon type.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Dosergen/Stuff"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	g_bLeft4Dead2 = (test == Engine_Left4Dead2);
	if (test == Engine_Left4Dead)
		g_bLeft4Dead2 = false;
	else if (test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hPluginEnable = CreateConVar("l4d_each_with_gun_enable", "1", "Enable or disable the plugin functionality.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hWeaponLimit = CreateConVar("l4d_each_with_gun_per_round", "1", "Maximum number of weapons a player can take per round. 0: Disable", FCVAR_NOTIFY, true, 0.0, true, 4.0);
	g_hChatMessages = CreateConVar("l4d_each_with_gun_chat_messages", "1", "Enable or disable chat messages for player.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hWeaponList = CreateConVar("l4d_each_with_gun_list", "weapon_hunting_rifle,weapon_sniper_military,weapon_sniper_awp,weapon_sniper_scout", "Comma-separated list of weapons.", FCVAR_NOTIFY);

	g_hPluginEnable.AddChangeHook(ConVarChanged);
	g_hWeaponLimit.AddChangeHook(ConVarChanged);
	g_hChatMessages.AddChangeHook(ConVarChanged);
	g_hWeaponList.AddChangeHook(ConVarChanged);

	if (g_bLateLoad) 
	{
		for (int i = 1; i <= MaxClients; i++) 
		{
			if (IsValidClient(i))
				OnClientPutInServer(i);
		}
	}

	RegAdminCmd("sm_ws", Command_WeaponStatus, ADMFLAG_ROOT, "Shows the current weapon status");

	AutoExecConfig(true, "l4d_each_with_gun");
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
	ParseWeaponList();
}

void GetCvars()
{
	g_bPluginEnable = g_hPluginEnable.BoolValue;
	g_iWeaponLimit = g_hWeaponLimit.IntValue;
	g_bChatMessages = g_hChatMessages.BoolValue;
}

void IsAllowed()
{   
	GetCvars();
	if (g_bPluginEnable && !g_bHookedEvents)
	{
		ParseWeaponList();
		HookEvent("round_start", evtRoundStart);
		HookEvent("round_end", evtRoundEnd);
		HookEvent("player_spawn", evtPlayerSpawn);
		if (g_bLeft4Dead2)
			HookEvent("weapon_drop", evtWeaponDrop);
		g_bHookedEvents = true;
	}
	else if (!g_bPluginEnable && g_bHookedEvents)
	{
		UnhookEvent("round_start", evtRoundStart);
		UnhookEvent("round_end", evtRoundEnd);
		UnhookEvent("player_spawn", evtPlayerSpawn);
		if (g_bLeft4Dead2)
			UnhookEvent("weapon_drop", evtWeaponDrop);
		g_bHookedEvents = false;
	}
}

Action Command_WeaponStatus(int client, int args)
{
	if (client == 0 || !IsValidClient(client))
		return Plugin_Handled;
	char clientName[64];
	GetClientName(client, clientName, sizeof(clientName));
	for (int i = 0; i < MAX_WEAPONS; i++)
		WeaponStatus(client, i);
	return Plugin_Handled;
}

void WeaponStatus(int client, int weaponIndex)
{
	if (g_bWeaponTaken[weaponIndex])
	{
		bool found = false;
		for (int j = 1; j <= MaxClients; j++)
		{
			if (IsValidClient(j) && g_WeaponData[j].taken[weaponIndex])
			{
				char playerName[64];
				GetClientName(j, playerName, sizeof(playerName));
				PrintToChat(client, "\x04[Weapon Limit]\x01 Weapon %s is taken by \x04%s\x01.", g_sWeaponNames[weaponIndex], playerName);
				found = true;
			}
		}
		if (!found)
			PrintToChat(client, "\x04[Weapon Limit]\x01 Weapon %s is taken but unknown.", g_sWeaponNames[weaponIndex]);
	}
	else
		PrintToChat(client, "\x02[Weapon Limit]\x01 Weapon %s is available.", g_sWeaponNames[weaponIndex]);
}

void ParseWeaponList()
{
	char weaponList[512];
	g_hWeaponList.GetString(weaponList, sizeof(weaponList));
	g_iWeaponCount = 0;
	char weaponArray[MAX_WEAPONS][32];
	int count = ExplodeString(weaponList, ",", weaponArray, sizeof(weaponArray), sizeof(weaponArray[]));
	for (int i = 0; i < count && g_iWeaponCount < MAX_WEAPONS; i++)
	{
		TrimString(weaponArray[i]);
		if (strlen(weaponArray[i]) > 0)
		{
			strcopy(g_sWeaponNames[g_iWeaponCount], 32, weaponArray[i]);
			g_iWeaponCount++;
		}
	}
	#if DEBUG
	LogMessage("Parsed weapon list: %d weapons loaded.", g_iWeaponCount);
	for (int j = 0; j < g_iWeaponCount; j++)
		LogMessage("Weapon %d: %s", j + 1, g_sWeaponNames[j]);
	#endif
}

void evtRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

void evtRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

void Reset()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
			ResetPlayerWeaponState(i);
	}
	// Reset global weapon availability
	for (int i = 0; i < MAX_WEAPONS; i++)
		g_bWeaponTaken[i] = false;
	#if DEBUG
	PrintToChatAll("[DEBUG] All weapon states have been reset.");
	#endif
}

void evtPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client))
	{
		ResetPlayerWeaponState(client);
		#if DEBUG
		char clientName[64];
		GetClientName(client, clientName, sizeof(clientName));
		PrintToChatAll("[DEBUG] Player %s spawned, weapon state initialized.", clientName);
		#endif
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
	if (!g_bLeft4Dead2)
		SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDrop);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_WeaponEquip, OnWeaponEquip);
	if (!g_bLeft4Dead2)
		SDKUnhook(client, SDKHook_WeaponDropPost, OnWeaponDrop);
}

Action OnWeaponEquip(int client, int weapon)
{
	if (!IsCheckConditions(client, weapon))
		return Plugin_Continue;
	char weaponName[64];
	GetEdictClassname(weapon, weaponName, sizeof(weaponName));
	int weaponIndex = GetWeaponIndex(weaponName);
	if (weaponIndex == -1)
		return Plugin_Continue;
	float currentTime = GetEngineTime();
	if (!IsCanPickUpWeapon(client, weaponIndex, currentTime))
		return Plugin_Handled;
	g_WeaponData[client].taken[weaponIndex] = true;
	g_WeaponData[client].count++;
	g_bWeaponTaken[weaponIndex] = true;
	g_WeaponData[client].availableTime[weaponIndex] = currentTime + WEAPON_WAIT_TIME;
	#if DEBUG
	char clientName[64];
	GetClientName(client, clientName, sizeof(clientName));
	PrintToChatAll("[DEBUG] Player %s picked up %s.", clientName, weaponName);
	#endif
	return Plugin_Continue;
}

bool IsCanPickUpWeapon(int client, int weaponIndex, float currentTime)
{
	if (g_WeaponData[client].availableTime[weaponIndex] > currentTime)
	{
		float remainingTime = g_WeaponData[client].availableTime[weaponIndex] - currentTime;
		if (g_bChatMessages)
			PrintToChat(client, "\x04[Weapon Limit]\x01 You must wait \x04%.2f\x01 seconds before picking up this weapon.", remainingTime);
		return false;
	}
	if (g_bWeaponTaken[weaponIndex])
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && g_WeaponData[i].taken[weaponIndex])
			{
				char weaponOwner[64];
				GetClientName(i, weaponOwner, sizeof(weaponOwner));
				if (g_bChatMessages)
					PrintToChat(client, "\x04[Weapon Limit]\x01 This weapon is still in use by \x04%s\x01!", weaponOwner);
				return false;
			}
		}
	}
	if (g_iWeaponLimit > 0 && g_WeaponData[client].count >= g_iWeaponLimit)
	{
		if (g_bChatMessages)
			PrintToChat(client, "\x04[Weapon Limit]\x01 You are limited to \x04%d\x01 weapon(s) per round.", g_iWeaponLimit);
		return false;
	}
	return true;
}

void evtWeaponDrop(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int weapon = event.GetInt("propid");
	if (!IsCheckConditions(client, weapon))
		return;
	WeaponDrop(client, weapon);
}

void OnWeaponDrop(int client, int weapon)
{
	if (!IsCheckConditions(client, weapon))
		return;
	WeaponDrop(client, weapon);
}

void WeaponDrop(int client, int weapon)
{
	char weaponName[64];
	GetEdictClassname(weapon, weaponName, sizeof(weaponName));
	int weaponIndex = GetWeaponIndex(weaponName);
	if (weaponIndex == -1)
		return;
	float currentTime = GetEngineTime();
	if (g_WeaponData[client].taken[weaponIndex])
	{
		g_WeaponData[client].taken[weaponIndex] = false;
		g_bWeaponTaken[weaponIndex] = false;
		g_WeaponData[client].availableTime[weaponIndex] = currentTime + WEAPON_WAIT_TIME;
		#if DEBUG
		char clientName[64];
		GetClientName(client, clientName, sizeof(clientName));
		PrintToChatAll("[DEBUG] Player %s dropped %s.", clientName, weaponName);
		#endif
	}
}

int GetWeaponIndex(const char[] weaponName)
{
	for (int i = 0; i < g_iWeaponCount; i++)
	{
		if (strcmp(weaponName, g_sWeaponNames[i], true) == 0)
			return i;
	}
	return -1;
}

void ResetPlayerWeaponState(int client)
{
	for (int i = 0; i < MAX_WEAPONS; i++)
	{
		g_WeaponData[client].taken[i] = false;
		g_WeaponData[client].availableTime[i] = 0.0;
	}
	g_WeaponData[client].count = 0;
}

bool IsCheckConditions(int client, int weapon)
{
	return g_bPluginEnable && IsValidClient(client) && IsPlayerAlive(client) && IsValidEntity(weapon);
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}