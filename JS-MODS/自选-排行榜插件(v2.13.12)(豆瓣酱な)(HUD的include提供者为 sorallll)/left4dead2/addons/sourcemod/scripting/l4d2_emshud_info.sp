#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <left4dhooks>
#include <l4d2_ems_hud>

#define CVAR_FLAGS		FCVAR_NOTIFY
#define PLUGIN_VERSION	"2.13.12"

#define	Number_1		(1 << 0)
#define Number_2		(1 << 1)
#define Number_4		(1 << 2)
#define Number_8		(1 << 3)
#define Number_16		(1 << 4)
#define Number_32		(1 << 5)
#define Number_64		(1 << 6)
#define Number_128		(1 << 7)

//对抗模式.
char g_sModeVersus[][] = 
{
	"versus",		//对抗模式
	"teamversus ",	//团队对抗
	"scavenge",		//团队清道夫
	"teamscavenge",	//团队清道夫
	"community3",	//骑师派对
	"community6",	//药抗模式
	"mutation11",	//没有救赎
	"mutation12",	//写实对抗
	"mutation13",	//清道肆虐
	"mutation15",	//生存对抗
	"mutation18",	//失血对抗
	"mutation19"	//坦克派对?
};

//单人模式.
char g_sModeSingle[][] = 
{
	"mutation1", //孤身一人
	"mutation17" //孤胆枪手
};

//设置数组数量(最大值:9).
#define Array	9
//设置数组数量(最大值:5).
#define Amount	5

bool  g_bMapRunTime, g_bShowHUD, g_bShowServerName, g_bDisplayNumber, g_bSwitchHud = true;
float g_fMapRunTime[2], g_fMeleeNerf2, g_fTempValue, g_fVsBossBuff, g_fMapMaxFlow;
float iCoord[] = {0.00, 0.055, 0.110, 0.160, 0.215, 0.265, 0.315, 0.365};//设置每个HUD类型的预设坐标.

int    g_iDisplayNumber, g_iDeathTime, g_iPlayerNum, g_iChapterTotal[2], g_iCumulativeTotal[2], g_iKillSpecial[MAXPLAYERS+1], g_iHeadSpecial[MAXPLAYERS+1], g_iKillZombie[MAXPLAYERS+1], g_iDmgHealth[2][MAXPLAYERS+1];

int    g_iSurvivorHealth, g_iMaxReviveCount, g_iPlayersNumber, g_iShowServerName, g_iShowServerTimer, g_iShowServerNumber, g_iShowRunningTime, g_iShowServerTime, g_iShowKillNumber, g_iFakeRanking, g_iDeathFake, g_iReportLine, g_iReportTime, g_iTypeRanking, g_iDispRanking, g_iInfoRanking;
ConVar g_hSurvivorHealth, g_hMaxReviveCount, g_hPlayersNumber, g_hShowServerName, g_hShowServerTimer, g_hShowServerNumber, g_hShowRunningTime, g_hShowServerTime, g_hShowKillNumber, g_hFakeRanking, g_hDeathFake, g_hReportLine, g_hReportTime, g_hTypeRanking, g_hDispRanking, g_hInfoRanking;
int g_iMaxChapters, g_iCurrentChapter;
ConVar g_hHostName, g_cVsBossBuff;
char g_sTemp[Amount - 1][128], g_sDeathKill[Amount][128], g_sDeathInfo[256];
char g_sDate[][] = {"天", "时", "分", "秒"};
char g_sTitle[][] = {"状态", "血量", "特感", "爆头", "丧尸", "被黑", "友伤", "名字"};//这里最好不要改变长度,否则自动对齐可能怪怪的.
char g_sWeekName[][] = {"一", "二", "三", "四", "五", "六", "日"};
char g_sZombieName[][] = {"舌头","胖子","猎人","口水","猴子","牛牛","女巫","坦克"};

Handle g_hTimerHUD, g_hTimerCSKill, g_hDisplayNumber;

