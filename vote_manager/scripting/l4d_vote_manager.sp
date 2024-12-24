#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#define PLUGIN_VERSION  "1.4.5"
#define MSGTAG          "{green}[VoteManager]{default}"

#define VOTE_NONE       0
#define VOTE_POLLING    1
#define CUSTOM_ISSUE    "#L4D_TargetID_Player"

char votes[][] =
{
	"veto",
	"pass",
	"cooldown_immunity",
	"notify",
	"custom",
	"returntolobby",
	"restartgame",
	"changedifficulty",
	"changemission",
	"changechapter",
	"changealltalk",
	"restartgame",
	"kick",
	"kick_immunity"
};

enum VoteManager_Vote
{
	Voted_No = 0,
	Voted_Yes,
	Voted_CantVote,
	Voted_CanVote
};

ConVar g_hCreationTimer,
       g_hCvarCooldownMode,
       g_hCvarVoteCooldown,
       g_hCvarTankImmunity,
       g_hCvarRespectImmunity,
       g_hCvarLog;

int    g_iInitVal,
       g_iCustomTeam,
       g_iCvarCooldownMode,
       g_iCvarLog;

float  g_fCvarVoteCooldown,
       g_fLastVote,
       g_fNextVote[MAXPLAYERS + 1];

bool   g_bLeft4Dead2,
       g_bCustom,
       g_bCvarTankImmunity,
       g_bCvarRespectImmunity;

int    g_iVoteStatus;

char   g_sCaller[32],
       g_sIssue[128],
       g_sOption[128],
       g_sCmd[192];

char filepath[PLATFORM_MAX_PATH];
VoteManager_Vote iVote[MAXPLAYERS + 1] = { Voted_CantVote, ... };

