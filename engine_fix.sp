#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define TEAM_SURVIVORS 2

#define FIRST_RESTORE_TIME 0.3
#define RESTORE_TIME 2.0
#define MAX_HEALTH_PER_RESTORE 10
#define MAX_HEALTH 100
#define CONSTANT_HEALTH 1
#define MAX_TEMP_HEALTH MAX_HEALTH - CONSTANT_HEALTH

#define LADDER_SPEED_GLITCH_FIX  (1 << 0)
#define NO_FALL_DAMAGE_BUG_FIX   (1 << 1)
#define HEALTH_BOOST_GLITCH_FIX  (1 << 2)
#define LADDER_RELOAD_GLITCH_FIX (1 << 3)

ConVar g_cvDecayRate;
float g_fDecayRate;

ConVar g_cvEngineFlags;
int g_iEngineFlags;

Handle g_hFixGlitchTimer[MAXPLAYERS + 1];
Handle g_hRestoreTimer[MAXPLAYERS + 1];

int g_iHealthToRestore[MAXPLAYERS + 1];
int g_iLastKnownHealth[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name        = "[L4D & L4D2] Engine Fix",
	author      = "raziEiL [disawar1]",
	description = "Blocking ladder speed glitch, no fall damage bug, health boost glitch.",
	version     = "1.2",
	url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

public void OnPluginStart() 
{
	g_cvDecayRate = FindConVar("pain_pills_decay_rate");
	g_fDecayRate = g_cvDecayRate.FloatValue;
	g_cvDecayRate.AddChangeHook(ConVarChanged_DecayRate);

	g_cvEngineFlags = CreateConVar("engine_fix_flags", "15", "What kind of exploit should be fixed/blocked (add together). 0: Off , 1: ladder speed glitch, 2: no fall damage bug, 4: health boost glitch, 8: ladder reload glitch.", FCVAR_NONE, true, 0.0, true, 15.0);
	g_iEngineFlags = g_cvEngineFlags.IntValue;
	g_cvEngineFlags.AddChangeHook(ConVarChanged_EngineFlags);

	ToogleEvents(!!(g_iEngineFlags & HEALTH_BOOST_GLITCH_FIX));
	
	AutoExecConfig(true, "engine_fix");
}

void ConVarChanged_DecayRate(ConVar cv, const char[] szOldVal, const char[] szNewVal)
{
	g_fDecayRate = g_cvDecayRate.FloatValue;
}

void ConVarChanged_EngineFlags(ConVar cv, const char[] szOldVal, const char[] szNewVal)
{
	g_iEngineFlags = g_cvEngineFlags.IntValue;
	ToogleEvents(!!(g_iEngineFlags & HEALTH_BOOST_GLITCH_FIX));
}

void ToogleEvents(bool bHook)
{
	for (int i = 1; i <= MaxClients; i++)
		EF_ClearAllVars(i);
	static bool bIsHooked;
	if (!bIsHooked && bHook)
	{
		HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		HookEvent("pills_used", Event_PillsUsed);
		HookEvent("player_hurt", Event_PlayerHurt);
		HookEvent("heal_success", Event_HealSuccess);
		HookEvent("revive_success", Event_HealSuccess);
		HookEvent("player_incapacitated", Event_HealSuccess);
		bIsHooked = true;
	}
	else if (bIsHooked && !bHook)
	{
		UnhookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("pills_used", Event_PillsUsed);
		UnhookEvent("player_hurt", Event_PlayerHurt);
		UnhookEvent("heal_success", Event_HealSuccess);
		UnhookEvent("revive_success", Event_HealSuccess);
		UnhookEvent("player_incapacitated", Event_HealSuccess);
		bIsHooked = false;
	}
}

public void OnMapEnd() 
{
	for (int i = 0; i <= MaxClients; i++)
	{
		g_hRestoreTimer[i] = null;
		g_hFixGlitchTimer[i] = null;
	}
}

/**
 * LADDER GLITCH
 * NO FALL DMG GLITCH
**/
public Action OnPlayerRunCmd(int iClient, int &iButtons) 
{
	if (!g_iEngineFlags)
		return Plugin_Continue;
	if (!IsValidClient(iClient))
		return Plugin_Continue;
	if (!IsPlayerAlive(iClient))
		return Plugin_Continue;
	if (GetClientTeam(iClient) == TEAM_SURVIVORS && IsFallDamage(iClient) && iButtons & IN_USE)
		if (g_iEngineFlags & NO_FALL_DAMAGE_BUG_FIX)
			iButtons &= ~IN_USE;
	if (g_iEngineFlags & LADDER_SPEED_GLITCH_FIX)
	{
		if (GetEntityMoveType(iClient) == MOVETYPE_LADDER)
		{
			if (iButtons & IN_FORWARD || iButtons & IN_BACK)
			{
				if (iButtons & IN_MOVELEFT)
					iButtons &= ~IN_MOVELEFT;
				if (iButtons & IN_MOVERIGHT)
					iButtons &= ~IN_MOVERIGHT;
			}
		}
	}
	return Plugin_Continue;
}

public void OnPlayerRunCmdPost(int iClient, int iButtons)
{
	if (!g_iEngineFlags)
		return;
	if (!IsValidClient(iClient))
		return;
	if (IsFakeClient(iClient))
		return;
	if (!IsPlayerAlive(iClient))
		return;
	if (!(g_iEngineFlags & LADDER_RELOAD_GLITCH_FIX))
		return;
	if (GetEntityMoveType(iClient) != MOVETYPE_LADDER)
		return;
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon == -1)
		return;
	if (!(GetEntProp(iWeapon, Prop_Send, "m_fEffects") & 0x20))
		return;
	if (GetEntPropFloat(iWeapon, Prop_Send, "m_reloadQueuedStartTime") == 0.0)
		return;
	SetEntPropFloat(iWeapon, Prop_Send, "m_reloadQueuedStartTime", 0.0);
}

