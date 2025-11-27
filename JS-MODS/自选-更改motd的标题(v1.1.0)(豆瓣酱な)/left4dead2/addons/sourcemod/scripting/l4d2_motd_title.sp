
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
 */
#pragma semicolon 1					//添加结束符.
#pragma newdecls required			//强制新语法.
#include <sourcemod>				//加载函数库.
#define PLUGIN_VERSION	"1.1.0"		//插件的版本.
#define TITL_CONTENT	"今日消息"	//标题的内容.

int    g_iMotdEnabled;//定义全局整数变量.
ConVar g_hMotdEnabled;//定义全局句柄变量.
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
	AddCommandListener(Listener_Motd, "motd");//监听指令钩子.
	
	g_hMotdEnabled = CreateConVar("l4d2_motd_enabled", "1", "启用 sm_motd 指令打开公告(默认H键打开). 0=禁用, 1=启用.", FCVAR_NOTIFY);
	g_hMotdEnabled.AddChangeHook(ConVarChanged);//参数更改钩子.
	
	AutoExecConfig(true, "l4d2_motd_enabled");//生成指定文件名的CFG.
}
//配置文件(server.cfg)加载后调用.
public void OnConfigsExecuted()
{
	GetCvars();
}
//参数更改回调.
void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}
//参数赋值到变量.
void GetCvars()
{
	g_iMotdEnabled = g_hMotdEnabled.IntValue;
}
//监听指令回调.
Action Listener_Motd(int client, const char[] command, int argc) 
{
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;

	if(strcmp(command, "motd") == 0)
	{
		if(g_iMotdEnabled == 1)
			ShowMOTDPanel(client, TITL_CONTENT, "motd", 1);//设置新的标题并打开公告界面.
		return Plugin_Stop;//阻止原始指令执行.
	}
	return Plugin_Continue;
}