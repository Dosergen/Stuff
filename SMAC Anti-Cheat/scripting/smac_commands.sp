/*
	SourceMod Anti-Cheat
	Copyright (C) 2011-2016 SMAC Development Team
	Copyright (C) 2007-2011 CodingDirect LLC

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#pragma semicolon 1
#pragma newdecls required

/* SM Includes */
#include <sourcemod>
#include <sdktools>
#include <smac>

/* Globals */
#define MAX_CMD_NAME_LEN PLATFORM_MAX_PATH

enum ActionType
{
	Action_Block = 0,
	Action_Ban,
	Action_Kick
};

int g_iCmdSpamLimit = 30;
int g_iCmdCount[MAXPLAYERS + 1] = {0, ...};

StringMap g_smBlockedCmds;
StringMap g_smIgnoredCmds;

ConVar g_cvCmdSpam;

/* Plugin Info */
public Plugin myinfo =
{
	name        = "SMAC Command Monitor",
	author      = SMAC_AUTHOR,
	description = "Blocks general command exploits",
	version     = SMAC_VERSION,
	url         = SMAC_URL
}

/* Plugin Functions */
public void OnPluginStart()
{
	// Convars.
	g_cvCmdSpam = SMAC_CreateConVar("smac_antispam_cmds", "30", "Amount of commands allowed per second. (0 = Disabled)", FCVAR_NONE, true, 0.0, false, 0.0);
	g_iCmdSpamLimit = g_cvCmdSpam.IntValue;
	g_cvCmdSpam.AddChangeHook(OnSettingsChanged);

	// Hooks.
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	
	switch (SMAC_GetGameType())
	{
		case Game_ND:
		{
			AddCommandListener(Command_Say, "say_squad");
		}
	}

	// Exploitable needed commands.  Sigh....
	AddCommandListener(Command_BlockEntExploit, "ent_create");
	AddCommandListener(Command_BlockEntExploit, "ent_fire");

	// L4D2 uses this for confogl.
	if (SMAC_GetGameType() != Game_L4D2)
		AddCommandListener(Command_BlockEntExploit, "give");

	// Init...
	g_smBlockedCmds = new StringMap();
	g_smIgnoredCmds = new StringMap();

	// Add commands to block list.
	g_smBlockedCmds.SetValue("ai_test_los",                  Action_Block);
	g_smBlockedCmds.SetValue("bugpause",                     Action_Block);
	g_smBlockedCmds.SetValue("bugunpause",                   Action_Block);
	g_smBlockedCmds.SetValue("cl_fullupdate",                Action_Block);
	g_smBlockedCmds.SetValue("dbghist_addline",              Action_Block);
	g_smBlockedCmds.SetValue("dbghist_dump",                 Action_Block);
	g_smBlockedCmds.SetValue("drawcross",                    Action_Block);
	g_smBlockedCmds.SetValue("drawline",                     Action_Block);
	g_smBlockedCmds.SetValue("dump_entity_sizes",            Action_Block);
	g_smBlockedCmds.SetValue("dump_globals",                 Action_Block);
	g_smBlockedCmds.SetValue("dump_panels",                  Action_Block);
	g_smBlockedCmds.SetValue("dump_terrain",                 Action_Block);
	g_smBlockedCmds.SetValue("dumpcountedstrings",           Action_Block);
	g_smBlockedCmds.SetValue("dumpentityfactories",          Action_Block);
	g_smBlockedCmds.SetValue("dumpeventqueue",               Action_Block);
	g_smBlockedCmds.SetValue("dumpgamestringtable",          Action_Block);
	g_smBlockedCmds.SetValue("editdemo",                     Action_Block);
	g_smBlockedCmds.SetValue("endround",                     Action_Block);
	g_smBlockedCmds.SetValue("fade",                         Action_Block);
	g_smBlockedCmds.SetValue("groundlist",                   Action_Block);
	g_smBlockedCmds.SetValue("listdeaths",                   Action_Block);
	g_smBlockedCmds.SetValue("listmodels",                   Action_Block);
	g_smBlockedCmds.SetValue("map_showspawnpoints",          Action_Block);
	g_smBlockedCmds.SetValue("mem_dump",                     Action_Block);
	g_smBlockedCmds.SetValue("mp_dump_timers",               Action_Block);
	g_smBlockedCmds.SetValue("npc_ammo_deplete",             Action_Block);
	g_smBlockedCmds.SetValue("npc_heal",                     Action_Block);
	g_smBlockedCmds.SetValue("npc_speakall",                 Action_Block);
	g_smBlockedCmds.SetValue("npc_thinknow",                 Action_Block);
	g_smBlockedCmds.SetValue("physics_budget",               Action_Block);
	g_smBlockedCmds.SetValue("physics_debug_entity",         Action_Block);
	g_smBlockedCmds.SetValue("physics_highlight_active",     Action_Block);
	g_smBlockedCmds.SetValue("physics_report_active",        Action_Block);
	g_smBlockedCmds.SetValue("physics_select",               Action_Block);
	g_smBlockedCmds.SetValue("report_entities",              Action_Block);
	g_smBlockedCmds.SetValue("report_simthinklist",          Action_Block);
	g_smBlockedCmds.SetValue("report_touchlinks",            Action_Block);
	g_smBlockedCmds.SetValue("respawn_entities",             Action_Block);
	g_smBlockedCmds.SetValue("rr_reloadresponsesystems",     Action_Block);
	g_smBlockedCmds.SetValue("scene_flush",                  Action_Block);
	g_smBlockedCmds.SetValue("snd_digital_surround",         Action_Block);
	g_smBlockedCmds.SetValue("snd_restart",                  Action_Block);
	g_smBlockedCmds.SetValue("soundlist",                    Action_Block);
	g_smBlockedCmds.SetValue("soundscape_flush",             Action_Block);
	g_smBlockedCmds.SetValue("sv_benchmark_force_start",     Action_Block);
	g_smBlockedCmds.SetValue("sv_findsoundname",             Action_Block);
	g_smBlockedCmds.SetValue("sv_soundemitter_filecheck",    Action_Block);
	g_smBlockedCmds.SetValue("sv_soundemitter_flush",        Action_Block);
	g_smBlockedCmds.SetValue("sv_soundscape_printdebuginfo", Action_Block);
	g_smBlockedCmds.SetValue("wc_update_entity",             Action_Block);
	g_smBlockedCmds.SetValue("changelevel",                  Action_Ban);
	g_smBlockedCmds.SetValue("speed.toggle",                 Action_Kick);

	// Add game specific commands to block list.
	switch (SMAC_GetGameType())
	{
		case Game_L4D:
		{
			g_smBlockedCmds.SetValue("demo_returntolobby", Action_Block);
			g_smIgnoredCmds.SetValue("choose_closedoor",   true);
			g_smIgnoredCmds.SetValue("choose_opendoor",    true);
		}
		case Game_L4D2:
		{
			g_smIgnoredCmds.SetValue("choose_closedoor", true);
			g_smIgnoredCmds.SetValue("choose_opendoor",  true);
		}
		case Game_ND:
		{
			g_smIgnoredCmds.SetValue("bitcmd", true);
			g_smIgnoredCmds.SetValue("sg",     true);
		}
	}

	// Add commands to ignore list.
	g_smIgnoredCmds.SetValue("buy",                true);
	g_smIgnoredCmds.SetValue("buyammo1",           true);
	g_smIgnoredCmds.SetValue("buyammo2",           true);
	g_smIgnoredCmds.SetValue("setpause",           true);
	g_smIgnoredCmds.SetValue("spec_mode",          true);
	g_smIgnoredCmds.SetValue("spec_next",          true);
	g_smIgnoredCmds.SetValue("spec_prev",          true);
	g_smIgnoredCmds.SetValue("unpause",            true);
	g_smIgnoredCmds.SetValue("use",                true);
	g_smIgnoredCmds.SetValue("vban",               true);
	g_smIgnoredCmds.SetValue("vmodenable",         true);
	g_smIgnoredCmds.SetValue("warp_to_start_area", true);
	g_smIgnoredCmds.SetValue("give",               true);
	g_smIgnoredCmds.SetValue("z_spawn_old",        true);

	CreateTimer(1.0, Timer_ResetCmdCount, _, TIMER_REPEAT);

	AddCommandListener(Command_CommandListener);

	RegAdminCmd("smac_addcmd",          Command_AddCmd,          ADMFLAG_ROOT, "Block a command.");
	RegAdminCmd("smac_addignorecmd",    Command_AddIgnoreCmd,    ADMFLAG_ROOT, "Ignore a command.");
	RegAdminCmd("smac_removecmd",       Command_RemoveCmd,       ADMFLAG_ROOT, "Unblock a command.");
	RegAdminCmd("smac_removeignorecmd", Command_RemoveIgnoreCmd, ADMFLAG_ROOT, "Unignore a command.");
	LoadTranslations("smac.phrases");
}

