#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// Flag indicating if the plugin was loaded late
bool g_bLateLoad = false;
// Array to track whether each player is currently using a minigun
bool g_bInMinigun[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name =          "[L4D/2] Minigun fix",
	author =        "SMAC, Kyle Sanderson, Dosergen",
	description =   "Prevents players from flying long distances when using the minigun",
	version =       "1.2.2",
	url =           "https://github.com/Dosergen/Stuff"
}

// Called when the plugin is loaded
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// Check if the game engine is Left 4 Dead 1 or 2
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead && test != Engine_Left4Dead2)
	{
		// If not, set an error message and prevent loading
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	// Store the late load status and allow the plugin to load
	g_bLateLoad = late;
	return APLRes_Success;
}

// Initializes plugin logic when it starts
public void OnPluginStart()
{
	// If the plugin was loaded late, hook existing entities and players
	if (!g_bLateLoad)
		return;
	char sClassname[32];
	int maxEntities = GetEntityCount();
	// Loop through all entities to find and hook existing miniguns
	for (int i = MaxClients + 1; i < maxEntities; i++)
	{
		if (IsValidEntity(i) && GetEntityClassname(i, sClassname, sizeof(sClassname)))
			OnEntityCreated(i, sClassname);
	}
	// Initialize the minigun status for each player
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
			OnClientPutInServer(i);
	}
}

// Called when a player disconnects
public void OnClientDisconnect(int client)
{
	// Reset the minigun status for the client
	g_bInMinigun[client] = false;
}

// Called when a player joins the server
public void OnClientPutInServer(int client)
{
	// Initialize the minigun status for the client
	g_bInMinigun[client] = false;
}

// Called when an entity is created
public void OnEntityCreated(int entity, const char[] classname)
{
	// Check if the created entity is a minigun and hook its "Use" event
	if (strcmp(classname, "prop_minigun") == 0 
	|| strcmp(classname, "prop_minigun_l4d1") == 0 
	|| strcmp(classname, "prop_mounted_machine_gun") == 0)
		SDKHook(entity, SDKHook_Use, OnUse);
}

// Handles the "Use" event on a minigun
Action OnUse(int entity, int activator, int caller, UseType type, float value)
{
	// Check if the player is on the ground and using the minigun toggle
	int iGround = GetEntPropEnt(caller, Prop_Send, "m_hGroundEntity");
	if (iGround == 0 || type != Use_Toggle)
	{
		// If valid client is using the minigun for the first time, hook PreThink
		if (IsValidClient(activator) && type == Use_Set && !g_bInMinigun[activator])
		{
			g_bInMinigun[activator] = true;
			SDKHook(caller, SDKHook_PreThink, OnPreThink);
		}
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

// Monitors player's state while using the minigun to prevent flying
Action OnPreThink(int client)
{
	// If the player is not in the minigun, ignore
	if (!g_bInMinigun[client])
		return Plugin_Continue;
	// Check if the player is on the ground and not jumping
	int iButtons = GetClientButtons(client);
	if (!(iButtons & IN_JUMP) || !(GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONGROUND))
		return Plugin_Continue;
	// Retrieve the player's current velocity vector
	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
	// If velocity is too high, scale it down to prevent "flying"
	if (GetVectorLength(fVelocity) >= (GetEntPropFloat(client, Prop_Data, "m_flMaxspeed") * 1.2))
	{
		ScaleVector(fVelocity, GetRandomFloat(0.20, 0.50));
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
	}
	// Reset minigun status and unhook PreThink
	g_bInMinigun[client] = false;
	SDKUnhook(client, SDKHook_PreThink, OnPreThink);
	return Plugin_Continue;
}

// Utility function to check if a client is a valid and active player
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}