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
#define SPIN_DETECTIONS 15 // Seconds of non-stop spinning before spinhack is detected
#define SPIN_ANGLE_CHANGE 1440.0 // Max angle deviation over one second before being flagged
#define SPIN_SENSITIVITY 6 // Ignore players with a higher mouse sensitivity than this

int g_iSpinCount[MAXPLAYERS + 1];
float g_fPrevAngle[MAXPLAYERS + 1];
float g_fAngleDiff[MAXPLAYERS + 1];
float g_fSensitivity[MAXPLAYERS + 1];
float g_fAngleBuffer;

/* Plugin Info */
public Plugin myinfo =
{
	name        = "SMAC Spinhack Detector",
	author      = SMAC_AUTHOR,
	description = "Monitors players to detect the use of spinhacks",
	version     = SMAC_VERSION,
	url         = SMAC_URL
}

/* Plugin Functions */
public void OnPluginStart()
{
	CreateTimer(1.0, Timer_CheckSpins, _, TIMER_REPEAT);
	LoadTranslations("smac.phrases");
}

public void OnClientDisconnect(int iClient)
{
	g_iSpinCount[iClient] = 0;
	g_fSensitivity[iClient] = 0.0;
}

Action Timer_CheckSpins(Handle hTimer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		if (IsFakeClient(i))
			continue;
		if (g_fAngleDiff[i] > SPIN_ANGLE_CHANGE && IsPlayerAlive(i))
		{
			g_iSpinCount[i]++;
			if (g_iSpinCount[i] == 1) QueryClientConVar(i, "sensitivity", Query_MouseCheck, GetClientSerial(i));
			if (g_iSpinCount[i] == SPIN_DETECTIONS && g_fSensitivity[i] <= SPIN_SENSITIVITY)
				Spinhack_Detected(i);
		}
		else
			g_iSpinCount[i] = 0;

		g_fAngleDiff[i] = 0.0;
	}
	return Plugin_Continue;
}

public void Query_MouseCheck(QueryCookie qCookie, int iClient, ConVarQueryResult cvResult, const char[] szCvarName, const char[] szCvarValue, any aSerial)
{
	if (cvResult != ConVarQuery_Okay)
		return;
	if (GetClientFromSerial(aSerial) != iClient)
		return;
	g_fSensitivity[iClient] = StringToFloat(szCvarValue);
}

public void OnPlayerRunCmdPre(int iClient, int iButtons, int iImpulse, const float vVel[3], const float vAng[3], int iWeapon)
{
	// Ignore bots and not valid clients
	if (iClient <= 0)
		return;
	if (iClient > MaxClients)
		return;
	if (!IsClientInGame(iClient))
		return;
	if (IsFakeClient(iClient))
		return;
	if (!(iButtons & IN_LEFT || iButtons & IN_RIGHT))
	{
		// Only checking the Z axis here.
		g_fAngleBuffer = FloatAbs(vAng[1] - g_fPrevAngle[iClient]);
		g_fAngleDiff[iClient] += (g_fAngleBuffer > 180.0) ? (g_fAngleBuffer - 360.0) * -1.0 : g_fAngleBuffer;
		g_fPrevAngle[iClient] = vAng[1];
	}
}

void Spinhack_Detected(int iClient)
{
	if (SMAC_CheatDetected(iClient, Detection_Spinhack, null) == Plugin_Continue)
	{
		SMAC_PrintAdminNotice("%t", "SMAC_SpinhackDetected", iClient);
		SMAC_LogAction(iClient, "is suspected of using a spinhack.");
	}
}