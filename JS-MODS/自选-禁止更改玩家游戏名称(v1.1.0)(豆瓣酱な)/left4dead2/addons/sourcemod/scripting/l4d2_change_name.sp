
/*
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v1.1.0
 *
 *	1:更改为签名方法.
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
//加载函数库.
#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define GAMEDATA		"l4d2_change_name"
#define PLUGIN_VERSION		"1.1.0"	//定义插件版本.

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
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	CreateDetour(hGameData, OnCTerrorPlayerChangeName_Pre, "CTerrorPlayer::ChangeName", false);

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
MRESReturn OnCTerrorPlayerChangeName_Pre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	if(IsFakeClient(pThis))//玩家是电脑.
		return MRES_Ignored;
	
	char newname[64];
	if(!hParams.IsNull(1))
		hParams.GetString(1, newname, sizeof(newname));//获取玩家新名称.

	char oldname[128];
	GetClientName(pThis, oldname, sizeof(oldname));//获取玩家旧名称.

	if(strcmp(oldname, newname) == 0)//新名称跟旧名称相同.
		return MRES_Ignored;

	hReturn.Value = 0;
	return MRES_Supercede;//阻止玩家改名,包括SetClientName()函数执行的改名.
}