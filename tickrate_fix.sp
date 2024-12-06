#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION   "1.4.0"
#define ENTITY_MAX_NAME  64
#define MAX_ENTITIES     2048 //(1 << 11)

enum /*DoorsTypeTracked*/
{
	DoorsTypeTracked_None = -1,
	DoorsTypeTracked_Prop_Door_Rotating = 0,
	DoorTypeTracked_Prop_Door_Rotating_Checkpoint = 1
};

static const char g_szDoors_Type_Tracked[][MAX_NAME_LENGTH] = 
{
	"prop_door_rotating",
	"prop_door_rotating_checkpoint"
};

enum struct DoorsData
{
	int   DoorsData_Type;
	float DoorsData_Speed;
	bool  DoorsData_ForceClose;
}

DoorsData g_ddDoors[MAX_ENTITIES];

//<<<<<<<<<<<<<<<<<<<<< TICKRATE FIXES >>>>>>>>>>>>>>>>>>
//--------------- Fast Pistols & Slow Doors -------------
//*******************************************************

ConVar g_hCvarPistolDelayDualies;
ConVar g_hCvarPistolDelaySingle;
ConVar g_hCvarPistolDelayIncapped;
ConVar g_hCvarDoorSpeed;

float g_fNextAttack[MAXPLAYERS + 1];
float g_fPistolDelayDualies = 0.1;
float g_fPistolDelaySingle = 0.2;
float g_fPistolDelayIncapped = 0.3;
float g_fDoorSpeed;

bool g_bLateLoad;

public Plugin myinfo = 
{
	name = "Tickrate Fixes",
	author = "Sir, Griffin, Chanz, Dosergen",
	description = "Fixes a handful of silly Tickrate bugs",
	version = PLUGIN_VERSION,
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/TickrateFixes.sp"
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
	CreateConVar("l4d_tickrate_fixes_version", PLUGIN_VERSION, "Tickrate Fixes plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
    
	g_hCvarPistolDelayDualies = CreateConVar("l4d_tickrate_pistol_dualies", "0.15", "Minimum time (in seconds) between dual pistol shots", FCVAR_NOTIFY, true, 0.0, true, 5.0);
	g_hCvarPistolDelaySingle = CreateConVar("l4d_tickrate_pistol_single", "0.2", "Minimum time (in seconds) between single pistol shots", FCVAR_NOTIFY, true, 0.0, true, 5.0);
	g_hCvarPistolDelayIncapped = CreateConVar("l4d_tickrate_pistol_incapped", "0.3", "Minimum time (in seconds) between pistol shots while incapped", FCVAR_NOTIFY, true, 0.0, true, 5.0);
	g_hCvarDoorSpeed = CreateConVar("l4d_tickrate_door_speed", "1.5", "Sets the speed of all prop_door entities on a map. 1.05 means = 105% speed", FCVAR_NOTIFY, true, 0.0, true, 5.0);

	GetCvars();
	UpdatePistolDelays();
	Door_ClearSettingsAll();
	Door_GetSettingsAll();
	Door_SetSettingsAll();

	g_hCvarPistolDelayDualies.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarPistolDelaySingle.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarPistolDelayIncapped.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDoorSpeed.AddChangeHook(ConVarChanged_Cvars);

	HookEvent("weapon_fire", Event_WeaponFire);

	if (g_bLateLoad) 
	{
		for (int i = 1; i <= MaxClients; i++) 
		{
			if (IsClientInGame(i))
				OnClientPutInServer(i);
		}
	}

	AutoExecConfig(true, "tickrate_fix");
}

public void OnPluginEnd()
{
	Door_ResetSettingsAll();
}

void ConVarChanged_Cvars(ConVar convar, char[] oldValue, char[] newValue)
{
	GetCvars();
	UpdatePistolDelays();
	Door_SetSettingsAll();
}

void GetCvars()
{
	g_fPistolDelayDualies = g_hCvarPistolDelayDualies.FloatValue;
	g_fPistolDelaySingle = g_hCvarPistolDelaySingle.FloatValue;
	g_fPistolDelayIncapped = g_hCvarPistolDelayIncapped.FloatValue;
	g_fDoorSpeed = g_hCvarDoorSpeed.FloatValue;
}

public void OnEntityCreated(int iEntity, const char[] sClassName)
{
	if (sClassName[0] != 'p')
		return;
	for (int i = 0; i < sizeof(g_szDoors_Type_Tracked); i++)
	{
		if (strcmp(sClassName, g_szDoors_Type_Tracked[i], false) != 0)
			continue;
		SDKHook(iEntity, SDKHook_SpawnPost, Hook_DoorSpawnPost);
	}
}

void Hook_DoorSpawnPost(int iEntity)
{
	if (!IsValidEntity(iEntity))
		return;
	char sClassName[ENTITY_MAX_NAME];
	GetEntityClassname(iEntity, sClassName, sizeof(sClassName));
	for (int i = 0; i < sizeof(g_szDoors_Type_Tracked); i++)
	{
		if (strcmp(sClassName, g_szDoors_Type_Tracked[i], false) != 0)
			continue;
		Door_GetSettings(iEntity, i);
	}
	Door_SetSettings(iEntity);
}

public void OnClientPutInServer(int iClient)
{
	g_fNextAttack[iClient] = 0.0;
	SDKHook(iClient, SDKHook_PreThink, Hook_OnPreThink);
}

public void OnClientDisconnect(int iClient)
{
	g_fNextAttack[iClient] = 0.0;
	SDKUnhook(iClient, SDKHook_PreThink, Hook_OnPreThink);
}

void UpdatePistolDelays()
{
	g_fPistolDelayDualies = Clamp(g_fPistolDelayDualies, 0.0, 5.0);
	g_fPistolDelaySingle = Clamp(g_fPistolDelaySingle, 0.0, 5.0);
	g_fPistolDelayIncapped = Clamp(g_fPistolDelayIncapped, 0.0, 5.0);
}

float Clamp(float value, float min, float max)
{
	return value < min ? min : value > max ? max : value;
}

void Hook_OnPreThink(int iClient)
{
	if (!IsClientInGame(iClient) || GetClientTeam(iClient) != 2)
		return;
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(iActiveWeapon))
		return;
	char sWeaponName[ENTITY_MAX_NAME];
	GetEdictClassname(iActiveWeapon, sWeaponName, sizeof(sWeaponName));
	if (strcmp(sWeaponName, "weapon_pistol") != 0)
		return;
	float fOldValue = GetEntPropFloat(iActiveWeapon, Prop_Send, "m_flNextPrimaryAttack");
	float fNewValue = g_fNextAttack[iClient];
	if (fNewValue > fOldValue)
		SetEntPropFloat(iActiveWeapon, Prop_Send, "m_flNextPrimaryAttack", fNewValue);
}