public Plugin myinfo = 
{
	name 			= "l4d2_emshud_info",
	author 			= "豆瓣酱な | HUD的include提供者:sorallll",
	description 	= "HUD显示各种信息.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public void OnPluginStart()
{
	LoadGameCFG();
	
	HookEvent("round_end",		Event_RoundEnd);	//回合结束.
	HookEvent("round_start",	Event_RoundStart);	//回合开始.
	HookEvent("player_hurt",	Event_PlayerHurt);	//玩家受伤.
	HookEvent("player_death",	Event_PlayerDeath);	//玩家死亡.

	RegConsoleCmd("sm_hud", CommandSwitchHud, "开启或关闭所有HUD.");
	
	g_hHostName			= FindConVar("hostname");
	g_cVsBossBuff		= FindConVar("versus_boss_buffer");
	g_hSurvivorHealth	= FindConVar("survivor_limp_health");
	g_hMaxReviveCount	= FindConVar("survivor_max_incapacitated_count");

	g_hPlayersNumber	= CreateConVar("l4d2_emshud_show_players_number", "127", "显示玩家数量信息(需要启用的功能数字相加,值为<0>时自动隐藏). 0=禁用, 1=连接, 2=闲置, 4=旁观, 8=丧尸, 16=女巫, 32=特感, 64=生还, 127=全部.", CVAR_FLAGS);
	g_hShowServerName	= CreateConVar("l4d2_emshud_show_server_name_type", "2", "设置服务器名称的显示方式. -1=居中显示, 0=禁用, 1=从右到左显示, >1=连续显示多少次.", CVAR_FLAGS);
	g_hShowServerTimer	= CreateConVar("l4d2_emshud_show_server_name_time", "10", "设置服务器名字的显示间隔(秒).", CVAR_FLAGS);
	g_hShowServerNumber	= CreateConVar("l4d2_emshud_show_server_name_number", "31", "显示服务器人数,路程,坦克和女巫刷新百分比. 0=禁用, 1=服务器人数, 2=地图章节数量, 4=路程显示, 8=刷坦克路程(需要额外配套插件支持), 16=刷女巫路程(需要额外配套插件支持), 31=全部.", CVAR_FLAGS);
	g_hShowRunningTime	= CreateConVar("l4d2_emshud_show_running_time", "3", "显示运行的时间(需要启用的功能数字相加). 0=禁用, 1=累计运行, 2=本次运行.", CVAR_FLAGS);
	g_hShowServerTime	= CreateConVar("l4d2_emshud_show_server_time", "7", "显示服务器时间(需要启用的功能数字相加). 0=禁用, 1=日期, 2=时间, 4=星期.", CVAR_FLAGS);
	g_hShowKillNumber	= CreateConVar("l4d2_emshud_show_kill_number", "3", "显示击杀总数量(需要启用的功能数字相加). 0=禁用, 1=累计击杀, 2=章节击杀.", CVAR_FLAGS);
	g_hFakeRanking		= CreateConVar("l4d2_emshud_ranking_Fake", "0", "排行榜显示电脑幸存者. 0=显示, 1=忽略.", CVAR_FLAGS);
	g_hInfoRanking		= CreateConVar("l4d2_emshud_ranking_Info", "8", "排行榜总共显示多少行(最多8行). 0=禁用.", CVAR_FLAGS);
	g_hTypeRanking		= CreateConVar("l4d2_emshud_ranking_Type", "255", "排行榜显示那些内容(需要启用的功能数字相加). 0=禁用, 1=状态, 2=血量, 4=特感, 8=爆头, 16=丧尸, 32=被黑, 64=友伤, 128=名字, 255=全部.", CVAR_FLAGS);
	g_hDispRanking		= CreateConVar("l4d2_emshud_ranking_disp", "63", "那些内容的值都为<0>时自动隐藏(需要自动隐藏的功能数字相加). 0=显示, 1=血量, 2=特感, 4=爆头, 8=丧尸, 16=被黑, 32=友伤, 63=全部.", CVAR_FLAGS);
	g_hDeathFake		= CreateConVar("l4d2_emshud_death_Fake", "0", "击杀播报显示电脑幸存者. 0=显示, 1=忽略.", CVAR_FLAGS);
	g_hReportLine		= CreateConVar("l4d2_emshud_death_report_line", "5", "设置仿CS的击杀播报显示多少行. 0=禁用(最多5行).", CVAR_FLAGS);
	g_hReportTime		= CreateConVar("l4d2_emshud_death_report_time", "10", "设置多少秒后删除击杀播报首行(最低5秒).", CVAR_FLAGS);
	
	g_hSurvivorHealth.AddChangeHook(ConVarChanged);
	g_hMaxReviveCount.AddChangeHook(ConVarChanged);
	g_cVsBossBuff.AddChangeHook(ConVarChanged);
	g_hPlayersNumber.AddChangeHook(ConVarChanged);
	g_hShowServerName.AddChangeHook(ConVarChanged);
	g_hShowServerTimer.AddChangeHook(ConVarChanged);
	g_hShowServerNumber.AddChangeHook(ConVarChanged);
	g_hShowRunningTime.AddChangeHook(ConVarChanged);
	g_hShowServerTime.AddChangeHook(ConVarChanged);
	g_hShowKillNumber.AddChangeHook(ConVarChanged);
	g_hFakeRanking.AddChangeHook(ConVarChanged);
	g_hInfoRanking.AddChangeHook(ConVarChanged);
	g_hTypeRanking.AddChangeHook(ConVarChanged);
	g_hDispRanking.AddChangeHook(ConVarChanged);
	g_hDeathFake.AddChangeHook(ConVarChanged);
	g_hReportLine.AddChangeHook(ConVarChanged);
	g_hReportTime.AddChangeHook(ConVarChanged);
	
	AutoExecConfig(true, "l4d2_emshud_info");//生成指定文件名的CFG.

	g_fMapRunTime[0] = GetEngineTime();
}

/* https://github.com/lakwsh */
void LoadGameCFG()
{
	GameData hGameData = new GameData("l4d2_emshud_info");
	if(!hGameData) 
		SetFailState("Failed to load 'l4d2_emshud_info.txt' gamedata.");
	DHookSetup hDetour = DHookCreateFromConf(hGameData, "HibernationUpdate");
	CloseHandle(hGameData);
	if(!hDetour || !DHookEnableDetour(hDetour, true, OnHibernationUpdate)) 
		SetFailState("Failed to hook HibernationUpdate");
}

//服务器里没人后触发一次.
public MRESReturn OnHibernationUpdate(DHookParam hParams)
{
	bool hibernating = DHookGetParam(hParams, 1);

	if(!hibernating) 
		return MRES_Ignored;
		
	g_bMapRunTime = false;
	return MRES_Handled;
}

public void OnConfigsExecuted()
{
	g_iMaxChapters = L4D_GetMaxChapters();
	g_iCurrentChapter = L4D_GetCurrentChapter();
	g_fMapMaxFlow = L4D2Direct_GetMapMaxFlowDistance();
	
	if (g_bMapRunTime == false)
	{
		g_bMapRunTime = true;
		g_fMapRunTime[1] = GetEngineTime();
	}
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iSurvivorHealth	= g_hSurvivorHealth.IntValue;
	g_iMaxReviveCount	= g_hMaxReviveCount.IntValue;
	g_iPlayersNumber	= g_hPlayersNumber.IntValue;
	g_iShowServerName	= g_hShowServerName.IntValue;
	g_iShowServerTimer	= g_hShowServerTimer.IntValue;
	g_iShowServerNumber	= g_hShowServerNumber.IntValue;
	g_iShowRunningTime	= g_hShowRunningTime.IntValue;
	g_iShowServerTime	= g_hShowServerTime.IntValue;
	g_iShowKillNumber	= g_hShowKillNumber.IntValue;
	g_iFakeRanking		= g_hFakeRanking.IntValue;
	g_iInfoRanking		= g_hInfoRanking.IntValue;
	g_iTypeRanking		= g_hTypeRanking.IntValue;
	g_iDispRanking		= g_hDispRanking.IntValue;
	g_iDeathFake		= g_hDeathFake.IntValue;
	g_iReportLine		= g_hReportLine.IntValue;
	g_iReportTime		= g_hReportTime.IntValue;
	g_fVsBossBuff		= g_cVsBossBuff.FloatValue;
	
	if( g_iReportTime < 5)
		g_iReportTime = 5;
	if( g_iReportLine > Amount)
		g_iReportLine = Amount;
	if( g_iInfoRanking > Array - 1)
		g_iInfoRanking = Array - 1;
}

public Action CommandSwitchHud(int client, int args)
{ 
	if(bCheckClientAccess(client))
		IsDisplayHud(client);
	else
		ReplyToCommand(client, "\x04[提示]\x05你无权使用该指令.");
	return Plugin_Handled;
}

void IsDisplayHud(int client)
{
	if(g_bSwitchHud == true)
	{
		g_bSwitchHud = false;//重新赋值.
		delete g_hTimerHUD;//停止计时器.
		RequestFrame(IsRequestRemoveHUD);//延迟一帧清除HUD.
		ReplyToCommand(client, "\x04[提示]\x03已关闭\x05所有\x04HUD\x05显示\x04.");
	}
	else
	{
		IsShowAllHUD();//显示指定的HUD.
		g_bSwitchHud = true;//重新赋值.
		delete g_hTimerHUD;//停止计时器.
		g_hTimerHUD = CreateTimer(1.0, DisplayInfo, _, TIMER_REPEAT);//创建计时器
		ReplyToCommand(client, "\x04[提示]\x03已开启\x05所有\x04HUD\x05显示\x04.");
	}
}

//延迟一帧清除HUD.
void IsRequestRemoveHUD()
{
	IsRemoveListHUD();//清除排行榜HUD.
	IsRemoveOtherHUD();//清除其它的HUD.
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int iDmg = event.GetInt("dmg_health");
	
	if(IsValidClient(client) && GetClientTeam(client) == 2)
	{
		if(IsValidClient(attacker) && GetClientTeam(attacker) == 2)
		{
			int iBot[2];
			iBot[0] = IsClientIdle(client);
			iBot[1] = IsClientIdle(attacker);

			if(iBot[0] != 0)
			{
				if(IsValidClient(iBot[0]))
					g_iDmgHealth[0][iBot[0]] += iDmg;
			}
			else
				g_iDmgHealth[0][client] += iDmg;
			if(iBot[1] != 0)
			{
				if(IsValidClient(iBot[1]))
					g_iDmgHealth[1][iBot[1]] += iDmg;
			}
			else
				g_iDmgHealth[1][attacker] += iDmg;
		}
	}
}

//玩家死亡.
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int iHeadshot = GetEventInt(event, "headshot");

	if(IsValidClient(attacker))
	{
		switch (GetClientTeam(attacker))
		{
			case 2:
			{
				char classname[32];
				int entity = GetEventInt(event, "entityid");
				GetEdictClassname(entity, classname, sizeof(classname));
				if (IsValidEdict(entity) && strcmp(classname, "infected") == 0)
				{
					int iBot = IsClientIdle(attacker);
					g_iChapterTotal[0] += 1;
					g_iCumulativeTotal[0] += 1;
					g_iKillZombie[iBot != 0 ? iBot : attacker] += 1;
				}
				if(IsValidClient(client) && GetClientTeam(client) == 3)
				{
					g_iChapterTotal[1] += 1;
					g_iCumulativeTotal[1] += 1;
					int iBot = IsClientIdle(attacker);
			
					if(iHeadshot)
						g_iHeadSpecial[iBot != 0 ? iBot : attacker] += 1;
					g_iKillSpecial[iBot != 0 ? iBot : attacker] += 1;
					
					if (g_iDeathFake != 0 && IsFakeClient(iBot != 0 ? iBot : attacker))//这里判断玩家是否在游戏中或是否显示电脑幸存者.
						return;
					IsImitationCSKillTip(client, attacker, iHeadshot ? "★" : "☆");
				}
			}
			case 3:
				if(IsValidClient(client) && GetClientTeam(client) == 2)
					IsImitationCSKillTip(client, attacker, "☆");
		}
	}
}

