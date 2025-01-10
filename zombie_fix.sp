#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define DEBUG 0
#define PLUGIN_VERSION "1.0.8"

bool MeleeDelay[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Stuck Zombie Melee Fix",
	author = "AtomicStryker",
	description = "Smash nonstaggering Zombies",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=932416"
}

public void OnPluginStart()
{
	CreateConVar("l4d_stuckzombiemeleefix_version", PLUGIN_VERSION, "Version of L4D Stuck Zombie Melee Fix on this server", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AddNormalSoundHook(view_as<NormalSHook>(HookSound_Callback)); // Hook melee sound events
	HookEvent("entity_shoved", Event_EntShoved);
}

Action HookSound_Callback(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (StrContains(sample, "Swish", false) == -1 || entity > MaxClients || MeleeDelay[entity])
	{
		return Plugin_Continue;
	}
	MeleeDelay[entity] = true;
	CreateTimer(1.0, ResetMeleeDelay, entity);
	#if DEBUG
    PrintToChatAll("Melee detected via soundhook.");
    #endif
	int entid = GetClientAimTarget(entity, false);
	if (entid <= 0) 
	{
		return Plugin_Continue;
	}
	char entclass[96];
	GetEntityNetClass(entid, entclass, sizeof(entclass));
	if (!StrEqual(entclass, "Infected"))
	{
		return Plugin_Continue;
	}
	float clientpos[3], entpos[3];
	GetEntityAbsOrigin(entid, entpos);
	GetClientEyePosition(entity, clientpos);
	if (GetVectorDistance(clientpos, entpos) >= 50)
	{
		Event newEvent = CreateEvent("entity_shoved");
		if (newEvent != null)
		{
			newEvent.SetInt("attacker", entity);
			newEvent.SetInt("entityid", entid);
			newEvent.Fire(true);
		}
	}
	return Plugin_Continue;
}

Action ResetMeleeDelay(Handle timer, any client)
{
	MeleeDelay[client] = false;
	return Plugin_Continue;
}

void Event_EntShoved(Event event, const char[] name, bool dontBroadcast)
{
	int entid = event.GetInt("entityid");
	char entclass[96];
	GetEntityNetClass(entid, entclass, sizeof(entclass));
	if (StrEqual(entclass, "Infected"))
	{
		DataPack hPack;
		CreateDataTimer(0.5, CheckForMovement, hPack, TIMER_FLAG_NO_MAPCHANGE);
		hPack.WriteCell(entid);
		float pos[3];
		GetEntityAbsOrigin(entid, pos);
		hPack.WriteFloat(pos[0]);
		hPack.WriteFloat(pos[1]);
		hPack.WriteFloat(pos[2]);
		#if DEBUG
		PrintToChatAll("Meleed Zombie detected.");
		#endif
	}
}

Action CheckForMovement(Handle timer, DataPack hDataPack)
{
	DataPack hPack = view_as<DataPack>(hDataPack);
	hPack.Reset();
	int zombieid = hPack.ReadCell();
	if (!IsValidEntity(zombieid))
	{
		return Plugin_Handled;
	}
	char entclass[96];
	GetEntityNetClass(zombieid, entclass, sizeof(entclass));
	if (!StrEqual(entclass, "Infected"))
	{
		return Plugin_Handled;
	}
	float oldpos[3];
	oldpos[0] = hPack.ReadFloat();
	oldpos[1] = hPack.ReadFloat();
	oldpos[2] = hPack.ReadFloat();
	float newpos[3];
	GetEntityAbsOrigin(zombieid, newpos);
	if (GetVectorDistance(oldpos, newpos) <= 5)
	{
		int zombiehealth = GetEntProp(zombieid, Prop_Data, "m_iHealth");
		int zombiehealthmax = FindConVar("z_health").IntValue;
		if (zombiehealth - (zombiehealthmax / 2) <= 0)
		{
			AcceptEntityInput(zombieid, "BecomeRagdoll");
			#if DEBUG
			PrintToChatAll("Slayed Stuck Zombie.");
			#endif
		}
		else
		{
			SetEntProp(zombieid, Prop_Data, "m_iHealth", zombiehealth - (zombiehealthmax / 2));
		}
	}
	return Plugin_Handled;
}

void GetEntityAbsOrigin(int entity, float origin[3])
{
	float mins[3], maxs[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
	GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
	origin[0] += (mins[0] + maxs[0]) * 0.5;
	origin[1] += (mins[1] + maxs[1]) * 0.5;
	origin[2] += (mins[2] + maxs[2]) * 0.5;
}