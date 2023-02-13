#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define DEBUG 0
#define PLUGIN_VERSION "1.0.6"

bool MeleeDelay[MAXPLAYERS+1];

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
	CreateConVar("l4d_stuckzombiemeleefix_version", PLUGIN_VERSION, " Version of L4D Stuck Zombie Melee Fix on this server ", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	HookEvent("entity_shoved", Event_EntShoved);
	AddNormalSoundHook(view_as<NormalSHook>(HookSound_Callback)); //my melee hook since they didnt include an event for it
}

public Action HookSound_Callback(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	//to work only on melee sounds, its 'swish' or 'weaponswing'
	if (StrContains(sample, "Swish", false) == -1)
		return Plugin_Continue;
	//so the client has the melee sound playing. OMG HES MELEEING!

	if (entity > MaxClients)
		return Plugin_Continue; // bugfix for some people on L4D2

	//add in a 1 second delay so this doesnt fire every frame
	if (MeleeDelay[entity])
		return Plugin_Continue; //note 'Entity' means 'client' here
	MeleeDelay[entity] = true;
	CreateTimer(1.0, ResetMeleeDelay, entity);

	#if DEBUG
	PrintToChatAll("Melee detected via soundhook.");
	#endif

	int entid = GetClientAimTarget(entity, false);
	if (entid <= 0) 
		return Plugin_Continue;

	char entclass[96];
	GetEntityNetClass(entid, entclass, sizeof(entclass));
	if (!StrEqual(entclass, "Infected"))
		return Plugin_Continue;

	float clientpos[3], entpos[3];
	GetEntityAbsOrigin(entid, entpos);
	GetClientEyePosition(entity, clientpos);
	if (GetVectorDistance(clientpos, entpos) < 50)
		return Plugin_Continue; //else you could 'jedi melee' Zombies from a distance

	#if DEBUG
	PrintToChatAll("Youre meleeing and looking at Zombie id #%i", entid);
	#endif

	//now to make this Zombie fire a event to be caught by the actual 'fix'

	Event newEvent = CreateEvent("entity_shoved");
	if(newEvent != null)
	{
		newEvent.SetInt("attacker", entity); //the client being called Entity is a bit unfortunate
		newEvent.SetInt("entityid", entid);
		newEvent.Fire(true);
	}

	return Plugin_Continue;
}

public Action ResetMeleeDelay(Handle timer, any client)
{
	MeleeDelay[client] = false;
	return Plugin_Stop;
}

public void Event_EntShoved(Event event, const char[] name, bool dontBroadcast)
{
	int entid = event.GetInt("entityid"); //get the events shoved entity id
	
	char entclass[96];
	GetEntityNetClass(entid, entclass, sizeof(entclass));
	if (!StrEqual(entclass, "Infected")) 
		return; //make sure it IS a zombie.
	
	DataPack hPack; //a data pack because i need multiple values saved
	CreateDataTimer(0.5, CheckForMovement, hPack, TIMER_FLAG_NO_MAPCHANGE); //0.5 seemed both long enough for a normal zombie to stumble away and for a stuck one to DIEEEEE
	
	hPack.WriteCell(entid); //save the Zombie id
	
	float pos[3];
	GetEntityAbsOrigin(entid, pos); //get the Zombies position
	hPack.WriteFloat(pos[0]); //save the Zombies position
	hPack.WriteFloat(pos[1]);
	hPack.WriteFloat(pos[2]);
	
	#if DEBUG
	PrintToChatAll("Meleed Zombie detected.");
	#endif
}

public Action CheckForMovement(Handle timer, DataPack hDataPack)
{
	DataPack hPack = view_as<DataPack>(hDataPack);
	hPack.Reset(); //this resets our 'reading' position in the data pack, to start from the beginning
	
	int zombieid = hPack.ReadCell(); //get the Zombie id
	if (!IsValidEntity(zombieid))
		return Plugin_Handled; //did the zombie get disappear somehow?
	
	char entclass[96];
	GetEntityNetClass(zombieid, entclass, sizeof(entclass));
	if (!StrEqual(entclass, "Infected"))
		return Plugin_Handled; //make sure it STILL IS a zombie.
	
	float oldpos[3];
	oldpos[0] = hPack.ReadFloat(); //get the old Zombie position (half a sec ago)
	oldpos[1] = hPack.ReadFloat();
	oldpos[2] = hPack.ReadFloat();
	
	float newpos[3];
	GetEntityAbsOrigin(zombieid, newpos); //get the Zombies current position
	
	if (GetVectorDistance(oldpos, newpos) > 5)
		return Plugin_Handled; //if the positions differ, the zombie was correctly shoved and is now staggering. Plugin End
	
	#if DEBUG
	PrintToChatAll("Stuck meleed Zombie detected.");
	#endif
	
	//now i could simply slay the stuck zombie. but this would also instantkill any zombie you meleed into a corner or against a wall
	//so instead i coded a two-punts-it-doesnt-move-so-slay-it command
	
	int zombiehealth = GetEntProp(zombieid, Prop_Data, "m_iHealth");
	int zombiehealthmax = FindConVar("z_health").IntValue;
	
	if (zombiehealth - (zombiehealthmax / 2) <= 0) // if the zombies health is less than half
	{
		//SetEntProp(zombieid, Prop_Data, "m_iHealth", 0); //CRUSH HIM!!!!!! - ragdoll bug, unused
		AcceptEntityInput(zombieid, "BecomeRagdoll"); //Damizean pointed this one out, Cheers to him.
		
		#if DEBUG
		PrintToChatAll("Slayed Stuck Zombie.");
		#endif
	}
	
	else SetEntProp(zombieid, Prop_Data, "m_iHealth", zombiehealth - (zombiehealthmax / 2)); //else remove half of its health, so the zombie dies from the next melee blow
	return Plugin_Stop;
}

//entity abs origin code from here
//http://forums.alliedmods.net/showpost.php?s=e5dce96f11b8e938274902a8ad8e75e9&p=885168&postcount=3
public void GetEntityAbsOrigin(int entity, float origin[3])
{
	float mins[3], maxs[3];
	GetEntPropVector(entity, Prop_Send,"m_vecOrigin", origin);
	GetEntPropVector(entity, Prop_Send,"m_vecMins", mins);
	GetEntPropVector(entity, Prop_Send,"m_vecMaxs", maxs);
	
	origin[0] += (mins[0] + maxs[0]) * 0.5;
	origin[1] += (mins[1] + maxs[1]) * 0.5;
	origin[2] += (mins[2] + maxs[2]) * 0.5;
}