#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#pragma newdecls required

/*
* PROGRAMMING CREDITS:
* Could not do this without Fyren at all, it was his original code chunk 
* 	that got me started (especially turning off directors and freezing players).
* 	Thanks to him for answering all of my silly coding questions too.
* 
* TESTING CREDITS:
* 
* Biggest #1 thanks goes out to Fission for always being there since the beginning
* even when this plugin was barely working.
*/

#define READY_DEBUG 0
#define READY_DEBUG_LOG 0

#define READY_VERSION "0.2.0"
#define READY_LIVE_COUNTDOWN 0
#define READY_UNREADY_HINT_PERIOD 10.0
#define READY_LIST_PANEL_LIFETIME 10
#define READY_RESTART_ROUND_DELAY 5.0
#define READY_RESTART_MAP_DELAY 5.0

#define L4D_MAXCLIENTS_PLUS1 (MaxClients+1)
#define L4D_TEAM_SURVIVORS 2
#define L4D_TEAM_INFECTED 3
#define L4D_TEAM_SPECTATE 1

#define HEALTH_BONUS_FIX 1

#if HEALTH_BONUS_FIX

#define EBLOCK_DEBUG READY_DEBUG

#define EBLOCK_BONUS_UPDATE_DELAY 0.01

#define EBLOCK_VERSION "0.1.2"

#if EBLOCK_DEBUG
#define EBLOCK_BONUS_HEALTH_BUFFER 10.0
#else
#define EBLOCK_BONUS_HEALTH_BUFFER 1.0
#endif

#define EBLOCK_USE_DELAYED_UPDATES 0
#define LEAGUE_ADD_NOTICE 1

bool painPillHolders[256];
#endif

/*
* TEST - should be fixed: the "error more than 1 witch spawned in a single round"
*  keeps being printed
* even though there isnt an extra witch being spawned or w/e
*/

bool readyMode; //currently waiting for players to ready up?

int goingLive; //0 = not going live, 1 or higher = seconds until match starts

bool votesUnblocked;
int insideCampaignRestart; //0=normal play, 1 or 2=programatically restarting round
bool isCampaignBeingRestarted;

int forcedStart;
int readyStatus[MAXPLAYERS + 1];

Handle menuPanel = null;

Handle liveTimer;
bool unreadyTimerExists;

ConVar	cvarEnforceReady, cvarReadyCompetition, cvarReadyMinimum, cvarReadyHalves,
		cvarReadyServerCfg, cvarReadySearchKeyDisable, cvarSearchKey;

Handle fwdOnReadyRoundRestarted = null;

int hookedPlayerHurt; //if we hooked player_hurt event?

int pauseBetweenHalves; //should we ready up before starting the 2nd round or go live right away
bool isSecondRound;

bool isMapRestartPending;
bool insidePluginEnd = false;

public Plugin myinfo =
{
	name = "L4D Ready Up",
	author = "Downtown1 & The Rotoblin Dev Team",
	description = "Force Players to Ready Up Before Beginning Match",
	version = READY_VERSION,
	url = "http://code.google.com/p/rotoblin/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	//case-insensitive handling of ready,unready,notready
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);

	RegConsoleCmd("sm_ready", readyUp);
	RegConsoleCmd("sm_unready", readyDown);
	RegConsoleCmd("sm_notready", readyDown); //alias for people who are bad at reading instructions
	
	RegConsoleCmd("sm_pause", readyPause);
	
	//block all voting if we're enforcing ready mode
	//we only temporarily allow votes to fake restart the campaign
	RegConsoleCmd("callvote", callVote);
	
	RegConsoleCmd("spectate", Command_Spectate);
	
	#if READY_DEBUG
	RegConsoleCmd("unfreezeme1", Command_Unfreezeme1);	
	RegConsoleCmd("unfreezeme2", Command_Unfreezeme2);	
	RegConsoleCmd("unfreezeme3", Command_Unfreezeme3);	
	RegConsoleCmd("unfreezeme4", Command_Unfreezeme4);
	
	RegConsoleCmd("sm_printclients", printClients);
	
	RegConsoleCmd("sm_votestart", SendVoteRestartStarted);
	RegConsoleCmd("sm_votepass", SendVoteRestartPassed);
	
	RegConsoleCmd("sm_whoready", readyWho);
	
	RegConsoleCmd("sm_drawready", readyDraw);
	
	RegConsoleCmd("sm_dumpentities", Command_DumpEntities);
	RegConsoleCmd("sm_dumpgamerules", Command_DumpGameRules);
	RegConsoleCmd("sm_scanproperties", Command_ScanProperties);
	
	RegAdminCmd("sm_begin", compReady, ADMFLAG_BAN, "sm_begin");
	#endif
	
	RegAdminCmd("sm_restartmap", CommandRestartMap, ADMFLAG_CHANGEMAP, "sm_restartmap - changelevels to the current map");
	RegAdminCmd("sm_restartround", FakeRestartVoteCampaign, ADMFLAG_CHANGEMAP, "sm_restartround - executes a restart campaign vote and makes everyone votes yes");
	
	RegAdminCmd("sm_abort", compAbort, ADMFLAG_BAN, "sm_abort");
	RegAdminCmd("sm_forcestart", compStart, ADMFLAG_BAN, "sm_forcestart");
	
	HookEvent("round_start", eventRSLiveCallback);
	HookEvent("round_end", eventRoundEndCallback);
	
	HookEvent("player_bot_replace", eventPlayerBotReplaceCallback);
	HookEvent("bot_player_replace", eventBotPlayerReplaceCallback);
	
	HookEvent("player_spawn", eventSpawnReadyCallback);
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("witch_spawn", Event_WitchSpawn);
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea);
	
	#if READY_DEBUG
	HookEvent("vote_started", eventVoteStarted);
	HookEvent("vote_passed", eventVotePassed);
	HookEvent("vote_ended", eventVoteEnded);
	
	Handle NoBosses = FindConVar("director_no_bosses");
	NoBosses.AddChangeHook(ConVarChange_DirectorNoBosses);
	#endif
	
	fwdOnReadyRoundRestarted = CreateGlobalForward("OnReadyRoundRestarted", ET_Event);
	
	CreateConVar("l4d_ready_version", READY_VERSION, "Version of the ready up plugin.", FCVAR_SPONLY|FCVAR_NOTIFY);
	cvarEnforceReady = CreateConVar("l4d_ready_enabled", "0", "Make players ready up before a match begins", FCVAR_SPONLY|FCVAR_NOTIFY);
	cvarReadyCompetition = CreateConVar("l4d_ready_competition", "0", "Disable all plugins but a few competition-allowed ones", FCVAR_SPONLY|FCVAR_NOTIFY);
	cvarReadyHalves = CreateConVar("l4d_ready_both_halves", "0", "Make players ready up both during the first and second rounds of a map", FCVAR_SPONLY|FCVAR_NOTIFY);
	cvarReadyMinimum = CreateConVar("l4d_ready_minimum_players", "8", "Minimum # of players before we can ready up", FCVAR_SPONLY|FCVAR_NOTIFY);
	cvarReadyServerCfg = CreateConVar("l4d_ready_server_cfg", "", "Config to execute when the map is changed (to exec after server.cfg).", FCVAR_SPONLY|FCVAR_NOTIFY);
	cvarReadySearchKeyDisable = CreateConVar("l4d_ready_search_key_disable", "1", "Automatically disable plugin if sv_search_key is blank", FCVAR_SPONLY|FCVAR_NOTIFY);
	
	cvarSearchKey = FindConVar("sv_search_key");
	
	cvarEnforceReady.AddChangeHook(ConVarChange_ReadyEnabled);
	cvarReadyCompetition.AddChangeHook(ConVarChange_ReadyCompetition);
	cvarSearchKey.AddChangeHook(ConVarChange_SearchKey);

	#if HEALTH_BONUS_FIX
	CreateConVar("l4d_eb_health_bonus", EBLOCK_VERSION, "Version of the Health Bonus Exploit Blocker", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_REPLICATED);
	
	HookEvent("item_pickup", Event_ItemPickup);	
	HookEvent("pills_used", Event_PillsUsed);
	HookEvent("heal_success", Event_HealSuccess);
	
	HookEvent("round_start", Event_RoundStart);
	
	#if EBLOCK_DEBUG
	RegConsoleCmd("sm_updatehealth", Command_UpdateHealth);
	
	//RegConsoleCmd("sm_givehealth", Command_GiveHealth);
	#endif
	#endif
	
}

