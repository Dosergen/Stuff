/*
    Prevent client from creating game on "easy" and "normal" difficulties.
    Forced setting of «advanced» difficulty level in the game.
    Prevent client from using mm_dedicated_force_servers to override sv_gametypes on the server.
    If mp_gamemode from the lobby is not included in sv_gametypes, reject the client connection.
    If sv_gametypes is not set in your server.cfg file, it should default to:
    coop, realism, survival, versus, scavenge, dash, holdout, shootzones
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.7.2"
#define DIFFICULTY_EASY "easy"
#define DIFFICULTY_NORMAL "normal"
#define DIFFICULTY_ADVANCED "hard"

ConVar g_hCvarMPGameMode;
ConVar g_hCvarSVGameTypes;
ConVar g_hCvarDifficulty;

char g_sGameMode[32];
char g_sGameTypes[1024];
char g_sGameType[32][32];
char g_sGameDifficulty[32];
char g_sAllowedGameType[32];

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
	CreateConVar("l4d_difficulty_gametypes_version", PLUGIN_VERSION, "Difficulty Gametypes plugin version.", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarSVGameTypes = FindConVar("sv_gametypes");
	g_hCvarDifficulty = FindConVar("z_difficulty");
	g_hCvarDifficulty.AddChangeHook(OnDifficultyChange);

	HookEvent("player_activate", EvtPlayerActivate);
}

void OnDifficultyChange(ConVar convar, const char[] oldValue, const char[] newValue) 
{
	if (AnyHumanPlayers() && IsTooEasy()) 
	{
		UpdateDifficulty();
		PrintToChatAll("\x04[DGT] \x03Difficulty level has been changed to advanced.");
	}
}

void EvtPlayerActivate(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (g_bTooEasy) 
	{
		PrintToChat(client, "\x04[DGT] \x03Difficulty level has been changed to advanced.");
	}
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

bool IsTooEasy()
{
	g_hCvarDifficulty.GetString(g_sGameDifficulty, sizeof(g_sGameDifficulty));
	bool g_bAvDiff = (strcmp(g_sGameDifficulty, DIFFICULTY_EASY, false) == 0 || strcmp(g_sGameDifficulty, DIFFICULTY_NORMAL, false) == 0);
	return g_bAvDiff;
}

void UpdateDifficulty()
{
	PrintToServer("[DGT] Setting difficulty to advanced.");
	g_hCvarDifficulty.SetString(DIFFICULTY_ADVANCED);
}

public void OnMapStart() 
{
	g_bTooEasy = IsTooEasy();
	if (g_bTooEasy) 
	{
		UpdateDifficulty();
	}
	g_hCvarMPGameMode.GetString(g_sGameMode, sizeof(g_sGameMode));
	g_hCvarSVGameTypes.GetString(g_sGameTypes, sizeof(g_sGameTypes));
	ExplodeString(g_sGameTypes, ",", g_sGameType, sizeof(g_sGameType), sizeof(g_sGameType[]));
	g_sAllowedGameType = g_sGameType[0];
	for (int iNdex = 0; iNdex < sizeof(g_sGameType); iNdex++)
	{
		TrimString(g_sGameType[iNdex]);
		if (strcmp(g_sGameType[iNdex], g_sGameMode, false) == 0)
		{
			g_bChgLvlFlg = false;
			break;
		}
		if (strlen(g_sGameType[iNdex]) == 0)
		{
			if (!g_bChgLvlFlg)
			{
				g_bChgLvlFlg = true;
				CreateTimer(1.0, ChangeLevel);
			}
		}
	}
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlength)
{
	if (IsFakeClient(client))
	{
		return true;
	}
	if (IsTooEasy() || g_bChgLvlFlg)
	{
		ServerCommand("sm_cvar sv_hibernate_when_empty 0; sm_cvar %s 1", g_bLeft4Dead2 ? "sb_all_bot_game" : "sb_all_bot_team");
		strcopy(rejectmsg, maxlength, "Server does not support this Gamemode");
		return false;
	}
	return true;
}

Action ChangeLevel(Handle timer) 
{
	ServerCommand("sm_cvar mp_gamemode %s", g_sAllowedGameType);
	ServerCommand("changelevel %s", g_bLeft4Dead2 ? "c8m5_rooftop" : "l4d_hospital05_rooftop");
	return Plugin_Continue;
}