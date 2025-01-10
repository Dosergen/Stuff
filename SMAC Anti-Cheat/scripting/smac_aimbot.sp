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
#define AIM_ANGLE_CHANGE 45.0 // Max angle change that a player should snap
#define AIM_BAN_MIN 4 // Minimum number of detections before an auto-ban is allowed
#define AIM_MIN_DISTANCE 200.0 // Minimum distance acceptable for a detection.

int g_iEyeIdx[MAXPLAYERS + 1];
int g_iAimDetections[MAXPLAYERS + 1];
int g_iMaxAngleHistory;

float g_vAng[MAXPLAYERS + 1][64][3];

ConVar g_cvAimbotBan;
int g_iAimbotBan;

StringMap g_smIgnoreWeapons;

/* Plugin Info */
public Plugin myinfo =
{
	name        = "SMAC Aimbot Detector",
	author      = SMAC_AUTHOR,
	description = "Analyzes clients to detect aimbots",
	version     = SMAC_VERSION,
	url         = SMAC_URL
}

/* Plugin Functions */
public void OnPluginStart()
{
	// Convars.
	g_cvAimbotBan = SMAC_CreateConVar("smac_aimbot_ban", "4", "Number of aimbot detections before a player is banned. Minimum allowed is 4. (0 = Never ban)", FCVAR_NONE, true, 0.0, false, 0.0);
	g_iAimbotBan = g_cvAimbotBan.IntValue;
	g_cvAimbotBan.AddChangeHook(OnSettingsChanged);

	// Store no more than 500ms worth of angle history.
	if ((g_iMaxAngleHistory = TIME_TO_TICK(0.5)) > sizeof(g_vAng[]))
		g_iMaxAngleHistory = sizeof(g_vAng[]);

	// Weapons to ignore when analyzing.
	g_smIgnoreWeapons = new StringMap();
	switch (SMAC_GetGameType())
	{
		case Game_CSS:
		{    
			g_smIgnoreWeapons.SetValue("weapon_knife", 1);
		}
		case Game_CSGO:
		{
			g_smIgnoreWeapons.SetValue("weapon_knife", 1);
			g_smIgnoreWeapons.SetValue("weapon_taser", 1);
		}
		case Game_DODS:
		{
			g_smIgnoreWeapons.SetValue("weapon_spade", 1);
			g_smIgnoreWeapons.SetValue("weapon_amerknife", 1);
		}
		case Game_TF2:
		{
			g_smIgnoreWeapons.SetValue("tf_weapon_bottle", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_sword", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_wrench", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_robot_arm", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_fists", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_bonesaw", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_fireaxe", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_bat", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_bat_wood", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_bat_fish", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_club", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_shovel", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_knife", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_stickbomb", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_katana", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_flamethrower", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_slap", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_buff_item", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_parachute", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_breakable_sign", 1);
			g_smIgnoreWeapons.SetValue("tf_wearable_demoshield", 1);
			g_smIgnoreWeapons.SetValue("tf_wearable_razorback", 1);
			g_smIgnoreWeapons.SetValue("tf_wearable", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_rocketpack", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_lunchbox_drink", 1);
			g_smIgnoreWeapons.SetValue("tf_weapon_lunchbox", 1);
			g_smIgnoreWeapons.SetValue("saxxy", 1);
		}
		case Game_HL2DM:
		{
			g_smIgnoreWeapons.SetValue("weapon_crowbar", 1);
			g_smIgnoreWeapons.SetValue("weapon_stunstick", 1);
		}
	}

	// Hooks.
	HookEntityOutput("trigger_teleport", "OnEndTouch", Teleport_OnEndTouch);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	if (SMAC_GetGameType() == Game_TF2)
		HookEvent("player_death", TF2_Event_PlayerDeath, EventHookMode_Post);
	else if (!HookEventEx("entity_killed", Event_EntityKilled, EventHookMode_Post))
		HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);

	LoadTranslations("smac.phrases");
}

public void OnClientPutInServer(int iClient)
{
	if (!IsClientNew(iClient))
		return;
	g_iAimDetections[iClient] = 0;
	Aimbot_ClearAngles(iClient);
}

void OnSettingsChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal)
{
	int iNewValue = g_cvAimbotBan.IntValue;
	if (iNewValue > 0 && iNewValue < AIM_BAN_MIN)
	{
		g_cvAimbotBan.SetInt(AIM_BAN_MIN);
		return;
	}
	g_iAimbotBan = iNewValue;
}

void Teleport_OnEndTouch(const char[] szOutput, int iCaller, int iActivator, float fDelay)
{
	/* A client is being teleported in the map. */
	if (!IS_CLIENT(iActivator))
		return;
	if (!IsClientConnected(iActivator))
		return;
	Aimbot_ClearAngles(iActivator);
	CreateTimer(0.1 + fDelay, Timer_ClearAngles, iActivator, TIMER_FLAG_NO_MAPCHANGE);
}

void Event_PlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	if (!IS_CLIENT(iClient))
		return;
	Aimbot_ClearAngles(iClient);
	CreateTimer(0.1, Timer_ClearAngles, iClient, TIMER_FLAG_NO_MAPCHANGE);
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	char szWeapon[32];
	eEvent.GetString("weapon", szWeapon, sizeof(szWeapon));
	int iDummy;
	if (g_smIgnoreWeapons.GetValue(szWeapon, iDummy))
		return;
	int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
	int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
	if (!IS_CLIENT(iVictim))
		return;
	if (!IS_CLIENT(iAttacker))
		return;
	if (iVictim == iAttacker)
		return;
	if (!IsClientInGame(iVictim))
		return;
	if (!IsClientInGame(iAttacker))
		return;
	float vVictim[3];
	GetClientAbsOrigin(iVictim, vVictim);
	float vAttacker[3];
	GetClientAbsOrigin(iAttacker, vAttacker);
	if (GetVectorDistance(vVictim, vAttacker) < AIM_MIN_DISTANCE)
		return;
	Aimbot_AnalyzeAngles(iAttacker);
}

void Event_EntityKilled(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	/* (OB Only) Inflictor support lets us ignore non-bullet weapons. */
	int iVictim = eEvent.GetInt("entindex_killed");
	int iAttacker = eEvent.GetInt("entindex_attacker");
	int iInflictor = eEvent.GetInt("entindex_inflictor");
	if (!IS_CLIENT(iVictim))
		return;
	if (!IS_CLIENT(iAttacker))
		return;
	if (iVictim == iAttacker)
		return;
	if (iAttacker != iInflictor)
		return;
	if (!IsClientInGame(iVictim))
		return;
	if (!IsClientInGame(iAttacker))
		return;
	char szWeapon[32];
	GetClientWeapon(iAttacker, szWeapon, sizeof(szWeapon));
	int iDummy;
	if (g_smIgnoreWeapons.GetValue(szWeapon, iDummy))
		return;
	float vVictim[3];
	GetClientAbsOrigin(iVictim, vVictim);
	float vAttacker[3];
	GetClientAbsOrigin(iAttacker, vAttacker);
	if (GetVectorDistance(vVictim, vAttacker) < AIM_MIN_DISTANCE)
		return;
	Aimbot_AnalyzeAngles(iAttacker);
}

void TF2_Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	/* TF2 custom death event */
	int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
	int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
	int iInflictor = eEvent.GetInt("inflictor_entindex");
	if (!IS_CLIENT(iVictim))
		return;
	if (!IS_CLIENT(iAttacker))
		return;
	if (iVictim == iAttacker)
		return;
	if (iAttacker != iInflictor)
		return;
	if (!IsClientInGame(iVictim))
		return;
	if (!IsClientInGame(iAttacker))
		return;
	char szWeapon[32];
	GetClientWeapon(iAttacker, szWeapon, sizeof(szWeapon));
	int iDummy;
	if (g_smIgnoreWeapons.GetValue(szWeapon, iDummy))
		return;
	float vVictim[3];
	GetClientAbsOrigin(iVictim, vVictim);
	float vAttacker[3];
	GetClientAbsOrigin(iAttacker, vAttacker);
	if (GetVectorDistance(vVictim, vAttacker) < AIM_MIN_DISTANCE)
		return;
	Aimbot_AnalyzeAngles(iAttacker);
}

