/**
 * [L4D/2] Crowned Horde
 * Created by Bigbuck
 *
 */

/**
	v1.0.0
	- Initial Release

	v1.0.1
	- Added translation support
	- Added option to set what event(s) trigger the horde

	v1.0.2
	- Added seperate CVAR's to control trigger events

	v1.0.3
	- Added option to randomly alert the horde

	v1.0.4
	- Added option to set delay between witches scream and the horde being alerted
	- Added option to set the size of the alerted horde
	- Added option to randomly set the size of the alerted horde
	- Added option to alert the horde when the witch has been killed but not crowned
	- Fixed potential bug in the random logic

	v1.0.5
	- Fixed bug with AlertHorde timers

	v1.0.6
	- Removed redundant cvar, l4d_ch_trigger_killed_not_crowned
	- Removed sm_ from cvar's to comply with guidelines

	v1.0.7
	- Fixed bug in random logic that always ran the random code
	- Fixed invalid client bug
	
	v1.0.8
	- Converted plugin source to the latest syntax utilizing methodmaps
 */

// Force strict semicolon mode
#pragma semicolon 1
#pragma newdecls required

/**
 * Includes
 *
 */
#include <sourcemod>
#include <sdktools>

/**
 * Defines
 *
 */
#define PLUGIN_VERSION	"1.0.8"

/**
 * Handles
 *
 */
ConVar  g_hCvarSound, g_hCvarSound_File, g_hCvarAnnouncements, g_hCvarTrigger_Annoyed, 
        g_hCvarTrigger_Annoyed_First, g_hCvarTrigger_Killed, g_hCvarTrigger_Killed_Crowned, g_hCvarTrigger_Random, 
        g_hCvarTrigger_Random_Alert_Horde, g_hCvarTrigger_Random_Horde_Size, g_hCvarTrigger_Horde_Size, g_hCvarTrigger_Delay;
bool    g_bLeft4Dead2, g_bSound, g_bAnnouncements, g_bTrigger_Annoyed, g_bTrigger_Annoyed_First, g_bTrigger_Killed, 
        g_bTrigger_Killed_Crowned, g_bTrigger_Random, g_bTrigger_Random_Alert_Horde, g_bTrigger_Random_Horde_Size, g_bTrigger_Horde_Size;
float   g_fTrigger_Delay;
char    g_sWitch[128];
	
// Timer handles
Handle Timer_AlertHorde[MAXPLAYERS + 1];

/**
 * Global variables
 *
 */
// Lets us know if we need to trigger the horde
bool alert_horde = true;
// Determines the size of the horde
int horde_size = 0;

/**
 * Plugin information
 *
 */
public Plugin  myinfo =
{
	name = "[L4D/2] Crowned Horde",
	author = "Bigbuck, Dosergen",
	description = "Sends out a horde when a witched has been killed.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=111958"
}