void IsDisplayTimeOut()
{
	delete g_hTimerCSKill;
	g_hTimerCSKill = CreateTimer(1.0, IsTimerImitationCSKillTip, _, TIMER_REPEAT);
}

int g_iTemp;
public Action IsTimerImitationCSKillTip(Handle timer)
{
	if(g_iReportLine <= 0)
		return Plugin_Continue;

	int g_iDeathKill = GetStringContent();
	if(g_iDeathKill > 0)
	{
		if(g_iDeathTime < g_iReportTime)
		{
			g_iDeathTime += 1;
			return Plugin_Continue;
		}
		if(g_iDeathKill >= g_iReportLine)
		{
			g_iTemp = g_iReportLine - 1;
			if(g_iDeathKill - 1 != g_iTemp)
				g_iTemp = g_iDeathKill - 1;
			g_iDeathKill = g_iTemp;
		}
		IsReorderDeath(g_iDeathKill);
		g_sDeathKill[g_iDeathKill][0] = '\0';
		ImplodeStrings(g_sDeathKill, sizeof(g_sDeathKill), "\n", g_sDeathInfo, sizeof(g_sDeathInfo));//打包字符串.
	}
	g_iDeathTime = 0;
	return Plugin_Continue;
}

//仿CS击杀提示.
void IsImitationCSKillTip(int client, int victim, char[] type)
{
	if (g_iReportLine <= 0)
		return;
	
	int g_iDeathKill = GetStringContent();
	if(g_iDeathKill >= g_iReportLine)
	{
		g_iTemp = g_iReportLine - 1;
		if(g_iDeathKill - 1 != g_iTemp)
			g_iTemp = g_iDeathKill - 1;
		g_iDeathKill = g_iTemp;
		IsReorderDeath(g_iDeathKill);
	}
	FormatEx(g_sDeathKill[g_iDeathKill], sizeof(g_sDeathKill[]), "%s%s%s", GetPlayerName(victim), type, GetPlayerName(client));
	ImplodeStrings(g_sDeathKill, sizeof(g_sDeathKill), "\n", g_sDeathInfo, sizeof(g_sDeathInfo));//打包字符串.
}
//清除数组第一行的内容,然后把后面的内容全部上移.
void IsReorderDeath(int iCycle)
{
	for (int i = 0; i < iCycle; i++)
		strcopy(g_sTemp[i], sizeof(g_sTemp[]), g_sDeathKill[i + 1]);
	for (int i = 0; i < iCycle; i++)
		strcopy(g_sDeathKill[i], sizeof(g_sDeathKill[]), g_sTemp[i]);
}
//获取数组里有多少内容.
int GetStringContent()
{
	for (int i = 0; i < sizeof(g_sDeathKill); i++)
		if(g_sDeathKill[i][0] == '\0')
			return i;//break;
		
	return sizeof(g_sDeathKill);
}

char[] GetPlayerName(int client)
{
	char g_sName[16];//因为字符限制,显示5行只能限制到16个字符.
	switch (GetClientTeam(client))
	{
		case 2:
		{
			int iBot = IsClientIdle(client);
			FormatEx(g_sName, sizeof(g_sName), "%N", iBot != 0 ? iBot : client);
		}
		case 3:
			strcopy(g_sName, sizeof(g_sName), g_sZombieName[GetEntProp(client, Prop_Send, "m_zombieClass") - 1]);
	}
	return g_sName;
}

//玩家连接
public void OnClientConnected(int client)
{   
	g_iKillSpecial[client] = 0;
	g_iHeadSpecial[client] = 0;
	g_iKillZombie[client] = 0;

	if (!IsFakeClient(client))
		g_iPlayerNum += 1;
}

//玩家离开.
public void OnClientDisconnect(int client)
{   
	g_iKillSpecial[client] = 0;
	g_iHeadSpecial[client] = 0;
	g_iKillZombie[client] = 0;

	if (!IsFakeClient(client))
		g_iPlayerNum -= 1;
}

//地图开始
public void OnMapStart()
{
	GetCvars();
	EnableHUD();
	g_iPlayerNum = 0;
	g_iDisplayNumber = 0;
	delete g_hDisplayNumber;
	g_bDisplayNumber = true;
	g_bShowServerName = false;
}

//地图结束.
public void OnMapEnd()
{
	delete g_hTimerCSKill;
}

//回合开始.
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_fMeleeNerf2 = 1.0;
	g_bShowHUD = false;
	//重置字符串.
	IsResetString();
	//创建计时器.
	IsDisplayTimeOut();
	//创建计时器显示HUD.
	IsCreateTimerShowHUD();
	//重置章节击杀特感和丧尸数量.
	for (int i = 0; i < sizeof(g_iChapterTotal); i++)
		g_iChapterTotal[i] = 0;//重置章节击杀特感和丧尸数量.
	
	//重置玩家友伤,击杀特感和丧尸数量.
	for (int i = 1; i <= MaxClients; i++)
	{
		for (int y = 0; y < sizeof(g_iDmgHealth); y++)
			g_iDmgHealth[y][i] = 0;
		g_iKillSpecial[i] = 0;
		g_iHeadSpecial[i] = 0;
		g_iKillZombie[i] = 0;
	}
}

