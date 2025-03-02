/*
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v1.0.1
 *
 *	1:新增了这个显示,提示类型从聊天窗改为屏幕中下.
 *
 *	v1.1.1
 *
 *	1:新增设置允许生还者团队或感染者团队使用喷漆,或者直接禁止使用喷漆.
 *
 */

#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	"1.1.1"
#define CVAR_FLAGS		FCVAR_NOTIFY

static const char g_sSurvivorNames[][] = 
{
	"Nick",
	"Rochelle",
	"Coach",
	"Ellis",
	"Bill",
	"Zoey",
	"Francis",
	"Louis"
};

static const char g_sSurvivorModels[][] = 
{
	"models/survivors/survivor_gambler.mdl",
	"models/survivors/survivor_producer.mdl",
	"models/survivors/survivor_coach.mdl",
	"models/survivors/survivor_mechanic.mdl",
	"models/survivors/survivor_namvet.mdl",
	"models/survivors/survivor_teenangst.mdl",
	"models/survivors/survivor_biker.mdl",
	"models/survivors/survivor_manager.mdl"
};

static const char g_sZombieName[][] = 
{
	"舌头",
	"胖子",
	"猎人",
	"口水",
	"猴子",
	"牛牛",
	"女巫",
	"坦克"
};

#define SURVIVOR	(1 << 0)
#define INFESTOR	(1 << 1)

int    g_iPlayerDecal;
ConVar g_hPlayerDecal;

public Plugin myinfo = 
{
	name 			= "l4d2_player_decal",
	author 			= "豆瓣酱な",
	description 	= "生还者或感染者使用喷漆时提示.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public void OnPluginStart() 
{
	AddTempEntHook("Player Decal", PlayerDecal);

	g_hPlayerDecal = CreateConVar("l4d2_player_decal", "3", "允许什么团队可以使用喷漆? 0=禁用, 1=生还者, 2=感染者, 3=两者皆可.", CVAR_FLAGS);
	g_hPlayerDecal.AddChangeHook(ConVarChanged);
	AutoExecConfig(true, "l4d2_player_decal");//生成指定文件名的CFG.
}

public void OnConfigsExecuted()
{
	GetCvars();
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iPlayerDecal = g_hPlayerDecal.IntValue;
}

public Action PlayerDecal(const char[] te_name, const int[] Players, int numClients, float delay)
{
	if(g_iPlayerDecal <= 0)
		return Plugin_Stop;//阻止玩家使用喷漆.

	int client = TE_ReadNum("m_nPlayer");
	
	if(IsValidClient(client))
	{
		int iTeam = GetClientTeam(client);

		switch (iTeam)
		{
			case 2:
			{
				if(g_iPlayerDecal & SURVIVOR)
				{
					PrintToChatAll("\x04[提示]\x03%s(%s)\x05使用了喷漆.", GetPlayerName(client), GetPlayerModel(client));
					return Plugin_Continue;
				}
			}
			case 3:
			{
				if(g_iPlayerDecal & INFESTOR)
				{
					PrintToChatAll("\x04[提示]\x03%s(%s)\x05使用了喷漆.", GetPlayerName(client), g_sZombieName[GetEntProp(client, Prop_Send, "m_zombieClass") - 1]);
					return Plugin_Continue;
				}
			}
			default:
			{
				PrintToChatAll("\x04[提示]\x03%s\x05使用了喷漆.", GetPlayerName(client));
				return Plugin_Continue;
			}
		}
	}
	return Plugin_Stop;//阻止玩家使用喷漆.
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock char[] GetPlayerName(int client)
{
	char g_sName[32];
	GetClientName(client, g_sName, sizeof(g_sName));
	return g_sName;
}

stock char[] GetPlayerModel(int client)
{
	char sModel[64];
	GetEntPropString(client, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	for (int i = 0; i < sizeof(g_sSurvivorModels); i++)
	{
		if (strcmp(sModel, g_sSurvivorModels[i], false) == 0)
		{
			strcopy(sModel, sizeof(sModel), g_sSurvivorNames[i]);
			break;
		}
	}
	return sModel;
}