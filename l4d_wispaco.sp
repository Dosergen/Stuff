/*
*	Plugin	: [L4D/2] Witchy Spawn Controller
*	Version	: 1.9
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
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.9"
#define CVAR_FLAGS	FCVAR_NOTIFY

float  g_fWitchTimeMin, g_fWitchTimeMax, g_fWitchDistance;

int    g_iCountWitch, g_iCountWitchInRound, g_iCountWitchAlive;

bool   g_bL4D2, g_bPluginEnable, g_bDirectorWitch, g_bFinaleStart, g_bDebugLog;

ConVar g_hCvarEnable, g_hCvarCountWitchInRound, g_hCvarCountAliveWitch, g_hCvarWitchTimeMin, 
       g_hCvarWitchTimeMax, g_hCvarWitchDistance, g_hCvarDirectorWitch, g_hCvarFinaleStart, g_hCvarLog;
		
bool   g_bRunTimer = false, g_bRoundStart = false, g_bLeftSafeArea = false, g_bWitchExec = false, g_bHookedEvents = false;

Handle g_hSpawnTimer;

public Plugin myinfo =
{
	name = "[L4D/2] WiSpaCo",
	author = "Sheleu, Dosergen",
	description = "This plugin spawns more witches on map.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=137431"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{	
	EngineVersion iEngineVersion = GetEngineVersion();
	if (iEngineVersion == Engine_Left4Dead) 
	{
		g_bL4D2 = false;
	}
	else if (iEngineVersion == Engine_Left4Dead2) 
	{
		g_bL4D2 = true;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d_wispaco_version", PLUGIN_VERSION, "WiSpaCo plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_hCvarEnable = CreateConVar("l4d_wispaco_enable", "1", "Enable or Disable plugin", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hCvarCountWitchInRound = CreateConVar("l4d_wispaco_limit", "0", "Sets the limit for witches spawned. If 0, the plugin will not check count witches", CVAR_FLAGS);
	g_hCvarCountAliveWitch = CreateConVar("l4d_wispaco_limit_alive", "2", "Sets the limit alive witches. If 0, the plugin will not check count alive witches", CVAR_FLAGS);
	g_hCvarWitchTimeMin = CreateConVar("l4d_wispaco_spawn_time_min", "90", "Sets the min spawn time for witches spawned by the plugin in seconds", CVAR_FLAGS);
	g_hCvarWitchTimeMax = CreateConVar("l4d_wispaco_spawn_time_max", "180", "Sets the max spawn time for witches spawned by the plugin in seconds", CVAR_FLAGS);
	g_hCvarWitchDistance = CreateConVar("l4d_wispaco_distance", "1500", "The range from survivors that witch should be removed. If 0, the plugin will not remove witches", CVAR_FLAGS);
	g_hCvarDirectorWitch = CreateConVar("l4d_wispaco_director_witch", "0", "If 1, enable director's witch. If 0, disable director's witch", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hCvarFinaleStart = CreateConVar("l4d_wispaco_finale_start", "1", "If 1, enable spawn witches after finale start. If 0, disable spawn witches after finale start", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hCvarLog = CreateConVar("l4d_wispaco_log", "0", "Enable or Disable DEBUG log", CVAR_FLAGS, true, 0.0, true, 1.0);
	
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
			HookEvent("witch_spawn", Event_WitchSpawned, EventHookMode_PostNoCopy);
			HookEvent("player_left_checkpoint", Event_PlayerLeftStartArea);
			HookEvent("door_open", Event_DoorOpened);
			HookEvent("round_start", Event_RoundStart);
			HookEvent("round_end", Event_RoundEnd);
			HookEvent("map_transition", Event_RoundEnd);
			HookEvent("finale_start", Event_FinaleStart);

			g_bHookedEvents = true;
		}
	}
	else if (!g_bPluginEnable)
	{
		if (g_bHookedEvents)
		{
			UnhookEvent("witch_spawn", Event_WitchSpawned, EventHookMode_PostNoCopy);
			UnhookEvent("player_left_checkpoint", Event_PlayerLeftStartArea);
			UnhookEvent("door_open", Event_DoorOpened);
			UnhookEvent("round_start", Event_RoundStart);
			UnhookEvent("round_end", Event_RoundEnd);
			UnhookEvent("map_transition", Event_RoundEnd);
			UnhookEvent("finale_start", Event_FinaleStart);

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

void Event_WitchSpawned(Event event, const char[] name , bool dontBroadcast)
{
	if (!g_bWitchExec && !g_bDirectorWitch)
	{
		int WitchID = event.GetInt("witchid");
		if (IsValidEdict(WitchID)) 
		{
			AcceptEntityInput(WitchID, "Kill");
			LogCommand("#DEBUG: Remove director's witch ID = %i; Witch = %d, Max count witch = %d", WitchID, g_iCountWitch, g_iCountWitchInRound);
		}
		else
		{
			LogCommand("#DEBUG: Don't remove director's witch ID = %i because not an edict index (witch ID) is valid", WitchID);
		}
	}
	else
	{
		g_iCountWitch++;
		LogCommand("#DEBUG: Witch spawned; Witch = %d, Max count witch = %d", g_iCountWitch, g_iCountWitchInRound);
	}
}

void Event_PlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRunTimer && !g_bLeftSafeArea)
	{	
		if (L4D_HasAnySurvivorLeftSafeArea())
		{
			LogCommand("#DEBUG: Player left the starting area");
			g_bLeftSafeArea = true;
			First_Start_Timer();
		}	
	}
}

void Event_DoorOpened(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRunTimer && !g_bLeftSafeArea)
	{
		if (g_bRoundStart && event.GetBool("checkpoint"))
		{
			LogCommand("#DEBUG: Door opened");
			g_bLeftSafeArea = true;
			First_Start_Timer();
		}
	}
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	LogCommand("#DEBUG: Round started");	
	g_iCountWitch = 0;
	g_bRoundStart = true;
	g_bLeftSafeArea = false;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	LogCommand("#DEBUG: Round ended");
	End_Timer(false);
}

void Event_FinaleStart(Event event, const char[] name, bool dontBroadcast)
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
	g_bRoundStart = false;
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
	if (g_bRunTimer)
	{
		if (!isClosedHandle) 
		{
			delete g_hSpawnTimer;
		}
		g_bRunTimer = false;
		g_bWitchExec = false;
		LogCommand("#DEBUG: End_Timer; Handle closed; RunTimer = %d", g_bRunTimer);
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
	int countalive = 0;
	int index = -1;
	while ((index = FindEntityByClassname2(index, "witch")) != -1)
	{
		countalive++;
		LogCommand("#DEBUG: Witch ID = %i (Alive witches = %i)", index, countalive);
		if (g_fWitchDistance > 0)
		{
			float WitchPos[3];
			float PlayerPos[3];
			GetEntPropVector(index, Prop_Send, "m_vecOrigin", WitchPos);
			int k = 0;
			int clients = 0;
			for (int i = 1; i <= MaxClients; i++)
			{	
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
				{
					clients++;
					GetClientAbsOrigin(i, PlayerPos);
					float distance = GetVectorDistance(WitchPos, PlayerPos);
					LogCommand("#DEBUG: Distance from the witch = %f; Max distance = %f", distance, g_fWitchDistance);
					if (distance > g_fWitchDistance)
					{
						k++;
					}
				}
			}
			if (k == clients)
			{
				AcceptEntityInput(index, "Kill");
				countalive--;
			}
		}
	}
	LogCommand("#DEBUG: Alive witches = %d, Max count alive witches = %d", countalive, g_iCountWitchAlive);
	return countalive;
}

void CheatCommand(int client, char[] command, char[] argument = "")
{
	if (client)
	{
		int userFlags = GetUserFlagBits(client);
		SetUserFlagBits(client, ADMFLAG_ROOT);
		int flags = GetCommandFlags(command);
		SetCommandFlags(command, flags & ~FCVAR_CHEAT);
		FakeClientCommand(client, "%s %s", command, argument);
		SetCommandFlags(command, flags);
		SetUserFlagBits(client, userFlags);
	}
}

Action SpawnAWitch(Handle timer)
{
	if (g_bRunTimer)
	{
		if (g_iCountWitchInRound > 0 && g_iCountWitch >= g_iCountWitchInRound)
		{
			LogCommand("#DEBUG: Witch = %d, Max count witch = %d; End_Timer()", g_iCountWitch, g_iCountWitchInRound);
			End_Timer(true);
			return Plugin_Continue;
		}
		if (g_iCountWitchAlive > 0 && g_iCountWitch >= g_iCountWitchAlive && GetCountAliveWitches() >= g_iCountWitchAlive)
		{
			Start_Timer();
			return Plugin_Continue;
		}
		int anyclient = GetAnyClient();
		if (anyclient == 0)
		{
			anyclient = CreateFakeClient("Bot");
			if (anyclient == 0)
			{
				LogCommand("#DEBUG: Anyclient = 0");
				Start_Timer();
				return Plugin_Continue;
			}
		}
		g_bWitchExec = true;
		if (g_bL4D2)
		{
			CheatCommand(anyclient, "z_spawn_old", "witch auto");
		}
		else
		{
			CheatCommand(anyclient, "z_spawn", "witch auto");
		}
		LogCommand("#DEBUG: Revival attempt with the plugin");
		g_bWitchExec = false;
		Start_Timer();
	}
	return Plugin_Stop;
}

void LogCommand(const char[] format, any ...)
{
	if(!g_bDebugLog)
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