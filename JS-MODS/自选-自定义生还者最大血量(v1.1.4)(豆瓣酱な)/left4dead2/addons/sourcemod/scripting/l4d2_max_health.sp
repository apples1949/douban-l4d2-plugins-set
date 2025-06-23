/*
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v1.0.1
 *
 *	1:优化了一些代码.
 *
 *	v1.0.2
 *
 *	1:修复了一些问题.
 *
 *	v1.0.3
 *
 *	1:更改最大血量cvar后立即设置全部生还者最大血量.
 *	2:止痛药使用血量限制同步更改(设置的最大血量减1).
 *
 *	v1.1.4
 *
 *	1:精简一些无用代码.
 *	2:适配官方虚血模式.
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <sdkhooks>

#define DEBUG		0		//0=禁用调试信息,1=显示调试信息.
#define GAMEDATA			"l4d2_max_health"
#define PLUGIN_VERSION		"1.1.4"

ConVar 
	g_hSurvivorMaxHeal,
	g_hSurvivorRespawn,
	g_hSurvivorThreshold;

bool 
	g_bFirstPlayer,
	g_bStartRestore,
	g_bSpectator[MAXPLAYERS+1],
	g_bMaxHealth[MAXPLAYERS+1],
	g_bDataRestore[MAXPLAYERS+1];

//定义插件信息.
public Plugin myinfo =  
{
	name = "l4d2_max_health",
	author = "豆瓣酱な",
	description = "自定义生还者血量",
	version = PLUGIN_VERSION,
	url = "N/A"
};
//插件开始时.
public void OnPluginStart()
{
	LoadingGameData();

	g_hSurvivorMaxHeal = FindConVar("first_aid_kit_max_heal");//设置生还者最大血量上限(默认:100).
	g_hSurvivorRespawn = FindConVar("z_survivor_respawn_health");//设置生还者重生血量上限(默认:50).
	g_hSurvivorThreshold = FindConVar("pain_pills_health_threshold");//使用止痛药的血量限制(默认值:99).
	g_hSurvivorMaxHeal.AddChangeHook(ConVarMaxHealChanged);

	HookEvent("player_team", 		Event_PlayerTeam);//玩家转换队伍.
	HookEvent("player_bot_replace", Event_PlayerBotReplace, EventHookMode_Pre);
	HookEvent("defibrillator_used", Event_DefibrillatorUsed, EventHookMode_Pre);//幸存者使用电击器救活队友.
	HookEvent("survivor_rescued", 	Event_SurvivorRescued, EventHookMode_Pre);//幸存者在营救门复活.
	HookEvent("player_first_spawn", Event_PlayerFirstSpawn);//玩家首次加入游戏.
}
//指定cvar更改时触发的回调.
public void ConVarMaxHealChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (strcmp(oldValue, newValue) != 0)
	{
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && GetClientTeam(i) == 2)
				SetEntProp(i, Prop_Data, "m_iMaxHealth", StringToInt(newValue));

		SetConVarInt(g_hSurvivorThreshold, StringToInt(newValue) - 1, false, false);//设置新的止痛药血量使用限制.
	}
		
	#if DEBUG
	PrintToChatAll("\x04[提示]\x03旧血量上限(%s),新血量上限(%s).", oldValue, newValue);//聊天窗提示.
	#endif
}
void LoadingGameData()
{
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	CreateDetour(hGameData, OnGoAwayFromKeyboard_Pre, "CTerrorPlayer::GoAwayFromKeyboard", false);
	CreateDetour(hGameData, OnGoAwayFromKeyboard_Post, "CTerrorPlayer::GoAwayFromKeyboard", true);

	CreateDetour(hGameData, OnSetHumanSpectator_Post, "SurvivorBot::SetHumanSpectator", true);

	CreateDetour(hGameData, OnTakeOverBot_Post, "CTerrorPlayer::TakeOverBot", true);

	CreateDetour(hGameData, OnPlayerSaveDataRestore_Pre, "PlayerSaveData::Restore", false);
	CreateDetour(hGameData, OnPlayerSaveDataRestore_Post, "PlayerSaveData::Restore", true);

	CreateDetour(hGameData, OnCDirectorRestart_Pre, "CDirector::Restart", false);
	CreateDetour(hGameData, OnCDirectorRestart_Post, "CDirector::Restart", true);

	CreateDetour(hGameData, OnCTerrorPlayerRoundRespawn_Post, "CTerrorPlayer::RoundRespawn", true);

	CreateDetour(hGameData,	OnTransitionRestore_Pre,	"CTerrorPlayer::TransitionRestore", false);
	CreateDetour(hGameData,	OnTransitionRestore_Post,	"CTerrorPlayer::TransitionRestore", true);

	delete hGameData;
}
void CreateDetour(Handle gameData, DHookCallback CallBack, const char[] sName, const bool post)
{
	Handle hDetour = DHookCreateFromConf(gameData, sName);
	if(!hDetour)
		SetFailState("Failed to find \"%s\" signature.", sName);
		
	if(!DHookEnableDetour(hDetour, post, CallBack))
		SetFailState("Failed to detour \"%s\".", sName);
		
	delete hDetour;
}
public void OnMapStart() 
{
	g_bFirstPlayer = false;
	for (int i = 1; i <= MaxClients; i++)
		ResetPlayerVariables(i);
}
//玩家转换队伍.
void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int iTeam = event.GetInt("team");
	
	if(IsValidClient(client) && !IsFakeClient(client) && iTeam == 2 && g_bFirstPlayer == false)//没有还原数据时首个玩家加入游戏.
	{
		#if DEBUG
		PrintToChatAll("\x04[提示]\x03%N\x05首个幸存者(%s).", client, g_bFirstPlayer ? "true" : "false");
		#endif

		RequestFrame(SetFirstHealth, GetClientUserId(client));//首个玩家加入生还者时是0团队,所以这里使用下一帧.
	}
}
//转换队伍的下一帧回调设置血量.
stock void SetFirstHealth(int client)
{
	if((client = GetClientOfUserId(client)) && !IsFakeClient(client) && GetClientTeam(client) == 2)
	{
		g_bFirstPlayer = true;
		SetPlayerHealth(client, GetConVarInt(g_hSurvivorMaxHeal));
		SetEntProp(client, Prop_Data, "m_iMaxHealth", GetConVarInt(g_hSurvivorMaxHeal));

		#if DEBUG
		int iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
		int iMaxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		PrintToChatAll("\x04[提示2]\x05生还者血量(%d)(%N)(%d/%d).", GetClientTeam(client), client, iHealth, iMaxHealth);
		#endif
	}
}
//营救门复活队友.
void Event_SurvivorRescued(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));

	if(IsValidClient(client) && GetClientTeam(client) == 2)
	{
		SetPlayerHealth(client, GetConVarInt(g_hSurvivorRespawn));
		SetEntProp(client, Prop_Data, "m_iMaxHealth", GetConVarInt(g_hSurvivorMaxHeal));
	}
}
//电击器救活队友.
void Event_DefibrillatorUsed(Event event, const char[] name, bool dontBroadcast)
{
	int subject = GetClientOfUserId(event.GetInt("subject"));

	if(IsValidClient(subject) && GetClientTeam(subject) == 2)
	{
		SetPlayerHealth(subject, GetConVarInt(g_hSurvivorRespawn));
		SetEntProp(subject, Prop_Data, "m_iMaxHealth", GetConVarInt(g_hSurvivorMaxHeal));
	}
}
//玩家复活.
MRESReturn OnCTerrorPlayerRoundRespawn_Post(int pThis, DHookReturn hReturn) 
{
	if(g_bStartRestore == false)//非还原数据时.
	{
		SetPlayerHealth(pThis, GetConVarInt(g_hSurvivorMaxHeal));
		SetEntProp(pThis, Prop_Data, "m_iMaxHealth", GetConVarInt(g_hSurvivorMaxHeal));
	
		#if DEBUG
		PrintToChatAll("\x04[提示Post]\x03玩家复活(%d)(%N).", pThis, pThis);//聊天窗提示.
		#endif
	}
	return MRES_Ignored;
}
//任务失败开始还原数据时.
MRESReturn OnCDirectorRestart_Pre(Address pThis, DHookReturn hReturn) 
{
	g_bStartRestore = true;
	
	for (int i = 1; i <= MaxClients; i++)
		ResetPlayerVariables(i);

	#if DEBUG
	PrintToChatAll("\x04[重开Pre]\x03开始还原.");//聊天窗提示.
	#endif
	return MRES_Ignored;
}
//任务失败完成还原数据时.
MRESReturn OnCDirectorRestart_Post(Address pThis, DHookReturn hReturn) 
{
	g_bStartRestore = false;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			if(g_bMaxHealth[i] == false)
			{
				SetPlayerHealth(i, GetConVarInt(g_hSurvivorMaxHeal));
				SetEntProp(i, Prop_Data, "m_iMaxHealth", GetConVarInt(g_hSurvivorMaxHeal));

				#if DEBUG
				PrintToChatAll("\x04[重开Pre]\x05(%s)索引(%d)名称(%N)值(%s)没有数据.", IsFakeClient(i) ? "假" : "真", i, i, g_bMaxHealth[i] ? "true" : "false");
				#endif
			}
		}
	}

	#if DEBUG
	PrintToChatAll("\x04[重开Post]\x03完成还原.");//聊天窗提示.
	#endif
	return MRES_Ignored;
}
//真玩家数据开始还原.
MRESReturn OnTransitionRestore_Pre(int pThis, DHookReturn hReturn) 
{
	g_bFirstPlayer = true;

	if(IsFakeClient(pThis))
		return MRES_Ignored;
	
	g_bMaxHealth[pThis] = true;
	g_bDataRestore[pThis] = true;

	#if DEBUG
	int iHealth = GetEntProp(pThis, Prop_Data, "m_iHealth");
	int iMaxHealth = GetEntProp(pThis, Prop_Data, "m_iMaxHealth");
	PrintToChatAll("\x04[还原Pre]\x05团队(%d)(%s)索引(%d)(%N)(%d/%d)(%s)开始还原.", GetClientTeam(pThis), IsFakeClient(pThis) ? "假" : "真", 
	pThis, pThis, iHealth, iMaxHealth, g_bMaxHealth[pThis] ? "true" : "false");
	#endif
	return MRES_Ignored;
}
//真玩家数据完成还原.
MRESReturn OnTransitionRestore_Post(int pThis, DHookReturn hReturn) 
{
	if(IsFakeClient(pThis))
		return MRES_Ignored;

	g_bDataRestore[pThis] = false;
	
	if(GetClientTeam(pThis) == 2)
		SetEntProp(pThis, Prop_Data, "m_iMaxHealth", GetConVarInt(g_hSurvivorMaxHeal));//设置最大上限.
	
	#if DEBUG
	int iHealth = GetEntProp(pThis, Prop_Data, "m_iHealth");
	int iMaxHealth = GetEntProp(pThis, Prop_Data, "m_iMaxHealth");
	PrintToChatAll("\x04[还原Post]\x05团队(%d)(%s)索引(%d)(%N)(%d/%d)(%s)完成还原.", GetClientTeam(pThis), IsFakeClient(pThis) ? "假" : "真", 
	pThis, pThis, iHealth, iMaxHealth, g_bMaxHealth[pThis] ? "true" : "false");
	#endif
	return MRES_Ignored;
}
//假玩家过关后开始还原数据时.
MRESReturn OnPlayerSaveDataRestore_Pre(Address pThis, DHookParam hParams)
{
	int player = hParams.Get(1);
	if(!IsFakeClient(player))
		return MRES_Ignored;

	g_bMaxHealth[player] = true;
	g_bDataRestore[player] = true;

	#if DEBUG
	int iHealth = GetEntProp(player, Prop_Data, "m_iHealth");
	int iMaxHealth = GetEntProp(player, Prop_Data, "m_iMaxHealth");
	PrintToChatAll("\x04[还原Pre]\x05团队(%d)(%s)索引(%d)(%N)(%d/%d)(%s)开始还原.", GetClientTeam(player), IsFakeClient(player) ? "假" : "真", 
	player, player, iHealth, iMaxHealth, g_bMaxHealth[player] ? "true" : "false");
	#endif
	return MRES_Ignored;
}
//假玩家过关后完成还原数据时.
MRESReturn OnPlayerSaveDataRestore_Post(Address pThis, DHookParam hParams)
{
	int player = hParams.Get(1);
	if(!IsFakeClient(player))
		return MRES_Ignored;

	g_bDataRestore[player] = false;

	if(GetClientTeam(player) == 2)
		SetEntProp(player, Prop_Data, "m_iMaxHealth", GetConVarInt(g_hSurvivorMaxHeal));//设置最大上限.
		
	#if DEBUG
	int iHealth = GetEntProp(player, Prop_Data, "m_iHealth");
	int iMaxHealth = GetEntProp(player, Prop_Data, "m_iMaxHealth");
	PrintToChatAll("\x04[还原Post]\x05团队(%d)(%s)索引(%d)(%N)(%d/%d)(%s)完成还原.", GetClientTeam(player), IsFakeClient(player) ? "假" : "真", 
	player, player, iHealth, iMaxHealth, g_bMaxHealth[player] ? "true" : "false");
	#endif
	return MRES_Ignored;
}
//玩家首次加入.
void Event_PlayerFirstSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(IsValidClient(client) && IsFakeClient(client) && GetClientTeam(client) == 2)
	{
		SetPlayerHealth(client, GetConVarInt(g_hSurvivorMaxHeal));//这个事件设置的血量会被过渡还原或闲置覆盖.
		SetEntProp(client, Prop_Data, "m_iMaxHealth", GetConVarInt(g_hSurvivorMaxHeal));
		
		#if DEBUG
		g_bMaxHealth[client] = true;
		int iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
		int iMaxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		PrintToChatAll("\x04[首次加入]\x05索引(%d)(%N)血量(%d/%d)值(%s).", 
		client, client, iHealth, iMaxHealth, g_bMaxHealth[client] ? "true" : "false");
		#endif
	}
}
//玩家开始闲置.
MRESReturn OnGoAwayFromKeyboard_Pre(int pThis, DHookReturn hReturn)
{
	g_bSpectator[pThis] = true;//玩家开始闲置.
	#if DEBUG
	PrintToChatAll("\x04[提示Pre]\x05(%d)(%N)闲置.", pThis, pThis);
	#endif
	return MRES_Ignored;
}
//玩家完成闲置.
MRESReturn OnGoAwayFromKeyboard_Post(int pThis, DHookReturn hReturn) 
{
	g_bSpectator[pThis] = false;//玩家完成闲置.

	#if DEBUG
	int iBot = iGetBotOfIdlePlayer(pThis);//闲置也能触发.
	int iHealth = GetEntProp(iBot, Prop_Data, "m_iHealth");
	int iMaxHealth = GetEntProp(iBot, Prop_Data, "m_iMaxHealth");
	PrintToChatAll("\x04[闲置Post]\x05(%d)(%d)(%d)(%d/%d)(%N)(%N).", 
	GetClientTeam(pThis), pThis, iBot != 0 ? iBot : pThis, iHealth, iMaxHealth, pThis, iBot != 0 ? iBot : pThis);
	#endif
	return MRES_Ignored;
}
//电脑生还者接管玩家.
void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast)
{
	int bot = GetClientOfUserId(event.GetInt("bot"));
	int player = GetClientOfUserId(event.GetInt("player"));
	if(IsValidClient(bot) && GetClientTeam(bot) == 2)
	{
		if(IsValidClient(player) && GetClientTeam(player) == 2)
		{
			if(g_bSpectator[player] == false)
			{
				SetEntProp(bot, Prop_Data, "m_iMaxHealth", GetConVarInt(g_hSurvivorMaxHeal));
				
				#if DEBUG
				int iHealth = GetEntProp(bot, Prop_Data, "m_iHealth");
				int iMaxHealth = GetEntProp(bot, Prop_Data, "m_iMaxHealth");
				PrintToChatAll("\x04[替换]\x03索引(%d)(%d)(%d/%d)(%N)(%N)\x05电脑→玩家.", 
				bot, player, iHealth, iMaxHealth, bot, player);//聊天窗提示.
				#endif
			}
		}
	}
}
MRESReturn OnSetHumanSpectator_Post(int pThis, DHookParam hParams) 
{
	int iBot = IsClientIdle(pThis);//闲置也能触发.
	if(iBot != 0 && iBot != pThis && g_bDataRestore[iBot] == false)//还原数据时不执行.
	{
		SetEntProp(pThis, Prop_Data, "m_iMaxHealth", GetConVarInt(g_hSurvivorMaxHeal));//设置电脑生还者最大血量.
		
		#if DEBUG
		int iHealth = GetEntProp(pThis, Prop_Data, "m_iHealth");
		int iMaxHealth = GetEntProp(pThis, Prop_Data, "m_iMaxHealth");
		PrintToChatAll("\x04[接管Post]\x05(%d)(%d)(%d/%d)(%N)(%N)值(%s)(%s).", 
		pThis, iBot, iHealth, iMaxHealth, pThis, iBot, g_bMaxHealth[pThis] ? "true" : "false", g_bMaxHealth[iBot] ? "true" : "false");
		#endif
	}
	return MRES_Ignored;
}
MRESReturn OnTakeOverBot_Post(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	if(GetClientTeam(pThis) == 2 && IsPlayerAlive(pThis) && g_bDataRestore[pThis] == false)
	{
		SetEntProp(pThis, Prop_Data, "m_iMaxHealth", GetConVarInt(g_hSurvivorMaxHeal));
		
		#if DEBUG
		int iHealth = GetEntProp(pThis, Prop_Data, "m_iHealth");
		int iMaxHealth = GetEntProp(pThis, Prop_Data, "m_iMaxHealth");
		PrintToChatAll("\x04[加入Post]\x05团队(%d)(%s)索引(%d)血量(%d/%d)名称(%N)值(%s).", 
		GetClientTeam(pThis), IsPlayerAlive(pThis) ? "活" : "死", pThis, iHealth, iMaxHealth, pThis, g_bMaxHealth[pThis] ? "true" : "false");
		#endif
	}
	return MRES_Ignored;
}
//返回闲置玩家对应的电脑.
stock int iGetBotOfIdlePlayer(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && IsClientIdle(i) == client)
			return i;
	}
	return 0;
}
//返回电脑幸存者对应的玩家.
stock int IsClientIdle(int client)
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}
//判断玩家有效.
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
//重置玩家变量.
stock void ResetPlayerVariables(int client)
{
	g_bSpectator[client] = false;
	g_bMaxHealth[client] = false;
	g_bDataRestore[client] = false;
}
//设置生还者血量.
stock void SetPlayerHealth(int client, int health) 
{
	if(strcmp(GetGameModeName(), "mutation3", false) == 0)
	{
		SetPlayerTempHealth(client, 0); //防止有虚血时give health会超过上限的问题.
		SetPlayerTempHealth(client, health - GetEntProp(client, Prop_Data, "m_iHealth")); //防止有虚血时give health会超过上限的问题.
	}
	else
	{
		SetEntProp(client, Prop_Data, "m_iHealth", health);
		SetPlayerTempHealth(client, 0); //防止有虚血时give health会超过上限的问题.
	}
}
//设置虚血血量.
stock void SetPlayerTempHealth(int client, int tempHealth)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", float(tempHealth));
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
}
//获取游戏模式名称.
stock char[] GetGameModeName()
{
	char sName[32];
	GetConVarString(FindConVar("mp_gamemode"), sName, sizeof(sName));
	return sName;
}