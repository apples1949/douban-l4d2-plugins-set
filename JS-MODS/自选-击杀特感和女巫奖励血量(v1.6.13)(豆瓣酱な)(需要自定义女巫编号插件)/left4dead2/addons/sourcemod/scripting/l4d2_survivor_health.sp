#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <l4d2_GetWitchNumber>
/*
 * 修复生还者血量大于最大上限时会被重置为最大上限的问题.
 */
#define CVAR_FLAGS		FCVAR_NOTIFY
#define PLUGIN_VERSION 	"1.6.14"
//数组数量.
#define array			8

//这里设置击杀奖励的血量(根据g_sZombieName数组顺序设置).
int iKillDefault[array] = {1, 1, 1, 1, 1, 2, 5, 10};
//这里设置爆头奖励的血量(根据g_sZombieName数组顺序设置).
int iHeadDefault[array] = {2, 2, 2, 2, 2, 5, 15, 35};

bool bKillWitchType[MAXPLAYERS+1];

char g_sZombieClass[][] = 
{
	"Smoker",
	"Boomer",
	"Hunter",
	"Spitter",
	"Jockey",
	"Charger",
	"witch",
	"Tank"
};

char g_sZombieName[][] = 
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

int    g_iKill[array], g_iHead[array], g_iOneshotWitch, g_iLimitHealth, g_iReviveSuccess, g_iSurvivorRescued, g_iHealSuccess, g_iDefibrillator;
ConVar g_hKill[array], g_hHead[array], g_hOneshotWitch, g_hLimitHealth, g_hReviveSuccess, g_hSurvivorRescued, g_hHealSuccess, g_hDefibrillator;