Action Command_AddCmd(int iClient, int iArgs)
{
	if (iArgs == 2)
	{
		char szCommand[MAX_CMD_NAME_LEN];
		GetCmdArg(1, szCommand, sizeof(szCommand));
		StringToLower(szCommand);
		char szAction[8];
		GetCmdArg(2, szAction, sizeof(szAction));
		ActionType cAction = Action_Block;
		switch (StringToInt(szAction))
		{
			case 1:
			{
				cAction = Action_Ban;
			}
			case 2:
			{
				cAction = Action_Kick;
			}
		}
		g_smBlockedCmds.SetValue(szCommand, cAction);
		ReplyToCommand(iClient, "%s has been added.", szCommand);
		return Plugin_Handled;
	}
	ReplyToCommand(iClient, "Usage: smac_addcmd <cmd> <action>");
	return Plugin_Handled;
}

Action Command_AddIgnoreCmd(int iClient, int iArgs)
{
	if (iArgs == 1)
	{
		char szCommand[MAX_CMD_NAME_LEN];
		GetCmdArg(1, szCommand, sizeof(szCommand));
		StringToLower(szCommand);
		g_smIgnoredCmds.SetValue(szCommand, true);
		ReplyToCommand(iClient, "%s has been added.", szCommand);
		return Plugin_Handled;
	}
	ReplyToCommand(iClient, "Usage: smac_addignorecmd <cmd>");
	return Plugin_Handled;
}

