/*
 * v1.0.0
 *	
 *	1:初始版本.
 *
 * v1.0.1
 *	
 *	1:修复某些情况下可能触发多次的问题.
 *
 * v1.0.2
 *	
 *	1:好像不能修复多次触发,不然散弹枪效果不正常.
 *
 */
#pragma newdecls required
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	"1.0.2"

#define SPRITE_OVER	"materials/sun/overlay.vmt"
#define SPRITE_LASE	"materials/sprites/laserbeam.vmt"

char g_sPosition[][] = {"x", "y", "z"};
int g_iOverlay, g_iLaserbeam, g_iColor[4];
float g_fOrigin[3], g_fDirection[3], g_fTarget[3];
//定义插件信息.
public Plugin myinfo =
{
	name = "l4d2_bullet_impact", 
	author = "豆瓣酱な", 
	description = "生还者随机弹尘颜色.", 
	version = PLUGIN_VERSION, 
	url = "N/A"
};
//插件开始.
public void OnPluginStart()
{
	HookEvent("bullet_impact", Event_BulletImpact);//实体碰撞.
}

public void OnMapStart()
{
	g_iOverlay = PrecacheModel(SPRITE_OVER);
	g_iLaserbeam = PrecacheModel(SPRITE_LASE);
}
//实体碰撞.
public void Event_BulletImpact(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsValidClient(client) && GetClientTeam(client) == 2)
	{
		for (int i = 0; i < sizeof(g_fOrigin); i++)
			g_fOrigin[i] = GetEventFloat(event, g_sPosition[i]);
		for (int i = 0; i < sizeof(g_fDirection); i++)
			g_fDirection[i] = GetRandomFloat(-1.0, 1.0);
		for (int i = 0; i < sizeof(g_fTarget); i++)
			g_fTarget[i] = GetEventFloat(event, g_sPosition[i]);
		for (int i = 0; i < sizeof(g_iColor); i++)
			g_iColor[i] = GetRandomInt(0, 255);
		TE_SetupBloodSprite(g_fOrigin, g_fDirection, g_iColor, 1000, g_iLaserbeam, g_iOverlay);
		TE_SendToAll(0.0);
	}
}
//玩家有效.
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}