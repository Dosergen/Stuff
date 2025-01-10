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
#define IS_VALID_CLIENT(%1) (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1) (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1) (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1) (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1) (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1) (IS_VALID_INGAME(%1) && IS_INFECTED(%1))

#define ZC_SMOKER  1
#define ZC_BOOMER  2
#define ZC_HUNTER  3
#define ZC_SPITTER 4
#define ZC_JOCKEY  5
#define ZC_CHARGER 6
#define ZC_TANK    8

#define HOP_ACCEL_THRESH 0.01 // bhop speed increase must be higher than this for it to count as part of a hop streak
#define HOP_CHECK_TIME 0.1
#define HOPEND_CHECK_TIME 0.1 // after streak end (potentially) detected, to check for realz?

int g_iHops[MAXPLAYERS + 1]; // amount of hops in streak

bool g_bIsHopping[MAXPLAYERS + 1];
bool g_bHopCheck[MAXPLAYERS + 1];

float g_vLastHop[MAXPLAYERS + 1][3]; // velocity vector of last jump
float g_fHopTopVelocity[MAXPLAYERS + 1];

ConVar g_cvEnabled;
bool g_bEnabled;

ConVar g_cvBHopMinInitSpeed;
float g_fBHopMinInitSpeed;

ConVar g_cvBHopContSpeed;
float g_fBHopContSpeed;

ConVar g_cvBHopMinStreak;
int g_iBHopMinStreak;

/* Plugin Info */
public Plugin myinfo =
{
	name        = "SMAC BunnyHop Detector",
	author      = "H.se",
	description = "Detect BHop",
	version     = SMAC_VERSION,
	url         = SMAC_URL
}

