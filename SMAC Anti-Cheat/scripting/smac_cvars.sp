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
#include <smac_cvars>

#undef REQUIRE_PLUGIN
#include <basecomm>
#define REQUIRE_PLUGIN

/* Globals */
#define CVAR_REPLICATION_DELAY 30
#define TIME_REQUERY_FIRST 20.0
#define TIME_REQUERY_SUBSEQUENT 10.0
#define MAX_REQUERY_ATTEMPTS 4

// plugin state
bool g_bLateLoad;
bool g_bPluginStarted;

// cvar data
int g_iADTSize;
StringMap g_smCvars;
ArrayList g_arrCvars;

// client data
int g_iRequeryCount[MAXPLAYERS + 1];
int g_iADTIndex[MAXPLAYERS + 1] = {-1, ...};
Handle g_hTimer[MAXPLAYERS + 1];
StringMap g_smCurData[MAXPLAYERS + 1];

/* Plugin Info */
public Plugin myinfo =
{
	name        = "SMAC ConVar Checker",
	author      = SMAC_AUTHOR,
	description = "Checks for players using exploitative cvars",
	version     = SMAC_VERSION,
	url         = SMAC_URL
}

/* Plugin Functions */
public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax)
{
	g_bLateLoad = bLate;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_smCvars  = new StringMap();
	g_arrCvars = new ArrayList();

	// Check for plugins first.
	AddCvar(Order_First, "0penscript",               Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "aim_bot",                  Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "aim_fov",                  Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "bat_version",              Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "beetlesmod_version",       Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "est_version",              Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "eventscripts_ver",         Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "fm_attackmode",            Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "lua-engine",               Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "lua_open",                 Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "mani_admin_plugin_version",Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "maniadminhacker",          Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "maniadmintakeover",        Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "metamod_version",          Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "openscript",               Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "openscript_version",       Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "runnscript",               Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "smadmintakeover",          Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "sourcemod_version",        Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "tb_enabled",               Comp_NonExist, Action_Kick);
	AddCvar(Order_First, "zb_version",               Comp_NonExist, Action_Kick);

	// Check for everything else last.
	AddCvar(Order_Last, "cl_clock_correction",    Comp_Equal, Action_Kick, "1.0");
	AddCvar(Order_Last, "cl_leveloverview",       Comp_Equal, Action_Kick, "0.0");
	AddCvar(Order_Last, "cl_overdraw_test",       Comp_Equal, Action_Kick, "0.0");
	AddCvar(Order_Last, "cl_phys_timescale",      Comp_Equal, Action_Kick, "1.0");
	AddCvar(Order_Last, "cl_showevents",          Comp_Equal, Action_Kick, "0.0");
	AddCvar(Order_Last, "fog_enable",             Comp_Equal, Action_Kick, "1.0");
	AddCvar(Order_Last, "mat_hdr_level",          Comp_Equal, Action_Kick, "2.0");
	AddCvar(Order_Last, "mat_postprocess_enable", Comp_Equal, Action_Kick, "1.0");

	AddCvar(Order_Last, "mat_dxlevel",             Comp_Greater,    Action_Kick, "80.0");
	AddCvar(Order_Last, "mat_fillrate",            Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "mat_measurefillrate",     Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "mat_proxy",               Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "mat_showlowresimage",     Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "mat_wireframe",           Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "mem_force_flush",         Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "r_aspectratio",           Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "r_colorstaticprops",      Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "r_dispwalkable",          Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "r_drawbeams",             Comp_Equal,      Action_Kick,  "1.0");
	AddCvar(Order_Last, "r_drawbrushmodels",       Comp_Equal,      Action_Kick,  "1.0");
	AddCvar(Order_Last, "r_drawclipbrushes",       Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "r_drawdecals",            Comp_Equal,      Action_Kick,  "1.0");
	AddCvar(Order_Last, "r_drawentities",          Comp_Equal,      Action_Kick,  "1.0");
	AddCvar(Order_Last, "r_drawmodelstatsoverlay", Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "r_drawopaqueworld",       Comp_Equal,      Action_Kick,  "1.0");
	AddCvar(Order_Last, "r_drawothermodels",       Comp_Equal,      Action_Kick,  "1.0");
	AddCvar(Order_Last, "r_showenvcubemap",        Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "r_drawparticles",         Comp_Equal,      Action_Kick,  "1.0");
	AddCvar(Order_Last, "r_drawrenderboxes",       Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "r_modelwireframedecal",   Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "r_drawskybox",            Comp_Equal,      Action_Kick,  "1.0");
	AddCvar(Order_Last, "r_drawtranslucentworld",  Comp_Equal,      Action_Kick,  "1.0");
	AddCvar(Order_Last, "r_shadowwireframe",       Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "r_skybox",                Comp_Equal,      Action_Kick,  "1.0");
	AddCvar(Order_Last, "r_visocclusion",          Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "snd_show",                Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "snd_visualize",           Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "vcollide_wireframe",      Comp_Equal,      Action_Kick,  "0.0");
	AddCvar(Order_Last, "host_timescale",          Comp_Replicated, Action_Kick);
	AddCvar(Order_Last, "mp_fadetoblack",          Comp_Replicated, Action_Kick);
	AddCvar(Order_Last, "sv_allowminmodels",       Comp_Replicated, Action_Kick);
	AddCvar(Order_Last, "sv_cheats",               Comp_Replicated, Action_Kick);
	AddCvar(Order_Last, "sv_competitive_minspec",  Comp_Replicated, Action_Kick);
	AddCvar(Order_Last, "sv_consistency",          Comp_Replicated, Action_Kick);
	AddCvar(Order_Last, "sv_footsteps",            Comp_Replicated, Action_Kick);

	// Commands.
	RegAdminCmd("smac_addcvar",    Command_AddCvar, ADMFLAG_ROOT, "Add cvar to checking.");
	RegAdminCmd("smac_removecvar", Command_RemCvar, ADMFLAG_ROOT, "Remove cvar from checking.");

	// scramble ordering.
	if (g_iADTSize) ScrambleCvars();

	// Start on all clients.
	if (g_bLateLoad)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))
				continue;
			if (!IsClientAuthorized(i))
				continue;
			OnClientPostAdminCheck(i);
		}
	}

	g_bPluginStarted = true;
	LoadTranslations("smac.phrases");
}

