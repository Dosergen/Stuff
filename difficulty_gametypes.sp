/*
	Prevent client to create game on "easy" and "normal" difficulties.
	Prevent client using mm_dedicated_force_servers to override sv_gametypes on server.
	If mp_gamemode from lobby is not included in sv_gametypes, reject client connection.
	If sv_gametypes is not set in your server.cfg file, it should default to:
	coop,realism,survival,versus,scavenge,dash,holdout,shootzones
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.3"

ConVar g_hCvarMPGameMode;
ConVar g_hCvarDifficulty;

char g_sGameMode[32];
char g_sGameTypes[1024];
char g_sGameType[32][32];
char g_sGameDifficulty[32];
char g_sAllowedGameType[32];

bool g_bAvDiff;
bool g_bTooEasy;
bool g_bChgLvlFlg;
bool g_bLeft4Dead2;

public Plugin myinfo =
{
	name = "[L4D/2] Difficulty Gametypes",
	author = "Distemper, Mystik Spiral, Dosergen",
	description = "Enforce difficulty and sv_gametypes modes",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=342570"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d_difficulty_gametypes_version", PLUGIN_VERSION, "Difficulty Gametypes plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hCvarMPGameMode = FindConVar("mp_gamemode");

	g_hCvarDifficulty = FindConVar("z_difficulty");
	g_hCvarDifficulty.AddChangeHook(OnDifficultyChange);
	
	HookEvent("player_activate", Event_PlayerActivate);
}

public void OnMapStart()
{
	g_bChgLvlFlg = false;
	g_bTooEasy = false;
	if (IsTooEasy() && !L4D_LobbyIsReserved())
	{
		g_bTooEasy = true;
		MakeItHard();
	}
}  

void Event_PlayerActivate(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	// Print a helpful message if the difficulty was forcibly changed at the beginning of the map.
	if (g_bTooEasy)
	{	
		PrintToChat(client, "\x04[DGT] \x03This is an advanced server designed for experts. The difficulty level has been changed back to advanced.");
	}
}

void OnDifficultyChange(ConVar convar, char[] oldValue, char[] newValue)
{
	// Check if any human players are on the server which suggests the difficulty was voted down.
	if (AnyHumanPlayers() && IsTooEasy())
	{
		MakeItHard();
		PrintToChatAll("\x04[DGT] \x03This is an advanced server designed for experts. The difficulty level has been changed back to advanced.");
	}
}

void MakeItHard()
{
	PrintToServer("[DGT] Setting difficulty to advanced.");
	g_hCvarDifficulty.SetString("Hard");
}

bool IsGameMode()
{
	g_hCvarMPGameMode.GetString(g_sGameMode, sizeof(g_sGameMode));
	return strcmp(g_sGameMode, "coop", false) == 0 || strcmp(g_sGameMode, "realism", false) == 0;
}

bool IsTooEasy()
{
	g_hCvarDifficulty.GetString(g_sGameDifficulty, sizeof(g_sGameDifficulty));
	g_bAvDiff = strcmp(g_sGameDifficulty, "Easy", false) == 0 || strcmp(g_sGameDifficulty, "Normal", false) == 0;
	return IsGameMode() && g_bAvDiff;
}

bool AnyHumanPlayers()
{
	for (int i = 1; i <= MaxClients; i++)
	{	
		if (IsClientInGame(i) && !IsFakeClient(i))
		{	
			return true;
		}
	}
	return false;
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlength)
{
	// Ignore bot connections
	if (IsFakeClient(client))
	{
		return true;
	}
	// Reject connections if difficulty "easy" or "normal"	
	if (g_bAvDiff && IsGameMode())
	{
		if (!g_bChgLvlFlg)
		{
			g_bChgLvlFlg = true;
			CreateTimer(1.0, ChangeLevel, client);
		}
		strcopy(rejectmsg, maxlength, "Server does not support this difficulty");
		return false;
	}
	// Reject connections if changelevel already in progress
	if (g_bChgLvlFlg)
	{
		strcopy(rejectmsg, maxlength, "Server does not support this gamemode");
		return false;
	}
	// Assign variables
	GetConVarString(FindConVar("mp_gamemode"), g_sGameMode, sizeof(g_sGameMode));
	GetConVarString(FindConVar("sv_gametypes"), g_sGameTypes, sizeof(g_sGameTypes));
	ExplodeString(g_sGameTypes, ",", g_sGameType, sizeof(g_sGameType), sizeof(g_sGameType[]));
	g_sAllowedGameType = g_sGameType[0];
	// Loop through game type values from sv_gametypes
	for (int iNdex = 0; iNdex < sizeof(g_sGameType); iNdex++)
	{
		TrimString(g_sGameType[iNdex]);
		PrintToServer("[DGT] %i - %s / %s", iNdex, g_sGameType[iNdex], g_sGameMode);
		// mp_gamemode matches one of the values in sv_gametypes, allow connection
		if (strcmp(g_sGameType[iNdex], g_sGameMode, false) == 0)
		{
			return true;
		}
		// mp_gamemode does not match any value in sv_gametypes, reject connection
		if (strlen(g_sGameType[iNdex]) == 0)
		{
			// If changelevel flag not already set, then changelevel to reset mp_gamemode
			if (!g_bChgLvlFlg)
			{
				g_bChgLvlFlg = true;
				CreateTimer(1.0, ChangeLevel, client);
			}
			strcopy(rejectmsg, maxlength, "Server does not support this gamemode");
			return false;
		}
	}
	return true;
}

public Action ChangeLevel(Handle timer, int client)
{
	// Need to turn off hibernate so changelevel completes (should be reset from server.cfg)
	ServerCommand("sm_cvar mp_gamemode %s; sm_cvar sv_hibernate_when_empty 0", g_sAllowedGameType);
	if (g_bLeft4Dead2)
	{
		ServerCommand("changelevel c8m5_rooftop");
	}
	else
	{
		ServerCommand("changelevel l4d_hospital05_rooftop");
	}
	return Plugin_Continue;
}