void Event_WeaponFire(Event event, const char[] name , bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (!IsClientInGame(iClient) || GetClientTeam(iClient) != 2)
		return;
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(iActiveWeapon))
		return;
	char sWeaponName[ENTITY_MAX_NAME];
	GetEdictClassname(iActiveWeapon, sWeaponName, sizeof(sWeaponName));
	if (strcmp(sWeaponName, "weapon_pistol") != 0)
		return;
	g_fNextAttack[iClient] = GetGameTime() + (GetEntProp(iClient, Prop_Send, "m_isIncapacitated") ? 
		g_fPistolDelayIncapped : (GetEntProp(iActiveWeapon, Prop_Send, "m_isDualWielding") ? 
			g_fPistolDelayDualies : g_fPistolDelaySingle));
}

void Door_GetSettingsAll()
{
	int iEntity = -1;
	for (int i = 0; i < sizeof(g_szDoors_Type_Tracked); i++)
	{
		while ((iEntity = FindEntityByClassname(iEntity, g_szDoors_Type_Tracked[i])) != INVALID_ENT_REFERENCE)
		{
			if (IsValidEntity(iEntity))
				Door_GetSettings(iEntity, i);
		}
		iEntity = -1;
	}
}

void Door_GetSettings(int iEntity, int iType)
{
	g_ddDoors[iEntity].DoorsData_Type = iType;
	g_ddDoors[iEntity].DoorsData_Speed = GetEntPropFloat(iEntity, Prop_Data, "m_flSpeed");
	g_ddDoors[iEntity].DoorsData_ForceClose = GetEntProp(iEntity, Prop_Data, "m_bForceClosed") != 0;
}

void Door_SetSettings(int iEntity)
{
	SetEntPropFloat(iEntity, Prop_Data, "m_flSpeed", g_ddDoors[iEntity].DoorsData_Speed * g_fDoorSpeed);
	SetEntProp(iEntity, Prop_Data, "m_bForceClosed", false);
}

void Door_SetSettingsAll()
{
	int iEntity = -1;
	for (int i = 0; i < sizeof(g_szDoors_Type_Tracked); i++)
	{
		while ((iEntity = FindEntityByClassname(iEntity, g_szDoors_Type_Tracked[i])) != INVALID_ENT_REFERENCE)
		{
			if (IsValidEntity(iEntity))
			{
				Door_SetSettings(iEntity);
				SetEntProp(iEntity, Prop_Data, "m_bForceClosed", false);
			}
		}
		iEntity = -1;
	}
}

void Door_ResetSettings(int iEntity)
{
	SetEntPropFloat(iEntity, Prop_Data, "m_flSpeed", g_ddDoors[iEntity].DoorsData_Speed);
	SetEntProp(iEntity, Prop_Data, "m_bForceClosed", g_ddDoors[iEntity].DoorsData_ForceClose);
}

void Door_ResetSettingsAll()
{
	int iEntity = -1;
	for (int i = 0; i < sizeof(g_szDoors_Type_Tracked); i++)
	{
		while ((iEntity = FindEntityByClassname(iEntity, g_szDoors_Type_Tracked[i])) != INVALID_ENT_REFERENCE)
		{
			if (IsValidEntity(iEntity))
				Door_ResetSettings(iEntity);
		}
		iEntity = -1;
	}
}

void Door_ClearSettingsAll()
{
	for (int i = 0; i < MAX_ENTITIES; i++)
	{
		g_ddDoors[i].DoorsData_Type = DoorsTypeTracked_None;
		g_ddDoors[i].DoorsData_Speed = 0.0;
		g_ddDoors[i].DoorsData_ForceClose = false;
	}
}