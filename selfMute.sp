#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <adminmenu>
#include <voiceannounce_ex>

#define PLUGIN_VERSION "1.5.3"
#define CVAR_FLAGS	FCVAR_NOTIFY

#define BOTS true // false == debugging with bots

bool MuteStatus[MAXPLAYERS+1][MAXPLAYERS+1];
char clientNames[MAXPLAYERS+1][MAX_NAME_LENGTH];

float clientTalkTime[MAXPLAYERS+1] = { 0.0, ... };
ConVar	sm_selfmute_admin, sm_selfmute_talk_seconds, sm_selfmute_spam_mutes, sv_alltalk;
bool LibraryError;

public Plugin myinfo = 
{
	name = "Self-Mute Intelligence",
	author = "Otokiru, edit 93x, Accelerator, IT-KiLLER, Dosergen",
	description = "Self Mute Player Voice",
	version = PLUGIN_VERSION,
	url = "www.xose.net"
}

public void OnPluginStart() 
{   
	LoadTranslations("common.phrases");
	RegConsoleCmd("sm_mu", selfMute, "Mute player by typing !mu <name>");
	RegConsoleCmd("sm_um", selfUnmute, "Unmute player by typing !um <name>");
	CreateConVar("sm_selfmute_version", PLUGIN_VERSION, "Version of Self-Mute Intelligence Plugin", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	sm_selfmute_admin = CreateConVar("sm_selfmute_admin", "0.0", "Admin can not be muted. Disabled by default", CVAR_FLAGS, true, 0.0, true, 1.0);
	sm_selfmute_talk_seconds = CreateConVar("sm_selfmute_talk_seconds", "45.0", "List clients who have recently spoken within x secounds", CVAR_FLAGS, true, 1.0, true, 180.0);
	sm_selfmute_spam_mutes = CreateConVar("sm_selfmute_spam_mutes", "4.0", "How many mutes a client needs to get listed as spammer.", CVAR_FLAGS, true, 1.0, true, 64.0);
}

public void OnAllPluginsLoaded()
{
	sv_alltalk = FindConVar("sv_alltalk");

	// Checking the libraries
	if ((LibraryError = !LibraryExists("voiceannounce_ex")))
	{
		SetFailState("An error has occurred with 'voiceannounce_ex'. The plugin is disabled.");
	}
	if ((LibraryError = !LibraryExists("dhooks")))
	{
		SetFailState("An error has occurred with 'dhooks'. The plugin is disabled.");
	}
}

public void OnPluginEnd()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		for (int target = 1; target <= MaxClients; target++)
		{
			if (IsClientInGame(client) && IsClientInGame(target))
			{
				SetListenOverride(client, target, Listen_Default);
			}
		}
	}
}

public void OnMapStart()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		clientTalkTime[client] = 0.0;
	}
}

public void OnClientDisconnect(int client)
{
	clientTalkTime[client] = 0.0;
}

public void OnClientPutInServer(int client)
{
	for (int target = 1; target <= MaxClients; target++)
	{
		MuteStatus[target][client] = false;
		if (target != client)
		{
			if (IsClientInGame(target))
			{
				SetListenOverride(target, client, Listen_Default);
			}
		}
	}
}

public void OnClientSpeakingEx(int client)
{
	if (GetClientListeningFlags(client) == VOICE_MUTED) return;
	clientTalkTime[client] = GetGameTime();
}

public void OnClientSpeakingEnd(int client)
{
	if (GetClientListeningFlags(client) == VOICE_MUTED) return;
	clientTalkTime[client] = GetGameTime();
}

public Action selfMute(int client, int args)
{
	if (!client) return Plugin_Handled;
	
	if (LibraryError)
	{
		PrintToChat(client, "\x04[MUTE]\x01 An error has occurred with the libraries. The plugin is disabled.");
		return Plugin_Handled;
	}

	if (args < 1) 
	{
		DisplayMuteMenu(client);
		return Plugin_Handled;
	}
	
	char strTarget[MAX_NAME_LENGTH];
	GetCmdArg(1, strTarget, sizeof(strTarget)); 

	if (StrEqual(strTarget, "@me"))
	{
		PrintToChat(client, "\x04[MUTE]\x01 You can not mute yourself.");
		return Plugin_Handled; 
	}
	
	char strTargetName[MAX_TARGET_LENGTH]; 
	int TargetList[MAXPLAYERS], TargetCount; 
	bool TargetTranslate; 
	
	if ((TargetCount = ProcessTargetString(strTarget, 0, TargetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED /*| COMMAND_FILTER_NO_BOTS*/ , strTargetName, sizeof(strTargetName), TargetTranslate)) <= 0) 
	{
		ReplyToTargetError(client, TargetCount); 
		return Plugin_Handled; 
	}

	muteTargetedPlayers(client, TargetList, TargetCount, strTarget);
	return Plugin_Handled;
}

void DisplayMuteMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_MuteMenu);
	menu.SetTitle("Mute Intelligence");
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	float gametime = GetGameTime();

	// Lised clients
	bool clientAlreadyListed[MAXPLAYERS+1] = {false,...}; 

	// Excluding client from the menu.
	clientAlreadyListed[client] = true; 
	
	// Sort array
	int clientSortRecentlyTalked[MAXPLAYERS+1] = {0,1,...}; 

	char strClientID[12];
	char strClientName[50];
	bool loop = true;
	int myindex = 0;
	int temp = 0;

	for (int target = 1; target <= MaxClients; target++)
	{	
		if (IsClientInGame(target) ? (!sv_alltalk.BoolValue && !VoiceTeam(client, target) || (BOTS && IsFakeClient(target)) ) : false) 
		{
			clientAlreadyListed[target] = true; // BOT or not in voiceteam
		}
	}

	// Sorts who have recently spoken 
	while (loop) 
	{
		loop = false;
		myindex++;
		for (int i = 1; i < MaxClients - myindex; i++) 
		{
			int target1 = clientSortRecentlyTalked[i];
			int target2 = clientSortRecentlyTalked[i + 1];
			if (clientTalkTime[target1] < clientTalkTime[target2]) 
			{
				temp = clientSortRecentlyTalked[target1];
				clientSortRecentlyTalked[target1] = clientSortRecentlyTalked[target2];
				clientSortRecentlyTalked[target2] = temp;
				loop = true;
			}
		}
	}

	// Players who speak now or have just done it. Adds these to the menu.
	for (int i = 0; i <= MaxClients; i++)
	{
		int target = clientSortRecentlyTalked[i];
		if (target != 0 && (IsClientInGame(target) && !clientAlreadyListed[target] && !MuteStatus[client][target] && clientTalkTime[target]!=0 && (clientTalkTime[target]+sm_selfmute_talk_seconds.FloatValue) > gametime))
		{
			clientAlreadyListed[target] = true;
			IntToString(GetClientUserId(target), strClientID, sizeof(strClientID));
			if (gametime == clientTalkTime[target]) // Speaking now
			{
				FormatEx(strClientName, sizeof(strClientName), "%N (Speaking + %dM)", target, targetMutes(target,true));
			} else {
				FormatEx(strClientName, sizeof(strClientName), "%N (%1.fs + %dM)", target, gametime-clientTalkTime[target], targetMutes(target,true));
			}
			menu.AddItem(strClientID, strClientName);
		}
	}

	// Provides suggestions for clients to mute based on other clients choices.
	for (int target = 1; target <= MaxClients; target++)
	{
		if (IsClientInGame(target) && !clientAlreadyListed[target] && targetMutes(target, true) >= sm_selfmute_spam_mutes.IntValue && !MuteStatus[client][target]) 
		{
			clientAlreadyListed[target] = true;
			IntToString(GetClientUserId(target), strClientID, sizeof(strClientID));
			FormatEx(strClientName, sizeof(strClientName), "%N (SPAM %dM)", target, targetMutes(target, true));
			menu.AddItem(strClientID, strClientName);
		}
	}

	int[] alphabetClients = new int[MaxClients+1];

	// Alphabetical sorting of clients
	for (int aClient = 1; aClient <= MaxClients; aClient++)
	{
		if (IsClientInGame(aClient) && !clientAlreadyListed[aClient])
		{
			alphabetClients[aClient] = aClient;
			GetClientName(alphabetClients[aClient], clientNames[alphabetClients[aClient]], sizeof(clientNames[]));
		}
	}

	SortCustom1D(alphabetClients, MaxClients, SortByPlayerName);
	
	for (int i = 0; i < MaxClients; i++)
	{
		if (alphabetClients[i]!=0 && !clientAlreadyListed[alphabetClients[i]] && !MuteStatus[client][alphabetClients[i]]) 
		{
			IntToString(GetClientUserId(alphabetClients[i]), strClientID, sizeof(strClientID));
			FormatEx(strClientName, sizeof(strClientName), "%N", alphabetClients[i]);
			menu.AddItem(strClientID, strClientName);
		}
	}

	if (menu.ItemCount == 0) 
	{
		PrintToChat(client, "\x04[MUTE]\x01 Could not list any comrades \x04(Already have muted \x05%d\x04)", clientMutes(client));
		delete menu;
	} else {
		menu.ExitBackButton = (menu.ItemCount > 7);
		menu.Display(client, MENU_TIME_FOREVER);
	}
}