Action Timer_ClearAngles(Handle hTimer, any iClient)
{
	/* Delayed because the client's angles can sometimes "spin" after being teleported. */
	Aimbot_ClearAngles(iClient);
	return Plugin_Stop;
}

Action Timer_DecreaseCount(Handle hTimer, any iClient)
{
	/* Decrease the detection count by 1. */
	if (g_iAimDetections[iClient] <= 0)
		return Plugin_Stop;
	g_iAimDetections[iClient]--;
	return Plugin_Stop;
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
	g_vAng[iClient][g_iEyeIdx[iClient]] = vAng;
	if (++g_iEyeIdx[iClient] == g_iMaxAngleHistory)
		g_iEyeIdx[iClient] = 0;
}

void Aimbot_AnalyzeAngles(int iClient)
{
	/* Analyze the client to see if their angles snapped. */
	float vLastAngles[3];
	float vAngles[3];
	float fAngleDiff;
	int iIdx = g_iEyeIdx[iClient];
	for (int i = 0; i < g_iMaxAngleHistory; i++)
	{
		if (iIdx == g_iMaxAngleHistory)
			iIdx = 0;
		if (IsVectorZero(g_vAng[iClient][iIdx]))
			break;
		// Nothing to compare on the first iteration.
		if (i == 0)
		{
			vLastAngles = g_vAng[iClient][iIdx];
			iIdx++;
			continue;
		}
		vAngles    = g_vAng[iClient][iIdx];
		fAngleDiff = GetVectorDistance(vLastAngles, vAngles);
		// If the difference is being reported higher than 180, get the 'real' value.
		if (fAngleDiff > 180)
			fAngleDiff = FloatAbs(fAngleDiff - 360);
		if (fAngleDiff > AIM_ANGLE_CHANGE)
		{
			Aimbot_Detected(iClient, fAngleDiff);
			break;
		}
		vLastAngles = vAngles;
		iIdx++;
	}
}

void Aimbot_Detected(int iClient, float fDeviation)
{
	// Extra checks must be done here because of data coming from two events.
	if (IsFakeClient(iClient))
		return;
	if (!IsPlayerAlive(iClient))
		return;
	switch (SMAC_GetGameType())
	{
		case Game_L4D:
		{
			if (GetClientTeam(iClient) != 2)
				return;
			if (L4D_IsSurvivorBusy(iClient))
				return;
		}
		case Game_L4D2:
		{
			if (GetClientTeam(iClient) != 2)
				return;
			if (L4D2_IsSurvivorBusy(iClient))
				return;
		}
		case Game_ND:
		{
			if (ND_IsPlayerCommander(iClient))
				return;
		}
	}
	char szWeapon[32];
	GetClientWeapon(iClient, szWeapon, sizeof(szWeapon));
	KeyValues kvInfo = new KeyValues("");
	kvInfo.SetNum("detection",   g_iAimDetections[iClient]);
	kvInfo.SetFloat("deviation", fDeviation);
	kvInfo.SetString("weapon",   szWeapon);
	if (SMAC_CheatDetected(iClient, Detection_Aimbot, kvInfo) == Plugin_Continue)
	{
		// Expire this detection after 10 minutes.
		CreateTimer(600.0, Timer_DecreaseCount, iClient);
		// Ignore the first detection as it's just as likely to be a false positive.
		if (++g_iAimDetections[iClient] > 1)
		{
			SMAC_PrintAdminNotice("%t", "SMAC_AimbotDetected", iClient, g_iAimDetections[iClient], fDeviation, szWeapon);
			SMAC_LogAction(iClient, "is suspected of using an aimbot. (Detection #%i | Deviation: %.0f° | Weapon: %s)", g_iAimDetections[iClient], fDeviation, szWeapon);
			if (g_iAimbotBan && g_iAimDetections[iClient] >= g_iAimbotBan)
			{
				SMAC_LogAction(iClient, "was banned for using an aimbot.");
				SMAC_Ban(iClient, "Aimbot Detected");
			}
		}
	}
	delete kvInfo;
}

void Aimbot_ClearAngles(int iClient)
{
	/* Clear angle history and reset the index. */
	g_iEyeIdx[iClient] = 0;
	for (int i = 0; i < g_iMaxAngleHistory; i++)
		ZeroVector(g_vAng[iClient][i]);
}