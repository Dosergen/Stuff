#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.02e"
#define CVAR_FLAGS	FCVAR_NOTIFY

bool    b_PluginEnable, b_Left4Dead2;
int     ent_table[128][2], new_ent_counter = 0;

int     i_limit_all, i_limit_autoshotgun, i_limit_rifle, i_limit_hunting_rifle, i_limit_pistol,
        i_limit_pumpshotgun, i_limit_smg, i_limit_grenade_launcher, i_limit_pistol_magnum, i_limit_rifle_ak47,
        i_limit_rifle_desert, i_limit_rifle_m60, i_limit_rifle_sg552, i_limit_shotgun_chrome, i_limit_shotgun_spas,
        i_limit_smg_mp5, i_limit_smg_silenced, i_limit_sniper_awp, i_limit_sniper_military, i_limit_sniper_scout;

ConVar  h_CvarEnable, h_limit_all, h_limit_autoshotgun, h_limit_rifle, h_limit_hunting_rifle, h_limit_pistol,
        h_limit_pumpshotgun, h_limit_smg, h_limit_grenade_launcher, h_limit_pistol_magnum, h_limit_rifle_ak47,
        h_limit_rifle_desert, h_limit_rifle_m60, h_limit_rifle_sg552, h_limit_shotgun_chrome, h_limit_shotgun_spas,
        h_limit_smg_mp5, h_limit_smg_silenced, h_limit_sniper_awp, h_limit_sniper_military, h_limit_sniper_scout;

