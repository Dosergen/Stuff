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
#include <sdkhooks>
#include <smac>

/* Globals */
enum ResetStatus
{
	State_Okay = 0,
	State_Resetting,
	State_Reset
};

GameType g_Game = Game_Unknown;

ResetStatus g_TickStatus[MAXPLAYERS + 1];

int g_iPrevButtons[MAXPLAYERS + 1] = {-1, ...};
int g_iPrevCmdNum[MAXPLAYERS + 1] = {-1, ...};
int g_iPrevTickCount[MAXPLAYERS + 1] = {-1, ...};
int g_iCmdNumOffset[MAXPLAYERS + 1] = {1,  ...};

bool g_bBan;
bool g_bCompat;
bool g_bPrevAlive[MAXPLAYERS + 1];

float g_fDetectedTime[MAXPLAYERS + 1];
float g_fMiniGunUseTime[MAXPLAYERS + 1];

ConVar g_cvBan;
ConVar g_cvCompat;

// Arbitrary group names for the purpose of differentiating eye angle detections.
enum EngineGroup
{
	Group_Ignore = 0,
	Group_EP1,
	Group_EP2V,
	Group_L4D2
};

EngineVersion g_EngineVersion = Engine_Unknown;
EngineGroup   g_EngineGroup   = Group_Ignore;

/* Plugin Info */
public Plugin myinfo =
{
	name        = "SMAC Eye Angle Test",
	author      = SMAC_AUTHOR,
	description = "Detects eye angle violations used in cheats",
	version     = SMAC_VERSION,
	url         = SMAC_URL
}

