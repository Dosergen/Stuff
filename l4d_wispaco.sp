/*
*	Plugin	: [L4D/2] Witchy Spawn Controller
*	Version	: 2.0
*	Game	: Left4Dead & Left4Dead 2
*	Coder	: Sheleu
*	Testers	: Myself and Dosergen (Ja-Forces)
*
*
*	Version 1.0 (05.09.10)
*		- Initial release
*
*	Version 1.1 (08.09.10)
*		- Fixed encountered error 23: Native detected error
*		- Fixed bug with counting alive witches
*		- Added removal of the witch when she far away from the survivors
*
*	Version 1.2 (09.09.10)
*		- Added precache for witch (L4D2)
*
*	Version 1.3 (16.09.10)
*		- Added removal director's witch
*		- Stopped spawn witches after finale start
*
*	Version 1.4 (24.09.10)
*		- Code optimization
*
*	Version 1.5 (17.05.11)
*		- Fixed error "Entity is not valid" (sapphire989's message)
*
*	Version 1.6 (23.01.20)
*		- Converted plugin source to the latest syntax utilizing methodmaps
*		- Added "z_spawn_old" method for L4D2
*
*	Version 1.7 (07.03.20)
*		- Added cvar "l4d_wispaco_enable" to enable or disable plugin
*
*	Version 1.8 (27.05.21)
*		- Added DEBUG log to file
*
*	Version 1.9 (3.08.22)
*		- Fixed SourceMod 1.11 warnings
*		- Fixed counter if director's witch spawns at the beginning of the map
*		- Various changes to clean up the code
*
*	Version 2.0 (1.05.23)
*		- Added support for "Left 4 DHooks Direct" natives
*		- Code optimization
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "2.0"

float   g_fWitchTimeMin,
        g_fWitchTimeMax,
        g_fWitchDistance;

int     g_iCountWitch,
        g_iCountWitchInRound,
        g_iCountWitchAlive;

bool    g_bPluginEnable,
        g_bLeft4Dead2,
        g_bDirectorWitch,
        g_bFinaleStart,
        g_bDebugLog;

ConVar  g_hCvarEnable,
        g_hCvarCountWitchInRound,
        g_hCvarCountAliveWitch,
        g_hCvarWitchTimeMin,
        g_hCvarWitchTimeMax,
        g_hCvarWitchDistance,
        g_hCvarDirectorWitch,
        g_hCvarFinaleStart,
        g_hCvarLog;
		
bool    g_bRunTimer = false,
        g_bLeftSafeArea = false,
        g_bWitchExec = false,
        g_bHookedEvents = false,
        g_bSpawnWitchBride = false;

Handle  g_hSpawnTimer;

public Plugin myinfo =
{
	name = "[L4D/2] WiSpaCo",
	author = "Sheleu, Dosergen",
	description = "Witch revival manager by timer.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=137431"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test == Engine_Left4Dead2)
	{
		g_bLeft4Dead2 = true;
		return APLRes_Success;
	}
	else if (test == Engine_Left4Dead)
	{
		g_bLeft4Dead2 = false;
		return APLRes_Success;
	}
	strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
	return APLRes_SilentFailure;
}


public void OnPluginStart()
{
	CreateConVar("l4d_wispaco_version", PLUGIN_VERSION, "WiSpaCo plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_hCvarEnable = CreateConVar("l4d_wispaco_enable", "1", "Enable or disable the plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarCountWitchInRound = CreateConVar("l4d_wispaco_limit", "0", "Sets the limit for the number of witches that can spawn in a round.", FCVAR_NOTIFY);
	g_hCvarCountAliveWitch = CreateConVar("l4d_wispaco_limit_alive", "2", "Sets the limit for the number of alive witches at any given time.", FCVAR_NOTIFY);
	g_hCvarWitchTimeMin = CreateConVar("l4d_wispaco_spawn_time_min", "90", "Minimum spawn time for witches.", FCVAR_NOTIFY);
	g_hCvarWitchTimeMax = CreateConVar("l4d_wispaco_spawn_time_max", "180", "Maximum spawn time for witches.", FCVAR_NOTIFY);
	g_hCvarWitchDistance = CreateConVar("l4d_wispaco_distance", "1500", "Distance from survivors beyond which the witch will be removed.", FCVAR_NOTIFY);
	g_hCvarDirectorWitch = CreateConVar("l4d_wispaco_director_witch", "0", "Enable or disable director's witch.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarFinaleStart = CreateConVar("l4d_wispaco_finale_start", "1", "Allow spawning witches after the finale start.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarLog = CreateConVar("l4d_wispaco_log", "0", "Enable or disable debug logging.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, "l4d_wispaco");
	
	g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarCountWitchInRound.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarCountAliveWitch.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarWitchTimeMin.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarWitchTimeMax.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarWitchDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDirectorWitch.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarFinaleStart.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarLog.AddChangeHook(ConVarChanged_Cvars);
}

public void OnPluginEnd()
{
	LogCommand("#DEBUG: On plugin end");
	End_Timer(false);
}

public void OnConfigsExecuted()
{
	LogCommand("#DEBUG: On configs executed");
	IsAllowed();
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bPluginEnable = g_hCvarEnable.BoolValue;
	g_iCountWitchInRound = g_hCvarCountWitchInRound.IntValue;
	g_iCountWitchAlive = g_hCvarCountAliveWitch.IntValue;
	g_fWitchTimeMin = g_hCvarWitchTimeMin.FloatValue;
	g_fWitchTimeMax = g_hCvarWitchTimeMax.FloatValue;
	g_fWitchDistance = g_hCvarWitchDistance.FloatValue;
	g_bDirectorWitch = g_hCvarDirectorWitch.BoolValue;
	g_bFinaleStart = g_hCvarFinaleStart.BoolValue;
	g_bDebugLog = g_hCvarLog.BoolValue;
}

void IsAllowed()
{	
	GetCvars();

	if (g_bPluginEnable)
	{
		if (!g_bHookedEvents)
		{
			HookEvent("witch_spawn", evtWitchSpawn, EventHookMode_PostNoCopy);
			HookEvent("player_left_checkpoint", evtLeftSafeArea, EventHookMode_Post);
			HookEvent("round_start", evtRoundStart, EventHookMode_Post);
			HookEvent("round_end", evtRoundEnd, EventHookMode_Post);
			HookEvent("finale_start", evtFinaleStart, EventHookMode_PostNoCopy);

			g_bHookedEvents = true;
		}
	}
	else if (!g_bPluginEnable)
	{
		if (g_bHookedEvents)
		{
			UnhookEvent("witch_spawn", evtWitchSpawn, EventHookMode_PostNoCopy);
			UnhookEvent("player_left_checkpoint", evtLeftSafeArea, EventHookMode_Post);
			UnhookEvent("round_start", evtRoundStart, EventHookMode_Post);
			UnhookEvent("round_end", evtRoundEnd, EventHookMode_Post);
			UnhookEvent("finale_start", evtFinaleStart, EventHookMode_PostNoCopy);

			g_bHookedEvents = false;
		}
	}
}

public void OnMapStart()
{
	LogCommand("#DEBUG: Model precaching");

	if (!IsModelPrecached("models/infected/witch.mdl"))
	{
		PrecacheModel("models/infected/witch.mdl", true);
	}
	if (!IsModelPrecached("models/infected/witch_bride.mdl"))
	{
		PrecacheModel("models/infected/witch_bride.mdl", true);
	}
}

public void OnMapEnd()
{
	LogCommand("#DEBUG: On map end");
	End_Timer(false);
}

public void OnClientDisconnect(int client)
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			return;
		}
	}
	if (g_bRunTimer)
	{
		LogCommand("#DEBUG: All players logged out, timer stopped");
		End_Timer(false);
	}
}

void evtWitchSpawn(Event event, const char[] name , bool dontBroadcast)
{
	if (!g_bWitchExec && !g_bDirectorWitch)
	{
		int WitchID = event.GetInt("witchid");
		if (IsValidEntity(WitchID) && IsValidEdict(WitchID)) 
		{
			RemoveEntity(WitchID);
			LogCommand("#DEBUG: Removing Director's Witch ID = %i; Witch = %d, Max count witch = %d", WitchID, g_iCountWitch, g_iCountWitchInRound);
		}
		else
		{
			LogCommand("#DEBUG: Failed to remove Director's Witch ID = %i because not an edict index (witch ID) is valid", WitchID);
		}
	}
	else
	{
		g_iCountWitch++;
		LogCommand("#DEBUG: Witch spawned; Witch = %d, Max count witch = %d", g_iCountWitch, g_iCountWitchInRound);
	}
}

void evtLeftSafeArea(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRunTimer && !g_bLeftSafeArea)
	{	
		if (L4D_HasAnySurvivorLeftSafeArea())
		{
			LogCommand("#DEBUG: Player has left the starting area");
			g_bLeftSafeArea = true;
			First_Start_Timer();
		}	
	}
}

void evtRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	LogCommand("#DEBUG: Round started");	
	g_iCountWitch = 0;
	g_bLeftSafeArea = false;
}

void evtRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	LogCommand("#DEBUG: Round ended");
	End_Timer(false);
}

void evtFinaleStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bFinaleStart)
	{
		LogCommand("#DEBUG: Spawn ended [FINALE START]");
		End_Timer(false);
	}
}

void First_Start_Timer()
{
	g_bRunTimer = true;
	LogCommand("#DEBUG: First_Start_Timer; Safety zone leaved; RunTimer = %d", g_bRunTimer);
	Start_Timer();
}

void Start_Timer()
{
	float WitchSpawnTime = GetRandomFloat(g_fWitchTimeMin, g_fWitchTimeMax);
	LogCommand("#DEBUG: Start_Timer; Witch spawn time = %f", WitchSpawnTime);
	g_hSpawnTimer = CreateTimer(WitchSpawnTime, SpawnAWitch, _);
}

void End_Timer(const bool isClosedHandle)
{
	if (!g_bRunTimer)
	{
		return;
	}
	if (!isClosedHandle) 
	{
		if (g_hSpawnTimer != null)
		{
			delete g_hSpawnTimer;
			g_hSpawnTimer = null;
		}
	}
	g_bRunTimer = false;
	g_bWitchExec = false;
	LogCommand("#DEBUG: End_Timer; Handle closed; RunTimer = %d", g_bRunTimer);
}

Action SpawnAWitch(Handle timer)
{
	if (g_bRunTimer)
	{
		// Check if the maximum number of witches for this round has been reached
		if (g_iCountWitchInRound > 0 && g_iCountWitch >= g_iCountWitchInRound)
		{
			LogCommand("#DEBUG: Witch = %d, Max count witch = %d; End_Timer()", g_iCountWitch, g_iCountWitchInRound);
			End_Timer(true); // Stop the timer since the limit is reached
			return Plugin_Continue;
		}
		// Check if there are already too many witches alive
		if (g_iCountWitchAlive > 0 && g_iCountWitch >= g_iCountWitchAlive && GetCountAliveWitches() >= g_iCountWitchAlive)
		{
			LogCommand("#DEBUG: Too many alive witches, delaying spawn");
			Start_Timer(); // Restart the timer to try again later
			return Plugin_Continue;
		}
		// Get any valid client to spawn the witch for
		int anyclient = GetAnyClient();
		if (anyclient == 0)
		{
			LogCommand("#DEBUG: No valid clients, restarting timer");
			Start_Timer(); // If no valid clients are available, restart the timer and try again later
			return Plugin_Continue;
		}
		// Set a flag indicating a witch is about to be spawned
		g_bWitchExec = true;
		LogCommand("#DEBUG: Attempting to spawn");
		// Spawn the witch for the selected client
		SpawnCommand(anyclient);
		// Reset the flag after the witch is spawned
		g_bWitchExec = false;
		LogCommand("#DEBUG: More witches needed, restarting timer");
		Start_Timer(); // Restart the timer for the next spawn
	}
	return Plugin_Stop; // Stop the function execution if the timer shouldn't run
}

void SpawnCommand(int client)
{
	if (client)
	{
		int iWitchiNdex;
		int iRandom = GetRandom();
		float fSpawnPos[3], fSpawnAng[3];
		// Attempt to find a valid spawn position based on the random value
		if (iRandom > 0 && L4D_GetRandomPZSpawnPosition(iRandom, 8, 30, fSpawnPos))
		{
			// Attempt to create a "witch" entity using the entity name "witch"
			iWitchiNdex = CreateEntityByName("witch");
			if (iWitchiNdex == -1)
			{
				LogCommand("#DEBUG: Failed to create a witch with sdktools");
				return; // Exit the function if entity creation fails
			}
			// Set the entity's position to the found spawn position
			SetAbsOrigin(iWitchiNdex, fSpawnPos);
			// Randomize the yaw angle (rotation around the vertical axis) between -179 and 179 degrees
			fSpawnAng[1] = GetRandomFloatEx(-179.0, 179.0); 
			// Apply the randomized angle to the entity
			SetAbsAngles(iWitchiNdex, fSpawnAng);
			// Spawn the entity into the game world
			DispatchSpawn(iWitchiNdex);
		}
		else if (g_bLeft4Dead2)
		{
			if (g_bSpawnWitchBride)
			{
				// Spawn a Witch Bride at the fallback position using L4D2_SpawnWitchBride
				iWitchiNdex = L4D2_SpawnWitchBride(fSpawnPos, fSpawnAng);
			}
			else
			{
				// Spawn a regular Witch at the fallback position using L4D2_SpawnWitch
				iWitchiNdex = L4D2_SpawnWitch(fSpawnPos, fSpawnAng);
			}
			// Toggle the boolean flag to alternate between spawning a Witch Bride and a regular Witch
			g_bSpawnWitchBride = !g_bSpawnWitchBride;
			if (iWitchiNdex == -1)
			{
				LogCommand("#DEBUG: Failed to create a witch with lef4dhooks");
				return; // Exit the function if entity creation fails
			}
		}
	}
}

int GetAnyClient()
{
	int i;
	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			return i;
		}
	}
	return 0;
}

int FindEntityByClassname2(int startEnt, const char[] classname)
{
	while (startEnt < GetMaxEntities() && !IsValidEntity(startEnt))
	{
		startEnt++;
	}
	return FindEntityByClassname(startEnt, classname);
}

int GetCountAliveWitches()
{
	int iCountAlive = 0;
	int iWitchiNdex = -1;
	while ((iWitchiNdex = FindEntityByClassname2(iWitchiNdex, "witch")) != INVALID_ENT_REFERENCE)
	{
		iCountAlive++;
		LogCommand("#DEBUG: Witch ID = %i (Alive witches = %i)", iWitchiNdex, iCountAlive);
		if (g_fWitchDistance > 0)
		{
			float fWitchPos[3];
			float fPlayerPos[3];
			GetEntPropVector(iWitchiNdex, Prop_Send, "m_vecOrigin", fWitchPos);
			int iClients = 0;
			int iTooFar = 0;
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
				{
					iClients++;
					GetClientAbsOrigin(i, fPlayerPos);
					float distance = GetVectorDistance(fWitchPos, fPlayerPos);
					LogCommand("#DEBUG: Distance to witch = %f; Max distance = %f", distance, g_fWitchDistance);
					if (distance > g_fWitchDistance)
					{
						iTooFar++;
					}
				}
			}
			if (iTooFar == iClients)
			{
				if (IsValidEntity(iWitchiNdex) && IsValidEdict(iWitchiNdex))
				{
					RemoveEntity(iWitchiNdex);
				}
				iCountAlive--;
				LogCommand("#DEBUG: Witch removed for being too far; Alive witches = %d", iCountAlive);
			}
		}
	}
	LogCommand("#DEBUG: Alive witches = %d, Max count alive witches = %d", iCountAlive, g_iCountWitchAlive);
	return iCountAlive;
}

int GetRandom()
{
	ArrayList array = new ArrayList();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
		{
			array.Push(i);
		}
	}
	int client = 0;
	if (array.Length > 0)
	{
		int randomIndex = GetRandomIntEx(0, array.Length - 1);
		client = array.Get(randomIndex);
	}
	delete array;
	return client;
}

int GetRandomIntEx(int min, int max)
{
	return GetURandomInt() % (max - min + 1) + min;
}

float GetRandomFloatEx(float min, float max)
{
	return GetURandomFloat() * (max - min) + min;
}

void LogCommand(const char[] format, any ...)
{
	if (!g_bDebugLog)
	{
		return;
	}
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	char sPath[PLATFORM_MAX_PATH], sTime[32];
	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/wispaco.log");
	File file = OpenFile(sPath, "a+");
	FormatTime(sTime, sizeof(sTime), "L %m/%d/%Y - %H:%M:%S");
	file.WriteLine("%s: %s", sTime, buffer);
	FlushFile(file);
	delete file;
}