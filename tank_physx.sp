#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

bool g_bLeft4Dead2;

bool g_bAllowHurt = false;
bool g_bRockPhyx = false;
bool g_bIncapKnock = false;
bool g_bPreIncap = false;
bool g_bAllDisabled = false;

float g_fRockForce;
float g_fPunchForce;
float g_fPunchForceZ;
float g_fPunchIncap;

ConVar hCvar_RockPhyx = null;
ConVar hCvar_IncapKnock = null;
ConVar hCvar_PreIncap = null;
ConVar hCvar_RockForce = null;
ConVar hCvar_PunchFling = null;
ConVar hCvar_PunchForceZ = null;
ConVar hCvar_PunchForce = null;
ConVar hCvar_PunchIncap = null;

int g_iPunchFling;
int ZOMBIECLASS_TANK;
int iRockRef[MAXPLAYERS+1];
int bHitByRock[2048+1];

#define PLUGIN_VERSION "1.4"
#define ENABLE_AUTOEXEC true

public Plugin myinfo =
{
	name = "Realish_Tank_Phyx",
	author = "Ludastar (Armonic), SilverShot, Dosergen",
	description = "Add's knockback to all attacks to survivor's from tanks",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2429846#post2429846"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{	
	EngineVersion iEngineVersion = GetEngineVersion();
	if (iEngineVersion == Engine_Left4Dead) 
	{
		ZOMBIECLASS_TANK = 5;
		g_bLeft4Dead2 = false;
	}
	else if (iEngineVersion == Engine_Left4Dead2) 
	{
		ZOMBIECLASS_TANK = 8;
		g_bLeft4Dead2 = true;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("Realish_Tank_Phyx", PLUGIN_VERSION, "Version of Realish_Tank_Phyxs", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_REPLICATED);
	
	hCvar_RockPhyx = CreateConVar("rtp_rock_phyx", "1", "Enable or Disable RockPhyx", FCVAR_NOTIFY);
	hCvar_IncapKnock = CreateConVar("rtp_incap_knock", "0", "Enable or Disable Incapped slap", FCVAR_NOTIFY);
	hCvar_PreIncap = CreateConVar("rtp_pre_incap", "1", "Enable or Disable Pre incapped flying", FCVAR_NOTIFY);
	hCvar_RockForce = CreateConVar("rtp_rock_force", "1.0", "Force of the rock, very high values send you flying very fast&far", FCVAR_NOTIFY);
	hCvar_PunchForce = CreateConVar("rtp_punch_force", "1.0", "Scales a Survivors velocity when punched by the Tank (_fling cvar 2) or sets the velocity (_fling cvar 1).", FCVAR_NOTIFY);
	hCvar_PunchForceZ = CreateConVar("rtp_punch_forcez", "100.0", "The vertical velocity a survivors is flung when punched by the Tank.", FCVAR_NOTIFY);
	hCvar_PunchFling = CreateConVar("rtp_punch_fling", "2", "The type of fling. 1: Fling with get up animation (L4D2 only). 2: Teleport player away from Tank.", FCVAR_NOTIFY);
	hCvar_PunchIncap = CreateConVar("rtp_punch_incap", "0.0", "Scales an Incapped Survivors velocity when punched by the Tank.", FCVAR_NOTIFY);
	
	CvarsChanged();

	hCvar_RockPhyx.AddChangeHook(eConvarChanged);
	hCvar_IncapKnock.AddChangeHook(eConvarChanged);
	hCvar_PreIncap.AddChangeHook(eConvarChanged);
	hCvar_RockForce.AddChangeHook(eConvarChanged);
	hCvar_PunchForce.AddChangeHook(eConvarChanged);
	hCvar_PunchFling.AddChangeHook(eConvarChanged);
	hCvar_PunchIncap.AddChangeHook(eConvarChanged);
	
	#if ENABLE_AUTOEXEC
	AutoExecConfig(true, "tank_phyx");
	#endif
}

public void eConvarChanged(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	CvarsChanged();
}

static void CvarsChanged()
{
	g_bRockPhyx = hCvar_RockPhyx.IntValue > 0;
	g_bIncapKnock = hCvar_IncapKnock.IntValue > 0;
	g_bPreIncap = hCvar_PreIncap.IntValue > 0;
	
	g_fRockForce = hCvar_RockForce.FloatValue;
	g_fPunchForce = hCvar_PunchForce.FloatValue;
	g_fPunchForceZ = hCvar_PunchForceZ.FloatValue;
	g_iPunchFling = hCvar_PunchFling.IntValue;
	g_fPunchIncap = hCvar_PunchIncap.FloatValue;
	
	if(!g_bRockPhyx && !g_bIncapKnock && !g_bPreIncap)
	{	
		g_bAllDisabled = true;
	}
	else
	{
		g_bAllDisabled = false;
	}
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamage, eOnTakeDamage);
}

