
/*
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v1.0.1
 *
 *	1:修复插件报错的问题.
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define GAMEDATA			"l4d2_RemoveSurvivorDeathModel"
#define PLUGIN_VERSION		"1.0.1"
#define MAX_PLAYERS			32
//定义全局整数数组变量.
int g_iSurvivorDeathModel[MAX_PLAYERS+1];
//定义插件信息.
public Plugin myinfo =  
{
	name = "l4d2_RemoveSurvivorDeathModel",
	author = "豆瓣酱な",
	description = "删除签名复活的生还者尸体模型",
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

	CreateDetour(hGameData, OnRoundRespawn_Post, "CTerrorPlayer::RoundRespawn", true);

	delete hGameData;
}
//创建监听钩子.
stock void CreateDetour(Handle gameData, DHookCallback CallBack, const char[] sName, const bool post)
{
	Handle hDetour = DHookCreateFromConf(gameData, sName);
	if(!hDetour)
		SetFailState("Failed to find \"%s\" signature.", sName);
		
	if(!DHookEnableDetour(hDetour, post, CallBack))
		SetFailState("Failed to detour \"%s\".", sName);
		
	delete hDetour;
}
//玩家复活.
MRESReturn OnRoundRespawn_Post(int pThis, DHookReturn hReturn) 
{
	vRemoveSurvivorDeathModel(pThis);
	return MRES_Ignored;
}
//生还者死亡时创建的尸体索引(需要Defib_Fix电击器修复插件支持).
public void L4D2_OnSurvivorDeathModelCreated(int iClient, int iDeathModel)
{
	g_iSurvivorDeathModel[iClient] = EntIndexToEntRef(iDeathModel);
}
//玩家离开游戏.
public void OnClientDisconnect(int client)
{
	vRemoveSurvivorDeathModel(client);
}
//删除生还者对应的尸体.
stock void vRemoveSurvivorDeathModel(int client)
{
	int entity = g_iSurvivorDeathModel[client];
	
	if(!bIsValidEntRef(entity))
		return;

	RemoveEntity(entity);
	g_iSurvivorDeathModel[client] = 0;
}
//判断索引有效.
bool bIsValidEntRef(int entity)
{
	return entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE;
}