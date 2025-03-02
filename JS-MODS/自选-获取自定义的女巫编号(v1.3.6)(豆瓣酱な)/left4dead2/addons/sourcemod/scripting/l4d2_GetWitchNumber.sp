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
 */

#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define PLUGIN_VERSION	"1.3.6"

bool g_bLateLoad;

ArrayList g_hWitchIndex;

public Plugin myinfo = 
{
	name 			= "l4d2_GetWitchNumber",
	author 			= "豆瓣酱な",
	description 	= "给女巫添加自定义编号,例如:witch(1)",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}
/*
** 该功能嫖至作者 NiCo-op, Edited By Ernecio (Satanael) 的,链接没找到.
*/
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
	g_hWitchIndex = new ArrayList();

	HookEvent("round_start",  Event_RoundStart);//回合开始.
	HookEvent("witch_spawn",  Event_WitchSpawn);//女巫出现.
	//HookEvent("witch_killed", Event_Witchkilled);//女巫死亡.

	if(g_bLateLoad)//如果插件延迟加载.
	{
		int iWitchid = -1;
		while ((iWitchid = FindEntityByClassname(iWitchid, "witch")) != INVALID_ENT_REFERENCE)//循环所有女巫.
			g_hWitchIndex.Push(EntIndexToEntRef(iWitchid));//把数据推送的数组末尾.
	}
}
//回合开始.
public void Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	g_hWitchIndex.Clear();//清除数组内容.
}
//女巫出现.
public void Event_WitchSpawn(Event event, const char[] sName, bool bDontBroadcast)
{
	int iWitchid = event.GetInt( "witchid");

	if (IsValidEntity(iWitchid))
	{
		int iIndex = GetInvalidNumber();//获取无效的女巫索引数组位置.

		if(iIndex != -1)//获取到无效的女巫索引数组位置.
			g_hWitchIndex.Set(iIndex, EntIndexToEntRef(iWitchid));//指定位置写入数据.
		else
			g_hWitchIndex.Push(EntIndexToEntRef(iWitchid));//把数据推送的数组末尾.
	}
}
/*
//实体删除.
public void OnEntityDestroyed(int entity)
{
	if(IsValidEntity(entity))
	{
		char sName[32];
		GetEntityClassname(entity, sName, sizeof(sName));
		if(strcmp(sName,"witch") == 0)
		{
			int iIndex = GetWitchNumber(entity);

			if(iIndex != -1)
				//g_hWitchIndex.Set(iIndex, -1);//突然发现根本不需要重新设置值.
		}
	}
}
//女巫死亡.
public void Event_Witchkilled(Event event, const char[] name, bool dontBroadcast)
{
	int iWitchid = event.GetInt("witchid");

	if (IsValidEntity(iWitchid))
	{
		int iIndex = GetWitchNumber(iWitchid);

		if(iIndex != -1)
			//g_hWitchIndex.Set(iIndex, -1);//突然发现根本不需要重新设置值.
	}
}
*/
//获取自定义的女巫编号.
int GetNativeWitchNumber(Handle plugin, int numParams)
{
	return GetWitchNumber(GetNativeCell(1));
}
//获取自定义的女巫编号.
int GetWitchNumber(int iWitchid)
{
	for(int i = 0; i < g_hWitchIndex.Length; i ++)
		if(EntRefToEntIndex(g_hWitchIndex.Get(i)) == iWitchid)
			return i;//返回数组位置.
	
	return -1;//数组里没有该女巫的索引.
}
//获取到失效的实体索引.
int GetInvalidNumber()
{
	for(int i = 0; i < g_hWitchIndex.Length; i ++)
		if(EntRefToEntIndex(g_hWitchIndex.Get(i)) == INVALID_ENT_REFERENCE)
			return i;//返回数组位置.
	
	return -1;//没有失效的实体的实体索引.
}