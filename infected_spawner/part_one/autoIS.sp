#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.3"

#define DEBUG_GENERAL 0
#define DEBUG_TIMES 0
#define DEBUG_SPAWNS 0
#define DEBUG_WEIGHTS 0
#define DEBUG_EVENTS 0

#define MAX_INFECTED 14
#define NUM_TYPES_INFECTED 4

#define SI_BOOMER 0
#define SI_HUNTER 1
#define SI_SMOKER 2
#define SI_TANK 3

char Spawns[NUM_TYPES_INFECTED][16] = {"boomer","hunter","smoker","tank"};

int SICount, SILimit, SpawnSize, SpawnTimeMode, GameMode, WitchCount, WitchLimit, SpawnWeights[NUM_TYPES_INFECTED];

float SpawnTimeMin, SpawnTimeMax, WitchPeriod, SpawnTimes[MAX_INFECTED+1], IntervalEnds[NUM_TYPES_INFECTED];

bool Enabled, EventsHooked, SafeRoomChecking, FasterResponse, FasterSpawn, SafeSpawn, ChangeByConstantTime, SpawnTimerStarted,
     WitchTimerStarted, WitchWaitTimerStarted, WitchCountFull, VariableWitchPeriod, RoundStarted, RoundEnded, LeftSafeRoom; 

ConVar hEnabled, hDisableInVersus, hFasterResponse, hFasterSpawn, hSafeSpawn, hSILimit, hSILimitMax, hSpawnSize, hSpawnTimeMin,
       hSpawnTimeMax, hSpawnTimeMode, hGameMode, hWitchLimit, hWitchPeriod, hWitchPeriodMode, hSpawnWeights[NUM_TYPES_INFECTED];
 
Handle hSpawnTimer, hWitchTimer, hWitchWaitTimer; 

