/*
 * v1.1.3
 *	
 *	1:掉落钞票插件的函数库名称更改了.
 *
 * v1.1.4
 *	
 *	1:修复依赖插件被卸载时此插件会被暂停的问题.
 *
 * v1.1.5
 *	
 *	1:删除其它配套代码.
 *
 * v1.2.5
 *	
 *	1:增加那些情况允许玩家使用自杀功能.
 *
 */

#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define	FUNCTION_1		(1 << 0)
#define FUNCTION_2		(1 << 1)
#define FUNCTION_4		(1 << 2)
#define FUNCTION_8		(1 << 3)
#define FUNCTION_16		(1 << 4)

#define PLUGIN_VERSION "1.1.5"

int    g_iSurvivor, g_iInfected;
ConVar g_hSurvivor, g_hInfected;

ConVar g_hSurvivorHealth, g_hMaxReviveCount;

public Plugin myinfo =  
{
	name = "l4d2_player_suicide",
	author = "豆瓣酱な",  
	description = "玩家自杀指令",
	version = PLUGIN_VERSION,
	url = "N/A"
};
//插件开始时.
public void OnPluginStart()
{
	RegConsoleCmd("sm_zs", Command_Suicide, "玩家自杀指令.");
	RegConsoleCmd("sm_kill", Command_Suicide, "玩家自杀指令.");
	g_hSurvivorHealth = FindConVar("survivor_limp_health");
	g_hMaxReviveCount = FindConVar("survivor_max_incapacitated_count");
	
	g_hSurvivor	= CreateConVar("l4d2_survivor_suicide",		"31", "启用生还者自杀功能. 0=禁用, 1=倒地, 2=挂边, 4=黑白, 8=瘸腿, 16=健康, 31=全部.");
	g_hInfected	= CreateConVar("l4d2_infected_suicide",		"3", "启用感染者自杀功能. 0=禁用, 1=灵魂, 2=存活, 3=全部.");

	g_hSurvivor.AddChangeHook(ConVarChanged);
	g_hInfected.AddChangeHook(ConVarChanged);

	AutoExecConfig(true, "l4d2_player_suicide");
}
public void OnConfigsExecuted()
{	
	GetConVarSuicide();
}
public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetConVarSuicide();
}
void GetConVarSuicide()
{
	g_iSurvivor = g_hSurvivor.IntValue;
	g_iInfected = g_hInfected.IntValue;
}
//聊天窗中文指令.
public Action OnClientSayCommand(int client, const char[] commnad, const char[] args)
{
	if(strlen(args) <= 1 || strncmp(commnad, "say", 3, false) != 0)
		return Plugin_Continue;

	if (strcmp(args, "自杀") == 0)
	{
		vForcePlayerSuicide(client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
//指令回调.
public Action Command_Suicide(int client, int args)
{
	vForcePlayerSuicide(client);
	return Plugin_Handled;
}
void vForcePlayerSuicide(int client)
{
	if(IsValidClient(client) && !IsFakeClient(client))
	{
		switch (GetClientTeam(client))
		{
			case 1:
			{
				int iBot = GetBotOfIdlePlayer(client);
				if (iBot != 0)
					ForceSurvivorSuicide(iBot, client, GetTrueName(client), "生还者");
				else
					PrintToChat(client, "\x04[提示]\x05旁观者无权使用该指令.");
			}
			case 2:
			{
				ForceSurvivorSuicide(client, client, GetTrueName(client), "生还者");
			}
			case 3:
			{
				ForceInfectedSuicide(client, client, GetTrueName(client), "感染者");
			}
		}
	}
}

void ForceSurvivorSuicide(int client, int victim, char[] sName, char[] sTeam)
{
	if(g_iSurvivor > 0)
	{
		if (IsPlayerAlive(client))
		{
			if(IsPlayerFallen(client))
			{
				if(g_iSurvivor & FUNCTION_1)
					ExecutePlayerSuicide(client, sName, sTeam);
				else
					PrintToChat(victim, "\x04[提示]\x05倒地状态禁止使用自杀功能.");
			}
			else if(IsPlayerFalling(client))
			{
				if(g_iSurvivor & FUNCTION_2)
					ExecutePlayerSuicide(client, sName, sTeam);
				else
					PrintToChat(victim, "\x04[提示]\x05挂边状态禁止使用自杀功能.");
			}
			else if(IsReviveCount(client))
			{
				if(g_iSurvivor & FUNCTION_4)
					ExecutePlayerSuicide(client, sName,  sTeam);
				else
					PrintToChat(victim, "\x04[提示]\x05黑白状态禁止使用自杀功能.");
			}
			else if(IsSurvivorLimp(client))
			{
				if(g_iSurvivor & FUNCTION_8)
					ExecutePlayerSuicide(client, sName, sTeam);
				else
					PrintToChat(victim, "\x04[提示]\x05瘸腿状态禁止使用自杀功能.");
			}
			else if(IsPlayerState(client))
			{
				if(g_iSurvivor & FUNCTION_16)
					ExecutePlayerSuicide(client, sName, sTeam);
				else
					PrintToChat(victim, "\x04[提示]\x05健康状态禁止使用自杀功能.");
			}
		}
		else
			PrintToChat(victim, "\x04[提示]\x05死亡状态禁止使用自杀功能.");
	}
	else
		PrintToChat(victim, "\x04[提示]\x03未开始\x05生还者自杀功能.");
}
//感染者.
void ForceInfectedSuicide(int client, int victim, char[] sName, char[] sTeam)
{
	if(g_iInfected > 0)
	{
		if (IsPlayerAlive(client))
		{
			if (GetEntProp(client, Prop_Send, "m_isGhost"))
			{
				if(g_iInfected & FUNCTION_1)
					ExecutePlayerSuicide(client, sName, sTeam);
				else
					PrintToChat(victim, "\x04[提示]\x05灵魂状态禁止使用自杀功能.");
			}
			else
			{
				if(g_iInfected & FUNCTION_2)
					ExecutePlayerSuicide(client, sName, sTeam);
				else
					PrintToChat(victim, "\x04[提示]\x05存活状态禁止使用自杀功能.");
			}
		}
		else
			PrintToChat(victim, "\x04[提示]\x05死亡状态禁止使用自杀功能.");
	}
	else
		PrintToChat(victim, "\x04[提示]\x03未开始\x05感染者自杀功能.");
}
//执行玩家自杀.
void ExecutePlayerSuicide(int client, char[] sName, char[] sTeam)
{
	ForcePlayerSuicide(client);//幸存者自杀代码.
	PrintToChatAll("\x04[提示]\x05(\x04%s\x05)\x03%s\x05突然失去了梦想.", sTeam, sName);
}
//玩家有效.
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
//幸存者瘸腿.
stock bool IsSurvivorLimp(int client)
{
	return GetSurvivorHealth(client) < g_hSurvivorHealth.IntValue;
}
//幸存者总血量.
stock int GetSurvivorHealth(int client)
{
	return GetClientHealth(client) + GetSurvivorTempHealth(client);
}
//幸存者虚血量.
stock int GetSurvivorTempHealth(int client)
{
	static Handle painPillsDecayCvar;
	painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
	if (painPillsDecayCvar == null)
		return -1;

	int tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(painPillsDecayCvar))) - 1;
	return tempHealth < 0 ? 0 : tempHealth;
}
//倒地状态.
stock bool IsPlayerFallen(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}
//挂边状态.
stock bool IsPlayerFalling(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}
//倒地次数.
stock bool IsReviveCount(int client)
{
	if(g_hMaxReviveCount.IntValue <= 0)
		return false;
	return GetEntProp(client, Prop_Send, "m_currentReviveCount") >= g_hMaxReviveCount.IntValue;
}
//正常状态.
stock bool IsPlayerState(int client)
{
	return !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}
//返回对应的内容.
stock char[] GetTrueName(int client)
{
	char sName[32];
	GetClientName(client, sName, sizeof(sName));
	return sName;
}
//返回闲置玩家对应的电脑.
stock int GetBotOfIdlePlayer(int client)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && GetClientIdle(i) == client)
			return i;

	return 0;
}
//返回电脑幸存者对应的玩家.
stock int GetClientIdle(int client)
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}