public Plugin myinfo =
{
	name = "l4d2_survivor_health",
	author = "豆瓣酱な", 
	description = "幸存者击杀奖励血量。",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public void OnPluginStart()
{
	HookEvent("witch_killed", Event_Witchkilled, EventHookMode_Pre);//女巫死亡.
	HookEvent("witch_harasser_set", Event_WitchHarasserSet);//惊扰女巫
	HookEvent("player_death", Event_PlayerDeath);//玩家死亡.

	HookEvent("defibrillator_used", Event_DefibrillatorUsed);//幸存者使用电击器救活队友.
	HookEvent("revive_success", Event_ReviveSuccess);//救起幸存者
	HookEvent("survivor_rescued", Event_SurvivorRescued);//幸存者在营救门复活.
	HookEvent("heal_success", Event_HealSuccess);//幸存者治疗
	HookEvent("adrenaline_used", Event_AdrenalineUsed, EventHookMode_Pre);//使用肾上腺素.

	char bar[2][64], buffers[2][64],value[2][64];
	for (int i = 0; i < array; i++)
	{
		FormatEx(buffers[0], sizeof(buffers[]), "l4d2_health_Kill_%s", g_sZombieClass[i]);
		FormatEx(value  [0], sizeof(value  []), "%d", iKillDefault[i]);
		FormatEx(bar    [0], sizeof(bar    []), "击杀%s的幸存者奖励多少血. 0=禁用.", g_sZombieName[i]);
		g_hKill[i] = CreateConVar(buffers[0], value[0], bar[0], CVAR_FLAGS);
	}

	for (int i = 0; i < array; i++)
	{
		FormatEx(buffers[1], sizeof(buffers[]), "l4d2_health_Head_%s", g_sZombieClass[i]);
		FormatEx(value  [1], sizeof(value  []), "%d", iHeadDefault[i]);
		FormatEx(bar    [1], sizeof(bar    []), "爆头%s的幸存者奖励多少血. 0=禁用.", g_sZombieName[i]);
		g_hHead[i] = CreateConVar(buffers[1], value[1], bar[1], CVAR_FLAGS);
	}

	g_hOneshotWitch	= CreateConVar("l4d2_health_oneshot_witch", "20", "秒杀女巫的幸存者奖励多少血. 0=禁用.", FCVAR_NOTIFY);
	g_hLimitHealth	= CreateConVar("l4d2_survivor_health_Limit", "100", "设置幸存者获得血量奖励的最高上限.", FCVAR_NOTIFY);

	g_hReviveSuccess	= CreateConVar("l4d2_health_reviveSuccess", "2", "救起倒地的幸存者奖励多少血. 0=禁用.", FCVAR_NOTIFY);
	g_hSurvivorRescued	= CreateConVar("l4d2_health_survivorRescued", "3", "营救队友的幸存者奖励多少血. 0=禁用.", FCVAR_NOTIFY);
	g_hHealSuccess		= CreateConVar("l4d2_health_healSuccess", "15", "治愈队友的幸存者奖励多少血. 0=禁用.", FCVAR_NOTIFY);
	g_hDefibrillator	= CreateConVar("l4d2_health_defibrillator", "20", "电击器复活队友的幸存者奖励多少血. 0=禁用.", FCVAR_NOTIFY);

	for (int i = 0; i < array; i++)
		g_hKill[i].AddChangeHook(ConVarChangedHealth);

	for (int i = 0; i < array; i++)
		g_hHead[i].AddChangeHook(ConVarChangedHealth);

	g_hOneshotWitch.AddChangeHook(ConVarChangedHealth);
	g_hLimitHealth.AddChangeHook(ConVarChangedHealth);

	g_hReviveSuccess.AddChangeHook(ConVarChangedHealth);
	g_hSurvivorRescued.AddChangeHook(ConVarChangedHealth);
	g_hHealSuccess.AddChangeHook(ConVarChangedHealth);
	g_hDefibrillator.AddChangeHook(ConVarChangedHealth);

	AutoExecConfig(true, "l4d2_survivor_health");//生成指定文件名的CFG.
}

//地图开始.
public void OnMapStart()
{
	GetConVarChange();
}

public void ConVarChangedHealth(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetConVarChange();
}

void GetConVarChange()
{
	for (int i = 0; i < array; i++)
		g_iKill[i] = g_hKill[i].IntValue;
	for (int i = 0; i < array; i++)
		g_iHead[i] = g_hHead[i].IntValue;

	g_iOneshotWitch = g_hOneshotWitch.IntValue;
	g_iLimitHealth = g_hLimitHealth.IntValue;

	g_iReviveSuccess = g_hReviveSuccess.IntValue;
	g_iSurvivorRescued = g_hSurvivorRescued.IntValue;
	g_iHealSuccess = g_hHealSuccess.IntValue;
	g_iDefibrillator = g_hDefibrillator.IntValue;
}

//玩家退出
public void OnClientDisconnect(int client)
{   
	if(!IsFakeClient(client))
		bKillWitchType[client] = false;
}

//使用肾上腺素.
public void Event_AdrenalineUsed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsValidClient(client) && GetClientTeam(client) == 2)
	{
		int iHealth = GetClientHealth(client);
		int tHealth = GetPlayerTempHealth(client);
		//重新设置一次血量,以避免一些问题.
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", float(tHealth) < 0.0 ? 0.0 : float(tHealth));
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		SetEntityHealth(client, iHealth < 1 ? 1 : iHealth);
	}
}

public void Event_DefibrillatorUsed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));

	if(IsValidClient(client) && GetClientTeam(client) == 2)
		if(IsValidClient(subject) && GetClientTeam(subject) == 2)
			if(client != subject)
				SetSurvivorHealth(client, g_iDefibrillator, g_iLimitHealth, "救活", GetTrueName(subject), IsPlayerAlive(client) ? IsPlayerState(client) ? true : false : false, false);
}

public void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));

	if(IsValidClient(client) && GetClientTeam(client) == 2)
		if(IsValidClient(subject) && GetClientTeam(subject) == 2)
			if(client != subject)
				SetSurvivorHealth(client, g_iReviveSuccess, g_iLimitHealth, "救起", GetTrueName(subject), IsPlayerAlive(client) ? IsPlayerState(client) ? true : false : false, false);
}

