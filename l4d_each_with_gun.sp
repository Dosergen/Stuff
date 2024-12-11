#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define DEBUG 0

#define PLUGIN_VERSION "0.5"
#define WEAPON_COUNT 16
#define WEAPON_WAIT_TIME 1.0

static const char g_sWeaponNames[WEAPON_COUNT][32] =
{
	"weapon_smg",
	"weapon_smg_mp5",
	"weapon_smg_silenced",
	"weapon_rifle",
	"weapon_rifle_ak47",
	"weapon_rifle_sg552",
	"weapon_rifle_desert",
	"weapon_hunting_rifle",
	"weapon_sniper_military",
	"weapon_sniper_awp",
	"weapon_sniper_scout",
	"weapon_pumpshotgun",
	"weapon_autoshotgun",
	"weapon_shotgun_chrome",
	"weapon_shotgun_spas",
	"weapon_pistol_magnum"
};

bool g_bPlayerWeaponTaken[MAXPLAYERS + 1][WEAPON_COUNT];
int g_iPlayerWeaponCount[MAXPLAYERS + 1];
float g_fWeaponAvailableTime[MAXPLAYERS + 1][WEAPON_COUNT];
bool g_bWeaponTaken[WEAPON_COUNT] = { false };

bool g_bLateLoad;
bool g_bHookedEvents;
bool g_bPluginEnable;
bool g_bChatMessages;
int g_iWeaponLimit;
ConVar g_hPluginEnable;
ConVar g_hWeaponLimit;
ConVar g_hChatMessages;

public Plugin myinfo =
{
	name = "[L4D/2] Each With Gun",
	author = "Dosergen",
	description = "The player is allowed to take only one type of weapon.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Dosergen/Stuff"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead && test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hPluginEnable = CreateConVar("l4d_weapon_limit_enable", "1", "Enable or disable the plugin functionality.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hWeaponLimit = CreateConVar("l4d_weapon_limit_per_round", "1", "Maximum number of weapons a player can take per round. 0: Disable", FCVAR_NOTIFY, true, 0.0, true, 4.0);
	g_hChatMessages = CreateConVar("l4d_weapon_chat_messages", "0", "Enable or disable chat messages for player.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	g_hPluginEnable.AddChangeHook(ConVarChanged);
	g_hWeaponLimit.AddChangeHook(ConVarChanged);
	g_hChatMessages.AddChangeHook(ConVarChanged);

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
		HookEvent("round_start", evtRoundStart);
		HookEvent("round_end", evtRoundEnd);
		HookEvent("player_spawn", evtPlayerSpawn);
		HookEvent("weapon_drop", evtWeaponDrop);
		g_bHookedEvents = true;
	}
	else if (!g_bPluginEnable && g_bHookedEvents)
	{
		UnhookEvent("round_start", evtRoundStart);
		UnhookEvent("round_end", evtRoundEnd);
		UnhookEvent("player_spawn", evtPlayerSpawn);
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
	for (int i = 0; i < WEAPON_COUNT; i++)
	{
		if (g_bWeaponTaken[i])
		{
			bool found = false;
			for (int j = 1; j <= MaxClients; j++)
			{
				if (IsValidClient(j) && g_bPlayerWeaponTaken[j][i])
				{
					char playerName[64];
					GetClientName(j, playerName, sizeof(playerName));
					PrintToChat(client, "\x04[Weapon Limit]\x01 Weapon %s is taken by \x04%s\x01.", g_sWeaponNames[i], playerName);
					found = true;
				}
			}
			if (!found)
				PrintToChat(client, "\x04[Weapon Limit]\x01 Weapon %s is taken but unknown.", g_sWeaponNames[i]);
		}
		else
			PrintToChat(client, "\x02[Weapon Limit]\x01 Weapon %s is available.", g_sWeaponNames[i]);
	}
	return Plugin_Handled;
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
	for (int i = 0; i < WEAPON_COUNT; i++)
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
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_WeaponEquip, OnWeaponEquip);
}

Action OnWeaponEquip(int client, int weapon)
{
	if (!g_bPluginEnable || !IsValidClient(client) || !IsPlayerAlive(client) || !IsValidEntity(weapon))
		return Plugin_Continue;
	char weaponName[64];
	GetEdictClassname(weapon, weaponName, sizeof(weaponName));
	int weaponIndex = GetWeaponIndex(weaponName);
	if (weaponIndex == -1)
		return Plugin_Continue;
	float currentTime = GetEngineTime();
	// Consolidated checks for weapon availability
	if (!CanPickUpWeapon(client, weaponIndex, currentTime))
		return Plugin_Handled;
	g_bPlayerWeaponTaken[client][weaponIndex] = true;
	g_iPlayerWeaponCount[client]++;
	g_bWeaponTaken[weaponIndex] = true;
	g_fWeaponAvailableTime[client][weaponIndex] = currentTime + WEAPON_WAIT_TIME;
	#if DEBUG
	char clientName[64];
	GetClientName(client, clientName, sizeof(clientName));
	PrintToChatAll("[DEBUG] Player %s picked up %s.", clientName, weaponName);
	#endif
	return Plugin_Continue;
}

bool CanPickUpWeapon(int client, int weaponIndex, float currentTime)
{
	// Check if the player is waiting on a weapon or has reached their limit
	if (g_fWeaponAvailableTime[client][weaponIndex] > currentTime)
	{
		float remainingTime = g_fWeaponAvailableTime[client][weaponIndex] - currentTime;
		if (g_bChatMessages)
			PrintToChat(client, "\x04[Weapon Limit]\x01 You must wait \x04%.2f\x01 seconds before picking up this weapon.", remainingTime);
		return false;
	}
	if (g_bWeaponTaken[weaponIndex])
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && g_bPlayerWeaponTaken[i][weaponIndex])
			{
				char weaponOwner[64];
				GetClientName(i, weaponOwner, sizeof(weaponOwner));
				if (g_bChatMessages)
					PrintToChat(client, "\x04[Weapon Limit]\x01 This weapon is still in use by \x04%s\x01!", weaponOwner);
				return false;
			}
		}
	}
	if (g_iWeaponLimit > 0 && g_iPlayerWeaponCount[client] >= g_iWeaponLimit)
	{
		if (g_bChatMessages)
			PrintToChat(client, "\x04[Weapon Limit]\x01 You are limited to \x04%d\x01 weapon(s) per round.", g_iWeaponLimit);
		return false;
	}
	return true;
}