/**
 * Setup plugins first run
 *
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test == Engine_Left4Dead2)
	{
		g_bLeft4Dead2 = true;
		return APLRes_Success;
	}
	else if (test == Engine_Left4Dead)
	{
		g_bLeft4Dead2 = false;
		return APLRes_Success;
	}
	strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
	return APLRes_SilentFailure;
}

public void OnPluginStart()
{
	// Create convars
	g_hCvarSound                              = CreateConVar("l4d_ch_sound", "1", "Play a sound when the trigger event has been activated?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarSound_File                         = CreateConVar("l4d_ch_sound_file", "npc/witch/voice/attack/Female_DistantScream2.wav", "If sound is enabled, the sound file to play relative to the sounds directory.", FCVAR_NOTIFY);
	g_hCvarAnnouncements                      = CreateConVar("l4d_ch_announcements", "1", "Enable or disable announcements.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarTrigger_Annoyed                    = CreateConVar("l4d_ch_trigger_annoyed", "0", "Alerts the horde when a witch is annoyed.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	if (g_bLeft4Dead2)
		g_hCvarTrigger_Annoyed_First          = CreateConVar("l4d_ch_trigger_annoyed_first", "0", "Alerts the horde when a witch is annoyed for the first time only (L4D2 only).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarTrigger_Killed                     = CreateConVar("l4d_ch_trigger_killed", "0", "Alerts the horde when a witch is killed.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarTrigger_Killed_Crowned             = CreateConVar("l4d_ch_trigger_killed_crowned", "0", "Alerts the horde when a witch is crowned.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarTrigger_Random                     = CreateConVar("l4d_ch_trigger_random", "1", "Randomly picks which event alerts the horde.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarTrigger_Random_Alert_Horde         = CreateConVar("l4d_ch_trigger_random_alert_horde", "0", "If random option is selected, randomly decide if a horde should be alerted.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarTrigger_Random_Horde_Size          = CreateConVar("l4d_ch_trigger_random_horde_size", "0", "If random option is selected, randomly decide what size horde should be alerted.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarTrigger_Horde_Size                 = CreateConVar("l4d_ch_trigger_horde_size", "0", "Size of the alerted horde (0 = mob, 1 = forced panic).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarTrigger_Delay                      = CreateConVar("l4d_ch_trigger_delay", "0", "The delay between the witches scream and the horde being alerted.", FCVAR_NOTIFY, true, 0.0);
	CreateConVar("l4d_crowned_horde_version", PLUGIN_VERSION, "[L4D/2] Crowned Horde Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	GetCvars();
	g_hCvarSound.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSound_File.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarAnnouncements.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTrigger_Annoyed.AddChangeHook(ConVarChanged_Cvars);
	if (g_bLeft4Dead2)
		g_hCvarTrigger_Annoyed_First.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTrigger_Killed.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTrigger_Killed_Crowned.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTrigger_Random.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTrigger_Random_Alert_Horde.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTrigger_Random_Horde_Size.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTrigger_Horde_Size.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTrigger_Delay.AddChangeHook(ConVarChanged_Cvars);
	
	// Hook events
	HookEvent("witch_harasser_set", Event_WitchHarasserSet);
	HookEvent("witch_spawn",        Event_WitchSpawn);
	HookEvent("witch_killed",       Event_WitchKilled);

	// Load config
	AutoExecConfig(true, "l4d_crowned_horde");
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bSound = g_hCvarSound.BoolValue;
	g_hCvarSound_File.GetString(g_sWitch, sizeof(g_sWitch));
	g_bAnnouncements = g_hCvarAnnouncements.BoolValue;
	g_bTrigger_Annoyed = g_hCvarTrigger_Annoyed.BoolValue;
	if (g_bLeft4Dead2)
		g_bTrigger_Annoyed_First = g_hCvarTrigger_Annoyed_First.BoolValue;
	g_bTrigger_Killed = g_hCvarTrigger_Killed.BoolValue;
	g_bTrigger_Killed_Crowned = g_hCvarTrigger_Killed_Crowned.BoolValue;
	g_bTrigger_Random = g_hCvarTrigger_Random.BoolValue;
	g_bTrigger_Random_Alert_Horde = g_hCvarTrigger_Random_Alert_Horde.BoolValue;
	g_bTrigger_Random_Horde_Size = g_hCvarTrigger_Random_Horde_Size.BoolValue;
	g_bTrigger_Horde_Size = g_hCvarTrigger_Horde_Size.BoolValue;
	g_fTrigger_Delay = g_hCvarTrigger_Delay.FloatValue;
}

/**
 * Called when the map starts
 *
 */
public void OnMapStart()
{
	// Precache sound
	PrecacheSound(g_sWitch, true);
}

public void OnMapEnd()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        delete Timer_AlertHorde[i];
    }
}

/**
 * Handles when a witch becomes annoyed
 *
 * @handle: event - The witch_harasser_set event
 * @string: name - Name of the event
 * @bool: dontBroadcast - Enable/disable broadcasting of event triggering
 *
 */