Action Command_RemoveCmd(int iClient, int iArgs)
{
	if (iArgs == 1)
	{
		char szCommand[MAX_CMD_NAME_LEN];
		GetCmdArg(1, szCommand, sizeof(szCommand));
		StringToLower(szCommand);
		if (g_smBlockedCmds.Remove(szCommand))
			ReplyToCommand(iClient, "%s has been removed.", szCommand);
		else
			ReplyToCommand(iClient, "%s was not found.", szCommand);
		return Plugin_Handled;
	}
	ReplyToCommand(iClient, "Usage: smac_removecmd <cmd>");
	return Plugin_Handled;
}

Action Command_RemoveIgnoreCmd(int iClient, int iArgs)
{
	if (iArgs == 1)
	{
		char szCommand[MAX_CMD_NAME_LEN];
		GetCmdArg(1, szCommand, sizeof(szCommand));
		StringToLower(szCommand);
		if (g_smIgnoredCmds.Remove(szCommand))
			ReplyToCommand(iClient, "%s has been removed.", szCommand);
		else
			ReplyToCommand(iClient, "%s was not found.", szCommand);
		return Plugin_Handled;
	}
	ReplyToCommand(iClient, "Usage: smac_removeignorecmd <cmd>");
	return Plugin_Handled;
}