public Plugin myinfo =
{
	name = "[L4D/2] Vote Manager",
	author = "McFlurry, Dosergen",
	description = "Vote manager for left 4 dead",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=1582772"
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
	CreateConVar("l4d_votemanager_version", PLUGIN_VERSION, "Version of Vote Manager", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	// Cooldown mode configuration:
	// 0 - Shared cooldown for all players;
	// 1 - Independent cooldown for each player.
	g_hCvarCooldownMode = CreateConVar("l4d_votemanager_cooldown_mode", "0", "Sets the cooldown mode for votes: 0 - for shared cooldown, 1 - for independent cooldown", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	// Duration in seconds before a player can initiate a new vote after their last vote.
	g_hCvarVoteCooldown = CreateConVar("l4d_votemanager_cooldown", "60.0", "Time (in seconds) a player must wait before calling another vote", FCVAR_NOTIFY, true, 0.0);

	// Tank immunity setting for kick votes:
	// 0 - Tanks can be voted out;
	// 1 - Tanks are immune to kick votes.
	g_hCvarTankImmunity = CreateConVar("l4d_votemanager_tank_immunity", "0", "Determines whether tanks are immune to kick votes: 0 - for no immunity, 1 - for immunity enabled", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	// Admin immunity respect in kick votes:
	// 0 - No respect for admin immunity levels;
	// 1 - Admin immunity levels respected during kick votes.
	g_hCvarRespectImmunity = CreateConVar("l4d_votemanager_respect_immunity", "1", "Defines if admin immunity levels are respected in kick votes: 0 - for no respect, 1 - for respect enabled", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	// Logging configuration options:
	// 1 - Log vote information to file;
	// 2 - Log vote information to the chat;
	// 3 - Log both to file and chat.
	g_hCvarLog = CreateConVar("l4d_votemanager_log", "3", "Sets the logging options for vote information: 1 - for file logging, 2 - for chat logging, 3 - for both", FCVAR_NOTIFY, true, 0.0, true, 3.0);

	g_hCreationTimer = FindConVar("sv_vote_creation_timer");
	g_iInitVal = g_hCreationTimer.IntValue;
	g_hCreationTimer.AddChangeHook(TimerChanged);

	GetCvars();

	g_hCvarCooldownMode.AddChangeHook(ConVarChanged);
	g_hCvarVoteCooldown.AddChangeHook(ConVarChanged);
	g_hCvarTankImmunity.AddChangeHook(ConVarChanged);
	g_hCvarRespectImmunity.AddChangeHook(ConVarChanged);
	g_hCvarLog.AddChangeHook(ConVarChanged);

	if (g_bLeft4Dead2)
	{
		HookUserMessage(GetUserMessageId("VotePass"), VoteResult);
		HookUserMessage(GetUserMessageId("VoteFail"), VoteResult);
	}
	else
	{
		HookEvent("vote_passed", vote_result);
		HookEvent("vote_failed", vote_result);
	}

	AddCommandListener(VoteStart, "callvote");
	AddCommandListener(VoteAction, "vote");

	RegConsoleCmd("sm_pass", Command_VotePassvote, "Force pass a current vote");
	RegConsoleCmd("sm_veto", Command_VoteVeto, "Force veto a current vote");
	RegConsoleCmd("sm_customvote", Command_CustomVote, "Start a custom vote");

	BuildPath(Path_SM, filepath, sizeof(filepath), "logs/vote_manager.log");
	LoadTranslations("l4d_vote_manager.phrases");
	AutoExecConfig(true, "l4d_vote_manager");
}

void ConVarChanged(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
	g_iCvarCooldownMode = g_hCvarCooldownMode.IntValue;
	g_fCvarVoteCooldown = g_hCvarVoteCooldown.FloatValue;
	g_bCvarTankImmunity = g_hCvarTankImmunity.BoolValue;
	g_bCvarRespectImmunity = g_hCvarRespectImmunity.BoolValue;
	g_iCvarLog = g_hCvarLog.IntValue;
}

void TimerChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_hCreationTimer.SetInt(0);
}

public void OnMapStart()
{
	g_hCreationTimer.SetInt(0);
	g_iVoteStatus = VOTE_NONE;
	g_bCustom = false;
}

public void OnPluginEnd()
{
	g_hCreationTimer.SetInt(g_iInitVal);
}

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client))
		return;
	int userid = GetClientUserId(client);
	CreateTimer(5.0, TransitionCheck, userid);
	iVote[client] = Voted_CantVote;
	VoteManagerUpdateVote();
}

