
/*
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
//加载函数库.
#include <sourcemod>
#include <sdktools>

#define MAX_PLAYERS		32	//定义数组大小.
#define PLUGIN_VERSION		"1.0.0"	//定义插件版本.

int  g_iChangeNameCount[MAX_PLAYERS+1];//定义全局整数数组.
char g_sOldName[MAX_PLAYERS+1][32];//定义全局字符串数组.

int    g_iChangeNameNumber;//定义全局整数变量.
ConVar g_hChangeNameNumber;//定义全局句柄变量.
bool g_bLateLoad;//定义全局布尔变量.
//插件开始之前调用.
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}
//定义插件信息.
public Plugin myinfo =  
{
	name = "l4d2_change_name",
	author = "豆瓣酱な",
	description = "禁止玩家通过控制台更改游戏名称",
	version = PLUGIN_VERSION,
	url = "N/A"
};
//插件开始时.
public void OnPluginStart()
{
	HookEvent("player_changename", Event_PlayerChangename);//玩家更改名称.
	HookUserMessage(GetUserMessageId("SayText2"), SayText2, true);//阻止显示改名信息.

	g_hChangeNameNumber = CreateConVar("l4d2_change_name", "5", "设置玩家连续改名多少次后自动踢出. 0=禁用.", FCVAR_NOTIFY);
	g_hChangeNameNumber.AddChangeHook(ConVarValueChanged);
	AutoExecConfig(true, "l4d2_change_name");

	if (g_bLateLoad)//如果是延迟加载插件.
	{
		for (int i = 1; i <= MaxClients; i++) 
			if (IsClientConnected(i) && !IsFakeClient(i)) 
				FormatEx(g_sOldName[i], sizeof(g_sOldName[]), "%N", i);//格式化玩家名称到字符串.
	}
}
//参数更改回调.
void ConVarValueChanged(ConVar convar, const char[] oldValue, const char[] newValue) 
{
	GetConVarValue();
}
//插件配置加载完成时.
public void OnConfigsExecuted()
{
	GetConVarValue();
}
//重新赋值.
void GetConVarValue()
{
	g_iChangeNameNumber = g_hChangeNameNumber.IntValue;
}
//玩家离开.
public void OnClientDisconnect(int client)
{   
	if(!IsFakeClient(client))
		g_sOldName[client][0] = '\0';//重置字符串内容.
}
//玩家连接游戏时.
public void OnClientAuthorized(int client, const char[] auth)
{
	if(!IsFakeClient(client))//真实玩家.
	{
		g_iChangeNameCount[client] = 0;
		FormatEx(g_sOldName[client], sizeof(g_sOldName[]), "%N", client);//格式化玩家名称到字符串.
	}
}
//玩家更改名称.
void Event_PlayerChangename(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client > 0 && client <= MaxClients && !IsFakeClient(client))
	{
		if(g_iChangeNameNumber > 0)
		{
			char sNewName[32];
			event.GetString("newname", sNewName, sizeof(sNewName));//获取新的玩家名称.
			if(strcmp(sNewName, g_sOldName[client]) != 0)//新名称跟旧名称不同.
			{
				g_iChangeNameCount[client]++;//增加改名次数.
				SetClientInfo(client, "name", g_sOldName[client]);//重新设置玩家名称.

				if(g_iChangeNameCount[client] < g_iChangeNameNumber)
					ReplyToCommand(client, "[警告]本服禁止玩家通过控制台更改游戏名称(%d/%d)", g_iChangeNameCount[client], g_iChangeNameNumber);
				else
					KickClient(client, "本服自动踢出通过控制台连续改名 %d 次的玩家", g_iChangeNameNumber);
			}
		}
	}
}
//阻止显示改名信息.
Action SayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	static char buffer[128];
	buffer[0] = '\0';

	msg.ReadString(buffer, sizeof(buffer));
	msg.ReadString(buffer, sizeof(buffer));
	if(strcmp(buffer, "#Cstrike_Name_Change") == 0)
		return Plugin_Handled;

	return Plugin_Continue;
}
//判断玩家有效.
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