public void OnClientPostAdminCheck(int iClient)
{
	if (IsFakeClient(iClient))
		return;
	SetTimer(g_hTimer[iClient], CreateTimer(0.1, Timer_QueryNextCvar, iClient, TIMER_REPEAT));
}

public void OnClientDisconnect(int iClient)
{
	if (IsFakeClient(iClient))
		return;
	g_smCurData[iClient] = null;
	g_iADTIndex[iClient] = -1;
	g_iRequeryCount[iClient] = 0;
	SetTimer(g_hTimer[iClient], null);
}

Action Command_AddCvar(int iClient, int iArgs)
{
	if (iArgs >= 3 && iArgs <= 5)
	{
		char szCvar[MAX_CVAR_NAME_LEN];
		GetCmdArg(1, szCvar, sizeof(szCvar));
		if (!IsValidConVarName(szCvar))
		{
			ReplyToCommand(iClient, "\"%s\" is not a valid convar.", szCvar);
			return Plugin_Handled;
		}
		char szCompType[16];
		GetCmdArg(2, szCompType, sizeof(szCompType));
		char szAction[16];
		GetCmdArg(3, szAction, sizeof(szAction));
		char szValue[MAX_CVAR_VALUE_LEN];
		if (iArgs >= 4)
			GetCmdArg(4, szValue, sizeof(szValue));
		char szValue2[MAX_CVAR_VALUE_LEN];
		if (iArgs >= 5)
			GetCmdArg(5, szValue2, sizeof(szValue2));
		if (AddCvar(Order_Last, szCvar, GetCompTypeInt(szCompType), GetCActionInt(szAction), szValue, szValue2))
		{
			ReplyToCommand(iClient, "%s successfully added.", szCvar);
			return Plugin_Handled;
		}
	}
	ReplyToCommand(iClient, "Usage: smac_addcvar <cvar> <comptype> <action> <value> <value2>");
	return Plugin_Handled;
}