Action VoteAction(int client, const char[] command, int argc)
{
	if (client == 0)
		return Plugin_Handled;
	if (argc == 1 
		&& iVote[client] == Voted_CanVote 
		&& client != 0 
		&& g_iVoteStatus == VOTE_POLLING)
	{
		char vote[5];
		GetCmdArg(1, vote, sizeof(vote));
		if (StrEqual(vote, "yes", false))
		{
			iVote[client] = Voted_Yes;
			VoteManagerUpdateVote();
			return Plugin_Continue;
		}
		else if (StrEqual(vote, "no", false))
		{
			iVote[client] = Voted_No;
			VoteManagerUpdateVote();
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

Action VoteStart(int client, const char[] command, int argc)
{
	if (GetServerClientCount(true) == 0 || client == 0 || IsFakeClient(client))
		return Plugin_Handled;
	if (argc <= 0)
		return Plugin_Continue;
	float flEngineTime = GetEngineTime();
	GetCmdArg(1, g_sIssue, sizeof(g_sIssue));
	if (argc == 2)
		GetCmdArg(2, g_sOption, sizeof(g_sOption));
	VoteStringsToLower();
	Format(g_sCaller, sizeof(g_sCaller), "%N", client);
	if ((ClientHasAccess(client, "cooldown_immunity") 
		|| g_fNextVote[client] <= flEngineTime) 
		&& g_iVoteStatus == VOTE_NONE)
	{
		if (flEngineTime - g_fLastVote <= 5.5)
			return Plugin_Handled;
		if (ClientHasAccess(client, g_sIssue))
		{
			if (StrEqual(g_sIssue, "custom", false))
			{
				ReplyToCommand(client, "%s %T", MSGTAG, "Use sm_customvote", client);
				return Plugin_Handled;
			}
			else if (StrEqual(g_sIssue, "kick", false))
				return ClientCanKick(client, g_sOption);
			DataPack hPack = new DataPack();
			hPack.WriteCell(argc);
			hPack.WriteCell(GetClientUserId(client));
			RequestFrame(NextFrame_CallVote, hPack);
			return Plugin_Continue;
		}
		else
		{
			LogVoteManager("%T", "No Vote Access", LANG_SERVER, g_sCaller, g_sIssue);
			VoteManagerNotify(client, "%s %t", MSGTAG, "No Vote Access", g_sCaller, g_sIssue);
			VoteLogAction(client, -1, "'%L' callvote denied (reason 'no access')", client);
			ClearVoteStrings();
			return Plugin_Handled;
		}
	}
	else if (g_iVoteStatus == VOTE_POLLING)
	{
		CPrintToChat(client, "%s %T", MSGTAG, "Conflict", client);
		VoteLogAction(client, -1, "'%L' callvote denied (reason 'vote already called')", client);
		ClearVoteStrings();
		return Plugin_Handled;
	}
	else if (g_fNextVote[client] > flEngineTime)
	{
		CPrintToChat(client, "%s %T", MSGTAG, "Wait", client, RoundToNearest(g_fNextVote[client] - flEngineTime));
		VoteLogAction(client, -1, "'%L' callvote denied (reason 'timeout')", client);
		ClearVoteStrings();
		return Plugin_Handled;
	}
	else
	{
		ClearVoteStrings();
		return Plugin_Handled;
	}
}

void NextFrame_CallVote(DataPack hPack)
{
	hPack.Reset();
	int argc = hPack.ReadCell();
	int client = GetClientOfUserId(hPack.ReadCell());
	delete hPack;
	if (!client || !IsClientInGame(client))
		return;
	if (argc == 2)
	{
		LogVoteManager("%T", "Vote Called 2 Arguments", LANG_SERVER, g_sCaller, g_sIssue, g_sOption);
		VoteManagerNotify(client, "%s %t", MSGTAG, "Vote Called 2 Arguments", g_sCaller, g_sIssue, g_sOption);
		VoteLogAction(client, -1, "'%L' callvote (issue '%s') (option '%s')", client, g_sIssue, g_sOption);
	}
	else
	{
		LogVoteManager("%T", "Vote Called", LANG_SERVER, g_sCaller, g_sIssue);
		VoteManagerNotify(client, "%s %t", MSGTAG, "Vote Called", g_sCaller, g_sIssue);
		VoteLogAction(client, -1, "'%L' callvote (issue '%s')", client, g_sIssue);
	}
	VoteManagerPrepareVoters(0);
	VoteManagerHandleCooldown(client);
	g_iVoteStatus = VOTE_POLLING;
	g_fLastVote = GetEngineTime();
}

Action VoteResult(UserMsg msg_id, BfRead bf, const int[] players, int playersNum, bool reliable, bool init)
{
	bool Message_Passed = (msg_id == GetUserMessageId("VotePass"));
	LogVoteManager("%T", Message_Passed ? "Vote Passed" : "Vote Failed", LANG_SERVER);
	VoteLogAction(-1, -1, Message_Passed ? "callvote (verdict 'passed')" : "callvote (verdict 'failed')");
	ClearVoteStrings();
	g_iVoteStatus = VOTE_NONE;
	return Plugin_Continue;
}

void vote_result(Event event, const char[] name, bool dontBroadcast)
{
	bool Event_Passed = (StrEqual(name, "vote_passed"));
	LogVoteManager("%T", Event_Passed ? "Vote Passed" : "Vote Failed", LANG_SERVER);
	VoteLogAction(-1, -1, Event_Passed ? "callvote (verdict 'passed')" : "callvote (verdict 'failed')");
	ClearVoteStrings();
	g_iVoteStatus = VOTE_NONE;
}

Action Command_VoteVeto(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;
	if (g_iVoteStatus == VOTE_POLLING && ClientHasAccess(client, "veto"))
	{
		int yesvoters = VoteManagerGetVotedAll(Voted_Yes);
		int undecided = VoteManagerGetVotedAll(Voted_CanVote);
		if (undecided * 2 > yesvoters)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				VoteManager_Vote info = VoteManagerGetVoted(i);
				if (info == Voted_CanVote)
					VoteManagerSetVoted(i, Voted_No);
			}
		}
		else
		{
			LogVoteManager("%T", "Cant VetoPass", LANG_SERVER, client);
			CPrintToChat(client, "%s %T", MSGTAG, "Cant Veto", client);
			VoteLogAction(client, -1, "'%L' sm_veto ('not enough undecided players')", client);
			return Plugin_Handled;
		}
		LogVoteManager("%T", "Vetoed", LANG_SERVER, client);
		CPrintToChatAll("%s %t", MSGTAG, "Vetoed", client);
		VoteLogAction(client, -1, "'%L' sm_veto ('allowed')", client);
		g_iVoteStatus = VOTE_NONE;
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(client, "%s %T", MSGTAG, "No Vote", client);
		VoteLogAction(client, -1, "'%L' sm_veto ('no vote')", client);
		return Plugin_Handled;
	}
}

Action Command_VotePassvote(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;
	if (g_iVoteStatus == VOTE_POLLING && ClientHasAccess(client, "pass"))
	{
		int novoters = VoteManagerGetVotedAll(Voted_No);
		int undecided = VoteManagerGetVotedAll(Voted_CanVote);
		if (undecided * 2 > novoters)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				VoteManager_Vote info = VoteManagerGetVoted(i);
				if (info == Voted_CanVote)
					VoteManagerSetVoted(i, Voted_Yes);
			}
		}
		else
		{
			LogVoteManager("%T", "Cant VetoPass", LANG_SERVER, client);
			CPrintToChat(client, "%s %T", MSGTAG, "Cant Pass", client);
			VoteLogAction(client, -1, "'%L' sm_veto ('not enough undecided players')", client);
			return Plugin_Handled;
		}
		LogVoteManager("%T", "Passed", LANG_SERVER, client);
		CPrintToChatAll("%s %t", MSGTAG, "Passed", client);
		VoteLogAction(client, -1, "'%L' sm_pass ('allowed')", client);
		g_iVoteStatus = VOTE_NONE;
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(client, "%s %T", MSGTAG, "No Vote", client);
		VoteLogAction(client, -1, "'%L' sm_pass ('no vote')", client);
		return Plugin_Handled;
	}
}

