
enum map_types {
	MAP_HALF_LIFE = 0,
	MAP_OPPOSING_FORCE = 1,
	MAP_BLUE_SHIFT = 2,
}

void print(string text) { g_Game.AlertMessage( at_console, text); }
void println(string text) { print(text + "\n"); }

dictionary classic_maps;
dictionary op4_maps;
dictionary bshift_maps;

bool isClassicMap = false;
int mapType = MAP_HALF_LIFE;

enum MODES {
	MODE_AUTO = -1,
	MODE_ALWAYS_OFF = 0,
	MODE_ALWAYS_ON = 1
}

int g_force_mode = MODE_ALWAYS_ON;
bool g_basic_mode = false;

string plugin_path = "scripts/plugins/AutoClassicMode/";

// load default skill settings so this plugin doesn't override any custom map skill settings
dictionary default_skill_settings;
dictionary classic_skill_settings;

dictionary loadMapList(string fpath)
{
	dictionary maps;
	File@ f = g_FileSystem.OpenFile( fpath, OpenFile::READ );
	if (f is null or !f.IsOpen())
	{
		println("AutoClassicMode: Failed to open " + fpath);
		return maps;
	}
	
	string line;
	while( !f.EOFReached() )
	{
		f.ReadLine(line);
		maps[line] = true;
	}
	return maps;
}

dictionary loadSkillSettings(string fpath)
{
	dictionary settings;
	File@ f = g_FileSystem.OpenFile( fpath, OpenFile::READ );
	if (f is null or !f.IsOpen())
	{
		println("AutoClassicMode: Failed to open " + fpath);
		return settings;
	}
	
	string line;
	while( !f.EOFReached() )
	{
		f.ReadLine(line);
		line.Trim();
		if (line.Length() == 0 or line.Find("sk_") != 0)
			continue;
			
		array<string> parts = line.Split("\"");
		if (parts.size() < 2)
			continue;
			
		string skill = parts[0];
		string value = parts[1];
		skill.Trim();
		value.Trim();
		skill.Trim("\t");
		value.Trim("\t");
			
		settings[skill] = atof(value);
	}
	return settings;
}

void execClassicSkillSettings()
{	
	array<string> keys = classic_skill_settings.getKeys();
	for (uint i = 0; i < keys.size(); i++)
	{
		float classicValue = -1;
		float defaultValue = -1;
		float currentValue = g_EngineFuncs.CVarGetFloat(keys[i]);
		default_skill_settings.get(keys[i], defaultValue);
		classic_skill_settings.get(keys[i], classicValue);
		if (!default_skill_settings.exists(keys[i]))
			println("Missing default skill value for " + keys[i]);
		
		if (currentValue == defaultValue) {
			g_EngineFuncs.ServerCommand(keys[i] + " " + classicValue + ";");
		}
	}
	g_EngineFuncs.ServerExecute();
}

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "w00tguy" );
	g_Module.ScriptInfo.SetContactInfo( "w00tguy123 - forums.svencoop.com" );
	
	g_Hooks.RegisterHook( Hooks::Player::ClientSay, @AutoClassicModeSay );
	
	default_skill_settings = loadSkillSettings(plugin_path + "skill.cfg");
	classic_skill_settings = loadSkillSettings(plugin_path + "skill_classic.cfg");
	classic_maps = loadMapList(plugin_path + "classic_maps.txt");
	op4_maps = loadMapList(plugin_path + "op4_maps.txt");
	bshift_maps = loadMapList(plugin_path + "bshift_maps.txt");
	println("AutoClassicMode: Map lists loaded");
}

