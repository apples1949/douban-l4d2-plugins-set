/*
 * v1.1.3
 *	
 *	1:设置火焰伤害还是得使用 SDKHooks_TakeDamage 的方法,不然统计类插件结果严重不准.
 *
 * v1.1.4
 *	
 *	1:设置伤害函数后面不能设置类型,否则会疯狂报错.
 *
 * v1.2.4
 *	
 *	1:设置伤害阻止原始伤害改成直接更改伤害.
 *	2:判断火焰伤害类型从伤害类型更改为类名方法.
 *
 * v1.2.5
 *
 *	1:才发现改成实体类名后火焰伤害类名用两个.
 *	2:此SDK钩子不能使用Plugin_Changed方式更改坦克火焰伤害,改回SDKHooks_TakeDamage设置伤害并阻止Plugin_Handled原始伤害.
 *
 * v1.2.6
 *
 *	1:换成判断火焰类名后,伤害为0的时候也设置了伤害导致无限递归插件报错.
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
//#pragma dynamic 1024	//增加堆栈空间.
//加载include库.
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
//定义插件版本.
#define PLUGIN_VERSION "1.2.6"

#define DMG_FIRE	2056
#define DMG_ONFIRE	268435464

bool g_bLateLoad;

int    g_iTankDamage;
ConVar g_hTankDamage;
//定义插件信息.
public Plugin myinfo =  
{
	name = "重置火焰伤害",
	author = "豆瓣酱な",  
	description = "重置火焰对坦克的伤害",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;//延迟加载插件.
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hTankDamage = CreateConVar("l4d2_tank_damage", "2", "设置坦克每次受到多少火焰伤害(约0.18秒/次). -1=禁用, 0=免疫火焰伤害.", FCVAR_NOTIFY);
	g_hTankDamage.AddChangeHook(ConVarChanged);
	AutoExecConfig(true, "l4d2_tank_damage");

	if(g_bLateLoad)//如果插件延迟加载.
		for(int i = 1; i <= MaxClients; i++)
			if(IsClientInGame(i))
				OnClientPutInServer(i);
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ChangedTankDamage();
}

public void OnMapStart()
{
	ChangedTankDamage();
}

void ChangedTankDamage()
{
	g_iTankDamage = g_hTankDamage.IntValue;
}
//玩家连接成功.
public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);//重新设置坦克受到的火焰伤害.
}
//重新设置坦克受到的火焰伤害.
public Action OnTakeDamageAlive(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{ 
	if(g_iTankDamage < 0)
		return Plugin_Continue;

	if(damage <= 0)
		return Plugin_Continue;

	if(g_iTankDamage > 0 && damage <= g_iTankDamage)
		return Plugin_Continue;

	if(IsValidClient(client) && IsValidTank(client) && IsPlayerState(client))
	{	
		if(IsInflictor(inflictor, "inferno") || IsInflictor(inflictor, "entityflame"))//火焰类.
		{
			if(g_iTankDamage == 0)
			{
				if(GetEntityFlags(client) & FL_ONFIRE)//判断客户端是否着火.
				{
					ExtinguishEntity(client);//灭火.

					int entity = GetEntPropEnt(client, Prop_Send, "m_hEffectEntity");
					
					if(IsValidEntity(entity))
						RemoveEntity(entity);
				}
				return Plugin_Handled;//阻止伤害(这里不能用Plugin_Changed).
			}
			else
			{
				if (GetClientHealth(client) > g_iTankDamage)
				{
					SDKHooks_TakeDamage(client, inflictor, attacker, float(g_iTankDamage));//设置指定的伤害.
					return Plugin_Handled;//阻止伤害(这里不能用Plugin_Changed).
				}
			}
		}
	}
	return Plugin_Continue;
}
//玩家有效.
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
//存活坦克.
stock bool IsValidTank(int client)  
{
	return GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(client);
}
//获取伤害来源类名.
stock bool IsInflictor(int inflictor, char[] sName)
{
	if(inflictor > MaxClients)
	{
		static char classname[13];
		GetEdictClassname(inflictor, classname, sizeof(classname));
		return strcmp(classname, sName) == 0;
	}
	return false;
}
//正常状态.
stock bool IsPlayerState(int client)
{
	return !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}