public int MenuHandler_MuteMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char info[32];
			int target;
			
			menu.GetItem(param2, info, sizeof(info));
			int userid = StringToInt(info);
			
			if ((target = GetClientOfUserId(userid)) == 0)
			{
				PrintToChat(param1, "\x04[MUTE]\x01 Comrade no longer available");
			}
			else
			{
				// This will be improved in a later update
				int temp[1];
				temp[0] = target;
				muteTargetedPlayers(param1, temp, 1, "");
			}
		}
	}
	return 0;
}

void muteTargetedPlayers(int client, int[] list, int TargetCount, const char[] filtername)
{
	if (TargetCount == 1)
	{
		int target = list[0];
		if (client == target)
		{
			PrintToChat(client, "\x04[MUTE]\x01 You can not mute yourself.");
			return;
		}
		if (sm_selfmute_admin.BoolValue && IsPlayerAdmin(target))
		{
			PrintToChat(client, "\x04[MUTE]\x01 You can not mute an admin: \x04%N", target);
			return;
		}
		if (VoiceTeam(client, target) || (BOTS && IsFakeClient(target)) ) 
		{
			PrintToChat(client, "\x04[MUTE]\x01 The client could not be muted: \x04%N", target);
			return;
		}
		SetListenOverride(client, target, Listen_No);
 
		PrintToChat(client, "\x04[MUTE]\x01 You have muted: \x04%N", target);
		MuteStatus[client][target] = true;

	} 
	else if (TargetCount > 1)
	{
		char textNames[250];
		int textSize = 0, countTargets = 0;
		int target;
		for (int i = 0; i < TargetCount; i++) 
		{	
			target = list[i];
			if (target == client || MuteStatus[client][target] || (sm_selfmute_admin.BoolValue && IsPlayerAdmin(target)) || !sv_alltalk.BoolValue && !VoiceTeam(client, target) || (BOTS && IsFakeClient(target)) ) continue;
			countTargets++;
			MuteStatus[client][target] = true;
			SetListenOverride(client, target, Listen_No);
			FormatEx(textNames, sizeof(textNames), "%s%s%N", textNames, countTargets==1 ? "" : ", ",  target);
			textSize = strlen(textNames) - textSize;
		}
		if (countTargets > 0) 
		{
			PrintToChat(client, "\x04[MUTE]\x01 You have muted(%d)\x04: %s", countTargets , (textSize <= sizeof(textNames) && countTargets <= 14 ) ? textNames : getFilterName(filtername));
		}
		else
		{
			PrintToChat(client, "\x04[MUTE]\x01 Everyone in the list was already muted.");
		}
	}
}

void unMuteTargetedPlayers(int client, int[] list, int TargetCount, const char[] filtername)
{
	if (TargetCount == 1)
	{
		int target = list[0];
		if (client == target)
		{
			PrintToChat(client, "\x04[MUTE]\x01 You can not unmute yourself.");
			return;
		}
		SetListenOverride(client, target, Listen_Default);
		PrintToChat(client, "\x04[MUTE]\x01 You have unmuted: \x04%N", target);
		MuteStatus[client][target] = false;
	} 
	else if (TargetCount > 1)
	{
		char textNames[250];
		int textSize = 0, countTargets = 0;
		int target;
		for (int i = 0; i < TargetCount; i++) 
		{
			target = list[i];
			if (target == client || !MuteStatus[client][target] || (sm_selfmute_admin.BoolValue && IsPlayerAdmin(target))) continue;
			countTargets++;
			SetListenOverride(client, target, Listen_Default);
			MuteStatus[client][target] = false;
			FormatEx(textNames, sizeof(textNames), "%s%s%N", textNames, countTargets==1 ? "" : ", ", target);
			textSize = strlen(textNames) - textSize;
		}
		if (countTargets > 0) 
		{
			PrintToChat(client, "\x04[MUTE]\x01 You have unmuted(%d)\x04: %s", countTargets , (textSize <= sizeof(textNames) && countTargets <= 14 ) ? textNames : getFilterName(filtername));
		}
		else
		{
			PrintToChat(client, "\x04[MUTE]\x01 Everyone in the list was already unmuted.");
		}
	}
}

