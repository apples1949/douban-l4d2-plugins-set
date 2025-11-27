/*
 *	v1.1.2
 *
 *	1:更换为动态数组.
 *
 *	v1.2.2
 *
 *	1:增加女巫死亡类型(建议在 HookEvent("witch_killed") 事件里使用,因为其它事件太早了).
 *
 *	v1.2.3
 *
 *	1:使用下一帧重置记录的数据,秒杀和爆头女巫提示写反了.
 *
 *	v1.2.4
 *
 *	1:击杀类型重置错了数据值,虽然没啥影响.
 *
 *	v1.2.5
 *
 *	1:女巫死亡事件 HookEvent("witch_killed", EventHookMode_Pre; 里获取和写入击杀类型.
 *	2:女巫死亡事件 HookEvent("witch_killed", EventHookMode_Post; 里延迟一帧删除储存的击杀类型.
 *
 *	v1.3.5
 *
 *	1:更改为include设置此插件为可选.
 *
 *	v1.3.6
 *
 *	1:删除了获取爆头和秒杀女巫的API功能,没啥用,主要是感觉写的太烂.
 *
 *	v1.3.7
 *
 *	1:女巫出现更换为签名(这个比witch_spawn事件早).
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define PLUGIN_VERSION	"1.3.7"
#define GAMEDATA		"l4d2_GetWitchNumber"

bool g_bLateLoad;

ArrayList g_hWitchIndex;

public Plugin myinfo = 
{
	name 			= "l4d2_GetWitchNumber",
	author 			= "豆瓣酱な",
	description 	= "给女巫添加仿特感的编号,例如:witch(1)",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("GetWitchNumber", GetNativeWitchNumber);
	RegPluginLibrary("l4d2_GetWitchNumber");
	g_bLateLoad = late;
	return APLRes_Success;
}
//插件开始.
public void OnPluginStart()
{
	LoadingGameData();//读取签名文件.
	
	g_hWitchIndex = new ArrayList();

	HookEvent("round_start",  Event_RoundStart);//回合开始.

	if(g_bLateLoad)//如果插件延迟加载.
	{
		int iWitchid = 32+1;
		while ((iWitchid = FindEntityByClassname(iWitchid, "witch")) != INVALID_ENT_REFERENCE)//循环所有女巫.
			g_hWitchIndex.Push(EntIndexToEntRef(iWitchid));//把数据推送的数组末尾.
	}
}
//回合开始.
public void Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	g_hWitchIndex.Clear();//清除数组内容.
}
//读取签名文件.
void LoadingGameData()
{
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	CreateDetour(hGameData, OnWitchSpawn_Pre, "Witch::Spawn", false);

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
MRESReturn OnWitchSpawn_Pre(int pThis, DHookReturn hReturn)//比事件早一点,但是这个不能设置血量.
{
	int iIndex = GetInvalidNumber();//获取无效的女巫索引数组位置.

	if(iIndex != -1)//获取无效的女巫索引数组位置.
		g_hWitchIndex.Set(iIndex, EntIndexToEntRef(pThis));//指定位置写入数据.
	else
		g_hWitchIndex.Push(EntIndexToEntRef(pThis));//推送数据到数组末尾.

	return MRES_Ignored;
}
//获取自定义的女巫编号.
stock int GetNativeWitchNumber(Handle plugin, int numParams)
{
	return GetWitchNumber(GetNativeCell(1));
}
//获取自定义的女巫编号.
stock int GetWitchNumber(int iWitchid)
{
	for(int i = 0; i < g_hWitchIndex.Length; i ++)
		if(EntRefToEntIndex(g_hWitchIndex.Get(i)) == iWitchid)
			return i;//返回数组位置.
	
	return -1;//数组里没有该女巫的索引.
}
//获取失效的实体索引.
stock int GetInvalidNumber()
{
	for(int i = 0; i < g_hWitchIndex.Length; i ++)
		if(EntRefToEntIndex(g_hWitchIndex.Get(i)) == INVALID_ENT_REFERENCE)
			return i;//返回数组位置.
	
	return -1;//没有失效的实体索引.
}