public Plugin myinfo =
{
	name = "[L4D/2] Weapon Remover",
	author = "Rain_orel, Hanzolo, Dosergen",
	description = "Removes weapon spawn when a specified number of pickups is reached",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=1254023"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{	
	EngineVersion iEngineVersion = GetEngineVersion();
	if (iEngineVersion == Engine_Left4Dead)
		b_Left4Dead2 = false;
	else if (iEngineVersion == Engine_Left4Dead2)
		b_Left4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d_weaponremove_version", PLUGIN_VERSION, "[L4D/2] Weapon Remover limits the maximum number of times a weapon can be grabbed", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	h_CvarEnable = CreateConVar("l4d_weaponremove_enable", "1", "Enable or disable Weapon Remover plugin", CVAR_FLAGS);
	h_limit_all = CreateConVar("l4d_weaponremove_limit_all", "0", "Limits all weapons to this many pickups (0 = no limit)", CVAR_FLAGS);
	// L4D1 & L4D2
	h_limit_autoshotgun = CreateConVar("l4d_weaponremove_limit_autoshotgun", "1", "Limit for Autoshotguns (0 = infinite, -1 = disable)", CVAR_FLAGS);
	h_limit_rifle = CreateConVar("l4d_weaponremove_limit_rifle", "1", "Limit for M4s (0 = infinite, -1 = disable)", CVAR_FLAGS);
	h_limit_hunting_rifle = CreateConVar("l4d_weaponremove_limit_hunting_rifle", "1", "Limit for Sniper Rifles (0 = infinite, -1 = disable)", CVAR_FLAGS);
	h_limit_pistol = CreateConVar("l4d_weaponremove_limit_pistol", "1", "Limit for Pistols (0 = infinite, -1 = disable)", CVAR_FLAGS);
	h_limit_pumpshotgun = CreateConVar("l4d_weaponremove_limit_pumpshotgun", "1", "Limit for Pumpshotguns (0 = infinite, -1 = disable)", CVAR_FLAGS);
	h_limit_smg = CreateConVar("l4d_weaponremove_limit_smg", "1", "Limit for SMGs (0 = infinite, -1 = disable)", CVAR_FLAGS);

	h_CvarEnable.AddChangeHook(ConVarChanged_Allow);
	h_limit_all.AddChangeHook(ConVarChanged_Cvars);
	h_limit_autoshotgun.AddChangeHook(ConVarChanged_Cvars);
	h_limit_rifle.AddChangeHook(ConVarChanged_Cvars);
	h_limit_hunting_rifle.AddChangeHook(ConVarChanged_Cvars);
	h_limit_pistol.AddChangeHook(ConVarChanged_Cvars);
	h_limit_pumpshotgun.AddChangeHook(ConVarChanged_Cvars);
	h_limit_smg.AddChangeHook(ConVarChanged_Cvars);
	// L4D2
	if (b_Left4Dead2)
	{
		h_limit_grenade_launcher = CreateConVar("l4d2_weaponremove_limit_grenade_launcher", "1", "Limit for this weapon (0 = infinite, -1 = disable)", CVAR_FLAGS);
		h_limit_pistol_magnum = CreateConVar("l4d2_weaponremove_limit_pistol_magnum", "1", "Limit for this weapon (0 = infinite, -1 = disable)", CVAR_FLAGS);
		h_limit_rifle_ak47 = CreateConVar("l4d2_weaponremove_limit_rifle_ak47", "1", "Limit for this weapon (0 = infinite, -1 = disable)", CVAR_FLAGS);
		h_limit_rifle_desert = CreateConVar("l4d2_weaponremove_limit_rifle_desert", "1", "Limit for this weapon (0 = infinite, -1 = disable)", CVAR_FLAGS);
		h_limit_rifle_m60 = CreateConVar("l4d2_weaponremove_limit_rifle_m60", "1", "Limit for this weapon (0 = infinite, -1 = disable)", CVAR_FLAGS);
		h_limit_rifle_sg552 = CreateConVar("l4d2_weaponremove_limit_rifle_sg552", "1", "Limit for this weapon (0 = infinite, -1 = disable)", CVAR_FLAGS);
		h_limit_shotgun_chrome = CreateConVar("l4d2_weaponremove_limit_shotgun_chrome", "1", "Limit for this weapon (0 = infinite, -1 = disable)", CVAR_FLAGS);
		h_limit_shotgun_spas = CreateConVar("l4d2_weaponremove_limit_shotgun_spas", "1", "Limit for this weapon (0 = infinite, -1 = disable)", CVAR_FLAGS);
		h_limit_smg_mp5 = CreateConVar("l4d2_weaponremove_limit_smg_mp5", "1", "Limit for this weapon (0 = infinite, -1 = disable)", CVAR_FLAGS);
		h_limit_smg_silenced = CreateConVar("l4d2_weaponremove_limit_smg_silenced", "1", "Limit for this weapon (0 = infinite, -1 = disable)", CVAR_FLAGS);
		h_limit_sniper_awp = CreateConVar("l4d2_weaponremove_limit_sniper_awp", "1", "Limit for this weapon (0 = infinite, -1 = disable)", CVAR_FLAGS);
		h_limit_sniper_military = CreateConVar("l4d2_weaponremove_limit_sniper_military", "1", "Limit for this weapon (0 = infinite, -1 = disable)", CVAR_FLAGS);
		h_limit_sniper_scout = CreateConVar("l4d2_weaponremove_limit_sniper_scout", "1", "Limit for this weapon (0 = infinite, -1 = disable)", CVAR_FLAGS);	

		h_limit_grenade_launcher.AddChangeHook(ConVarChanged_Cvars);
		h_limit_pistol_magnum.AddChangeHook(ConVarChanged_Cvars);
		h_limit_rifle_ak47.AddChangeHook(ConVarChanged_Cvars);
		h_limit_rifle_desert.AddChangeHook(ConVarChanged_Cvars);
		h_limit_rifle_m60.AddChangeHook(ConVarChanged_Cvars);
		h_limit_rifle_sg552.AddChangeHook(ConVarChanged_Cvars);
		h_limit_shotgun_chrome.AddChangeHook(ConVarChanged_Cvars);
		h_limit_shotgun_spas.AddChangeHook(ConVarChanged_Cvars);
		h_limit_smg_mp5.AddChangeHook(ConVarChanged_Cvars);
		h_limit_smg_silenced.AddChangeHook(ConVarChanged_Cvars);
		h_limit_sniper_awp.AddChangeHook(ConVarChanged_Cvars);
		h_limit_sniper_military.AddChangeHook(ConVarChanged_Cvars);
		h_limit_sniper_scout.AddChangeHook(ConVarChanged_Cvars);
	}
	AutoExecConfig(true, "l4d_weaponremover");
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged_Allow(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	i_limit_all = h_limit_all.IntValue;
	i_limit_autoshotgun = h_limit_autoshotgun.IntValue;
	i_limit_rifle = h_limit_rifle.IntValue;
	i_limit_hunting_rifle = h_limit_hunting_rifle.IntValue;
	i_limit_pistol = h_limit_pistol.IntValue;
	i_limit_pumpshotgun = h_limit_pumpshotgun.IntValue;
	i_limit_smg = h_limit_smg.IntValue;
	if (b_Left4Dead2)
	{
		i_limit_grenade_launcher = h_limit_grenade_launcher.IntValue;
		i_limit_pistol_magnum = h_limit_pistol_magnum.IntValue;	
		i_limit_rifle_ak47 = h_limit_rifle_ak47.IntValue;	
		i_limit_rifle_desert = h_limit_rifle_desert.IntValue;	
		i_limit_rifle_m60 = h_limit_rifle_m60.IntValue;	
		i_limit_rifle_sg552 = h_limit_rifle_sg552.IntValue;
		i_limit_shotgun_chrome = h_limit_shotgun_chrome.IntValue;
		i_limit_shotgun_spas = h_limit_shotgun_spas.IntValue;
		i_limit_smg_mp5 = h_limit_smg_mp5.IntValue;
		i_limit_smg_silenced = h_limit_smg_silenced.IntValue;
		i_limit_sniper_awp = h_limit_sniper_awp.IntValue;
		i_limit_sniper_military = h_limit_sniper_military.IntValue;
		i_limit_sniper_scout = h_limit_sniper_scout.IntValue;
	}
}

void IsAllowed()
{
	bool bCvarAllow = h_CvarEnable.BoolValue;
	GetCvars();
	if (b_PluginEnable == false && bCvarAllow == true)
	{
		b_PluginEnable = true;
		HookEvent("round_start", eRoundStart, EventHookMode_Post);
		HookEvent("spawner_give_item", eSpawnerGiveItem, EventHookMode_Post);
	}
	else if (b_PluginEnable == true && bCvarAllow == false)
	{
		b_PluginEnable = false;
		UnhookEvent("round_start", eRoundStart, EventHookMode_Post);
		UnhookEvent("spawner_give_item", eSpawnerGiveItem, EventHookMode_Post);
	}
}

void eRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!b_PluginEnable)
		return;
	for (int i = 0; i < sizeof(ent_table); i++)
	{
		ent_table[i][0] = -1;
		ent_table[i][1] = -1;
	}
	new_ent_counter = 0;
	// Remove all weapons which have a limit of "-1"
	// L4D1 + 2
	if (i_limit_autoshotgun < 0) DeleteAllEntities("weapon_autoshotgun_spawn");
	if (i_limit_rifle < 0) DeleteAllEntities("weapon_rifle_spawn");
	if (i_limit_hunting_rifle < 0) DeleteAllEntities("weapon_hunting_rifle_spawn");
	if (i_limit_pistol < 0) DeleteAllEntities("weapon_pistol_spawn");
	if (i_limit_pumpshotgun < 0) DeleteAllEntities("weapon_pumpshotgun_spawn");
	if (i_limit_smg < 0) DeleteAllEntities("weapon_smg_spawn");
	// L4D2
	if (b_Left4Dead2)
	{
		if (i_limit_grenade_launcher < 0) DeleteAllEntities("weapon_grenade_launcher_spawn");
		if (i_limit_pistol_magnum < 0) DeleteAllEntities("weapon_pistol_magnum_spawn");
		if (i_limit_rifle_ak47 < 0) DeleteAllEntities("weapon_rifle_ak47_spawn");
		if (i_limit_rifle_desert < 0) DeleteAllEntities("weapon_rifle_desert_spawn");
		if (i_limit_rifle_m60 < 0) DeleteAllEntities("weapon_rifle_m60_spawn");
		if (i_limit_rifle_sg552 < 0) DeleteAllEntities("weapon_rifle_sg552_spawn");
		if (i_limit_shotgun_chrome < 0) DeleteAllEntities("weapon_shotgun_chrome_spawn");
		if (i_limit_shotgun_spas < 0) DeleteAllEntities("weapon_shotgun_spas_spawn");
		if (i_limit_smg_mp5 < 0) DeleteAllEntities("weapon_smg_mp5_spawn");
		if (i_limit_smg_silenced < 0) DeleteAllEntities("weapon_smg_silenced_spawn");
		if (i_limit_sniper_awp < 0) DeleteAllEntities("weapon_sniper_awp_spawn");
		if (i_limit_sniper_military < 0) DeleteAllEntities("weapon_sniper_military_spawn");
		if (i_limit_sniper_scout < 0) DeleteAllEntities("weapon_sniper_scout_spawn");
	}
}

