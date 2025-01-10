//Happy: by Spazman0 and Arg!
//Thanks to Greyscale for the prototype

/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/

bool g_Blocktext[MAXPLAYERS+1] = {true, ...};
bool g_IsHappy[MAXPLAYERS+1] = {false, ...};
char g_Phrases[256][192];
int g_currClient = 0;
int g_phraseCount;

/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/
public void SetupHappy()
{
    RegConsoleCmd("say", Command_Say);
    RegConsoleCmd("say_team", Command_Say);
    RegAdminCmd("sm_happy", Command_Happy, ADMFLAG_SLAY, "sm_happy <#userid|name> <1|0> - replaces clients text chat with strings from happy_phrases.ini");
    RegAdminCmd("sm_addhappy", Command_AddHappyPhrase, ADMFLAG_ROOT, "Adds a happy phrase to happy_phrases.ini");
    
    g_phraseCount = BuildPhrases();
}

public bool OnClientConnect_Happy(int client, char[] rejectmsg, int maxlen)
{
	g_Blocktext[client] = true;
	g_IsHappy[client] = false;

	return true;
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/
public Action Command_Happy(int client,int args)
{
	char target[65];
	char toggleStr[2];
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;
	int toggle = 2;
	
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_happy <#userid|name> <1|0>");
		return Plugin_Handled;
	}
	
	GetCmdArg(1, target, sizeof(target));
	
	if (args > 1)
	{
		GetCmdArg(2, toggleStr, sizeof(toggleStr));
		if (StrEqual(toggleStr[0],"1"))
		{
			toggle = 1;
		}
		else if (StrEqual(toggleStr[0],"0"))
		{
			toggle = 0;
		}
		else
		{
			ReplyToCommand(client, "[SM] Usage: sm_happy <#userid|name> <1|0>");
			return Plugin_Handled;	
		}
	}
	
	if ((target_count = ProcessTargetString(
			target,
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		DoHappy(client, target_list[i], toggle);
	}	

	ShowActivity2(client, "[SM] ", "%t", "Toggled happy on target", target_name);
	
	return Plugin_Handled; 
}

public Action Command_AddHappyPhrase(int client, int args)
{
    if(args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_addhappy <phrase>");
        return Plugin_Handled;
    }

    char szhappyphrase[64];
    char szFile[256];
    File hFile = OpenFile(szFile, "at");
    
    GetCmdArgString(szhappyphrase, sizeof(szhappyphrase));
    
    BuildPath(Path_SM, szFile, sizeof(szFile), "configs/happy_phrases.ini");
    
    hFile.WriteLine("%s", szhappyphrase);
    delete hFile;

    g_phraseCount = BuildPhrases();

    return Plugin_Handled;
} 

public Action Command_Say(int client, int args)
{
	if (g_IsHappy[client])
	{
	   	if (g_Blocktext[client])
	   	{
	   		g_Blocktext[client] = false;
	   		
	   		if( g_phraseCount > 0 )
	   		{
	   			FakeClientCommandEx(client, "say %s", g_Phrases[GetRandomInt(0,(g_phraseCount -1 ))]);
	   		}
	   		else
	   		{	   			
	   			FakeClientCommandEx(client, "say %s", "The person who set up the happy plugin on this server forgot to add a phrases file! They should check that...");
	   		}
	   		
	   		g_currClient = client;
	   		CreateTimer(0.1, UnblockText);
	   		return Plugin_Handled;
	   	}
	}
	return Plugin_Continue;
}

public Action UnblockText(Handle timer)
{	
	g_Blocktext[g_currClient] = true;

	return Plugin_Stop;
}

/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/

void MakeHappy(int target)
{
	g_IsHappy[target] = true;
}

void MakeUnhappy(int target)
{
	g_IsHappy[target] = false;
}

void DoHappy(int client, int target, int toggle)
{
 	switch(toggle)
 	{
 		case(2):
 		{
			if (g_IsHappy[target] == false)
			{
				MakeHappy(target);
				LogAction(client, target, "\"%L\" made \"%L\" Happy", client, target);
			}
			else
			{
				MakeUnhappy(target);
				LogAction(client, target, "\"%L\" made \"%L\" Unhappy", client, target);
			}
 		}
 		case(1):
 		{
 			MakeHappy(target);
 			LogAction(client, target, "\"%L\" made \"%L\" Happy", client, target);
 		}
 		case(0):
 		{
 			MakeUnhappy(target);
 			LogAction(client, target, "\"%L\" made \"%L\" Unhappy", client, target);
 		}
 	}
}

int BuildPhrases()
{
	char imFile[PLATFORM_MAX_PATH];
	char line[192];
	int i = 0;
	int totalLines = 0;
	
	BuildPath(Path_SM, imFile, sizeof(imFile), "configs/happy_phrases.ini");
	
	File file = OpenFile(imFile, "rt");
	
	if(file != null)
	{
		while (!IsEndOfFile(file))
		{
			if (!ReadFileLine(file, line, sizeof(line)))
			{
				break;
			}
			
			TrimString(line);
			if( strlen(line) > 0 )
			{
				FormatEx(g_Phrases[i],192, "%s", line);
				totalLines++;
			}
			
			i++;
			
			//check for max no. of entries
			if( i >= sizeof(g_Phrases) )
			{
				LogError("Happy attempted to add more than the maximum allowed phrases from file");
				break;
			}
		}
		delete file;
	}
	else
	{
		LogError("[SM] (happy) no file found for phrases (configs/happy_phrases.ini)");
	}
	
	return totalLines;
}

/*****************************************************************


			A D M I N   M E N U   F U N C T I O N S


*****************************************************************/

void Setup_AdminMenu_Happy_Player(TopMenuObject parentmenu)
{
	hTopMenu.AddItem("sm_happy",
		AdminMenu_Happy,
		parentmenu,
		"sm_happy",
		ADMFLAG_SLAY);
}

public void AdminMenu_Happy(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Happy player", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayHappyMenu(param);
	}
}

void DisplayHappyMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_Happy);
	
	char title[100];
	Format(title, sizeof(title), "%T:", "Happy player", client);
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	
	AddTargetsToMenu(menu, client, true, false);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Happy(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		menu.Close();
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu != null)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		int userid, target;
		
		menu.GetItem(param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			char name[32];
			GetClientName(target, name, sizeof(name));
			
			DoHappy(param1, target, 2);
			ShowActivity2(param1, "[SM] ", "%t", "Toggled happy on target", name);
		}
		
		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayHappyMenu(param1);
		}
	}
	return 0;
}