public Plugin myinfo = 
{
	name = "L4D Auto Infected Spawner",
	author = "Tordecybombo, Dosergen",
	description = "Custom automatic infected spawner",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=105661"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead)
	{
		strcopy(error, err_max, "[AIS] This plugin is for Left 4 Dead only.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegAdminCmd("l4d_ais_reset", ResetSpawns, ADMFLAG_RCON, "Reset by slaying all special infected and restarting the timer");
	RegAdminCmd("l4d_ais_start", StartSpawnTimerManually, ADMFLAG_RCON, "Manually start the spawn timer");
	RegAdminCmd("l4d_ais_time", SetConstantSpawnTime, ADMFLAG_CHEATS, "Set a constant spawn time (seconds) by setting l4d_ais_time_min and l4d_ais_time_max to the same value.");
	RegAdminCmd("l4d_ais_preset", PresetWeights, ADMFLAG_CHEATS, "<default|none|boomer|smoker|hunter|tank> Set spawn weights to given presets");
	
	CreateConVar("l4d_ais_version", PLUGIN_VERSION, "Auto Infected Spawner Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	hEnabled = CreateConVar("l4d_ais_enabled", "1", "[0=OFF|1=ON] Disable/Enable functionality of the plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hDisableInVersus = CreateConVar("l4d_ais_disable_in_versus", "1", "[0=OFF|1=ON] Automatically disable plugin in versus mode", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hFasterResponse = CreateConVar("l4d_ais_fast_response", "0", "[0=OFF|1=ON] Disable/Enable faster special infected response", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hFasterSpawn = CreateConVar("l4d_ais_fast_spawn", "0", "[0=OFF|1=ON] Disable/Enable faster special infected spawn (Enable when SI spawn rate is high)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hSafeSpawn = CreateConVar("l4d_ais_safe_spawn", "0", "[0=OFF|1=ON] Disable/Enable special infected spawning while survivors are in safe room", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hSpawnWeights[SI_BOOMER] = CreateConVar("l4d_ais_boomer_weight", "100", "The weight for a boomer spawning", FCVAR_NOTIFY, true, 0.0);
	hSpawnWeights[SI_HUNTER] = CreateConVar("l4d_ais_hunter_weight", "100", "The weight for a hunter spawning", FCVAR_NOTIFY, true, 0.0);
	hSpawnWeights[SI_SMOKER] = CreateConVar("l4d_ais_smoker_weight", "100", "The weight for a smoker spawning", FCVAR_NOTIFY, true, 0.0);
	hSpawnWeights[SI_TANK] = CreateConVar("l4d_ais_tank_weight", "-1", "[-1 = Director spawns tanks] The weight for a tank spawning", FCVAR_NOTIFY, true, -1.0);
	hWitchLimit = CreateConVar("l4d_ais_witch_limit", "-1", "[-1 = Director spawns witches] The max amount of witches present at once (independant of l4d_ais_limit).", FCVAR_NOTIFY, true, -1.0, true, 100.0);
	hWitchPeriod = CreateConVar("l4d_ais_witch_period", "300.0", "The time (seconds) interval in which exactly one witch will spawn", FCVAR_NOTIFY, true, 1.0);
	hWitchPeriodMode = CreateConVar("l4d_ais_witch_period_mode", "1", "The witch spawn rate consistency [0=CONSTANT|1=VARIABLE]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hSILimit = CreateConVar("l4d_ais_limit", "3", "The max amount of special infected at once", FCVAR_NOTIFY, true, 1.0, true, float(MAX_INFECTED));
	hSpawnSize = CreateConVar("l4d_ais_spawn_size", "1", "The amount of special infected spawned at each spawn interval", FCVAR_NOTIFY, true, 1.0, true, float(MAX_INFECTED));
	hSpawnTimeMode = CreateConVar("l4d_ais_time_mode", "1", "The spawn time mode [0=RANDOMIZED|1=INCREMENTAL|2=DECREMENTAL]", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	//hSpawnTimeFunction = CreateConVar("l4d_ais_time_function", "0", "The spawn time function [0=LINEAR|1=EXPONENTIAL|2=LOGARITHMIC]", FCVAR_NOTIFY, true, 0.0, true 2.0);
	hSpawnTimeMin = CreateConVar("l4d_ais_time_min", "0.0", "The minimum auto spawn time (seconds) for infected", FCVAR_NOTIFY, true, 0.0);
	hSpawnTimeMax = CreateConVar("l4d_ais_time_max", "60.0", "The maximum auto spawn time (seconds) for infected", FCVAR_NOTIFY, true, 1.0);

	hSILimitMax = FindConVar("z_max_player_zombies");
	hGameMode = FindConVar("mp_gamemode");
	
	hEnabled.AddChangeHook(ConVarEnabled);
	hFasterResponse.AddChangeHook(ConVarFasterResponse);
	hFasterSpawn.AddChangeHook(ConVarFasterSpawn);
	hSafeSpawn.AddChangeHook(ConVarSafeSpawn);
	hSILimit.AddChangeHook(ConVarSILimit);
	hSpawnSize.AddChangeHook(ConVarSpawnSize);
	hSpawnTimeMode.AddChangeHook(ConVarSpawnTimeMode);
	hSpawnTimeMin.AddChangeHook(ConVarSpawnTime);
	hSpawnTimeMax.AddChangeHook(ConVarSpawnTime);
	HookSpawnWeights(); //hooks all SI weights
	hGameMode.AddChangeHook(ConVarGameMode);
	hWitchLimit.AddChangeHook(ConVarWitchLimit);
	hWitchPeriod.AddChangeHook(ConVarWitchPeriod);
	hWitchPeriodMode.AddChangeHook(ConVarWitchPeriodMode);

	EnabledCheck(); //sets Enabled, FasterResponse, FasterSpawn, and cvars
	SafeSpawn = hSafeSpawn.BoolValue;
	SILimit = hSILimit.IntValue;
	SpawnSize = hSpawnSize.IntValue;
	SpawnTimeMode = hSpawnTimeMode.IntValue;	
	SetSpawnTimes(); //sets SpawnTimeMin, SpawnTimeMax, and SpawnTimes[]
	SetSpawnWeights(); //sets SpawnWeights[] and IntervalEnds[]
	WitchLimit = hWitchLimit.IntValue;
	WitchPeriod = hWitchPeriod.FloatValue;
	VariableWitchPeriod = hWitchPeriodMode.BoolValue;
	
	ChangeByConstantTime = false;
	RoundStarted = false;
	RoundEnded = false;
	LeftSafeRoom = false;
	
	HookEvents();
	HookEvent("witch_spawn", evtWitchSpawn);
	HookEvent("witch_killed", evtWitchKilled);
	
	AutoExecConfig(true, "l4d_autoIS");
}

public void OnConfigsExecuted()
{
	SetCvars(); //refresh cvar settings in case they change
	GameModeCheck();
	if (GameMode == 2 && hDisableInVersus.BoolValue) //disable in versus
		SetConVarBool(hEnabled, false);
}

void HookEvents()
{
	if (!EventsHooked)
	{
		EventsHooked = true;
		HookEvent("round_start", evtRoundStart, EventHookMode_Post);
		HookEvent("round_end", evtRoundEnd, EventHookMode_Pre);
		HookEvent("map_transition", evtRoundEnd, EventHookMode_Pre); //also stop spawn timers upon map transition
		HookEvent("create_panic_event", evtSurvivalStart);
		HookEvent("player_death", evtInfectedDeath);
		#if DEBUG_EVENTS
		LogMessage("[AIS] Events Hooked");
		#endif
	}
}

void UnhookEvents()
{
	if (EventsHooked)
	{
		EventsHooked = false;
		UnhookEvent("round_start", evtRoundStart, EventHookMode_Post);
		UnhookEvent("round_end", evtRoundEnd, EventHookMode_Pre);
		UnhookEvent("map_transition", evtRoundEnd, EventHookMode_Pre);
		UnhookEvent("create_panic_event", evtSurvivalStart);
		UnhookEvent("player_death", evtInfectedDeath);
		#if DEBUG_EVENTS
		LogMessage("[AIS] Events Unhooked");
		#endif
	}
}

void HookSpawnWeights()
{
	for (int i = 0; i < NUM_TYPES_INFECTED; i++)
		hSpawnWeights[i].AddChangeHook(ConVarSpawnWeights);
}

void ConVarEnabled(ConVar convar, const char[] oldValue, const char[] newValue)
{
	EnabledCheck();
}

void ConVarFasterResponse(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetAIDelayCvars();
}

void ConVarFasterSpawn(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetAISpawnCvars();
}

void ConVarSafeSpawn(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SafeSpawn = hSafeSpawn.BoolValue;
}

void ConVarSILimit(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SILimit = hSILimit.IntValue;
	CalculateSpawnTimes(); //must recalculate spawn time table to compensate for limit change
	if (LeftSafeRoom)
		StartSpawnTimer(); //restart timer after times change
}

void ConVarSpawnSize(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SpawnSize = hSpawnSize.IntValue;
}

void ConVarSpawnTimeMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SpawnTimeMode = hSpawnTimeMode.IntValue;
	CalculateSpawnTimes(); //must recalculate spawn time table to compensate for mode change
	if (LeftSafeRoom)
		StartSpawnTimer(); //restart timer after times change
}

void ConVarSpawnTime(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!ChangeByConstantTime)
		SetSpawnTimes();
}

void ConVarSpawnWeights(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetSpawnWeights();
	if (WitchLimit < 0 && SpawnWeights[SI_TANK] >= 0)
	{
		SetConVarInt(FindConVar("director_no_bosses"), 1);
		SetConVarInt(hWitchLimit, 0);
	}
	else if (WitchLimit >= 0 && SpawnWeights[SI_TANK] < 0)
	{
		SetConVarInt(FindConVar("director_no_bosses"), 0);
		SetConVarInt(hWitchLimit, -1);
	}
}

void ConVarWitchLimit(ConVar convar, const char[] oldValue, const char[] newValue)
{
	WitchLimit = hWitchLimit.IntValue;
	if (WitchLimit < 0 && SpawnWeights[SI_TANK] >= 0)
	{
		SetConVarInt(FindConVar("director_no_bosses"), 0);
		SetConVarInt(hSpawnWeights[SI_TANK], -1);
	}
	else if (WitchLimit >= 0 && SpawnWeights[SI_TANK] < 0)
	{
		SetConVarInt(FindConVar("director_no_bosses"), 1);
		SetConVarInt(hSpawnWeights[SI_TANK], 0);
	}
	if (LeftSafeRoom && WitchLimit > 0)
		RestartWitchTimer(0.0); //restart timer after times change
}

void ConVarWitchPeriod(ConVar convar, const char[] oldValue, const char[] newValue)
{
	WitchPeriod = hWitchPeriod.FloatValue;
	if (LeftSafeRoom && WitchLimit > 0)
		RestartWitchTimer(0.0); //restart timer after times change
}

void ConVarWitchPeriodMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	VariableWitchPeriod = hWitchPeriodMode.BoolValue;
	if (LeftSafeRoom && WitchLimit > 0)
		RestartWitchTimer(0.0); //restart timer after times change
}

void ConVarGameMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GameModeCheck();
}

void EnabledCheck()
{
	Enabled = hEnabled.BoolValue;
	SetCvars();
	if (Enabled)
	{
		HookEvents();
		InitTimers();
	}
	else
		UnhookEvents();
	#if DEBUG_GENERAL
	LogMessage("[AIS] Plugin Enabled?: %b", Enabled);
	#endif
}

void InitTimers()
{
	if (LeftSafeRoom)
		StartTimers();
	else if (GameMode != 3 && !SafeRoomChecking) //start safe room check in non-survival mode
	{
		SafeRoomChecking = true;
		CreateTimer(1.0, PlayerLeftStart);
	}
}

void SetCvars()
{
	if (Enabled)
	{
		SetConVarBounds(hSILimitMax, ConVarBound_Upper, true, float(MAX_INFECTED));
		SetConVarFloat(hSILimitMax, float(MAX_INFECTED));
		SetConVarInt(FindConVar("z_exploding_limit"), 0);
		SetConVarInt(FindConVar("z_gas_limit"), 0);
		SetConVarInt(FindConVar("z_hunter_limit"), 0);
		SetConVarInt(FindConVar("z_versus_boomer_limit"), 0);
		SetConVarInt(FindConVar("z_versus_smoker_limit"), 0);
		SetConVarInt(FindConVar("holdout_max_boomers"), 0);
		SetConVarInt(FindConVar("holdout_max_hunters"), 0);
		SetConVarInt(FindConVar("holdout_max_smokers"), 0);
		SetConVarInt(FindConVar("holdout_max_specials"), SILimit);
		SetBossesCvar();
		SetConVarInt(FindConVar("director_spectate_specials"), 1);
	}
	else
	{
		ResetConVar(FindConVar("z_max_player_zombies"));
		ResetConVar(FindConVar("z_exploding_limit"));
		ResetConVar(FindConVar("z_gas_limit"));
		ResetConVar(FindConVar("z_hunter_limit"));
		ResetConVar(FindConVar("z_versus_boomer_limit"));
		ResetConVar(FindConVar("z_versus_smoker_limit"));
		ResetConVar(FindConVar("holdout_max_boomers"));
		ResetConVar(FindConVar("holdout_max_smokers"));
		ResetConVar(FindConVar("holdout_max_hunters"));
		ResetConVar(FindConVar("holdout_max_specials"));
		ResetConVar(FindConVar("director_no_bosses"));	
		ResetConVar(FindConVar("director_spectate_specials"));
	}
	SetAIDelayCvars();
	SetAISpawnCvars();
}

void SetBossesCvar() //both tank and witch must be handled by director or not
{
	if (WitchLimit < 0 || SpawnWeights[SI_TANK] < 0)
		SetConVarInt(FindConVar("director_no_bosses"), 0);
	else
		SetConVarInt(FindConVar("director_no_bosses"), 1);
}

void SetAIDelayCvars()
{
	FasterResponse = hFasterResponse.BoolValue;
	if (FasterResponse)
	{
		SetConVarInt(FindConVar("boomer_exposed_time_tolerance"), 0);	
		SetConVarInt(FindConVar("boomer_vomit_delay"), 0);
		SetConVarInt(FindConVar("smoker_tongue_delay"), 0);
		SetConVarInt(FindConVar("hunter_leap_away_give_up_range"), 0);
	}
	else
	{
		ResetConVar(FindConVar("boomer_exposed_time_tolerance"));
		ResetConVar(FindConVar("boomer_vomit_delay"));
		ResetConVar(FindConVar("smoker_tongue_delay"));
		ResetConVar(FindConVar("hunter_leap_away_give_up_range"));
	}
}

void SetAISpawnCvars()
{
	FasterSpawn = hFasterSpawn.BoolValue;
	if (FasterSpawn)
		SetConVarInt(FindConVar("z_spawn_safety_range"), 0);
	else
		ResetConVar(FindConVar("z_spawn_safety_range"));
}

//MI 5
void GameModeCheck()
{
	//We determine what the gamemode is
	char GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	if (StrContains(GameName, "survival", false) != -1)
		GameMode = 3;
	else if (StrContains(GameName, "versus", false) != -1)
		GameMode = 2;
	else if (StrContains(GameName, "coop", false) != -1)
		GameMode = 1;
	else
		GameMode = 0;
}

Action SetConstantSpawnTime(int client, int args)
{
	ChangeByConstantTime = true; //prevent conflict with hooked event change
	if (args > 0)
	{
		float time = 1.0;
		char arg[8];
		GetCmdArg(1, arg, sizeof(arg));
		time = StringToFloat(arg);
		if (time < 0.0)
			time = 1.0;
		SetConVarFloat(hSpawnTimeMin, time);
		SetConVarFloat(hSpawnTimeMax, time);
		SetSpawnTimes(); //refresh times since hooked event from SetConVarFloat is temporarily disabled
		ReplyToCommand(client, "[AIS] Minimum and maximum spawn time set to %.3f seconds.", time);
	}
	else
		ReplyToCommand(client, "l4d_ais_time <# of seconds>");
	ChangeByConstantTime = false;
	return Plugin_Handled;
}

void SetSpawnTimes()
{
	SpawnTimeMin = hSpawnTimeMin.FloatValue;
	SpawnTimeMax = hSpawnTimeMax.FloatValue;
	if (SpawnTimeMin > SpawnTimeMax) //SpawnTimeMin cannot be greater than SpawnTimeMax
		SetConVarFloat(hSpawnTimeMin, SpawnTimeMax); //set back to appropriate limit
	else if (SpawnTimeMax < SpawnTimeMin) //SpawnTimeMax cannot be less than SpawnTimeMin
		SetConVarFloat(hSpawnTimeMax, SpawnTimeMin); //set back to appropriate limit
	else
	{
		CalculateSpawnTimes(); //must recalculate spawn time table to compensate for min change
		if (LeftSafeRoom)
			StartSpawnTimer(); //restart timer after times change
	}
}

void CalculateSpawnTimes()
{
	int i;
	if (SILimit > 1 && SpawnTimeMode > 0)
	{
		float unit = (SpawnTimeMax-SpawnTimeMin)/(SILimit-1);
		switch (SpawnTimeMode)
		{
			case 1: //incremental spawn time mode
			{
				SpawnTimes[0] = SpawnTimeMin;
				for (i = 1; i <= MAX_INFECTED; i++)
				{
					if (i < SILimit)
						SpawnTimes[i] = SpawnTimes[i-1] + unit;
					else
						SpawnTimes[i] = SpawnTimeMax;
				}
			}
			case 2: //decremental spawn time mode
			{
				SpawnTimes[0] = SpawnTimeMax;
				for (i = 1; i <= MAX_INFECTED; i++)
				{
					if (i < SILimit)
						SpawnTimes[i] = SpawnTimes[i-1] - unit;
					else
						SpawnTimes[i] = SpawnTimeMax;
				}
			}
			//randomized spawn time mode does not use time tables
		}
	}
	else //constant spawn time for if SILimit is 1
		SpawnTimes[0] = SpawnTimeMax;
	#if DEBUG_TIMES
	for (i = 0; i <= MAX_INFECTED; i++)
		LogMessage("[AIS] %d : %.5f s", i, SpawnTimes[i]);
	#endif
}

void SetSpawnWeights()
{
	int i, weight, TotalWeight, CurrentWeight;
	//set and sum spawn weights
	for (i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		weight = hSpawnWeights[i].IntValue;
		SpawnWeights[i] = weight;
		if (weight >= 0)
			TotalWeight += weight;
	}
	//calculate end intervals
	float unit = 1.0/TotalWeight;
	for (i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		weight = SpawnWeights[i];
		if (weight >= 0)
		{
			CurrentWeight += weight;
			IntervalEnds[i] = CurrentWeight * unit;
		}
	}
	#if DEBUG_WEIGHTS
	for (i = 0; i < NUM_TYPES_INFECTED; i++)
		LogMessage("[AIS] %s weight: %d (%.5f)", Spawns[i], SpawnWeights[i], IntervalEnds[i]);
	#endif
}

Action PresetWeights(int client, int args)
{
	char arg[16];
	GetCmdArg(1, arg, sizeof(arg));
	if (strcmp(arg, "default") == 0)
		ResetWeights();
	else if (strcmp(arg, "none") == 0)
		ZeroWeights();
	else //presets for spawning special infected i only
	{
		for (int i = 0; i < NUM_TYPES_INFECTED; i++)
		{
			if (strcmp(arg, Spawns[i]) == 0)
			{
				ZeroWeightsExcept(i);
				return Plugin_Handled;
			}
		}	
	}
	ReplyToCommand(client, "l4d_ais_preset <default|none|boomer|smoker|hunter|tank>");
	return Plugin_Handled;
}

void ResetWeights()
{
	for (int i = 0; i < NUM_TYPES_INFECTED; i++)
		ResetConVar(hSpawnWeights[i]);
}

void ZeroWeights()
{
	for (int i = 0; i < NUM_TYPES_INFECTED; i++)
		SetConVarInt(hSpawnWeights[i], 0);
}

void ZeroWeightsExcept(int index)
{
	for (int i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		if (i == index)
			SetConVarInt(hSpawnWeights[i], 100);
		else
			SetConVarInt(hSpawnWeights[i], 0);
	}
	if (index != SI_TANK) //include director spawning of tank for non-tank SI presets
		ResetConVar(hSpawnWeights[SI_TANK]);
}

void GenerateSpawn(int client)
{
	int index = GenerateIndex();
	if (index >= 0) //negative indices means array out of bounds, or no selection in this case
		ExecuteCheatCommand(client, "z_spawn", Spawns[index], "auto");
	#if DEBUG_SPAWNS
	LogMessage("[AIS] Spawned %s", Spawns[index]);
	#endif
}

int GenerateIndex()
{
	float r = GetRandomFloat(0.0, 1.0); //selector r must be within the ith interval for i to be selected
	for (int i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		//negative and 0 weights are ignored
		if (SpawnWeights[i] <= 0)
			continue;
		//r is not within the ith interval
		if (IntervalEnds[i] < r)
			continue;
		//selected index i because r is within ith interval
		return i;
	}
	return -1; //no selection because all weights were negative or 0
}

void StartSpawnTimer()
{
	EndSpawnTimer();
	if (Enabled)
	{
		float time;
		CountSpecialInfected();
		if (SpawnTimeMode > 0) //NOT randomization spawn time mode
			time = SpawnTimes[SICount]; //a spawn time based on the current amount of special infected
		else //randomization spawn time mode
			time = GetRandomFloat(SpawnTimeMin, SpawnTimeMax); //a random spawn time between min and max inclusive
		SpawnTimerStarted = true;
		hSpawnTimer = CreateTimer(time, SpawnInfectedAuto);
		#if DEBUG_TIMES
		LogMessage("[AIS] Mode: %d | SI: %d | Next: %.3f s", SpawnTimeMode, SICount, time);
		#endif
	}
}

void StartCustomSpawnTimer(float time)
{
	EndSpawnTimer();
	if (Enabled)
	{
		SpawnTimerStarted = true;
		hSpawnTimer = CreateTimer(time, SpawnInfectedAuto);
	}
}

void EndSpawnTimer()
{
	if (SpawnTimerStarted)
	{
		if (hSpawnTimer != null)
		{
			delete hSpawnTimer;
			hSpawnTimer = null;
		}
		SpawnTimerStarted = false;
	}
}

void StartWitchWaitTimer(float time)
{
	EndWitchWaitTimer();
	if (Enabled && WitchLimit > 0)
	{
		if (WitchCount < WitchLimit)
		{
			WitchWaitTimerStarted = true;
			hWitchWaitTimer = CreateTimer(time, StartWitchTimer);
			#if DEBUG_TIMES
			LogMessage("[AIS] Mode: %b | Witches: %d | Next(WitchWait): %.3f s", VariableWitchPeriod, WitchCount, time);
			#endif
		}
		else //if witch count reached limit, wait until a witch killed event to start witch timer
		{
			WitchCountFull = true;
			#if DEBUG_TIMES
			LogMessage("[AIS] Witch Limit reached. Waiting for witch death.");
			#endif
		}
	}
}

Action StartWitchTimer(Handle timer)
{
	WitchWaitTimerStarted = false;
	EndWitchTimer();
	if (Enabled && WitchLimit > 0)
	{
		float time;
		if (VariableWitchPeriod)
			time = GetRandomFloat(0.0, WitchPeriod);
		else
			time = WitchPeriod;
		WitchTimerStarted = true;
		hWitchTimer = CreateTimer(time, SpawnWitchAuto, WitchPeriod-time);
		#if DEBUG_TIMES
		LogMessage("[AIS] Mode: %b | Witches: %d | Next(Witch): %.3f s", VariableWitchPeriod, WitchCount, time);
		#endif
	}
	return Plugin_Stop;
}

void EndWitchWaitTimer()
{
	if (WitchWaitTimerStarted)
	{
		if (hWitchWaitTimer != null)
		{
			delete hWitchWaitTimer;
			hWitchWaitTimer = null;
		}
		WitchWaitTimerStarted = false;
	}
}

void EndWitchTimer()
{
	if (WitchTimerStarted)
	{
		if (hWitchTimer != null)
		{
			delete hWitchTimer;
			hWitchTimer = null;
		}
		WitchTimerStarted = false;
	}
}

void RestartWitchTimer(float time)
{
	EndWitchTimer();
	StartWitchWaitTimer(time);
}

void StartTimers()
{
	StartSpawnTimer();
	RestartWitchTimer(0.0);
}

void EndTimers()
{
	EndSpawnTimer();
	EndWitchWaitTimer();
	EndWitchTimer();
}

Action StartSpawnTimerManually(int client, int args)
{
	if (Enabled)
	{
		if (args < 1)
		{
			StartSpawnTimer();
			ReplyToCommand(client, "[AIS] Spawn timer started manually.");
		}
		else
		{
			float time = 1.0;
			char arg[8];
			GetCmdArg(1, arg, sizeof(arg));
			time = StringToFloat(arg);
			if (time < 0.0)
				time = 1.0;
			StartCustomSpawnTimer(time);
			ReplyToCommand(client, "[AIS] Spawn timer started manually. Next potential spawn in %.3f seconds.", time);
		}
	}
	else
		ReplyToCommand(client, "[AIS] Plugin is disabled. Enable plugin before manually starting timer.");
	return Plugin_Handled;
}
 
Action SpawnInfectedAuto(Handle timer)
{
	SpawnTimerStarted = false; //spawn timer always stops here (the non-repeated spawn timer calls this function)
	if (LeftSafeRoom) //only spawn infected and repeat spawn timer when survivors have left safe room
	{
		int client = GetAnyClient();
		if (client) //make sure client is in-game
		{
			CountSpecialInfected(); //refresh infected count
			int maxSize = SILimit - SICount;
			if (SICount < SILimit) //spawn when infected count hasn't reached limit
			{
				int size;
				if (SpawnSize > maxSize) //prevent amount of special infected from exceeding SILimit
					size = maxSize;
				else
					size = SpawnSize;
				for (int i = 0; i < size; i++)
					GenerateSpawn(client);
			}
			StartSpawnTimer();
		}
		else //longer timer for when invalid client was returned (prevent a potential infinite loop when there are 0 SI)
			StartCustomSpawnTimer(SpawnTimeMax);
	}
	return Plugin_Stop;
}

Action SpawnWitchAuto(Handle timer, any waitTime)
{
	WitchTimerStarted = false;
	if (LeftSafeRoom)
	{
		int client = GetAnyClient();
		if (client)
		{
			if (WitchCount < WitchLimit)
				ExecuteCheatCommand(client, "z_spawn", "witch", "auto");
			StartWitchWaitTimer(waitTime);
		}
		else
			StartWitchWaitTimer(waitTime + 1.0);
	}
	return Plugin_Stop;
}

void ExecuteCheatCommand(int client, const char[] command, char[] param1, char[] param2) 
{
	//Hold original user flag for restoration, temporarily give user root admin flag (prevent conflict with admincheats)
	int admindata = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	//Removes sv_cheat flag from command
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s %s", command, param1, param2);
	//Restore command flag and user flag
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, admindata);
}

Action ResetSpawns(int client, int args)
{	
	KillSpecialInfected();
	if (Enabled)
	{
		StartCustomSpawnTimer(SpawnTimes[0]);
		RestartWitchTimer(0.0);
		ReplyToCommand(client, "[AIS] Slayed all special infected. Spawn timer restarted. Next potential spawn in %.3f seconds.", SpawnTimeMin);
	}
	else
		ReplyToCommand(client, "[AIS] Slayed all special infected.");
	return Plugin_Handled;
}

void CountSpecialInfected()
{
	//reset counter
	SICount = 0;
	//First we count the amount of infected players
	for (int i = 1; i <= MaxClients; i++)
	{
		//We check if player is in game
		if (!IsClientInGame(i))
			continue;
		//Check if client is infected ...
		if (GetClientTeam(i) == 3)
			SICount++;
	}
}

void KillSpecialInfected()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		if (GetClientTeam(i) == 3)
			ForcePlayerSuicide(i);
	}
	//reset counter after all special infected have been killed
	SICount = 0;
}

int GetAnyClient()
{
	int i;
	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			return i;
	}
	return 0;
}

