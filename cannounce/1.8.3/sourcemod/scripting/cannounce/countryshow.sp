/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/

KeyValues hKVCountryShow;

ConVar g_CvarShowConnect;
ConVar g_CvarShowDisconnect;
ConVar g_CvarShowEnhancedToAdmins;

/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/

void SetupCountryShow()
{
	g_CvarShowConnect = CreateConVar("sm_ca_showenhanced", "1", "displays enhanced message when player connects");
	g_CvarShowDisconnect = CreateConVar("sm_ca_showenhanceddisc", "1", "displays enhanced message when player disconnects");
	g_CvarShowEnhancedToAdmins = CreateConVar("sm_ca_showenhancedadmins", "0", "displays a different enhanced message to admin players (ADMFLAG_GENERIC)");

	//prepare kv for countryshow
	hKVCountryShow = new KeyValues("CountryShow");

	if (!hKVCountryShow.ImportFromFile(g_filesettings))
		hKVCountryShow.ExportToFile(g_filesettings);

	SetupDefaultMessages();
}

void OnPostAdminCheck_CountryShow(int client)
{
	char rawmsg[301];
	char rawadmmsg[301];
	//if enabled, show message
	if (g_CvarShowConnect.BoolValue)
	{
		hKVCountryShow.Rewind();
		//get message admins will see (if sm_ca_showenhancedadmins)
		if (hKVCountryShow.JumpToKey("messages_admin", false))
		{
			hKVCountryShow.GetString("playerjoin", rawadmmsg, sizeof(rawadmmsg), "");
			Format(rawadmmsg, sizeof(rawadmmsg), "%c%s", 1, rawadmmsg);
			hKVCountryShow.Rewind();
		}
		//get message all players will see
		if (hKVCountryShow.JumpToKey("messages", false))
		{
			hKVCountryShow.GetString("playerjoin", rawmsg, sizeof(rawmsg), "");
			Format(rawmsg, sizeof(rawmsg), "%c%s", 1, rawmsg);
			hKVCountryShow.Rewind();
		}
		//if sm_ca_showenhancedadmins - show diff messages to admins
		if (g_CvarShowEnhancedToAdmins.BoolValue)
		{
			PrintFormattedMessageToAdmins(rawadmmsg, client);
			PrintFormattedMsgToNonAdmins(rawmsg, client);
		}
		else
			PrintFormattedMessageToAll(rawmsg, client);
	}
}

void OnPluginEnd_CountryShow()
{
	delete hKVCountryShow;
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/

public void event_PlayerDisc_CountryShow(Event event, const char[] name, bool dontBroadcast)
{
	char rawmsg[301];
	char rawadmmsg[301];
	char reason[65];
	int client = GetClientOfUserId(event.GetInt("userid"));
	//if enabled, show message
	if (g_CvarShowDisconnect.BoolValue)
	{
		event.GetString("reason", reason, sizeof(reason));
		hKVCountryShow.Rewind();
		//get message admins will see (if sm_ca_showenhancedadmins)
		if (hKVCountryShow.JumpToKey("messages_admin", false))
		{
			hKVCountryShow.GetString("playerdisc", rawadmmsg, sizeof(rawadmmsg), "");
			Format(rawadmmsg, sizeof(rawadmmsg), "%c%s", 1, rawadmmsg);
			hKVCountryShow.Rewind();
			//first replace disconnect reason if applicable
			if (StrContains(rawadmmsg, "{DISC_REASON}") != -1)
			{
				ReplaceString(rawadmmsg, sizeof(rawadmmsg), "{DISC_REASON}", reason);
				//strip carriage returns, replace with space
				ReplaceString(rawadmmsg, sizeof(rawadmmsg), "\n", " ");
			}
		}
		//get message all players will see
		if (hKVCountryShow.JumpToKey("messages", false))
		{
			hKVCountryShow.GetString("playerdisc", rawmsg, sizeof(rawmsg), "");
			Format(rawmsg, sizeof(rawmsg), "%c%s", 1, rawmsg);
			hKVCountryShow.Rewind();
			//first replace disconnect reason if applicable
			if (StrContains(rawmsg, "{DISC_REASON}") != -1)
			{
				ReplaceString(rawmsg, sizeof(rawmsg), "{DISC_REASON}", reason);
				//strip carriage returns, replace with space
				ReplaceString(rawmsg, sizeof(rawmsg), "\n", " ");
			}
		}
		//if sm_ca_showenhancedadmins - show diff messages to admins
		if (g_CvarShowEnhancedToAdmins.BoolValue)
		{
			PrintFormattedMessageToAdmins(rawadmmsg, client);
			PrintFormattedMsgToNonAdmins(rawmsg, client);
		}
		else
			PrintFormattedMessageToAll(rawmsg, client);
		hKVCountryShow.Rewind();
	}
}

/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/

void SetupDefaultMessages()
{
	if (!hKVCountryShow.JumpToKey("messages"))
	{
		hKVCountryShow.JumpToKey("messages", true);
		hKVCountryShow.SetString("playerjoin", "{PLAYERTYPE} {GREEN}{PLAYERNAME} {DEFAULT}<{LIGHTGREEN}{STEAMID}{DEFAULT}> connected from country {GREEN}{PLAYERCOUNTRY} {DEFAULT}({LIGHTGREEN}{PLAYERCOUNTRYSHORT}{DEFAULT}), IP {GREEN}{PLAYERIP}");
		hKVCountryShow.SetString("playerdisc", "{PLAYERTYPE} {GREEN}{PLAYERNAME} {DEFAULT}<{LIGHTGREEN}{STEAMID}{DEFAULT}> from country {GREEN}{PLAYERCOUNTRY} {DEFAULT}({LIGHTGREEN}{PLAYERCOUNTRYSHORT}{DEFAULT}) disconnected from IP {GREEN}{PLAYERIP}{GREEN}reason: {DEFAULT}{DISC_REASON}");
		hKVCountryShow.Rewind();
		hKVCountryShow.ExportToFile(g_filesettings);	
	}
	hKVCountryShow.Rewind();
	if (!hKVCountryShow.JumpToKey("messages_admin"))
	{
		hKVCountryShow.JumpToKey("messages_admin", true);
		hKVCountryShow.SetString("playerjoin", "{PLAYERTYPE} {GREEN}{PLAYERNAME} {DEFAULT}<{LIGHTGREEN}{STEAMID}{DEFAULT}> connected from country {GREEN}{PLAYERCOUNTRY} {DEFAULT}({LIGHTGREEN}{PLAYERCOUNTRYSHORT}{DEFAULT}), IP {GREEN}{PLAYERIP}");
		hKVCountryShow.SetString("playerdisc", "{PLAYERTYPE} {GREEN}{PLAYERNAME} {DEFAULT}<{LIGHTGREEN}{STEAMID}{DEFAULT}> from country {GREEN}{PLAYERCOUNTRY} {DEFAULT}({LIGHTGREEN}{PLAYERCOUNTRYSHORT}{DEFAULT}) disconnected from IP {GREEN}{PLAYERIP}{GREEN}reason: {DEFAULT}{DISC_REASON}");
		hKVCountryShow.Rewind();
		hKVCountryShow.ExportToFile(g_filesettings);	
	}
	hKVCountryShow.Rewind();
}