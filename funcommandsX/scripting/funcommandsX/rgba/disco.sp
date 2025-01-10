//Disco: by Arg!

/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/

Handle g_DiscoTimer;
ConVar cvar_DiscoInterval;
ConVar cvar_AutoDisco;
ConVar cvar_AutoDiscoTime;

/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/

public void SetupDisco()
{	
	g_DiscoTimer = null;
	cvar_DiscoInterval = null;
	
	RegAdminCmd("sm_disco", Command_SmDisco, ADMFLAG_SLAY, "sm_disco [1|0] - toggles disco mode or force on or off");
	
	cvar_DiscoInterval = CreateConVar("sm_discointerval", "0.6", "Set disco mode change color interval", FCVAR_NOTIFY, true, 0.0, true, 10.0);
	cvar_DiscoInterval.AddChangeHook(DiscoIntervalChanged);
	
	cvar_AutoDisco = CreateConVar("sm_autodisco", "0", "Automatically starts disco mode on map change and runs for sm_autodiscotime", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvar_AutoDiscoTime = CreateConVar("sm_autodiscotime", "60.0", "Time in seconds to run auto disco mode", FCVAR_NOTIFY, true, 0.0, true, 300.0);
}

public void OnMapStart_Disco()
{
	float interval;
	
	if( cvar_AutoDisco.BoolValue )
	{	
		interval = cvar_AutoDiscoTime.FloatValue;
	
		//1 off timer to kill auto disco
		CreateTimer(interval, Timer_AutoDisco);
		
		CreateDisco();
		LogMessage("Disco mode enabled due to auto disco");
	}
}

public void OnMapEnd_Disco()
{
	if( g_DiscoTimer != null )
	{
		KillTimer(g_DiscoTimer);
		g_DiscoTimer = null;	
	}
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/

public Action Command_SmDisco(int client, int args)
{
	char toggleStr[2];
	
	int toggle = 2;
	
	if (args > 0)
	{
		GetCmdArg(1, toggleStr, sizeof(toggleStr));
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
			ReplyToCommand(client, "[SM] Usage: sm_disco [1|0]");
			return Plugin_Handled;	
		}
	}
	
	//handle disco mode
	if(	PerformDisco(client, toggle) )
	{
		ShowActivity2(client, "[SM] ", "%t", "Enabled disco mode");
	}
	else
	{
		ShowActivity2(client, "[SM] ", "%t", "Disabled disco mode");
	}
	
	return Plugin_Handled; 
}

public Action Timer_Disco(Handle timer)
{	
	int maxclients = MaxClients;
	int colIndex;
	
	for( int i = 1; i <= maxclients; i++ )
	{
		if( IsClientInGame(i) )
		{
			colIndex = GetRandomInt(0,(sizeof(g_sTColors) -1 ));
			
			SetColor(i,colIndex );

			DoRGBA(i, RENDER_NORMAL);
		}
	}
	
	return Plugin_Handled;
}

public void DiscoIntervalChanged(ConVar convar, const char[] oldValue, const char[] intValue)
{
	float intVal;
	
	//are we running mode rite now?
	if( g_DiscoTimer != null )
	{
		intVal = StringToFloat( intValue );
		
		//is the cvar set to a valid value
		if( intVal > 0.0 )
		{
			//kill the timer and recrate
			KillTimer(g_DiscoTimer);
			g_DiscoTimer = null;	
			
			CreateDisco();
		}
	}
}

public Action Timer_AutoDisco(Handle timer)
{	
	KillDisco();
	LogMessage("Disco mode disabled due to auto disco time elapsed");
	
	return Plugin_Handled;
}

/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/

bool PerformDisco(int client, int toggle)
{
 	switch(toggle)
 	{
 		case(2):
 		{
			if (g_DiscoTimer == null)
			{
				CreateDisco();
				LogMessage("\"%L\" enabled disco mode", client);
				PrintCenterTextAll("%t", "Disco on message");
				return true;
			}
			else
			{
				KillDisco();
				LogMessage("\"%L\" disabled disco mode", client);
				return false;
			}
 		}
 		case(1):
 		{
				CreateDisco();
				LogMessage("\"%L\" enabled disco mode", client);
				PrintCenterTextAll("Disco mode on, get down and boogie!");
				return true;
 		}
 		case(0):
 		{
				KillDisco();
				LogMessage("\"%L\" disabled disco mode", client);
				return false;
 		}
 	}
 	
 	return false;
}

void CreateDisco()
{	
	float interval;
	
	interval = cvar_DiscoInterval.FloatValue;
	
	//validate convar value
	if( interval <= 0.0 )
	{
		interval = 1.0;
	}
	
	//create timer if applicible
	if( g_DiscoTimer == null )
	{
		g_DiscoTimer = CreateTimer(interval, Timer_Disco, _, TIMER_REPEAT);
	}	
}

void KillDisco()
{
	if( g_DiscoTimer != null )
	{
		KillTimer(g_DiscoTimer);
		g_DiscoTimer = null;	
	}
	
	//restore players
	int maxclients = MaxClients;
	
	for( int i = 1; i <= maxclients; i++ )
	{
		SetColor(i, 0);
		
		if( IsClientInGame(i) )
		{			
			DoRGBA(i, RENDER_NORMAL);
		}
	}
	
}

/*****************************************************************


			A D M I N   M E N U   F U N C T I O N S


*****************************************************************/

void Setup_AdminMenu_Disco_Server(TopMenuObject parentmenu)
{
	hTopMenu.AddItem("sm_disco",
		AdminMenu_ToggleDisco,
		parentmenu,
		"sm_disco",
		ADMFLAG_SLAY);
}

public void AdminMenu_ToggleDisco(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if(g_DiscoTimer != null)
		{
			Format(buffer, maxlength, "%T", "Disco Mode Off", param);
		}
		else
		{
			Format(buffer, maxlength, "%T", "Disco Mode On", param);
		}
	}
	else if (action == TopMenuAction_SelectOption)
	{	
		if(	PerformDisco(param, 2) )
		{
			ShowActivity2(param, "[SM] ", "%t", "Enabled disco mode");
		}
		else
		{
			ShowActivity2(param, "[SM] ", "%t", "Disabled disco mode");
		}
		
		RedisplayAdminMenu(topmenu, param);	
	}
}