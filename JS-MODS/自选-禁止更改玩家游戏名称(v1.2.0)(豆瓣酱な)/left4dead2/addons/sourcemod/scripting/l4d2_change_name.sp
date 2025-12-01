
/*
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v1.1.0
 *
 *	1:更改为签名方法.
 *
 *	v1.2.0
 *
 *	1:增加一个转发给需要临时使用 SetClientName() 函数更改玩家名称.
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
//加载函数库.
#include <sourcemod>
#include <dhooks>

#define GAMEDATA		"l4d2_change_name"
#define PLUGIN_VERSION		"1.2.0"	//定义插件版本.

GlobalForward g_hOnChangeName;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("l4d2_change_name");
	g_hOnChangeName = new GlobalForward("OnChangeClientName", ET_Event, Param_Cell, Param_String, Param_String);
	
	return APLRes_Success;
}
//定义插件信息.
public Plugin myinfo =  
{
	name = "l4d2_change_name",
	author = "豆瓣酱な",
	description = "禁止更改玩家游戏名称",
	version = PLUGIN_VERSION,
	url = "N/A"
};
//插件开始时.
public void OnPluginStart()
{
	HookUserMessage(GetUserMessageId("SayText2"), SayText2, true);
	
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	CreateDetour(hGameData, OnOnChangeClientName_Pre, "CTerrorPlayer::ChangeName", false);

	delete hGameData;
}
//创建钩子.
void CreateDetour(Handle gameData, DHookCallback CallBack, const char[] sName, const bool post)
{
	Handle hDetour = DHookCreateFromConf(gameData, sName);
	if(!hDetour)
		SetFailState("Failed to find \"%s\" signature.", sName);
		
	if(!DHookEnableDetour(hDetour, post, CallBack))
		SetFailState("Failed to detour \"%s\".", sName);
		
	delete hDetour;
}
//钩子回调.
MRESReturn OnOnChangeClientName_Pre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	char oldname[128], newname[128];
	GetClientName(pThis, oldname, sizeof(oldname));//获取玩家旧名称.
	hParams.GetString(1, newname, sizeof(newname));//获取玩家新名称.

	Action aResult = Plugin_Continue;
	Call_StartForward(g_hOnChangeName);
	Call_PushCell(pThis);
	Call_PushString(oldname);
	Call_PushString(newname);
	Call_Finish(aResult);
	
	if(aResult == Plugin_Handled)
	{
		hReturn.Value = 0;
		return MRES_Supercede;//阻止玩家改名,包括 SetClientName() 函数执行的改名.
	}
	return MRES_Ignored;
}
//阻止改名信息广播.
Action SayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	char sName[128];
	msg.ReadString(sName, sizeof(sName));
	msg.ReadString(sName, sizeof(sName));
	if(strcmp(sName, "#Cstrike_Name_Change") == 0)
		return Plugin_Handled;

	return Plugin_Continue;
}