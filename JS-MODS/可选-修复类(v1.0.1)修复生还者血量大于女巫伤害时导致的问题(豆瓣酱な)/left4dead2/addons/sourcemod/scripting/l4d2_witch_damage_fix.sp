/*
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v1.0.1
 *
 *	1:修复女巫攻击油桶和煤气罐等爆炸物导致周围的队友也被秒杀的问题.
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0.1"

public Plugin myinfo =  
{
	name = "l4d2_witch_damage_fix",
	author = "豆瓣酱な",  
	description = "修复生还者血量大于女巫伤害时导致的问题",
	version = PLUGIN_VERSION,
	url = "N/A"
};
//玩家加入时.
public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}
//伤害钩子回调.
Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(IsValidClient(victim) && GetClientTeam(victim) == 2&& IsPlayerAlive(victim) && IsPlayerState(victim))
	{
		char clsname[32];
		GetEdictClassname(inflictor, clsname, sizeof(clsname));

		if(strcmp(clsname, "witch") == 0)
		{
			//PrintToChatAll("\x04[提示]\x05玩家(%N)旧伤害(%.0f)索引(%d)类名(%s)", victim, damage, inflictor, clsname);
			damage = float(GetClientHealth(victim) + GetClientTempHealth(victim));
			//PrintToChatAll("\x04[提示]\x05玩家(%N)新伤害(%.0f)索引(%d)类名(%s)", victim, damage, inflictor, clsname);
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}
//玩家有效.
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
//获取虚血值.
stock int GetClientTempHealth(int client)
{
    static Handle painPillsDecayCvar = null;
    if (painPillsDecayCvar == null)
    {
        painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
        if (painPillsDecayCvar == null)
            return -1;
    }

    int tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(painPillsDecayCvar))) - 1;
    return tempHealth < 0 ? 0 : tempHealth;
}
//正常状态.
stock bool IsPlayerState(int client)
{
	return !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}