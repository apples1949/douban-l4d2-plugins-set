/*
 *	
 *
 *	v1.2.5
 *
 *	1:修复踢出玩家前玩家离开游戏导致随机踢出一个倒霉蛋的问题.
 *
 *	v1.3.5
 *
 *	1:更改设置投票同意和反对为官方方法.
 *
 *	v1.4.5
 *
 *	1:更改设置投票同意和反对为官方方法.
 *
 */
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#undef REQUIRE_PLUGIN	//标记为可选开始.
#include <l4d2_banned>	//数据库封禁玩家.
#define REQUIRE_PLUGIN	//标记为可选结束.
#include <l4d2_nativevote>			// https://github.com/fdxx/l4d2_nativevote

#define PLUGIN_VERSION "1.4.5"

bool g_bLibraries;
Handle g_hChangelevel;

char g_sGameDifficulty[][][] = 
{
	{"简单", "Easy"}, 
	{"普通", "Normal"}, 
	{"高级", "Hard"}, 
	{"专家", "Impossible"}
};

int    g_iBanTime, g_iPercent, g_iMenuTime, g_iDifficulty;
ConVar g_hBanTime, g_hPercent, g_hMenuTime, g_hDifficulty;

public Plugin myinfo =  
{
	name = "l4d2_menu_vote", 
	author = "豆瓣酱な", 
	description = "投票更改难度,踢出玩家,重启当前章节.", 
	version = PLUGIN_VERSION,
	url = "N/A"
};

//所有插件加载完成后执行一次(延迟加载插件也会执行一次).
public void OnAllPluginsLoaded()   
{
	g_bLibraries = LibraryExists("l4d2_banned");
}
//库被加载时.
public void OnLibraryAdded(const char[] name) 
{
	if (strcmp(name, "l4d2_banned") == 0)
		g_bLibraries = true;
}
//库被卸载时.
public void OnLibraryRemoved(const char[] name) 
{
	if (strcmp(name, "l4d2_banned") == 0)
		g_bLibraries = false;
}

public void OnPluginStart()   
{
	RegConsoleCmd("sm_vt", Command_VoteMenu);

	g_hBanTime = CreateConVar("l4d2_vote_BanTime", "5", "设置被投票踢出玩家的封禁时间/分钟. -1=仅踢出, 0=永久封禁.", FCVAR_NOTIFY);
	g_hPercent = CreateConVar("l4d2_vote_Percent", "60", "设置通过投票所需的百分比(1/100).", FCVAR_NOTIFY);
	g_hMenuTime = CreateConVar("l4d2_vote_menuTime", "25", "设置同意或反对菜单的显示时间/秒.", FCVAR_NOTIFY);
	g_hDifficulty = CreateConVar("l4d2_vote_difficulty", "15", "启用投票更改难度(把需要启用的数字加起来). 0=禁用, 1=简单, 2=普通, 4=高级, 8=专家, 15=全部.", FCVAR_NOTIFY);
	g_hBanTime.AddChangeHook(CvarChanged);
	g_hPercent.AddChangeHook(CvarChanged);
	g_hMenuTime.AddChangeHook(CvarChanged);
	g_hDifficulty.AddChangeHook(CvarChanged);

	AutoExecConfig(true, "l4d2_menu_vote");
}

public void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iBanTime = g_hBanTime.IntValue;
	g_iPercent = g_hPercent.IntValue;
	g_iMenuTime = g_hMenuTime.IntValue;
	g_iDifficulty = g_hDifficulty.IntValue;

	if (g_iPercent < 1)
		g_iPercent = 1;
	if (g_iPercent > 100)
		g_iPercent = 100;
	if (g_iMenuTime < 1)
		g_iMenuTime = 1;
}