Action Command_CustomVote(int client, int args)
{
	if (GetServerClientCount(true) == 0)
		return Plugin_Handled;
	float flEngineTime = GetEngineTime();
	if ((ClientHasAccess(client, "cooldown_immunity") 
		|| g_fNextVote[client] <= flEngineTime) 
		&& g_iVoteStatus == VOTE_NONE 
		&& args >= 2 
		&& ClientHasAccess(client, "custom"))
	{
		char arg1[5];
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, g_sOption, sizeof(g_sOption));
		if (args == 3)
			GetCmdArg(3, g_sCmd, sizeof(g_sCmd));
		Format(g_sCaller, sizeof(g_sCaller), "%N", client);
		LogVoteManager("%T", "Custom Vote", LANG_SERVER, client, arg1, g_sOption, g_sCmd);
		VoteManagerNotify(client, "%s %t", MSGTAG, "Custom Vote", client, arg1, g_sOption, g_sCmd);
		VoteLogAction(client, -1, "'%L' callvote custom started for team: %s (issue: '%s' cmd: '%s')", client, arg1, g_sOption, g_sCmd);
		g_fLastVote = flEngineTime;
		g_iVoteStatus = VOTE_POLLING;
		g_iCustomTeam = StringToInt(arg1);
		VoteManagerPrepareVoters(g_iCustomTeam); 
		VoteManagerHandleCooldown(client);
		DataPack hPack = new DataPack();
		hPack.WriteCell(GetClientUserId(client));
		hPack.WriteString(g_sOption);
		hPack.WriteString(g_sCmd);
		hPack.WriteCell(g_iCustomTeam);
		RequestFrame(NextFrame_CreateVote, hPack);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

void NextFrame_CreateVote(DataPack hPack)
{
	hPack.Reset();
	int client = GetClientOfUserId(hPack.ReadCell());
	hPack.ReadString(g_sOption, sizeof(g_sOption));
	hPack.ReadString(g_sCmd, sizeof(g_sCmd));
	g_iCustomTeam = hPack.ReadCell();
	delete hPack;
	g_iCustomTeam = (g_iCustomTeam == 0) ? 255 : g_iCustomTeam;
	g_bCustom = true;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (g_iCustomTeam != 255 && GetClientTeam(i) != g_iCustomTeam)
				continue;
			if (g_bLeft4Dead2)
			{
				BfWrite bf = UserMessageToBfWrite(StartMessageOne("VoteStart", i, USERMSG_RELIABLE));
				bf.WriteByte(g_iCustomTeam);
				bf.WriteByte(client);
				bf.WriteString(CUSTOM_ISSUE);
				bf.WriteString(g_sOption);
				bf.WriteString(g_sCaller);
				EndMessage();
			}
			else
			{
				Event event = CreateEvent("vote_started");
				event.SetString("issue", CUSTOM_ISSUE);
				event.SetString("param1", g_sOption);
				event.SetString("param2", g_sCaller);
				event.SetInt("team", g_iCustomTeam);
				event.SetInt("initiator", client);
				event.Fire();
			}
		}
	}
	float voteDuration = float(FindConVar("sv_vote_timer_duration").IntValue);
	CreateTimer(voteDuration, CustomVerdict, _, TIMER_FLAG_NO_MAPCHANGE);	
	VoteManagerSetVoted(client, Voted_Yes);
	VoteManagerUpdateVote();
}