void evtRoundStart(Event event, const char[] name, bool dontBroadcast)
{	
	//If round haven't started
	if (!RoundStarted)
	{
		//and we reset some variables
		RoundEnded = false;
		RoundStarted = true;
		LeftSafeRoom = SafeSpawn; //depends on whether special infected should spawn while survivors are in starting safe room
		WitchCount = 0;
		SpawnTimerStarted = false;
		WitchTimerStarted = false;
		WitchWaitTimerStarted = false;
		WitchCountFull = false;
		InitTimers();
	}
}

void evtRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!RoundEnded)
	{
		//we mark the round as ended
		EndTimers();
		RoundEnded = true;
		RoundStarted = false;
		LeftSafeRoom = false;
	}
}

Action PlayerLeftStart(Handle Timer)
{
	if (LeftStartArea())
	{
		// We don't care who left, just that at least one did
		if (!LeftSafeRoom)
		{
			LeftSafeRoom = true;
			StartTimers();
		}
		SafeRoomChecking = false;
	}
	else
		CreateTimer(1.0, PlayerLeftStart);
	return Plugin_Continue;
}

static int g_iEntTerrorPlayerManager = INVALID_ENT_REFERENCE;

bool LeftStartArea()
{
	int entity = EntRefToEntIndex(g_iEntTerrorPlayerManager);
	if (entity == INVALID_ENT_REFERENCE)
	{
		entity = FindEntityByClassname(-1, "terror_player_manager");
		if (entity == INVALID_ENT_REFERENCE)
		{
			g_iEntTerrorPlayerManager = INVALID_ENT_REFERENCE;
			return false;
		}
		g_iEntTerrorPlayerManager = EntIndexToEntRef(entity);
	}
	return GetEntProp(entity, Prop_Send, "m_hasAnySurvivorLeftSafeArea") == 1;
}

Action evtSurvivalStart(Event event, const char[] name, bool dontBroadcast)
{
	if (GameMode == 3)
	{
		if (!LeftSafeRoom)
		{
			LeftSafeRoom = true;
			StartTimers();
		}
	}
	return Plugin_Continue;
}

void evtInfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (FasterSpawn)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (client)
		{
			if (GetClientTeam(client) == 3 && IsFakeClient(client))
				KickClient(client, "");
		}
	}
}

void evtWitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	WitchCount++;
}

void evtWitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	WitchCount--;
	if (WitchCountFull)
	{
		WitchCountFull = false;
		StartWitchWaitTimer(0.0);
	}
}

public void OnMapEnd()
{
	EndTimers();
	RoundStarted = false;
	RoundEnded = true;
	LeftSafeRoom = false;
}