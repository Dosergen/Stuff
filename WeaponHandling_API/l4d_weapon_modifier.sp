#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <WeaponHandling>

bool g_bLateLoad;

// ConVars for modifying fire rate
ConVar g_CvarRateOfFireHuntingRifle;
ConVar g_CvarRateOfFireSniperAwp;
ConVar g_CvarRateOfFireSniperMilitary;
ConVar g_CvarRateOfFireRifle;
ConVar g_CvarRateOfFireRifleSg552;

// ConVars for modifying reload speed
ConVar g_CvarReloadSniperMilitary;
ConVar g_CvarReloadSniperAwp;
ConVar g_CvarReloadRifleSg552;
ConVar g_CvarReloadRifleDesert;
ConVar g_CvarReloadSMGMp5;
ConVar g_CvarReloadGrenadeLauncher;

// ConVars for damage boost functionality
ConVar g_CvarDamageBoostEnable;
ConVar g_CvarDamageBoostSniperAwp;
ConVar g_CvarDamageBoostSniperScout;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "This plugin is for Left 4 Dead 2 only.");
		return APLRes_SilentFailure;
	}
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	// Initialize fire rate ConVars
	g_CvarRateOfFireHuntingRifle = CreateConVar("l4d2_fire_rate_hunting_rifle", "0.5", "Fire rate modifier for Hunting Rifle");
	g_CvarRateOfFireSniperAwp = CreateConVar("l4d2_fire_rate_sniper_awp", "1.1", "Fire rate modifier for Sniper AWP");
	g_CvarRateOfFireSniperMilitary = CreateConVar("l4d2_fire_rate_sniper_military", "0.7", "Fire rate modifier for Sniper Military");
	g_CvarRateOfFireRifle = CreateConVar("l4d2_fire_rate_rifle", "0.9", "Fire rate modifier for Rifle");
	g_CvarRateOfFireRifleSg552 = CreateConVar("l4d2_fire_rate_rifle_sg552", "0.9", "Fire rate modifier for Rifle SG552");

	// Initialize reload speed ConVars
	g_CvarReloadSniperMilitary = CreateConVar("l4d2_reload_sniper_military", "0.9", "Reload speed modifier for Sniper Military");
	g_CvarReloadSniperAwp = CreateConVar("l4d2_reload_sniper_awp", "0.8", "Reload speed modifier for Sniper AWP");
	g_CvarReloadRifleSg552 = CreateConVar("l4d2_reload_rifle_sg552", "1.2", "Reload speed modifier for Rifle SG552");
	g_CvarReloadRifleDesert = CreateConVar("l4d2_reload_rifle_desert", "1.1", "Reload speed modifier for Rifle Desert");
	g_CvarReloadSMGMp5 = CreateConVar("l4d2_reload_smg_mp5", "1.2", "Reload speed modifier for SMG MP5");
	g_CvarReloadGrenadeLauncher = CreateConVar("l4d2_reload_grenade_launcher", "1.2", "Reload speed modifier for Grenade Launcher");

	// Initialize damage boost ConVars
	g_CvarDamageBoostEnable = CreateConVar("l4d2_damage_boost_enable", "1", "Enable Gun Damage Booster?");
	g_CvarDamageBoostSniperAwp = CreateConVar("l4d2_damage_boost_hunting_awp", "300.0", "Damage Boost for Sniper AWP");
	g_CvarDamageBoostSniperScout = CreateConVar("l4d2_damage_boost_hunting_scout", "150.0", "Damage Boost for Sniper SCOUT");

	if (g_bLateLoad)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
				OnClientPutInServer(i);
		}
	}

	AutoExecConfig(true, "l4d_weapon_modifier");
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity > 0 && IsValidEntity(entity) && (StrEqual(classname, "infected", false) || StrEqual(classname, "witch", false)))
		SDKHook(entity, SDKHook_SpawnPost, OnInfectedSpawnPost);
}

void OnInfectedSpawnPost(int entity)
{
	SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	// Check if damage boosting is enabled
	if (!g_CvarDamageBoostEnable)
		return Plugin_Continue;
	// Apply damage boost if the attacker is a survivor
	if (IsSurvivor(attacker) && damage > 0.0)
	{
		char sWeapon[128];
		GetClientWeapon(attacker, sWeapon, sizeof sWeapon);
		if (StrEqual(sWeapon, "weapon_sniper_awp", false))
			damage += g_CvarDamageBoostSniperAwp.FloatValue;
		else if (StrEqual(sWeapon, "weapon_sniper_scout", false))
			damage += g_CvarDamageBoostSniperScout.FloatValue;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

// Modify the fire rate for specific weapons
public void WH_OnGetRateOfFire(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	switch (weapontype)
	{
		case L4D2WeaponType_HuntingRifle: 
			speedmodifier *= g_CvarRateOfFireHuntingRifle.FloatValue; // Apply Hunting Rifle fire rate modifier
		case L4D2WeaponType_SniperAwp: 
			speedmodifier *= g_CvarRateOfFireSniperAwp.FloatValue; // Apply Sniper AWP fire rate modifier
		case L4D2WeaponType_SniperMilitary: 
			speedmodifier *= g_CvarRateOfFireSniperMilitary.FloatValue; // Apply Sniper Military fire rate modifier
		case L4D2WeaponType_Rifle: 
			speedmodifier *= g_CvarRateOfFireRifle.FloatValue; // Apply Rifle fire rate modifier
		case L4D2WeaponType_RifleSg552: 
			speedmodifier *= g_CvarRateOfFireRifleSg552.FloatValue; // Apply Rifle SG552 fire rate modifier
	}
}

// Modify the reload speed for specific weapons
public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	switch (weapontype)
	{
		case L4D2WeaponType_SniperMilitary: 
			speedmodifier *= g_CvarReloadSniperMilitary.FloatValue; // Apply Sniper Military reload speed modifier
		case L4D2WeaponType_SniperAwp: 
			speedmodifier *= g_CvarReloadSniperAwp.FloatValue; // Apply Sniper AWP reload speed modifier
		case L4D2WeaponType_RifleSg552: 
			speedmodifier *= g_CvarReloadRifleSg552.FloatValue; // Apply Rifle SG552 reload speed modifier
		case L4D2WeaponType_RifleDesert: 
			speedmodifier *= g_CvarReloadRifleDesert.FloatValue; // Apply Rifle Desert reload speed modifier
		case L4D2WeaponType_SMGMp5: 
			speedmodifier *= g_CvarReloadSMGMp5.FloatValue; // Apply SMG MP5 reload speed modifier
		case L4D2WeaponType_GrenadeLauncher: 
			speedmodifier *= g_CvarReloadGrenadeLauncher.FloatValue; // Apply Grenade Launcher reload speed modifier
	}
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

bool IsSurvivor(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}