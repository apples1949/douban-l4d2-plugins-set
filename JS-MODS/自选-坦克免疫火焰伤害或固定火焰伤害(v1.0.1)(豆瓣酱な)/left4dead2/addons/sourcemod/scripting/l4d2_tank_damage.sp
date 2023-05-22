#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION "1.0.1"

#define DOUBANFIRE	2056
#define DOUBANONFIRE	268435464

int    g_iTankDamage;
ConVar g_hTankDamage;

public Plugin myinfo =  
{
	name = "重置火焰伤害",
	author = "豆瓣酱な",  
	description = "重置火焰对坦克的伤害",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public void OnPluginStart()
{
	g_hTankDamage = CreateConVar("l4d2_tank_damage", "2", "设置坦克每次受到多少火焰伤害(约0.18秒/次). -1=禁用, 0=免疫火伤.", FCVAR_NOTIFY);
	g_hTankDamage.AddChangeHook(ConVarChanged);
	AutoExecConfig(true, "l4d2_tank_damage");
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsTankDamage();
}

public void OnMapStart()
{
	IsTankDamage();
}

void IsTankDamage()
{
	g_iTankDamage = g_hTankDamage.IntValue;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);//重新设置坦克受到的火焰伤害.
}

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{ 
	if(g_iTankDamage != 0)
		return Plugin_Continue;
	
	if(IsTank(client) && (damagetype == DMG_BURN || damagetype == DOUBANFIRE || damagetype == DOUBANONFIRE))
	{
		if(GetEntityFlags(client) & FL_ONFIRE)//判断客户端是否着火.
			ExtinguishEntity(client);//灭火.
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

//重新设置坦克受到的火焰伤害.
public Action OnTakeDamageAlive(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{ 
	if(g_iTankDamage < 0)
		return Plugin_Continue;

	if(IsTank(client))
	{	
		if(damagetype == DMG_BURN  || damagetype == DOUBANFIRE || damagetype == DOUBANONFIRE)
		{
			if(g_iTankDamage == 0)
				return Plugin_Handled;
			else
			{
				int iHealth = GetClientHealth(client);
				
				if (iHealth > g_iTankDamage)
				{
					SDKHooks_TakeDamage(client, inflictor, attacker, float(g_iTankDamage));//设置指定的伤害.
					//PrintToChatAll("\x04[提示]\x03攻击者%N,%N\x05,总血量\x04:\x03%d,受到了\x04:\x03%.0f\x05点伤害.", attacker, client, iHealth, damage);
					return Plugin_Handled;//阻止原来的伤害.
				}
			}
		}
	}
	return Plugin_Continue;
}

stock bool IsSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

stock bool IsInfected(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

stock bool IsTank(int client)  
{
	if (!IsInfected(client))
		return false;
		
	if (!IsPlayerAlive(client))
		return false;

	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
		return false;

	return true;
}