Action CustomVerdict(Handle Timer)
{
	if (!g_bCustom)
		return Plugin_Stop;
	int yes = VoteManagerGetVotedAll(Voted_Yes);
	int no = VoteManagerGetVotedAll(Voted_No);
	int numPlayers;
	int players[MAXPLAYERS + 1];
	g_bCustom = false;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && VoteManagerGetVoted(i) != Voted_CantVote)
		{
			if (g_iCustomTeam != 255 && GetClientTeam(i) != g_iCustomTeam)
				continue;	
			players[numPlayers] = i;
			numPlayers++;
		}
	}
	bool confirmed = (yes > no);
	if (confirmed)
	{
		if (strlen(g_sCmd) > 0)
		{
			int client = GetClientByName(g_sCaller);
			if (client > 0)
				FakeClientCommand(client, g_sCmd);
			else if (client == 0)
				ServerCommand(g_sCmd);
		}
	}
	char logMessage[64];
	Format(logMessage, sizeof(logMessage), "%T", confirmed ? "Custom Passed" : "Custom Failed", LANG_SERVER, g_sCaller, g_sOption);
	LogVoteManager("%s", logMessage);
	VoteLogAction(-1, -1, confirmed ? "sm_customvote (verdict: 'passed')" : "sm_customvote (verdict: 'failed')");
	if (g_bLeft4Dead2)
	{
		Handle message = StartMessage(confirmed ? "VotePass" : "VoteFail", players, numPlayers, USERMSG_RELIABLE);
		BfWrite bf = UserMessageToBfWrite(message);
		bf.WriteByte(g_iCustomTeam);
		g_iCustomTeam = 0;
		if (confirmed)
		{
			bf.WriteString(CUSTOM_ISSUE);
			char votepassed[128];
			Format(votepassed, sizeof(votepassed), "%T", "Custom Vote Passed", LANG_SERVER);
			bf.WriteString(votepassed);
		}
		EndMessage();
	}
	else
	{
		Event event = CreateEvent(confirmed ? "vote_passed" : "vote_failed");
		event.SetInt("team", g_iCustomTeam);
		g_iCustomTeam = 0;
		if (confirmed)
		{
			event.SetString("issue", CUSTOM_ISSUE);
			char votepassed[128];
			Format(votepassed, sizeof(votepassed), "%T", "Custom Vote Passed", LANG_SERVER);
			event.SetString("param1", votepassed);
		}
		event.Fire();
	}
	return Plugin_Stop;
}

