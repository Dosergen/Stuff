#pragma semicolon 1
#pragma newdecls required
 
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <entity_prop_stocks>
 
#define VERSION "1.4.6"
 
#define DOOR_CLASS_01 "prop_door_rotating"
#define DOOR_CLASS_02 "prop_door_rotating_checkpoint"
#define DOOR_MODEL_01 "models/props_doors/doorfreezer01.mdl"
#define DOOR_MODEL_02 "models/props_doors/checkpoint_door_01.mdl"
#define DOOR_MODEL_03 "models/lighthouse/checkpoint_door_lighthouse01.mdl"

static int g_iTankCount;
static int g_iTankClassIndex;
 
float g_fNextTankPunchAllowed[MAXPLAYERS+1];
 
public Plugin myinfo = 
{
	name = "TankDoorFix",
	author = "PP(R)TH: Dr. Gregory House, Glide Loading, Uncle Jessie, Dosergen",
	description = "This should at some point fix the case in which the tank misses the door he's supposed to destroy by using his punch",
	version = VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=225087"
}
 
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead:
		{
			g_iTankClassIndex = 5;
		}
		case Engine_Left4Dead2:
		{
			g_iTankClassIndex = 8;
		}
		default:
		{
			strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
			return APLRes_SilentFailure;
		}
	}
	return APLRes_Success;
}
 
public void OnPluginStart()
{
	CreateConVar("tankdoorfix_version", VERSION, "TankDoorFix Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	HookEvent("round_start", evt_RoundStart, EventHookMode_Post);
	HookEvent("tank_spawn", evt_SpawnTank, EventHookMode_Post);
	HookEvent("tank_killed", evt_KilledTank, EventHookMode_Post);
}
 
void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_iTankCount = 0;
}
 
void evt_SpawnTank(Event event, const char[] name, bool dontBroadcast)
{
	g_iTankCount++;
	g_fNextTankPunchAllowed[GetClientOfUserId(event.GetInt("userid"))] = GetGameTime() + 0.8;
}
 
void evt_KilledTank(Event event, const char[] name, bool dontBroadcast)
{
	g_iTankCount--;
}
 
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (g_iTankCount > 0)
	{
		if (buttons & IN_ATTACK && IsValidTank(client) && !IsPlayerGhost(client))
		{
			int tankweapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
 			if (tankweapon > 0)
			{
				float gameTime = GetGameTime();
 				if (GetEntPropFloat(tankweapon, Prop_Send, "m_flTimeWeaponIdle") <= gameTime && g_fNextTankPunchAllowed[client] <= gameTime)
				{
					g_fNextTankPunchAllowed[client] = gameTime + 2.0;
					CreateTimer(1.0, Timer_DoorCheck, GetClientUserId(client));
				}
			}
		}
	}
	return Plugin_Continue;
}
 
Action Timer_DoorCheck(Handle timer, int clientUserID)
{
	int client = GetClientOfUserId(clientUserID);
 	if (IsValidTank(client) && !IsPlayerGhost(client))
	{
		IsLookingAtBreakableDoor(client);
	}
 	return Plugin_Stop;
}
 
void IsLookingAtBreakableDoor(int client)
{
	int g_iEntSafeDoor;
	float origin[3], angles[3], endorigin[3], Push[3], power;
	GetClientAbsOrigin(client, origin);
	GetClientAbsAngles(client, angles);
	origin[2] += 20.0;
	TR_TraceRayFilter(origin, angles, MASK_SHOT, RayType_Infinite, TraceFilterClients, client);
	if (TR_DidHit())
	{
		g_iEntSafeDoor = TR_GetEntityIndex();
		TR_GetEndPosition(endorigin);
		if (g_iEntSafeDoor != -1 && GetVectorDistance(origin, endorigin) <= 90.0)
		{
			char sClassName[64], sModelName[64];
			GetEntityClassname(g_iEntSafeDoor, sClassName, sizeof(sClassName));
			GetEntPropString(g_iEntSafeDoor, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
			if (StrContains(sClassName, DOOR_CLASS_01) != -1 && StrContains(sModelName, DOOR_MODEL_01) != -1 
			|| StrContains(sClassName, DOOR_CLASS_02) != -1 && StrContains(sModelName, DOOR_MODEL_02) != -1)
			{
				GetEntPropVector(g_iEntSafeDoor, Prop_Send, "m_vecOrigin", endorigin);
				float vPos[3], vAng[3];
				GetEntPropVector(g_iEntSafeDoor, Prop_Send, "m_vecOrigin", vPos);
				GetEntPropVector(g_iEntSafeDoor, Prop_Send, "m_angRotation", vAng);
				SetEntProp(g_iEntSafeDoor, Prop_Send, "m_CollisionGroup", 1);
				SetEntProp(g_iEntSafeDoor, Prop_Data, "m_CollisionGroup", 1);
				vPos[2] += 10000.0;
				TeleportEntity(g_iEntSafeDoor, vPos, NULL_VECTOR, NULL_VECTOR);
				vPos[2] -= 10000.0;
				SetEntityRenderMode(g_iEntSafeDoor, RENDER_TRANSALPHA);
				SetEntityRenderColor(g_iEntSafeDoor, 0, 0, 0, 0);
				int g_iEntBrokenEnt = CreateEntityByName("prop_physics");
				DispatchKeyValue(g_iEntBrokenEnt, "model", sModelName);
				DispatchKeyValue(g_iEntBrokenEnt, "spawnflags", "4");
				DispatchSpawn(g_iEntBrokenEnt);
				GetAngleVectors(angles, Push, NULL_VECTOR, NULL_VECTOR);
				power = GetRandomFloat(600.0, 800.0);
				Push[0] *= power;
				Push[1] *= power;
				Push[2] *= power;
				TeleportEntity(g_iEntBrokenEnt, vPos, vAng, Push);
				if (g_iEntBrokenEnt != -1)
				{
					char remove[64];
					FormatEx(remove, sizeof(remove), "OnUser1 !self:kill::%f:1", 5.0);
					SetVariantString(remove);
					SetEntityRenderFx(g_iEntBrokenEnt, RENDERFX_FADE_SLOW);
					AcceptEntityInput(g_iEntBrokenEnt, "AddOutput");
					AcceptEntityInput(g_iEntBrokenEnt, "FireUser1");
				}
			}
		}
	}
}
 
stock bool IsValidClient(int client)
{
	if (client <= 0)
	{
		return false;
	}
 	if (client > MaxClients)
	{
		return false;
	}
 	if (!IsClientInGame(client))
	{
		return false;
	}
 	if (!IsPlayerAlive(client))
	{
		return false;
	}
	return true;
}
 
stock bool IsValidTank(int client)
{
	if (IsValidClient(client) && GetClientTeam(client) == 3)
	{
		int class = GetEntProp(client, Prop_Send, "m_zombieClass");
 		if (class == g_iTankClassIndex)
		{
			return true;
		}
 		return false;
	}
 	return false;
}

stock bool IsPlayerGhost(int client)
{
	if (GetEntProp(client, Prop_Send, "m_isGhost")) 
	{
		return true;
	}
	else 
	{
		return false;
	}
}
 
stock bool TraceFilterClients(int entity, int mask, any data)
{
 	return entity != data && entity > MaxClients;
}