//回合结束.
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bShowHUD = true;
	IsResetString();//重置字符串.
	IsRemoveListHUD();//清除排行榜HUD.
	g_fMeleeNerf2 = 1.0;
	delete g_hTimerCSKill;
}

//重置字符串.
void IsResetString()
{
	for (int i = 0; i < sizeof(g_sDeathKill); i++)
		g_sDeathKill[i][0] = '\0';
	g_sDeathInfo[0] = '\0';
}

//创建计时器.
void IsCreateTimerShowHUD()
{
	if(g_hTimerHUD == null)//不存在计时器才创建.
		g_hTimerHUD = CreateTimer(1.0, DisplayInfo, _, TIMER_REPEAT);
}

public Action DisplayInfo(Handle timer)
{
	if(g_bSwitchHud == true)
	{
		IsRemoveListHUD();//清除排行榜HUD.
		IsRemoveOtherHUD();//清除其它的HUD.
		IsShowAllHUD();//显示指定的HUD.
	}
	return Plugin_Continue;
}

//清除其它的HUD.
void IsRemoveOtherHUD()
{
	//删除仿CS击杀提示HUD.
	if(HUDSlotIsUsed(HUD_FAR_LEFT))
		RemoveHUD(HUD_FAR_LEFT);
	
	//删除玩家人数HUD.
	if(HUDSlotIsUsed(HUD_SCORE_1))
		RemoveHUD(HUD_SCORE_1);
	
	//删除击杀累计HUD.
	if(HUDSlotIsUsed(HUD_MID_BOX))
		RemoveHUD(HUD_MID_BOX);

	//删除运行时间HUD.
	if(HUDSlotIsUsed(HUD_SCORE_TITLE))
		RemoveHUD(HUD_SCORE_TITLE);
	
	//删除当前时间HUD.
	if(HUDSlotIsUsed(HUD_MID_TOP))
		RemoveHUD(HUD_MID_TOP);

	//删除玩家数量HUD.
	if(HUDSlotIsUsed(HUD_SCORE_4))
		RemoveHUD(HUD_SCORE_4);
	
	//删除服名HUD.
	if(HUDSlotIsUsed(HUD_LEFT_TOP))
		RemoveHUD(HUD_LEFT_TOP);
}

//清除排行榜HUD.
void IsRemoveListHUD()
{
	/* 以下是排行榜相关HUD. */
	//删除玩家状态HUD.
	if(HUDSlotIsUsed(HUD_LEFT_BOT))
		RemoveHUD(HUD_LEFT_BOT);
	
	//删除击杀数量HUD.
	if(HUDSlotIsUsed(HUD_MID_BOT))
		RemoveHUD(HUD_MID_BOT);

	//删除爆头数量HUD.
	if(HUDSlotIsUsed(HUD_RIGHT_TOP))
		RemoveHUD(HUD_RIGHT_TOP);

	//删除玩家血量HUD.
	if(HUDSlotIsUsed(HUD_SCORE_3))
		RemoveHUD(HUD_SCORE_3);

	//删除丧尸统计HUD.
	if(HUDSlotIsUsed(HUD_TICKER))
		RemoveHUD(HUD_TICKER);

	//删除被黑统计HUD.
	if(HUDSlotIsUsed(HUD_FAR_RIGHT))
		RemoveHUD(HUD_FAR_RIGHT);
	
	//删除友伤统计HUD.
	if(HUDSlotIsUsed(HUD_SCORE_2))
		RemoveHUD(HUD_SCORE_2);
		
	//删除玩家名字HUD.
	if(HUDSlotIsUsed(HUD_RIGHT_BOT))
		RemoveHUD(HUD_RIGHT_BOT);
}

//显示指定的HUD.
void IsShowAllHUD()
{
	//显示仿CS击杀提示.
	if(g_iReportLine > 0)
		IsDeathMessage();
	//显示服务器时间.
	if(g_iShowServerTime > 0)
		IsShowServerTime();
	//显示运行的时间.
	if(g_iShowRunningTime > 0)
		IsShowRunningTime();
	//显示累计击杀数.
	if(g_iShowKillNumber > 0)
		IsCumulativeStatistics();
	//显示连接,闲置,旁观,特感和幸存者数量.
	if(g_iPlayersNumber > 0)
		IsPlayersNumber();
	//显示服务器名字.
	if(g_iShowServerName <= -1)
		IsShowServerName();
	//显示服务器人数.
	if(g_iShowServerNumber > 0)
		IsShowServersNumber();
	//显示击杀特感排行榜.
	if(g_iInfoRanking > 0)
		IsKillLeaderboards();
}

//开局提示.
public void OnClientPostAdminCheck(int client)
{
	if(!IsFakeClient(client) && g_bShowServerName == false)
	{
		g_fTempValue = IsDynamicVariable(GetConVarInt(FindConVar("sv_maxupdaterate")), RoundToNearest(1.0 / GetTickInterval()));
		g_bShowServerName = true;
	}
}

float IsDynamicVariable(int iSvMaxUpdateRate, int iTickInterval)
{
	float g_fTemp = 0.003;
	if(iSvMaxUpdateRate > 30 && iTickInterval == 30)
		iSvMaxUpdateRate = iTickInterval;
	for (int i = 0; i < iSvMaxUpdateRate; i++)
		g_fTemp -= 0.00002;
	return g_fTemp;
}

public void OnGameFrame()
{
	if(g_iShowServerName <= 0 || g_bShowServerName == false || g_bDisplayNumber == false || g_bSwitchHud == false)
		return;

	IsShowServerName();
}

//显示服务器名字.
void IsShowServerName()
{
	if(g_iShowServerName <= -1)
	{
		HUDSetLayout(HUD_LEFT_TOP, HUD_FLAG_ALIGN_CENTER|HUD_FLAG_NOBG|HUD_FLAG_TEXT|HUD_FLAG_BLINK, GetHostName());
		HUDPlace(HUD_LEFT_TOP, 0.00,0.03, 1.0,0.03);
	}
	else
	{
		g_fMeleeNerf2 -= g_fTempValue;
		if(g_fMeleeNerf2 <= 0)
		{
			g_fMeleeNerf2 = 1.0;
			if(g_iShowServerName > 1)
			{
				g_iDisplayNumber += 1;
				if(g_iDisplayNumber >= g_iShowServerName)
				{
					g_bDisplayNumber = false;
					if(HUDSlotIsUsed(HUD_LEFT_TOP))
						RemoveHUD(HUD_LEFT_TOP);
					if(g_hDisplayNumber == null)
						g_hDisplayNumber = CreateTimer(float(g_iShowServerTimer), IsDisplayNumberTimer);
					return;
				}
			}
		}
			
		HUDSetLayout(HUD_LEFT_TOP, HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEXT|HUD_FLAG_BLINK, GetHostName());
		HUDPlace(HUD_LEFT_TOP, g_fMeleeNerf2,0.03, 1.0,0.03);
	}
}

public Action IsDisplayNumberTimer(Handle timer)
{
	g_iDisplayNumber = 0;
	g_bDisplayNumber = true;
	g_hDisplayNumber = null;
	return Plugin_Continue;
}

