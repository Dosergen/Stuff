#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

ConVar g_cAllowRootAdmin;
Handle g_hClientPrintf;

char g_sLogs[PLATFORM_MAX_PATH + 1];

public Plugin myinfo =
{
	name = "[DHooks] Block SM Plugins",
	description = "",
	author = "Bara",
	version = "1.0.1",
	url = "https://github.com/Bara"
}

public void OnPluginStart()
{
	g_cAllowRootAdmin = CreateConVar("sbp_allow_rootadmin", "1", "Allow root admins to access all commands?", _, true, 0.0, true, 1.0);
	Handle gameconf = LoadGameConfigFile("sbp.games");
	if (gameconf == null)
	{
		SetFailState("Failed to find sbp.games.txt gamedata");
		delete gameconf;
	}
	int offset = GameConfGetOffset(gameconf, "ClientPrintf");
	if (offset == -1)
	{
		SetFailState("Failed to find offset for ClientPrintf");
		delete gameconf;
	}
	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(gameconf, SDKConf_Signature, "CreateInterface"))
	{
		SetFailState("Failed to get CreateInterface");
		delete gameconf;
	}
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	char identifier[64];
	if (!GameConfGetKeyValue(gameconf, "EngineInterface", identifier, sizeof(identifier)))
	{
		SetFailState("Failed to get engine identifier name");
		delete gameconf;
	}
	Handle temp = EndPrepSDKCall();
	Address addr = SDKCall(temp, identifier, 0);
	delete gameconf;
	delete temp;
	if (!addr)
	{
		SetFailState("Failed to get engine ptr");
	}
	g_hClientPrintf = DHookCreate(offset, HookType_Raw, ReturnType_Void, ThisPointer_Ignore, Hook_ClientPrintf);
	DHookAddParam(g_hClientPrintf, HookParamType_Edict);
	DHookAddParam(g_hClientPrintf, HookParamType_CharPtr);
	DHookRaw(g_hClientPrintf, false, addr);
	char sDate[18];
	FormatTime(sDate, sizeof(sDate), "%y-%m-%d");
	BuildPath(Path_SM, g_sLogs, sizeof(g_sLogs), "logs/sbp-%s.log", sDate);
}

public MRESReturn Hook_ClientPrintf(Handle hParams)
{
	char sBuffer[1024];
	int client = DHookGetParam(hParams, 1);
	if (client == 0)
	{
		return MRES_Ignored;
	}
	if (g_cAllowRootAdmin.BoolValue && CheckCommandAccess(client, "sbp_admin", ADMFLAG_ROOT, true))
	{
		return MRES_Ignored;
	}
	DHookGetParamString(hParams, 2, sBuffer, sizeof(sBuffer));
	if (sBuffer[1] == '"' && (StrContains(sBuffer, "\" (") != -1 || (StrContains(sBuffer, ".smx\" ") != -1))) 
	{
		DHookSetParamString(hParams, 2, "");
		return MRES_ChangedHandled;
	}
	else if ((StrContains(sBuffer, "To see more, type \"sm plugins") != -1) || (StrContains(sBuffer, "To see more, type \"sm exts") != -1))
	{
		if (client > 0 && IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client))
		{
			if (CheckCommandAccess(client, "sm_admin", ADMFLAG_ROOT, true))
			{
				return MRES_Ignored;
			}
			LogToFile(g_sLogs, "\"%L\" tried to get the plugin list", client);
		}
		return MRES_ChangedHandled;
	}
	return MRES_Ignored;
}