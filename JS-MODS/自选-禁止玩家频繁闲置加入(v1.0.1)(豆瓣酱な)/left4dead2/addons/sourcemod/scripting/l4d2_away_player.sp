/*
 *
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v1.0.1
 *
 *	1:删除闲置和加入的冷却选项.
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>
//定义插件版本.
#define PLUGIN_VERSION	"1.0.1"
#define MAX_PLAYERS		32

int    g_iSbAllBotGame;
ConVar g_hSbAllBotGame;

float  g_fKeyboardTimer, g_fSpecnextTimer;
ConVar g_hKeyboardTimer, g_hSpecnextTimer;

float g_fTakeTime[MAX_PLAYERS+1];
float g_fAwayTime[MAX_PLAYERS+1];
Handle g_hTakeTimer[MAX_PLAYERS+1];
Handle g_hAwayTimer[MAX_PLAYERS+1];

//定义插件信息.
public Plugin myinfo =  
{
	name = "l4d2_away_player",
	author = "豆瓣酱な",
	description = "防止生还者玩家滥用闲置",
	version = PLUGIN_VERSION,
	url = "N/A"
};
//插件开始.
public void OnPluginStart()
{
	g_hSbAllBotGame = FindConVar("sb_all_bot_game");
	g_hSbAllBotGame.AddChangeHook(ConVarBotGameChanged);
	g_hKeyboardTimer = CreateConVar("l4d2_away_timer_keyboard", "1.5", "设置多少秒后自动加入观察者. 0.0=无延迟.", FCVAR_NOTIFY);
	g_hSpecnextTimer = CreateConVar("l4d2_away_timer_specnext", "2.0", "设置多少秒后自动加入幸存者. 0.0=无延迟.", FCVAR_NOTIFY);
	g_hKeyboardTimer.AddChangeHook(ConVarValueChanged);
	g_hSpecnextTimer.AddChangeHook(ConVarValueChanged);
	
	AutoExecConfig(true, "l4d2_away_player");
	
	//监听鼠标左键.
	AddCommandListener(AddSpecNext, "spec_next");
	//监听休息命令.
	AddCommandListener(AddAwayFromKeyboard, "go_away_from_keyboard");
}
//参数更改回调.
void ConVarBotGameChanged(ConVar convar, const char[] oldValue, const char[] newValue) 
{
	g_iSbAllBotGame = g_hSbAllBotGame.IntValue;
	if(StringToInt(newValue) == 0 && GetSurvivorsNumber() <= 0)//没有真实生还者.
	{
		int client = GetPlayerIndex();//随机获取一名玩家.
		if(IsValidClient(client) && !IsFakeClient(client) && GetClientTeam(client) == 1 && iGetBotOfIdlePlayer(client))
			L4D_TakeOverBot(client);
	}
}
//参数更改回调.
void ConVarValueChanged(ConVar convar, const char[] oldValue, const char[] newValue) 
{
	GetConVarValue();
}
//插件配置加载完成时.
public void OnConfigsExecuted()
{
	GetConVarValue();
}
//重新赋值.
void GetConVarValue()
{
	g_iSbAllBotGame = g_hSbAllBotGame.IntValue;
	g_fKeyboardTimer = g_hKeyboardTimer.FloatValue;
	g_fSpecnextTimer = g_hSpecnextTimer.FloatValue;
}
//生还者使用闲置命令.
Action AddAwayFromKeyboard(int client, const char[] command, int args)
{
	if(IsValidClient(client))
	{
		switch (GetClientTeam(client))
		{
			case 1:
			{
				PrintToChat(client,"\x04[提示]\x05你当前已是观察者.");
			}
			case 2:
			{
				if(!IsPlayerAlive(client))
					PrintToChat(client,"\x04[提示]\x05死亡状态不能使用休息.");
				else
				{
					if (g_iSbAllBotGame == 0 && GetSurvivorsNumber() <= 1)
					{
						PrintToChat(client, "\x04[提示]\x05至少两名生还者玩家才能使用休息.");
						return Plugin_Handled;
					}

					if (IsInfectionControl(client))
					{
						PrintCenterText(client, "被特感控制时禁止使用休息.");
						return Plugin_Handled;
					}
					else if (IsInReload(client))
					{
						PrintCenterText(client, "更换弹药时禁止使用休息.");
						return Plugin_Handled;
					}
					else if (IsGettingUp(client))
					{
						PrintCenterText(client, "起身过程中禁止使用休息.");
						return Plugin_Handled;
					}
					else if (L4D_IsPlayerStaggering(client))
					{
						PrintCenterText(client, "硬直状态时禁止使用休息.");
						return Plugin_Handled;
					}
					else 
					{
						if(g_fKeyboardTimer <= 0.0)
						{
							L4D_GoAwayFromKeyboard(client);
							return Plugin_Continue;
						}

						float fFromTime = GetEngineTime() - g_fAwayTime[client];
						if (fFromTime < g_fKeyboardTimer)
						{
							PrintCenterText(client, "你将在 %.1f 秒后加入观察者.", g_fKeyboardTimer - fFromTime);
							return Plugin_Handled;
						}
						
						if(g_hAwayTimer[client] == null)
						{
							g_fAwayTime[client] = GetEngineTime();
							PrintCenterText(client, "你将在 %.1f 秒后加入观察者.", g_fKeyboardTimer);
							g_hAwayTimer[client] = CreateTimer(g_fKeyboardTimer, GoAwayTimer, GetClientUserId(client));
						}
						return Plugin_Handled;//阻止游戏自带的闲置命令.
					}
				}
			}
			case 3:
			{
				PrintToChat(client,"\x04[提示]\x05只限幸存者使用休息.");
			}
		}
	}
	return Plugin_Continue;
}
//计时器回调.
public Action GoAwayTimer(Handle timer, any client)
{
	if ((client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2)
		L4D_GoAwayFromKeyboard(client);
	g_hAwayTimer[client] = null;
	return Plugin_Stop;
}
//闲置状态加入生还者.
Action AddSpecNext(int client, char[] command, int argc)
{
	if(IsValidClient(client) && !IsFakeClient(client))
	{
		if(GetClientTeam(client) == 1 && iGetBotOfIdlePlayer(client))
		{
			if(g_fSpecnextTimer <= 0.0)
				return Plugin_Continue;
			
			float fFromTime = GetEngineTime() - g_fTakeTime[client];
			if (fFromTime < g_fSpecnextTimer)
			{
				PrintCenterText(client, "你将在 %.1f 秒后加入生还者.", g_fSpecnextTimer - fFromTime);
				return Plugin_Handled;
			}
			
			if(g_hTakeTimer[client] == null)
			{
				g_fTakeTime[client] = GetEngineTime();
				PrintCenterText(client, "你将在 %.1f 秒后加入生还者.", g_fSpecnextTimer);
				g_hTakeTimer[client] = CreateTimer(g_fSpecnextTimer, GoTakeTimer, GetClientUserId(client));
			}
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}
//计时器回调.
public Action GoTakeTimer(Handle timer, any client)
{
	if ((client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 1 && iGetBotOfIdlePlayer(client))
		L4D_TakeOverBot(client);
	g_hTakeTimer[client] = null;
	return Plugin_Stop;
}
//玩家退出.
public void OnClientDisconnect(int client)
{   
	if(!IsFakeClient(client))
	{
		delete g_hTakeTimer[client];
		delete g_hAwayTimer[client];
	}	
}
//返回闲置玩家对应的电脑.
stock int iGetBotOfIdlePlayer(int client)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && IsClientIdle(i) == client)
			return i;
	
	return 0;
}
//返回电脑幸存者对应的玩家.
stock int IsClientIdle(int client)
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}
//获取真实生还者数量.
stock int GetPlayerIndex()
{
	int index;
	int[] player = new int[MaxClients];//更改为动态大小的数组.
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 1 && iGetBotOfIdlePlayer(i))
			player[index++] = i;
	
	return index > 0 ? GetRandomInt(0, index-1) : 0;
}
//获取真实生还者数量.
stock int GetSurvivorsNumber()
{
	int count1 = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2)
			count1++;
	
	return count1;
}
//生还者更换弹药.
stock bool IsInReload(int client)
{
	int iActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	
	return IsValidEdict(iActiveWeapon) && GetEntProp(iActiveWeapon, Prop_Data, "m_bInReload") == 1;
}
//生还者被特感控制.
bool IsInfectionControl(int client)
{
	if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
		return true;
	return false;
}
//生还者起身(https://github.com/LuxLuma/L4D2_Adrenaline_Recovery).
stock bool IsGettingUp(int client) 
{
	static char sModel[31];
	GetClientModel(client, sModel, sizeof sModel);
	switch (sModel[29]) 
	{
		case 'b': {	//nick
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 680, 667, 671, 672, 630, 620, 627:
					return true;
			}
		}
		case 'd': {	//rochelle
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 687, 679, 678, 674, 638, 635, 629:
					return true;
			}
		}
		case 'c': {	//coach
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 669, 661, 660, 656, 630, 627, 621:
					return true;
			}
		}
		case 'h': {	//ellis
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 684, 676, 675, 671, 625, 635, 632:
					return true;
			}
		}
		case 'v': {	//bill
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 772, 764, 763, 759, 538, 535, 528:
					return true;
			}
		}
		case 'n': {	//zoey
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 824, 823, 819, 809, 547, 544, 537:
					return true;
			}
		}
		case 'e': {	//francis
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 775, 767, 766, 762, 541, 539, 531:
					return true;
			}
		}
		case 'a': {	//louis
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 772, 764, 763, 759, 538, 535, 528:
					return true;
			}
		}
		case 'w': {	//adawong
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 687, 679, 678, 674, 638, 635, 629:
					return true;
			}
		}
	}
	return false;
}
//玩家有效性.
stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}
