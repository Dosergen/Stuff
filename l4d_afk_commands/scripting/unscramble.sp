/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 (R2CompMod) project.
 * See https://github.com/raziEiL/rotoblin2
 *
 *  Language:       SourcePawn.
 *  Description:	Puts players on the right team after map/campaign change and provides API.
 *  Credits:		Scratchy [Царапка] for idea.
 *
 *  Copyright (C) 2012-2015, 2020 raziEiL [disawar1] <mr.raz4291@gmail.com>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 */
#define PLUGIN_VERSION "1.1"

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

#define UNSCRABBLE_LOG 0
#define MAIN_TAG				"[Unscramble]"

#define VOTE_MISSION_CHANGE "#L4D_vote_passed_mission_change"
#define VOTE_LEVEL_RESTART "#L4D_vote_passed_versus_level_restart"

#if UNSCRABBLE_LOG
static const char g_LogFile[] = "logs\\rotoblin_unscramble.log";
static char g_sLogPatch[128];
#endif

static Handle g_hTrine, g_fwdOnUnscrambleEnd;
bool g_bCvarUnlocker, g_bCvarEnabled, g_bCvarNotify, g_bCvarNoVotes;
int g_iCvarAttempts, g_iFailureCount[MAXPLAYERS+1], g_isOldTeamFlipped, g_isNewTeamFlipped, g_iTrineSize; 
bool g_bCheked[MAXPLAYERS+1], g_bJoinTeamUsed[MAXPLAYERS+1], g_bMapTranslition, g_bTeamLock;
UserMsg g_iVotePassMessageId;
float g_fCvarTime;

public Plugin myinfo =
{
	name = "[L4D & L4D2] Unscramble (R2CompMod Standalone)",
	author = "raziEiL [disawar1]",
	description = "Puts players on the right team after map/campaign change and provides API.",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/raziEiL"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("r2comp_unscramble");
	CreateNative("R2comp_UnscrambleStart", Native_R2comp_UnscrambleStart);
	CreateNative("R2comp_UnscrambleKeep", Native_R2comp_UnscrambleKeep);
	CreateNative("R2comp_IsUnscrambled", Native_R2comp_IsUnscrambled);
	CreateNative("R2comp_AbortUnscramble", Native_R2comp_AbortUnscramble);
	return APLRes_Success;
}