public void OnAllPluginsLoaded()
{	
	if(FindConVar("l4d_team_manager_ver") != null)
	{
		// l4d scores manager plugin is loaded
		
		// allow reready because it will fix scores when rounds are restarted?
		RegConsoleCmd("sm_reready", Command_Reready);
	}
	else
	{
		// l4d scores plugin is NOT loaded
		// supply these commands which would otherwise be done by the team manager
		
		RegAdminCmd("sm_swap", Command_PlayerSwap, ADMFLAG_BAN, "sm_swap <player1> <player2> - swap player1's and player2's teams");
		RegAdminCmd("sm_swapteams", Command_SwapTeams, ADMFLAG_BAN, "sm_swapteams - swap all the players to the opposite teams");
	}
	
}

public void OnPluginEnd()
{
	insidePluginEnd = true;
	
	readyOff();	
}

public void OnMapEnd()
{
	isSecondRound = false;	
	
	DebugPrintToAll("Event: Map ended.");
}

public void OnMapStart()
{
	DebugPrintToAll("Event map started.");
	
	/*
	* execute the cfg specified in l4d_ready_server_cfg
	*/
	if(GetConVarInt(cvarEnforceReady))
	{
		
		char cfgFile[128];
		GetConVarString(cvarReadyServerCfg, cfgFile, sizeof(cfgFile));
		
		if(strlen(cfgFile) == 0)
		{
			return;
		}
		
		char cfgPath[1024];
		BuildPath(Path_SM, cfgPath, 1024, "../../cfg/%s", cfgFile);
		
		if(FileExists(cfgPath))
		{
			DebugPrintToAll("Executing server config %s", cfgPath);
			
			ServerCommand("exec %s", cfgFile);
		}
		else
		{
			LogError("[SM] Could not execute server config %s, file not found", cfgPath);
			PrintToServer("[SM] Could not execute server config %s, file not found", cfgFile);	
			PrintToChatAll("[SM] Could not execute server config %s, file not found", cfgFile);	
		}
	}
}

public bool OnClientConnect()
{
	if (readyMode) 
	{
		checkStatus();
	}
	
	return true;
}

public void OnClientDisconnect()
{
	if (readyMode) checkStatus();
}