public void OnClientDisconnect(int iClient)
{
	SDKUnhook(iClient, SDKHook_OnTakeDamage, eOnTakeDamage);
}

public Action eOnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamagetype)
{
	if(g_bAllDisabled)
		return Plugin_Continue;
	
	if(g_bAllowHurt)
		return Plugin_Continue;
	
	if(iAttacker < 1 || iAttacker > MaxClients || !IsClientInGame(iAttacker) || GetClientTeam(iAttacker) != 3 || GetEntProp(iAttacker, Prop_Send, "m_zombieClass") != ZOMBIECLASS_TANK)
		return Plugin_Continue;
	
	if(!IsSurvivorAlive(iVictim))
		return Plugin_Continue;
	
	char sWeapon[18];
	if(g_bRockPhyx)
	{
		GetEntityClassname(iInflictor, sWeapon, sizeof(sWeapon));
		if(sWeapon[0] == 't' && StrEqual(sWeapon, "tank_rock", false))
		{
			bHitByRock[iInflictor] = GetClientUserId(iVictim);
			iRockRef[iVictim] = EntIndexToEntRef(iInflictor);
			
			float fPos[3];
			GetEntPropVector(iVictim, Prop_Send, "m_vecOrigin", fPos);
			static Handle trace;
			trace = TR_TraceRayFilterEx(fPos, view_as<float>({270.0, 0.0, 0.0}), MASK_SHOT, RayType_Infinite, _TraceFilter);
			
			static float fEnd[3];
			TR_GetEndPosition(fEnd, trace); // retrieve our trace endpoint
			CloseHandle(trace);
			trace = null;
			
			static float fDist;
			fDist = GetVectorDistance(fPos, fEnd);
			
			if(fDist > 150.0)
			{
				fPos[2] += 40.0;
				TeleportEntity(iVictim, fPos, NULL_VECTOR, NULL_VECTOR);
			}
			else if(fDist > 125.0)
			{
				fPos[2] += 25.0;
				TeleportEntity(iVictim, fPos, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
	
	GetClientWeapon(iAttacker, sWeapon, sizeof(sWeapon)); // i do a classname check so it will work on l4d1 also
	if(StrContains(sWeapon, "tank_claw", false) == -1) // for l4d1 support also
	{
		return Plugin_Continue;
	}
	
	if(GetEntProp(iVictim, Prop_Send, "m_isIncapacitated", 1))
	{
		if(!g_bIncapKnock)
			return Plugin_Continue;
		
		static float fAngles[3];
		GetClientEyeAngles(iAttacker, fAngles);
		
		fAngles[0] = 340.0;
		SetEntityFlags(iVictim, GetEntityFlags(iVictim) & ~FL_ONGROUND);
		Entity_PushForce(iVictim, float(GetTankThrowForce()), fAngles, 0.0, false);
		return Plugin_Continue;
	}
	else
	{
		if(!g_bPreIncap)
			return Plugin_Continue;
	
		static int iDamage;
		iDamage = RoundFloat(fDamage);
		static int iHealth;
		iHealth = GetPlayerTempHealth(iVictim) + GetEntProp(iVictim, Prop_Send, "m_iHealth");
		
		if(iHealth > iDamage)
			return Plugin_Continue;
		
		DataPack hPack = new DataPack();
		hPack.WriteCell(GetClientUserId(iVictim));
		hPack.WriteCell(iDamage);
		hPack.WriteCell(iAttacker);
		
		RequestFrame(NextFrame, hPack);
		return Plugin_Handled;
	}
}

public void NextFrame(any hDataPack)
{
	DataPack hPack = hDataPack;
	hPack.Reset();
	static int iVictim;
	iVictim = GetClientOfUserId(hPack.ReadCell());
	
	if(!IsSurvivorAlive(iVictim))
	{
		delete hPack;
		return;
	}
	
	static int iDamage;
	iDamage = hPack.ReadCell();
	static int iAttacker;
	iAttacker = hPack.ReadCell();
	delete hPack;
	
	if(iAttacker < 1)
		iAttacker = 0;
		
	g_bAllowHurt = true;
	Entity_Hurt(iVictim, iDamage, iAttacker, DMG_VEHICLE); //we use point hurt here to prevent anybugs so we use the normal damage system instead
	g_bAllowHurt = false;// prevent endless loop with sdkhooks
	
}

public void OnEntityDestroyed(int iEntity)
{
	if(iEntity < MaxClients+1 || iEntity > 2048)
		return;
	
	static int iClient;
	iClient = GetClientOfUserId(bHitByRock[iEntity]);
	if(iClient < 1 || iClient > MaxClients)
		return;
	
	if(!IsValidEntRef(iRockRef[iClient]))
		return;
	
	static float fClient[3];
	GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", fClient);
	
	static float fRockPos[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fRockPos);
	
	static float fAngles[3];
	static float fAimVector[3];
	MakeVectorFromPoints(fRockPos, fClient, fAimVector);
	GetVectorAngles(fAimVector, fAngles);
	
	if(fAngles[0] < 270.0)
		fAngles[0] = 360.0;
	if(fAngles[0] < 340.0)
		fAngles[0] = 340.0;
	
	Entity_PushForce(iClient, g_fRockForce, fAngles, 0.0, false); //this does not seem to work in OnTakeDamage hook but works here quite strange
	bHitByRock[iEntity] = -1;
}

public void L4D_TankClaw_OnPlayerHit_Post(int tank, int claw, int player)
{
	OnTankClawHit(tank, player, false);
}

public void L4D_TankClaw_OnPlayerHit_PostHandled(int tank, int claw, int player)
{
	OnTankClawHit(tank, player, true);
}

void OnTankClawHit(int tank, int player, bool handled)
{
	if(g_bAllDisabled)
		return;

	if(GetClientTeam(player) == 2)
	{
		float vPos[3], vEnd[3];
		GetClientAbsOrigin(tank, vPos);
		GetClientAbsOrigin(player, vEnd);

		if(handled) // Stagger blocked by "Block Stumble From Tanks"
		{
			MakeVectorFromPoints(vPos, vEnd, vEnd);
			NormalizeVector(vEnd, vEnd);
			ScaleVector(vEnd, 200.0);
		}
		else 
		{
			GetEntPropVector(player, Prop_Data, "m_vecVelocity", vEnd);
		}

		if(GetEntProp(player, Prop_Send, "m_isIncapacitated", 1))
		{
			ScaleVector(vEnd, g_fPunchIncap);
			if(g_fPunchIncap)
			{
				vEnd[2] = g_fPunchForceZ;
			}
		}
		else
		{
			ScaleVector(vEnd, g_fPunchForce);
			vEnd[2] = g_fPunchForceZ;
		}

		if(g_bLeft4Dead2 && g_iPunchFling == 1 && GetEntProp(player, Prop_Send, "m_isIncapacitated") == 0)
		{	
			L4D2_CTerrorPlayer_Fling(player, tank, vEnd);
		}
		else
		{	
			TeleportEntity(player, NULL_VECTOR, NULL_VECTOR, vEnd);
		}
	}
}

static int IsSurvivorAlive(int iClient)
{
	if(iClient < 1 || iClient > MaxClients || !IsClientInGame(iClient) || GetClientTeam(iClient) != 2 || !IsPlayerAlive(iClient))
	{	
		return false;
	}
	
	return true;
}

static bool Entity_Hurt(int entity, int damage, int attacker = 0, int damageType = DMG_GENERIC, const char[] fakeClassName = "")
{
	static int point_hurt = INVALID_ENT_REFERENCE;
	
	if (point_hurt == INVALID_ENT_REFERENCE || !IsValidEntity(point_hurt)) 
	{
		point_hurt = EntIndexToEntRef(Entity_Create("point_hurt"));
		
		if (point_hurt == INVALID_ENT_REFERENCE) 
		{
			return false;
		}
		
		DispatchSpawn(point_hurt);
	}
	
	AcceptEntityInput(point_hurt, "TurnOn");
	SetEntProp(point_hurt, Prop_Data, "m_nDamage", damage);
	SetEntProp(point_hurt, Prop_Data, "m_bitsDamageType", damageType);
	Entity_PointHurtAtTarget(point_hurt, entity);
	
	if (fakeClassName[0] != '\0') 
	{
		Entity_SetClassName(point_hurt, fakeClassName);
	}
	
	AcceptEntityInput(point_hurt, "Hurt", attacker);
	AcceptEntityInput(point_hurt, "TurnOff");
	
	if (fakeClassName[0] != '\0') 
	{
		Entity_SetClassName(point_hurt, "point_hurt");
	}
	
	return true;
}

static int Entity_Create(const char[] className , int ForceEdictIndex = -1)
{
	if (ForceEdictIndex != -1 && IsValidEntity(ForceEdictIndex)) 
	{
		return INVALID_ENT_REFERENCE;
	}
	
	return CreateEntityByName(className, ForceEdictIndex);
}

static void Entity_PointHurtAtTarget(int entity, int target, const char[] name = "")
{
	char targetName[128];
	Entity_GetTargetName(entity, targetName, sizeof(targetName));
	
	if (name[0] == '\0') 
	{
		
		if (targetName[0] == '\0') 
		{
			// Let's generate our own name
			Format  (
					targetName,
					sizeof(targetName),
					"_smlib_Entity_PointHurtAtTarget:%d",
					target
					);
		}
	}
	else 
	{
		strcopy(targetName, sizeof(targetName), name);
	}
	
	DispatchKeyValue(entity, "DamageTarget", targetName);
	Entity_SetName(target, targetName);
}

static int Entity_SetName(int entity, const char[] name, any ...)
{
	char format[128];
	VFormat(format, sizeof(format), name, 3);
	
	return DispatchKeyValue(entity, "targetname", format);
}

static int Entity_GetTargetName(int entity, char[] buffer, int size)
{
	return GetEntPropString(entity, Prop_Data, "m_target", buffer, size);
}

static int Entity_SetClassName(int entity, const char[] className)
{
	return DispatchKeyValue(entity, "classname", className);
}

static int GetPlayerTempHealth(int client)
{
	static Handle painPillsDecayCvar = null;
	if (painPillsDecayCvar == null)
	{
		painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
		if (painPillsDecayCvar == null)
		{
			SetFailState("pain_pills_decay_rate not found.");
		}
	}
	
	static int tempHealth;
	tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(painPillsDecayCvar))) - 1;
	return tempHealth < 0 ? 0 : tempHealth;
}

static int GetTankThrowForce()
{
	static Handle hThrowForce = null;
	if (hThrowForce == null)
	{
		hThrowForce = FindConVar("z_tank_throw_force");
		if (hThrowForce == null)
		{
			SetFailState("z_tank_throw_force not found.");
		}
	}
	
	return GetConVarInt(hThrowForce);
}

public bool _TraceFilter(int iEntity, int contentsMask)
{
	char sClassName[11];
	GetEntityClassname(iEntity, sClassName, sizeof(sClassName));
	
	if(sClassName[0] != 'i' || !StrEqual(sClassName, "infected"))
	{
		return false;
	}
	else if(sClassName[0] != 'w' || !StrEqual(sClassName, "witch"))
	{
		return false;
	}
	else if(iEntity > 0 && iEntity <= MaxClients)
	{
		return false;
	}
	return true;
	
}

static void Entity_PushForce(int iEntity, float fForce, float fAngles[3], float fMax = 0.0, bool bAdd = false)
{
	static float fVelocity[3];
	
	fVelocity[0] = fForce * Cosine(DegToRad(fAngles[1])) * Cosine(DegToRad(fAngles[0]));
	fVelocity[1] = fForce * Sine(DegToRad(fAngles[1])) * Cosine(DegToRad(fAngles[0]));
	fVelocity[2] = fForce * Sine(DegToRad(fAngles[0]));
	
	GetAngleVectors(fAngles, fVelocity, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(fVelocity, fVelocity);
	ScaleVector(fVelocity, fForce);
	
	if(bAdd) 
	{
		static float fMainVelocity[3];
		GetEntPropVector(iEntity, Prop_Data, "m_vecAbsVelocity", fMainVelocity);
		
		fVelocity[0] += fMainVelocity[0];
		fVelocity[1] += fMainVelocity[1];
		fVelocity[2] += fMainVelocity[2];
	}
	
	if(fMax > 0.0)
	{
		fVelocity[0] = ((fVelocity[0] > fMax) ? fMax : fVelocity[0]);
		fVelocity[1] = ((fVelocity[1] > fMax) ? fMax : fVelocity[1]);
		fVelocity[2] = ((fVelocity[2] > fMax) ? fMax : fVelocity[2]);
	}
	
	TeleportEntity(iEntity, NULL_VECTOR, NULL_VECTOR, fVelocity);
}

static bool IsValidEntRef(int iEntRef)
{
	return (iEntRef != 0 && EntRefToEntIndex(iEntRef) != INVALID_ENT_REFERENCE);
}
