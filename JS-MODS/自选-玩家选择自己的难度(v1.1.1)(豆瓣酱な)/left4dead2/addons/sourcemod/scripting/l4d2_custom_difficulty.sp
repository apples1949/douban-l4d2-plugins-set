/*
 *
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v1.0.1
 *
 *	1:修复依赖插件未安装时使用指令打开菜单会出现报错的问题.
 *	2:新增聊天窗中文命令更改个人难度(默认,简单,普通,高级,专家).
 *
 *	v1.1.1
 *
 *	1:优化一些细节方面的问题.
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#undef REQUIRE_PLUGIN	//标记为可选开始.
#include <l4d2_simulation>
#define REQUIRE_PLUGIN	//标记为可选结束.

#define PLUGIN_VERSION	"1.1.1"

bool g_bLibraries;
char g_sDifficultyName[][] = {"简单", "普通", "高级", "专家"};
char g_sDifficultyCode[][] = {"Easy", "Normal", "Hard", "Impossible"};

public Plugin myinfo =  
{
	name = "l4d2_custom_difficulty",
	author = "豆瓣酱な",  
	description = "更改个人的游戏难度(其它插件模拟的特感,丧尸和女巫对生还者的伤害).",
	version = PLUGIN_VERSION,
	url = "N/A"
};
//插件开始.
public void OnPluginStart()
{
	RegConsoleCmd("sm_dd", Command_CustomDifficulty, "更改个人难度菜单.");
}
//聊天窗中文指令.
public void OnClientSayCommand_Post(int client, const char[] commnad, const char[] args)
{
	if(IsValidClient(client) && !IsFakeClient(client))
	{
		if (strcmp(args, "默认") == 0)
			IsChangeDifficule(client, -1);
		else if (strcmp(args, "简单") == 0)
			IsChangeDifficule(client, 0);
		else if (strcmp(args, "普通") == 0)
			IsChangeDifficule(client, 1);
		else if (strcmp(args, "高级") == 0)
			IsChangeDifficule(client, 2);
		else if (strcmp(args, "专家") == 0)
			IsChangeDifficule(client, 3);
	}
}
//监听聊天窗内容设置难度.
void IsChangeDifficule(int client, int value)
{
	char sName[32], error[128];
	if(SetCustomizeDifficulty(client, value, sName, error))
		PrintToChat(client, "\x04[提示]\x05已设置你的难度为\x03%s\x05难度.", sName);
	else
		PrintToChat(client, "\x04[提示]\x05%s.", error);
}
//所有插件加载完成后执行一次(延迟加载插件也会执行一次).
public void OnAllPluginsLoaded()   
{
	g_bLibraries = LibraryExists("l4d2_simulation");
}
//库被加载时.
public void OnLibraryAdded(const char[] name) 
{
	if (strcmp(name, "l4d2_simulation") == 0)
		g_bLibraries = true;
}
//库被卸载时.
public void OnLibraryRemoved(const char[] name) 
{
	if (strcmp(name, "l4d2_simulation") == 0)
		g_bLibraries = false;
}
//更改个人难度菜单.
public Action Command_CustomDifficulty(int client, int args)
{
	if(g_bLibraries == true)
		IsCustomDifficulty(client, 8);//MENU_TIME_FOREVER =永久显示.
	else
		PrintToChat(client, "\x04[提示]\x05依赖插件l4d2_simulation.smx未安装.");
	return Plugin_Handled;
}
void IsCustomDifficulty(int client, int time)
{
	char sLine[128];
	Menu menu = new Menu(MenuCustomDifficultyHandler);
	Format(sLine, sizeof(sLine), "选择难度:(%s)\n ", GetCustomDifficultyName());
	menu.SetTitle("%s", sLine);

	Format(sLine, sizeof(sLine), "[%s]%s", GetCustomizeDifficulty(client) == -1 ? "●" : "○", "默认");
	menu.AddItem("-1", sLine);
	Format(sLine, sizeof(sLine), "[%s]%s", GetCustomizeDifficulty(client) == 0 ? "●" : "○", "简单");
	menu.AddItem("0", sLine);
	Format(sLine, sizeof(sLine), "[%s]%s", GetCustomizeDifficulty(client) == 1 ? "●" : "○", "普通");
	menu.AddItem("1", sLine);
	Format(sLine, sizeof(sLine), "[%s]%s", GetCustomizeDifficulty(client) == 2 ? "●" : "○", "高级");
	menu.AddItem("2", sLine);
	Format(sLine, sizeof(sLine), "[%s]%s", GetCustomizeDifficulty(client) == 3 ? "●" : "○", "专家");
	menu.AddItem("3", sLine);
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = false;//菜单首页显示数字8返回上一页选项.
	menu.Display(client, time);
}
//菜单回调.
int MenuCustomDifficultyHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[32], sName[32], error[128];
			menu.GetItem(itemNum, sItem, sizeof(sItem));
			if(SetCustomizeDifficulty(client, StringToInt(sItem), sName, error))
				PrintToChat(client, "\x04[提示]\x05已设置你的难度为\x03%s\x05难度.", sName);
			else
				PrintToChat(client, "\x04[提示]\x05%s.", error);
			IsCustomDifficulty(client, 8);//重新打开菜单并设置这个菜单的存在时间/秒.
		}
	}
	return 0;
}
char[] GetCustomDifficultyName()
{
	char sName[128] = "默认";
	char sDifficulty[32];
	GetConVarString(FindConVar("z_Difficulty"), sDifficulty, sizeof(sDifficulty));
	for (int i = 0; i < sizeof(g_sDifficultyCode); i++)
		if(strcmp(sDifficulty, g_sDifficultyCode[i]) == 0)
			strcopy(sName, sizeof(sName), g_sDifficultyName[i]);

	return sName;
}
//玩家连接游戏并完全进入游戏时.
public void OnClientPostAdminCheck(int client)
{
	if (!IsFakeClient(client))
		CreateTimer(6.5, IsCustomDifficultyTimer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}
//计时器回调.
public Action IsCustomDifficultyTimer(Handle timer, any client)
{
	if ((client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client))
	{
		switch (GetClientTeam(client))
		{
			case 1:
			{
				int iBot = IsGetBotOfIdlePlayer(client);
				if (iBot != 0)
				{
					PrintToChat(client, "\x04[提示]\x05输入指令\x03!dd\x05选择你的难度.");//聊天窗提示.
				}
			}
			case 2:
			{
				PrintToChat(client, "\x04[提示]\x05输入指令\x03!dd\x05选择你的难度.");//聊天窗提示.
			}
		}
	}
	return Plugin_Stop;
}
//返回闲置玩家对应的电脑.
stock int IsGetBotOfIdlePlayer(int client)
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
//玩家有效.
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}