public Action selfUnmute(int client, int args)
{
	if (!client) return Plugin_Handled;
	
	if (LibraryError)
	{
		PrintToChat(client, "\x04[MUTE]\x01 An error has occurred with the libraries. The plugin is disabled.");
		return Plugin_Handled;
	}

	if (args < 1) 
	{
		DisplayUnMuteMenu(client);
		return Plugin_Handled;
	}
	
	char strTarget[MAX_NAME_LENGTH];
	GetCmdArg(1, strTarget, sizeof(strTarget)); 
	
	char strTargetName[MAX_TARGET_LENGTH]; 
	int TargetList[MAXPLAYERS], TargetCount; 
	bool TargetTranslate; 
	
	if (StrEqual(strTarget, "@me"))
	{
		PrintToChat(client, "\x04[MUTE]\x01 You can not unmute yourself.");
		return Plugin_Handled; 
	}

	if ((TargetCount = ProcessTargetString(strTarget, 0, TargetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED /*| COMMAND_FILTER_NO_BOTS*/, strTargetName, sizeof(strTargetName), TargetTranslate)) <= 0) 
	{
		ReplyToTargetError(client, TargetCount); 
		return Plugin_Handled; 
	}

	unMuteTargetedPlayers(client, TargetList, TargetCount, strTarget);
	return Plugin_Handled;
}

void DisplayUnMuteMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_UnMuteMenu);
	menu.SetTitle("UnMute Intelligence");
	char strClientID[12];
	char strClientName[50];
	
	for (int target = 1; target <= MaxClients; target++)
	{
		if (client != target && IsClientInGame(target) && MuteStatus[client][target]) 
		{
			IntToString(GetClientUserId(target), strClientID, sizeof(strClientID));
			FormatEx(strClientName, sizeof(strClientName), "%N (M)", target);
			menu.AddItem(strClientID, strClientName);
		}
	}

	if (menu.ItemCount == 0) 
	{
		PrintToChat(client, "\x04[MUTE]\x01 No comrades are muted.");
		delete menu;
	}
	else
	{
		menu.ExitBackButton = (menu.ItemCount > 7);
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int MenuHandler_UnMuteMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char info[32];
			int target;
			
			menu.GetItem(param2, info, sizeof(info));
			int userid = StringToInt(info);
			
			if ((target = GetClientOfUserId(userid)) == 0)
			{
				PrintToChat(param1, "\x04[MUTE]\x01 Comrade no longer available");
			}
			else
			{
				// This will be improved in a later update
				int temp[1];
				temp[0] = target;
				unMuteTargetedPlayers(param1, temp, 1, "");
			}
		}
	}
	return 0;
}

// Checking if a client is admin
bool IsPlayerAdmin(int client)
{
	if (CheckCommandAccess(client, "Kick_admin", ADMFLAG_KICK, false))
	{
		return true;
	}
	return false;
}

bool VoiceTeam(int client, int target)
{
	if (!sv_alltalk.BoolValue)
	{
		if (GetClientTeam(client) == GetClientTeam(target))
		{
			return true;
		}
	}
	return false;
}

int SortByPlayerName(int player1, int player2, const int[] array, Handle hndl)
{
	return strcmp(clientNames[player1], clientNames[player2], false);
}

// Counting how many mutes a client has done.
int clientMutes(int client)
{
	int count = 0;
	for (int target = 1; target <= MaxClients ; target++)
	{
		if (MuteStatus[client][target]) 
		{
			count++;
		}
	}
	return count;
}

// Counting how many mutes a target has received.
int targetMutes(int target, bool massivemute = false)
{
	int count = 0;
	int mutes = 0;
	for (int client = 1; client <= MaxClients ; client++)
	{
		if (MuteStatus[client][target] && (massivemute && (mutes=clientMutes(client)) > 0 && mutes <= (MaxClients/2))) 
		{
			count++;
		}
	}
	return count;
}

stock char getFilterName(const char[] filter)
{
	// This will be improved in a later update
	char temp[30];
	if (StrEqual(filter, "@all"))
	{
		temp = "Everyone";
	} 
	else if (StrEqual(filter, "@spec"))
	{
		temp = "Spectators";
	}
	else if (StrEqual(filter, "@dead"))
	{
		temp = "Dead players";
	}
	else if (StrEqual(filter, "@alive"))
	{
		temp = "Alive players";
	}
	else if (StrEqual(filter, "@!me"))
	{
		temp = "Everyone except me";
	}
	else if (StrEqual(filter, "@admins"))
	{
		temp = "Admins";
	} 
	else 
	{
		FormatEx(temp, sizeof(temp), "%s", filter);
	}
	return temp;
}