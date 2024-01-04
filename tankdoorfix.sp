#pragma semicolon 1
#pragma newdecls required
 
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <entity_prop_stocks>

#define VERSION "1.4.5"

#define SAFEDOOR_MODEL_01 "models/props_doors/checkpoint_door_01.mdl"
#define SAFEDOOR_MODEL_02 "models/props_doors/checkpoint_door_-01.mdl"
#define SAFEDOOR_MODEL_03 "models/lighthouse/checkpoint_door_lighthouse01.mdl"
#define SAFEDOOR_CLASS_01 "prop_door_rotating_checkpoint"

static int g_iTankCount;
static int g_iTankClassIndex;
static int g_iEnt_SafeDoor;

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
	g_iEnt_SafeDoor = -1;
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
	g_iEnt_SafeDoor = GetSafeRoomDoor();
	if (g_iEnt_SafeDoor > 0)
	{
		char model[128];
		float origin[3], angles[3], endorigin[3], Push[3], power;
		GetClientAbsOrigin(client, origin);
		GetClientAbsAngles(client, angles);
		origin[2] += 20.0;
		Handle g_hTRace = TR_TraceRayFilterEx(origin, angles, MASK_SHOT, RayType_Infinite, TraceFilterClients, client);
		if (TR_DidHit(g_hTRace))
		{
			g_iEnt_SafeDoor = TR_GetEntityIndex(g_hTRace);
			TR_GetEndPosition(endorigin, g_hTRace);
			if (g_iEnt_SafeDoor && IsValidDoor(g_iEnt_SafeDoor) && TR_LadderFilter(g_iEnt_SafeDoor) && GetVectorDistance(origin, endorigin) <= 90.0)
			{
				GetEntPropVector(g_iEnt_SafeDoor, Prop_Send, "m_vecOrigin", endorigin);
				GetEntPropString(g_iEnt_SafeDoor, Prop_Data, "m_ModelName", model, sizeof(model));
				float pos[3], ang[3];
				GetEntPropVector(g_iEnt_SafeDoor, Prop_Send, "m_vecOrigin", pos);
				GetEntPropVector(g_iEnt_SafeDoor, Prop_Send, "m_angRotation", ang);
				SetEntProp(g_iEnt_SafeDoor, Prop_Send, "m_CollisionGroup", 1);
				SetEntProp(g_iEnt_SafeDoor, Prop_Data, "m_CollisionGroup", 1);
				pos[2] += 10000.0;
				TeleportEntity(g_iEnt_SafeDoor, pos, NULL_VECTOR, NULL_VECTOR);
				pos[2] -= 10000.0;
				SetEntityRenderMode(g_iEnt_SafeDoor, RENDER_TRANSALPHA);
				SetEntityRenderColor(g_iEnt_SafeDoor, 0, 0, 0, 0);
				int g_iEnt_BrokenDoor = CreateEntityByName("prop_physics");
				DispatchKeyValue(g_iEnt_BrokenDoor, "model", model);
				DispatchKeyValue(g_iEnt_BrokenDoor, "spawnflags", "4");
				DispatchSpawn(g_iEnt_BrokenDoor);
				GetAngleVectors(angles, Push, NULL_VECTOR, NULL_VECTOR);
				power = GetRandomFloat(600.0, 800.0);
				Push[0] *= power;
				Push[1] *= power;
				Push[2] *= power;
				TeleportEntity(g_iEnt_BrokenDoor, pos, ang, Push);
				if (IsValidDoor(g_iEnt_BrokenDoor))
				{
					char remove[64];
					FormatEx(remove, sizeof(remove), "OnUser1 !self:kill::%f:1", 5.0);			
					SetVariantString(remove);
					SetEntityRenderFx(g_iEnt_BrokenDoor, RENDERFX_FADE_SLOW);
					AcceptEntityInput(g_iEnt_BrokenDoor, "AddOutput");
					AcceptEntityInput(g_iEnt_BrokenDoor, "FireUser1");
				}
			}
		}
		delete g_hTRace;
	}
}

int GetSafeRoomDoor()
{
	g_iEnt_SafeDoor = MaxClients + 1;
	while ((g_iEnt_SafeDoor = FindEntityByClassname(g_iEnt_SafeDoor, SAFEDOOR_CLASS_01)) != -1)
	{
		if (!IsValidEntity(g_iEnt_SafeDoor) && !IsValidEdict(g_iEnt_SafeDoor))
		{
			continue;
		}
		char model[128];
		GetEntPropString(g_iEnt_SafeDoor, Prop_Data, "m_ModelName", model, sizeof(model));
		int spawn_flags = GetEntProp(g_iEnt_SafeDoor, Prop_Data, "m_spawnflags");
		if (((strcmp(model, SAFEDOOR_MODEL_01) == 0) && ((spawn_flags == 8192) || (spawn_flags == 0))) 
		|| ((strcmp(model, SAFEDOOR_MODEL_02) == 0) && ((spawn_flags == 8192) || (spawn_flags == 0)))
		|| ((strcmp(model, SAFEDOOR_MODEL_03) == 0) && ((spawn_flags == 8192) || (spawn_flags == 0))))
		{
			return g_iEnt_SafeDoor;
		}
	}
	return -1;
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

stock bool TR_LadderFilter(int entity)
{
	if (IsValidEntity(entity) && IsValidEdict(entity))
	{
		char waClass[64] = {'\0'};
		GetEntityClassname(entity, waClass, sizeof(waClass));
		if (waClass[0] == 'f' && (strcmp(waClass, "func_simpleladder") == 0 || strcmp(waClass, "func_ladder") == 0))
		{
			return false;
		}
	}
	return true;
}

stock bool IsValidDoor(int entity)
{
	return entity > 0 && IsValidEntity(entity) && IsValidEdict(entity);
}

stock bool TraceFilterClients(int entity, int mask, any data)
{
 	return entity != data && entity > MaxClients;
}