void eSpawnerGiveItem(Event event, const char[] name, bool dontBroadcast)
{
	if (!b_PluginEnable)
		return;
	char item_name[32];
	event.GetString("item", item_name, sizeof(item_name));
	int entity_id = event.GetInt("spawner");
	if (GetUseCount(entity_id) == -1)
	{
		ent_table[new_ent_counter][0] = entity_id;
		ent_table[new_ent_counter][1] = 0;
		new_ent_counter++;
	}
	SetUseCount(entity_id);
	//PrintToServer("item_name is %s ", item_name); // DEBUG
	if	((GetUseCount(entity_id) == i_limit_all) ||
		((StrEqual(item_name, "weapon_autoshotgun", false) == true) && (GetUseCount(entity_id) == i_limit_autoshotgun)) ||
		((StrEqual(item_name, "weapon_rifle", false) == true) && (GetUseCount(entity_id) == i_limit_rifle)) ||
		((StrEqual(item_name, "weapon_hunting_rifle", false) == true) && (GetUseCount(entity_id) == i_limit_hunting_rifle)) ||
		((StrEqual(item_name, "weapon_pistol", false) == true) && (GetUseCount(entity_id) == i_limit_pistol)) ||
		((StrEqual(item_name, "weapon_pumpshotgun", false) == true) && (GetUseCount(entity_id) == i_limit_pumpshotgun)) ||
		((StrEqual(item_name, "weapon_smg", false) == true) && (GetUseCount(entity_id) == i_limit_smg)) ||
		((StrEqual(item_name, "weapon_grenade_launcher", false) == true) && (GetUseCount(entity_id) == i_limit_grenade_launcher)) ||
		((StrEqual(item_name, "weapon_pistol_magnum", false) == true) && (GetUseCount(entity_id) == i_limit_pistol_magnum)) ||
		((StrEqual(item_name, "weapon_rifle_ak47", false) == true) && (GetUseCount(entity_id) == i_limit_rifle_ak47)) ||
		((StrEqual(item_name, "weapon_rifle_desert", false) == true) && (GetUseCount(entity_id) == i_limit_rifle_desert)) ||
		((StrEqual(item_name, "weapon_rifle_m60", false) == true) && (GetUseCount(entity_id) == i_limit_rifle_m60)) ||
		((StrEqual(item_name, "weapon_rifle_sg552", false) == true) && (GetUseCount(entity_id) == i_limit_rifle_sg552)) ||
		((StrEqual(item_name, "weapon_shotgun_chrome", false) == true) && (GetUseCount(entity_id) == i_limit_shotgun_chrome)) ||
		((StrEqual(item_name, "weapon_shotgun_spas", false) == true) && (GetUseCount(entity_id) == i_limit_shotgun_spas)) ||
		((StrEqual(item_name, "weapon_smg_mp5", false) == true) && (GetUseCount(entity_id) == i_limit_smg_mp5)) ||
		((StrEqual(item_name, "weapon_smg_silenced", false) == true) && (GetUseCount(entity_id) == i_limit_smg_silenced)) ||
		((StrEqual(item_name, "weapon_sniper_awp", false) == true) && (GetUseCount(entity_id) == i_limit_sniper_awp)) ||
		((StrEqual(item_name, "weapon_sniper_military", false) == true) && (GetUseCount(entity_id) == i_limit_sniper_military)) ||
		((StrEqual(item_name, "weapon_sniper_scout", false) == true) && (GetUseCount(entity_id) == i_limit_sniper_scout)))
	{
		RemoveEntity(entity_id);
	}
}

int GetUseCount(const int entid)
{
	for (int i = 0; i < sizeof(ent_table); i++)
	{
		if (ent_table[i][0] == entid)
			return ent_table[i][1];
	}
	return -1;
}

void SetUseCount(const int entid)
{
	for (int j = 0; j < sizeof(ent_table); j++)
	{
		if (ent_table[j][0] == entid)
			ent_table[j][1]++;
	}
}

void DeleteAllEntities(const char[] class)
{
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, class)) != INVALID_ENT_REFERENCE)
		RemoveEntity(ent);
}