//开局提示.
public void OnClientPutInServer(int client)
{
	if(!IsFakeClient(client))
		CreateTimer(7.5, g_hTimerAnnounce, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action g_hTimerAnnounce(Handle timer, any client)
{
	if ((client = GetClientOfUserId(client)) && IsClientInGame(client))
		PrintToChat(client, "\x04[提示]\x05聊天窗输入指令\x03!vt\x05打开投票菜单.");//聊天窗提示.
	return Plugin_Continue;
}
//地图开始.
public void OnMapStart()
{
	GetCvars();
	delete g_hChangelevel;
}
//地图结束.
public void OnMapEnd()
{
	delete g_hChangelevel;
}

public Action Command_VoteMenu(int client, int args)
{
	IsChooseFunction(client);
	return Plugin_Handled;
}

void IsChooseFunction(int client)
{
	char line[32];
	Menu menu = new Menu(Menu_HandlerFunction);
	FormatEx(line, sizeof(line), "投票菜单:");
	SetMenuTitle(menu, "%s", line);
	if (g_iDifficulty > 0)
		menu.AddItem("0", "更改难度");
	menu.AddItem("1", "重启章节");
	menu.AddItem("2", "踢出玩家");
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	//menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_HandlerFunction(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[32];
			if(menu.GetItem(itemNum, sItem, sizeof(sItem)))
			{
				switch(StringToInt(sItem))
				{
					case 0:
						MenuVoteChangeDifficulty(client, sItem);
					case 1:
						MenuVoteReopenTheChapter(client, sItem);
					case 2:
						MenuVoteKickThePlayer(client, sItem);
				}
			}
		}
	}
	return 0;
}

void MenuVoteChangeDifficulty(int client, char[] g_sItem)
{
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		IsChooseFunction(client);
		ReplyToCommand(client, "\x04[提示]\x05当前正在进行投票.");
		return;
	}
	if (TestVoteDelay(client))
	{
		IsChooseFunction(client);
		return;
	}
	if (g_iDifficulty <= 0)
	{
		IsChooseFunction(client);
		ReplyToCommand(client, "\x04[提示]\x05难度投票功能未开启.");
		return;
	}
	char line[32], sInfo[32], sData[3][32];
	Menu menu = new Menu(Menu_HandlerDifficulty);
	FormatEx(line, sizeof(line), "选择难度:");
	SetMenuTitle(menu, "%s", line);
	for (int i = 0; i < sizeof(g_sGameDifficulty); i++)
	{
		if (strcmp(GetDifficulty(), g_sGameDifficulty[i][1]) == 0)//不显示当前难度.
			continue;
		
		if(g_iDifficulty & (1 << i))
		{
			strcopy(sData[0], sizeof(sData[]), g_sItem);
			strcopy(sData[1], sizeof(sData[]), g_sGameDifficulty[i][1]);
			strcopy(sData[2], sizeof(sData[]), g_sGameDifficulty[i][0]);
			ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.
			menu.AddItem(sInfo, g_sGameDifficulty[i][0]);
		}
	}
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_HandlerDifficulty(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[32], sName[32], sInfo[3][32];
			menu.GetItem(itemNum, sItem, sizeof(sItem), _, sName, sizeof(sName));
			ExplodeString(sItem, "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.
			
			if (strcmp(GetDifficulty(), sInfo[2]) == 0)
				PrintToChat(client, "\x04[提示]\x05选择的难度与当前难度相同.");
			else
			{
				IsVoteChangeDifficulty(client, sItem, sName);
				PrintToChatAll("\x04[提示]\x03%N\x05发起投票更换难度为\x04:\x03%s", client, sName);
			}
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				IsChooseFunction(client);
		}
	}
	return 0;
}

void IsVoteChangeDifficulty(int client, char[] sItem, char[] sName)
{
	L4D2NativeVote vote = L4D2NativeVote(Menu_HandlerGetVotes);
	vote.Initiator = client;
	vote.SetInfo(sItem);

	int playerCount = 0;
	int[] clients = new int[MaxClients];
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		vote.SetTitle("更改难度为:%s?", sName);

		clients[playerCount++] = i;
	}
	vote.DisplayVote(clients, playerCount, g_iMenuTime);
}

void MenuVoteReopenTheChapter(int client, char[] sItem)
{
	if (g_hChangelevel != null)
	{
		ReplyToCommand(client, "\x04[提示]\x05当前也存在重启章节的计时器.");
		return;
	}
	if (TestVoteDelay(client))
	{
		IsChooseFunction(client);
		return;
	}
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		IsChooseFunction(client);
		ReplyToCommand(client, "\x04[提示]\x05当前正在进行投票.");
		return;
	}
	char sInfo[32], sData[3][32];
	strcopy(sData[0], sizeof(sData[]), sItem);
	strcopy(sData[1], sizeof(sData[]), "内容");//这个里的内容用不着.
	strcopy(sData[2], sizeof(sData[]), "内容");//这个里的内容用不着.
	ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.

	PrintToChatAll("\x04[提示]\x03%N\x05发起投票重启当前章节.", client);

	L4D2NativeVote vote = L4D2NativeVote(Menu_HandlerGetVotes);
	vote.Initiator = client;
	vote.SetInfo(sInfo);

	int playerCount = 0;
	int[] clients = new int[MaxClients];
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		vote.SetTitle("重启当前章节?");

		clients[playerCount++] = i;
	}
	vote.DisplayVote(clients, playerCount, g_iMenuTime);
}