bool IsFallDamage(int iClient)
{
	return GetEntPropFloat(iClient, Prop_Send, "m_flFallVelocity") > 440;
}

/**
 * DROWN GLITCH
**/
public void OnClientDisconnect(int iClient)
{
	EF_ClearAllVars(iClient);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		EF_ClearAllVars(i);
		if (!IsClientInGame(i))
			continue;
		if (!IsDrownPropNotEqual(i))
			continue;
		ForceEqualDrownProp(i);
	}
}

void Event_PlayerHurt(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	if (!(eEvent.GetInt("type") & DMG_DROWN))
		return;
	int iUserId = eEvent.GetInt("userid");
	int iClient = GetClientOfUserId(iUserId);
	if (IsIncapacitated(iClient))
		return;
	if (eEvent.GetInt("health") != CONSTANT_HEALTH)
	{
		g_iLastKnownHealth[iClient] = eEvent.GetInt("health");
		return;
	}
	int iDamage = eEvent.GetInt("dmg_health");
	if (g_iLastKnownHealth[iClient] && iDamage >= g_iLastKnownHealth[iClient])
	{
		iDamage -= g_iLastKnownHealth[iClient];
		g_iLastKnownHealth[iClient] -= CONSTANT_HEALTH;
	}
	if (g_iHealthToRestore[iClient] < 0)
		g_iHealthToRestore[iClient] = 0;
	if (!g_iHealthToRestore[iClient])
	{
		EF_KillRestoreTimer(iClient);
		DataPack dp;
		CreateDataTimer(FIRST_RESTORE_TIME, Timer_CheckRestoring, dp, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		dp.WriteCell(iUserId);
		dp.WriteCell(iClient);
	}
	g_iHealthToRestore[iClient] += iDamage;
	DataPack dp;
	CreateDataTimer(0.1, Timer_SetDrownDmg, dp, TIMER_FLAG_NO_MAPCHANGE);
	dp.WriteCell(iUserId);
	dp.WriteCell(GetEntProp(iClient, Prop_Data, "m_idrowndmg") + g_iLastKnownHealth[iClient]);
	g_iLastKnownHealth[iClient] = 0;
}

Action Timer_SetDrownDmg(Handle hTimer, DataPack dp)
{
	dp.Reset();
	int iClient = GetClientOfUserId(dp.ReadCell());
	if (iClient <= 0)
		return Plugin_Stop;
	if (!IsSurvivor(iClient))
		return Plugin_Stop;
	int iDrownDmg = dp.ReadCell();
	SetEntProp(iClient, Prop_Data, "m_idrowndmg", iDrownDmg);
	return Plugin_Stop;
}

Action Timer_CheckRestoring(Handle hTimer, DataPack dp)
{
	dp.Reset();
	int iUserId = dp.ReadCell();
	int iClient = dp.ReadCell();
	if (GetClientOfUserId(iUserId) != iClient)
	{
		g_iHealthToRestore[iClient] = 0;
		return Plugin_Stop;
	}
	if (g_iHealthToRestore[iClient] <= 0 || !IsSurvivor(iClient))
	{
		g_iHealthToRestore[iClient] = 0;
		return Plugin_Stop;
	}
	if (IsUnderWater(iClient))
		return Plugin_Continue;
	float fHealthToRestore = float(GetEntProp(iClient, Prop_Data, "m_idrowndmg") - GetEntProp(iClient, Prop_Data, "m_idrownrestored"));
	if (fHealthToRestore <= 0)
	{
		DataPack dp2;
		g_hRestoreTimer[iClient] = CreateDataTimer(RESTORE_TIME, Timer_RestoreTempHealth, dp2, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		dp2.WriteCell(iUserId);
		dp2.WriteCell(iClient);
		return Plugin_Stop;
	}
	int iRestoreCount = RoundToCeil(fHealthToRestore / MAX_HEALTH_PER_RESTORE);
	float fRestoreTimeEnd = RESTORE_TIME * float(iRestoreCount);
	DataPack dp2;
	CreateDataTimer(fRestoreTimeEnd, Timer_StartRestoreTempHealth, dp2, TIMER_FLAG_NO_MAPCHANGE);
	dp2.WriteCell(iUserId);
	dp2.WriteCell(iClient);
	return Plugin_Stop;
}

Action Timer_StartRestoreTempHealth(Handle hTimer, DataPack dp)
{
	dp.Reset();
	int iUserId = dp.ReadCell();
	int iClient = dp.ReadCell();
	if (GetClientOfUserId(iUserId) != iClient)
		return Plugin_Stop;
	if (g_iHealthToRestore[iClient] <= 0 || !IsSurvivor(iClient))
		return Plugin_Stop;
	DataPack dp2;
	g_hRestoreTimer[iClient] = CreateDataTimer(RESTORE_TIME, Timer_RestoreTempHealth, dp2, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	dp2.WriteCell(iUserId);
	dp2.WriteCell(iClient);
	return Plugin_Stop;
}

Action Timer_RestoreTempHealth(Handle hTimer, DataPack dp)
{
	dp.Reset();
	int iUserId = dp.ReadCell();
	int iClient = dp.ReadCell();
	if (GetClientOfUserId(iUserId) != iClient)
	{
		EF_ClearVars(iClient);
		return Plugin_Stop;
	}
	if (g_iHealthToRestore[iClient] <= 0 || !IsSurvivor(iClient))
	{
		EF_ClearVars(iClient);
		return Plugin_Stop;
	}
	if (!IsUnderWater(iClient) && !IsDrownPropNotEqual(iClient))
	{
		float fTemp = GetTempHealth(iClient);
		int iLimit = MAX_TEMP_HEALTH - (GetClientHealth(iClient) + RoundToFloor(fTemp));
		int iTempToRestore = g_iHealthToRestore[iClient] >= MAX_HEALTH_PER_RESTORE ? MAX_HEALTH_PER_RESTORE : g_iHealthToRestore[iClient];
		if (iTempToRestore > iLimit)
		{
			iTempToRestore = iLimit;
			g_iHealthToRestore[iClient] = 0;
			if (iTempToRestore <= 0)
				return Plugin_Continue;
		}
		SetTempHealth(iClient, fTemp + iTempToRestore);
		g_iHealthToRestore[iClient] -= MAX_HEALTH_PER_RESTORE;
	}
	return Plugin_Continue;
}

void Event_HealSuccess(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt(StrEqual(szName, "player_incapacitated") ? "userid" : "subject"));
	if (!IsDrownPropNotEqual(iClient))
		return;
	EF_ClearVars(iClient);
	ForceEqualDrownProp(iClient);
}

void Event_PillsUsed(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iUserId = eEvent.GetInt("userid");
	int iClient = GetClientOfUserId(iUserId);
	if (!IsDrownPropNotEqual(iClient))
		return;
	EF_KillFixGlitchTimer(iClient);
	DataPack dp;
	g_hFixGlitchTimer[iClient] = CreateDataTimer(0.0, Timer_FixTempHpGlitch, dp, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	dp.WriteCell(iUserId);
	dp.WriteCell(iClient);
}

Action Timer_FixTempHpGlitch(Handle hTimer, DataPack dp)
{
	dp.Reset();
	int iUserId = dp.ReadCell();
	int iClient = dp.ReadCell();
	if (GetClientOfUserId(iUserId) != iClient)
	{
		g_hFixGlitchTimer[iClient] = null;
		return Plugin_Stop;
	}
	if (!IsSurvivor(iClient) || IsIncapacitated(iClient))
	{
		g_hFixGlitchTimer[iClient] = null;
		return Plugin_Stop;
	}
	float fTemp = GetTempHealth(iClient);
	if (fTemp)
	{
		int iHealth = GetClientHealth(iClient);
		if ((iHealth + RoundToFloor(fTemp)) > MAX_TEMP_HEALTH)
			SetTempHealth(iClient, float(MAX_HEALTH - iHealth));
	}
	if (IsDrownPropNotEqual(iClient))
		return Plugin_Continue;
	g_hFixGlitchTimer[iClient] = null;
	return Plugin_Stop;
}

void EF_KillRestoreTimer(int iClient)
{
	if (g_hRestoreTimer[iClient] == null)
		return;
	KillTimer(g_hRestoreTimer[iClient]);
	g_hRestoreTimer[iClient] = null;
}

void EF_ClearAllVars(int iClient)
{
	EF_ClearVars(iClient);
	EF_KillFixGlitchTimer(iClient);
}

void EF_ClearVars(int iClient)
{
	EF_KillRestoreTimer(iClient);
	g_iHealthToRestore[iClient] = 0;
	g_iLastKnownHealth[iClient] = 0;
}

void EF_KillFixGlitchTimer(int iClient)
{
	if (g_hFixGlitchTimer[iClient] == null)
		return;
	KillTimer(g_hFixGlitchTimer[iClient]);
	g_hFixGlitchTimer[iClient] = null;
}

bool IsSurvivor(int iClient)
{
	return IsClientInGame(iClient) && GetClientTeam(iClient) == TEAM_SURVIVORS && IsPlayerAlive(iClient);
}

bool IsUnderWater(int iClient)
{
	return GetEntProp(iClient, Prop_Send, "m_nWaterLevel") == 3;
}

bool IsIncapacitated(int iClient)
{
	return GetEntProp(iClient, Prop_Send, "m_isIncapacitated") != 0;
}

bool IsDrownPropNotEqual(int iClient)
{
	return GetEntProp(iClient, Prop_Data, "m_idrowndmg") != GetEntProp(iClient, Prop_Data, "m_idrownrestored");
}

void ForceEqualDrownProp(int iClient)
{
	SetEntProp(iClient, Prop_Data, "m_idrownrestored", GetEntProp(iClient, Prop_Data, "m_idrowndmg"));
}

void SetTempHealth(int iClient, float iHealth)
{
	SetEntPropFloat(iClient, Prop_Send, "m_healthBufferTime", GetGameTime());
	SetEntPropFloat(iClient, Prop_Send, "m_healthBuffer", iHealth);
}

// Code by SilverShot aka Silvers (Healing Gnome plugin https://forums.alliedmods.net/showthread.php?p=1658852)
float GetTempHealth(int iClient)
{
	float fTempHealth = GetEntPropFloat(iClient, Prop_Send, "m_healthBuffer");
	fTempHealth -= (GetGameTime() - GetEntPropFloat(iClient, Prop_Send, "m_healthBufferTime")) * g_fDecayRate;
	return fTempHealth < 0.0 ? 0.0 : fTempHealth;
}

bool IsValidClient(int iClient)
{
	if (iClient <= 0)
		return false;
	if (iClient > MaxClients)
		return false;
	return IsClientInGame(iClient);
}