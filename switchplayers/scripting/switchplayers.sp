/********************************************************************************************
* Plugin	: L4DSwitchPlayers
* Version	: 1.6
* Game		: Left 4 Dead 2
* Author	: SkyDavid (djromero)
* 
* Purpose	: This plugin allows admins to switch player's teams or swap 2 players
* 
* Version 1.0:
* 		- Initial release
* 
* Version 1.1:
* 		- Added check to prevent switching a player to a team that is already full
* 
* Version 1.2:
* 		- Added cvar to bypass team full check (l4dswitch_checkteams). Default = 1. 
* 		  Change to 0 to disable it.
* 		- Added new Swap Players option, that allows to immediately swap 2 player's teams.
* 		  (2 lines of code taken from Downtown1's L4d Ready up plugin)
* Version 1.2.1:
* 		- Added public cvar.
* Version 1.3:
* 		- Fixed plubic cvar to disable check of full teams.
* 		- Added validations to prevent log errors when a player leaves the game before it
* 		  gets switched/swapped.
* Version 1.4:
*		- Added support for L4D2. Thanks to AtomicStryker for finding the new signature.
* Version 1.5: ( By: https://forums.alliedmods.net/member.php?u=50161 )
* 		- Fixed swapping in L4D2
* 		- Fixed small bug in PerformSwitch()
* Version 1.6:
* 		- Fixed "Client x is not in game" 
* 		- Converted plugin source to the latest syntax utilizing methodmaps   
*********************************************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#undef REQUIRE_PLUGIN
#include <adminmenu>

#define PLUGIN_VERSION "1.6"

ConVar Survivor_Limit, Infected_Limit, h_Switch_CheckTeams;
int SwapPlayer1, SwapPlayer2, g_SwitchTo, g_SwitchTarget;
bool IsSwapPlayers, g_bLeft4Dead2;
TopMenu hTopMenu;
Handle fSHS, fTOB;

public Plugin myinfo = 
{
	name = "L4DSwitchPlayers",
	author = "SkyDavid (djromero)",
	description = "Adds options to players commands menu to switch and swap players' team",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=83950"
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
	LoadTranslations("common.phrases");

	CreateConVar("l4d_switchplayers_version", PLUGIN_VERSION, "Version of L4D Switch Players plugin", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	GameData gConf = new GameData("l4dswitchplayers");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "SetHumanSpec");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	fSHS = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "TakeOverBot");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	fTOB = EndPrepSDKCall();
	
	Survivor_Limit = FindConVar("survivor_limit");
	Infected_Limit = FindConVar("z_max_player_zombies");
	
	h_Switch_CheckTeams = CreateConVar("l4dswitch_checkteams", "1", "Determines if the function should check if target team is full", ADMFLAG_KICK, true, 0.0, true, 1.0);
	
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		hTopMenu = null;
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);
	if (topmenu == hTopMenu) 
		return;
	hTopMenu = topmenu;
	TopMenuObject players_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);
	if (players_commands != INVALID_TOPMENUOBJECT)
	{
		hTopMenu.AddItem("l4dteamswitch", SkyAdmin_SwitchPlayer, players_commands, "l4dteamswitch", ADMFLAG_KICK);
		hTopMenu.AddItem("l4dswapplayers", SkyAdmin_SwapPlayers, players_commands, "l4dswapplayers", ADMFLAG_KICK);
	}
}

void SkyAdmin_SwitchPlayer(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	IsSwapPlayers = false;
	SwapPlayer1 = -1;
	SwapPlayer2 = -1;
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "Switch player", "", param);
	else if (action == TopMenuAction_SelectOption)
		DisplaySwitchPlayerMenu(param);
}

void SkyAdmin_SwapPlayers(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	IsSwapPlayers = true;
	SwapPlayer1 = -1;
	SwapPlayer2 = -1;
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "Swap players", "", param);
	else if (action == TopMenuAction_SelectOption)
		DisplaySwitchPlayerMenu(param);
}

void DisplaySwitchPlayerMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_SwitchPlayer);
	char title[64];
	if (!IsSwapPlayers)
		Format(title, sizeof(title), "Switch player");
	else
		Format(title, sizeof(title), SwapPlayer1 == -1 ? "Player 1" : "Player 2");
	menu.SetTitle(title, "", client);
	menu.ExitBackButton = true;
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_BOTS);
	menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_SwitchPlayer(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu != null)
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		int userid, target;
		menu.GetItem(param2, info, sizeof(info));
		userid = StringToInt(info);
		if ((target = GetClientOfUserId(userid)) == 0)
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		else if (!CanUserTarget(param1, target))
			PrintToChat(param1, "[SM] %t", "Unable to target");
		if (IsSwapPlayers)
		{
			if (SwapPlayer1 == -1)
				SwapPlayer1 = target;
			else
				SwapPlayer2 = target;
			if (SwapPlayer1 != -1 && SwapPlayer2 != -1)
			{
				PerformSwap(param1);
				hTopMenu.Display(param1, TopMenuPosition_LastCategory);
			}
			else
				DisplaySwitchPlayerMenu(param1);
		}
		else
		{
			g_SwitchTarget = target;
			DisplaySwitchPlayerToMenu(param1);
		}
	}
	return 0;
}

void DisplaySwitchPlayerToMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_SwitchPlayerTo);
	menu.SetTitle("Choose team");
	menu.ExitBackButton = true;
	menu.AddItem("1", "Spectators");
	menu.AddItem("2", "Survivors");
	menu.AddItem("3", "Infected");
	menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_SwitchPlayerTo(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu != null)
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		g_SwitchTo = StringToInt(info);
		PerformSwitch(param1, g_SwitchTarget, g_SwitchTo, false);
		DisplaySwitchPlayerMenu(param1);
	}
	return 0;
}

bool IsTeamFull(int team)
{
	if (team != 2 && team != 3)
		return false;
	int max = (team == 2) ? Survivor_Limit.IntValue : Infected_Limit.IntValue;
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == team)
			count++;
	}
	return count >= max;
}

void PerformSwap(int client)
{
	if (SwapPlayer1 == SwapPlayer2)
	{
		PrintToChat(client, "[SM] Can't swap this player with himself.");
		return;
	}
	if (SwapPlayer1 <= 0 || SwapPlayer2 <= 0)
	{
		PrintToChat(client, "[SM] Invalid player ID's provided for swapping.");
		return;
	}
	if (!IsClientInGame(SwapPlayer1))
	{
		PrintToChat(client, "[SM] First player is not available anymore.");
		return;
	}
	if (!IsClientInGame(SwapPlayer2))
	{
		PrintToChat(client, "[SM] Second player is not available anymore.");
		return;
	}
	int team1 = GetClientTeam(SwapPlayer1);
	int team2 = GetClientTeam(SwapPlayer2);
	if (team1 == team2)
	{
		PrintToChat(client, "[SM] Can't swap players that are on the same team.");
		return;
	}
	ConVar hConVar = FindConVar(g_bLeft4Dead2 ? "sb_all_bot_game" : "sb_all_bot_team");
	SetConVarInt(hConVar, 1);
	PerformSwitch(client, SwapPlayer1, 1, true);
	PerformSwitch(client, SwapPlayer2, 1, true);
	PerformSwitch(client, SwapPlayer1, team2, true);
	PerformSwitch(client, SwapPlayer2, team1, true);
	ResetConVar(hConVar);
	char PlayerName1[MAX_NAME_LENGTH], PlayerName2[MAX_NAME_LENGTH];
	GetClientName(SwapPlayer1, PlayerName1, sizeof(PlayerName1));
	GetClientName(SwapPlayer2, PlayerName2, sizeof(PlayerName2));
	PrintToChat(client, "\x01[SM] \x03%s \x01has been swapped with \x03%s", PlayerName1, PlayerName2);
}

void PerformSwitch(int client, int target, int team, bool silent)
{
	if (!IsClientInGame(target))
	{
		PrintToChat(client, "[SM] The player is not available anymore.");
		return;
	}
	if (GetClientTeam(target) == team)
	{
		PrintToChat(client, "[SM] That player is already on that team.");
		return;
	}
	if (h_Switch_CheckTeams.BoolValue && IsTeamFull(team))
	{
		PrintToChat(client, team == 2 ? "[SM] The \x03Survivor\x01's team is already full." : "[SM] The \x03Infected\x01's team is already full.");
		return;
	}
	if (GetClientTeam(target) == 3 && GetEntProp(client, Prop_Send, "m_isGhost") == 0)
	{
		char model[128];
		GetClientModel(target, model, sizeof(model));
		if (StrContains(model, "hulk", false) == -1)
			ForcePlayerSuicide(target);
	}
	if (team == 2)
	{
		ChangeClientTeam(target, 1);
		int bot = 1;
		while (bot <= MaxClients && !(IsClientInGame(bot) && IsFakeClient(bot) && GetClientTeam(bot) == 2))
			bot++;
		if (bot <= MaxClients)
		{
			SDKCall(fSHS, bot, target);
			SDKCall(fTOB, target, true);
		}
	}
	else
		ChangeClientTeam(target, team);
	if (!silent)
	{
		char PlayerName[MAX_NAME_LENGTH];
		GetClientName(target, PlayerName, sizeof(PlayerName));
		char teamName[32];
		if (team == 1)
			strcopy(teamName, sizeof(teamName), "Spectators");
		else if (team == 2)
			strcopy(teamName, sizeof(teamName), "Survivors");
		else
			strcopy(teamName, sizeof(teamName), "Infected");
		PrintToChat(client, "[SM] \x03%s \x01has been moved to \x03%s", PlayerName, teamName);
	}
}