public void OnPluginStart()
{
	// Convars.
	g_cvBan = SMAC_CreateConVar("smac_eyetest_ban", "0", "Automatically ban players on eye test detections.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bBan = g_cvBan.BoolValue;
	g_cvBan.AddChangeHook(ConVarChanged);

	g_cvCompat = SMAC_CreateConVar("smac_eyetest_compat", "1", "Enable compatibility mode with third-party plugins. This will disable some detection methods.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bCompat = g_cvCompat.BoolValue;
	g_cvCompat.AddChangeHook(ConVarChanged);

	// Initialize.
	g_Game = SMAC_GetGameType();
	RequireFeature(FeatureType_Capability, FEATURECAP_PLAYERRUNCMD_11PARAMS, "This module requires a newer version of SourceMod.");

	// Cache engine version and game type.
	g_EngineVersion = GetEngineVersion();
	if (g_EngineVersion == Engine_Unknown)
		SetFailState("Engine Version could not be determined");

	switch (g_EngineVersion)
	{
		case Engine_Original, Engine_DarkMessiah, Engine_SourceSDK2006, Engine_SourceSDK2007, Engine_BloodyGoodTime, Engine_EYE:
		{
			g_EngineGroup = Group_EP1;
		}
		case Engine_CSS, Engine_DODS, Engine_HL2DM, Engine_TF2:
		{
			g_EngineGroup = Group_EP2V;
		}
		case Engine_Left4Dead, Engine_Left4Dead2, Engine_NuclearDawn, Engine_CSGO:
		{
			g_EngineGroup = Group_L4D2;
		}
	}

	LoadTranslations("smac.phrases");
}

void ConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal)
{
	g_bBan = g_cvBan.BoolValue;
	g_bCompat = g_cvCompat.BoolValue;
}

public void OnClientPutInServer(int iClient)
{
	// Clients don't actually disconnect on map change. They start sending the new cmdnums before _Post fires.
	g_bPrevAlive[iClient] = false;
	g_iPrevButtons[iClient] = -1;
	g_iPrevCmdNum[iClient] = -1;
	g_iPrevTickCount[iClient] = -1;
	g_iCmdNumOffset[iClient] =  1;
	g_fDetectedTime[iClient] = 0.0;
	g_fMiniGunUseTime[iClient] = 0.0;
	g_TickStatus[iClient] = State_Okay;
}

public void OnClientDisconnect(int iClient)
{
	// Clients don't actually disconnect on map change. They start sending the new cmdnums before _Post fires.
	g_bPrevAlive[iClient] = false;
	g_iPrevButtons[iClient] = -1;
	g_iPrevCmdNum[iClient] = -1;
	g_iPrevTickCount[iClient] = -1;
	g_iCmdNumOffset[iClient] =  1;
	g_fDetectedTime[iClient] = 0.0;
	g_fMiniGunUseTime[iClient] = 0.0;
	g_TickStatus[iClient] = State_Okay;
}

public void OnPlayerRunCmdPre(int iClient, int iButtons, int iImpulse, const float vVel[3], const float vAng[3], int iWeapon, int iSubType, int iCmdNum, int iTickCount, int iSeed, const int iMouse[2])
{
	// Ignore bots and not valid clients
	if (!IsClientInGame(iClient))
		return;
	if (IsFakeClient(iClient))
		return;
	if (SkipDueToLoss(iClient))
		return;
	static float fTime;
	fTime = GetGameTime();
	// NULL commands
	if (iCmdNum <= 0)
		return;
	// Block old cmds after a client resets their tickcount.
	if (iTickCount <= 0)
		g_TickStatus[iClient] = State_Resetting;
	// Fixes issues caused by client timeouts.
	bool bAlive = IsPlayerAlive(iClient);
	if (!bAlive || !g_bPrevAlive[iClient] || fTime <= g_fDetectedTime[iClient])
	{
		g_bPrevAlive  [iClient] = bAlive;
		g_iPrevButtons[iClient] = iButtons;
		if (g_iPrevCmdNum[iClient] >= iCmdNum)
		{
			if (g_TickStatus[iClient] == State_Resetting)
				g_TickStatus[iClient] = State_Reset;

			g_iCmdNumOffset[iClient]++;
		}
		else
		{
			if (g_TickStatus[iClient] == State_Reset)
				g_TickStatus[iClient] = State_Okay;

			g_iPrevCmdNum  [iClient] = iCmdNum;
			g_iCmdNumOffset[iClient] = 1;
		}
		g_iPrevTickCount[iClient] = iTickCount;
		return;
	}
	// Check for valid cmd values being sent. The command number cannot decrement.
	if (g_iPrevCmdNum[iClient] > iCmdNum)
	{
		if (g_TickStatus[iClient] != State_Okay)
		{
			g_TickStatus[iClient] = State_Reset;
			return;
		}
		g_fDetectedTime[iClient] = fTime + 30.0;
		KeyValues kvInfo = new KeyValues("");
		kvInfo.SetNum("cmdnum",        iCmdNum);
		kvInfo.SetNum("prevcmdnum",    g_iPrevCmdNum[iClient]);
		kvInfo.SetNum("tickcount",     iTickCount);
		kvInfo.SetNum("prevtickcount", g_iPrevTickCount[iClient]);
		kvInfo.SetNum("gametickcount", GetGameTickCount());
		if (SMAC_CheatDetected(iClient, Detection_UserCmdReuse, kvInfo) == Plugin_Continue)
		{
			SMAC_PrintAdminNotice("%t", "SMAC_EyetestDetected", iClient);
			if (g_bBan)
			{
				SMAC_LogAction(iClient, "was banned for reusing old movement commands. CmdNum: %d PrevCmdNum: %d | [%d:%d:%d]", iCmdNum, g_iPrevCmdNum[iClient], g_iPrevTickCount[iClient], iTickCount, GetGameTickCount());
				SMAC_Ban(iClient, "Eye Test Violation");
			}
			else
				SMAC_LogAction(iClient, "is suspected of reusing old movement commands. CmdNum: %d PrevCmdNum: %d | [%d:%d:%d]", iCmdNum, g_iPrevCmdNum[iClient], g_iPrevTickCount[iClient], iTickCount, GetGameTickCount());
		}
		delete kvInfo;
		return;
	}
	// Other than the incremented tickcount, nothing should have changed.
	if (g_iPrevCmdNum[iClient] == iCmdNum)
	{
		if (g_TickStatus[iClient] != State_Okay)
		{
			g_TickStatus[iClient] = State_Reset;
			return;
		}
		// The tickcount should be incremented.
		// No longer true in CS:GO (https://forums.alliedmods.net/showthread.php?t=267559)
		if (g_iPrevTickCount[iClient] != iTickCount && g_iPrevTickCount[iClient] + 1 != iTickCount && iTickCount != GetGameTickCount())
		{
			g_fDetectedTime[iClient] = fTime + 30.0;
			KeyValues kvInfo = new KeyValues("");
			kvInfo.SetNum("cmdnum",        iCmdNum);
			kvInfo.SetNum("tickcount",     iTickCount);
			kvInfo.SetNum("prevtickcount", g_iPrevTickCount[iClient]);
			kvInfo.SetNum("gametickcount", GetGameTickCount());
			if (SMAC_CheatDetected(iClient, Detection_UserCmdTamperingTickcount, kvInfo) == Plugin_Continue)
			{
				SMAC_PrintAdminNotice("%t", "SMAC_EyetestDetected", iClient);
				if (g_bBan)
				{
					SMAC_LogAction(iClient, "was banned for tampering with an old movement command (tickcount). CmdNum: %d | [%d:%d:%d]", iCmdNum, g_iPrevTickCount[iClient], iTickCount, GetGameTickCount());
					SMAC_Ban(iClient, "Eye Test Violation");
				}
				else
					SMAC_LogAction(iClient, "is suspected of tampering with an old movement command (tickcount). CmdNum: %d | [%d:%d:%d]", iCmdNum, g_iPrevTickCount[iClient], iTickCount, GetGameTickCount());
			}
			delete kvInfo;
			return;
		}
		// Check for specific buttons in order to avoid compatibility issues with server-side plugins.
		if (!g_bCompat && ((g_iPrevButtons[iClient] ^ iButtons) & (IN_FORWARD|IN_BACK|IN_MOVELEFT|IN_MOVERIGHT|IN_SCORE)))
		{
			g_fDetectedTime[iClient] = fTime + 30.0;
			KeyValues kvInfo = new KeyValues("");
			kvInfo.SetNum("cmdnum",      iCmdNum);
			kvInfo.SetNum("prevbuttons", g_iPrevButtons[iClient]);
			kvInfo.SetNum("buttons",     iButtons);
			if (SMAC_CheatDetected(iClient, Detection_UserCmdTamperingButtons, kvInfo) == Plugin_Continue)
			{
				SMAC_PrintAdminNotice("%t", "SMAC_EyetestDetected", iClient);
				if (g_bBan)
				{
					SMAC_LogAction(iClient, "was banned for tampering with an old movement command (buttons). CmdNum: %d | [%d:%d]", iCmdNum, g_iPrevButtons[iClient], iButtons);
					SMAC_Ban(iClient, "Eye Test Violation");
				}
				else
					SMAC_LogAction(iClient, "is suspected of tampering with an old movement command (buttons). CmdNum: %d | [%d:%d]", iCmdNum, g_iPrevButtons[iClient], iButtons);
			}
			delete kvInfo;
			return;
		}

		// Track so we can predict the next cmdnum.
		g_iCmdNumOffset[iClient]++;
	}
	else
	{
		// Passively block cheats from skipping to desired seeds.
		if ((iButtons & IN_ATTACK) && g_iPrevCmdNum[iClient] + g_iCmdNumOffset[iClient] != iCmdNum && g_iPrevCmdNum[iClient] > 0)
			iSeed = GetURandomInt();
		g_iCmdNumOffset[iClient] = 1;
	}
	g_iPrevButtons  [iClient] = iButtons;
	g_iPrevCmdNum   [iClient] = iCmdNum;
	g_iPrevTickCount[iClient] = iTickCount;
	if (g_TickStatus[iClient] == State_Reset)
		g_TickStatus[iClient] = State_Okay;
	// Check for valid eye angles.
	switch (g_EngineGroup)
	{
		case Group_L4D2:
		{
			// In L4D+ engines the client can alternate between ±180 and 0-360.
			if (vAng[0] > -135.0 && vAng[0] < 135.0 && vAng[1] > -270.0 && vAng[1] < 420.0)
				return;
		}
		case Group_EP2V:
		{
			// ± normal limit * 1.5 as a buffer zone.
			// TF2 taunts conflict with yaw checks.
			if (vAng[0] > -135.0 && vAng[0] < 135.0 && (g_EngineVersion == Engine_TF2 || (vAng[1] > -270.0 && vAng[1] < 270.0)))
				return;
		}
		case Group_EP1:
		{
			// Older engine support.
			float vTemp[3];
			vTemp = vAng;
			if (vTemp[0] > 180.0)
				vTemp[0] -= 360.0;

			if (vTemp[2] > 180.0)
				vTemp[2] -= 360.0;

			if (vTemp[0] >= -90.0 && vTemp[0] <= 90.0 && vTemp[2] >= -90.0 && vTemp[2] <= 90.0)
				return;
		}
		default:
		{
			// Ignore angles for this engine.
			return;
		}
	}
	// Game specific checks.
	switch (g_Game)
	{
		case Game_DODS:
		{
			// Ignore prone players.
			if (DODS_IsPlayerProne(iClient))
				return;
		}
		case Game_L4D:
		{
			// Only check survivors in first-person view.
			if (GetClientTeam(iClient) != 2)
				return;

			if (L4D_IsSurvivorBusy(iClient))
				return;

			if (IsUsingMinigun(iClient))
			{
				g_fMiniGunUseTime[iClient] = fTime + 3.0;
				return;
			}
		}
		case Game_L4D2:
		{
			// Only check survivors in first-person view.
			if (GetClientTeam(iClient) != 2)
				return;

			if (L4D2_IsSurvivorBusy(iClient))
				return;

			if (IsUsingMinigun(iClient))
			{
				g_fMiniGunUseTime[iClient] = fTime + 3.0;
				return;
			}
		}
		case Game_ND:
		{
			if (ND_IsPlayerCommander(iClient))
				return;
		}
	}
	// Ignore clients that are interacting with the map.
	int iFlags = GetEntityFlags(iClient);
	if (iFlags & FL_FROZEN)
		return;
	if (iFlags & FL_ATCONTROLS)
		return;
	if (fTime < g_fMiniGunUseTime[iClient])
		return;
	// The client failed all checks.
	g_fDetectedTime[iClient] = fTime + 30.0;
	// Strict bot checking - https://bugs.alliedmods.net/show_bug.cgi?id=5294
	char szAuthID[MAX_AUTHID_LENGTH];
	KeyValues kvInfo = new KeyValues("");
	kvInfo.SetVector("angles", vAng);
	if (GetClientAuthId(iClient, AuthId_Steam2, szAuthID, sizeof(szAuthID), false) && !StrEqual(szAuthID, "BOT") && SMAC_CheatDetected(iClient, Detection_Eyeangles, kvInfo) == Plugin_Continue)
	{
		SMAC_PrintAdminNotice("%t", "SMAC_EyetestDetected", iClient);
		if (g_bBan)
		{
			SMAC_LogAction(iClient, "was banned for cheating with their eye angles. Eye Angles: %.0f %.0f %.0f", vAng[0], vAng[1], vAng[2]);
			SMAC_Ban(iClient, "Eye Test Violation");
		}
		else
			SMAC_LogAction(iClient, "is suspected of cheating with their eye angles. Eye Angles: %.0f %.0f %.0f", vAng[0], vAng[1], vAng[2]);
	}
	delete kvInfo;
}

bool SkipDueToLoss(int iClient)
{
	return GetClientAvgLoss(iClient, NetFlow_Both) > 0.5;
}

stock bool IsUsingMinigun(int iClient)
{
	return ((GetEntProp(iClient, Prop_Send, "m_usingMountedWeapon") > 0) || (GetEntProp(iClient, Prop_Send, g_Game == Game_L4D2 ? "m_usingMountedGun" : "m_usingMinigun") > 0));
}