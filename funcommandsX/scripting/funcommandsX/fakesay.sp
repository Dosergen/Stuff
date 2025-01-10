//Fakesay: by Arg!

/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/

public void SetupFakeSay()
{
	RegAdminCmd("sm_fakesay", Command_Fakesay, ADMFLAG_BAN, "sm_fakesay <#userid|name> \"text\" - Specified client appears to say text");
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/

public Action Command_Fakesay(int client,int args)
{
	if(args != 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_fakesay <#userid|name> <text>");
		return Plugin_Handled;
	}

	char Target[64];
	char text[128];

	GetCmdArg(1, Target, sizeof(Target));
	GetCmdArg(2, text, sizeof(text));

	int itarget = FindTarget(client, Target);
	if(itarget == -1)
	{
		ReplyToCommand(client, "Unable to find target");
		return Plugin_Handled;
	}
	MC_PrintToChatAllEx(itarget, "{teamcolor}%N{default} :  %s", itarget, text);
	LogAction(client, itarget, "%L made %L say %s ", client, itarget, text);
	
	return Plugin_Handled;
}