//显示击杀特感排行榜.
void IsKillLeaderboards()
{
	if (g_bShowHUD || g_iTypeRanking == 0 || GetPlayersMaxNumber(2, false) <= 0)//没有幸存者或禁用时直接返回，不执行后面的操作.
		return;
	
	int temp[sizeof(g_sTitle) - 2], iMax[sizeof(g_sTitle) - 2], ranking_count = 1, assister_count, iHudCoord;
	int[][] assisters = new int[MaxClients][sizeof(g_sTitle) - 1];//更改为动态大小的数组.
	
	char g_sData[sizeof(g_sTitle)][Array][128], g_sInfo[sizeof(g_sTitle)][256];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			int iBot = IsClientIdle(i);

			if (iBot != 0 && IsClientConnected(i) && !IsClientInGame(iBot) || g_iFakeRanking != 0 && IsFakeClient(iBot == 0 ? i : iBot))//这里判断玩家是否在游戏中或是否显示电脑幸存者.
				continue;

			assisters[assister_count][0] = !iBot ? i : iBot;
			assisters[assister_count][1] = GetSurvivorHP(i);
			assisters[assister_count][2] = g_iKillSpecial[!iBot ? i : iBot];
			assisters[assister_count][3] = g_iHeadSpecial[!iBot ? i : iBot];
			assisters[assister_count][4] = g_iKillZombie[!iBot ? i : iBot];
			assisters[assister_count][5] = g_iDmgHealth[0][!iBot ? i : iBot] > 9999 ? 9999 : g_iDmgHealth[0][!iBot ? i : iBot];
			assisters[assister_count][6] = g_iDmgHealth[1][!iBot ? i : iBot] > 9999 ? 9999 : g_iDmgHealth[1][!iBot ? i : iBot];
			assister_count+=1;
		}
	}
	//以最大击杀数排序.
	SortCustom2D(assisters, assister_count, ClientValue2DSortDesc);

	for (int z = 0; z < sizeof(g_sData); z++)
		strcopy(g_sData[z][0], sizeof(g_sData[][]), g_sTitle[z]);
	
	for (int x = 0; x < g_iInfoRanking; x++)
	{
		int j = x + 1;
		int client	= assisters[x][0];
		int iHealth	= assisters[x][1];
		int iKill	= assisters[x][2];
		int iHead	= assisters[x][3];
		int iZombie	= assisters[x][4];
		int iHurt	= assisters[x][5];
		int iDmg	= assisters[x][6];
		
		if (IsValidClient(client))//因为要显示闲置玩家的数据,所以这里不要判断团队.
		{
			int Player = iGetBotOfIdlePlayer(client);
			strcopy(g_sData[0][j],	sizeof(g_sData[][]), GetSurvivorStatus(Player != 0 ? Player : client));

			IntToString(iHealth,	g_sData[1][j], sizeof(g_sData[][]));
			IntToString(iKill,		g_sData[2][j], sizeof(g_sData[][]));
			IntToString(iHead,		g_sData[3][j], sizeof(g_sData[][]));
			IntToString(iZombie,	g_sData[4][j], sizeof(g_sData[][]));
			IntToString(iHurt,		g_sData[5][j], sizeof(g_sData[][]));
			IntToString(iDmg,		g_sData[6][j], sizeof(g_sData[][]));

			strcopy(g_sData[7][j], sizeof(g_sData[][]), GetTrueName(Player != 0 ? Player : client));
			ranking_count += 1;
		}
	}
	int quantity = sizeof(g_sTitle) - 2;
	for (int k = 1; k < quantity; k++)
		temp[k] = strlen(g_sData[k + 1][1]);

	for (int j = 1; j < ranking_count; j++)
		for (int y = 0; y < quantity; y++)
			if(strlen(g_sData[y + 1][j]) > temp[y])
				temp[y] = strlen(g_sData[y + 1][j]);
	
	//这里必须重新循环,不然数字不能对齐.
	for (int y = 1; y < ranking_count; y++)
	{
		for (int h = 0; h < quantity; h++)
		{
			iMax[h] = temp[h] - strlen(g_sData[h + 1][y]);

			if(iMax[h] > 0)
				Format(g_sData[h + 1][y], sizeof(g_sData[][]), "%s%s", GetAddSpacesMax(iMax[h], " "),  g_sData[h + 1][y]);//这里不能使用FormatEx
		}
	}

	for (int y = 0; y < sizeof(g_sData); y++)
		ImplodeStrings(g_sData[y], sizeof(g_sData[]), "\n", g_sInfo[y], sizeof(g_sInfo[]));//打包字符串.
	
	float g_fPos = 0.03;
	if(g_iShowServerName > 0)
		g_fPos += 0.03;
	if(g_iTypeRanking & Number_1)
	{
		HUDSetLayout(HUD_LEFT_BOT,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[0]);
		HUDPlace(HUD_LEFT_BOT, iCoord[iHudCoord],g_fPos,1.0,0.35);
		iHudCoord += 1;
	}
	if((g_iTypeRanking & Number_2))
	{
		if(g_iDispRanking == 0 || !(g_iDispRanking & Number_1))
		{
			HUDSetLayout(HUD_MID_BOT,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[1]);
			HUDPlace(HUD_MID_BOT, iCoord[iHudCoord],g_fPos,1.0,0.35);
			iHudCoord += 1;
		}
		else
		{
			if(GetPlayerStatus(g_sInfo[1], ranking_count))
			{
				HUDSetLayout(HUD_MID_BOT,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[1]);
				HUDPlace(HUD_MID_BOT, iCoord[iHudCoord],g_fPos,1.0,0.35);
				iHudCoord += 1;
			}
		}
	}
	if((g_iTypeRanking & Number_4))
	{
		if(g_iDispRanking == 0 || !(g_iDispRanking & Number_2))
		{
			HUDSetLayout(HUD_RIGHT_TOP,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[2]);
			HUDPlace(HUD_RIGHT_TOP, iCoord[iHudCoord],g_fPos,1.0,0.35);
			iHudCoord += 1;
		}
		else
		{
			if(GetPlayerStatus(g_sInfo[2], ranking_count))
			{
				HUDSetLayout(HUD_RIGHT_TOP,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[2]);
				HUDPlace(HUD_RIGHT_TOP, iCoord[iHudCoord],g_fPos,1.0,0.35);
				iHudCoord += 1;
			}
		}
	}
	if ((g_iTypeRanking & Number_8))
	{
		if(g_iDispRanking == 0 || !(g_iDispRanking & Number_4))
		{
			HUDSetLayout(HUD_SCORE_3,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[3]);
			HUDPlace(HUD_SCORE_3, iCoord[iHudCoord],g_fPos,1.0,0.35);
			iHudCoord += 1;
		}
		else
		{
			if(GetPlayerStatus(g_sInfo[3], ranking_count))
			{
				HUDSetLayout(HUD_SCORE_3,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[3]);
				HUDPlace(HUD_SCORE_3, iCoord[iHudCoord],g_fPos,1.0,0.35);
				iHudCoord += 1;
			}
		}
	}
	if((g_iTypeRanking & Number_16))
	{
		if(g_iDispRanking == 0 || !(g_iDispRanking & Number_8))
		{
			HUDSetLayout(HUD_TICKER,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[4]);
			HUDPlace(HUD_TICKER, iCoord[iHudCoord],g_fPos,1.0,0.35);
			iHudCoord += 1;
		}
		else
		{
			if(GetPlayerStatus(g_sInfo[4], ranking_count))
			{
				HUDSetLayout(HUD_TICKER,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[4]);
				HUDPlace(HUD_TICKER, iCoord[iHudCoord],g_fPos,1.0,0.35);
				iHudCoord += 1;
			}
		}
	}
	if((g_iTypeRanking & Number_32))
	{
		if(g_iDispRanking == 0 || !(g_iDispRanking & Number_16))
		{
			HUDSetLayout(HUD_FAR_RIGHT,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[5]);
			HUDPlace(HUD_FAR_RIGHT, iCoord[iHudCoord],g_fPos,1.0,0.35);
			iHudCoord += 1;
		}
		else
		{
			if(GetPlayerStatus(g_sInfo[5], ranking_count))
			{
				HUDSetLayout(HUD_FAR_RIGHT,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[5]);
				HUDPlace(HUD_FAR_RIGHT, iCoord[iHudCoord],g_fPos,1.0,0.35);
				iHudCoord += 1;
			}
		}
	}
	if((g_iTypeRanking & Number_64))
	{
		if(g_iDispRanking == 0 || !(g_iDispRanking & Number_32))
		{
			HUDSetLayout(HUD_SCORE_2,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[6]);
			HUDPlace(HUD_SCORE_2, iCoord[iHudCoord],g_fPos,1.0,0.35);
			iHudCoord += 1;
		}
		else
		{
			if(GetPlayerStatus(g_sInfo[6], ranking_count))
			{
				HUDSetLayout(HUD_SCORE_2,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[6]);
				HUDPlace(HUD_SCORE_2, iCoord[iHudCoord],g_fPos,1.0,0.35);
				iHudCoord += 1;
			}
		}
	}
	if(g_iTypeRanking & Number_128)
	{
		HUDSetLayout(HUD_RIGHT_BOT,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[7]);
		HUDPlace(HUD_RIGHT_BOT, iCoord[iHudCoord],g_fPos,1.0,0.35);
		iHudCoord += 1;
	}
}

