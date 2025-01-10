#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

#define Z_JOCKEY 5
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

#define GAMEDATA "l4d2_si_ability"

Handle g_hCLeapOnTouch;
bool   g_bJumpCapBlock[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name        = "L4D2 Jockey Jump-Cap Patch",
	author      = "Visor, A1m`",
	description = "Prevent Jockeys from being able to land caps with non-ability jumps in unfair situations",
	version     = "1.5",
	url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

public void OnPluginStart() 
{
	GameData gmConf = new GameData(GAMEDATA);
	if (!gmConf)
		SetFailState("Gamedata '%s.txt' missing or corrupt.", GAMEDATA);
	int iCleapOnTouch = gmConf.GetOffset("CBaseAbility::OnTouch");
	if (iCleapOnTouch == -1) 
		SetFailState("Failed to get offset 'CBaseAbility::OnTouch'.");
	delete gmConf;
	
	g_hCLeapOnTouch = DHookCreate(iCleapOnTouch, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, CLeap_OnTouch);
	DHookAddParam(g_hCLeapOnTouch, HookParamType_CBaseEntity);
	
	HookEvent("round_start",   Event_RoundReset, EventHookMode_PostNoCopy);
	HookEvent("round_end",     Event_RoundReset, EventHookMode_PostNoCopy);
	HookEvent("player_shoved", Event_PlayerShoved);
}

void Event_RoundReset(Event eEvent, const char[] szName, bool bDontBroadcast) 
{
	for (int i = 0; i <= MaxClients; i++) 
	{
		g_bJumpCapBlock[i] = false;
	}
}

void Event_PlayerShoved(Event eEvent, const char[] szName, bool bDontBroadcast) 
{
	int iShovee = GetClientOfUserId(eEvent.GetInt("userid"));
	int iShover = GetClientOfUserId(eEvent.GetInt("attacker"));
	if (IsSurvivor(iShover) && IsJockey(iShovee)) 
	{
		g_bJumpCapBlock[iShovee] = true;
		CreateTimer(3.0, ResetJumpcapState, iShovee, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action ResetJumpcapState(Handle hTimer, int iJockey) 
{
	g_bJumpCapBlock[iJockey] = false;
	return Plugin_Handled;
}

public void OnEntityCreated(int iEnt, const char[] szClsName) 
{
	if (strcmp(szClsName, "ability_leap") == 0) 
	{
		DHookEntity(g_hCLeapOnTouch, false, iEnt);
	}
}

MRESReturn CLeap_OnTouch(int iAbility, Handle hParams) 
{
	int iJockey = GetEntPropEnt(iAbility, Prop_Send, "m_owner");
	if (IsJockey(iJockey) && !IsFakeClient(iJockey)) 
	{
		int iSurvivor = DHookGetParam(hParams, 1);
		if (!IsSurvivor(iSurvivor))
			return MRES_Ignored;
		if (!IsAbilityActive(iAbility) && g_bJumpCapBlock[iJockey])
			return MRES_Supercede;
	}
	return MRES_Ignored;
}

bool IsAbilityActive(int iAbility) 
{
	return view_as<bool>(GetEntProp(iAbility, Prop_Send, "m_isLeaping", 1));
}

bool IsJockey(int iClient) 
{
	return (iClient > 0
		&& iClient <= MaxClients
		&& IsClientInGame(iClient)
		&& GetClientTeam(iClient) == TEAM_INFECTED
		&& GetEntProp(iClient, Prop_Send, "m_zombieClass") == Z_JOCKEY);
}

bool IsSurvivor(int iClient) 
{
	return (iClient > 0
		&& iClient <= MaxClients
		&& IsClientInGame(iClient)
		&& GetClientTeam(iClient) == TEAM_SURVIVOR);
}