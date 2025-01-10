#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "0.2"
#define IsValidClient(%1) ((1 <= %1 <= MaxClients) && IsClientInGame(%1))

const int Z_COMMON = 0;

bool    g_bLeft4Dead2, g_bLateLoad, g_bMapStarted, g_bAllowByPlugin;

bool    g_bFakeClient[MAXPLAYERS+1][MAXPLAYERS+1];
int     g_iClientPing[MAXPLAYERS+1], g_iClientPlayTime[MAXPLAYERS+1], g_iCurrentPing[MAXPLAYERS+1];

char    g_sStatusServer[64], g_sStatusVersion[64];
int     g_iCurrentMode, g_iMinPing, g_iMaxPing, g_iOffsetPing, g_iMinPlayTime, g_iMaxPlayTime, 
        g_iFakeCoop, g_iFakePing, g_iFakeStatus, g_iFakeHealth, g_iIncapHealth;

ConVar  g_hCvarHostName, g_hCvarLan, g_hCvarMaxPlayers, g_hCvarIncapHealth;

ConVar  g_pCvarMPGameMode, g_pCvarAllow, g_pCvarModes, g_pCvarModesOff, g_pCvarModesTog, g_pCvarMinPing, g_pCvarMaxPing, g_pCvarOffsetPing, 
        g_pCvarServer, g_pCvarFakeHealth, g_pCvarMinPlayTime, g_pCvarMaxPlayTime, g_pCvarVersion, g_pCvarFakeCoop, g_pCvarFakePing, g_pCvarFakeStatus;
	