bool GetPlayerStatus(char[] sValue, int ranking_count)
{
	char sInfo[9][128];
	//char[][] sInfo = new char[ranking_count][128];//更改为动态大小的数组.
	ExplodeString(sValue, "\n", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.
	for (int i = 1; i < ranking_count; i++)
		if (StringToInt(sInfo[i]) > 0)
			return true;
	return false;
}

int ClientValue2DSortDesc(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	if (elem1[2] > elem2[2])
		return -1;
	else if (elem2[2] > elem1[2])
		return 1;
	return 0;
}
/*
//获取玩家状态.
int GetSurvivorsStatus()
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsPlayerState(i))
			return 1;//有倒地的和挂边的生还者置顶显示.
	return 2;//以击杀数量排序.
}
*/
void IsPlayersNumber()
{
	int iNumber[8];
	char sLine[128], sInfo[sizeof(iNumber)][32];
	
	if(g_iPlayersNumber & Number_1)
	{
		iNumber[0] = GetConnectionNumber();
		if(iNumber[0] > 0)
			FormatEx(sInfo[0], sizeof(sInfo[]), "连接:%d ", iNumber[0]);
	}
	if(g_iPlayersNumber & Number_2)
	{
		iNumber[1] = GetPlayersStateNumber(1, true);
		if(iNumber[1] > 0)
			FormatEx(sInfo[1], sizeof(sInfo[]), "闲置:%d ", iNumber[1]);
	}
	if(g_iPlayersNumber & Number_4)
	{
		iNumber[2] = GetPlayersStateNumber(1, false);
		if(iNumber[2] > 0)
			FormatEx(sInfo[2], sizeof(sInfo[]), "旁观:%d ", iNumber[2]);
	}
	if(g_iPlayersNumber & Number_8)
	{
		iNumber[3] = GetInfectedNumber("infected");
		if(iNumber[3] > 0)
			FormatEx(sInfo[3], sizeof(sInfo[]), "丧尸:%d ", iNumber[3]);
	}
	if(g_iPlayersNumber & Number_16)
	{
		iNumber[4] = GetInfectedNumber("witch");
		if(iNumber[4] > 0)
			FormatEx(sInfo[4], sizeof(sInfo[]), "女巫:%d ", iNumber[4]);
	}
	if(g_iPlayersNumber & Number_32)
	{
		iNumber[5] = GetPlayersMaxNumber(3, false);
		if(iNumber[5] > 0)
			FormatEx(sInfo[5], sizeof(sInfo[]), "特感:%d ", iNumber[5]);
	}
	if(g_iPlayersNumber & Number_64)
	{
		iNumber[6] = GetPlayersMaxNumber(2, false);
		if(iNumber[6] > 0)
			FormatEx(sInfo[6], sizeof(sInfo[]), "生还:%d ", iNumber[6]);
	}
	
	ImplodeStrings(sInfo, sizeof(sInfo), "", sLine, sizeof(sLine));//打包字符串.
	HUDSetLayout(HUD_SCORE_4, HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEXT, sLine);
	HUDPlace(HUD_SCORE_4,0.00,0.00,1.0,0.03);
}

//显示当前和总人数.
void IsShowServersNumber()
{
	static char g_sTitleName[][] = {"➣路程:", "➣坦克:", "➣女巫:"};

	int iDistance[3], iValue[sizeof(iDistance)], iNumber[2];
	char sData[256], sLine[2][128], sDistance[sizeof(iDistance)][64], sNumber[sizeof(iNumber)][64];
	if(g_iShowServerNumber & Number_1)
	{
		iNumber[0] = g_iPlayerNum;
		if(iNumber[0] > 0)
			FormatEx(sNumber[0], sizeof(sNumber[]), "➣人数:%d/%d\n", iNumber[0], GetMaxPlayers());
	}
	if(g_iShowServerNumber & Number_2)
	{
		iNumber[1] = g_iCurrentChapter;
		if(iNumber[1] > 0)
			FormatEx(sNumber[1], sizeof(sNumber[]), "➣地图:%d/%d\n", iNumber[1], g_iMaxChapters);
	}

	if(g_iShowServerNumber & Number_4)
		iDistance[0] = GetGameDistance();

	if(g_iShowServerNumber & Number_8)
		iDistance[1] = GetTankDistance();

	if(g_iShowServerNumber & Number_16)
		iDistance[2] = GetWitchDistance();

	int iTemp = GetMaxiMum(iDistance, sizeof(iDistance));//获取数组中的最大值.
	
	for (int i = 0; i < sizeof(iDistance); i++)
		if (iDistance[i] > 0)
			iValue[i] = GetCharacterSize(iTemp) - GetCharacterSize(iDistance[i]);
		
	for (int i = 0; i < sizeof(iDistance); i++)
		if (iDistance[i] > 0)
			FormatEx(sDistance[i], sizeof(sDistance[]), "%s%s%d％\n", g_sTitleName[i], GetAddSpacesMax(iValue[i], "0"), iDistance[i]);
		
	ImplodeStrings(sNumber, sizeof(sNumber), "", sLine[0], sizeof(sLine[]));//打包字符串.
	ImplodeStrings(sDistance, sizeof(sDistance), "", sLine[1], sizeof(sLine[]));//打包字符串.
	ImplodeStrings(sLine, sizeof(sLine), "", sData, sizeof(sData));//打包字符串.

	HUDSetLayout(HUD_SCORE_1, HUD_FLAG_BLINK|HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEXT, sData);
	HUDPlace(HUD_SCORE_1,0.76,0.795,1.0,0.22);
}

int GetMaxiMum(int[] iArray, int iNumber)
{
	int iMax;
	for (int i = 0; i < iNumber; i++)
		if (iArray[i] > 0)
			if (iArray[i] > iMax)
				iMax = iArray[i];
	
	return iMax;
}

//获取游戏路程.
int GetGameDistance()
{
	static int client;
	static float highestFlow;
	highestFlow = (client = L4D_GetHighestFlowSurvivor()) != -1 ? L4D2Direct_GetFlowDistance(client) : L4D2_GetFurthestSurvivorFlow();
	if (highestFlow)
		highestFlow = highestFlow / g_fMapMaxFlow * 100;
	return RoundToCeil(highestFlow);
}
//获取坦克路程.
int GetTankDistance()
{
	int flow, roundNumber;
	roundNumber = GetGameRulesNumber();

	if (L4D2Direct_GetVSTankToSpawnThisRound(roundNumber)) 
	{
		flow = RoundToCeil(L4D2Direct_GetVSTankFlowPercent(roundNumber) * 100.0);
		if (flow > 0) 
			flow -= RoundToFloor(g_fVsBossBuff / g_fMapMaxFlow * 100);
	}
	return flow < 0 ? 0 : flow;
}
//获取女巫路程.
int GetWitchDistance()
{
	int flow, roundNumber;
	roundNumber = GetGameRulesNumber();

	if (L4D2Direct_GetVSWitchToSpawnThisRound(roundNumber)) 
	{
		flow = RoundToCeil(L4D2Direct_GetVSWitchFlowPercent(roundNumber) * 100.0);
		if (flow > 0) 
			flow -= RoundToFloor(g_fVsBossBuff / g_fMapMaxFlow * 100);
	}
	return flow < 0 ? 0 : flow;
}
int GetGameRulesNumber()
{
	return GameRules_GetProp("m_bInSecondHalfOfRound");
}
int GetInfectedNumber(char[] g_sInfected)
{
	int inf = -1, count;
	while ((inf = FindEntityByClassname(inf, g_sInfected)) != INVALID_ENT_REFERENCE)
		count += 1;
	return count;
}

//显示仿CS击杀提示.
void IsDeathMessage()
{
	HUDSetLayout(HUD_FAR_LEFT, HUD_FLAG_ALIGN_RIGHT|HUD_FLAG_NOBG|HUD_FLAG_TEXT, g_sDeathInfo);
	HUDPlace(HUD_FAR_LEFT,0.00,g_iShowServerName <= -1?0.17:0.195,1.0,0.22);
}

//显示服务器时间.
void IsShowServerTime()
{
	char sDate[3][128], sInfo[256], sTime[256];
	if(g_iShowServerTime & Number_1)
		FormatTime(sDate[0], sizeof(sDate[]), "%Y-%m-%d");
	if(g_iShowServerTime & Number_2)
		FormatTime(sDate[1], sizeof(sDate[]), "%H:%M:%S");
	if(g_iShowServerTime & Number_4)
		FormatEx(sDate[2], sizeof(sDate[]), "星期%s", IsWeekName());
	ImplodeStrings(sDate, sizeof(sDate), " ", sInfo, sizeof(sInfo));//打包字符串.
	FormatEx(sTime, sizeof(sTime), "%s%s", sInfo, GetAddSpacesMax(3, " "));
	HUDSetLayout(HUD_MID_TOP, HUD_FLAG_ALIGN_RIGHT|HUD_FLAG_NOBG|HUD_FLAG_TEXT, sTime);
	HUDPlace(HUD_MID_TOP,0.00,0.00,1.0,0.03);
}

//显示击杀数量.
void IsCumulativeStatistics()
{
	int temp[2], count;
	char sQuantity[256], sInfo[256], sStatistics[2][128];
	for (int i = 0; i < sizeof(temp); i++)
		temp[i] = GetCharacterSize(g_iCumulativeTotal[i]) - GetCharacterSize(g_iChapterTotal[i]);
	if(g_iShowKillNumber & Number_1)
	{
		count += 1;
		FormatEx(sStatistics[0], sizeof(sStatistics[]), "累计:特感:%d 丧尸:%d", g_iCumulativeTotal[1], g_iCumulativeTotal[0]);
	}
		
	if(g_iShowKillNumber & Number_2)
	{
		count += 1;
		FormatEx(sStatistics[1], sizeof(sStatistics[]), "章节:特感:%s%d 丧尸:%s%d", GetAddSpacesMax(temp[1], "0"), g_iChapterTotal[1], GetAddSpacesMax(temp[0], "0"), g_iChapterTotal[0]);
	}
		
	ImplodeStrings(sStatistics, sizeof(sStatistics), count < 2 ? "" : "\n", sQuantity, sizeof(sQuantity));//打包字符串.
	if(count < 2)
		FormatEx(sInfo, sizeof(sInfo), "%s%s", sQuantity, GetAddSpacesMax(3, " "));
	HUDSetLayout(HUD_MID_BOX, HUD_FLAG_ALIGN_RIGHT|HUD_FLAG_NOBG|HUD_FLAG_TEXT, count < 2 ? sInfo : sQuantity);
	HUDPlace(HUD_MID_BOX,0.00,g_iShowServerName <= -1?0.035:0.06,1.0,count < 2 ? 0.03 : 0.07);
}

//显示运行时间.
void IsShowRunningTime()
{
	int count;
	char sQuantity[256], sInfo[256], sChapter[2][128];
	if(g_iShowRunningTime & Number_1)
	{
		count += 1;
		FormatEx(sChapter[0], sizeof(sChapter[]), "累计运行:%s", StandardizeTime(g_fMapRunTime[0]));
	}
	if(g_iShowRunningTime & Number_2)
	{
		count += 1;
		FormatEx(sChapter[1], sizeof(sChapter[]), "本次运行:%s", StandardizeTime(g_fMapRunTime[1]));
	}
	
	ImplodeStrings(sChapter, sizeof(sChapter), count < 2 ? "" : "\n", sQuantity, sizeof(sQuantity));//打包字符串.
	if(count < 2)
		FormatEx(sInfo, sizeof(sInfo), "%s%s", sQuantity, GetAddSpacesMax(3, " "));
	HUDSetLayout(HUD_SCORE_TITLE, HUD_FLAG_ALIGN_RIGHT|HUD_FLAG_NOBG|HUD_FLAG_TEXT, count < 2 ? sInfo : sQuantity);
	HUDPlace(HUD_SCORE_TITLE,0.00,g_iShowServerName <= -1?0.110:0.135,1.0,count < 2 ? 0.03 : 0.07);
}

//填入对应数量的内容.
char[] GetAddSpacesMax(int Value, char[] sContent)
{
	char g_sBlank[64];
	
	if(Value > 0)
	{
		char g_sFill[32][64];
		if(Value > sizeof(g_sFill))
			Value = sizeof(g_sFill);
		for (int i = 0; i < Value; i++)
			strcopy(g_sFill[i], sizeof(g_sFill[]), sContent);
		ImplodeStrings(g_sFill, sizeof(g_sFill), "", g_sBlank, sizeof(g_sBlank));//打包字符串.
	}
	return g_sBlank;
}

//返回对应的内容.
char[] GetTrueName(int client)
{
	char g_sName[14];//因为字符限制,显示8行只能限制到14个字符.
	int Bot = IsClientIdle(client);
	
	if(Bot != 0)
		FormatEx(g_sName, sizeof(g_sName), "闲置:%N", Bot);
	else
		GetClientName(client, g_sName, sizeof(g_sName));
	return g_sName;
}

//https://forums.alliedmods.net/showthread.php?t=288686
char[] StandardizeTime(float g_fRunTime)
{
	int iTime[4];
	char sName[128], sTime[sizeof(iTime)][32];
	float fTime[3] = {86400.0, 3600.0, 60.0};
	float remainder = GetEngineTime() - g_fRunTime;
	
	iTime[0] = RoundToFloor(remainder / fTime[0]);
	remainder = remainder - float(iTime[0]) * fTime[0];
	iTime[1] = RoundToFloor(remainder / fTime[1]);
	remainder = remainder - float(iTime[1]) * fTime[1];
	iTime[2] = RoundToFloor(remainder / fTime[2]);
	remainder = remainder - float(iTime[2]) * fTime[2];
	iTime[3] = RoundToFloor(remainder);

	for (int i = 0; i < sizeof(iTime); i++)
		if(iTime[i] > 0)
			FormatEx(sTime[i], sizeof(sTime[]), "%d%s", iTime[i], g_sDate[i]);
	ImplodeStrings(sTime, sizeof(sTime), "", sName, sizeof(sName));//打包字符串.
	return sName;
}

//返回当前星期几.
char[] IsWeekName()
{
	char g_sWeek[8];
	FormatTime(g_sWeek, sizeof(g_sWeek), "%u");
	return g_sWeekName[StringToInt(g_sWeek) - 1];
}

//返回玩家状态.
char[] GetSurvivorStatus(int client)
{
	char g_sStatus[8];
	if(GetEntProp(client, Prop_Send, "m_currentReviveCount") >= g_iMaxReviveCount)//判断是否黑白.
	{
		if (!IsPlayerAlive(client))
			strcopy(g_sStatus, sizeof(g_sStatus), "死亡");
		else
			strcopy(g_sStatus, sizeof(g_sStatus), GetSurvivorHP(client) < g_iSurvivorHealth ? "濒死" : g_iMaxReviveCount <= 0 ? "正常" : "黑白");
	}
	else
		if (!IsPlayerAlive(client))
			strcopy(g_sStatus, sizeof(g_sStatus), "死亡");
		else if (IsPlayerFallen(client))
			strcopy(g_sStatus, sizeof(g_sStatus), "倒地");
		else if (IsPlayerFalling(client))
			strcopy(g_sStatus, sizeof(g_sStatus), "挂边");
		else
			strcopy(g_sStatus, sizeof(g_sStatus), GetSurvivorHP(client) < g_iSurvivorHealth ? g_iMaxReviveCount <= 0 ? "濒死" : "瘸腿" : "正常");
	return g_sStatus;
}

//返回服务器名字.
char[] GetHostName()
{
	char g_sHostName[256];
	g_hHostName.GetString(g_sHostName, sizeof(g_sHostName));
	return g_sHostName;
}

//返回字符串实际大小.
int GetCharacterSize(int g_iSize)
{
	char sChapter[64];
	IntToString(g_iSize, sChapter, sizeof(sChapter));//格式化int类型为char类型.
	return strlen(sChapter);
}

//幸存者总血量.
int GetSurvivorHP(int client)
{
	int HP = GetClientHealth(client) + GetPlayerTempHealth(client);
	return IsPlayerAlive(client) ? HP > 999 ? 999 : HP : 0;//如果幸存者血量大于999就显示为999
}

//幸存者虚血量.
int GetPlayerTempHealth(int client)
{
	static Handle painPillsDecayCvar;
	painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
	if (painPillsDecayCvar == null)
		return -1;

	int tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(painPillsDecayCvar))) - 1;
	return tempHealth < 0 ? 0 : tempHealth;
}