void checkStatus()
{
	int humans, ready;
	int i;
	
	//count number of non-bot players in-game
	for (i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			humans++;
			if (readyStatus[i]) ready++;
		}
	}
	if(humans == 0 || humans < GetConVarInt(cvarReadyMinimum))
		return;
	
	if (goingLive && (humans == ready)) return;
	else if (goingLive && (humans != ready))
	{
		goingLive = 0;
		PrintHintTextToAll("Aborted going live due to player unreadying.");
		KillTimer(liveTimer);
	}
	else if (!goingLive && (humans == ready))
	{
		if(!insideCampaignRestart)
		{
			goingLive = READY_LIVE_COUNTDOWN; //TODO get from variable
			liveTimer = CreateTimer(1.0, timerLiveCountCallback, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else if (!goingLive && (humans != ready)) PrintHintTextToAll("%d of %d players are ready.", ready, humans);
	else PrintToChatAll("checkStatus bad state (tell Downtown1)");
}

//repeatedly count down until the match goes live
public Action timerLiveCountCallback(Handle timer)
{
	//will go live soon
	if (goingLive)
	{
		if (forcedStart) PrintHintTextToAll("Forcing match start.  An admin must 'say !abort' to abort!\nGoing live in %d seconds.", goingLive);
		else PrintHintTextToAll("All players ready.  Say !unready now to abort!\nGoing live in %d seconds.", goingLive);
		goingLive--;
	}
	//actually go live and unfreeze everyone
	else
	{
		//readyOff();
		
		PrintHintTextToAll("Match will be live after 2 round restarts.");
		
		insideCampaignRestart = 2;
		RestartCampaignAny();
		
		//		CreateTimer(4.0, timerLiveMessageCallback, _, _);
		//SDKCall(restartScenario, gConf, "Director", 1);
		//HookEvent("round_start", eventRSLiveCallback);
		//SDKCall(restartScenario, gConf, "Director", 1);
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public void eventRoundEndCallback(Event event, const char[] name, bool dontBroadcast)
{
	#if READY_DEBUG
	DebugPrintToAll("[DEBUG] Event round has ended");
	#endif
	
	if(!isCampaignBeingRestarted)
	{
		#if READY_DEBUG
		if(!isSecondRound)
			DebugPrintToAll("[DEBUG] Second round detected.");
		else
		DebugPrintToAll("[DEBUG] End of second round detected.");
		#endif
		isSecondRound = true;
	}
	
	//we just ended the last restart, match will be live soon
	if(insideCampaignRestart == 1) 
	{
		//enable the director etc, but dont unfreeze all players just yet
		RoundEndBeforeLive();
	}
	
	isCampaignBeingRestarted = false;
}

public Action eventRSLiveCallback(Event event, const char[] name, bool dontBroadcast)
{
	#if READY_DEBUG
	DebugPrintToAll("[DEBUG] Event round has started");
	#endif
	
	//currently automating campaign restart before going live?
	if(insideCampaignRestart > 0) 
	{
		insideCampaignRestart--;
		#if READY_DEBUG
		DebugPrintToAll("[DEBUG] Round restarting, left = %d", insideCampaignRestart);
		#endif
		
		//first restart, do one more
		if(insideCampaignRestart == 1) 
		{
			CreateTimer(READY_RESTART_ROUND_DELAY, timerOneRoundRestart, _, _);
			
			//PrintHintTextToAll("Match will be live after 1 round restart.");
			
		}
		//last restart, match is now live!
		else if (insideCampaignRestart == 0)
		{
			RoundIsLive();
		}
		else
		{
			LogError("insideCampaignRestart somehow neither 0 nor 1 after decrementing");
		}
		
		return Plugin_Continue;
	}
	
	//normal round start event not triggered by our plugin
	
	//our code will just enable ready mode at the start of a round
	//if the cvar is set to it
	if(GetConVarInt(cvarEnforceReady)
	&& (!isSecondRound || GetConVarInt(cvarReadyHalves) || pauseBetweenHalves)) 
	{
		#if READY_DEBUG
		DebugPrintToAll("[DEBUG] Calling comPready, pauseBetweenHalves = %d", pauseBetweenHalves);
		#endif
		
		compReady(0, 0);
		pauseBetweenHalves = 0;
	}
	
	return Plugin_Continue;
}

public Action timerOneRoundRestart(Handle timer)
{
	PrintToChatAll("[SM] Match will be live after 1 round restart!");
	PrintHintTextToAll("Match will be live after 1 round restart!");
	
	RestartCampaignAny();
	
	return Plugin_Stop;
}

public Action timerLiveMessageCallback(Handle timer)
{
	PrintHintTextToAll("Match is LIVE!");
	
	if(GetConVarInt(cvarReadyHalves) || isSecondRound)
	{
		PrintToChatAll("[SM] Match is LIVE!");
	}
	else
	{
		PrintToChatAll("[SM] Match is LIVE for both halves, say !reready to request a ready-up before the next half.");
	}
	
	return Plugin_Stop;
}


public Action timerUnreadyCallback(Handle timer)
{
	if(!readyMode)
	{
		unreadyTimerExists = false;
		return Plugin_Stop;
	}
	
	if(insideCampaignRestart)
	{
		return Plugin_Continue;
	}
	
	//int curPlayers = CountInGameHumans();
	//int minPlayers = GetConVarInt(cvarReadyMinimum);
	
	int i;
	for (i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if (IsClientInGameHuman(i)) 
		{
			//use panel for ready up stuff?
			if(!readyStatus[i])
			{
				PrintHintText(i, "You are NOT READY!\n\nSay !ready in chat to ready up.");
			}
			else
			{
				PrintHintText(i, "You are ready.\n\nSay !unready in chat if no longer ready.");
			}
		}
	}
	
	DrawReadyPanelList();
	
	return Plugin_Continue;
}

public Action eventSpawnReadyCallback(Event event, const char[] name, bool dontBroadcast)
{
	if(!readyMode)
	{
		#if READY_DEBUG
		int player = GetClientOfUserId(GetEventInt(event, "userid"));
		
		char curname[128];
		GetClientName(player,curname,128);
		DebugPrintToAll("[DEBUG] Spawned %s [%d], doing nothing.", curname, player);
		#endif
		
		return Plugin_Handled;
	}
	
	int player = GetClientOfUserId(GetEventInt(event, "userid"));
	
	#if READY_DEBUG
	char curname[128];
	GetClientName(player,curname,128);
	DebugPrintToAll("[DEBUG] Spawned %s [%d], freezing.", curname, player);
	#endif
	
	ToggleFreezePlayer(player, true);
	return Plugin_Handled;
}

public Action L4D_OnSpawnTank(const float vector[3], const float qangle[3])
{
	DebugPrintToAll("OnSpawnTank(vector[%f,%f,%f], qangle[%f,%f,%f]", 
		vector[0], vector[1], vector[2], qangle[0], qangle[1], qangle[2]);
		
	if(readyMode)
	{
		DebugPrintToAll("Blocking tank spawn...");
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

public Action L4D_OnSpawnWitch(const float vector[3], const float qangle[3])
{
	DebugPrintToAll("OnSpawnWitch(vector[%f,%f,%f], qangle[%f,%f,%f])", 
		vector[0], vector[1], vector[2], qangle[0], qangle[1], qangle[2]);
		
	if(readyMode)
	{
		DebugPrintToAll("Blocking witch spawn...");
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}


public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
}

public void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{/*	int witchid = GetEventInt(event, "witchid");
	int client = GetClientOfUserId(witchid);*/
}

public void Event_PlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast)
{
}

//When a player replaces a bot (i.e. player joins survivors team)
public Action eventBotPlayerReplaceCallback(Event event, const char[] name, bool dontBroadcast)
{
	//	int bot = GetClientOfUserId(GetEventInt(event, "bot"));
	int player = GetClientOfUserId(GetEventInt(event, "player"));
	
	if(readyMode)
	{
		//called when player joins survivor....?
		#if READY_DEBUG
		char curname[128];
		GetClientName(player,curname,128);
		DebugPrintToAll("[DEBUG] Player %s [%d] replacing bot, freezing player.", curname, player);
		#endif
		
		ToggleFreezePlayer(player, true);
	}
	else
	{
		#if READY_DEBUG
		char curname[128];
		GetClientName(player,curname,128);
		DebugPrintToAll("[DEBUG] Player %s [%d] replacing bot, doing nothing.", curname, player);
		#endif	
	}
	
	return Plugin_Handled;
}


//When a bot replaces a player (i.e. player switches to spectate or infected)
public Action eventPlayerBotReplaceCallback(Event event, const char[] name, bool dontBroadcast)
{
	
	int player = GetClientOfUserId(GetEventInt(event, "player"));
	//	int bot = GetClientOfUserId(GetEventInt(event, "bot"));
	
	if(readyMode)
	{
		#if READY_DEBUG
		char curname[128];
		GetClientName(player,curname,128);
		
		DebugPrintToAll("[DEBUG] Bot replacing player %s [%d], unfreezing player.", curname, player);
		#endif
		
		ToggleFreezePlayer(player, false);
	}
	else
	{
		#if READY_DEBUG
		char curname[128];
		GetClientName(player,curname,128);
		DebugPrintToAll("[DEBUG] Bot replacing player %s [%d], doing nothing.", curname, player);
		#endif	
	}
	
	return Plugin_Handled;
}

//When a player gets hurt during ready mode, block all damage
public void eventPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(event, "userid"));
	int health = GetEventInt(event, "health");
	int dmg_health = GetEventInt(event, "dmg_health");
	
	#if READY_DEBUG
	char curname[128];
	GetClientName(player,curname,128);
	
	DebugPrintToAll("[DEBUG] Player hurt %s [%d], health = %d, dmg_health = %d.", curname, player, health, dmg_health);
	#endif
	
	SetEntityHealth(player, health + dmg_health);
}

public Action eventVotePassed(Event event, const char[] name, bool dontBroadcast)
{
	char details[128];
	char param1[128];
	int team;
	
	GetEventString(event, "details", details, 128);
	GetEventString(event, "param1", param1, 128);
	team = GetEventInt(event, "team");
		
	DebugPrintToAll("[DEBUG] Vote passed, details=%s, param1=%s, team=[%d].", details, param1, team);
	
	return Plugin_Handled;
}

public void eventVoteStarted(Event event, const char[] name, bool dontBroadcast)
{
	char issue[128];
	char param1[128];
	int team;
	int initiator;
	
	GetEventString(event, "issue", issue, 128);
	GetEventString(event, "param1", param1, 128);
	team = GetEventInt(event, "team");
	initiator = GetEventInt(event, "initiator");
			
	DebugPrintToAll("[DEBUG] Vote started, issue=%s, param1=%s, team=[%d], initiator=[%d].", issue, param1, team, initiator);
}

public void eventVoteEnded(Event event, const char[] name, bool dontBroadcast)
{
	DebugPrintToAll("[DEBUG] Vote ended");
}


public void ConVarChange_DirectorNoBosses(ConVar convar, const char[] oldValue, const char[] newValue)
{
	DebugPrintToAll("director_no_bosses changed from %s to %s", oldValue, newValue);
	
}

public void SendVoteRestartPassed(int client, int args)
{
	Handle event = CreateEvent("vote_passed");	
	if(event == null) 
	{
		return;
	}
	
	SetEventString(event, "details", "#L4D_vote_passed_restart_game");
	SetEventString(event, "param1", "");
	SetEventInt(event, "team", -1);
	
	FireEvent(event);
	
	DebugPrintToAll("[DEBUG] Sent fake vote passed to restart game");
}

public void SendVoteRestartStarted(int client, int args)
{
	Handle event = CreateEvent("vote_started");	
	if(event == null)
	{
		return;
	}
	
	SetEventString(event, "issue", "#L4D_vote_restart_game");
	SetEventString(event, "param1", "");
	SetEventInt(event, "team", -1);
	SetEventInt(event, "initiator", client);
	
	FireEvent(event);
	
	DebugPrintToAll("[DEBUG] Sent fake vote started to restart game");
}

public Action FakeRestartVoteCampaign(int client, int args)
{
	//re-enable ready mode after the restart
	pauseBetweenHalves = 1;
	
	RestartCampaignAny();
	PrintToChatAll("[SM] Round manually restarted.");
	DebugPrintToAll("[SM] Round manually restarted.");
	
	return Plugin_Handled;
}

void RestartCampaignAny()
{	
	char currentmap[128];
	GetCurrentMap(currentmap, sizeof(currentmap));
	
	DebugPrintToAll("RestartCampaignAny() - Restarting scenario from vote ...");
	
	Call_StartForward(fwdOnReadyRoundRestarted);
	Call_Finish();
	
	L4D_RestartScenarioFromVote(currentmap);
}

public Action CommandRestartMap(int client, int args)
{	
	if(!isMapRestartPending)
	{
		PrintToChatAll("[SM] Map resetting in %.0f seconds.", READY_RESTART_MAP_DELAY);
		RestartMapDelayed();
	}
	
	return Plugin_Handled;
}

void RestartMapDelayed()
{
	isMapRestartPending = true;
	
	CreateTimer(READY_RESTART_MAP_DELAY, timerRestartMap, _, TIMER_FLAG_NO_MAPCHANGE);
	DebugPrintToAll("[SM] Map will restart in %f seconds.", READY_RESTART_MAP_DELAY);
}

public Action timerRestartMap(Handle timer)
{
	RestartMapNow();
	
	return Plugin_Stop;
}

void RestartMapNow()
{
	isMapRestartPending = false;
	
	char currentMap[256];
	
	GetCurrentMap(currentMap, 256);
	
	ServerCommand("changelevel %s", currentMap);
}

public Action callVote(int client, int args)
{
	//only allow voting when are not enforcing ready modes
	if(!GetConVarInt(cvarEnforceReady)) 
	{
		return Plugin_Continue;
	}
	
	if(!votesUnblocked) 
	{
		#if READY_DEBUG
		DebugPrintToAll("[DEBUG] Voting is blocked");
		#endif
		return Plugin_Handled;
	}
	
	char votetype[32];
	GetCmdArg(1,votetype,32);
	
	if (strcmp(votetype,"RestartGame",false) == 0)
	{
		#if READY_DEBUG
		DebugPrintToAll("[DEBUG] Vote on RestartGame called");
		#endif
		votesUnblocked = false;
	}
	
	return Plugin_Continue;
}

public Action Command_Spectate(int client, int args)
{
	if(GetClientTeam(client) != L4D_TEAM_SPECTATE)
	{
		ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
		PrintToChat(client, "[SM] You are now spectating." );
	}
	//respectate trick to get around spectator camera being stuck
	else
	{
		ChangePlayerTeam(client, L4D_TEAM_INFECTED);
		CreateTimer(0.1, Timer_Respectate, client, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Handled;
}

public Action Timer_Respectate(Handle timer, int client)
{
	ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
	PrintToChat(client, "[SM] You are now spectating (again).");
	return Plugin_Stop;
}

public Action Command_Unfreezeme1(int client, int args)
{
	SetEntityMoveType(client, MOVETYPE_NOCLIP);	
	PrintToChatAll("Unfroze %N with noclip");
	
	return Plugin_Handled;
}

public Action Command_Unfreezeme2(int client, int args)
{
	SetEntityMoveType(client, MOVETYPE_OBSERVER);	
	PrintToChatAll("Unfroze %N with observer");
	
	return Plugin_Handled;
}

public Action Command_Unfreezeme3(int client, int args)
{
	SetEntityMoveType(client, MOVETYPE_WALK);	
	PrintToChatAll("Unfroze %N with WALK");
	
	return Plugin_Handled;
}


public Action Command_Unfreezeme4(int client, int args)
{
	SetEntityMoveType(client, MOVETYPE_CUSTOM);	
	PrintToChatAll("Unfroze %N with customs");
	
	return Plugin_Handled;
}


public Action printClients(int client, int args)
{
	
	int i;
	for (i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if (IsClientInGame(i)) 
		{
			char curname[128];
			GetClientName(i,curname,128);
			DebugPrintToAll("[DEBUG] Player %s with client id [%d]", curname, i);
		}
	}
	
	return Plugin_Handled;
}

public Action Command_Say(int client, int args)
{
	if (args < 1 || !readyMode)
	{
		return Plugin_Continue;
	}
	
	char sayWord[MAX_NAME_LENGTH];
	GetCmdArg(1, sayWord, sizeof(sayWord));
	
	int idx = StrContains(sayWord, "notready", false);
	if(idx == 1)
	{
		readyDown(client, args);
		return Plugin_Handled;
	}
	
	idx = StrContains(sayWord, "unready", false);
	if(idx == 1)
	{
		readyDown(client, args);
		return Plugin_Handled;
	}
	
	idx = StrContains(sayWord, "ready", false);
	if(idx == 1)
	{
		readyUp(client, args);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action readyUp(int client, int args)
{
	if (!readyMode || readyStatus[client]) return Plugin_Handled;
	
	//don't allow readying up if there's too few players
	int realPlayers = CountInGameHumans();
	int minPlayers = GetConVarInt(cvarReadyMinimum);
	
	//ready up the player and see if everyone is ready now
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	
	if(realPlayers >= minPlayers)
		PrintToChatAll("%s is ready.", name);
	else
	PrintToChatAll("%s is ready. A minimum of %d players is required.", name, minPlayers);
	
	readyStatus[client] = 1;
	checkStatus();
	
	DrawReadyPanelList();
	
	return Plugin_Handled;
}

public Action readyDown(int client, int args)
{
	if (!readyMode || !readyStatus[client]) return Plugin_Handled;
	if(isCampaignBeingRestarted || insideCampaignRestart) return Plugin_Handled;
	
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	PrintToChatAll("%s is no longer ready.", name);
	
	readyStatus[client] = 0;
	checkStatus();
	
	DrawReadyPanelList();
	
	return Plugin_Handled;
}

public Action readyPause(int client, int args)
{
	PrintToChatAll("[SM] Please use !reready to pause the match at halftime. !pause in the future will literally pause the match anytime.");
	
	return Plugin_Handled;
}


public Action Command_Reready(int client, int args)
{
	if (readyMode) return Plugin_Handled;
	
	pauseBetweenHalves = 1;
	PrintToChatAll("[SM] Match will pause at the end of this half and require readying up again.");
	
	return Plugin_Handled;
}


public Action readyWho(int client, int args)
{
	if (!readyMode) return Plugin_Handled;
	
	char readyPlayers[1024];
	char unreadyPlayers[1024];
	
	readyPlayers[0] = 0;
	unreadyPlayers[0] = 0;
	
	int numPlayers = 0;
	int numPlayers2 = 0;
	
	int i;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i)) 
		{
			char name[MAX_NAME_LENGTH];
			GetClientName(i, name, sizeof(name));
			
			if(readyStatus[i]) 
			{
				if(numPlayers > 0 )
					StrCat(readyPlayers, 1024, ", ");
				
				StrCat(readyPlayers, 1024, name);
				
				numPlayers++;
			}
			else
			{
				if(numPlayers2 > 0 )
					StrCat(unreadyPlayers, 1024, ", ");
				
				StrCat(unreadyPlayers, 1024, name);
				
				numPlayers2++;
			}
		}
	}
	
	if(numPlayers == 0) 
	{
		StrCat(readyPlayers, 1024, "NONE");
	}
	if(numPlayers2 == 0) 
	{
		StrCat(unreadyPlayers, 1024, "NONE");
	}
	
	DebugPrintToAll("[SM] Players ready: %s", readyPlayers);
	DebugPrintToAll("[SM] Players NOT ready: %s", unreadyPlayers);
	
	return Plugin_Handled;
}


//draws a menu panel of ready and unready players
void DrawReadyPanelList()
{
	if (!readyMode) return;
	
	/*
	#if READY_DEBUG
	DebugPrintToAll("[DEBUG] Drawing the ready panel");
	#endif
	*/
	
	char readyPlayers[1024];
	char name[MAX_NAME_LENGTH];
	
	readyPlayers[0] = 0;
	
	int numPlayers = 0;
	int numPlayers2 = 0;
	
	int ready, unready;
	
	int i;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
	{
		if(IsClientInGameHuman(i)) 
		{
			if(readyStatus[i]) 
				ready++;
			else
				unready++;
		}
	}
	
	Handle panel = CreatePanel();
	
	if(ready)
	{
		DrawPanelText(panel, "READY");
		
		//->%d. %s makes the text yellow
		// otherwise the text is white
		
		for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
		{
			if(IsClientInGameHuman(i)) 
			{
				GetClientName(i, name, sizeof(name));
				
				if(readyStatus[i]) 
				{
					numPlayers++;
					Format(readyPlayers, 1024, "->%d. %s", numPlayers, name);
					DrawPanelText(panel, readyPlayers);
					
					#if READY_DEBUG
					DrawPanelText(panel, readyPlayers);
					#endif
				}
			}
		}
	}
	
	if(unready)
	{
		DrawPanelText(panel, "NOT READY");
		
		for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
		{
			if(IsClientInGameHuman(i)) 
			{
				GetClientName(i, name, sizeof(name));
				
				if(!readyStatus[i]) 
				{
					numPlayers2++;
					Format(readyPlayers, 1024, "->%d. %s", numPlayers2, name);
					DrawPanelText(panel, readyPlayers);
					#if READY_DEBUG
					DrawPanelText(panel, readyPlayers);
					#endif
				}
			}
		}
	}
	
	char versionInfo[128];
	Format(versionInfo, 128, "RUP Mod v%s", READY_VERSION);
	DrawPanelText(panel, versionInfo);
	
#if LEAGUE_ADD_NOTICE
	DrawPanelText(panel,     "Rotoblin v0.8.1");
#endif
	
	for (i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
	{
		if(IsClientInGameHuman(i)) 
		{
			SendPanelToClient(panel, i, Menu_ReadyPanel, READY_LIST_PANEL_LIFETIME);			
		}
	}
	
	if(menuPanel != null)
	{
		CloseHandle(menuPanel);
	}
	menuPanel = panel;
}


public Action readyDraw(int client, int args)
{
	DrawReadyPanelList();
	
	return Plugin_Handled;
}

public int Menu_ReadyPanel(Menu menu, MenuAction action, int param1, int param2)
{
	return 0;
}

//thanks to Liam for helping me figure out from the disassembly what the server's director_stop does
void directorStop()
{
	#if READY_DEBUG
	DebugPrintToAll("[DEBUG] Director stopped.");
	#endif
	
	//doing director_stop on the server sets the below variables like so
	SetConVarInt(FindConVar("director_no_bosses"), 1);
	SetConVarInt(FindConVar("director_no_specials"), 1);
	SetConVarInt(FindConVar("director_no_mobs"), 1);
	SetConVarInt(FindConVar("director_ready_duration"), 0);
	SetConVarInt(FindConVar("z_common_limit"), 0);
	SetConVarInt(FindConVar("z_mega_mob_size"), 1); //why not 0? only Valve knows
	
	//empty teams of survivors dont cycle the round
	SetConVarInt(FindConVar("sb_all_bot_team"), 1);
	
	//dont accidentally spawn tanks in ready mode
	ResetConVar(FindConVar("director_force_tank"));
}

void directorStart()
{
	#if READY_DEBUG
	DebugPrintToAll("[DEBUG] Director started.");
	#endif
	
	ResetConVar(FindConVar("director_no_bosses"));
	ResetConVar(FindConVar("director_no_specials"));
	ResetConVar(FindConVar("director_no_mobs"));
	ResetConVar(FindConVar("director_ready_duration"));
	ResetConVar(FindConVar("z_common_limit"));
	ResetConVar(FindConVar("z_mega_mob_size"));
	
	#if !READY_DEBUG
	ResetConVar(FindConVar("sb_all_bot_team"));
	#endif
	
}

//freeze everyone until they ready up
void readyOn()
{
	DebugPrintToAll("readyOn() called");
	
	readyMode = true;
	
	PrintHintTextToAll("Ready mode on.\nSay !ready to ready up or !unready to unready.");
	
	if(!hookedPlayerHurt) 
	{
		HookEvent("player_hurt", eventPlayerHurt);
		hookedPlayerHurt = 1;
	}
	
	directorStop();
	
	int i;
	for (i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		readyStatus[i] = 0;
		if (IsValidEntity(i) && IsClientInGame(i) && (GetClientTeam(i) == L4D_TEAM_SURVIVORS)) 
		{
			
			#if READY_DEBUG
			char curname[128];
			GetClientName(i,curname,128);
			DebugPrintToAll("[DEBUG] Freezing %s [%d] during readyOn().", curname, i);
			#endif
			
			ToggleFreezePlayer(i, true);
		}
	}
	
	if(!unreadyTimerExists)
	{
		unreadyTimerExists = true;
		CreateTimer(READY_UNREADY_HINT_PERIOD, timerUnreadyCallback, _, TIMER_REPEAT);
	}
}

//allow everyone to move now
void readyOff()
{
	DebugPrintToAll("readyOff() called");
	
	readyMode = false;
	
	//events seem to be all unhooked _before_ OnPluginEnd
	//though even if it wasnt, they'd get unhooked after anyway..
	if(hookedPlayerHurt && !insidePluginEnd) 
	{
		UnhookEvent("player_hurt", eventPlayerHurt);
		hookedPlayerHurt = 0;
	}
	
	directorStart();
	
	if(insidePluginEnd)
	{
		UnfreezeAllPlayers();
	}
	
	//used to unfreeze all players here always
	//now we will do it at the beginning of the round when its live
	//so that players cant open the safe room door during the restarts
}

void UnfreezeAllPlayers()
{
	int i;
	for (i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
	{
		if (IsClientInGame(i)) 
		{
			#if READY_DEBUG
			char curname[128];
			GetClientName(i,curname,128);
			DebugPrintToAll("[DEBUG] Unfreezing %s [%d] during UnfreezeAllPlayers().", curname, i);
			#endif
			
			ToggleFreezePlayer(i, false);			
		}
	}
}

//make everyone un-ready, but don't actually freeze them
void compOn()
{
	DebugPrintToAll("compOn() called");
	
	goingLive = 0;
	readyMode = false;
	forcedStart = 0;
	
	int i;
	for (i = 1; i <= MAXPLAYERS; i++) readyStatus[i] = 0;
}

//abort an impending countdown to a live match
public Action compAbort(int client, int args)
{
	if (!goingLive)
	{
		ReplyToCommand(0, "L4DC: Nothing to abort.");
		return Plugin_Handled;
	}
	
	//	if (readyMode) readyOff();
	if (goingLive)
	{
		KillTimer(liveTimer);
		forcedStart = 0;
		goingLive = 0;
	}
	
	PrintHintTextToAll("Match was aborted by command.");
	
	return Plugin_Handled;
}

//begin the ready mode (everyone now needs to ready up before they can move)
public Action compReady(int client, int args)
{
	if (goingLive)
	{
		ReplyToCommand(0, "L4DC: Already going live, ignoring.");
		return Plugin_Handled;
	}
	
	compOn();
	readyOn();
	
	return Plugin_Handled;
}

//force start a match using admin
public Action compStart(int client, int args)
{
	if(!readyMode)
		return Plugin_Handled;
	
	if (goingLive)
	{
		ReplyToCommand(0, "L4DC: Already going live, ignoring.");
		return Plugin_Handled;
	}
	
	//	compOn();
	
	//TODO get it from a variable
	goingLive = READY_LIVE_COUNTDOWN;
	forcedStart = 1;
	liveTimer = CreateTimer(1.0, timerLiveCountCallback, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Handled;
}

//restart the map when we toggle the cvar
public void ConVarChange_ReadyEnabled(ConVar convar, const char[] oldValue, const char[] newValue)
{		
	if (oldValue[0] == newValue[0])
	{
		return;
	}
	else
	{
		int value = StringToInt(newValue);
		
		if(value)
		{
			//if sv_search_key is "" && l4d_ready_disable_search_key is 1
			//then don't let admins turn on our plugin
			if(GetConVarInt(cvarReadySearchKeyDisable))
			{
				char searchKey[128];
				GetConVarString(cvarSearchKey, searchKey, 128);
				
				if(searchKey[0] == 0)
				{
					LogMessage("Ready plugin will not start while sv_search_key is \"\"");
					PrintToChatAll("[SM] Ready plugin will not start while sv_search_key is \"\"");
					
					ServerCommand("l4d_ready_enabled 0");
					return;
				}
			}
			
			PrintToChatAll("[SM] Ready plugin has been enabled, restarting map in %.0f seconds", READY_RESTART_MAP_DELAY);
		}
		else
		{
			PrintToChatAll("[SM] Ready plugin has been disabled, restarting map in %.0f seconds", READY_RESTART_MAP_DELAY);
			readyOff();
		}
		RestartMapDelayed();
	}
}


//disable most non-competitive plugins
public void ConVarChange_ReadyCompetition(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (oldValue[0] == newValue[0])
	{
		return;
	}
	else
	{
		int value = StringToInt(newValue);
		
		if(value)
		{
			//TODO: use plugin iterators such as GetPluginIterator
			// to unload all plugins BUT the ones below
			
			ServerCommand("sm plugins load_unlock");
			ServerCommand("sm plugins unload_all");
			ServerCommand("sm plugins load basebans.smx");
			ServerCommand("sm plugins load basecommands.smx");
			ServerCommand("sm plugins load admin-flatfile.smx");
			ServerCommand("sm plugins load adminhelp.smx");
			ServerCommand("sm plugins load adminmenu.smx");
			ServerCommand("sm plugins load l4dscores.smx"); //IMPORTANT: load before l4dready!
			ServerCommand("sm plugins load l4dready.smx");
			ServerCommand("sm plugins load_lock");
			
			DebugPrintToAll("Competition mode enabled, plugins unloaded...");
			
			//TODO: also call sm_restartmap and sm_resetscores
			// this removes the dependency from configs to know what to do :)
			
			//Maybe make this command sm_competition_on, sm_competition_off ?
			//that way people will probably not use in server.cfg 
			// and they can exec the command over and over and it will be fine
		}
		else
		{
			ServerCommand("sm plugins load_unlock");
			ServerCommand("sm plugins refresh");

			DebugPrintToAll("Competition mode enabled, plugins reloaded...");
		}
	}
}


//disable the ready mod if sv_search_key is ""
public void ConVarChange_SearchKey(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (oldValue[0] == newValue[0])
	{
		return;
	}
	else
	{	
		if(newValue[0] == 0)
		{
			//wait about 5 secs and then disable the ready up mod
			
			//this gives time for l4d_ready_server_cfg to get executed
			//if a server.cfg disables the sv_search_key
			CreateTimer(5.0, Timer_SearchKeyDisabled, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

//repeatedly count down until the match goes live
public Action Timer_SearchKeyDisabled(Handle timer)
{
	//if sv_search_key is "" && l4d_ready_disable_search_key is 1
	//then don't let admins turn on our plugin
	if(GetConVarInt(cvarReadySearchKeyDisable) && GetConVarInt(cvarEnforceReady))
	{
		char searchKey[128];
		GetConVarString(cvarSearchKey, searchKey, 128);
		
		if(searchKey[0] == 0)
		{
			PrintToChatAll("[SM] Sv_search_key is set to \"\", the ready plugin will now automatically disable.");
			
			ServerCommand("l4d_ready_enabled 0");
			return Plugin_Continue;
		}
	}
	return Plugin_Stop;
}

public Action Command_DumpEntities(int client, int args)
{
	char netClass[128];
	char className[128];
	int i;
	
	DebugPrintToAll("Dumping entities...");
	
	for(i = 1; i < GetMaxEntities(); i++)
	{
		if(IsValidEntity(i))
		{
			if(IsValidEdict(i)) 
			{
				GetEdictClassname(i, className, 128);
				GetEntityNetClass(i, netClass, 128);
				DebugPrintToAll("Edict = %d, class name = %s, net class = %s", i, className, netClass);
			}
			else
			{
				GetEntityNetClass(i, netClass, 128);
				DebugPrintToAll("Entity = %d, net class = %s", i, netClass);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action Command_DumpGameRules(int client, int args) 
{
	int getTeamScore = GetTeamScore(2);
	DebugPrintToAll("Get team Score for team 2 = %d", getTeamScore);
	
	int gamerules = FindEntityByClassname(-1, "terror_gamerules");
	
	if(gamerules == -1)
	{
		DebugPrintToAll("Failed to find terror_gamerules edict");
		return Plugin_Handled;
	}
	
	int offset = FindSendPropInfo("CTerrorGameRulesProxy","m_iSurvivorScore");
	if(offset == -1)
	{
		DebugPrintToAll("Failed to find the property when searching for offset");
		return Plugin_Handled;
	}
	
	int entValue = GetEntData(gamerules, offset, 4);
	int entValue2 = GetEntData(gamerules, offset+4, 4);
	//	int distance = GetEntProp(gamerules, Prop_Send, "m_iSurvivorScore");
	
	DebugPrintToAll("Survivor score = %d, %d [offset = %d]", entValue, entValue2, offset);
	
	int c_offset = FindSendPropInfo("CTerrorGameRulesProxy","m_iCampaignScore");
	if(c_offset == -1)
	{
		DebugPrintToAll("Failed to find the property when searching for c_offset");
		return Plugin_Handled;
	}
	
	int centValue = GetEntData(gamerules, c_offset, 2);
	int centValue2 = GetEntData(gamerules, c_offset+4, 2);
	//	int distance = GetEntProp(gamerules, Prop_Send, "m_iSurvivorScore");
	
	DebugPrintToAll("Campaign score = %d, %d [offset = %d]", centValue, centValue2, c_offset);
	
	/*
	* try the 4 cs_team_manager aka CCSTeam edicts
	* 
	*/
	
	int teamNumber, score;
	char teamName[128];
	char curClassName[128];
	
	int i, teams;
	for(i = 0; i < GetMaxEntities() && teams < 4; i++)
	{
		if(IsValidEdict(i)) 
		{
			GetEdictClassname(i, curClassName, 128);
			if(strcmp(curClassName, "cs_team_manager") == 0) 
			{
				teams++;
				
				teamNumber = GetEntData(i, FindSendPropInfo("CCSTeam", "m_iTeamNum"), 1);
				score = GetEntData(i, FindSendPropInfo("CCSTeam", "m_iScore"), 4);
				
				GetEntPropString(i, Prop_Send, "m_szTeamname", teamName, 128);
				
				DebugPrintToAll("Team #%d, score = %d, name = %s", teamNumber, score, teamName);
			}
		}		
	}
	
	return Plugin_Handled;
}

public Action Command_ScanProperties(int client, int args)
{
	if(GetCmdArgs() != 3)
	{
		PrintToChat(client, "Usage: sm_scanproperties <step> <size> <needle>");
		return Plugin_Handled;
	}
	
	char cmd1[128], cmd2[128], cmd3[128];
	char curClassName[128];
	
	GetCmdArg(1, cmd1, 128);
	GetCmdArg(2, cmd2, 128);	
	GetCmdArg(3, cmd3, 128);
	
	int step = StringToInt(cmd1);
	int size = StringToInt(cmd2);
	int needle = StringToInt(cmd3);
	
	int gamerules = FindEntityByClassname(-1, "terror_gamerules");
	
	if(gamerules == -1)
	{
		DebugPrintToAll("Failed to find terror_gamerules edict");
		return Plugin_Handled;
	}
		
	int i;
	int value = -1;
	for(i = 100; i < 1000; i += step)
	{
		value = GetEntData(gamerules, i, size);
		
		if(value == needle)
		{
			break;
		}
	}
	if(value == needle)
	{
		DebugPrintToAll("Found value at offset = %d in terror_gamesrules", i);
	}
	else
	{
		DebugPrintToAll("Failed to find value in terror_gamesrules");
	}
	
	int teams;
	int j;
	for(j = 0; j < GetMaxEntities() && teams < 4; j++)
	{
		if(IsValidEdict(j)) 
		{
			GetEdictClassname(j, curClassName, 128);
			if(strcmp(curClassName, "cs_team_manager") == 0)
			{
				teams++;
				value = -1;
				
				for(i = 100; i < 1000; i += step)
				{
					value = GetEntData(j, i, size);
					
					if(value == needle)
					{
						break;
					}
				}
				if(value == needle)
				{
					DebugPrintToAll("Found value at offset = %d in cs_team_manager", i);
					break;
				}
				else
				{
					DebugPrintToAll("Failed to find value in cs_team_manager");
				}
			}
		}
		
	}
	
	return Plugin_Handled;
	
}

public Action Command_PlayerSwap(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_swap <player1> <player2> - swap player1's and player2's teams");
		return Plugin_Handled;
	}
	
	int player1_id, player2_id;

	char player1[64];
	GetCmdArg(1, player1, sizeof(player1));

	char player2[64];
	GetCmdArg(2, player2, sizeof(player2));
	
	player1_id = FindTarget(client, player1, true /*nobots*/, false /*immunity*/);
	player2_id = FindTarget(client, player2, true /*nobots*/, false /*immunity*/);
	
	if(player1_id == -1 || player2_id == -1)
		return Plugin_Handled;
	
	SwapPlayers(player1_id, player2_id);
	
	PrintToChatAll("[SM] %N and %N have been swapped.", player1_id, player2_id);
	
	return Plugin_Handled;
}

public Action Command_SwapTeams(int client, int args)
{
	int infected[4];
	int survivors[4];
	
	int inf = 0, sur = 0;
	int i;
	
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i)) 
		{
			int team = GetClientTeam(i);
			if(team == L4D_TEAM_SURVIVORS)
			{
				survivors[sur] = i;
				sur++;
			}
			else if (team == L4D_TEAM_INFECTED)
			{
				infected[inf] = i;
				inf++;
			}
		}
	}
	
	int min = inf > sur ? sur : inf;
	
	//first swap everyone that we can (equal # on both sides)
	for(i = 0; i < min; i++)
	{
		SwapPlayers(infected[i], survivors[i]);
	}
	
	//then move the remainder of the team to the other team
	if(inf > sur)
	{
		for(i = min; i < inf; i++)
		{
			ChangePlayerTeam(infected[i], L4D_TEAM_SURVIVORS);
		}
	}
	else 
	{
		for(i = min; i < sur; i++)
		{
			ChangePlayerTeam(survivors[i], L4D_TEAM_INFECTED);
		}
	}
	
	PrintToChatAll("[SM] Infected and Survivors have been swapped.");
	
	return Plugin_Handled;
}

//swap the two given players' teams
void SwapPlayers(int i, int j)
{
	if(GetClientTeam(i) == GetClientTeam(j))
		return;
	
	int inf, surv;
	if (GetClientTeam(i) == L4D_TEAM_INFECTED)
	{
		inf = i;
		surv = j;
	}
	else
	{
		inf = j;
		surv = i;
	}

	ChangePlayerTeam(inf,  L4D_TEAM_SPECTATE); 
	ChangePlayerTeam(surv, L4D_TEAM_INFECTED); 
	ChangePlayerTeam(inf,  L4D_TEAM_SURVIVORS); 
}

void ChangePlayerTeam(int client, int team)
{
	if(GetClientTeam(client) == team) return;
	
	if(team != L4D_TEAM_SURVIVORS)
	{
		ChangeClientTeam(client, team);
		return;
	}
	
	//for survivors its more tricky
	
	char command[] = "sb_takecontrol";
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	
	char botNames[][] = { "zoey", "louis", "bill", "francis" };
	
	int cTeam;
	cTeam = GetClientTeam(client);
	
	int i = 0;
	while(cTeam != L4D_TEAM_SURVIVORS && i < 4)
	{
		FakeClientCommand(client, "sb_takecontrol %s", botNames[i]);
		cTeam = GetClientTeam(client);
		i++;
	}

	SetCommandFlags(command, flags);
}



//when the match goes live, at round_end of the last automatic restart
//just before the round_start
void RoundEndBeforeLive()
{
	readyOff();	
}

//round_start just after the last automatic restart
void RoundIsLive()
{
	UnfreezeAllPlayers();
	
	CreateTimer(1.0, timerLiveMessageCallback, _, _);
}

void ToggleFreezePlayer(int client, int freeze)
{
	SetEntityMoveType(client, freeze ? MOVETYPE_NONE : MOVETYPE_WALK);
}

//client is in-game and not a bot
bool IsClientInGameHuman(int client)
{
	return IsClientInGame(client) && !IsFakeClient(client);
}

int CountInGameHumans()
{
	int i, realPlayers = 0;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i)) 
		{
			realPlayers++;
		}
	}
	return realPlayers;
}

public int GetAnyClient()
{
	int i;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if (IsClientConnected(i) && IsClientInGameHuman(i))
		{
			return i;
		}
	}
	return 0;
}


void DebugPrintToAll(const char[] format, any ...)
{
#if READY_DEBUG	|| READY_DEBUG_LOG
	char buffer[192];
	
	VFormat(buffer, sizeof(buffer), format, 2);
	
#if READY_DEBUG
	PrintToChatAll("[READY] %s", buffer);
#endif
	LogMessage("%s", buffer);
#else
	//suppress "format" never used warning
	if(format[0])
		return;
	else
		return;
#endif
}


#if HEALTH_BONUS_FIX
public Action Command_UpdateHealth(int client, int args)
{
	DelayedUpdateHealthBonus();
	
	return Plugin_Handled;
}

public Action Event_ItemPickup(Event event, const char[] name, bool dontBroadcast)
{	
	int player = GetClientOfUserId(GetEventInt(event, "userid"));
	
	char item[128];
	GetEventString(event, "item", item, sizeof(item));
	
	#if EBLOCK_DEBUG
	char curname[128];
	GetClientName(player,curname,128);
	
	if(strcmp(item, "pain_pills") == 0)		
		DebugPrintToAll("EVENT - Item %s picked up by %s [%d]", item, curname, player);
	#endif
	
	if(strcmp(item, "pain_pills") == 0)
	{
		painPillHolders[player] = true;
		DelayedPillUpdate();
	}
	
	return Plugin_Handled;
}

public Action Event_PillsUsed(Event event, const char[] name, bool dontBroadcast)
{	
	int player = GetClientOfUserId(GetEventInt(event, "userid"));
	
	#if EBLOCK_DEBUG
	int subject = GetClientOfUserId(GetEventInt(event, "subject"));
	
	char curname[128];
	GetClientName(player,curname,128);
	
	char curname_subject[128];
	GetClientName(subject,curname_subject,128);
	
	DebugPrintToAll("EVENT - %s [%d] used pills on subject %s [%d]", curname, player, curname_subject, subject);
	#endif
	
	painPillHolders[player] = false;
	
	return Plugin_Handled;
}



public Action Event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{	
	#if EBLOCK_DEBUG
	int player = GetClientOfUserId(GetEventInt(event, "userid"));
	int subject = GetClientOfUserId(GetEventInt(event, "subject"));
	
	char curname[128];
	GetClientName(player,curname,128);
	
	char curname_subject[128];
	GetClientName(subject,curname_subject,128);
	
	DebugPrintToAll("EVENT - %s [%d] healed %s [%d] successfully", curname, player, curname_subject, subject);
	#endif

	DelayedUpdateHealthBonus();
	
	return Plugin_Handled;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{	
	int i;
	for (i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		painPillHolders[i] = false;
	}
	
	return Plugin_Handled;
}


void DelayedUpdateHealthBonus()
{
	#if EBLOCK_USE_DELAYED_UPDATES
	CreateTimer(EBLOCK_BONUS_UPDATE_DELAY, Timer_DoUpdateHealthBonus, _, _);
	#else
	UpdateHealthBonus();
	#endif
	
	DebugPrintToAll("Delayed health bonus update");
}

public Action Timer_DoUpdateHealthBonus(Handle timer)
{
	UpdateHealthBonus();
	
	return Plugin_Stop;
}

void UpdateHealthBonus()
{
	int i;
	for (i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2) 
		{
			UpdateHealthBonusForClient(i);
		}
	}
}

void DelayedPillUpdate()
{
	#if EBLOCK_USE_DELAYED_UPDATES
	CreateTimer(EBLOCK_BONUS_UPDATE_DELAY, Timer_PillUpdate, _, _);
	#else
	UpdateHealthBonusForPillHolders();
	#endif
	
	DebugPrintToAll("Delayed pill bonus update");
}

public Action Timer_PillUpdate(Handle timer)
{
	UpdateHealthBonusForPillHolders();
	
	return Plugin_Stop;
}

void UpdateHealthBonusForPillHolders()
{
	int i;
	for (i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && painPillHolders[i]) 
		{
			UpdateHealthBonusForClient(i);
		}
	}
}

void UpdateHealthBonusForClient(int client)
{
	SendHurtMe(client);
}

void SendHurtMe(int i)
{	/*
	* when a person uses pills the m_healthBuffer gets set to 
	* minimum(50, 100-currentHealth)
	* 
	* it stays at that value until the person heals (or uses pills?)
	* or the round is over
	* 
	* once the m_healthBuffer property is non-0 the health bonus for that player
	* seems to keep updating
	* 
	* The first time we set it ourselves that player gets that much temp hp,
	* setting it afterwards crashes the server, and setting it after we set it
	* for the first time doesn't do anything.
	*/
	float healthBuffer = GetEntPropFloat(i, Prop_Send, "m_healthBuffer");
	
	DebugPrintToAll("Health buffer for player [%d] is %f", i, healthBuffer);	
	if(healthBuffer == 0.0)
	{
		SetEntPropFloat(i, Prop_Send, "m_healthBuffer", EBLOCK_BONUS_HEALTH_BUFFER);
		DebugPrintToAll("Health buffer for player [%d] set to %f", i, EBLOCK_BONUS_HEALTH_BUFFER);
	}
	
	DebugPrintToAll("Sent hurtme to [%d]", i);
}
#endif