public Plugin myinfo =
{
	name = "[L4D/2] Stealth Mode",
	author = "zonde306, Dosergen",
	description = "Adds the ability to set fake parameters for survivors",
	version = PLUGIN_VERSION,
	url = "https://github.com/zonde306/l4d2sc/blob/master/l4d2_fake_server.sp"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test == Engine_Left4Dead) g_bLeft4Dead2 = false;
	else if (test == Engine_Left4Dead2) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d_fs_version", PLUGIN_VERSION, "Plugin Version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	g_pCvarAllow = CreateConVar("l4d_fs_allow", "1", "Enable Plugin?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_pCvarModes = CreateConVar("l4d_fs_modes", "", "Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", FCVAR_NOTIFY);
	g_pCvarModesOff = CreateConVar("l4d_fs_modes_off", "", "Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", FCVAR_NOTIFY);
	g_pCvarModesTog = CreateConVar("l4d_fs_modes_tog", "0", "Turn on the plugin in these game modes. 0: All 1: Coop 2: Survival 4: Versus 8: Scavenge. Add numbers together.", FCVAR_NOTIFY, true, 0.0, true, 15.0);

	g_pCvarMinPing = CreateConVar("l4d_fs_min_ping", "35", "Minimum ping value", FCVAR_NOTIFY, true, 0.0, true, 800.0);
	g_pCvarMaxPing = CreateConVar("l4d_fs_max_ping", "65", "Maximum ping value", FCVAR_NOTIFY, true, 0.0, true, 800.0);
	g_pCvarOffsetPing = CreateConVar("l4d_fs_offset_ping", "15", "Ping difference value", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_pCvarServer = CreateConVar("l4d_fs_fake_server", "Linux Listen", "Fake server content in status", FCVAR_NOTIFY);
	g_pCvarMinPlayTime = CreateConVar("l4d_fs_min_playtime", "", "Minimum value of online time in fictitious status", FCVAR_NOTIFY, true, 0.0, true, 65535.0);
	g_pCvarMaxPlayTime = CreateConVar("l4d_fs_max_playtime", "", "Maximum value of online time in fictitious status", FCVAR_NOTIFY, true, 0.0, true, 65535.0);
	g_pCvarVersion = CreateConVar("l4d_fs_fake_version", "", "Version of the game in disguise status", FCVAR_NOTIFY);
	g_pCvarFakeCoop = CreateConVar("l4d_fs_fake_coop", "1", "Cooperative mode. 0: off 1: only for admins 2: for all players", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_pCvarFakePing = CreateConVar("l4d_fs_fake_ping", "1", "Ping mode. 0: off 1: only for admins 2: for all players", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_pCvarFakeStatus = CreateConVar("l4d_fs_fake_status", "1", "Status mode. 0: off 1: only for admins 2: for all players", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_pCvarFakeHealth = CreateConVar("l4d_fs_fake_health", "1", "Health mode. 0: off 1: only for admins 2: for all players", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	
	AutoExecConfig(true, "l4d_fake_server");

	g_hCvarHostName = FindConVar("hostname");
	g_hCvarLan = FindConVar("sv_lan");
	g_hCvarMaxPlayers = FindConVar("sv_visiblemaxplayers");
	g_hCvarIncapHealth = FindConVar("survivor_incap_health");
	
	AddCommandListener(Command_Status, "status");
	RegAdminCmd("sm_status", Command_Status2, ADMFLAG_ROOT);

	g_pCvarMPGameMode = FindConVar("mp_gamemode");
	g_pCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_pCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_pCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_pCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_pCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	
	g_pCvarMinPing.AddChangeHook(ConVarChanged_Cvars);
	g_pCvarMaxPing.AddChangeHook(ConVarChanged_Cvars);
	g_pCvarOffsetPing.AddChangeHook(ConVarChanged_Cvars);
	g_pCvarServer.AddChangeHook(ConVarChanged_Cvars);
	g_pCvarMinPlayTime.AddChangeHook(ConVarChanged_Cvars);
	g_pCvarMaxPlayTime.AddChangeHook(ConVarChanged_Cvars);
	g_pCvarFakeCoop.AddChangeHook(ConVarChanged_Cvars);
	g_pCvarFakePing.AddChangeHook(ConVarChanged_Cvars);
	g_pCvarFakeStatus.AddChangeHook(ConVarChanged_Cvars);
	g_pCvarFakeHealth.AddChangeHook(ConVarChanged_Cvars);
	g_pCvarVersion.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarIncapHealth.AddChangeHook(ConVarChanged_Cvars);
	
	HookUserMessage(GetUserMessageId("TextMsg"), OnUserMsg_TextMsg, true);
	HookUserMessage(GetUserMessageId("HintText"), OnUserMsg_HintText, true);
	
	if (g_bLateLoad && IsServerProcessing())
	{
		int entity = FindEntityByClassname(MaxClients + 1, "terror_player_manager");
		if (entity > MaxClients)
			SDKHook(entity, SDKHook_ThinkPost, EntityHook_ThinkPost);
		entity = FindEntityByClassname(MaxClients + 1, "player_manager");
		if (entity > MaxClients)
			SDKHook(entity, SDKHook_ThinkPost, EntityHook_ThinkPost);
		for(int i = 1; i <= MaxClients; ++i)
			if (IsClientConnected(i))
				OnClientConnected(i);
	}
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Allow(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bAllowByPlugin = g_pCvarAllow.BoolValue;
	g_iMinPing = g_pCvarMinPing.IntValue;
	g_iMaxPing = g_pCvarMaxPing.IntValue;
	g_iOffsetPing = g_pCvarOffsetPing.IntValue;
	g_pCvarServer.GetString(g_sStatusServer, sizeof(g_sStatusServer));
	g_iMinPlayTime = g_pCvarMinPlayTime.IntValue;
	g_iMaxPlayTime = g_pCvarMaxPlayTime.IntValue;
	g_pCvarVersion.GetString(g_sStatusVersion, sizeof(g_sStatusVersion));
	g_iFakeCoop = g_pCvarFakeCoop.IntValue;
	g_iFakePing = g_pCvarFakePing.IntValue;
	g_iFakeStatus = g_pCvarFakeStatus.IntValue;
	g_iFakeHealth = g_pCvarFakeHealth.IntValue;
	g_iIncapHealth = g_hCvarIncapHealth.IntValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_pCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();
	if (g_bAllowByPlugin == false && bCvarAllow == true && bAllowMode == true)
	{
		g_bAllowByPlugin = true;
		HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
		HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
		HookEvent("player_hurt_concise", Event_PlayerHurtConcise, EventHookMode_Pre);
		if (g_bLeft4Dead2)
			HookEvent("zombie_death", Event_ZombieDeath, EventHookMode_Pre);
		HookEvent("player_incapacitated", Event_PlayerIncapacitated, EventHookMode_Pre);
		HookEvent("player_incapacitated_start", Event_PlayerIncapacitatedStart, EventHookMode_Pre);
		HookEvent("revive_success", Event_ReviveSuccess, EventHookMode_Pre);
		HookEvent("revive_begin", Event_ReviveBegin);
		HookEvent("award_earned", Event_AwardEarned, EventHookMode_Pre);
		if (g_bLeft4Dead2)
			HookEvent("defibrillator_used", Event_DefibrillatorUsed, EventHookMode_Pre);
		if (g_bLeft4Dead2)
			HookEvent("defibrillator_begin", Event_DefibrillatorBegin);
		HookEvent("heal_success", Event_HealSuccess, EventHookMode_Pre);
		HookEvent("heal_begin", Event_HealBegin);
		HookEvent("survivor_rescued", Event_SurvivorRescued, EventHookMode_Pre);
	}
	else if (g_bAllowByPlugin == true && (bCvarAllow == false || bAllowMode == false))
	{
		g_bAllowByPlugin = false;
		UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
		UnhookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
		UnhookEvent("player_hurt_concise", Event_PlayerHurtConcise, EventHookMode_Pre);
		if (g_bLeft4Dead2)
			UnhookEvent("zombie_death", Event_ZombieDeath, EventHookMode_Pre);
		UnhookEvent("player_incapacitated", Event_PlayerIncapacitated, EventHookMode_Pre);
		UnhookEvent("player_incapacitated_start", Event_PlayerIncapacitatedStart, EventHookMode_Pre);
		UnhookEvent("revive_success", Event_ReviveSuccess, EventHookMode_Pre);
		UnhookEvent("revive_begin", Event_ReviveBegin);
		UnhookEvent("award_earned", Event_AwardEarned, EventHookMode_Pre);
		if (g_bLeft4Dead2)
			UnhookEvent("defibrillator_used", Event_DefibrillatorUsed, EventHookMode_Pre);
		if (g_bLeft4Dead2)
			UnhookEvent("defibrillator_begin", Event_DefibrillatorBegin);
		UnhookEvent("heal_success", Event_HealSuccess, EventHookMode_Pre);
		UnhookEvent("heal_begin", Event_HealBegin);
		UnhookEvent("survivor_rescued", Event_SurvivorRescued, EventHookMode_Pre);
	}
}

bool IsAllowedGameMode()
{
	if (g_pCvarMPGameMode == null)
		return false;
	int iCvarModesTog = g_pCvarModesTog.IntValue;
	if (iCvarModesTog != 0)
	{
		if (g_bMapStarted == false)
			return false;
		g_iCurrentMode = 0;
		int entity = CreateEntityByName("info_gamemode");
		if (IsValidEntity(entity))
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if (IsValidEntity(entity))
				RemoveEntity(entity);
		}
		if (g_iCurrentMode == 0)
			return false;
		if (!(iCvarModesTog & g_iCurrentMode))
			return false;
	}
	char sGameModes[64], sGameMode[64];
	g_pCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);
	g_pCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if (sGameModes[0])
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if (StrContains(sGameModes, sGameMode, false) == -1)
			return false;
	}
	g_pCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if (sGameModes[0])
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if (StrContains(sGameModes, sGameMode, false) != -1)
			return false;
	}

	return true;
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if (strcmp(output, "OnCoop") == 0)
		g_iCurrentMode = 1;
	else if (strcmp(output, "OnSurvival") == 0)
		g_iCurrentMode = 2;
	else if (strcmp(output, "OnVersus") == 0)
		g_iCurrentMode = 4;
	else if (strcmp(output, "OnScavenge") == 0)
		g_iCurrentMode = 8;
}

public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

public void OnClientConnected(int client)
{
	if (!g_bAllowByPlugin)
		return;
	SetRandomSeed(GetSysTickCount() - client);
	g_iClientPing[client] = GetRandomInt(g_iMinPing, g_iMaxPing);
	g_iClientPlayTime[client] = GetRandomInt(g_iMinPlayTime, g_iMaxPlayTime);
	g_iCurrentPing[client] = 0;
	for (int i = 1; i <= MaxClients; ++i)
		g_bFakeClient[client][i] = (i != client && IsClientInGame(i));
}

Action Command_Status2(int client, int argc)
{
	if (!g_bAllowByPlugin)
		return Plugin_Continue;
	if (client <= 0 || client >= MaxClients || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;
	PrintStatusInfo(client);
	return Plugin_Continue;
}

Action Command_Status(int client, const char[] command, int argc)
{
	if (!g_bAllowByPlugin)
		return Plugin_Continue;
	if (client <= 0 || client >= MaxClients || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;
	if (g_iFakeStatus == 0 || (g_iFakeStatus == 1 && IsClientAdmin(client)))
		return Plugin_Continue;
	PrintStatusInfo(client);
	return Plugin_Handled;
}

void PrintStatusInfo(int client)
{
	static char sHostName[64];
	if (IsDedicatedServer())
		g_hCvarHostName.GetString(sHostName, sizeof(sHostName));
	else
		strcopy(sHostName, sizeof(sHostName), "Left 4 Dead 2");
	static char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	float vOrigin[3];
	GetClientAbsOrigin(client, vOrigin);
	/*
		hostname: Left4Dead 2
		version : 2.2.2.6 8777 secure  (unknown)
		udp/ip  : 192.168.1.196:27015 [ public same ]
		os      : Linux Dedicated
		map     : c8m5_rooftop at ( 5294, 8429, 5598 )
		players : 1 humans, 0 bots (4 max) (not hibernating) (unreserved)
	*/
	PrintToConsole(client, "hostname: %s", sHostName);
	PrintToConsole(client, "version : %s secure  (unknown)", g_sStatusVersion);
	PrintToConsole(client, "udp/ip  : 127.0.0.1:27015 [ public n/a ] ");
	PrintToConsole(client, "os      : %s", g_sStatusServer);
	PrintToConsole(client, "map     : %s at ( %.0f, %.0f, %.0f )", sMap, vOrigin[0], vOrigin[1], vOrigin[2]);
	PrintToConsole(client, "players : %d humans, %d bots (%d max) (not hibernating) (unreserved)", GetClientCount2(false), GetClientCount2(true), GetMaxClients2());
	PrintToConsole(client, " ");	// NEW LINE
	PrintToConsole(client, "# userid name uniqueid connected ping loss state rate adr");
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientConnected(i) || IsClientInvis(i))
			continue;
		int team = GetClientTeam(i);
		bool bot = IsFakeClient(i);
		if (bot && team != 2)
			continue;
		/*
			# userid name uniqueid connected ping loss state rate adr
			#  2 1 "unnamed" STEAM_1:0:0 00:11 34 0 active 30000 loopback
			# 4 "Zoey" BOT active
			# 5 "Bill" BOT active
			# 7 "Louis" BOT active
			# 9 "Francis" BOT active
			#end
		*/
		if (bot)
			PrintToConsole(i, "# %d \"%N\" BOT active", GetClientUserId(i), i);
		else
		{
			static char time[64];
			if (g_bFakeClient[i][client])
				FormatShortTime(g_iClientPlayTime[i] + RoundToZero(GetClientTime(i)), time, sizeof(time));
			else
				FormatShortTime(RoundToZero(GetClientTime(i)), time, sizeof(time));
			static char auth[64];
			GetClientAuthId(i, AuthId_Steam2, auth, sizeof(auth), false);
			int ping = (g_iCurrentPing[i] > 0 ? g_iCurrentPing[i] : RoundToFloor(GetClientAvgLatency(i, NetFlow_Both) * 1000.0));
			int loss = RoundToFloor(GetClientAvgLoss(i, NetFlow_Both) * 100.0);
			static char state[64];
			if (IsClientInGame(i))
				strcopy(state, sizeof(state), "active");
			else
				strcopy(state, sizeof(state), "spawnning");
			static char ip[32];
			GetClientIP(i, ip, sizeof(ip), false);
			if(IsClientAdmin(i))
			{
				FormatEx(auth, sizeof(auth), "STEAM_1:0:%9d", GetRandomInt(100000000, 999999999));
				if (IsDedicatedServer())
					FormatEx(ip, sizeof(ip), "%d.%d.%d.%d:27005", GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255));
				else if (g_hCvarLan.BoolValue)
					FormatEx(ip, sizeof(ip), "%d.%d.%d.%d:27005", GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255));
				else
					FormatEx(ip, sizeof(ip), "0.0.0.%d:27005", GetRandomInt(0, 255));
			}
			PrintToConsole(i, "# %d %d \"%N\" %s %s %d %d %s %d %s",
				GetClientUserId(i),      // userid
				i,                       // idx
				i,                       // name
				auth,                    // uniqueid
				time,                    // connected
				ping,                    // ping
				loss,                    // loss
				state,                   // state
				GetClientDataRate(i),    // rate
				ip                       // adr
			);
		}
	}
	PrintToConsole(client, "#end");
	PrintToServer("client %N query status", client);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "terror_player_manager", false) || StrEqual(classname, "player_manager", false))
		SDKHook(entity, SDKHook_ThinkPost, EntityHook_ThinkPost);
}

