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
#define TRIGGER_DETECTIONS 30 // Amount of detections needed to perform action.
#define MIN_JUMP_TIME 0.500 // Minimum amount of air-time for a jump to count.

// Detection methods.
#define METHOD_BUNNYHOP 0
#define METHOD_AUTOFIRE 1
#define METHOD_MAX 2

// Integers
int g_iAttackMax = 66;
int g_iDetections[METHOD_MAX][MAXPLAYERS + 1];

// ConVars
ConVar g_cvEnabled;
bool g_bEnabled;

ConVar g_cvBan;
bool g_bBan;

/* Plugin Info */
public Plugin myinfo =
{
	name        = "SMAC AutoTrigger Detector",
	author      = SMAC_AUTHOR,
	description = "Detects cheats that automatically press buttons for players",
	version     = SMAC_VERSION,
	url         = SMAC_URL
}

/* Plugin Functions */
public void OnPluginStart()
{
	// Convars.
	g_cvEnabled = SMAC_CreateConVar("smac_autotrigger_enabled", "1", "Enable auto-trigger detect module?", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bEnabled = g_cvEnabled.BoolValue;
	g_cvEnabled.AddChangeHook(ConVarChanged);

	g_cvBan = SMAC_CreateConVar("smac_autotrigger_ban", "0", "Automatically ban players on auto-trigger detections.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bBan = g_cvBan.BoolValue;
	g_cvBan.AddChangeHook(ConVarChanged);

	// Initialize.
	g_iAttackMax = RoundToNearest(1.0 / GetTickInterval() / 3.0);
	CreateTimer(4.0, Timer_DecreaseCount, _, TIMER_REPEAT);

	LoadTranslations("smac.phrases");
}

void ConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal)
{
	g_bEnabled = g_cvEnabled.BoolValue;
	g_bBan = g_cvBan.BoolValue;
}

public void OnClientDisconnect(int iClient)
{
	for (int i = 0; i < METHOD_MAX; i++)
		g_iDetections[i][iClient] = 0;
}

Action Timer_DecreaseCount(Handle hTimer)
{
	for (int i = 0; i < METHOD_MAX; i++)
	{
		for (int j = 1; j <= MaxClients; j++)
		{
			if (g_iDetections[i][j] > 0)
				g_iDetections[i][j]--;
		}
	}
	return Plugin_Continue;
}

public void OnPlayerRunCmdPre(int iClient, int iButtons, int iImpulse, const float vVel[3], const float vAng[3], int iWeapon)
{
	if (!g_bEnabled)
		return;
	// Ignore bots and not valid clients
	if (iClient <= 0)
		return;
	if (iClient > MaxClients)
		return;
	if (!IsClientInGame(iClient))
		return;
	if (IsFakeClient(iClient))
		return;
	static int iPrevButtons[MAXPLAYERS + 1];
	/* BunnyHop */
	static float fCheckTime[MAXPLAYERS + 1];
	// Player didn't jump immediately after the last jump.
	if (!(iButtons & IN_JUMP) && (GetEntityFlags(iClient) & FL_ONGROUND) && fCheckTime[iClient] > 0.0)
		fCheckTime[iClient] = 0.0;
	// Ignore this jump if the player is in a tight space or stuck in the ground.
	if ((iButtons & IN_JUMP) && !(iPrevButtons[iClient] & IN_JUMP))
	{
		// Player is on the ground and about to trigger a jump.
		if (GetEntityFlags(iClient) & FL_ONGROUND)
		{
			float fGameTime = GetGameTime();
			// Player jumped on the exact frame that allowed it.
			if (fCheckTime[iClient] > 0.0 && fGameTime > fCheckTime[iClient])
				AutoTrigger_Detected(iClient, METHOD_BUNNYHOP);
			else
				fCheckTime[iClient] = fGameTime + MIN_JUMP_TIME;
		}
		else
			fCheckTime[iClient] = 0.0;
	}
	/* Auto-Fire */
	static int iAttackAmt[MAXPLAYERS + 1];
	static bool bResetNext[MAXPLAYERS + 1];
	if (((iButtons & IN_ATTACK) && !(iPrevButtons[iClient] & IN_ATTACK)) || (!(iButtons & IN_ATTACK) && (iPrevButtons[iClient] & IN_ATTACK)))
	{
		if (++iAttackAmt[iClient] >= g_iAttackMax)
		{
			AutoTrigger_Detected(iClient, METHOD_AUTOFIRE);
			iAttackAmt[iClient] = 0;
		}
		bResetNext[iClient] = false;
	} 
	else if (bResetNext[iClient])
	{
		iAttackAmt[iClient] = 0;
		bResetNext[iClient] = false;
	}
	else
		bResetNext[iClient] = true;

	iPrevButtons[iClient] = iButtons;
}

void AutoTrigger_Detected(int iClient, int iMethod)
{
	if (IsFakeClient(iClient))
		return;
	if (!IsPlayerAlive(iClient))
		return;
	g_iDetections[iMethod][iClient]++;
	if (g_iDetections[iMethod][iClient] < TRIGGER_DETECTIONS)
		return;
	char szMethod[32];
	switch (iMethod)
	{
		case METHOD_BUNNYHOP:
		{
			strcopy(szMethod, sizeof(szMethod), "BunnyHop");
		}
		case METHOD_AUTOFIRE:
		{
			strcopy(szMethod, sizeof(szMethod), "Auto-Fire");
		}
	}
	KeyValues kvInfo = new KeyValues("");
	kvInfo.SetString("method", szMethod);
	if (SMAC_CheatDetected(iClient, Detection_AutoTrigger, kvInfo) == Plugin_Continue)
	{
		SMAC_PrintAdminNotice("%t", "SMAC_AutoTriggerDetected", iClient, szMethod);
		if (g_bBan)
		{
			SMAC_LogAction(iClient, "was banned for using auto-trigger cheat: %s", szMethod);
			SMAC_Ban(iClient, "AutoTrigger Detection: %s", szMethod);
		}
		else
			SMAC_LogAction(iClient, "is suspected of using auto-trigger cheat: %s", szMethod);
	}
	delete kvInfo;
	g_iDetections[iMethod][iClient] = 0;
}