
/*
 *
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v1.1.0
 *
 *	1:增加一个ConVar参数开关指令打开motd功能.
 *
 *	v1.2.0
 *
 *	1:集成原版参数可设置是否自动开启显示.
 *
 *	v1.3.1
 *
 *	1:修复已知的一些问题.
 *	2:新增签名功能区分自动和手动打开时显示的标题内容.
 *
 */
#pragma semicolon 1					//添加结束符.
#pragma newdecls required			//强制新语法.
#include <sourcemod>				//加载函数库.
#include <dhooks>					//加载函数库.
#define PLUGIN_VERSION	"1.3.1"		//插件的版本.
#define TITL_COMMAND	"今日消息"	//指令显示的标题内容.
#define TITL_AUTOMATIC	"今日消息"	//自动显示的标题内容.
#define GAMEDATA		"l4d2_motd_title"

int    g_iMotdCommand;//定义全局整数变量.
ConVar g_hMotdCommand;//定义全局句柄变量.
ConVar g_hMotdEnabled;//定义全局句柄变量.
ConVar g_hMotdAutomatic;//定义全局句柄变量.
//插件信息.
public Plugin myinfo = 
{
	name 			= "l4d2_motd_title",
	author 			= "豆瓣酱な",
	description 	= "更改motd的标题内容.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}
//插件开始时.
public void OnPluginStart()
{
	LoadingGameData();
	
	AddCommandListener(Listener_Motd, "motd");//监听指令钩子.

	g_hMotdEnabled = FindConVar("motd_enabled");
	
	g_hMotdCommand		= CreateConVar("l4d2_motd_command", 	"1", "启用玩家使用指令打开公告(默认H键). 0=禁用, 1=启用.", FCVAR_NOTIFY);
	g_hMotdAutomatic	= CreateConVar("l4d2_motd_automatic", 	"1", "启用玩家加入后自动显示公告信息. 0=禁用, 1=启用.", FCVAR_NOTIFY);
	g_hMotdCommand.AddChangeHook(ConVarChangedCommand);//参数更改钩子.
	g_hMotdAutomatic.AddChangeHook(ConVarChangedAutomatic);//参数更改钩子.
	
	AutoExecConfig(true, "l4d2_motd_enabled");//生成指定文件名的CFG.
}
//配置文件(server.cfg)加载后调用.
public void OnConfigsExecuted()
{
	g_iMotdCommand = g_hMotdCommand.IntValue;
}
//参数更改回调.
void ConVarChangedCommand(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iMotdCommand = g_hMotdCommand.IntValue;
}
//参数更改回调.
void ConVarChangedAutomatic(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_hMotdEnabled.IntValue = g_hMotdAutomatic.IntValue;
}
//监听指令回调.
Action Listener_Motd(int client, const char[] command, int argc) 
{
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;

	if(strcmp(command, "motd") == 0)
	{
		if(g_iMotdCommand == 1)
			ShowMOTDPanel(client, TITL_COMMAND, "motd", 1);//设置新的标题并打开公告界面.
		return Plugin_Stop;//阻止原始指令执行.
	}
	return Plugin_Continue;
}
//加载签名文件.
void LoadingGameData()
{
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	CreateDetour(hGameData, OnShowMOTD_Pre, "CCSPlayer::ShowMOTD", false);
	CreateDetour(hGameData, OnShowMOTD_Post, "CCSPlayer::ShowMOTD", true);
}
//创建指定名称的钩子.
void CreateDetour(Handle gameData, DHookCallback CallBack, const char[] sName, const bool post)
{
	Handle hDetour = DHookCreateFromConf(gameData, sName);
	if(!hDetour)
		SetFailState("Failed to find \"%s\" signature.", sName);
		
	if(!DHookEnableDetour(hDetour, post, CallBack))
		SetFailState("Failed to detour \"%s\".", sName);
		
	delete hDetour;
}
//显示motd今日信息.
MRESReturn OnShowMOTD_Pre(int pThis, DHookReturn hReturn) 
{
	if(IsFakeClient(pThis))
		return MRES_Ignored;
	
	if(g_hMotdEnabled.IntValue == 1)
	{
		DHookSetReturn(hReturn, 1);//阻止原始标题.
		return MRES_Supercede;
	}
	return MRES_Ignored;
}
//显示motd今日信息.
MRESReturn OnShowMOTD_Post(int pThis, DHookReturn hReturn) 
{
	if(IsFakeClient(pThis))
		return MRES_Ignored;
	
	if(g_hMotdEnabled.IntValue == 1)
		ShowMOTDPanel(pThis, TITL_AUTOMATIC, "motd", 1);//设置新的标题并打开公告界面.
	return MRES_Ignored;
}
