#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "1.1.0"

ConVar g_hSteamGroupCvar;

public Plugin myinfo = 
{
	name        = "sv_steamgroup fixer",
	author      = "asherkin",
	description = "VAAAAAAAAAAALVE",
	version     = "1.1.0",
	url         = "https://limetech.io/"
}

public void OnPluginStart()
{
	CreateConVar("sv_steamgroup_fixer_version", PLUGIN_VERSION, "Version of \"sv_steamgroup fixer\" plugin", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_hSteamGroupCvar = FindConVar("sv_steamgroup");
	if (!g_hSteamGroupCvar) 
	{
		LogMessage("Failed to find sv_steamgroup, creating fake version for testing.");
		g_hSteamGroupCvar = CreateConVar("sv_steamgroup", "0", "Fake sv_steamgroup for testing \"sv_steamgroup fixer\" plugin");
	}
	g_hSteamGroupCvar.AddChangeHook(OnSteamGroupChanged);
}

public void OnConfigsExecuted()
{
	FixSteamGroupId();
}

public void OnSteamGroupChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	FixSteamGroupId();
}

void FixSteamGroupId()
{
	int oldIntValue = g_hSteamGroupCvar.IntValue;
	char stringValue[128];
	g_hSteamGroupCvar.GetString(stringValue, sizeof(stringValue));
	int intValue = StringToInt(stringValue);
	if (intValue != oldIntValue) 
	{
		g_hSteamGroupCvar.IntValue = intValue;
		LogMessage("Corrected sv_steamgroup (\"%s\") from %d to %d.", stringValue, oldIntValue, intValue);
	}
}