public void OnEntityDestroyed(int entity)
{
	SDKUnhook(entity, SDKHook_ThinkPost, EntityHook_ThinkPost);
}

void EntityHook_ThinkPost(int entity)
{
	if (!g_bAllowByPlugin)
		return;
	int maxClients = MaxClients > 32 ? 32 : MaxClients;
	for (int i = 1; i <= maxClients; ++i)
	{
		if (!IsClientInGame(i))
			continue;
		int team = GetClientTeam(i);
		if (team != 2 && team != 3)
			continue;
		// FAKE HEALTH
		if (team == 2 && g_iFakeHealth == 2 || (g_iFakeHealth == 1 && (IsClientAdmin(i) || IsFakeClient(i))))
		{
			int maxHealth = GetEntProp(i, Prop_Data, "m_iMaxHealth");
			int health = GetEntProp(i, Prop_Data, "m_iHealth");
			int rawMaxHealth = 100;
			if (GetEntProp(i, Prop_Send, "m_isIncapacitated") || GetEntProp(i, Prop_Send, "m_isHangingFromLedge"))
				rawMaxHealth = g_iIncapHealth;
			if (maxHealth > rawMaxHealth)
			{
				float scale = maxHealth / 100.0;
				SetEntProp(entity, Prop_Send, "m_maxHealth", RoundToCeil(maxHealth / scale), 2, i);
				SetEntProp(entity, Prop_Send, "m_iHealth", RoundToCeil(health / scale), 2, i);
			}
			else if (health > rawMaxHealth)
			{
				SetEntProp(entity, Prop_Send, "m_iHealth", rawMaxHealth, 2, i);
			}
		}
		
		if (!IsFakeClient(i))
		{
			// FAKE PING
			if(g_iClientPing[i] > 0 && g_iFakePing == 2 || (g_iFakePing == 1 && IsClientAdmin(i)))
			{
				SetRandomSeed(GetSysTickCount() + i);
				g_iCurrentPing[i] = g_iClientPing[i] + GetRandomInt(-g_iOffsetPing, g_iOffsetPing);
				SetEntProp(entity, Prop_Send, "m_iPing", g_iCurrentPing[i], 2, i);
			}
			// HIDDEN
			if(IsClientInvis(i))
			{
				SetEntProp(entity, Prop_Send, "m_bConnected", 0, 1, i);
				SetEntProp(entity, Prop_Send, "m_iTeam", 0, 1, i);
				SetEntProp(entity, Prop_Send, "m_bAlive", 0, 1, i);
				SetEntProp(entity, Prop_Send, "m_isGhost", 0, 1, i);
				SetEntProp(entity, Prop_Send, "m_isIncapacitated", 0, 1, i);
				SetEntProp(entity, Prop_Send, "m_wantsToPlay", 0, 1, i);
				SetEntProp(entity, Prop_Send, "m_zombieClass", Z_COMMON, 1, i);
			}
		}
		if (IsDedicatedServer() && IsClientAdmin(i))
			SetEntProp(entity, Prop_Send, "m_listenServerHost", 1, 1, i);
	}
}