void MenuVoteKickThePlayer(int client, char[] sItem)
{
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		IsChooseFunction(client);
		ReplyToCommand(client, "\x04[提示]\x05当前正在进行投票.");
		return;
	}
	if (TestVoteDelay(client))
	{
		IsChooseFunction(client);
		return;
	}
	if (!GetplayerTarget(client))
	{
		IsChooseFunction(client);
		PrintToChat(client, "\x04[提示]\x05当前有效玩家不足.");
		return;
	}
	char line[32], sInfo[32], auth[32], sData[3][32];
	Menu menu = new Menu(Menu_HandlerKickPlayer);
	FormatEx(line, sizeof(line), "踢出玩家?");
	menu.SetTitle("%s", line);
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && client != i)
		{ 
			if (!CanUserTarget(client, i) && CanUserTarget(i, client))
				continue;

			if(!GetClientAuthId(i, AuthId_Steam2, auth, sizeof(auth)))
				continue;

			strcopy (sData[0], sizeof(sData[]), sItem);
			FormatEx(sData[1], sizeof(sData[]), "%N", i);
			FormatEx(sData[2], sizeof(sData[]), "%s", auth);
			ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.
			menu.AddItem(sInfo, sData[1]);
		}		
	}
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_HandlerKickPlayer(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[32], sName[32];
			menu.GetItem(itemNum, sItem, sizeof(sItem), _, sName, sizeof(sName));
			IsVoteKickThePlayer(client, sItem, sName);
			PrintToChatAll("\x04[提示]\x03%N\x05发起投票踢出玩家\x04:\x03%s", client, sName);
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				IsChooseFunction(client);
		}
	}
	return 0;
}

void IsVoteKickThePlayer(int client, char[] sItem, char[] sName)
{
	L4D2NativeVote vote = L4D2NativeVote(Menu_HandlerGetVotes);
	vote.Initiator = client;
	vote.SetInfo(sItem);

	int playerCount = 0;
	int[] clients = new int[MaxClients];
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		vote.SetTitle("踢出玩家:%s?", sName);

		clients[playerCount++] = i;
	}
	vote.DisplayVote(clients, playerCount, g_iMenuTime);
}

