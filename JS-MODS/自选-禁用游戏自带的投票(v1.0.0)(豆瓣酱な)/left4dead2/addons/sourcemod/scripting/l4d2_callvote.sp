/*
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 */
#pragma semicolon 1			//添加结束符.
#pragma newdecls required	//强制新语法.
#include <sourcemod>		//加载函数库.
#define PLUGIN_VERSION		"1.0.0"	//定义插件版本.
//定义全局变量.
int    g_iChangeAlltalk, g_iChangeChapter, g_iChangeDifficulty, g_iChangeMission, g_iChangePlayerKick, g_iChangeRestartGame, g_iChangeReturnTolobby;
ConVar g_hChangeAlltalk, g_hChangeChapter, g_hChangeDifficulty, g_hChangeMission, g_hChangePlayerKick, g_hChangeRestartGame, g_hChangeReturnTolobby;
//定义插件信息.
public Plugin myinfo =  
{
	name = "l4d2_callvote",
	author = "豆瓣酱な",
	description = "阻止游戏自带的投票功能.",
	version = PLUGIN_VERSION,
	url = "N/A"
};
//插件开始.
public void OnPluginStart()
{
	g_hChangeAlltalk		= CreateConVar("l4d2_enabled_change_alltalk", "0", "启用全局通话投票? 0=禁用, 1=启用.");
	g_hChangeChapter		= CreateConVar("l4d2_enabled_change_chapter", "0", "启用更换章节投票? 0=禁用, 1=启用.");
	g_hChangeDifficulty		= CreateConVar("l4d2_enabled_change_difficulty", "0", "启用更换难度投票? 0=禁用, 1=启用.");
	g_hChangeMission		= CreateConVar("l4d2_enabled_change_mission", "0", "启用开始新图投票? 0=禁用, 1=启用.");
	g_hChangePlayerKick		= CreateConVar("l4d2_enabled_change_playerkick", "0", "启用踢出玩家投票? 0=禁用, 1=启用.");
	g_hChangeRestartGame	= CreateConVar("l4d2_enabled_change_restartgame", "0", "启用重新开始投票? 0=禁用, 1=启用.");
	g_hChangeReturnTolobby	= CreateConVar("l4d2_enabled_change_returntolobby", "0", "启用返回大厅投票? 0=禁用, 1=启用.");
	
	g_hChangeAlltalk.AddChangeHook(ConVarChangedHook);
	g_hChangeChapter.AddChangeHook(ConVarChangedHook);
	g_hChangeDifficulty.AddChangeHook(ConVarChangedHook);
	g_hChangeMission.AddChangeHook(ConVarChangedHook);
	g_hChangePlayerKick.AddChangeHook(ConVarChangedHook);
	g_hChangeRestartGame.AddChangeHook(ConVarChangedHook);
	g_hChangeReturnTolobby.AddChangeHook(ConVarChangedHook);
	
	AutoExecConfig(true, "l4d2_callvote");//生成指定文件名的CFG.
	AddCommandListener(Listener_CallVote, "callvote");
}
//地图开始.
public void OnMapStart()
{
	GetConVarChange();
}
//参数更改回调.
void ConVarChangedHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetConVarChange();
}
//赋值到全局变量.
void GetConVarChange()
{
	g_iChangeAlltalk = g_hChangeAlltalk.IntValue;
	g_iChangeChapter = g_hChangeChapter.IntValue;
	g_iChangeDifficulty = g_hChangeDifficulty.IntValue;
	g_iChangeMission = g_hChangeMission.IntValue;
	g_iChangePlayerKick = g_hChangePlayerKick.IntValue;
	g_iChangeRestartGame = g_hChangeRestartGame.IntValue;
	g_iChangeReturnTolobby = g_hChangeReturnTolobby.IntValue;
}
//监听回调.
Action Listener_CallVote(int client, const char[] command, int args)
{
	char Msg[128];
	//获取callvote命令的参数并将其存储在变量中.
	GetCmdArg(1, Msg, sizeof(Msg));
	//踢人时候的对象.
	//GetCmdArg(2, g_sTarget[client], sizeof(g_sTarget[]));

	if(!IsValidClient(client) || IsFakeClient(client))
		return Plugin_Continue;
	
	if(strcmp(Msg, "kick", false) == 0)
	{
		if (g_iChangePlayerKick == 0)
		{
			PrintToChat(client,"\x04[提示]\x05游戏自带的投票踢出玩家已禁用.");//聊天窗提示.
			return Plugin_Handled;
		}
	}
	else if(strcmp(Msg, "returntolobby", false) == 0)
	{
		if (g_iChangeReturnTolobby == 0)
		{
			PrintToChat(client,"\x04[提示]\x05游戏自带的投票返回大厅已禁用.");//聊天窗提示.
			return Plugin_Handled;
		}
	}
	else if(strcmp(Msg, "changealltalk", false) == 0)
	{
		if (g_iChangeAlltalk == 0)
		{
			PrintToChat(client,"\x04[提示]\x05游戏自带的全局通话投票已禁用.");//聊天窗提示.
			return Plugin_Handled;
		}
	}
	else if(strcmp(Msg, "restartgame", false) == 0)
	{
		if (g_iChangeRestartGame == 0)
		{
				PrintToChat(client,"\x04[提示]\x05游戏自带的投票重新开始已禁用.");//聊天窗提示.
				return Plugin_Handled;
		}
	}
	else if(strcmp(Msg, "changemission", false) == 0)
	{
		if (g_iChangeMission == 0)
		{
			PrintToChat(client,"\x04[提示]\x05游戏自带的投票开始新图已禁用.");//聊天窗提示.
			return Plugin_Handled;
		}
	}
	else if(strcmp(Msg, "changechapter", false) == 0)
	{
		if (g_iChangeChapter == 0)
		{
			PrintToChat(client,"\x04[提示]\x05游戏自带的投票更换章节已禁用.");//聊天窗提示.
			return Plugin_Handled;
		}
	}
	else if(strcmp(Msg, "changedifficulty", false) == 0)
	{
		if (g_iChangeDifficulty == 0)
		{
			PrintToChat(client,"\x04[提示]\x05游戏自带的投票更改难度已禁用.");//聊天窗提示.
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}
//玩家有效性.
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
