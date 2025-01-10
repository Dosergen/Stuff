// -------------------------------------------------------------------------------
// Set any of these to 0 and recompile to completely disable those commands
// -------------------------------------------------------------------------------
#define COLORIZE        1
#define INVISIBLE       1
#define DISCO           1
// -------------------------------------------------------------------------------

/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/

// Basic color arrays for temp entities
int g_iTColors[26][4] = {{255, 255, 255, 255}, {0, 0, 0, 192}, {255, 0, 0, 192},    {0, 255, 0, 192}, {0, 0, 255, 192}, {255, 255, 0, 192}, {255, 0, 255, 192}, {0, 255, 255, 192}, {255, 128, 0, 192}, {255, 0, 128, 192}, {128, 255, 0, 192}, {0, 255, 128, 192}, {128, 0, 255, 192}, {0, 128, 255, 192}, {192, 192, 192}, {210, 105, 30}, {139, 69, 19}, {75, 0, 130}, {248, 248, 255}, {216, 191, 216}, {240, 248, 255}, {70, 130, 180}, {0, 128, 128},	{255, 215, 0}, {210, 180, 140}, {255, 99, 71}};
char g_sTColors[26][32];

int g_PlayerColor[MAXPLAYERS+1][4];     //remembers players color/alpha settings
int g_AffectWeapon[MAXPLAYERS+1];       //tells recurring rgba functions to skip weapon setting if true

/*****************************************************************


			L I B R A R Y   I N C L U D E S


*****************************************************************/

#if COLORIZE
#include "funcommandsX/rgba/colorize.sp"
#endif
#if INVISIBLE
#include "funcommandsX/rgba/invisible.sp"
#endif
#if DISCO
#include "funcommandsX/rgba/disco.sp"
#endif

/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/

public void SetupRGBA()
{
	char colorTemp[32];
	
	Format(colorTemp, sizeof(colorTemp), "%t", "color_normal");
	g_sTColors[0] = colorTemp;	
	Format(colorTemp, sizeof(colorTemp), "%t", "color_black");
	g_sTColors[1] = colorTemp;	
	Format(colorTemp, sizeof(colorTemp), "%t", "color_red");
	g_sTColors[2] = colorTemp;	
	Format(colorTemp, sizeof(colorTemp), "%t", "color_green");
	g_sTColors[3] = colorTemp;	
	Format(colorTemp, sizeof(colorTemp), "%t", "color_blue");
	g_sTColors[4] = colorTemp;	
	Format(colorTemp, sizeof(colorTemp), "%t", "color_yellow");
	g_sTColors[5] = colorTemp;	
	Format(colorTemp, sizeof(colorTemp), "%t", "color_purple");
	g_sTColors[6] = colorTemp;	
	Format(colorTemp, sizeof(colorTemp), "%t", "color_cyan");
	g_sTColors[7] = colorTemp;	
	Format(colorTemp, sizeof(colorTemp), "%t", "color_orange");
	g_sTColors[8] = colorTemp;	
	Format(colorTemp, sizeof(colorTemp), "%t", "color_pink");
	g_sTColors[9] = colorTemp;	
	Format(colorTemp, sizeof(colorTemp), "%t", "color_olive");
	g_sTColors[10] = colorTemp;	
	Format(colorTemp, sizeof(colorTemp), "%t", "color_lime");
	g_sTColors[11] = colorTemp;	
	Format(colorTemp, sizeof(colorTemp), "%t", "color_violet");
	g_sTColors[12] = colorTemp;	
	Format(colorTemp, sizeof(colorTemp), "%t", "color_lightblue");
	g_sTColors[13] = colorTemp;
	Format(colorTemp, sizeof(colorTemp), "%t", "color_silver");
	g_sTColors[14] = colorTemp;
	Format(colorTemp, sizeof(colorTemp), "%t", "color_chocolate");
	g_sTColors[15] = colorTemp;
	Format(colorTemp, sizeof(colorTemp), "%t", "color_saddlebrown");
	g_sTColors[16] = colorTemp;
	Format(colorTemp, sizeof(colorTemp), "%t", "color_indigo");
	g_sTColors[17] = colorTemp;
	Format(colorTemp, sizeof(colorTemp), "%t", "color_ghostwhite");
	g_sTColors[18] = colorTemp;
	Format(colorTemp, sizeof(colorTemp), "%t", "color_thistle");
	g_sTColors[19] = colorTemp;
	Format(colorTemp, sizeof(colorTemp), "%t", "color_aliceblue");
	g_sTColors[20] = colorTemp;
	Format(colorTemp, sizeof(colorTemp), "%t", "color_steelblue");
	g_sTColors[21] = colorTemp;
	Format(colorTemp, sizeof(colorTemp), "%t", "color_teal");
	g_sTColors[22] = colorTemp;
	Format(colorTemp, sizeof(colorTemp), "%t", "color_gold");
	g_sTColors[23] = colorTemp;
	Format(colorTemp, sizeof(colorTemp), "%t", "color_tan");
	g_sTColors[24] = colorTemp;
	Format(colorTemp, sizeof(colorTemp), "%t", "color_tomato");
	g_sTColors[25] = colorTemp;
	 
	//set all player colors to normal
	for( int i = 0; i < sizeof(g_PlayerColor); i++ )
	{
		ResetClientColor(i);
	}
	
	//hook change loadout for TF2
	if(g_GameType == GAME_TF2)
	{
		HookEvent("post_inventory_application", hook_InventoryApplication, EventHookMode_Post);
	}
	//HookEvent("player_spawn", hook, EventHookMode_Post);
	
	#if COLORIZE
	SetupColorize();		// sm_colorize, sm_colorize_colors
	#endif
	#if INVISIBLE
	SetupInvisible();		// sm_invis, sm_alpha
	#endif
	#if DISCO
	SetupDisco();			// sm_disco
	#endif
}

