/**
 *   COMMANDS:
 *
 *    sm_spc <hours|bans|level> add <STEAMID64> - Adding a player to the whitelist. For example: !spc hours add XXXXXXXXXXXXXXXXX
 *    sm_spc <hours|bans|level> remove <STEAMID64> - Removing a player from the whitelist. For example: !spc bans remove XXXXXXXXXXXXXXXXX
 *    sm_spc <hours|bans|level> check <STEAMID64> - Checking if a player is in the whitelist. For example: !spc level check XXXXXXXXXXXXXXXXX
 *    sm_spc whitelist - Whitelist Menu
 *
 *   https://developer.valvesoftware.com/wiki/Steam_Web_API
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <regex>
#include <multicolors>
#include <steamworks>

#define PLUGIN_VERSION "1.3"

ConVar g_hCvarEnable, g_hCvarApiKey, g_hCvarDatabase, g_hCvarEnableHourCheck, g_hCvarMinHours, g_hCvarHoursWhitelistEnable, 
       g_hCvarHoursWhitelistAuto, g_hCvarEnableBanDetection, g_hCvarBansWhitelist, g_hCvarVACDays, g_hCvarVACAmount, 
       g_hCvarCommunityBan, g_hCvarGameBans, g_hCvarEconomyBan, g_hCvarEnableLevelCheck, g_hCvarLevelWhitelistEnable, 
       g_hCvarLevelWhitelistAuto, g_hCvarMinLevel, g_hCvarMaxLevel, g_hCvarEnablePrivateCheck;

bool   g_bEnable, g_bEnableHourCheck, g_bHoursWhitelistEnable, g_bHoursWhitelistAuto, g_bEnableBanDetection, g_bBansWhitelist, 
       g_bCommunityBan, g_bEnableLevelCheck, g_bLevelWhitelistEnable, g_bLevelWhitelistAuto, g_bEnablePrivateCheck, g_bIsLite;

int g_iminHours, g_ivacDays, g_ivacAmount, g_igameBans, g_ieconomyBan, g_iMinLevel, g_iMaxLevel;
static char g_sAPIKey[64], g_sDatabase[64], g_sEcBan[10];
static int c = 3;
Database g_hDatabase;

public Plugin myinfo = 
{
	name = "[ANY] Steam Profile Checker",
	author = "StevoTVR, ratawar, Dosergen", 
	description = "Checking players' steam profiles against criteria.",
	version = PLUGIN_VERSION, 
	url = "https://forums.alliedmods.net/showthread.php?t=80942"
}

public void OnPluginStart() 
{
	CreateConVar("sm_steamprocheck_version", PLUGIN_VERSION, "Plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_hCvarEnable                 = CreateConVar("sm_steamprocheck_enable", "1", "Enable the plugin?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarApiKey                 = CreateConVar("sm_steamprocheck_apikey", "", "Your Steam API key (https://steamcommunity.com/dev/apikey)", FCVAR_PROTECTED);
	g_hCvarDatabase               = CreateConVar("sm_steamprocheck_database", "storage-local", "This value can only be changed if you are using a different set of databases in the databases.cfg file.");
	g_hCvarEnableHourCheck        = CreateConVar("sm_steamprocheck_hours_enable", "1", "Enable Hour Checking functions?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarMinHours               = CreateConVar("sm_steamprocheck_hours_minhours", "100", "Minimum of hours required to enter the server.");
	g_hCvarHoursWhitelistEnable   = CreateConVar("sm_steamprocheck_hours_whitelist_enable", "1", "Enable Hours Check Whitelist?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarHoursWhitelistAuto     = CreateConVar("sm_steamprocheck_hours_whitelist_auto", "0", "Whitelist members that have been checked automatically?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarEnableBanDetection     = CreateConVar("sm_steamprocheck_bans_enable", "1", "Enable Ban Checking functions?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarBansWhitelist          = CreateConVar("sm_steamprocheck_bans_whitelist", "1", "Enable Bans Whitelist?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarVACDays                = CreateConVar("sm_steamprocheck_vac_days", "0", "Minimum days since the last VAC ban to be allowed into the server (0 for zero tolerance).");
	g_hCvarVACAmount              = CreateConVar("sm_steamprocheck_vac_amount", "0", "Amount of VAC bans tolerated until prohibition (0 for zero tolerance).");
	g_hCvarCommunityBan           = CreateConVar("sm_steamprocheck_community_ban", "0", "0: Don't kick if there's a community ban | 1: Kick if there's a community ban", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarGameBans               = CreateConVar("sm_steamprocheck_game_bans", "5", "Amount of game bans tolerated until prohibition (0 for zero tolerance).");
	g_hCvarEconomyBan             = CreateConVar("sm_steamprocheck_economy_bans", "0", "0: Don't check for economy bans | 1: Kick if user is economy \"banned\" only. | 2: Kick if user is in either \"banned\" or \"probation\" state.", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_hCvarEnableLevelCheck       = CreateConVar("sm_steamprocheck_level_enable", "1", "Enable Steam Level Checking functions", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarLevelWhitelistEnable   = CreateConVar("sm_steamprocheck_level_whitelist_enable", "1", "Enable Steam Level Check Whitelist?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarLevelWhitelistAuto     = CreateConVar("sm_steamprocheck_level_whitelist_auto", "0", "Whitelist members that have been checked automatically?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarMinLevel               = CreateConVar("sm_steamprocheck_minlevel", "5", "Minimum required level to enter the server.");
	g_hCvarMaxLevel               = CreateConVar("sm_steamprocheck_maxlevel", "", "Maximum level allowed to enter the server.");
	g_hCvarEnablePrivateCheck     = CreateConVar("sm_steamprocheck_private_enable", "1", "Block Private Profiles Completely?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	GetCvars();
	g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarApiKey.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDatabase.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarEnableHourCheck.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarMinHours.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHoursWhitelistEnable.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHoursWhitelistAuto.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarEnableBanDetection.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarBansWhitelist.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarVACDays.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarVACAmount.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarCommunityBan.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarGameBans.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarEconomyBan.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarEnableLevelCheck.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarLevelWhitelistEnable.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarLevelWhitelistAuto.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarMinLevel.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarMaxLevel.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarEnablePrivateCheck.AddChangeHook(ConVarChanged_Cvars);

	RegAdminCmd("sm_spc", SteamProCheck, ADMFLAG_BAN, "Steam Profile Checker");

	LoadTranslations("steamprocheck.phrases");
	AutoExecConfig(true, "steamprocheck");
}

public void OnConfigsExecuted() 
{
	if (!g_bEnable)
		SetFailState("[SPC] Plugin disabled!");
	if (!IsAPIKeyCorrect(g_sAPIKey))
		SetFailState("[SPC] Please set your Steam API Key properly!");
	if (g_bHoursWhitelistEnable || g_bBansWhitelist || g_bLevelWhitelistEnable)
		Database.Connect(SQL_ConnectDatabase, g_sDatabase);
	else
		PrintToServer("[SPC] No usage of database detected! Aborting database connection.");
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bEnable = g_hCvarEnable.BoolValue;
	g_hCvarApiKey.GetString(g_sAPIKey, sizeof(g_sAPIKey));
	g_hCvarDatabase.GetString(g_sDatabase, sizeof(g_sDatabase));
	g_bEnableHourCheck = g_hCvarEnableHourCheck.BoolValue;
	g_iminHours = g_hCvarMinHours.IntValue;
	g_bHoursWhitelistEnable = g_hCvarHoursWhitelistEnable.BoolValue;
	g_bHoursWhitelistAuto = g_hCvarHoursWhitelistAuto.BoolValue;
	g_bEnableBanDetection = g_hCvarEnableBanDetection.BoolValue;
	g_bBansWhitelist = g_hCvarBansWhitelist.BoolValue;
	g_ivacDays = g_hCvarVACDays.IntValue;
	g_ivacAmount = g_hCvarVACAmount.IntValue;
	g_bCommunityBan = g_hCvarCommunityBan.BoolValue;	
	g_igameBans = g_hCvarGameBans.IntValue;
	g_ieconomyBan = g_hCvarEconomyBan.IntValue;
	g_bEnableLevelCheck = g_hCvarEnableLevelCheck.BoolValue;	
	g_bLevelWhitelistEnable = g_hCvarLevelWhitelistEnable.BoolValue;	
	g_bLevelWhitelistAuto = g_hCvarLevelWhitelistAuto.BoolValue;
	g_iMinLevel = g_hCvarMinLevel.IntValue;
	g_iMaxLevel = g_hCvarMaxLevel.IntValue;
	g_bEnablePrivateCheck = g_hCvarEnablePrivateCheck.BoolValue;
}

public void SQL_ConnectDatabase(Database db, const char[] error, any data)
{
	if (db == null) 
	{
		LogError("[SPC] Could not connect to database %s! Error: %s", g_sDatabase, error);
		PrintToServer("[SPC] Could not connect to database %s! Error: %s", g_sDatabase, error);
		return;
	}
	PrintToServer("[SPC] Database connection to \"%s\" successful!", g_sDatabase);
	g_hDatabase = db;
	GetDriver();
	CreateTable();
}

void GetDriver() 
{
	char driver[16];
	SQL_ReadDriver(g_hDatabase, driver, sizeof(driver));
	g_bIsLite = strcmp(driver, "sqlite") == 0 ? true : false;
}

void CreateTable() 
{
	const int querySize = 256;
	char sQuery1[querySize];
	char sQuery2[querySize];
	char sQuery3[querySize];
	if (g_bIsLite) 
	{
		TableQuery(sQuery1, querySize, "spc_whitelist", true);
		TableQuery(sQuery2, querySize, "spc_whitelist_bans", true);
		TableQuery(sQuery3, querySize, "spc_whitelist_level", true);
	} 
	else 
	{
		TableQuery(sQuery1, querySize, "spc_whitelist", false);
		TableQuery(sQuery2, querySize, "spc_whitelist_bans", false);
		TableQuery(sQuery3, querySize, "spc_whitelist_level", false);
	}
	g_hDatabase.Query(SQL_CreateTable, sQuery1);
	g_hDatabase.Query(SQL_CreateTable, sQuery2);
	g_hDatabase.Query(SQL_CreateTable, sQuery3);    
}

void TableQuery(char[] query, int querySize, const char[] tableName, bool isLite)
{
	Format(query, querySize, "CREATE TABLE IF NOT EXISTS %s(", tableName);
	if (isLite)
	{
		StrCat(query, querySize, "entry INTEGER PRIMARY KEY, ");
		StrCat(query, querySize, "steamid VARCHAR(17), ");
		StrCat(query, querySize, "unique (steamid));");
	}
	else
	{
		StrCat(query, querySize, "entry INT NOT NULL AUTO_INCREMENT, ");
		StrCat(query, querySize, "steamid VARCHAR(17) UNIQUE, ");
		StrCat(query, querySize, "PRIMARY KEY (entry));");
	}
}

public void SQL_CreateTable(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null || results == null)
	{
		LogError("[SPC] Create Table Query failure! %s", error);
		PrintToServer("[SPC] Create Table Query failure! %s", error);
		return;
	}
	c--;
	if (!c) PrintToServer("[SPC] Tables successfully created or were already created!");
}

void QueryHoursWhitelist(int client, char[] auth) 
{
	char WhitelistReadQuery[512];
	Format(WhitelistReadQuery, sizeof(WhitelistReadQuery), "SELECT * FROM spc_whitelist WHERE steamid='%s';", auth);
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	pack.WriteCell(GetClientUserId(client));
	g_hDatabase.Query(SQL_QueryHoursWhitelist, WhitelistReadQuery, pack);
}

public void SQL_QueryHoursWhitelist(Database db, DBResultSet results, const char[] error, DataPack pack) 
{
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	int client = GetClientOfUserId(pack.ReadCell());
	delete pack;
	if (!client)
		return;
	if (db == null || results == null) 
	{
		LogError("[SPC] Error while checking if user %s is hour whitelisted! %s", auth, error);
		PrintToServer("[SPC] Error while checking if user %s is hour whitelisted! %s", auth, error);
		return;
	}
	if (!results.RowCount) 
	{
		RequestHours(client, auth);
		return;
	}
}

void RequestHours(int client, char[] auth) 
{
	char URL[512];
	Format(URL, sizeof(URL), "http://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key=%s&include_played_free_games=1&appids_filter[0]=%i&steamid=%s&format=json", g_sAPIKey, GetAppID(), auth);
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, URL);
	SteamWorks_SetHTTPRequestContextValue(request, GetClientUserId(client));
	SteamWorks_SetHTTPCallbacks(request, RequestHours_OnHTTPResponse);
	SteamWorks_SendHTTPRequest(request);
}

void RequestHours_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int userid) 
{
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK) 
	{
		PrintToServer("[SPC] HTTP Hours Request failure!");
		delete request;
		return;
	}
	int client = GetClientOfUserId(userid);
	if (!client) 
	{
		delete request;
		return;
	}
	int bufferSize;
	SteamWorks_GetHTTPResponseBodySize(request, bufferSize);
	char[] responseBody = new char[bufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, responseBody, bufferSize);
	delete request;
	if (!g_bEnableHourCheck) return;
	int playedTime = GetPlayerHours(responseBody);
	int totalPlayedTime = playedTime / 60;
	if (totalPlayedTime == 0)
	{
		KickClient(client, "%t", "Invisible Hours");
		return;
	}
	if (g_iminHours != 0 && totalPlayedTime < g_iminHours)
	{
		KickClient(client, "%t", "Not Enough Hours", totalPlayedTime, g_iminHours);
		return;
	}
	if (g_bHoursWhitelistAuto)
	{
		char auth[40];
		GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
		AddPlayerToHoursWhitelist(auth);
	}
}

void AddPlayerToHoursWhitelist(char[] auth) 
{
	char WhitelistWriteQuery[512];
	Format(WhitelistWriteQuery, sizeof(WhitelistWriteQuery), "INSERT INTO spc_whitelist (steamid) VALUES (%s);", auth);
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	g_hDatabase.Query(SQL_AddPlayerToHoursWhitelist, WhitelistWriteQuery, pack);
}

public void SQL_AddPlayerToHoursWhitelist(Database db, DBResultSet results, const char[] error, DataPack pack) 
{
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	delete pack;
	if (db == null || results == null) 
	{
		LogError("[SPC] Error while trying to hour whitelist user %s! %s", auth, error);
		PrintToServer("[SPC] Error while trying to hour whitelist user %s! %s", auth, error);
		return;
	}
	PrintToServer("[SPC] Player %s successfully hour whitelisted!", auth);
}

void QueryBansWhitelist(int client, char[] auth) 
{
	char BansWhitelistQuery[256];
	Format(BansWhitelistQuery, sizeof(BansWhitelistQuery), "SELECT * FROM spc_whitelist_bans WHERE steamid='%s'", auth);
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	pack.WriteCell(GetClientUserId(client));
	g_hDatabase.Query(SQL_QueryBansWhitelist, BansWhitelistQuery, pack);
}

public void SQL_QueryBansWhitelist(Database db, DBResultSet results, const char[] error, DataPack pack) 
{
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	int client = GetClientOfUserId(pack.ReadCell());
	delete pack;
	if (!client)
		return;
	if (db == null || results == null) 
	{
		LogError("[SPC] Error while checking if user %s is ban whitelisted! %s", auth, error);
		PrintToServer("[SPC] Error while checking if user %s is ban whitelisted! %s", auth, error);
		return;
	}
	if (!results.RowCount) 
	{
		RequestBans(client, auth);
		return;
	}
	PrintToServer("[SPC] User %s is ban whitelisted! Skipping ban check.", auth);
}

void RequestBans(int client, char[] auth) 
{
	char URL[512];
	Format(URL, sizeof(URL), "http://api.steampowered.com/ISteamUser/GetPlayerBans/v1?key=%s&steamids=%s", g_sAPIKey, auth);
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, URL);
	SteamWorks_SetHTTPRequestContextValue(request, GetClientUserId(client));
	SteamWorks_SetHTTPCallbacks(request, RequestBans_OnHTTPResponse);
	SteamWorks_SendHTTPRequest(request);
}

void RequestBans_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int userid)
{
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		PrintToServer("[SPC] HTTP Bans Request failure!");
		delete request;
		return;
	}
	int client = GetClientOfUserId(userid);
	if (!client)
	{
		delete request;
		return;
	}
	int bufferSize;
	SteamWorks_GetHTTPResponseBodySize(request, bufferSize);
	char[] responseBodyBans = new char[bufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, responseBodyBans, bufferSize);
	delete request;
	if (!g_bEnableBanDetection)
		return;
	bool vacBanned = IsVACBanned(responseBodyBans);
	int daysSinceLastVAC = GetDaysSinceLastVAC(responseBodyBans);
	int vacAmount = GetVACAmount(responseBodyBans);
	if (vacBanned)
	{
		if (g_ivacDays == 0 || g_ivacAmount == 0)
		{
			KickClient(client, "%t", "VAC Kicked");
			return;
		}
		if (daysSinceLastVAC < g_ivacDays)
		{
			KickClient(client, "%t", "VAC Kicked Days", g_ivacDays);
			return;
		}
		if (vacAmount > g_ivacAmount)
		{
			KickClient(client, "%t", "VAC Kicked Amount", g_ivacAmount);
			return;
		}
	}
	bool commBanned = IsCommunityBanned(responseBodyBans);
	int gameBanned = GetGameBans(responseBodyBans);
	if (commBanned && g_bCommunityBan)
	{
		KickClient(client, "%t", "Community Ban Kicked");
		return;
	}
	if (gameBanned > g_igameBans)
	{
		KickClient(client, "%t", "Game Bans Exceeded", g_igameBans);
		return;
	}
	GetEconomyBans(responseBodyBans, g_sEcBan);
	bool econBanned = StrContains(g_sEcBan, "banned", false) != -1;
	bool econProbation = StrContains(g_sEcBan, "probation", false) != -1;
	if (g_ieconomyBan == 1 && econBanned)
	{
		KickClient(client, "%t", "Economy Ban Kicked");
		return;
	}
	if (g_ieconomyBan == 2 && (econBanned || econProbation))
	{
		KickClient(client, "%t", "Economy Ban/Prob Kicked");
		return;
	}
}

void QueryLevelWhitelist(int client, char[] auth) 
{
	char LevelWhitelistQuery[256];
	Format(LevelWhitelistQuery, sizeof(LevelWhitelistQuery), "SELECT * FROM spc_whitelist_level WHERE steamid='%s'", auth);
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	pack.WriteCell(GetClientUserId(client));
	g_hDatabase.Query(SQL_QueryLevelWhitelist, LevelWhitelistQuery, pack);
}

public void SQL_QueryLevelWhitelist(Database db, DBResultSet results, const char[] error, DataPack pack) 
{
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	int client = GetClientOfUserId(pack.ReadCell());
	delete pack;
	if (!client)
		return;
	if (db == null || results == null) 
	{
		LogError("[SPC] Error while checking if user %s is level whitelisted! %s", auth, error);
		PrintToServer("[SPC] Error while checking if user %s is level whitelisted! %s", auth, error);
		return;
	}
	if (!results.RowCount) 
	{
		RequestLevel(client, auth);
		return;
	}
	PrintToServer("[SPC] User %s is level whitelisted! Skipping level check.", auth);
}

void RequestLevel(int client, char[] auth) 
{
	char URL[512];
	Format(URL, sizeof(URL), "http://api.steampowered.com/IPlayerService/GetSteamLevel/v1/?key=%s&steamid=%s", g_sAPIKey, auth);
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, URL);
	SteamWorks_SetHTTPRequestContextValue(request, GetClientUserId(client));
	SteamWorks_SetHTTPCallbacks(request, RequestLevel_OnHTTPResponse);
	SteamWorks_SendHTTPRequest(request);
}

void RequestLevel_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int userid) 
{
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK) 
	{
		PrintToServer("[SPC] HTTP Steam Level Request failure!");
		delete request;
		return;
	}
	int client = GetClientOfUserId(userid);
	if (!client) 
	{
		delete request;
		return;
	}
	int bufferSize;
	SteamWorks_GetHTTPResponseBodySize(request, bufferSize);
	char[] responseBodyLevel = new char[bufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, responseBodyLevel, bufferSize);
	delete request;
	if (!g_bEnableLevelCheck)
		return;
	int minlevel = g_iMinLevel;
	int maxlevel = g_iMaxLevel;
	int level = GetSteamLevel(responseBodyLevel);
	if (level == -1) 
	{
		KickClient(client, "%t", "Invisible Level");
		return;
	}
	else if (level < minlevel) 
	{
		KickClient(client, "%t", "Low Level", level, minlevel);
		return;
	}
	else if (maxlevel != 0 && level > maxlevel) 
	{
		KickClient(client, "%t", "High Level", level, maxlevel);
		return;
	}
	if (g_bLevelWhitelistAuto)
	{
		char auth[40];
		GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
		AddPlayerToLevelWhitelist(auth);
	}
}

void AddPlayerToLevelWhitelist(char[] auth) 
{
	char LevelWriteQuery[512];
	Format(LevelWriteQuery, sizeof(LevelWriteQuery), "INSERT INTO spc_whitelist_level (steamid) VALUES (%s);", auth);
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	g_hDatabase.Query(SQL_AddPlayerToLevelWhitelist, LevelWriteQuery, pack);
}

public void SQL_AddPlayerToLevelWhitelist(Database db, DBResultSet results, const char[] error, DataPack pack) 
{
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	delete pack;
	if (db == null || results == null)
	{
		LogError("[SPC] Error while trying to level whitelist user %s! %s", auth, error);
		PrintToServer("[SPC] Error while trying to level whitelist user %s! %s", auth, error);
		return;
	}
	PrintToServer("[SPC] Player %s successfully level whitelisted!", auth);
}

void CheckPrivateProfile(int client, char[] auth) 
{
	char URL[512];
	Format(URL, sizeof(URL), "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=%s&steamids=%s", g_sAPIKey, auth);
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, URL);
	SteamWorks_SetHTTPRequestContextValue(request, GetClientUserId(client));
	SteamWorks_SetHTTPCallbacks(request, RequestPrivate_OnHTTPResponse);
	SteamWorks_SendHTTPRequest(request);
}

void RequestPrivate_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int userid) 
{
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK) 
	{
		PrintToServer("[SPC] HTTP Steam Private Profile Request failure!");
		delete request;
		return;
	}
	int client = GetClientOfUserId(userid);
	if (!client) 
	{
		delete request;
		return;
	}
	int bufferSize;
	SteamWorks_GetHTTPResponseBodySize(request, bufferSize);
	char[] responseBodyPrivate = new char[bufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, responseBodyPrivate, bufferSize);
	delete request;
	if (!g_bEnablePrivateCheck)
		return;
	int commVisible = GetCommVisibState(responseBodyPrivate) == 1;
	if (commVisible)
	{
		KickClient(client, "%t", "No Private Profile");
		return;
	}
}

void OpenWhitelistMenu(int client) 
{
	Menu menu = new Menu(mPickWhitelist, MENU_ACTIONS_ALL);
	menu.AddItem("hoursTable", "Hours Whitelist");
	menu.AddItem("bansTable", "Bans Whitelist");
	menu.AddItem("levelTable", "Level Whitelist");
	menu.ExitButton = true;
	menu.Display(client, 20);
}

int mPickWhitelist(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action) 
	{
		case MenuAction_Display: 
		{
			char buffer[255];
			Format(buffer, sizeof(buffer), "%t", "Select a Table");
			Panel panel = view_as<Panel>(param2);
			panel.SetTitle(buffer);
		}
		case MenuAction_Select: 
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			MenuQuery(param1, info);
		}
		case MenuAction_End: 
		{
			delete menu;
		}
	}
	return 0;
}

void MenuQuery(int client, char[] info) 
{
	char table[32];
	if (StrEqual(info, "hoursTable", false))
		Format(table, sizeof(table), "spc_whitelist");
	if (StrEqual(info, "bansTable", false))
		Format(table, sizeof(table), "spc_whitelist_bans");
	if (StrEqual(info, "levelTable", false))
		Format(table, sizeof(table), "spc_whitelist_level");
	char query[256];
	g_hDatabase.Format(query, sizeof(query), "SELECT * FROM %s", table);
	DataPack pack = new DataPack();
	pack.WriteString(table);
	pack.WriteCell(GetClientUserId(client));
	g_hDatabase.Query(SQL_MenuQuery, query, pack);
}

public void SQL_MenuQuery(Database db, DBResultSet results, const char[] error, DataPack pack) 
{
	pack.Reset();
	char table[32];
	pack.ReadString(table, sizeof(table));
	int client = GetClientOfUserId(pack.ReadCell());
	delete pack;
	if (!client)
		return;
	if (db == null || results == null) 
	{
		LogError("[SPC] Error while querying %s for menu display! %s", table, error);
		PrintToServer("[SPC] Error while querying %s for menu display! %s", table, error);
		CPrintToChat(client, "[SPC] Error while querying %s for menu display! %s", table, error);
		return;
	}
	char type[16];
	if (StrEqual(table, "hoursTable", false))	
		Format(type, sizeof(type), "Hours");
	if (StrEqual(table, "bansTable", false))
		Format(type, sizeof(type), "Bans");
	if (StrEqual(table, "levelTable", false))
		Format(type, sizeof(type), "Level");
	int entryCol, steamidCol;
	results.FieldNameToNum("entry", entryCol);
	results.FieldNameToNum("steamid", steamidCol);
	Menu menu = new Menu(TablesMenu, MENU_ACTIONS_ALL);
	menu.SetTitle("Showing %s Whitelist", type);
	char steamid[32], id[16];
	int count;
	if (!results.FetchRow()) 
	{
		CPrintToChat(client, "%t", "No Results");
		OpenWhitelistMenu(client);
		return;
	} 
	else 
	{
		do 
		{
			count++;
			results.FetchString(steamidCol, steamid, sizeof(steamid));
			IntToString(count, id, sizeof(id));
			menu.AddItem(id, steamid, ITEMDRAW_RAWLINE);
		} 
		while (results.FetchRow());
		menu.ExitBackButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

int TablesMenu(Menu menu, MenuAction action, int param1, int param2) 
{
	switch (action) 
	{
		case MenuAction_Cancel: 
		{
			if (param2 == MenuCancel_ExitBack) 
			{
				OpenWhitelistMenu(param1);
				delete menu;
			}
		}
	}
	return 0;
}

Action SteamProCheck(int client, int args)
{
	char arg1[30], arg2[30], arg3[30];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	if (!client) 
	{	
		ReplyToCommand(client, "You cannot use plugin functionality from the console!");
		return Plugin_Handled;
	}
	if (StrEqual(arg1, "whitelist", false)) 
	{
		OpenWhitelistMenu(client);
		return Plugin_Handled;
	}
	if (!StrEqual(arg1, "hours", false) && !StrEqual(arg1, "bans", false) && !StrEqual(arg1, "level", false)) 
	{
		CReplyToCommand(client, "%t", "Command Usage");
		return Plugin_Handled;
	}
	if ((!StrEqual(arg2, "add", false) && !StrEqual(arg2, "remove", false) && !StrEqual(arg2, "check", false)) || StrEqual(arg3, "")) 
	{
		CReplyToCommand(client, "%t", "Command Usage");
		return Plugin_Handled;
	}
	if (!SimpleRegexMatch(arg3, "^7656119[0-9]{10}$")) 
	{
		CReplyToCommand(client, "%t", "Invalid STEAMID");
		return Plugin_Handled;
	}
	Command(arg1, arg2, arg3, client);
	return Plugin_Handled;
}

void Command(char[] arg1, char[] arg2, char[] arg3, int client) 
{
	char query[256], table[32];
	if (StrEqual(arg1, "hours", false))
		Format(table, sizeof(table), "spc_whitelist");
	if (StrEqual(arg1, "bans", false))
		Format(table, sizeof(table), "spc_whitelist_bans");
	if (StrEqual(arg1, "level", false))
		Format(table, sizeof(table), "spc_whitelist_level");
	if (StrEqual(arg2, "add"))
		Format(query, sizeof(query), "INSERT INTO %s (steamid) VALUES (%s);", table, arg3);
	if (StrEqual(arg2, "remove"))
		Format(query, sizeof(query), "DELETE FROM %s WHERE steamid='%s';", table, arg3);
	if (StrEqual(arg2, "check"))
		Format(query, sizeof(query), "SELECT * FROM %s WHERE steamid='%s';", table, arg3);
	DataPack pack = new DataPack();
	pack.WriteCell(client ? GetClientUserId(client) : client);
	pack.WriteString(arg1);
	pack.WriteString(arg2);
	pack.WriteString(arg3);
	g_hDatabase.Query(SQL_Command, query, pack);
}

public void SQL_Command(Database db, DBResultSet results, const char[] error, DataPack pack) 
{
	pack.Reset();
	int clientID = pack.ReadCell();
	int client = clientID ? GetClientOfUserId(clientID) : clientID;
	char arg1[30], arg2[30], arg3[30];
	pack.ReadString(arg1, sizeof(arg1));
	pack.ReadString(arg2, sizeof(arg2));
	pack.ReadString(arg3, sizeof(arg3));
	delete pack;
	if (StrEqual(arg2, "add", false)) 
	{
		if (db == null)
		{
			Error(client, "adding", arg1, arg3, error);
			return;
		}
		if (results == null)
		{
			Nothing(client, true, arg1, arg3);
			return;
		}
		Success(client, true, arg1, arg3);
	}
	else if (StrEqual(arg2, "remove", false)) 
	{
		if (db == null || results == null) 
		{
			Error(client, "removing", arg1, arg3, error);
			return;
		}
		if (!results.AffectedRows) 
		{
			Nothing(client, false, arg1, arg3);
			return;
		}
		Success(client, false, arg1, arg3);
	}
	else if (StrEqual(arg2, "check", false)) 
	{
		if (db == null || results == null)
		{
			Error(client, "issuing check command on", arg1, arg3, error);
			return;
		}
		Check(client, arg1, arg3, results.RowCount > 0);
	}
}

void Error(int client, const char[] action, const char[] arg1, const char[] arg3, const char[] error)
{
	LogError("[SPC] Error while %s %s to/from the %s whitelist! %s", action, arg3, arg1, error);
	PrintToServer("[SPC] Error while %s %s to/from the %s whitelist! %s", action, arg3, arg1, error);
	CReplyToCommand(client, "[SPC] Error while %s %s to/from the %s whitelist! %s", action, arg3, arg1, error);
}

void Nothing(int client, bool isAdding, const char[] arg1, const char[] arg3) 
{
	char message[64];
	if (StrEqual(arg1, "hours", false))
		Format(message, sizeof(message), isAdding ? "Nothing Hour Added" : "Nothing Hour Removed");
	else if (StrEqual(arg1, "bans", false))
		Format(message, sizeof(message), isAdding ? "Nothing Ban Added" : "Nothing Ban Removed");
	else if (StrEqual(arg1, "level", false))
		Format(message, sizeof(message), isAdding ? "Nothing Level Added" : "Nothing Level Removed");
	else
		return;
	CReplyToCommand(client, "%t", message, arg3);
}

void Success(int client, bool isAdding, const char[] arg1, const char[] arg3) 
{
	char message[64];
	if (StrEqual(arg1, "hours", false))
		Format(message, sizeof(message), isAdding ? "Successfully Hour Added" : "Successfully Hour Removed");
	else if (StrEqual(arg1, "bans", false))
		Format(message, sizeof(message), isAdding ? "Successfully Ban Added" : "Successfully Ban Removed");
	else if (StrEqual(arg1, "level", false))
		Format(message, sizeof(message), isAdding ? "Successfully Level Added" : "Successfully Level Removed");
	else
		return;
	CReplyToCommand(client, "%t", message, arg3);
}

void Check(int client, const char[] arg1, const char[] arg3, bool isWhitelisted) 
{
	char message[64];
	if (StrEqual(arg1, "hours", false))
		Format(message, sizeof(message), isWhitelisted ? "Hour Check Whitelisted" : "Hour Check Not Whitelisted");
	else if (StrEqual(arg1, "bans", false))
		Format(message, sizeof(message), isWhitelisted ? "Ban Check Whitelisted" : "Ban Check Not Whitelisted");
	else if (StrEqual(arg1, "level", false))
		Format(message, sizeof(message), isWhitelisted ? "Level Check Whitelisted" : "Level Check Not Whitelisted");
	else
		return;
	CReplyToCommand(client, "%t", message, arg3);
}

public void OnClientAuthorized(int client)
{
	if (IsFakeClient(client) || !g_hDatabase)
		return;
	char auth[40];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
	if (g_bEnableHourCheck)
	{
		if (g_bHoursWhitelistEnable)
			QueryHoursWhitelist(client, auth);
		else
			RequestHours(client, auth);
	}
	if (g_bEnableBanDetection)
	{
		if (g_bBansWhitelist)
			QueryBansWhitelist(client, auth);
		else
			RequestBans(client, auth);
	}
	if (g_bEnableLevelCheck)
	{
		if (g_bLevelWhitelistEnable)
			QueryLevelWhitelist(client, auth);
		else
			RequestLevel(client, auth);
	}
	if (g_bEnablePrivateCheck)
		CheckPrivateProfile(client, auth);
}

stock int GetAppID()
{
	char buffer[16];
	if (GetSteamINFData().GetString("appID", buffer, sizeof(buffer)))
		return StringToInt(buffer);
	return 0;
}

static stock StringMap GetSteamINFData()
{
	static StringMap s_VersionInfo;
	if (!s_VersionInfo)
	{
		s_VersionInfo = new StringMap();
		File hSteam = OpenFile("steam.inf", "r");
		char buffer[32];
		while (hSteam.ReadLine(buffer, sizeof(buffer)))
		{
			int assign = FindCharInString(buffer, '=');
			if (assign != -1)
			{
				char[] key = new char[assign + 1];
				strcopy(key, assign + 1, buffer);
				s_VersionInfo.SetString(key, buffer[assign + 1]);
			}
		}
		delete hSteam;
	}
	return s_VersionInfo;
}

stock bool IsAPIKeyCorrect(char[] cAPIKey) 
{
	return (cAPIKey[0] == '\0' || !SimpleRegexMatch(cAPIKey, "^[0-9A-Z]*$")) ? false : true;
}

stock int GetPlayerHours(const char[] responseBody)
{
	char str[8][64];
	ExplodeString(responseBody, ",", str, sizeof(str), sizeof(str[]));
	for (int i = 0; i < 8; i++)
	{
		if (StrContains(str[i], "playtime_forever") != -1)
		{
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			return StringToInt(str2[1]);
		}
	}
	return -1;
}

stock bool IsVACBanned(const char[] responseBodyBans)
{
	char str[10][64];
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	for (int i = 0; i < 7; i++)
	{
		if (StrContains(str[i], "VACBanned") != -1)
		{
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			return (StrEqual(str2[1], "false")) ? false : true;
		}
	}
	return false;
}

stock int GetDaysSinceLastVAC(const char[] responseBodyBans)
{
	char str[7][64];
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	for (int i = 0; i < 7; i++)
	{
		if (StrContains(str[i], "DaysSinceLastBan") != -1)
		{
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			return StringToInt(str2[1]);
		}
	}
	return -1;
}

stock int GetVACAmount(const char[] responseBodyBans)
{
	char str[7][64];
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	for (int i = 0; i < 7; i++)
	{
		if (StrContains(str[i], "NumberOfVACBans") != -1)
		{
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			return StringToInt(str2[1]);
		}
	}
	return -1;
}

stock bool IsCommunityBanned(const char[] responseBodyBans)
{
	char str[10][64];
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	for (int i = 0; i < 7; i++)
	{
		if (StrContains(str[i], "CommunityBanned") != -1)
		{
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			return (StrEqual(str2[1], "false")) ? false : true;
		}
	}
	return false;
}

stock int GetGameBans(char[] responseBodyBans)
{
	char str[7][64];
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	for (int i = 0; i < 7; i++)
	{
		if (StrContains(str[i], "NumberOfGameBans") != -1)
		{
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			return StringToInt(str2[1]);
		}
	}
	return -1;
}

stock void GetEconomyBans(const char[] responseBodyBans, char[] EcBan)
{
	char str[7][64];
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	for (int i = 0; i < 7; i++)
	{
		if (StrContains(str[i], "EconomyBan") != -1)
		{
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			strcopy(EcBan, 15, str2[1]);
		}
	}
}

stock int GetSteamLevel(const char[] responseBodyLevel)
{
	char str[10][64];
	ExplodeString(responseBodyLevel, "_level\":", str, sizeof(str), sizeof(str[]));
	char str2[2][64];
	ExplodeString(str[1], "}", str2, sizeof(str2), sizeof(str2[]));
	if (str2[0][0] == '\0')
		return -1;
	else
		return StringToInt(str2[0]);
}

stock int GetCommVisibState(const char[] responseBodyPrivate)
{
	char str[10][512];
	ExplodeString(responseBodyPrivate, ",", str, sizeof(str), sizeof(str[]));
	for (int i = 0; i < 10; i++)
	{
		if (StrContains(str[i], "communityvisibilitystate", false) != -1)
		{
			char str2[3][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			return StringToInt(str2[1]);
		}
	}
	return -1;
}