/*
 *
 *	v1.5.8
 *
 *	1:伤害统计新增一个坦克击杀者标记.
 *
 *	v1.5.9
 *
 *	1:不知什么原因导致排序时玩家有效性没过数据没显示出来,改了下尝试修复,由于无法稳定复现所以无法测试.
 *
 */
#pragma semicolon 1
//#pragma dynamic 231072	//增加堆栈空间.
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>

#define MAX_SIZE		32	//定义字符串大小.
#define PLUGIN_VERSION	"1.5.9"

bool g_bLateLoad;

int    g_iTankIdle, g_iTankRanking;
ConVar g_hTankIdle, g_hTankRanking;

int g_iTankHP[MAXPLAYERS+1], g_iTankHurt[MAXPLAYERS+1], g_iTankSlayer[MAXPLAYERS+1][MAXPLAYERS+1], g_iSurvivorTankHurt[MAXPLAYERS+1][MAXPLAYERS+1];

public Plugin myinfo =  
{
	name = "l4d2_tank_ranking",
	author = "豆瓣酱な",  
	description = "生还者对坦克的伤害排名.",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("tank_spawn", Event_TankSpawn);//坦克出现.
	HookEvent("player_hurt", Event_PlayerHurt);//玩家受伤.
	HookEvent("player_death", Event_PlayerDeath);//玩家死亡.
	g_hTankIdle = CreateConVar("l4d2_tank_player_idle", "1", "玩家闲置时电脑造成的伤害计算给玩家? 0=禁用, 1=启用.", FCVAR_NOTIFY);
	g_hTankRanking = CreateConVar("l4d2_tank_Ranking", "5", "设置生还者对坦克的伤害的最大排名. 0=禁用.", FCVAR_NOTIFY);
	g_hTankIdle.AddChangeHook(IsConVarChanged);
	g_hTankRanking.AddChangeHook(IsConVarChanged);
	AutoExecConfig(true, "l4d2_tank_ranking");//生成指定文件名的CFG.

	if(g_bLateLoad)//如果插件延迟加载.
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
			{
				OnClientPutInServer(i);//勾住坦克.
				g_iTankHP[i] = GetClientHealth(i);//记录坦克的血量.
			}
		}
	}
}
//地图开始.
public void OnMapStart()
{
	IsGetCvars();
}

