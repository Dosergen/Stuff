#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

bool g_bIsWeaponEmpty[2048];
bool g_bIgnoreWeaponSwitch[MAXPLAYERS+1];

ConVar ConVar_Pistol_EReloadLayer, ConVar_Pistol_EReloadTime, ConVar_Pistol_ReloadLayer, 
       ConVar_Pistol_ReloadTime, ConVar_Pistol_PickupLayer,ConVar_Pistol_SwtichLayer;

ConVar ConVar_DPistol_EReloadLayer, ConVar_DPistol_EReloadTime, ConVar_DPistol_ReloadLayer,
       ConVar_DPistol_ReloadTime, ConVar_DPistol_PickupLayer, ConVar_DPistol_SwtichLayer;

ConVar ConVar_Huntrifle_EReloadLayer, ConVar_Huntrifle_EReloadTime, ConVar_Huntrifle_ReloadLayer,
       ConVar_Huntrifle_ReloadTime, ConVar_Huntrifle_PickupLayer, ConVar_Huntrifle_SwtichLayer;

ConVar ConVar_Rifle_EReloadLayer, ConVar_Rifle_EReloadTime, ConVar_Rifle_ReloadLayer, 
       ConVar_Rifle_ReloadTime, ConVar_Rifle_PickupLayer, ConVar_Rifle_SwtichLayer;

ConVar ConVar_Smg_EReloadLayer, ConVar_Smg_EReloadTime, ConVar_Smg_ReloadLayer,
       ConVar_Smg_ReloadTime, ConVar_Smg_PickupLayer, ConVar_Smg_SwtichLayer;

ConVar ConVar_Pumpshot_PickupLayer, ConVar_Pumpshot_SwtichLayer;
ConVar ConVar_Autoshot_PickupLayer, ConVar_Autoshot_SwtichLayer;
ConVar ConVar_BlockAttack2;

public Plugin myinfo =
{
	name = "Beta Reload Animations",
	author = "Tester:Xeno, Coder:Timocop",
	description = "Beta Reloading Animations",
	version = "2.2",
	url = ""
}