void Menu_HandlerGetVotes(L4D2NativeVote vote, VoteAction action, int param1, int param2)
{
	switch (action)
	{
		case VoteAction_PlayerVoted:
		{
			switch(param2)
			{
				case 1: 
					PrintToChatAll("\x04[提示]\x03%N\x05已投票.", param1);
				case 2: 
					PrintToChatAll("\x04[提示]\x03%N\x05已投票.", param1);
			}
		}
		case VoteAction_End:
		{
			char sItem[128], sInfo[3][32];
			vote.GetInfo(sItem, sizeof sItem);
			ExplodeString(sItem, "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.

			switch(param1)
			{
				case VOTEEND_FULLVOTED: 
					PrintToChatAll("\x04[提示]\x05所有玩家已投票.");
				case VOTEEND_TIMEEND: 
					PrintToChatAll("\x04[提示]\x05本次投票结束.");
			}

			int iPercent = RoundToNearest(float(vote.YesCount) / float(vote.YesCount + vote.NoCount) * 100.0);
			if (FloatCompare(float(iPercent), float(g_iPercent)) < 0)
			{
				vote.SetFail();
				PrintToChatAll("\x04[提示]\x05投票失败\x04.\x05至少需要\x03%d%%\x05支持\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", g_iPercent, iPercent, vote.YesCount + vote.NoCount);
			}
			else
			{
				switch(StringToInt(sInfo[0]))
				{
					case 0:
					{
						vote.SetPass("投票通过...");
						ServerCommand("z_difficulty %s", sInfo[1]);
						PrintToChatAll("\x04[提示]\x05投票通过\x04.\x05难度已更换为\x04:\x03%s\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", sInfo[2], iPercent, vote.YesCount + vote.NoCount);
					}
					case 1:
					{
						vote.SetPass("投票通过...");
						delete g_hChangelevel;
						g_hChangelevel = CreateTimer(8.0, ChangelevelMap);
						PrintHintTextToAll("[提示] 投票通过,将在 8秒 后重启当前章节.");
						PrintToChatAll("\x04[提示]\x05投票通过\x04.\x038\x05秒后重启当前章节\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", iPercent, vote.YesCount + vote.NoCount);
					}
					case 2:
					{
						vote.SetPass("投票通过...");
						char g_sBanTime[64];
						FormatEx(g_sBanTime, sizeof(g_sBanTime), "你被投票踢出,并且被封禁%d分钟", g_iBanTime);

						int client = GetPlayerAuthIdIndex(sInfo[2]);
						if (client != -1)
						{
							if (g_iBanTime <= -1)
								KickClient(client, "你被投票踢出");
							else
							{
								if(g_bLibraries)
									BanPlayers(client, g_iBanTime, BANFLAG_AUTO, "被投票踢出", g_sBanTime, "sm_ban", client);
								else
									BanClient(client, g_iBanTime, BANFLAG_AUTO, "被投票踢出", g_sBanTime, "sm_ban", client);
							}
						}
						else
							if (g_iBanTime > -1)
								BanIdentity(sInfo[2], g_iBanTime, BANFLAG_AUTO, g_sBanTime, "sm_ban", client);
						
						PrintToChatAll("\x04[提示]\x05投票通过\x04.\x05玩家\x03%s\x05已被踢出.\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", sInfo[1], iPercent, vote.YesCount + vote.NoCount);
					}
				}
			}
		}
	}
}

int GetPlayerAuthIdIndex(char[] steamid)
{
	char auth[32];
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			if(GetClientAuthId(i, AuthId_Steam2, auth, sizeof(auth)))
				if(strcmp(auth, steamid) == 0)
					return i;
	return -1;
}

public Action ChangelevelMap(Handle Timer)
{
	char sMap[32];
	GetCurrentMap(sMap, sizeof(sMap));
	ServerCommand("changelevel %s", sMap);
	g_hChangelevel = null;
	return Plugin_Stop;
}

char[] GetDifficulty()
{
	char sDifficulty[16];
	GetConVarString(FindConVar("z_difficulty"), sDifficulty, sizeof(sDifficulty));
	return sDifficulty;
}

bool GetplayerTarget(int client)
{
	for(int i = 1;i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && client != i)
		{
			if (!CanUserTarget(client, i) && CanUserTarget(i, client))
				continue;
			return true;
		}
	}	
	return false;
}

bool TestVoteDelay(int client)
{
 	int delay = CheckVoteDelay();
 	
 	if (delay > 0)
	{
 		PrintToChat(client, "\x04[提示]\x05您必须再等待\x03%s\x05后才能发起新的投票.", StandardizeTime(delay));
 		return true;
 	}
	return false;
}

//https://forums.alliedmods.net/showthread.php?t=288686
char[] StandardizeTime(int remainder)
{
	char str[32], sD[32], sH[32], sM[32], sS[32];

	int D = RoundToFloor(float(remainder) / 86400.0);
	remainder = remainder - (D * 86400);
	int H = RoundToFloor(float(remainder) / 3600.0);
	remainder = remainder - (H * 3600);
	int M = RoundToFloor(float(remainder) / 60.0);
	remainder = remainder - (M * 60);
	int S = RoundToFloor(float(remainder));

	FormatEx(sD, sizeof(sD), "%d天", D);
	FormatEx(sH, sizeof(sH), "%d%s", H, !D && !M && !S ? "小时" : "时");
	FormatEx(sM, sizeof(sM), "%d%s", M, !D && !H && !S ? "分钟" : "分");
	FormatEx(sS, sizeof(sS), "%d秒", S);
	FormatEx(str, sizeof(str), "%s%s%s%s", !D ? "" : sD, !H ? "" : sH, !M ? "" : sM, !S ? "" : sS);
	return str;
}