Action Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(victim) && IsClientInvis(victim))
		return Plugin_Handled;
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (IsValidClient(attacker) && IsClientInvis(attacker))
	{
		event.SetInt("attacker", 0);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

Action Event_PlayerHurt(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(victim) && IsClientInvis(victim))
		return Plugin_Handled;
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (IsValidClient(attacker) && IsClientInvis(attacker))
	{
		event.SetInt("attacker", 0);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

Action Event_PlayerHurtConcise(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(victim) && IsClientInvis(victim))
		return Plugin_Handled;
	int attacker = event.GetInt("attackerentid");
	if (IsValidClient(attacker) && IsClientInvis(attacker))
	{
		event.SetInt("attackerentid", 0);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

Action Event_ZombieDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if (IsValidClient(victim) && IsClientInvis(victim))
		return Plugin_Handled;
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (IsValidClient(attacker) && IsClientInvis(attacker))
	{
		event.SetInt("attacker", 0);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

Action Event_PlayerIncapacitated(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if (IsValidClient(victim) && IsClientInvis(victim))
		return Plugin_Handled;
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (IsValidClient(attacker) && IsClientInvis(attacker))
	{
		event.SetInt("attacker", 0);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

Action Event_PlayerIncapacitatedStart(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if (IsValidClient(victim) && IsClientInvis(victim))
		return Plugin_Handled;
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (IsValidClient(attacker) && IsClientInvis(attacker))
	{
		event.SetInt("attacker", 0);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

Action Event_ReviveSuccess(Event event, const char[] eventName, bool dontBroadcast)
{
	int revivee = GetClientOfUserId(event.GetInt("subject"));
	if (IsValidClient(revivee) && IsClientInvis(revivee))
		return Plugin_Handled;
	int reviver = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(reviver) && IsClientInvis(reviver))
		return Plugin_Handled;
	return Plugin_Continue;
}

void Event_ReviveBegin(Event event, const char[] eventName, bool dontBroadcast)
{
	int helpee = GetClientOfUserId(event.GetInt("subject"));
	int helper = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(helpee) || !IsValidClient(helper) || helpee == helper)
		return;
	if (IsClientInvis(helpee))
	{
		SetEntProp(helper, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
		SetEntProp(helper, Prop_Send, "m_flProgressBarDuration", 0.0);
	}
	if (IsClientInvis(helper))
	{
		SetEntProp(helpee, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
		SetEntProp(helpee, Prop_Send, "m_flProgressBarDuration", 0.0);
	}
}

Action Event_AwardEarned(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && IsClientInvis(client))
		return Plugin_Handled;
	int subject = event.GetInt("subjectentid");
	if (IsValidClient(subject) && IsClientInvis(subject))
		return Plugin_Handled;
	return Plugin_Continue;
}

Action Event_DefibrillatorUsed(Event event, const char[] eventName, bool dontBroadcast)
{
	int helper = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(helper) && IsClientInvis(helper))
		return Plugin_Handled;
	int helpee = GetClientOfUserId(event.GetInt("subject"));
	if (IsValidClient(helpee) && IsClientInvis(helpee))
		return Plugin_Handled;
	return Plugin_Continue;
}

void Event_DefibrillatorBegin(Event event, const char[] eventName, bool dontBroadcast)
{
	int helpee = GetClientOfUserId(event.GetInt("subject"));
	int helper = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(helpee) || !IsValidClient(helper) || helpee == helper)
		return;
	if (IsClientInvis(helpee))
	{
		SetEntProp(helper, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
		SetEntProp(helper, Prop_Send, "m_flProgressBarDuration", 0.0);
	}
}

Action Event_HealSuccess(Event event, const char[] eventName, bool dontBroadcast)
{
	int helper = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(helper) && IsClientInvis(helper))
		return Plugin_Handled;
	int helpee = GetClientOfUserId(event.GetInt("subject"));
	if (IsValidClient(helpee) && IsClientInvis(helpee))
		return Plugin_Handled;
	return Plugin_Continue;
}

void Event_HealBegin(Event event, const char[] eventName, bool dontBroadcast)
{
	int helpee = GetClientOfUserId(event.GetInt("subject"));
	int helper = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(helpee) || !IsValidClient(helper) || helpee == helper)
		return;
	if (IsClientInvis(helpee))
	{
		SetEntProp(helper, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
		SetEntProp(helper, Prop_Send, "m_flProgressBarDuration", 0.0);
	}
	if (IsClientInvis(helper))
	{
		SetEntProp(helpee, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
		SetEntProp(helpee, Prop_Send, "m_flProgressBarDuration", 0.0);
	}
}

Action Event_SurvivorRescued(Event event, const char[] eventName, bool dontBroadcast)
{
	int helper = GetClientOfUserId(event.GetInt("rescuer"));
	if (IsValidClient(helper) && IsClientInvis(helper))
		return Plugin_Handled;
	int helpee = GetClientOfUserId(event.GetInt("victim"));
	if (IsValidClient(helpee) && IsClientInvis(helpee))
		return Plugin_Handled;
	return Plugin_Continue;
}

public Action OnUserMsg_TextMsg(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if (!g_bAllowByPlugin)
		return Plugin_Continue;
	static char message[256], name[MAX_NAME_LENGTH];
	msg.ReadString(message, sizeof(message), false);
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientConnected(i) || !IsClientInvis(i))
			continue;
		GetClientName(i, name, sizeof(name));
		if (StrContains(message, name, true) != -1)
			return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action OnUserMsg_HintText(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if (!g_bAllowByPlugin)
		return Plugin_Continue;
	static char message[256], name[MAX_NAME_LENGTH];
	msg.ReadByte();
	msg.ReadString(message, sizeof(message), false);
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientConnected(i) || !IsClientInvis(i))
			continue;
		GetClientName(i, name, sizeof(name));
		if (StrContains(message, name, true) != -1)
			return Plugin_Handled;
	}
	return Plugin_Continue;
}

stock void FormatShortTime(int time, char[] outTime, int size)
{
	int s = time % 60;
	int m = (time % 3600) / 60;
	int h = (time % 86400) / 3600;
	if (h > 0)
		FormatEx(outTime, size, "%02d:%02d:%02d", h, m, s);
	else
		FormatEx(outTime, size, "%02d:%02d", m, s);
}

stock int GetClientCount2(bool bot)
{
	int nClients = 0;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientConnected(i) || IsClientInvis(i))
			continue;
		if (IsFakeClient(i))
		{
			if(bot)
				nClients += 1;
		}
		else
		{
			if(!bot)
				nClients += 1;
		}
	}
	return nClients;
}

stock int GetMaxClients2()
{
	// L4DToolz
	if (g_hCvarMaxPlayers && g_hCvarMaxPlayers.IntValue > 0)
		return g_hCvarMaxPlayers.IntValue;
	int nClients = 4;
	if (g_iCurrentMode == 4 || g_iCurrentMode == 8)
		nClients += 4;
	return nClients;
}

stock bool IsClientInvis(int client)
{
	if (g_iFakeCoop == 0 || (g_iFakeCoop == 1 && !IsClientAdmin(client)))
		return false;
	if (!IsClientInGame(client) || IsFakeClient(client))
		return false;
	if (g_iCurrentMode == 1 || g_iCurrentMode == 2)
		if(GetClientTeam(client) == 3)
			return true;
	return false;
}

stock bool IsClientAdmin(int client)
{
	if (GetUserFlagBits(client) != 0)
		return true;
	return false;
}