bool AddCvar(CvarOrder COrder, char[] szCvar, int SCCompType, CvarAction CAction, const char[] szValue = "", const char[] szValue2 = "")
{
	if (SCCompType == Comp_Invalid)
		return false;
	if (CAction == Action_Invalid)
		return false;
	// Trie is case sensitive.
	StringToLower(szCvar);
	char szNewValue[MAX_CVAR_VALUE_LEN];
	ConVar cv;
	if (SCCompType == Comp_Replicated)
	{
		cv = FindConVar(szCvar);
		if (cv == null || !(cv.Flags & FCVAR_REPLICATED))
			return false;
		cv.GetString(szNewValue, sizeof(szNewValue));
	}
	else
		strcopy(szNewValue, sizeof(szNewValue), szValue);
	StringMap smData;
	if (g_smCvars.GetValue(szCvar, smData))
	{
		smData.SetString(Cvar_Name,    szCvar);
		smData.SetValue(Cvar_CompType, SCCompType);
		smData.SetValue(Cvar_Action,   CAction);
		smData.SetString(Cvar_Value,   szNewValue);
		smData.SetString(Cvar_Value2,  szValue2);
	}
	else
	{
		// Setup cvar data
		smData = new StringMap();
		smData.SetValue(Cvar_Order,    COrder);
		smData.SetString(Cvar_Name,    szCvar);
		smData.SetValue(Cvar_CompType, SCCompType);
		smData.SetValue(Cvar_Action,   CAction);
		smData.SetString(Cvar_Value,   szNewValue);
		smData.SetString(Cvar_Value2,  szValue2);
		smData.SetValue(Cvar_ReplicatedTime, 0);
		// Add cvar to lists
		g_smCvars.SetValue(szCvar, smData);
		g_arrCvars.Push(smData);
		g_iADTSize = g_arrCvars.Length;
		// Begin replication
		if (SCCompType == Comp_Replicated)
		{
			cv.AddChangeHook(OnConVarChanged);
			ReplicateToAll(cv, szNewValue);
		}
		// Scramble
		if (g_bPluginStarted)
			ScrambleCvars();
	}
	return true;
}

Action Command_RemCvar(int iClient, int iArgs)
{
	if (iArgs == 1)
	{
		char szCvar[MAX_CVAR_NAME_LEN];
		GetCmdArg(1, szCvar, sizeof(szCvar));

		if (RemCvar(szCvar))
			ReplyToCommand(iClient, "%s successfully removed.", szCvar);
		else
			ReplyToCommand(iClient, "%s was not found.", szCvar);
		return Plugin_Handled;
	}
	ReplyToCommand(iClient, "Usage: smac_removecvar <cvar>");
	return Plugin_Handled;
}

bool RemCvar(char[] szCvar)
{
	StringMap smData;
	// Trie is case sensitive.
	StringToLower(szCvar);
	// Are you listed?
	if (!g_smCvars.GetValue(szCvar, smData)) return false;
	// Invalidate active queries.
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_smCurData[i] == smData)
			g_smCurData[i] = null;
	}
	// Disable replication
	int SCCompType;
	smData.GetValue(Cvar_CompType, SCCompType);
	if (SCCompType == Comp_Replicated) FindConVar(szCvar).RemoveChangeHook(OnConVarChanged);
	// Remove relevant entries
	g_smCvars.Remove(szCvar);
	g_arrCvars.Erase(g_arrCvars.FindValue(smData));
	g_iADTSize = g_arrCvars.Length;
	delete smData;
	return true;
}

Action Timer_QueryNextCvar(Handle hTimer, any aClient)
{
	// No cvars in the list
	if (!g_iADTSize)
		return Plugin_Continue;
	// Get next cvar
	if (++g_iADTIndex[aClient] >= g_iADTSize)
		g_iADTIndex[aClient] = 0;
	StringMap smData = g_arrCvars.Get(g_iADTIndex[aClient]);
	if (IsReplicating(smData))
		return Plugin_Continue;
	// Attempt to query it
	char szCvar[MAX_CVAR_NAME_LEN];
	smData.GetString(Cvar_Name, szCvar, sizeof(szCvar));
	if (QueryClientConVar(aClient, szCvar, OnConVarQueryFinished, GetClientSerial(aClient)) == QUERYCOOKIE_FAILED)
		return Plugin_Continue;
	// Success!
	g_smCurData[aClient] = smData;
	g_hTimer[aClient] = CreateTimer(TIME_REQUERY_FIRST, Timer_RequeryCvar, aClient);
	return Plugin_Stop;
}

