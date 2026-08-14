/*
 *
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v1.2.0
 *
 *	1:更改了下插件名称.
 *
 */
#pragma semicolon 1			//添加结束符.
#include <sourcemod>		//加载函数库.
#pragma newdecls required	//强制新语法.

#define PLUGIN_VERSION	"1.2.0"	//定义插件版本.
#define MAX_PLAYERS		32		//定义数组大小.

int g_iObserverMode[MAX_PLAYERS+1];//定义全局整数数组变量.
float g_fDoubleClickTime[MAX_PLAYERS+1];//定义全局浮点数组变量.
//定义插件信息.
public Plugin myinfo = 
{
	name 			= "l4d2_observer_mode",
	author 			= "豆瓣酱な",
	description 	= "闲置状态快速双击鼠标右键切换自由视角(或单击空格键)",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}
//插件开始.
public void OnPluginStart()
{
	//闲置状态快速双击鼠标右键切换自由视角(或单击空格键).
	AddCommandListener(CommandListener_SpecPrev, "spec_prev");
}
//监听回调.
//玩家闲置时快速双击鼠标右键打开自由视角,再次单击鼠标右键恢复.
Action CommandListener_SpecPrev(int client, char[] command, int argc)
{
	if(client <= 0 || !IsClientInGame(client) || GetClientTeam(client) != 1 || !iGetBotOfIdlePlayer(client))
		return Plugin_Continue;

	float fTime = GetEngineTime();
	if(fTime - g_fDoubleClickTime[client] < 0.3)
	{
		if (!IsObserverMode(client, 6))
		{
			g_iObserverMode[client] = GetEntProp(client, Prop_Send, "m_iObserverMode");
			PrintCenterText(client, "当前为自由视角.");
			SetEntProp(client, Prop_Send, "m_iObserverMode", 6);
		}
		else
		{
			switch (g_iObserverMode[client])
			{
				case 4:
				{
					PrintCenterText(client, "当前为第一人称视角.");
					SetEntProp(client, Prop_Send, "m_iObserverMode", g_iObserverMode[client]);
				}
				case 5:
				{
					PrintCenterText(client, "当前为第三人称视角.");
					SetEntProp(client, Prop_Send, "m_iObserverMode", g_iObserverMode[client]);
				}
				default:
				{
					PrintCenterText(client, "当前为第三人称视角.");
					SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
				}
			}
		}
	}
	g_fDoubleClickTime[client] = fTime;
	return Plugin_Continue;
}
//判断玩家视角模式.
bool IsObserverMode(int client, int iObserver)
{
	return GetEntProp(client, Prop_Send, "m_iObserverMode") == iObserver;
}
//返回闲置玩家对应的电脑.
stock int iGetBotOfIdlePlayer(int client)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && IsClientIdle(i) == client)
			return i;
	
	return 0;
}
//返回电脑幸存者对应的玩家.
stock int IsClientIdle(int client)
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}