stock int GetClientByName(const char[] name)
{
	char iname[32];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			Format(iname, sizeof(iname), "%N", i);
			if (StrEqual(name, iname, true))
				return i;
		}
	}
	Format(iname, sizeof(iname), "%N", 0);
	if (StrEqual(name, iname, true))
		return 0;
	return -1;
}

Action TransitionCheck(Handle Timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client == 0)
		g_fNextVote[client] == 0.0;
	return Plugin_Stop;
}

bool ClientHasAccess(int client, const char[] issuee)
{
	if (!IsValidVoteType(issuee))
	{
		static char steam64[64];
		GetClientAuthId(client, AuthId_SteamID64, steam64, sizeof(steam64));
		LogVoteManager("%T", "Client Exploit Attempt", LANG_SERVER, client, steam64, issuee);
		VoteLogAction(client, -1, "'%L' (Steam ID: %s) call invalid vote exploit attempted (Votetype: '%s')", client, steam64, issuee);
	}
	return CheckCommandAccess(client, issuee, 0, true);
}

bool IsValidVoteType(const char[] issuee)
{
	for (int i = 0; i < sizeof(votes); i++)
	{
		if (StrEqual(issuee, votes[i]))
			return true;
	}
	return false;
}

Action ClientCanKick(int client, const char[] userid)
{
	if (strlen(userid) < 1 || client == 0)
	{
		ClearVoteStrings();
		return Plugin_Handled;
	}
	int target = GetClientOfUserId(StringToInt(userid));
	int cTeam = GetClientTeam(client);
	if (0 >= target || target > MaxClients || !IsClientInGame(target))
	{
		LogVoteManager("%T", "Invalid Kick Userid", LANG_SERVER, client, userid);
		VoteManagerNotify(client, "%s %t", MSGTAG, "Invalid Kick Userid", client, userid);
		VoteLogAction(client, -1, "'%L' callvote kick denied (reason: 'invalid userid<%d>')", client, StringToInt(userid));
		ClearVoteStrings();
		return Plugin_Handled;
	}
	if (g_bCvarTankImmunity && IsPlayerAlive(target) && cTeam == 3 && TankClass(target))
	{
		LogVoteManager("%T", "Tank Immune Response", LANG_SERVER, client, target);
		VoteManagerNotify(client, "%s %t", MSGTAG, "Tank Immune Response", client, target);
		VoteLogAction(client, -1, "'%L' callvote kick denied (reason: '%L has tank immunity')", client, target);
		ClearVoteStrings();
		return Plugin_Handled;
	}
	if (cTeam == 1)
	{
		LogVoteManager("%T", "Spectator Response", LANG_SERVER, client, target);
		VoteManagerNotify(client, "%s %t", MSGTAG, "Spectator Response", client, target);
		VoteLogAction(client, -1, "'%L' callvote kick denied (reason: 'spectators have no kick access')", client);
		ClearVoteStrings();
		return Plugin_Handled;
	}
	AdminId id = GetUserAdmin(client);
	AdminId targetid = GetUserAdmin(target);
	if (g_bCvarRespectImmunity && id != INVALID_ADMIN_ID && targetid != INVALID_ADMIN_ID)
	{
		if (!CanAdminTarget(id, targetid))
		{
			LogVoteManager("%T", "Kick Vote Call Failed", LANG_SERVER, client, target);
			VoteManagerNotify(client, "%s %t", MSGTAG, "Kick Vote Call Failed", client, target);
			VoteLogAction(client, -1, "'%L' callvote kick denied (reason: '%L has higher immunity')", client, target);
			ClearVoteStrings();
			return Plugin_Handled;
		}
	}
	if (CheckCommandAccess(target, "kick_immunity", 0, true) && !CheckCommandAccess(client, "kick_immunity", 0, true))
	{
		LogVoteManager("%T", "Kick Immunity", LANG_SERVER, client, target);
		VoteManagerNotify(client, "%s %t", MSGTAG, "Kick Immunity", client, target);
		VoteLogAction(client, -1, "'%L' callvote kick denied (reason: '%L has kick vote immunity')", client, target);
		ClearVoteStrings();
		return Plugin_Handled;
	}
	DataPack hPack = new DataPack();
	hPack.WriteCell(GetClientUserId(client));
	hPack.WriteCell(GetClientUserId(target));
	hPack.WriteCell(cTeam);
	RequestFrame(NextFrame_KickVote, hPack);
	return Plugin_Continue;
}

