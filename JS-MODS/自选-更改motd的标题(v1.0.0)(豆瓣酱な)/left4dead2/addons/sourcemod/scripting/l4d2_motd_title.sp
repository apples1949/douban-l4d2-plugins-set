
/*
 *
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 */
#pragma semicolon 1					//添加结束符.
#pragma newdecls required			//强制新语法.
#include <sourcemod>				//加载函数库.
#define PLUGIN_VERSION	"1.0.0"		//插件的版本.
#define TITL_CONTENT	"今日消息:"	//标题的内容.
#define MOTDPANEL_TYPE_INDEX	1	/**< Msg is auto determined by the engine */
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
	AddCommandListener(Listener_Motd, "motd");//监听命令.
}
//监听回调.
Action Listener_Motd(int client, char[] command, int argc) 
{
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;

	if(strcmp(command, "motd") == 0)
	{
		RequestFrame(DelayShowMOTDPanel, GetClientUserId(client));//下一个数据包执行.
		return Plugin_Stop;//阻止原始指令执行.
	}
	return Plugin_Continue;
}
//下一个数据包回调.
void DelayShowMOTDPanel(int client)
{
	if ((client = GetClientOfUserId(client)))
		if (IsClientInGame(client) && !IsFakeClient(client))
			ShowMOTDPanel(client, TITL_CONTENT, "motd", MOTDPANEL_TYPE_INDEX);
}