void Event_WitchHarasserSet(Event event, const char[] name , bool dontBroadcast)
{
	// Make sure we can continue
	if (!g_bTrigger_Annoyed && !g_bTrigger_Annoyed_First)
	{
		return;
	}
	// Get event information
	int attacker_id	= event.GetInt("userid");
	int witch_id = event.GetInt("witchid");
	// Get the correct client id
	int attacker = GetClientOfUserId(attacker_id);
	if (!IsValidClient(attacker))
	{
		return;
	}
	// If this is the first time the witch has been annoyed
	if (g_bTrigger_Annoyed_First)
	{
		if (g_bLeft4Dead2)
		{
			bool annoyed_first = event.GetBool("first");
			if (annoyed_first)
			{
				WitchAnnoyedFirst(attacker, witch_id);
			}
		}
		return;
	}
	else if (!g_bTrigger_Annoyed)
	{
		return;
	}
	// Play sound if needed
	if (g_bSound)
	{
		PlaySound(witch_id);
	}
	// Trigger the horde
	if (alert_horde)
	{
		Timer_AlertHorde[attacker] = CreateTimer(g_fTrigger_Delay, AlertHorde, attacker);
	}
	// Announce who woke up the witch if needed
	if (g_bAnnouncements)
	{
		PrintToChatAll("\x04[Crowned Horde] \x03%N \x05has startled the witch!", attacker);
	}
}

/**
 * Handles when a witch spawns
 *
 * @handle: event - The witch_spawn event
 * @string: name - Name of the event
 * @bool: dontBroadcast - Enable/disable broadcasting of event triggering
 *
 */
void Event_WitchSpawn(Event event, const char[] name , bool dontBroadcast)
{
	// Make sure we can continue
	if (!g_bTrigger_Random)
	{
		horde_size = g_bTrigger_Horde_Size;
		return;
	}
	// Set a random event to trigger the horde
	if (g_bLeft4Dead2)
	{
		int trigger_event = GetRandomInt(0, 3);
		switch (trigger_event)
		{
			case 0: SetConVarBool(g_hCvarTrigger_Annoyed, true);
			case 1: SetConVarBool(g_hCvarTrigger_Annoyed_First, true);
			case 2: SetConVarBool(g_hCvarTrigger_Killed, true);
			case 3: SetConVarBool(g_hCvarTrigger_Killed_Crowned, true);			
		}
	}
	else
	{
		int trigger_event = GetRandomInt(0, 2);
		switch (trigger_event)
		{
			case 0: SetConVarBool(g_hCvarTrigger_Annoyed, true);
			case 1: SetConVarBool(g_hCvarTrigger_Killed, true);
			case 2: SetConVarBool(g_hCvarTrigger_Killed_Crowned, true);
		}
	}
	// Randomly select if a horde should be alerted
	if (g_bTrigger_Random_Alert_Horde)
	{
		int trigger_alert_horde = GetRandomInt(0, 1);
		if (!trigger_alert_horde)
		{
			alert_horde = false;
		}
	}
	// Randomly select the horde size
	if (g_bTrigger_Random_Horde_Size)
	{
		int trigger_horde_size = GetRandomInt(0, 1);
		switch (trigger_horde_size)
		{
			case 0: horde_size = 0;
			case 1: horde_size = 1;
		}
	}
}

/**
 * Handles when a witch is killed
 *
 * @handle: event - The witch_killed event
 * @string: name - Name of the event
 * @bool: dontBroadcast - Enable/disable broadcasting of event triggering
 *
 */
void Event_WitchKilled(Event event, const char[] name , bool dontBroadcast)
{
	// Make sure we can continue
	if (!g_bTrigger_Killed && !g_bTrigger_Killed_Crowned)
	{
		return;
	}
	// Get event information
	int attacker_id	= event.GetInt("userid");
	int witch_id = event.GetInt("witchid");
	bool crowned = event.GetBool("oneshot");
	// Get the correct client id
	int attacker = GetClientOfUserId(attacker_id);
	if (!IsValidClient(attacker))
	{
		return;
	}
	// If witch was crowned
	if (g_bTrigger_Killed_Crowned)
	{
		if (crowned)
		{
			WitchCrowned(attacker, witch_id);
		}

		return;
	}
	else if (!g_bTrigger_Killed)
	{
		return;
	}
	// Play sound if needed
	if (g_bSound)
	{
		PlaySound(witch_id);
	}
	// Trigger the horde
	if (alert_horde)
	{
		Timer_AlertHorde[attacker] = CreateTimer(g_fTrigger_Delay, AlertHorde, attacker);
	}
	// Announce who killed witch if needed
	if (g_bAnnouncements)
	{
		PrintToChatAll("\x04[Crowned Horde] \x03%N \x05has killed the witch!", attacker);
	}
	// We need to reset any changed convars
	if (g_bTrigger_Random)
	{
		ResetConVars();
	}
}