public void Event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));

	if(IsValidClient(client) && GetClientTeam(client) == 2)
		if(IsValidClient(subject) && GetClientTeam(subject) == 2)
			if(client != subject)
				SetSurvivorHealth(client, g_iHealSuccess, g_iLimitHealth, "治愈", GetTrueName(subject), IsPlayerAlive(client) ? IsPlayerState(client) ? true : false : false, false);
}

//幸存者在营救门复活.
public void Event_SurvivorRescued(Event event, const char[] name, bool dontBroadcast)
{
	int rescuer = GetClientOfUserId(event.GetInt("rescuer"));
	int client = GetClientOfUserId(event.GetInt("victim"));

	if(IsValidClient(client) && GetClientTeam(client) == 2)
		if(IsValidClient(rescuer) && GetClientTeam(rescuer) == 2)
			if(client != rescuer)
				SetSurvivorHealth(rescuer, g_iSurvivorRescued, g_iLimitHealth, "营救", GetTrueName(client), IsPlayerAlive(rescuer) ? IsPlayerState(rescuer) ? true : false : false, false);

}

public void Event_WitchHarasserSet(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int witchid = event.GetInt("witchid" );
	
	if(IsValidClient(client) && GetClientTeam(client) == 2)
		PrintToChatAll("\x04[提示]\x03%s\x05惊扰了\x03%s.", GetTrueName(client), GetWitchName(witchid));//聊天窗提示.
}