public void OnPluginStart()
{
	#if UNSCRABBLE_LOG
		BuildPath(Path_SM, g_sLogPatch, 128, g_LogFile);
	#endif
	LoadTranslations("rotoblin.phrases");

	g_hTrine = CreateTrie();
	g_fwdOnUnscrambleEnd = CreateGlobalForward("R2comp_OnUnscrambleEnd", ET_Ignore);
	g_iVotePassMessageId = GetUserMessageId("VotePass");

	CreateConVar("rotoblin_unscramble_version", PLUGIN_VERSION, "R2CompMod Unscramble Standalone plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	ConVar cVar;
	cVar = CreateConVar("rotoblin_unscramble_notify", "1", "0=Off, 1=Prints a notification to chat when unscramble is completed (lets spectators know when they can join a team).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarNotify = GetConVarBool(cVar);
	HookConVarChange(cVar, OnCvarChange_Notify);

	cVar = CreateConVar("rotoblin_choosemenu_unlocker", "1", "0=Off, 1=Allows spectator/infected players to join the survivor team even if the survivor bot is dead (through M button).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarUnlocker = GetConVarBool(cVar);
	HookConVarChange(cVar, OnCvarChange_Unlocker);

	cVar = CreateConVar("rotoblin_unscramble_novotes", "1", "0=Off, 1=Prevents calling votes until unscramble completes.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarNoVotes = GetConVarBool(cVar);
	HookConVarChange(cVar, OnCvarChange_NoVotes);

	cVar = CreateConVar("rotoblin_unscramble_attempts", "3", "Maximum attempts to try to move player to the team he were.", FCVAR_NOTIFY, true, 1.0, true, 6.0);
	g_iCvarAttempts = GetConVarInt(cVar);
	HookConVarChange(cVar, OnCvarChange_Attempts);

	cVar = CreateConVar("rotoblin_unscramble_time", "45", "Unscramble max processing time after map changed. When the time expires the teams changes will be unlocked.", FCVAR_NOTIFY, true, 15.0);
	g_fCvarTime = GetConVarFloat(cVar);
	HookConVarChange(cVar, OnCvarChange_Time);

	cVar = CreateConVar("rotoblin_allow_unscramble", "1", "0=Off, 1=Enables unscramble feature (Puts players on the right team after map/campaign change).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarEnabled = GetConVarBool(cVar);
	UM_OnPluginEnabled();
	HookConVarChange(cVar, OnCvarChange_Enabled);

	AutoExecConfig(true, "unscramble");
	AddCommandListener(US_cmdh_JoinTeam, "jointeam");

	RegAdminCmd("sm_keepteams", Command_KeepTeams, ADMFLAG_ROOT, "Force to store players team data.");
	RegAdminCmd("sm_unscramble_start", Command_UnscrambleStart, ADMFLAG_ROOT, "Force to puts players on the right team.");
	RegAdminCmd("sm_unscramble_abort", Command_UnscrambleAbort, ADMFLAG_ROOT, "Aborts unscramble process.");
}

void UM_OnPluginEnabled()
{
	if (!g_bCvarEnabled){
	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "unscramble cvar is disabled");
		PrintToServer("%s unscramble cvar is disabled", MAIN_TAG);
	#endif
		return;
	}
	if (g_bCvarNoVotes){

		AddCommandListener(US_cmdh_Vote, "callvote");
		AddCommandListener(US_cmdh_Vote, "vote");

		if (g_iVotePassMessageId != INVALID_MESSAGE_ID)
			HookUserMessage(g_iVotePassMessageId, US_msg_OnVotePass);
	}
	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "unscramble is enabled");
		PrintToServer("%s unscramble is enabled", MAIN_TAG);
	#endif

	HookEvent("round_end", US_ev_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("vote_passed", US_ev_VotePassed);
}

void UM_OnPluginDisabled()
{
	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "unscramble is disabled");
		PrintToServer("%s unscramble is disabled", MAIN_TAG);
	#endif

	if (!g_bCvarEnabled) return;

	if (g_bCvarNoVotes){

		RemoveCommandListener(US_cmdh_Vote, "callvote");
		RemoveCommandListener(US_cmdh_Vote, "vote");

		if (g_iVotePassMessageId != INVALID_MESSAGE_ID)
			UnhookUserMessage(g_iVotePassMessageId, US_msg_OnVotePass);
	}

	UnhookEvent("round_end", US_ev_RoundEnd, EventHookMode_PostNoCopy);
	UnhookEvent("vote_passed", US_ev_VotePassed);
}

Action Command_KeepTeams(int client, int args)
{
	US_KeepTeams();
	return Plugin_Handled;
}

Action Command_UnscrambleStart(int client, int args)
{
	US_StartProcess();
	return Plugin_Handled;
}

Action Command_UnscrambleAbort(int client, int args)
{
	US_AbortProcess();
	return Plugin_Handled;
}

Action US_cmdh_Vote(int client, const char[] command, int argc)
{
	if (g_bTeamLock){

		if (GetClientTeam(client) != 1)
			PrintToChat(client, "%s %t", MAIN_TAG, "R2CompMod #24");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

Action US_cmdh_JoinTeam(int client, const char[] command, int argc)
{
	if (g_bTeamLock && !g_bJoinTeamUsed[client]){

		#if UNSCRABBLE_LOG
			LogToFile(g_sLogPatch, "%N use '%s' cmd, but blocked!", client, command);
		#endif

		return Plugin_Handled;
	}

	if (g_bCvarUnlocker){

		char sAgr[32];
		GetCmdArg(1, sAgr, 32);

		if (/*only chooseteam menu!*/StrEqual(sAgr, "survivor", false) && GetClientTeam(client) != 2){
			#if UNSCRABBLE_LOG
				LogToFile(g_sLogPatch, "%N use '%s' cmd, args '%s'", client, command, sAgr);
			#endif

			for (int i = 1; i <= MaxClients; i++){
				if (IsSurvivor(i) && IsFakeClient(i) && IsPlayerAlive(i))
					return Plugin_Continue;
			}

			char sSurvivor[16];
			bool bAnyBot;

			for (int i = 1; i <= MaxClients; i++){
				if (!IsSurvivor(i) || IsPlayerAlive(i) || !IsFakeClient(i)) continue;

				bAnyBot = true;

				if (!GetCharacterName(i, SZF(sSurvivor)))
					return Plugin_Continue;

				break;
			}

			if (!bAnyBot) return Plugin_Continue;

			CheatCommandEx(client, "sb_takecontrol", sSurvivor);

			#if UNSCRABBLE_LOG
				LogToFile(g_sLogPatch, "[chooseteam] %N trying to join survivor (%s) (%s)", client, sSurvivor, GetClientTeam(client) == 2 ? "Okay" : "Fail");
			#endif

			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

void US_ev_VotePassed(Event event, const char[] sName, bool DontBroadCast)
{
	char sDetals[128];
	GetEventString(event, "details", sDetals, 128);

	if (StrEqual(sDetals, VOTE_MISSION_CHANGE))
		US_KeepTeams();
}

public Action US_msg_OnVotePass(UserMsg msg_id, BfRead message, const int[] players, int playersNum, bool reliable, bool init)
{
	char sIssue[40];
	message.ReadByte();
	message.ReadString(SZF(sIssue));

	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "VotePass Usermessage: issue: %s", sIssue);
	#endif

	if (StrEqual(VOTE_MISSION_CHANGE, sIssue) || StrEqual(VOTE_LEVEL_RESTART, sIssue))
		US_KeepTeams();

	return Plugin_Continue;
}

//public Action:OnLogAction(Handle:source, Identity:ident, client, target, const String:message[])
//{
//	if (g_bCvarEnabled && StrContains(message, "changed map to") != -1)
//		US_KeepTeams();
//}

/*
 * ---------------------------
 *		Forwards
 * ---------------------------
*/
public void L4DReady_OnRoundIsLive()
{
	US_ForceToUnlockTeams();
}
// ---- ;

public void OnMapStart()
{
	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "--------- MapStart ---------");
	#endif
	for (int i = IsL4DGameEx() ? L4D_SURVIVOR_CHARACTER_OFFSET : 0; i < SC_SIZE; i++){
		PrecacheModel(L4D2_LIB_SURVIVOR_MDL[i], true);
	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "Precache %s", L4D2_LIB_SURVIVOR_MDL[i]);
	#endif
	}
	g_bMapTranslition = false;
	CreateTimer(0.5, US_t_TeamsFlipped);
	US_Start();
}

Action US_t_TeamsFlipped(Handle timer)
{
	US_UpdateTeamFlipped();
	return Plugin_Continue;
}

void US_UpdateTeamFlipped()
{
	g_isNewTeamFlipped = GameRules_GetProp("m_bAreTeamsFlipped");
}

bool US_Start()
{
	if (!g_iTrineSize)
		return false;

	g_bTeamLock = true;

	CreateTimer(5.0, US_t_CheckConnected, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(g_fCvarTime, US_t_AllowTeamChanges, _, TIMER_FLAG_NO_MAPCHANGE);
	return true;
}

void US_StartProcess()
{
	if (US_Start()){
		US_UpdateTeamFlipped();

		for (int i = 1; i <= MaxClients; i++){
			if (IsClientInGame(i))
				OnClientPutInServer(i);
		}
	}
}

void US_ev_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (GameRules_GetProp("m_bInSecondHalfOfRound") && !g_bMapTranslition)
		US_KeepTeams();
}

void US_KeepTeams()
{
	if (!g_bCvarEnabled) return;
	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "KeepTeams");
	#endif

	g_bTeamLock = false;
	g_bMapTranslition = true;
	g_isOldTeamFlipped = GameRules_GetProp("m_bAreTeamsFlipped");
	ClearTrie(g_hTrine);

	bool bInGame;
	char sSteamID[32];
	int iTeam;
	bool bConnectedOnly = true;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (((!(bInGame = IsClientInGame(i)) && IsClientConnected(i)) || bInGame) && !IsFakeClient(i))
		{
			if (GetClientAuthId(i, AuthId_Steam2, sSteamID, 32))
			{
				iTeam = 1;

				if (bInGame){

					iTeam = GetClientTeam(i);

					if (!iTeam)
						iTeam = 1;
				}

				if (iTeam != 1) // disable unscramble if both team is empty
					bConnectedOnly = false;

				SetTrieValue(g_hTrine, sSteamID, iTeam);

				#if UNSCRABBLE_LOG
					LogToFile(g_sLogPatch, "team %d. %N (%s)", iTeam, i, sSteamID);
				#endif
			}
		}
	}

	if (bConnectedOnly)
		ClearTrie(g_hTrine);

	g_iTrineSize = GetTrieSize(g_hTrine);
}

public void OnClientPutInServer(int client)
{
	if (g_bTeamLock && !IsFakeClient(client)){

		g_bCheked[client] = true;
		g_iFailureCount[client] = 0;
		CreateTimer(1.0, US_t_UnscrabbleMe, client, TIMER_REPEAT);
	}
}

Action US_t_UnscrabbleMe(Handle timer, any client)
{
	if (!g_bTeamLock || !IsClientInGame(client)){

		g_bCheked[client] = false;
		return Plugin_Stop;
	}

	int iCTeam = GetClientTeam(client);

	if (!iCTeam)
		return Plugin_Continue;

	char sSteamID[32];
	int iLTeam;
	GetClientAuthId(client, AuthId_Steam2, sSteamID, 32);

	if (GetTrieValue(g_hTrine, sSteamID, iLTeam)){

		int iNTeam = iLTeam;

		if (IsTeamSwapped()){

			switch (iLTeam){

				case 2:
					iNTeam = 3;
				case 3:
					iNTeam = 2;
			}
		}

		if (iCTeam != iNTeam)
		{
			if (iCTeam != 1)
				ChangeClientTeam(client, 1);

			// we dont use sdk call's
			g_bJoinTeamUsed[client] = true;
			FakeClientCommand(client, "jointeam %d", iNTeam);
			g_bJoinTeamUsed[client] = false;
		}

		#if UNSCRABBLE_LOG
			LogToFile(g_sLogPatch, "%N (%s). Teams: last %d, current %d. Moved to %d (%s).", client, sSteamID, iLTeam, iCTeam, iNTeam, GetClientTeam(client) == iNTeam ? "Okay" : "Fail");
		#endif

		if (GetClientTeam(client) != iNTeam){

			if (++g_iFailureCount[client] >= g_iCvarAttempts){

				g_bCheked[client] = false;
				return Plugin_Stop;
			}

			return Plugin_Continue;
		}
		else if (--g_iTrineSize == 0){

			#if UNSCRABBLE_LOG
				LogToFile(g_sLogPatch, "Trine is empty. Unlock 'jointeam' cmd");
			#endif

			US_ForceToUnlockTeams();
		}
	}
	else if (iCTeam != 1){

		ChangeClientTeam(client, 1);

		#if UNSCRABBLE_LOG
			LogToFile(g_sLogPatch, "%N (%s). Unknown client. Moved to 1", client, sSteamID);
		#endif
	}

	g_bCheked[client] = false;

	return Plugin_Stop;
}

Action US_t_AllowTeamChanges(Handle timer)
{
	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "Time is up (%.0f sec). Force to unlock 'jointeam' cmd", g_fCvarTime);
	#endif

	US_ForceToUnlockTeams();
	
	return Plugin_Continue;
}

Action US_t_CheckConnected(Handle timer)
{
	if (!g_iTrineSize)
		return Plugin_Stop;

	if (IsUnscrabbleComplete()){

		#if UNSCRABBLE_LOG
			LogToFile(g_sLogPatch, "Last client connected. Unlock 'jointeam' cmd");
		#endif

		US_ForceToUnlockTeams();

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

void US_ForceToUnlockTeams()
{
	if (!g_bTeamLock) return;

	if (g_bCvarNotify)
		PrintToChatAll("%s %t", MAIN_TAG, "R2CompMod #23");

	Call_StartForward(g_fwdOnUnscrambleEnd);
	Call_Finish();

	US_ClearVars();
}

void US_ClearVars()
{
	ClearTrie(g_hTrine);
	g_bTeamLock = false;
	g_iTrineSize = 0;
}

bool IsTeamSwapped()
{
	return g_isOldTeamFlipped != g_isNewTeamFlipped;
}

bool IsUnscrabbleComplete()
{
	for (int i = 1; i <= MaxClients; i++)
		if (g_bCheked[i] || IsClientConnected(i) && !IsClientInGame(i))
			return false;

	return true;
}

void US_AbortProcess(bool fireOnUnscrambleEnd = true)
{
	if (fireOnUnscrambleEnd)
		US_ForceToUnlockTeams();
	else
		US_ClearVars();
}

void CheatCommandEx(int client, const char[] command, const char[] arguments = "")
{
	int iFlags = GetCommandFlags(command);
	SetCommandFlags(command, iFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, iFlags);
}

public int Native_R2comp_UnscrambleStart(Handle plugin, int numParams)
{
	US_StartProcess();
	return 0;
}

public int Native_R2comp_UnscrambleKeep(Handle plugin, int numParams)
{
	US_KeepTeams();
	return 0;
}

public int Native_R2comp_IsUnscrambled(Handle plugin, int numParams)
{
	return !g_bTeamLock;
}

public int Native_R2comp_AbortUnscramble(Handle plugin, int numParams)
{
	US_AbortProcess(GetNativeCell(1));
	return 0;
}

void OnCvarChange_Enabled(ConVar cVar, const char[] sOldVal, const char[] sNewVal)
{
	if (!StrEqual(sOldVal, sNewVal)){

		g_bCvarEnabled = GetConVarBool(cVar);
		US_ClearVars();

		if (g_bCvarEnabled)
			UM_OnPluginEnabled();
		else
			UM_OnPluginDisabled();
	}
}

void OnCvarChange_Notify(ConVar cVar, const char[] sOldVal, const char[] sNewVal)
{
	if (!StrEqual(sOldVal, sNewVal))
		g_bCvarNotify = GetConVarBool(cVar);
}

void OnCvarChange_Unlocker(ConVar cVar, const char[] sOldVal, const char[] sNewVal)
{
	if (!StrEqual(sOldVal, sNewVal))
		g_bCvarUnlocker = GetConVarBool(cVar);
}

void OnCvarChange_NoVotes(ConVar cVar, const char[] sOldVal, const char[] sNewVal)
{
	if (!StrEqual(sOldVal, sNewVal))
		g_bCvarNoVotes = GetConVarBool(cVar);
}

void OnCvarChange_Attempts(ConVar cVar, const char[] sOldVal, const char[] sNewVal)
{
	if (!StrEqual(sOldVal, sNewVal))
		g_iCvarAttempts = GetConVarInt(cVar);
}

void OnCvarChange_Time(ConVar cVar, const char[] sOldVal, const char[] sNewVal)
{
	if (!StrEqual(sOldVal, sNewVal))
		g_fCvarTime = GetConVarFloat(cVar);
}
