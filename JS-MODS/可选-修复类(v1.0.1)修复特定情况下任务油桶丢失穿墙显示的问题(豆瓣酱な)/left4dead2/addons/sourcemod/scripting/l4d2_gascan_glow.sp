/*
 *
 *	v1.0.0
 *
 *	1:初始版本发布(真时生还者拿着油桶死亡,离开,闲置时会触发这个问题).
 *
 *	v1.0.1
 *
 *	1:真实生还者拿着油桶时死亡时也会丢失穿墙显示.
 *
 */
#pragma semicolon 1
#pragma newdecls required//強制1.7以後的新語法
#include <sourcemod>
#include <sdkhooks>
#define PLUGIN_VERSION	"1.0.1"

//定义插件信息.
public Plugin myinfo =  
{
	name = "l4d2_gascan_glow",
	author = "豆瓣酱な",  
	description = "修复特定情况下任务油桶丢失穿墙显示的问题",
	version = PLUGIN_VERSION,
	url = "N/A"
};
//玩家连接成功.
public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDropPost);//生还者的物品掉落.
}
//生还者的物品掉落.
void OnWeaponDropPost(int client, int weapon)
{
	if(strcmp(GetGameModeName(), "coop") == 0)//只限coop战役模式.
	{
		if(IsValidEntity(weapon))//判断实体有效.
		{
			if (IsValidClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))//掉落武器时生还者还是存活状态.
			{
				char classname[64];
				GetEntityClassname(weapon, classname, sizeof(classname));//获取实体类名.
				if(strcmp(classname, "weapon_gascan") == 0)//判断物品是油桶.
				{
					if(GetEntProp(weapon, Prop_Send, "m_nSkin") > 0)//判断是否为任务油桶.
					{
						if (GetEntProp(weapon, Prop_Send, "m_iGlowType") != 3)//暂不清楚任务油桶类型是不是固定为3,先暂定为3.
							SetEntProp(weapon, Prop_Send, "m_iGlowType", 3);//设置发光的类型.
						//SetEntProp(weapon, Prop_Send, "m_glowColorOverride", 33023);//设置发光的颜色.
						//PrintToChatAll("\x04[掉落]\x03(%N)(%d)(%s).", client, skin, classname);
					}
				}
			}
		}
	}
}
//判断玩家有效.
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
//获取模式名称.
stock char[] GetGameModeName()
{
	char sMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sMode, sizeof(sMode));
	return sMode;
}