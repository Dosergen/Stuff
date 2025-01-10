//Teleport: by Spazman0

/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/

float g_pos[3];

/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/

public void SetupTeleport()
{
	RegAdminCmd("sm_tele", Command_Tele, ADMFLAG_SLAY, "sm_tele <#userid|name> - Teleports player to where admin is looking");
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/

public Action Command_Tele(int client, int args)
{
	char target[32];
	char target_name[MAX_NAME_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;
	
	//validate args
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_tele <#userid|name>");
		return Plugin_Handled;
	}
	
	if( !client )
	{
		ReplyToCommand(client, "[SM] Cannot teleport from rcon");
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
	
	if( !SetTeleportEndPoint(client))
	{
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		PerformTeleport(client,target_list[i],g_pos);
	}
	
	ShowActivity2(client, "[SM] ", "%t", "was Teleported",  target_name);
	
	return Plugin_Handled;	
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
} 

public Action DeleteParticles(Handle timer, any particle)
{
	if (IsValidEntity(particle))
	{
		char classname[32];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
		{
			RemoveEdict(particle);
		}
	}
	return Plugin_Stop;
}

/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/
int SetTeleportEndPoint(int client)
{
	float vAngles[3];
	float vOrigin[3];
	float vBuffer[3];
	float vStart[3];
	float Distance;
	
	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, vAngles);
	
    //get endpoint for teleport
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
    	
	if(TR_DidHit(trace))
	{   	 
   	 	TR_GetEndPosition(vStart, trace);
		GetVectorDistance(vOrigin, vStart, false);
		Distance = -35.0;
   	 	GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
		g_pos[0] = vStart[0] + (vBuffer[0]*Distance);
		g_pos[1] = vStart[1] + (vBuffer[1]*Distance);
		g_pos[2] = vStart[2] + (vBuffer[2]*Distance);
	}
	else
	{
		PrintToChat(client, "[SM] %s", "Could not teleport player");
		CloseHandle(trace);
		return false;
	}
	
	CloseHandle(trace);
	return true;
}

void TeleportEffects(float pos[3])
{
	if(g_GameType == GAME_TF2)
	{
		ShowParticle(pos, "pyro_blast", 1.0);
		ShowParticle(pos, "pyro_blast_lines", 1.0);
		ShowParticle(pos, "pyro_blast_warp", 1.0);
		ShowParticle(pos, "pyro_blast_flash", 1.0);
		ShowParticle(pos, "burninggibs", 0.5);
	}
}

void ShowParticle(float possie[3], char[] particlename, float time)
{
    int particle = CreateEntityByName("info_particle_system");
    if (IsValidEdict(particle))
    {
        TeleportEntity(particle, possie, NULL_VECTOR, NULL_VECTOR);
        DispatchKeyValue(particle, "effect_name", particlename);
        ActivateEntity(particle);
        AcceptEntityInput(particle, "start");
        CreateTimer(time, DeleteParticles, particle);
    }
    else
    {
        LogError("ShowParticle: could not create info_particle_system");
    }    
}

void PerformTeleport(int client, int target, float pos[3])
{
	float partpos[3];
	
	GetClientEyePosition(target, partpos);
	partpos[2]-=20.0;	
	
	TeleportEffects(partpos);
	
	TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
	pos[2]+=40.0;
	
	TeleportEffects(pos);
	
	LogAction(client,target, "\"%L\" teleported \"%L\"" , client, target);
}

/*****************************************************************


			A D M I N   M E N U   F U N C T I O N S


*****************************************************************/

void Setup_AdminMenu_Teleport_Player(TopMenuObject parentmenu)
{
	hTopMenu.AddItem("sm_tele",
		AdminMenu_Tele,
		parentmenu,
		"sm_tele",
		ADMFLAG_SLAY);
}

public void AdminMenu_Tele(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Teleport player", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayTeleMenu(param);
	}
}

void DisplayTeleMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_Tele);
	
	char title[100];
	Format(title, sizeof(title), "%T:", "Teleport player", client);
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	
	AddTargetsToMenu(menu, client, true, false);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Tele(Menu menu, MenuAction action, int param1, int param2)
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
			
			if( SetTeleportEndPoint(param1) && IsClientInGame(target) && IsPlayerAlive(target))
			{
				PerformTeleport(param1, target, g_pos);
				ShowActivity2(param1, "[SM] ", "%t", "was Teleported",  name);
			}
		}
		
		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayTeleMenu(param1);
		}
	}
	return 0;
}