void NextFrame_KickVote(DataPack hPack)
{
	hPack.Reset();
	int client = GetClientOfUserId(hPack.ReadCell());
	int target = GetClientOfUserId(hPack.ReadCell());
	int cTeam = hPack.ReadCell();
	delete hPack;
	if ((!client || !IsClientInGame(client)) || (!target || !IsClientInGame(target)))
		return;
	LogVoteManager("%T", "Kick Vote", LANG_SERVER, client, target);
	VoteManagerNotify(client, "%s %t", MSGTAG, "Kick Vote", client, target);
	VoteLogAction(client, -1, "'%L' callvote kick started (kickee: '%L')", client, target);
	VoteManagerPrepareVoters(cTeam);
	VoteManagerHandleCooldown(client);
	g_iVoteStatus = VOTE_POLLING;
	g_fLastVote = GetEngineTime();
}

bool TankClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass") == (g_bLeft4Dead2 ? 8 : 5);
}

void VoteManagerHandleCooldown(int client)
{
	float time = GetEngineTime();
	float cooldownTime = time + g_fCvarVoteCooldown;
	if (g_iCvarCooldownMode == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
				g_fNextVote[i] = cooldownTime;
		}
	}
	else if (g_iCvarCooldownMode == 1)
		g_fNextVote[client] = cooldownTime;
}

void VoteManagerUpdateVote()
{
	if (!g_bCustom)
		return;
	int undecided = VoteManagerGetVotedAll(Voted_CanVote);
	int yes = VoteManagerGetVotedAll(Voted_Yes);
	int no = VoteManagerGetVotedAll(Voted_No);
	int total = yes + no + undecided;
	Event event = CreateEvent("vote_changed");
	event.SetInt("yesVotes", yes);
	event.SetInt("noVotes", no);
	event.SetInt("potentialVotes", total);
	event.Fire();
	if (no == total || yes == total || yes + no == total)
		CreateTimer(1.0, CustomVerdict, _, TIMER_FLAG_NO_MAPCHANGE);
}

void VoteManagerSetVoted(int client, VoteManager_Vote vote)
{
	if (vote > Voted_Yes || client == 0)
		return;
	else
	{
		switch (vote)
		{
			case Voted_Yes:
				FakeClientCommand(client, "Vote Yes");
			case Voted_No:
				FakeClientCommand(client, "Vote No");
		}
		iVote[client] = vote;
	}
}

