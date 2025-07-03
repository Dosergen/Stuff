#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.35.2"

UserMsg g_umSayText2;

ConVar g_hPluginEnable, g_hServerChange, g_hNameChange, g_hChatChange, g_hVocalGuard, g_hVocalDelay, g_hVocalMessages;
bool g_bPluginEnable, g_bLateLoad, g_bServerChange, g_bNameChange, g_bChatChange, g_bVocalGuard, g_bVocalMessages;
int g_iVocalDelay;

int g_iVocalSpamCount[MAXPLAYERS + 1];
float g_fLastVocalTime[MAXPLAYERS + 1];
float g_fVocalBlockTime[MAXPLAYERS + 1];

#define MAX_VOCAL_SPAM_COUNT 10
#define VOCAL_SPAM_BLOCK_DURATION 15.0

public Plugin myinfo = 
{
	name = "BeQuiet",
	author = "Sir",
	description = "Please be Quiet! Block unnecessary chat/announcement/vocalize.",
	version = PLUGIN_VERSION,
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework/blob/55bf7783ad22df54bc46f9fdf232fb08353afabc/addons/sourcemod/scripting/bequiet.sp"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead && test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	// ConVars initialization
	g_hPluginEnable = CreateConVar("bequiet_enable", "1", "Enable or disable the plugin functionality.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hServerChange = CreateConVar("bequiet_cvar_change_suppress", "1", "Control the suppression of server cvar change announcements.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hNameChange = CreateConVar("bequiet_name_change_player_suppress", "1", "Suppress announcements for player name changes, including spectators.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hChatChange = CreateConVar("bequiet_chatbox_cmd_suppress", "1", "Suppress chat commands starting with '!' or '/'.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hVocalGuard = CreateConVar("bequiet_vocalize_guard", "1", "Control the suppression of frequent vocalize commands.", FCVAR_NOTIFY, true, 0.0, true, 1.0);	
	g_hVocalDelay = CreateConVar("bequiet_vocalize_guard_delay", "3", "Delay before a player can issue another vocalize command.");
	g_hVocalMessages = CreateConVar("bequiet_vocalize_messages", "1", "Enable or disable vocalize messages for player.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	GetCvars();  // Retrieve ConVar values on startup

	// Hook ConVar change events
	g_hPluginEnable.AddChangeHook(ConVarChanged_Cvars);
	g_hServerChange.AddChangeHook(ConVarChanged_Cvars);
	g_hNameChange.AddChangeHook(ConVarChanged_Cvars);
	g_hChatChange.AddChangeHook(ConVarChanged_Cvars);
	g_hVocalGuard.AddChangeHook(ConVarChanged_Cvars);
	g_hVocalDelay.AddChangeHook(ConVarChanged_Cvars);
	g_hVocalMessages.AddChangeHook(ConVarChanged_Cvars);

	// Command listeners
	AddCommandListener(Say_TeamSay_Callback, "say");
	AddCommandListener(Say_TeamSay_Callback, "say_team");
	AddCommandListener(Vocal_Callback, "vocalize");

	// Hook user message for suppressing name changes
	g_umSayText2 = GetUserMessageId("SayText2");
	HookUserMessage(g_umSayText2, UserMessageHook, true);

	// Hook server event for cvar announcements
	HookEvent("server_cvar", evtServerConVar, EventHookMode_Pre);

	// Generate config file
	AutoExecConfig(true, "bequiet");

	if (g_bLateLoad) 
	{
		for (int i = 1; i <= MaxClients; i++) 
		{
			if (IsClientInGame(i))
				OnClientPutInServer(i);
		}
	}
}

public void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	// Re-fetch ConVar values when any ConVar is changed
	GetCvars();
}

public void GetCvars()
{
	// Store the values of ConVars into variables
	g_bPluginEnable = g_hPluginEnable.BoolValue;
	g_bServerChange = g_hServerChange.BoolValue;
	g_bNameChange = g_hNameChange.BoolValue;
	g_bChatChange = g_hChatChange.BoolValue;
	g_bVocalGuard = g_hVocalGuard.BoolValue;
	g_iVocalDelay = g_hVocalDelay.IntValue;
	g_bVocalMessages = g_hVocalMessages.BoolValue;
}

public void OnClientPutInServer(int client)
{
	// Reset vocal time for the new client
	g_iVocalSpamCount[client] = 0;
	g_fLastVocalTime[client] = 0.0;
	g_fVocalBlockTime[client] = 0.0;
}

public void OnClientDisconnect(int client)
{
	// Clear vocalize time for the client who disconnected
	g_iVocalSpamCount[client] = 0;
	g_fLastVocalTime[client] = 0.0;
	g_fVocalBlockTime[client] = 0.0;
}

Action Say_TeamSay_Callback(int client, const char[] command, int argc)
{
	if (!g_bPluginEnable || !g_bChatChange)
		return Plugin_Continue;  // If plugin or chat suppression is disabled, continue normally
	// Get the first argument of the command (the word being said)
	char sayWord[MAX_NAME_LENGTH];
	GetCmdArg(1, sayWord, sizeof(sayWord));
	// If the word starts with '!' or '/', suppress the chat
	if (sayWord[0] == '!' || sayWord[0] == '/')
		return Plugin_Handled;
	return Plugin_Continue;
}

Action Vocal_Callback(int client, const char[] command, int args)
{   
	if (!g_bPluginEnable || !g_bVocalGuard)
		return Plugin_Continue;
	// Check if the argument matches "auto", allow it to proceed
	char sArg[32];
	GetCmdArg(2, sArg, sizeof(sArg));
	if (!strcmp(sArg, "auto"))
		return Plugin_Continue;
	float currentTime = GetEngineTime();
	if (g_fVocalBlockTime[client] > currentTime)
	{
		float blockTimeLeft = g_fVocalBlockTime[client] - currentTime;
		if (g_bVocalMessages)
			PrintToChat(client, "\x04[SM] \x01You are temporarily blocked from using vocalize due to spamming. Please wait %.1f seconds.", blockTimeLeft);
		return Plugin_Handled;
	}
	float timeSinceLastVocal = currentTime - g_fLastVocalTime[client];
	// Handle delay between vocalizations
	if (timeSinceLastVocal < g_iVocalDelay)
	{
		int iTimeLeft = RoundToNearest(g_iVocalDelay - timeSinceLastVocal);
		if (g_bVocalMessages)
			PrintToChat(client, "\x04[SM] \x01Wait \x03%d\x01 seconds before vocalizing", iTimeLeft);
		return Plugin_Handled;
	}
	g_fLastVocalTime[client] = currentTime;
	// Reset the spam count after the block duration
	if (timeSinceLastVocal > VOCAL_SPAM_BLOCK_DURATION)
		g_iVocalSpamCount[client] = 0;
	// Check if the player has exceeded the maximum allowed vocalizations
	if (g_iVocalSpamCount[client] >= MAX_VOCAL_SPAM_COUNT)
	{
		g_fVocalBlockTime[client] = currentTime + VOCAL_SPAM_BLOCK_DURATION;
		if (g_bVocalMessages)
			PrintToChat(client, "\x04[SM] \x01You have been blocked from vocalizing for %.1f seconds due to spamming.", VOCAL_SPAM_BLOCK_DURATION);
		return Plugin_Handled;
	}
	// Increment the vocal spam count
	g_iVocalSpamCount[client]++;
	return Plugin_Continue;
}

Action evtServerConVar(Event event, const char[] name, bool dontBroadcast) 
{
	if (!g_bPluginEnable || !g_bServerChange)
		return Plugin_Continue;
	// Block server cvar announcements if configured to do so
	if (!dontBroadcast)
		SetEventBroadcast(event, true);
	return Plugin_Continue;
}

public Action UserMessageHook(UserMsg msg_hd, Handle bf, const int[] players, int playersNum, bool reliable, bool init)
{
	if (!g_bPluginEnable || !g_bNameChange)
		return Plugin_Continue;
	// Read the message and check for "Cstrike_Name_Change"
	char sMessage[96];
	BfReadByte(bf);
	BfReadByte(bf);
	BfReadString(bf, sMessage, sizeof(sMessage), true);
	// If the message contains "Cstrike_Name_Change", suppress it
	if (StrContains(sMessage, "Cstrike_Name_Change") != -1)
		return Plugin_Handled;
	return Plugin_Continue;
}