public void IsConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsGetCvars();
}
void IsGetCvars()
{
	g_iTankIdle = g_hTankIdle.IntValue;
	g_iTankRanking = g_hTankRanking.IntValue;

	if (g_iTankRanking > MaxClients)
		g_iTankRanking = MaxClients;
}
//坦克出现.
public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsValidClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
	{	
		RequestFrame(IsTankHealthFrame, GetClientUserId(client));//坦克出现时延迟一帧获取血量.
		IsResetVariable(client);//坦克出现时重置整型变量.
	}
}
//坦克出现时获取血量.
void IsTankHealthFrame(int client)
{
	if ((client = GetClientOfUserId(client)))
		if (IsValidClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
		{
			for (int i = 1; i <= MaxClients; i++)
				g_iTankSlayer[i][client] = 0;
			g_iTankHP[client] = g_iTankHurt[client] = GetClientHealth(client);//记录坦克出现时的血量.
		}
}
//玩家受伤.
public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int iDmg = event.GetInt("dmg_health");
	//int health = event.GetInt("health");
	
	if(IsValidClient(attacker) && GetClientTeam(attacker) == 2)
	{
		if(IsValidClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
		{
			if (IsPlayerState(client))//判断坦克是正常状态.
			{
				int iBot = IsClientIdle(attacker);
				g_iTankHurt[client] = GetClientHealth(client);//记录坦克剩余的血量.
				g_iSurvivorTankHurt[!g_iTankIdle ? attacker : !iBot ? attacker : iBot][client] += iDmg;
				//PrintToChat(!iBot ? attacker : iBot, "\x04[提示]\x05当前\x03%N\x05受到了\x04:\x03%d\x05点伤害,总计受到了\x04:\x03%.0f点伤害,总血量\x04:\x03%d.", client, iDmg, g_iSurvivorTankHurt[!iBot ? attacker : iBot][client], g_iTankHP[client]);
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PostThink, IsTankThink);
}

void IsTankThink(int client)
{
	if (IsValidClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && IsClientInKickQueue(client))
	{
		char sIndex[32];
		if(IsFakeClient(client))
		{
			FormatEx(sIndex, sizeof(sIndex), "%N", client);
			SplitString(sIndex, "Tank", sIndex, sizeof(sIndex));
		}
		else
			FormatEx(sIndex, sizeof(sIndex), "\x03%N", client);
		if (g_iTankRanking > 0)
			IsTankDamageSort(client, sIndex, "消失");
		IsResetVariable(client);//坦克死亡后重置整型变量.
	}
}
//坦克死亡,显示幸存者对坦克的伤害量.
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if(IsValidClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
	{
		if(IsValidClient(attacker) && GetClientTeam(attacker) == 2)
		{
			int iBot = IsClientIdle(attacker);
			g_iTankSlayer[iBot != 0 ? iBot : attacker][client] = 1;
			g_iSurvivorTankHurt[!g_iTankIdle ? attacker : iBot != 0 ? iBot : attacker][client] += g_iTankHurt[client];//坦克死亡后把剩余血量+给击杀者.
			//PrintToChat(attacker, "\x04[提示]\x05总共对\x03%N\x05造成了\x04:\x03%d\x05点伤害,总血量\x04:\x03%d.", client, g_iSurvivorTankHurt[attacker][client], g_iTankHP[client]);
		}
		char sIndex[32];
		if(IsFakeClient(client))
		{
			FormatEx(sIndex, sizeof(sIndex), "%N", client);
			SplitString(sIndex, "Tank", sIndex, sizeof(sIndex));
		}
		else
			FormatEx(sIndex, sizeof(sIndex), "\x03%N", client);
		if (g_iTankRanking > 0)
			IsTankDamageSort(client, sIndex, "死亡");
		IsResetVariable(client);//坦克死亡后重置整型变量.
	}
}
//坦克伤害排行榜.
void IsTankDamageSort(int client, char[] sIndex, char[] sWhys)
{
	int assister_count;
	int[][] assisters = new int[MaxClients][3];//动态数组.
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			int iBot = IsClientIdle(i);
			if (g_iSurvivorTankHurt[!iBot ? i : iBot][client] > 0)
			{
				assisters[assister_count][0] = !iBot ? i : iBot;
				assisters[assister_count][1] = g_iTankSlayer[!iBot ? i : iBot][client];
				assisters[assister_count][2] = g_iSurvivorTankHurt[!iBot ? i : iBot][client];
				assister_count++;
			}
		}
	}
	if (assister_count > 0)
	{
		SortCustom2D(assisters, assister_count, ClientValue2DSortDesc);

		int iCount, iTemp[3], iMax[3];
		int iTotalDamage = GetTotalDamage(client);
		int iTotalHealth = GetTotalHealth(g_iTankHP[client], iTotalDamage);

		char sInfo[128], sTemp[2][64];
		char[][][] sData = new char[assister_count][5][MAX_SIZE];//动态数组.
		
		FormatEx(sTemp[0], sizeof(sTemp[]), "\x05总血量\x04:\x03%d", g_iTankHP[client]);
		if(iTotalDamage > g_iTankHP[client])
			FormatEx(sTemp[1], sizeof(sTemp[]), "\x04+\x03%d", iTotalDamage - g_iTankHP[client]);
		ImplodeStrings(sTemp, sizeof(sTemp), "", sInfo, sizeof(sInfo));//打包字符串.
		PrintToChatAll("\x04坦克%s\x03%s\x04,%s\x05HP\x04.\n\x05显示伤害排名\x04:\x03(\x05总伤害\x04:\x05%d\x03)", sIndex, sWhys, sInfo, iTotalDamage);
		for (int x = 0; x < g_iTankRanking; x++)
		{
			int attacker = assisters[x][0];
			int slayer   = assisters[x][1];
			int damage   = assisters[x][2];
			
			if(damage > 0)
			{
				//PrintToChatAll("\x04%d\x05:\x03%.1f%%\x05,\x04伤害量\x05:\x03%d\x05,\x04名字\x05:\x03%N", x + 1, GetDamagePercentage(damage, client), damage, attacker);
				FormatEx(sData[x][0], MAX_SIZE, "%d", x + 1);
				FormatEx(sData[x][1], MAX_SIZE, "%.1f", GetDamagePercentage(damage, iTotalHealth));
				FormatEx(sData[x][2], MAX_SIZE, "%d", damage);
				FormatEx(sData[x][3], MAX_SIZE, "%s", GetTrueName(attacker));
				FormatEx(sData[x][4], MAX_SIZE, "%d", slayer);
				iCount += 1;
			}
		}
		//这部分用于显示对齐的计算.
		for (int y = 0; y < 3; y++)
			iTemp[y] = strlen(sData[0][y]);

		for (int x = 0; x < iCount; x++)
		{ 
			for (int y = 0; y < 3; y++)
				if(strlen(sData[x][y]) > iTemp[y])
					iTemp[y] = strlen(sData[x][y]);

			for (int y = 0; y < 3; y++)
				iMax[y] = iTemp[y] - strlen(sData[x][y]);

			PrintToChatAll("%s\x04%s%s\x05:\x04[\x03%s\x04]\x03[%s\x04%s%%%s\x03]\x03(\x04%s%s%s\x03)\x05%s", 
			IsWritesData(iMax[0], " "), sData[x][0], IsWritesData(iMax[0], " "), 
			StringToInt(sData[x][4]) == 0 ? "○" : "●", 
			IsWritesData(iMax[1], " "), sData[x][1], IsWritesData(iMax[1], " "), 
			IsWritesData(iMax[2], " "), sData[x][2], IsWritesData(iMax[2], " "), sData[x][3]);
		}
	}
}
//返回玩家名称.
char[] GetTrueName(int client)
{
	char sName[32];
	if (client > 0 && IsClientConnected(client))
		GetClientName(client, sName, sizeof(sName));
	ReplaceString(sName, sizeof(sName), "\n", "");//把换行符替换为空.
	ReplaceString(sName, sizeof(sName), "\r", "");//把换行符替换为空.
	return sName;
}
//用于计算的百分比.
int GetTotalHealth(int iTankHealth, int iTotalDamage)
{
	return iTotalDamage > iTankHealth ? iTotalDamage : iTankHealth;
}
//计算生还者对坦克的总伤害.
int GetTotalDamage(int client)
{
	int iTotalDamage;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			int iBot = IsClientIdle(i);
			if (g_iSurvivorTankHurt[!iBot ? i : iBot][client] > 0)
				iTotalDamage += g_iSurvivorTankHurt[!iBot ? i : iBot][client];
		}
	}
	return iTotalDamage;
}
//填入对应数量的内容.
stock char[] IsWritesData(int iNumber, char[] sValue)
{
	char sInfo[128];
	if(iNumber > 0)
	{
		int iLength = strlen(sValue) + 1;
		char[][] sData = new char[iNumber][iLength];//动态数组.
		for (int i = 0; i < iNumber; i++)
			strcopy(sData[i], iLength, sValue);
		ImplodeStrings(sData, iNumber, "", sInfo, sizeof(sInfo));//打包字符串.
	}
	return sInfo;
}
//计算百分比.
float GetDamagePercentage(int iDamage, int iTotalHealth)
{
	return float(iDamage) / float(iTotalHealth) * 100.0;
}
//2D排序的回调.
int ClientValue2DSortDesc(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	if (elem1[2] > elem2[2])
		return -1;
	else if (elem2[2] > elem1[2])
		return 1;
		
	return 0;
}
//坦克死亡后重置整型变量.
void IsResetVariable(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iTankSlayer[i][client] = 0;
		g_iSurvivorTankHurt[i][client] = 0;
	}
	g_iTankHurt[client] = 0;
}
//判断玩家有效性.
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
//正常状态.
stock bool IsPlayerState(int client)
{
	return !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}
//这个属性特别好用.
int IsClientIdle(int client)
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}