Action evtWeaponDrop(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int weapon = event.GetInt("propid");
	if (!g_bPluginEnable || !IsValidClient(client) || !IsPlayerAlive(client) || !IsValidEntity(weapon))
		return Plugin_Continue;
	char weaponName[64];
	GetEdictClassname(weapon, weaponName, sizeof(weaponName));
	int weaponIndex = GetWeaponIndex(weaponName);
	if (weaponIndex == -1)
		return Plugin_Continue;
	float currentTime = GetEngineTime();
	// Drop handling
	if (g_bPlayerWeaponTaken[client][weaponIndex])
	{
		g_bPlayerWeaponTaken[client][weaponIndex] = false;
		g_bWeaponTaken[weaponIndex] = false;
		g_fWeaponAvailableTime[client][weaponIndex] = currentTime + WEAPON_WAIT_TIME;
		#if DEBUG
		char clientName[64];
		GetClientName(client, clientName, sizeof(clientName));
		PrintToChatAll("[DEBUG] Player %s dropped %s.", clientName, weaponName);
		#endif
	}
	return Plugin_Continue;
}

int GetWeaponIndex(const char[] weaponName)
{
	for (int i = 0; i < WEAPON_COUNT; i++)
	{
		if (strcmp(weaponName, g_sWeaponNames[i], true) == 0)
			return i;
	}
	return -1;
}

void ResetPlayerWeaponState(int client)
{
	for (int i = 0; i < WEAPON_COUNT; i++)
	{
		g_bPlayerWeaponTaken[client][i] = false;
		g_fWeaponAvailableTime[client][i] = 0.0;
	}
	g_iPlayerWeaponCount[client] = 0;
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}