//Explode: by Arg!

/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/

public void SetupExplode()
{
	RegAdminCmd("sm_explode", Command_Explode, ADMFLAG_SLAY, "sm_explode <#userid|name> - Explodes player(s) if alive");
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/

public Action Command_Explode(int client, int args)
{
	char target[32];
	char target_name[MAX_NAME_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;
	
	//validate args
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_explode <#userid|name>");
		return Plugin_Handled;
	}
	
	//get argument
	GetCmdArg(1, target, sizeof(target));		
	
	//get target(s)
	if ((target_count = ProcessTargetString(
			target,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		PerformExplode(client,target_list[i]);
	}
	
	ShowActivity2(client, "[SM] ", "%t", "was exploded",  target_name);
	
	return Plugin_Handled;
}

/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/

void PerformExplode(int client, int target)
{
	FakeClientCommand(target, "explode"); 
	
	LogAction(client,target, "\"%L\" exploded \"%L\"" , client, target);
}

/*****************************************************************


			A D M I N   M E N U   F U N C T I O N S


*****************************************************************/

void Setup_AdminMenu_Explode_Player(TopMenuObject parentmenu)
{
	hTopMenu.AddItem("sm_explode",
		AdminMenu_Explode,
		parentmenu,
		"sm_explode",
		ADMFLAG_SLAY);
}

public void AdminMenu_Explode(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Explode player", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayExplodeMenu(param);
	}
}

void DisplayExplodeMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_Explode);
	
	char title[100];
	Format(title, sizeof(title), "%T:", "Explode player", client);
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	
	AddTargetsToMenu(menu, client, true, false);
	
	menu.Display(client, MENU_TIME_FOREVER);
}


public int MenuHandler_Explode(Menu menu, MenuAction action, int param1, int param2)
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
			
			PerformExplode(param1,target);
			ShowActivity2(param1, "[SM] ", "%t", "was exploded",  name);
		}
		
		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayExplodeMenu(param1);
		}
	}
	return 0;
}