public void Event_Witchkilled(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int iOneshot = event.GetBool("oneshot");
	int witchid = event.GetInt("witchid" );
	
	if(IsValidClient(client) && GetClientTeam(client) == 2)
	{
		if(iOneshot != 0)
			SetSurvivorHealth(client, g_iOneshotWitch, g_iLimitHealth, "秒杀", GetWitchName(witchid), IsPlayerAlive(client) ? IsPlayerState(client) ? true : false : false, false);
		bKillWitchType[client] = iOneshot != 0 ? true : false;
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int headshot = event.GetBool("headshot");
	
	if(IsValidClient(attacker) && GetClientTeam(attacker) == 2)
	{
		char classname[32];
		int entity = GetEventInt(event, "entityid");
		GetEdictClassname(entity, classname, sizeof(classname));
		if (IsValidEdict(entity) && strcmp(classname, "witch") == 0)
		{
			//这里使用下一帧.
			DataPack hPack = new DataPack();
			hPack.WriteCell(attacker);
			hPack.WriteCell(headshot);
			hPack.WriteCell(false);
			hPack.WriteString(GetWitchName(entity));
			RequestFrame(IsGetStruckType, hPack);
		}
		if(IsValidClient(client) && GetClientTeam(client) == 3)
		{
			char sName[32], slName[32];
			int iHLZClass = (GetEntProp(client, Prop_Send, "m_zombieClass"));
			FormatEx(sName, sizeof(sName), "%N", client);
			SplitString(sName, g_sZombieClass[iHLZClass - 1], sName, sizeof(sName));
			FormatEx(slName, sizeof(slName), "%s%s", g_sZombieName[iHLZClass - 1], sName);
			SetSurvivorHealth(attacker, headshot == 0 ? g_iKill[iHLZClass - 1] :  g_iHead[iHLZClass - 1], g_iLimitHealth, headshot == 0 ? "击杀" : "爆头", 
			slName, IsPlayerAlive(attacker) ? IsPlayerState(attacker) ? true : false : false, iHLZClass != 8 ? true : false);
		}
	}
}

void IsGetStruckType(DataPack hPack)
{
	hPack.Reset();
	char sName[32];
	int  attacker = hPack.ReadCell();
	int  headshot =	hPack.ReadCell();
	bool bDisplay =	hPack.ReadCell();
	hPack.ReadString(sName, sizeof(sName));
	
	if(IsClientInGame(attacker))
	{
		if(bKillWitchType[attacker] == false)
			SetSurvivorHealth(attacker, headshot == 0 ? g_iKill[6] :  g_iHead[6], g_iLimitHealth, headshot == 0 ? "击杀" : "爆头", 
			sName, IsPlayerAlive(attacker) ? IsPlayerState(attacker) ? true : false : false, bDisplay);		 
		bKillWitchType[attacker] = false;
	}
	delete hPack;
}

void SetSurvivorHealth(int attacker, int iReward, int iMaxHealth, char[] sType, char[] sName, bool bPlayerState, bool bAllTheDisplay)
{
	int iBot = IsClientIdle(attacker);
	int iHealth = GetClientHealth(attacker);
	int tHealth = GetPlayerTempHealth(attacker);
	int iTotalHealth = iHealth + tHealth;

	if (iTotalHealth + iReward > iMaxHealth)
	{
		if (bPlayerState)
		{
			float overhealth, fakehealth;
			overhealth = float(iTotalHealth + iReward - iMaxHealth);
			if (tHealth < overhealth)
				fakehealth = 0.0;
			else
				fakehealth = float(tHealth) - overhealth;
			SetEntPropFloat(attacker, Prop_Send, "m_healthBuffer", fakehealth < 0.0 ? 0.0 : fakehealth);
			SetEntPropFloat(attacker, Prop_Send, "m_healthBufferTime", GetGameTime());
		}
	}
	if (bPlayerState)
		if ((iHealth + iReward) < iMaxHealth)
			SetEntityHealth(attacker, iHealth + iReward);
		else
			SetEntityHealth(attacker, iHealth == iMaxHealth ? iMaxHealth : iHealth);
	
	if (bAllTheDisplay)
		IsPrintToChat(iBot != 0 ? iBot : attacker, iTotalHealth, iReward, iMaxHealth, sType, sName, bPlayerState);
	else
		IsPrintToChatAll(attacker, iTotalHealth, iReward, iMaxHealth, sType, sName, bPlayerState);
}

void IsPrintToChat(int attacker, int iTotalHealth, int iReward, int iMaxHealth, char[] sType, char[] sName, bool bPlayerState)
{
	if (!IsClientInGame(attacker))
		return;

	if (bPlayerState)
	{
		if (iTotalHealth < iMaxHealth)
			PrintToChat(attacker, "\x04[提示]\x05%s了\x03%s\x04,\x05奖励\x03%d\x05点血量.", sType, sName, iReward);
		else
			PrintToChat(attacker, "\x04[提示]\x05%s了\x03%s\x04,\x05血量已达\x03%d\x05上限.", sType, sName, iMaxHealth);//聊天窗提示.
	}
	else
		PrintToChat(attacker, "\x04[提示]\x05%s了\x03%s\x04.", sType, sName);//聊天窗提示.
}

void IsPrintToChatAll(int attacker, int iTotalHealth, int iReward, int iMaxHealth, char[] sType, char[] sName, bool bPlayerState)
{
	if (bPlayerState)
	{
		if (iTotalHealth < iMaxHealth)
			PrintToChatAll("\x04[提示]\x03%s\x05%s了\x03%s\x04,\x05奖励\x03%d\x05点血量.", GetTrueName(attacker), sType, sName, iReward);
		else
			PrintToChatAll("\x04[提示]\x03%s\x05%s了\x03%s\x04,\x05血量已达\x03%d\x05上限.", GetTrueName(attacker), sType, sName, iMaxHealth);//聊天窗提示.
	}
	else
		PrintToChatAll("\x04[提示]\x03%s\x05%s了\x03%s\x04.", GetTrueName(attacker), sType, sName);//聊天窗提示.
}

bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

//正常状态.
bool IsPlayerState(int client)
{
	return !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

char[] GetWitchName(int iWitchid)
{
	char clName[32];
	if(GetWitchNumber(iWitchid) == 0) 
		strcopy(clName, sizeof(clName), "女巫");
	else
		FormatEx(clName, sizeof(clName), "女巫(%d)", GetWitchNumber(iWitchid));
	
	return clName;
}

char[] GetTrueName(int client)
{
	char sName[32];
	int Bot = IsClientIdle(client);
	
	if(Bot != 0)
		FormatEx(sName, sizeof(sName), "闲置:%N", Bot);
	else
		GetClientName(client, sName, sizeof(sName));
	return sName;
}

int IsClientIdle(int client) 
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

//获取虚血值.
int GetPlayerTempHealth(int client)
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