public void OnPluginStart()
{
	//PISTOL
	ConVar_Pistol_EReloadLayer = CreateConVar( "l4dbeta_pistol_empty_reloadlayer", "9", "[-1 = DISABLED] <The Empty Reload Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Pistol_EReloadTime = CreateConVar( "l4dbeta_pistol_empty_reloadtime", "1.2", "[1.0 = DISABLED] <Time to Block the Empty Reload Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Pistol_ReloadLayer = CreateConVar( "l4dbeta_pistol_normal_reloadlayer", "-1", "[-1 = DISABLED | 7 = OTHER] <The Normal Reload Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Pistol_ReloadTime = CreateConVar( "l4dbeta_pistol_normal_reloadtime", "0.9", "[1.0 = DISABLED] <Time to Block the Normal Reload Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Pistol_PickupLayer = CreateConVar( "l4dbeta_pistol_pickuplayer", "11", "[-1 = DISABLED] <The Pickup Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Pistol_SwtichLayer = CreateConVar( "l4dbeta_pistol_swtichlayer", "15", "[-1 = DISABLED] <The Swtich Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	//DUAL PISTOL
	ConVar_DPistol_EReloadLayer = CreateConVar( "l4dbeta_dpistol_empty_reloadlayer", "17", "[-1 = DISABLED] <The Empty Reload Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_DPistol_EReloadTime = CreateConVar( "l4dbeta_dpistol_empty_reloadtime", "1.2", "[1.0 = DISABLED] <Time to Block the Empty Reload Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_DPistol_ReloadLayer = CreateConVar( "l4dbeta_dpistol_normal_reloadlayer", "-1", "[-1 = DISABLED | 13 = OTHER] <The Normal Reload Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_DPistol_ReloadTime = CreateConVar( "l4dbeta_dpistol_normal_reloadtime", "0.8", "[1.0 = DISABLED] <Time to Block the Normal Reload Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_DPistol_PickupLayer = CreateConVar( "l4dbeta_dpistol_pickuplayer", "5", "[-1 = DISABLED] <The Pickup Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_DPistol_SwtichLayer = CreateConVar( "l4dbeta_dpistol_swtichlayer", "9", "[-1 = DISABLED] <The Swtich Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	//Huntingrifle
	ConVar_Huntrifle_EReloadLayer = CreateConVar( "l4dbeta_huntingrifle_empty_reloadlayer", "15", "[-1 = DISABLED] <The Empty Reload Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Huntrifle_EReloadTime = CreateConVar( "l4dbeta_huntingrifle_empty_reloadtime", "1.2", "[1.0 = DISABLED] <Time to Block the Empty Reload Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Huntrifle_ReloadLayer = CreateConVar( "l4dbeta_huntingrifle_normal_reloadlayer", "-1", "[-1 = DISABLED | 7 = OTHER] <The Normal Reload Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Huntrifle_ReloadTime = CreateConVar( "l4dbeta_huntingrifle_normal_reloadtime", "0.9", "[1.0 = DISABLED] <Time to Block the Normal Reload Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Huntrifle_PickupLayer = CreateConVar( "l4dbeta_huntingrifle_pickuplayer", "5", "[-1 = DISABLED] <The Pickup Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Huntrifle_SwtichLayer = CreateConVar( "l4dbeta_huntingrifle_swtichlayer", "7", "[-1 = DISABLED] <The Swtich Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	//Rifle
	ConVar_Rifle_EReloadLayer = CreateConVar( "l4dbeta_rifle_empty_reloadlayer", "18", "[-1 = DISABLED] <The Empty Reload Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Rifle_EReloadTime = CreateConVar( "l4dbeta_rifle_empty_reloadtime", "1.2", "[1.0 = DISABLED] <Time to Block the Empty Reload Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Rifle_ReloadLayer = CreateConVar( "l4dbeta_rifle_normal_reloadlayer", "-1", "[-1 = DISABLED | 16 = OTHER] <The Normal Reload Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Rifle_ReloadTime = CreateConVar( "l4dbeta_rifle_normal_reloadtime", "1.0", "[1.0 = DISABLED] <Time to Block the Normal Reload Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Rifle_PickupLayer = CreateConVar( "l4dbeta_rifle_pickuplayer", "8", "[-1 = DISABLED] <The Pickup Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Rifle_SwtichLayer = CreateConVar( "l4dbeta_rifle_swtichlayer", "14", "[-1 = DISABLED] <The Swtich Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	//SMG
	ConVar_Smg_EReloadLayer = CreateConVar( "l4dbeta_smg_empty_reloadlayer", "15", "[-1 = DISABLED] <The Empty Reload Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Smg_EReloadTime = CreateConVar( "l4dbeta_smg_empty_reloadtime", "1.3", "[1.0 = DISABLED] <Time to Block the Empty Reload Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Smg_ReloadLayer = CreateConVar( "l4dbeta_smg_normal_reloadlayer", "-1", "[-1 = DISABLED | 13 = OTHER] <The Normal Reload Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Smg_ReloadTime = CreateConVar( "l4dbeta_smg_normal_reloadtime", "0.7", "[1.0 = DISABLED] <Time to Block the Normal Reload Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Smg_PickupLayer = CreateConVar( "l4dbeta_smg_pickuplayer", "5", "[-1 = DISABLED] <The Pickup Reload Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Smg_SwtichLayer = CreateConVar( "l4dbeta_smg_swtichlayer", "9", "[-1 = DISABLED] <The Swtich Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	//Pumpshotgun
	ConVar_Pumpshot_PickupLayer = CreateConVar( "l4dbeta_pumpshotgun_pickuplayer", "18", "[-1 = DISABLED] <The Pickup Reload Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Pumpshot_SwtichLayer = CreateConVar( "l4dbeta_pumpshotgun_swtichlayer", "18", "[-1 = DISABLED] <The Swtich Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	//Autoshotgun
	ConVar_Autoshot_PickupLayer = CreateConVar( "l4dbeta_autoshotgun_pickuplayer", "39", "[-1 = DISABLED] <The Pickup Reload Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	ConVar_Autoshot_SwtichLayer = CreateConVar( "l4dbeta_autoshotgun_swtichlayer", "39", "[-1 = DISABLED] <The Swtich Layer Sequence>", FCVAR_REPLICATED | FCVAR_NOTIFY );
	
	ConVar_BlockAttack2 = CreateConVar( "l4dbeta_block_shove", "0", "[1/0 BLOCK/DON'T BLOCK] <Shove is blocked while Reload>", FCVAR_REPLICATED | FCVAR_NOTIFY );

	HookEvent("weapon_fire", eWeaponFire);
	HookEvent("weapon_reload", eReloadWeapon);
	HookEvent("spawner_give_item", ePlayerUse);
	HookEvent("item_pickup", ePlayerUse);
	
	RegConsoleCmd("+attack2", Attack2_Cmd);
	
	AutoExecConfig(true, "l4dbeta_reloading_animation");
}

/****************************************************************************************************************************
*****************************************************************************************************************************
*****************************************************************************************************************************
    WARNING!
	    If you're using your own animations, make sure its a LAYER(!!!!!) (ModelViewer > "v_models" and select "_LAYERS" only!) or your animation will mess up!
	        Good Luck...
*****************************************************************************************************************************
*****************************************************************************************************************************
*****************************************************************************************************************************/

Action Attack2_Cmd(int iClient, int args)    
{
	if (ConVar_BlockAttack2.IntValue != 1)
		return Plugin_Continue;
	if (!IsValidClient(iClient) || IsFakeClient(iClient) || GetClientTeam(iClient) != 2)
		return Plugin_Continue;
	int iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(iCurrentWeapon))
		return Plugin_Continue;
	if (GetEntProp(iCurrentWeapon, Prop_Send, "m_bInReload") > 0)
	{
		PrintHintText(iClient, "[!] Shove is blocked while reloading [!]");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

Action eWeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient) || IsFakeClient(iClient) || GetClientTeam(iClient) != 2)
		return Plugin_Continue;
	ChangeWeaponSize(iClient, 1);
	return Plugin_Continue;
}

bool ChangeWeaponSize(int iClient, int iClip)
{
	int iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(iCurrentWeapon))
		return false;
	g_bIsWeaponEmpty[iCurrentWeapon] = (GetEntProp(iCurrentWeapon, Prop_Data, "m_iClip1") <= iClip);
	return true;
}

public Action OnPlayerRunCmd(int iClient, int& iButtons, int& iImpulse, float fVelocity[3], float fAngles[3], int& iWeapon)
{ 
	if (!IsClientInGame(iClient))
		return Plugin_Continue;
	if (GetClientTeam(iClient) != 2)
		return Plugin_Continue;
	if (IsFakeClient(iClient))
		return Plugin_Continue;
	if (!IsPlayerAlive(iClient))
		return Plugin_Continue;
	static int OLD_WEAPON[MAXPLAYERS+1];
	static int NEW_WEAPON[MAXPLAYERS+1];
	NEW_WEAPON[iClient] = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (NEW_WEAPON[iClient] != OLD_WEAPON[iClient])
	{
		if (!g_bIgnoreWeaponSwitch[iClient])
			WeaponChangeAnimation(iClient);
		else
			g_bIgnoreWeaponSwitch[iClient] = false;
		ChangeWeaponSize(iClient, 0);
	}
	OLD_WEAPON[iClient] = NEW_WEAPON[iClient];
	return Plugin_Continue;
}

bool WeaponChangeAnimation(int iClient)
{
	int iWeaponNum = 0;
	if (GetPlayerWeaponSlot(iClient, 0) > 0 && GetEntProp(GetPlayerWeaponSlot(iClient, 0), Prop_Data, "m_iClip1") > 0)
		iWeaponNum += 1;
	if (GetPlayerWeaponSlot(iClient, 1) > 0)
		iWeaponNum += 1;
	if (GetPlayerWeaponSlot(iClient, 2) > 0)
		iWeaponNum += 1;
	if (GetPlayerWeaponSlot(iClient, 3) > 0)
		iWeaponNum += 1;
	if (GetPlayerWeaponSlot(iClient, 4) > 0)
		iWeaponNum += 1;
	int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if (!IsValidEntity(iViewModel))
		return false;
	int iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(iCurrentWeapon))
		return false;
	if (iWeaponNum > 1)
	{
		char sWeaponName[64];
		GetClientWeapon(iClient, sWeaponName, sizeof(sWeaponName));
		if (StrContains(sWeaponName, "smg", false) != -1)
		{
			if (ConVar_Smg_SwtichLayer.IntValue == -1)
				return false;
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Smg_SwtichLayer.IntValue);
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
			ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
		}
		else if (StrContains(sWeaponName, "weapon_rifle", false) != -1)
		{
			if (ConVar_Rifle_SwtichLayer.IntValue == -1)
				return false;
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Rifle_SwtichLayer.IntValue);
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
			ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
		}
		else if (StrContains(sWeaponName, "hunting_rifle", false) != -1)
		{
			if (ConVar_Huntrifle_SwtichLayer.IntValue == -1)
				return false;
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Huntrifle_SwtichLayer.IntValue); 
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
			ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
		}
		else if (StrContains(sWeaponName, "pumpshotgun", false) != -1)
		{
			if (ConVar_Pumpshot_SwtichLayer.IntValue == -1)
				return false;
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Pumpshot_SwtichLayer.IntValue); 
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
			ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
		}
		else if (StrContains(sWeaponName, "autoshotgun", false) != -1)
		{
			if (ConVar_Autoshot_SwtichLayer.IntValue == -1)
				return false;
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Autoshot_SwtichLayer.IntValue); 
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
			ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
		}
		else if (StrContains(sWeaponName, "pistol", false) != -1)
		{
			if (GetEntProp(iCurrentWeapon, Prop_Send, "m_isDualWielding") > 0) // ITS A DUAL PISTOL! RUNN!!
			{
				if (ConVar_DPistol_SwtichLayer.IntValue == -1)
					return false;
				SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_DPistol_SwtichLayer.IntValue);
				SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
				ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
			}
			else
			{
				if (ConVar_Pistol_SwtichLayer.IntValue == -1)
					return false;
				SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Pistol_SwtichLayer.IntValue);
				SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
				ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
			}
		}
	}
	return true;
}



Action eReloadWeapon(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient) || IsFakeClient(iClient) || GetClientTeam(iClient) != 2)
		return Plugin_Continue;
	int iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(iCurrentWeapon))
		return Plugin_Continue;
	int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if (!IsValidEntity(iViewModel))
		return Plugin_Continue;
	char sWeaponName[32];
	GetClientWeapon(iClient, sWeaponName, sizeof(sWeaponName));
	if (StrContains(sWeaponName, "smg", false) != -1)
	{
		if (g_bIsWeaponEmpty[iCurrentWeapon] && ConVar_Smg_EReloadLayer.IntValue > -1)
		{
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Smg_EReloadLayer.IntValue);
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime()); //Some Animation Glich Fixes
			ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
			Weapon_Speed(iClient, ConVar_Smg_EReloadTime.FloatValue);
		}
		else if (ConVar_Smg_ReloadLayer.IntValue > -1)
		{
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Smg_ReloadLayer.IntValue);
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
			ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
			Weapon_Speed(iClient, ConVar_Smg_ReloadTime.FloatValue);
		}
	}
	else if (StrContains(sWeaponName, "weapon_rifle", false) != -1)
	{
		if (g_bIsWeaponEmpty[iCurrentWeapon] && ConVar_Rifle_EReloadLayer.IntValue > -1)
		{
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Rifle_EReloadLayer.IntValue);
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
			ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
			Weapon_Speed(iClient, ConVar_Rifle_EReloadTime.FloatValue);
		}
		else if (ConVar_Rifle_ReloadLayer.IntValue > -1)
		{
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Rifle_ReloadLayer.IntValue);
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
			ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
			Weapon_Speed(iClient, ConVar_Rifle_ReloadTime.FloatValue);
		}
	}
	else if (StrContains(sWeaponName, "hunting_rifle", false) != -1)
	{
		if (g_bIsWeaponEmpty[iCurrentWeapon] && ConVar_Huntrifle_EReloadLayer.IntValue > -1)
		{
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Huntrifle_EReloadLayer.IntValue); //16
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime()); //Some Animation Glich Fixes
			ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
			Weapon_Speed(iClient, ConVar_Huntrifle_EReloadTime.FloatValue);
		}
		else if (ConVar_Huntrifle_ReloadLayer.IntValue > -1)
		{
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Huntrifle_ReloadLayer.IntValue);
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
			ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
			Weapon_Speed(iClient, ConVar_Huntrifle_ReloadTime.FloatValue);
		}
	}
	else if (StrContains(sWeaponName, "pistol", false) != -1)
	{
		if (GetEntProp(iCurrentWeapon, Prop_Send, "m_isDualWielding") > 0)
		{	 
			// PrintToChatAll("Weapon_DualPistolSide: %i", Weapon_DualPistolSide(iCurrentWeapon));
			//DUAL PISTOL
			if (g_bIsWeaponEmpty[iCurrentWeapon] && ConVar_DPistol_EReloadLayer.IntValue > -1)
			{
				SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", GetConVarInt(ConVar_DPistol_EReloadLayer));
				SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime()); //Some Animation Glich Fixes
				ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
				Weapon_Speed(iClient, ConVar_DPistol_EReloadTime.FloatValue);
			}
			else if (ConVar_DPistol_ReloadLayer.IntValue > -1)
			{
				SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_DPistol_ReloadLayer.IntValue);
				SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
				ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
				Weapon_Speed(iClient, ConVar_DPistol_ReloadTime.FloatValue);
			}
		}
		else 
		{	
			//ONE PISTOL
			if (g_bIsWeaponEmpty[iCurrentWeapon] && ConVar_Pistol_EReloadLayer.IntValue > -1)
			{
				SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Pistol_EReloadLayer.IntValue);
				SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime()); //Some Animation Glich Fixes
				ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
				Weapon_Speed(iClient, ConVar_Pistol_EReloadTime.FloatValue);
			}
			else if (ConVar_Pistol_ReloadLayer.IntValue > -1)
			{
				SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Pistol_ReloadLayer.IntValue);
				SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
				ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
				Weapon_Speed(iClient, ConVar_Pistol_ReloadTime.FloatValue);
			}
		}
	}
	return Plugin_Continue;
}
Action ePlayerUse(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient) || IsFakeClient(iClient) || GetClientTeam(iClient) != 2)
		return Plugin_Continue;
	char sPickupName[64];
	GetEventString(event, "item", sPickupName, sizeof(sPickupName)); 
	g_bIgnoreWeaponSwitch[iClient] = true;
	int iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(iCurrentWeapon))
		return Plugin_Continue;
	int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if (!IsValidEntity(iViewModel))
		return Plugin_Continue;
	char sWeaponName[32];
	GetClientWeapon(iClient, sWeaponName, sizeof(sWeaponName));
	if (!StrEqual(sPickupName, sWeaponName, false))
		return Plugin_Continue;
	if (StrContains(sPickupName, "smg", false) != -1)
	{
		if (ConVar_Smg_PickupLayer.IntValue < 0)
			return Plugin_Continue;
		SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Smg_PickupLayer.IntValue);
		ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
	}
	else if (StrContains(sPickupName, "weapon_rifle", false) != -1)
	{
		if (ConVar_Rifle_PickupLayer.IntValue < 0)
			return Plugin_Continue;
		SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Rifle_PickupLayer.IntValue);
		ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
	}
	else if (StrContains(sPickupName, "hunting_rifle", false) != -1)
	{
		if (ConVar_Huntrifle_PickupLayer.IntValue < 0)
			return Plugin_Continue;
		SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Huntrifle_PickupLayer.IntValue);
		ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
	}
	else if (StrContains(sPickupName, "pumpshotgun", false) != -1)
	{
		if (ConVar_Pumpshot_PickupLayer.IntValue < 0)
			return Plugin_Continue;
		SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Pumpshot_PickupLayer.IntValue);
		ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
	}
	else if (StrContains(sPickupName, "autoshotgun", false) != -1)
	{
		if (ConVar_Autoshot_PickupLayer.IntValue < 0)
			return Plugin_Continue;
		SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Autoshot_PickupLayer.IntValue);
		ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
	}
	else if (StrContains(sPickupName, "pistol", false) != -1)
	{
		if (GetEntProp(iCurrentWeapon, Prop_Send, "m_isDualWielding") > 0) // ITS A DUAL PISTOL! RUNN!!
		{
			if (ConVar_DPistol_PickupLayer.IntValue < 0)
				return Plugin_Continue;
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_DPistol_PickupLayer.IntValue);
			ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
		}
		else
		{
			if (ConVar_Pistol_PickupLayer.IntValue < 0)
				return Plugin_Continue;
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Pistol_PickupLayer.IntValue);
			ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
		}
	}
	return Plugin_Continue;
}

void Weapon_Speed(int iClient, float fValue) //WITHOUT ANIMATION SPEED CHANGE!
{
	int iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (IsValidEntity(iCurrentWeapon))
	{
		float fNextPrimaryAttack  = GetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextPrimaryAttack");
		float fGameTime = GetGameTime();
		float fNextPrimaryAttack_Mod = (fNextPrimaryAttack - fGameTime ) * fValue;
		fNextPrimaryAttack_Mod += fGameTime;
		SetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextPrimaryAttack", fNextPrimaryAttack_Mod);
		SetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flTimeWeaponIdle", fNextPrimaryAttack_Mod);
		SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", fNextPrimaryAttack_Mod);

	}
}

bool IsValidClient(int iClient)
{
	if (iClient < 1 || iClient > MaxClients)
		return false;
	return IsClientInGame(iClient);
}