public void OnPluginEnd_RGBA()
{
	//reset all invis/colorize if applicable
	for( int i = 1 ; i < MaxClients; i++ )
	{
		if( IsClientInGame(i) )
		{	
			#if COLORIZE
			DoRGBA(i,RENDER_NORMAL);
			#endif
			#if INVISIBLE
			DoRGBA(i,RENDER_TRANSCOLOR);
			#endif
		}
		
		ResetClientColor(i);
		
		#if DISCO
		KillDisco();
		#endif
	}
}

public void OnMapStart_RGBA()
{
	#if DISCO
	OnMapStart_Disco();
	#endif
}

public void OnMapEnd_RGBA()
{
	#if DISCO
	OnMapEnd_Disco();
	#endif
	
	//reset all players color/alpha
	for( int i = 0; i < sizeof(g_PlayerColor); i++)
	{
		ResetClientColor(i);
	}
}

public bool OnClientConnect_RGBA(int client, char[] rejectmsg, int maxlen)
{
	//reset players default color/alpha
	ResetClientColor(client);
	
	#if INVISIBLE
	OnClientConnect_Invisible(client, rejectmsg, maxlen);
	#endif
	
	return true;
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/

public Action hook_InventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	SetWearablesRGBA(client,RENDER_NORMAL);
	SetWeaponsRGBA( client,RENDER_NORMAL);
	
	#if INVISIBLE
	SetWearablesRGBA(client,RENDER_TRANSCOLOR);
	SetWeaponsRGBA( client,RENDER_TRANSCOLOR);
	#endif
	
	return Plugin_Continue;
}

/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/

void ResetClientColor(int client)
{
	g_PlayerColor[client][0] = 255;
	g_PlayerColor[client][1] = 255;
	g_PlayerColor[client][2] = 255;
	g_PlayerColor[client][3] = 255;
	
	g_AffectWeapon[client] = true;
}

void SetColor(int target, int c)
{
	g_PlayerColor[target][0] = g_iTColors[c][0];
	g_PlayerColor[target][1] = g_iTColors[c][1];
	g_PlayerColor[target][2] = g_iTColors[c][2];
}

void DoRGBA(int client, RenderMode mode, bool weapon = true)
{
	if( weapon )
	{
		SetWeaponsRGBA(client,mode);
	}
	SetWearablesRGBA(client,mode);
	SetEntityRenderMode(client, mode);
	SetEntityRenderColor(client, g_PlayerColor[client][0], g_PlayerColor[client][1], g_PlayerColor[client][2], g_PlayerColor[client][3]);
	
	#if INVISIBLE
	if( mode == RENDER_NORMAL)
	{
		DoRGBA(client,RENDER_TRANSCOLOR);
	}
	#endif
}

void SetWeaponsRGBA(int client, RenderMode mode)
{
	if( !g_AffectWeapon[client] )
	{
		return;
	}
	
	int m_hMyWeapons = FindSendPropInfo(g_PlayerProperty, "m_hMyWeapons");	
	
	//GetEntDataEnt2 will error if m_hMyWeapons is -1
	if( m_hMyWeapons == -1 )
	{
		return;
	}
	
	for(int i = 0, weapon; i < 47; i += 4)
	{
		weapon = GetEntDataEnt2(client, m_hMyWeapons + i);
	
		if (weapon > 0 && IsValidEdict(weapon))
		{
			char classname[64];
			if (GetEdictClassname(weapon, classname, sizeof(classname)) && StrContains(classname, "weapon") != -1)
			{
				SetEntityRenderMode(weapon, mode);
				SetEntityRenderColor(weapon, g_PlayerColor[client][0], g_PlayerColor[client][1], g_PlayerColor[client][2], g_PlayerColor[client][3]);
			}
		}
	}
}

void SetWearablesRGBA( int client, RenderMode mode )
{
	//only set wearable items for Team Fortress 2
	if(g_GameType == GAME_TF2)
	{
		SetWearablesRGBA_Impl( client, mode, "tf_wearable", "CTFWearable" );
		SetWearablesRGBA_Impl( client, mode, "tf_wearable_demoshield", "CTFWearableDemoShield" );
	}
}

void SetWearablesRGBA_Impl( int client, RenderMode mode, const char[] entClass, const char[] serverClass )
{
	int ent = -1;
	while( (ent = FindEntityByClassname(ent, entClass)) != -1 )
	{
		if ( IsValidEntity(ent) )
		{		
			if (GetEntDataEnt2(ent, FindSendPropInfo(serverClass, "m_hOwnerEntity")) == client)
			{
				SetEntityRenderMode(ent, mode);
				SetEntityRenderColor(ent, g_PlayerColor[client][0], g_PlayerColor[client][1], g_PlayerColor[client][2], g_PlayerColor[client][3]);
			}
		}
	}
}

/*****************************************************************


			A D M I N   M E N U   F U N C T I O N S


*****************************************************************/

void Setup_AdminMenu_RGBA_Player(TopMenuObject parentmenu)
{
	#if COLORIZE
	Setup_AdminMenu_Colorize_Player(parentmenu);
	#endif
	#if INVISIBLE
	Setup_AdminMenu_Invis_Player(parentmenu);
	#endif	
}

void Setup_AdminMenu_RGBA_Server(TopMenuObject parentmenu)
{
	#if DISCO
	Setup_AdminMenu_Disco_Server(parentmenu);
	#endif	
}