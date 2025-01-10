//Colorise: by Arg!

/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/

int g_ColorizeTarget[MAXPLAYERS+1];
ConVar cvar_SelfColorize;

/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/

public void SetupColorize()
{
	RegAdminCmd("sm_colorize", Command_SmColorize, ADMFLAG_SLAY, "sm_colorize <name or #userid> <color> - sets player color (normal to revert)");
	RegAdminCmd("sm_colorme", Command_SmColorMe, 0, "sm_colorme <color> - colorize yourself");
	
	RegConsoleCmd("sm_colorize_colors", Command_SmColorizeColors, "displays colors available to sm_colorize and sm_colorme");	
	
	cvar_SelfColorize = CreateConVar("sm_selfcolorize", "0", "Allow players to colorize themselves with sm_colorme", FCVAR_NOTIFY, true, 0.0, true, 1.0);
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/

public Action Command_SmColorize(int client, int args)
{
	char target[65];
	char color[65];
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;
	
	bool colorFound;
	
	//not enough arguments, display usage
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_colorize <#userid|name> color");
		return Plugin_Handled;
	}	

	//get command arguments
	GetCmdArg(1, target, sizeof(target));
	GetCmdArg(2, color, sizeof(color));
	
	//get the target of this command, return error if invalid
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
	
	//check for random color
	if(StrEqual("random", color, false))
	{
		colorFound = true;			
		
		for (int i = 0; i < target_count; i++)
		{
			PerformColorize(client, target_list[i], GetRandomInt(0,(sizeof(g_sTColors) -1 )) );
		}
	}
	else
	{	
		//iterate colors	
		for (int c = 0; c < sizeof(g_sTColors); c++)
		{
			//if we match requested color, colorize all targets found and break
			if (StrEqual(g_sTColors[c],color,false)) 
			{
				colorFound = true;			
				
				for (int i = 0; i < target_count; i++)
				{
					PerformColorize(client, target_list[i], c);
				}			
				
				break;
			}
		}
	}
	
	//if invalid color specified, return error
	if( !colorFound )
	{
		ReplyToCommand(client, "[SM] %s", "Invalid color");
		return Plugin_Handled;
	}

	ShowActivity2(client, "[SM] ", "%t", "made the color",  target_name, color);
	
	return Plugin_Handled;
}

public Action Command_SmColorMe(int client, int args)
{
	char color[65];
	bool colorFound;
	
	if( !cvar_SelfColorize.BoolValue )
	{	
		ReplyToCommand(client, "[SM] You do not have access to this command");
		return Plugin_Handled;	
	}
	
	//not enough arguments, display usage
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_colorme <color>");
		return Plugin_Handled;
	}	

	//get command arguments
	GetCmdArg(1, color, sizeof(color));
	
	//check for random color
	if(StrEqual("random", color, false))
	{
		colorFound = true;			
		PerformColorize(client, client, GetRandomInt(0,(sizeof(g_sTColors) -1 )) );
	}
	else
	{	
		//iterate colors	
		for (int c = 0; c < sizeof(g_sTColors); c++)
		{
			//if we match requested color, colorize all targets found and break
			if (StrEqual(g_sTColors[c],color,false)) 
			{
				colorFound = true;			
				PerformColorize(client, client, c);
				
				break;
			}
		}
	}
	
	//if invalid color specified, return error
	if( !colorFound )
	{
		ReplyToCommand(client, "[SM] %s", "Invalid color");
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

public Action Command_SmColorizeColors(int client, int args)
{
	char colorlist[sizeof(g_sTColors)*21];

	//iterate colors
	for (int c = 0; c < sizeof(g_sTColors); c++) 
	{
		//generate list of colors
		if( c != 0 )
		{
			Format( colorlist, sizeof(colorlist), "%s, ", colorlist);
		}
		Format( colorlist, sizeof(colorlist), "%s%s", colorlist, g_sTColors[c]);
	}
	
	//display in console
	ReplyToCommand(client, "[SM] sm_colorize accepts the following colors: random, %s", colorlist);
	
	return Plugin_Handled;
}

/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/

void PerformColorize(int client, int target, int c)
{
	//set target color and log action
	SetColor(target, c);
	
	DoRGBA(target,RENDER_NORMAL);
	
	LogAction(client, target, "\"%L\" made \"%L\" %s", client, target, g_sTColors[c]);
}

/*****************************************************************


			A D M I N   M E N U   F U N C T I O N S


*****************************************************************/

void Setup_AdminMenu_Colorize_Player(TopMenuObject parentmenu)
{
	hTopMenu.AddItem("sm_colorize",
		AdminMenu_Colorize,
		parentmenu,
		"sm_colorize",
		ADMFLAG_SLAY);
}

public void AdminMenu_Colorize(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Colorize player", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayColorizeMenu(param);
	}
}

void DisplayColorizeMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_Colorize);
	
	char title[100];
	Format(title, sizeof(title), "%T:", "Colorize player", client);
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	
	AddTargetsToMenu(menu, client, true, false);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Colorize(Menu menu, MenuAction action, int param1, int param2)
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
			g_ColorizeTarget[param1] = userid;
			DisplayColorizeColorMenu(param1);
			return 0;	// Return, because we went to a new menu and don't want the re-draw to occur.
		}
		
		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayColorizeMenu(param1);
		}
	}
	return 0;
}

void DisplayColorizeColorMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_ColorizeColor);
	
	char title[100];
	Format(title, sizeof(title), "%T:", "Color", client);
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	
	menu.AddItem("random", "random");
	
	//iterate colors
	for (int c = 0; c < sizeof(g_sTColors); c++) 
	{
		//generate list of colors
		menu.AddItem(g_sTColors[c], g_sTColors[c]);		
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ColorizeColor(Menu menu, MenuAction action, int param1, int param2)
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
		int target;
		char color[16];
		
		menu.GetItem(param2, color, sizeof(color));
		
		if ((target = GetClientOfUserId(g_ColorizeTarget[param1])) == 0)
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
			
			//check for random color
			if(StrEqual("random", color, false))
			{
				PerformColorize(param1, target, GetRandomInt(0,(sizeof(g_sTColors) -1 )) );
			}
			else
			{
				//iterate colors	
				for (int c = 0; c < sizeof(g_sTColors); c++) 
				{
					//if we match requested color, colorize all targets found and break
					if (StrEqual(g_sTColors[c],color,false)) 
					{
						PerformColorize(param1, target, c);
						break;
					}
				}
			}	

			ShowActivity2(param1, "[SM] ", "%t", "made the color",  name, color);
		}
		
		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayColorizeMenu(param1);
		}
	}
	return 0;
}