Action Command_Say(int iClient, const char[] szCommand, int iArgs)
{
	if (!IS_CLIENT(iClient))
		return Plugin_Continue;
	int iSpaceNum;
	char szChar, sMsg[256];
	int iLen = GetCmdArgString(sMsg, sizeof(sMsg));
	for (int i = 0; i < iLen; i++)
	{
		szChar = sMsg[i];
		if (szChar == ' ')
		{
			if (iSpaceNum++ >= 64)
			{
				PrintToChat(iClient, "%t", "SMAC_SayBlock");
				return Plugin_Stop;
			}
		}
		if (szChar < 32 && !IsCharMB(szChar))
		{
			PrintToChat(iClient, "%t", "SMAC_SayBlock");
			return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}

Action Command_BlockEntExploit(int iClient, const char[] szCommand, int iArgs)
{
	if (!IS_CLIENT(iClient))
		return Plugin_Continue;
	if (!IsClientInGame(iClient))
		return Plugin_Stop;
	char szArgString[512];
	if (GetCmdArgString(szArgString, sizeof(szArgString)) > 500)
		return Plugin_Stop;
	if (StrContains(szArgString, "admin")                   != -1 ||
		StrContains(szArgString, "alias", false)            != -1 ||
		StrContains(szArgString, "logic_auto")              != -1 ||
		StrContains(szArgString, "logic_autosave")          != -1 ||
		StrContains(szArgString, "logic_branch")            != -1 ||
		StrContains(szArgString, "logic_case")              != -1 ||
		StrContains(szArgString, "logic_collision_pair")    != -1 ||
		StrContains(szArgString, "logic_compareto")         != -1 ||
		StrContains(szArgString, "logic_lineto")            != -1 ||
		StrContains(szArgString, "logic_measure_movement")  != -1 ||
		StrContains(szArgString, "logic_multicompare")      != -1 ||
		StrContains(szArgString, "logic_navigation")        != -1 ||
		StrContains(szArgString, "logic_relay")             != -1 ||
		StrContains(szArgString, "logic_timer")             != -1 ||
		StrContains(szArgString, "ma_")                     != -1 ||
		StrContains(szArgString, "meta")                    != -1 ||
		StrContains(szArgString, "mp_", false)              != -1 ||
		StrContains(szArgString, "point_clientcommand")     != -1 ||
		StrContains(szArgString, "point_servercommand")     != -1 ||
		StrContains(szArgString, "quit", false)             != -1 ||
		StrContains(szArgString, "quti")                    != -1 ||
		StrContains(szArgString, "rcon", false)             != -1 ||
		StrContains(szArgString, "restart", false)          != -1 ||
		StrContains(szArgString, "sm")                      != -1 ||
		StrContains(szArgString, "sv_", false)              != -1 ||
		StrContains(szArgString, "taketimer")               != -1)
		return Plugin_Stop;
	return Plugin_Continue;
}

Action Command_CommandListener(int iClient, const char[] szCommand, int iArgs)
{
	if (!IS_CLIENT(iClient))
		return Plugin_Continue;
	if (IsClientConnected(iClient) && IsFakeClient(iClient))
		return Plugin_Continue;
	if (!IsClientInGame(iClient))
		return Plugin_Stop;
	// NOTE: InternalDispatch automatically lower cases "command".
	ActionType cAction = Action_Block;
	if (g_smBlockedCmds.GetValue(szCommand, cAction))
	{
		if (cAction != Action_Block)
		{
			char szArgString[192];
			GetCmdArgString(szArgString, sizeof(szArgString));
			KeyValues kvInfo = new KeyValues("");
			kvInfo.SetString("command", szCommand);
			kvInfo.SetString("argstring", szArgString);
			kvInfo.SetNum("action", view_as<int>(cAction));
			if (SMAC_CheatDetected(iClient, Detection_BannedCommand, kvInfo) == Plugin_Continue)
			{
				if (cAction == Action_Ban)
				{
					SMAC_PrintAdminNotice("%N was banned for command: %s %s", iClient, szCommand, szArgString);
					SMAC_LogAction(iClient, "was banned for command: %s %s", szCommand, szArgString);
					SMAC_Ban(iClient, "Command %s violation", szCommand);
				}
				else if (cAction == Action_Kick)
				{
					SMAC_PrintAdminNotice("%N was kicked for command: %s %s", iClient, szCommand, szArgString);
					SMAC_LogAction(iClient, "was kicked for command: %s %s", szCommand, szArgString);
					KickClient(iClient, "Command %s violation", szCommand);
				}
			}
			delete kvInfo;
		}
		return Plugin_Stop;
	}

	if (g_iCmdSpamLimit && !g_smIgnoredCmds.GetValue(szCommand, cAction) && ++g_iCmdCount[iClient] > g_iCmdSpamLimit)
	{
		char szArgString[192];
		GetCmdArgString(szArgString, sizeof(szArgString));
		KeyValues kvInfo = new KeyValues("");
		kvInfo.SetString("command", szCommand);
		kvInfo.SetString("argstring", szArgString);
		if (SMAC_CheatDetected(iClient, Detection_CommandSpamming, kvInfo) == Plugin_Continue)
		{
			SMAC_PrintAdminNotice("%N was kicked for spamming: %s %s", iClient, szCommand, szArgString);
			SMAC_LogAction(iClient, "was kicked for spamming: %s %s", szCommand, szArgString);
			KickClient(iClient, "%t", "SMAC_CommandSpamKick");
		}
		delete kvInfo;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

Action Timer_ResetCmdCount(Handle hTimer)
{
	for (int i = 1; i <= MaxClients; i++)
		g_iCmdCount[i] = 0;
	return Plugin_Continue;
}

void OnSettingsChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal)
{
	g_iCmdSpamLimit = g_cvCmdSpam.IntValue;
}