/* Plugin Functions */
public void OnPluginStart()
{
	HookEvent("player_jump", Event_PlayerJumped, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
//	HookEvent("scavenge_round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	// Convars
	g_cvEnabled = CreateConVar("smac_bh_detect", "1", "Enable bh detect module?", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bEnabled = g_cvEnabled.BoolValue;
	g_cvEnabled.AddChangeHook(ConVarChanged);

	g_cvBHopMinInitSpeed = CreateConVar("smac_bh_initspeed", "150", "The minimal speed of the first jump of a bunnyhop streak (0 to allow 'hops' from standstill).", FCVAR_NONE, true, 0.0, false, 0.0);
	g_fBHopMinInitSpeed = g_cvBHopMinInitSpeed.FloatValue;
	g_cvBHopMinInitSpeed.AddChangeHook(ConVarChanged);

	g_cvBHopContSpeed = CreateConVar("smac_bh_keepspeed", "300", "The minimal speed at which hops are considered successful even if not speed increase is made.", FCVAR_NONE, true, 0.0, false, 0.0);
	g_fBHopContSpeed = g_cvBHopContSpeed.FloatValue;
	g_cvBHopContSpeed.AddChangeHook(ConVarChanged);

	g_cvBHopMinStreak = CreateConVar("smac_bh_bhopstreak", "12", "The lowest bunnyhop streak that will be reported.", FCVAR_NONE, true, 0.0, false, 0.0);
	g_iBHopMinStreak = g_cvBHopMinStreak.IntValue;
	g_cvBHopMinStreak.AddChangeHook(ConVarChanged);

	LoadTranslations("smac.phrases");
}

void ConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal)
{
	g_bEnabled = g_cvEnabled.BoolValue;
	g_fBHopMinInitSpeed = g_cvBHopMinInitSpeed.FloatValue;
	g_fBHopContSpeed = g_cvBHopContSpeed.FloatValue;
	g_iBHopMinStreak = g_cvBHopMinStreak.IntValue;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
		g_bIsHopping[i] = false;
}

void Event_PlayerJumped(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	if (IS_VALID_SURVIVOR(iClient) || IS_VALID_INFECTED(iClient))
	{
		int iClass = GetEntProp(iClient, Prop_Send, "m_zombieClass");
		if (iClass < ZC_TANK)
			return;
		// could be the start or part of a hopping streak
		float vVel[3];
		GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vVel);
		vVel[2] = 0.0; // safeguard
		float fLengthNew;
		fLengthNew = GetVectorLength(vVel);
		g_bHopCheck[iClient] = false;
		if (!g_bIsHopping[iClient])
		{
			if (fLengthNew >= g_fBHopMinInitSpeed)
			{
				// starting potential hop streak
				g_fHopTopVelocity[iClient] = fLengthNew;
				g_bIsHopping     [iClient] = true;
				g_iHops          [iClient] = 0;
			}
		}
		else
		{
			// check for hopping streak
			float fLengthOld;
			fLengthOld = GetVectorLength(g_vLastHop[iClient]);
			// if they picked up speed, count it as a hop, otherwise, we're done hopping
			if (fLengthNew - fLengthOld > HOP_ACCEL_THRESH || fLengthNew >= g_fBHopContSpeed)
			{
				g_iHops[iClient]++;
				// this should always be the case...
				if (fLengthNew > g_fHopTopVelocity[iClient])
					g_fHopTopVelocity[iClient] = fLengthNew;
			}
			else
			{
				g_bIsHopping[iClient] = false;
				if (g_iHops[iClient])
				{
					HandleBHopStreak(iClient, g_iHops[iClient], g_fHopTopVelocity[iClient]);
					g_iHops[iClient] = 0;
				}
			}
		}
		g_vLastHop[iClient][0] = vVel[0];
		g_vLastHop[iClient][1] = vVel[1];
		g_vLastHop[iClient][2] = vVel[2];
		// check when the player returns to the ground
		if (g_iHops[iClient] != 0)
			CreateTimer(HOP_CHECK_TIME, Timer_CheckHop, GetClientUserId(iClient), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action Timer_CheckHop(Handle hTimer, any aUserId)
{
	int iClient = GetClientOfUserId(aUserId);
	// player back to ground = end of hop (streak)?
	if (!IS_VALID_INGAME(iClient))
		return Plugin_Stop;
	if (!IsPlayerAlive(iClient))
		return Plugin_Stop;
	if (GetEntityFlags(iClient) & FL_ONGROUND)
	{
		float vVel[3];
		GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vVel);
		vVel[2] = 0.0; // safeguard
		g_bHopCheck[iClient] = true;
		CreateTimer(HOPEND_CHECK_TIME, Timer_CheckHopStreak, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

Action Timer_CheckHopStreak(Handle hTimer, any aUserId)
{
	int iClient = GetClientOfUserId(aUserId);
	if (!IS_VALID_INGAME(iClient))
		return Plugin_Continue;
	if (!IsPlayerAlive(iClient))
		return Plugin_Continue;
	// check if we have any sort of hop streak, and report
	if (g_bHopCheck[iClient] && g_iHops[iClient])
	{
		HandleBHopStreak(iClient, g_iHops[iClient], g_fHopTopVelocity[iClient]);
		g_bIsHopping     [iClient] = false;
		g_iHops          [iClient] = 0;
		g_fHopTopVelocity[iClient] = 0.0;
	}
	g_bHopCheck[iClient] = false;
	return Plugin_Continue;
}

// bhaps
void HandleBHopStreak(int iSurvivor, int iStreak, float fMaxVelocity)
{
	if (IS_VALID_INGAME(iSurvivor) && !IsFakeClient(iSurvivor) && iStreak >= g_iBHopMinStreak)
	{
		SMAC_PrintAdminNotice("%N is suspected of using auto-trigger cheat: BunnyHop [hops = %i, velocity = %.1f]", iSurvivor, iStreak, fMaxVelocity);
		SMAC_LogAction(iSurvivor, "is suspected of using auto-trigger cheat: BunnyHop [hops = %i, velocity = %.1f]", iStreak, fMaxVelocity);
	}
}