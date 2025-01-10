//FF: by Arg!

/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/

ConVar Cvar_FF = null;

/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/

public void SetupFF()
{
	RegAdminCmd("sm_ff", Command_SmFF, ADMFLAG_SLAY, "toggles friendly fire");
	
	Cvar_FF = FindConVar("mp_friendlyfire");
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/

public Action Command_SmFF(int client, int args)
{
	if( DoFF(client) )
	{
		ShowActivity2(client, "[SM] ", "%t", "Enabled friendly fire");
	}
	else
	{
		ShowActivity2(client, "[SM] ", "%t", "Disabled friendly fire");
	}
	
	return Plugin_Handled;
}

/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/

bool DoFF(int client)
{
	//toggle ff
	if( Cvar_FF.BoolValue )
	{
		Cvar_FF.SetBool(false);
		PrintToChatAll("\x04Friendly fire \x01disabled!");
		LogMessage( "\"%L\" disabled friendly fire", client );
		return false;
	}
	else
	{
		Cvar_FF.SetBool(true);
		PrintToChatAll("\x04Friendly fire \x01enabled!");
		LogMessage( "\"%L\" enabled friendly fire", client );
		return true;
	}
}

/*****************************************************************


			A D M I N   M E N U   F U N C T I O N S


*****************************************************************/

void Setup_AdminMenu_FF_Server(TopMenuObject parentmenu)
{
	hTopMenu.AddItem("sm_ff",
		AdminMenu_ToggleFF,
		parentmenu,
		"sm_ff",
		ADMFLAG_SLAY);
}


public void AdminMenu_ToggleFF(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if( Cvar_FF.BoolValue )
		{
			Format(buffer, maxlength, "%T", "Friendly Fire Off", param);
		}
		else
		{
			Format(buffer, maxlength, "%T", "Friendly Fire On", param);
		}
		
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if( DoFF(param) )
		{
			ShowActivity2(param, "[SM] ", "%t", "Enabled friendly fire");
		}
		else
		{
			ShowActivity2(param, "[SM] ", "%t", "Disabled friendly fire");
		}
		
		RedisplayAdminMenu(topmenu, param);	
	}
}