VoteManager_Vote VoteManagerGetVoted(int client)
{
	return iVote[client];
}

int VoteManagerGetVotedAll(VoteManager_Vote vote)
{
	int total;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (VoteManagerGetVoted(i) == vote)
			total++;
	}
	return total;
}

void VoteManagerPrepareVoters(int team)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (team == 0)
				iVote[i] = Voted_CanVote;
			else if (GetClientTeam(i) == team)
				iVote[i] = Voted_CanVote;
		}
		else
			iVote[i] = Voted_CantVote;
	}
}

void ClearVoteStrings()
{
	Format(g_sIssue, sizeof(g_sIssue), "");
	Format(g_sOption, sizeof(g_sOption), "");
	Format(g_sCaller, sizeof(g_sCaller), "");
	Format(g_sCmd, sizeof(g_sCmd), "");
}

void VoteStringsToLower()
{
	StringToLower(g_sIssue, strlen(g_sIssue));
	StringToLower(g_sOption, strlen(g_sOption));
}

void StringToLower(char[] string, int stringlength)
{
	int maxlength = stringlength + 1;
	char[] buffer = new char[maxlength], sChar = new char[maxlength];
	Format(buffer, maxlength, string);
	for (int i; i <= stringlength; i++)
	{
		Format(sChar, maxlength, buffer[i]);
		if (strlen(buffer[i + 1]) > 0)
			ReplaceString(sChar, maxlength, buffer[i + 1], "");
		if (IsCharUpper(sChar[0]))
		{
			sChar[0] += 0x20;
			Format(sChar, maxlength, "%s%s", sChar, buffer[i+1]);
			ReplaceString(buffer, maxlength, sChar, sChar, false);
		}
	}
	Format(string, maxlength, buffer);
}

int GetServerClientCount(bool filterbots = false)
{
	int total;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			total++;
			if (IsFakeClient(i) && filterbots) total--;
		}
	}
	return total;
}

void VoteLogAction(int client, int target, const char[] message, any ...)
{
	if (g_iCvarLog < 2)
		return;
	char buffer[512];
	VFormat(buffer, sizeof(buffer), message, 4);
	LogAction(client, target, buffer);
}

void VoteManagerNotify(int client, const char[] message, any ...)
{
	static char buffer[256];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && i != client && !IsFakeClient(i))
		{
			if (CheckCommandAccess(i, "notify", 0, true))
			{
				SetGlobalTransTarget(i);
				VFormat(buffer, sizeof(buffer), message, 3);
				CPrintToChat(i, buffer);
			}
		}
	}
}

void LogVoteManager(const char[] log, any ...)
{
	if (g_iCvarLog < 1)
		return;
	char buffer[256], time[64];
	FormatTime(time, sizeof(time), "%x %X");
	VFormat(buffer, sizeof(buffer), log, 2);
	Format(buffer, sizeof(buffer), "[%s] %s", time, buffer);
	File file = OpenFile(filepath, "a");
	if (file)
	{
		ReplaceString(buffer, sizeof(buffer), "{default}", "", false);
		ReplaceString(buffer, sizeof(buffer), "{white}", "", false);
		ReplaceString(buffer, sizeof(buffer), "{cyan}", "", false);
		ReplaceString(buffer, sizeof(buffer), "{lightgreen}", "", false);
		ReplaceString(buffer, sizeof(buffer), "{orange}", "", false);
		ReplaceString(buffer, sizeof(buffer), "{green}", "", false);
		ReplaceString(buffer, sizeof(buffer), "{olive}", "", false);
		WriteFileLine(file, buffer);
		FlushFile(file);
		delete file;
	}
	else
		LogError("%T", "Log Error", LANG_SERVER);
}