void MapInit()
{
	// classic mode votes will only restart the map but not change anything. Might as well disable it.
	g_EngineFuncs.ServerCommand("mp_voteclassicmoderequired -1;\n");
	g_EngineFuncs.ServerExecute();

	isClassicMap = classic_maps.exists(g_Engine.mapname);
	
	mapType = MAP_HALF_LIFE;
	if (isClassicMap)
	{
		if (op4_maps.exists(g_Engine.mapname))
			mapType = MAP_OPPOSING_FORCE;
		else if (bshift_maps.exists(g_Engine.mapname))
			mapType = MAP_BLUE_SHIFT;
	}
		
	if (g_force_mode == MODE_ALWAYS_ON)
		isClassicMap = true;
	else if (g_force_mode == MODE_ALWAYS_OFF)
		isClassicMap = false;
	
	println("IS CLASSIC MAP PLUGIN? " + isClassicMap); 
	
	if (isClassicMap)
	{
		// weaponmode_mp5 breaks the GL if enabled
		g_EngineFuncs.ServerCommand("weaponmode_mp5 0;\n");
		g_EngineFuncs.ServerExecute();
		
		execClassicSkillSettings();
	}
	
	dictionary keys;
	keys["targetname"] = "AutoClassicModeTrigger";
	keys["m_iszScriptFile"] = "AutoClassicMode";
	keys["m_iszScriptFunctionName"] = "AutoClassicMode::MapInit";
	keys["m_iMode"] = "1";
	CBaseEntity@ classicTrigger = g_EntityFuncs.CreateEntity("trigger_script", keys, true);
	int mapInfo = (isClassicMap ? 1 : 0) + (mapType << 1);
	classicTrigger.pev.rendermode = mapInfo;
	
	classicTrigger.Think();
	g_EntityFuncs.FireTargets("AutoClassicModeTrigger", classicTrigger, classicTrigger, USE_ON, 0.0f);
	g_EntityFuncs.Remove(classicTrigger);
	
	if (isClassicMap and !g_basic_mode)
	{
		keys["targetname"] = "game_playerspawn";
		keys["m_iszScriptFunctionName"] = "AutoClassicMode::PlayerSpawn";
		g_EntityFuncs.CreateEntity("trigger_script", keys, true);
		
		keys["targetname"] = "game_playerdie";
		keys["m_iszScriptFunctionName"] = "AutoClassicMode::PlayerDie";
		g_EntityFuncs.CreateEntity("trigger_script", keys, true);
	}
}

void MapActivate()
{
	if (isClassicMap and !g_basic_mode)
	{
		dictionary keys;
		keys["targetname"] = "AutoClassicModeTrigger";
		keys["m_iszScriptFile"] = "AutoClassicMode";
		keys["m_iszScriptFunctionName"] = "AutoClassicMode::MapActivate";
		keys["m_iMode"] = "1";
		CBaseEntity@ classicTrigger = g_EntityFuncs.CreateEntity("trigger_script", keys, true);
		
		classicTrigger.Think();
		g_EntityFuncs.FireTargets("AutoClassicModeTrigger", classicTrigger, classicTrigger, USE_ON, 0.0f);
		g_EntityFuncs.Remove(classicTrigger);
	}
}

bool doCommand(CBasePlayer@ plr, const CCommand@ args)
{	
	bool isAdmin = g_PlayerFuncs.AdminLevel(plr) >= ADMIN_YES;

	if ( args.ArgC() > 0 )
	{
		if (args[0] == ".classic" or args[0] == ".cm")
		{
			if (args.ArgC() > 1)
			{
				if (args[1] == "1" or args[1] == "on")
				{
					if (g_force_mode != MODE_ALWAYS_ON)
						g_PlayerFuncs.SayTextAll(plr, "Classic mode is now ON\n");
					else
						g_PlayerFuncs.SayText(plr, "Classic mode is already set to ON\n");
					g_force_mode = MODE_ALWAYS_ON;
				}
				else if (args[1] == "0" or args[1] == "off")
				{
					if (g_force_mode != MODE_ALWAYS_OFF)
						g_PlayerFuncs.SayTextAll(plr, "Classic mode is now OFF\n");
					else
						g_PlayerFuncs.SayText(plr, "Classic mode is already set to OFF\n");
					g_force_mode = MODE_ALWAYS_OFF;
				}
				else if (args[1] == "2" or args[1] == "auto")
				{
					if (g_force_mode != MODE_AUTO)
						g_PlayerFuncs.SayTextAll(plr, "Classic mode is now AUTO.\n");
					else
						g_PlayerFuncs.SayText(plr, "Classic mode is already set to AUTO\n");
					g_force_mode = MODE_AUTO;
				}
				return true;
			}
			else
			{
				string msg = "Classic mode is ";
				switch(g_force_mode)
				{
					case MODE_ALWAYS_OFF:
						msg += "OFF";
						break;
					case MODE_ALWAYS_ON:
						msg += "ON";
						break;
					case MODE_AUTO:
					default:
						msg += "AUTO. ";
						if (isClassicMap)
							msg += "This is a classic map.";
						else
							msg += "This is a modern map.";
				}		
				
				g_PlayerFuncs.SayText(plr, msg + "\n");
				return true;
			}
			
		}
	}
	return false;
}

HookReturnCode AutoClassicModeSay( SayParameters@ pParams )
{
	CBasePlayer@ plr = pParams.GetPlayer();
	const CCommand@ args = pParams.GetArguments();	
	if (doCommand(plr, args))
	{
		pParams.ShouldHide = true;
		return HOOK_HANDLED;
	}
	return HOOK_CONTINUE;
}