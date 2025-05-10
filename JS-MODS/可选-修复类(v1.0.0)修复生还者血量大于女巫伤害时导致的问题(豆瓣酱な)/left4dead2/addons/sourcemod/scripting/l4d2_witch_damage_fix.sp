#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0.0"

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
		char class[6];
		GetEdictClassname(attacker, class, sizeof(class));

		if(strcmp(class, "witch") == 0)
		{
			//PrintToChatAll("\x04[提示]\x05%N旧伤害%.0f(%d)", victim, damage, damagetype);
			damage = float(GetClientHealth(victim) + GetClientTempHealth(victim));
			//PrintToChatAll("\x04[提示]\x05%N新伤害%.0f(%d)", victim, damage, damagetype);
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