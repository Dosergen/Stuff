#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PL_VERSION "2.1"

Handle hWeaponSwitchFwd;

float fLastMeleeSwing[MAXPLAYERS + 1];

bool bLate;

public Plugin myinfo =
{
	name = "Fast melee fix",
	author = "sheo",
	description = "Fixes the bug with too fast melee attacks",
	version = PL_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2407280"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d2_fast_melee_fix_version", PL_VERSION, "Fast melee fix version");
	hWeaponSwitchFwd = CreateGlobalForward("OnClientMeleeSwitch", ET_Ignore, Param_Cell, Param_Cell);
	HookEvent("weapon_fire", Event_WeaponFire);
	if (bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitched);
	fLastMeleeSwing[client] = 0.0;
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitched);
}

void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && !IsFakeClient(client))
	{
		char sBuffer[64];
		GetEventString(event, "weapon", sBuffer, sizeof(sBuffer));
		if (StrEqual(sBuffer, "melee"))
		{
			fLastMeleeSwing[client] = GetGameTime();
		}
	}
}

void OnWeaponSwitched(int client, int weapon)
{
	if (!IsFakeClient(client) && IsValidEntity(weapon))
	{
		char sBuffer[32];
		GetEntityClassname(weapon, sBuffer, sizeof(sBuffer));
		if (StrEqual(sBuffer, "weapon_melee"))
		{
			float fShouldbeNextAttack = fLastMeleeSwing[client] + 0.92;
			float fByServerNextAttack = GetGameTime() + 0.5;
			SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", (fShouldbeNextAttack > fByServerNextAttack) ? fShouldbeNextAttack : fByServerNextAttack);
			Call_StartForward(hWeaponSwitchFwd);
			Call_PushCell(client);
			Call_PushCell(weapon);
			Call_Finish();
		}
	}
}