Action Timer_RequeryCvar(Handle hTimer, any aClient)
{
	// Have we had enough?
	if (++g_iRequeryCount[aClient] > MAX_REQUERY_ATTEMPTS)
	{
		g_hTimer[aClient] = null;
		KickClient(aClient, "%t", "SMAC_FailedToReply");
		return Plugin_Stop;
	}
	// Did the query get invalidated?
	if (g_smCurData[aClient] != null && !IsReplicating(g_smCurData[aClient]))
	{
		char szCvar[MAX_CVAR_NAME_LEN];
		g_smCurData[aClient].GetString(Cvar_Name, szCvar, sizeof(szCvar));
		if (QueryClientConVar(aClient, szCvar, OnConVarQueryFinished, GetClientSerial(aClient)) != QUERYCOOKIE_FAILED)
		{
			g_hTimer[aClient] = CreateTimer(TIME_REQUERY_SUBSEQUENT, Timer_RequeryCvar, aClient);
			return Plugin_Stop;
		}
	}
	g_hTimer[aClient] = CreateTimer(0.1, Timer_QueryNextCvar, aClient, TIMER_REPEAT);
	return Plugin_Stop;
}

public void OnConVarQueryFinished(QueryCookie qCookie, int iClient, ConVarQueryResult qResult, const char[] szCvarName, const char[] szCvarValue, any aSerial)
{
	if (GetClientFromSerial(aSerial) != iClient)
		return;
	// Trie is case sensitive.
	char szCvar[MAX_CVAR_NAME_LEN];
	StringMap smData;
	strcopy(szCvar, sizeof(szCvar), szCvarName);
	StringToLower(szCvar);
	// Did we expect this query?
	if (!g_smCvars.GetValue(szCvar, smData) || smData != g_smCurData[iClient])
		return;
	// Prepare the next query.
	g_smCurData    [iClient] = null;
	g_iRequeryCount[iClient] = 0;
	SetTimer(g_hTimer[iClient], CreateTimer(0.1, Timer_QueryNextCvar, iClient, TIMER_REPEAT));
	// Initialize data
	int SCCompType;
	smData.GetValue(Cvar_CompType, SCCompType);
	char szValue[MAX_CVAR_VALUE_LEN];
	smData.GetString(Cvar_Value, szValue, sizeof(szValue));
	char szValue2[MAX_CVAR_VALUE_LEN];
	smData.GetString(Cvar_Value2, szValue2, sizeof(szValue2));
	char szKickMessage[255];
	// Check query results
	if (qResult == ConVarQuery_Okay)
	{
		if (IsReplicating(smData))
			return;
		switch (SCCompType)
		{
			case Comp_Equal:
			{
				if (StringToFloat(szCvarValue) == StringToFloat(szValue))
					return;
				FormatEx(szKickMessage, sizeof(szKickMessage), "%T", "SMAC_ShouldEqual", iClient, szCvar, szValue, szCvarValue);
			}
			case Comp_StrEqual, Comp_Replicated:
			{
				if (StrEqual(szCvarValue, szValue))
					return;
				FormatEx(szKickMessage, sizeof(szKickMessage), "%T", "SMAC_ShouldEqual", iClient, szCvar, szValue, szCvarValue);
			}
			case Comp_Greater:
			{
				if (StringToFloat(szCvarValue) >= StringToFloat(szValue))
					return;
				FormatEx(szKickMessage, sizeof(szKickMessage), "%T", "SMAC_ShouldBeGreater", iClient, szCvar, szValue, szCvarValue);
			}
			case Comp_Less:
			{
				if (StringToFloat(szCvarValue) <= StringToFloat(szValue))
					return;
				FormatEx(szKickMessage, sizeof(szKickMessage), "%T", "SMAC_ShouldBeLess", iClient, szCvar, szValue, szCvarValue);
			}
			case Comp_Between:
			{
				if (StringToFloat(szCvarValue) >= StringToFloat(szValue) && StringToFloat(szCvarValue) <= StringToFloat(szValue2))
					return;
				FormatEx(szKickMessage, sizeof(szKickMessage), "%T", "SMAC_ShouldBeBetween", iClient, szCvar, szValue, szValue2, szCvarValue);
			}
			case Comp_Outside:
			{
				if (StringToFloat(szCvarValue) < StringToFloat(szValue) || StringToFloat(szCvarValue) > StringToFloat(szValue2))
					return;
				FormatEx(szKickMessage, sizeof(szKickMessage), "%T", "SMAC_ShouldBeOutside", iClient, szCvar, szValue, szValue2, szCvarValue);
			}
			default:
			{
				FormatEx(szKickMessage, sizeof(szKickMessage), "ConVar %s violation", szCvar);
			}
		}
	}
	else if (SCCompType == Comp_NonExist)
	{
		if (qResult == ConVarQuery_NotFound)
			return;
		FormatEx(szKickMessage, sizeof(szKickMessage), "ConVar %s violation", szCvar);
	}
	// The client failed relevant checks.
	CvarAction cAction;
	smData.GetValue(Cvar_Action, cAction);
	KeyValues kvInfo = new KeyValues("");
	kvInfo.SetString("cvar", szCvar);
	kvInfo.SetNum("comptype", view_as<int>(SCCompType));
	kvInfo.SetNum("actiontype", view_as<int>(cAction));
	kvInfo.SetString("cvarvalue", szCvarValue);
	kvInfo.SetString("value", szValue);
	kvInfo.SetString("value2", szValue2);
	kvInfo.SetNum("result", view_as<int>(qResult));
	if (SMAC_CheatDetected(iClient, Detection_CvarViolation, kvInfo) == Plugin_Continue)
	{
		SMAC_PrintAdminNotice("%t", "SMAC_CvarViolation", iClient, szCvar);
		char szResult[16];
		GetQueryResultString(qResult, szResult, sizeof(szResult));
		char szCompType[16];
		GetCompTypeString(SCCompType, szCompType, sizeof(szCompType));
		switch (cAction)
		{
			case Action_Mute:
			{
				if (!BaseComm_IsClientMuted(iClient))
				{
					PrintToChatAll("%t%t", "SMAC_Tag", "SMAC_Muted", iClient);
					BaseComm_SetClientMute(iClient, true);
				}
			}
			case Action_Kick:
			{
				SMAC_LogAction(iClient, "was kicked for failing checks on convar \"%s\". result \"%s\" | CompType: \"%s\" | cvarValue \"%s\" | value: \"%s\" | value2: \"%s\"", szCvar, szResult, szCompType, szCvarValue, szValue, szValue2);
				KickClient(iClient, "\n%s", szKickMessage);
			}
			case Action_Ban:
			{
				SMAC_LogAction(iClient, "was banned for failing checks on convar \"%s\". result \"%s\" | CompType: \"%s\" | cvarValue \"%s\" | value: \"%s\" | value2: \"%s\"", szCvar, szResult, szCompType, szCvarValue, szValue, szValue2);
				SMAC_Ban(iClient, "ConVar %s violation", szCvar);
			}
		}
	}
	delete kvInfo;
}

void OnConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal)
{
	char szCvar[MAX_CVAR_NAME_LEN];
	cv.GetName(szCvar, sizeof(szCvar));
	StringToLower(szCvar);
	StringMap smData;
	if (!g_smCvars.GetValue(szCvar, smData))
		return;
	smData.SetString(Cvar_Value, szNewVal);
	smData.SetValue(Cvar_ReplicatedTime, GetTime() + CVAR_REPLICATION_DELAY);
	// sv_cheats, if enabled, will false positive on client-side cheat commands.
	if (StrEqual(szCvar, "sv_cheats") && StringToInt(szNewVal) != 0)
	{
		cv.SetInt(0, true, true);
		return;
	}
	ReplicateToAll(cv, szNewVal);
}

void ScrambleCvars()
{
	Handle[][] hCvarADTs = new Handle[view_as<int>(Order_MAX)][g_iADTSize];
	StringMap smData;
	int iOrder;
	int[] iADTIndex = new int[view_as<int>(Order_MAX)];
	for (int i = 0; i < g_iADTSize; i++)
	{
		smData = g_arrCvars.Get(i);
		smData.GetValue(Cvar_Order, iOrder);
		hCvarADTs[iOrder][iADTIndex[iOrder]++] = smData;
	}
	g_arrCvars.Clear();
	for (int i = 0; i < view_as<int>(Order_MAX); i++)
	{
		if (iADTIndex[i] > 0)
		{
			SortIntegers(view_as<int>(hCvarADTs[i]), iADTIndex[i], Sort_Random);
			for (int j = 0; j < iADTIndex[i]; j++)
				g_arrCvars.Push(hCvarADTs[i][j]);
		}
	}
}

bool IsReplicating(StringMap smData)
{
	int iReplicatedTime;
	smData.GetValue(Cvar_ReplicatedTime, iReplicatedTime);
	return (iReplicatedTime > GetTime());
}