/**
 * Handles the witch being crowned
 *
 * @param: witch_id - ID of the witch
 *
 */
void WitchCrowned(any attacker, any witch_id)
{
	// Play sound if needed
	if (g_bSound)
	{
		PlaySound(witch_id);
	}
	// Trigger the horde
	if (alert_horde)
	{
		Timer_AlertHorde[attacker] = CreateTimer(g_fTrigger_Delay, AlertHorde, attacker);
	}
	// Announce who killed witch if needed
	if (g_bAnnouncements)
	{
		PrintToChatAll("\x04[Crowned Horde] \x03%N \x05has crowned the witch!", attacker);
	}
	// We need to reset any changed convars
	if (g_bTrigger_Random)
	{
		ResetConVars();
	}
}

/**
 * Handles the witch being annoyed for the first time
 *
 * @param: attacker_id - ID of the attacker
 * @param: witch_id - ID of the witch
 *
 */
void WitchAnnoyedFirst(any attacker, any witch_id)
{
	// Play sound if needed
	if (g_bSound)
	{
		PlaySound(witch_id);
	}
	// Trigger the horde
	if (alert_horde)
	{
		Timer_AlertHorde[attacker] = CreateTimer(g_fTrigger_Delay, AlertHorde, attacker);
	}
	// Announce who killed witch if needed
	if (g_bAnnouncements)
	{
		PrintToChatAll("\x04[Crowned Horde] \x03%N \x05has startled the witch for the first time!", attacker);
	}
}

/**
 * Plays the witches scream
 *
 * @param: witch - ID of the witch
 *
 */
void PlaySound(any witch_id)
{
	// Play the sound to each client
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
		{
			continue;
		}
		if (IsFakeClient(i))
		{
			continue;
		}
		EmitSoundToClient(i, g_sWitch, witch_id, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	}
}

/**
 * Alerts the horde
 *
 * @handle: timer - Handle to the timer
 * @param: attacker - The witches attacker id
 *
 */
Action AlertHorde(Handle timer, any attacker)
{
	// Alert the correct size horde
	switch (horde_size)
	{
		case 0: BypassAndExecuteCommand(attacker, "z_spawn", "mob");
		case 1: BypassAndExecuteCommand(attacker, "director_force_panic_event", "");
	}
	Timer_AlertHorde[attacker] = null;
	return Plugin_Stop;
}

/**
 * Bypasses the sv_cheats to use command
 * Thanks to Damizean
 *
 * @param: Client - The Client to execute the command on
 * @string: strCommand - The command to execute
 * @string: strParam1 - Parameter of the command
 *
 */
void BypassAndExecuteCommand(int Client, char[] strCommand, char[] strParam1)
{
	// Fixes invalid client bug
	if (!Client)
	{
		return;
	}
	int Flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, Flags & ~FCVAR_CHEAT);
	FakeClientCommand(Client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, Flags);
}

/**
 * Resets any changed convars
 *
 */
void ResetConVars()
{
	ResetConVar(g_hCvarTrigger_Annoyed);
	if (g_bLeft4Dead2)
		ResetConVar(g_hCvarTrigger_Annoyed_First);
	ResetConVar(g_hCvarTrigger_Killed);
	ResetConVar(g_hCvarTrigger_Killed_Crowned);
}

bool IsValidClient(int client)
{
	return client > 0 
		&& client <= MaxClients 
		&& IsClientInGame(client) 
		&& !IsFakeClient(client);
}