//获取正在连接的玩家数量.
int GetConnectionNumber()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i) && !IsClientInGame(i) && !IsFakeClient(i))
			count += 1;
	
	return count;
}

//获取闲置或旁观者数量.
int GetPlayersStateNumber(int iTeam, bool bClientTeam)
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == iTeam)
		{
			if (bClientTeam)
			{
				if (iGetBotOfIdlePlayer(i))
					count += 1;
			}
			else
			{
				if (!iGetBotOfIdlePlayer(i))
					count += 1;
			}
		}
	}
	return count;
}

//获取特感或幸存者数量.
int GetPlayersMaxNumber(int iTeam, bool bSurvive)
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == iTeam)
			if (bSurvive)
			{
				if(IsPlayerAlive(i))
					count += 1;
			}
			else
				count += 1;
	
	return count;
}

//返回最大人数.
int GetMaxPlayers()
{
	static Handle hMaxPlayers;
	hMaxPlayers = FindConVar("sv_maxplayers");
	if (hMaxPlayers == null)
		return GetDefaultNumber();
		
	int iMaxPlayers = GetConVarInt(hMaxPlayers);
	if(iMaxPlayers <= -1)
		return GetDefaultNumber();
	
	return iMaxPlayers;
}

int GetDefaultNumber()
{
	for (int i = 0; i < sizeof(g_sModeVersus); i++)
		if(strcmp(GetGameMode(), g_sModeVersus[i]) == 0)
			return 8;
	for (int i = 0; i < sizeof(g_sModeSingle); i++)
		if(strcmp(GetGameMode(), g_sModeSingle[i]) == 0)
			return 1;
	return 4;
}

char[] GetGameMode()
{
	char g_sMode[32];
	GetConVarString(FindConVar("mp_gamemode"), g_sMode, sizeof(g_sMode));
	return g_sMode;
}

//返回闲置玩家对应的电脑.
int iGetBotOfIdlePlayer(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && IsClientIdle(i) == client)
			return i;
	}
	return 0;
}

//返回电脑幸存者对应的玩家.
int IsClientIdle(int client)
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

//正常状态.
stock bool IsPlayerState(int client)
{
	return !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

//挂边状态.
bool IsPlayerFalling(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

//倒地状态.
bool IsPlayerFallen(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}

//判断玩家有效.
bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}