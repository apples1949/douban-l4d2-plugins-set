/*
 *
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v1.1.0
 *
 *	1:新增名称前添加标记方便管理玩家免控.
 *	2:更改为用StringMap动态数组存变量以防止可能出现的继承遗产问题.
 *
 *	v1.2.0
 *
 *	1:合并牛牛撞击和携带,新增免疫坦克石头击倒和拳头击飞.
 *
 *	v1.2.1
 *
 *	1:再次修复新玩家加入时可能继承遗产的问题.
 *
 *	v1.3.1
 *
 *	1:新增管理员开关免控功能时给玩家显示提示.
 *
 */

#pragma semicolon 1
#pragma dynamic 331072	//增加堆栈空间.
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>
#include <left4dhooks>

#define PLUGIN_VERSION	"1.3.1"	//定义插件版本.
#define MAX_LENGTH		32		//字符串最大值.

int g_iIgnoreAbility[2][MAXPLAYERS + 1];

bool 
	g_bAllIgnoreAbility[5], 
	g_bIgnoreAbility[5][MAXPLAYERS + 1];

char g_sFreeControl[][] = {"舌头", "猎人", "猴子", "牛牛", "坦克"};

StringMap g_sArraySteamID;

TopMenu g_hTopMenu;
TopMenuObject hOtherFeatures = INVALID_TOPMENUOBJECT;

public Plugin myinfo =
{
	name = "l4d2_survivors_control", 
	author = "豆瓣酱な", 
	description = "生还者免疫特感控制.", 
	version = PLUGIN_VERSION, 
	url = "N/A"
};
//插件开始时.
public void OnPluginStart()
{
	g_sArraySteamID = new StringMap();
	
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
	RegConsoleCmd("sm_control", MenuSurvivorsControl, "管理员打开生还免控菜单.");
	HookEvent("player_disconnect", Event_PlayerDisconnect);//玩家离开.
}
//玩家加入时.
public void OnClientAuthorized(int client, const char[] auth)
{
	if(!IsFakeClient(client))
	{
		char sAuth[MAX_LENGTH];
		char sIgnoreAbility[5][MAX_LENGTH] = {"0","0","0","0","0"};
		if(GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth)))
			IsPlayerControlStatus(client, sAuth, sIgnoreAbility, sizeof(sIgnoreAbility), sizeof(sIgnoreAbility[]));
		else
			KickClient(client, "你已被踢出.\n踢出原因:ID获取失败.\n你的ID为:%s.", sAuth);//执行踢出玩家并显示原因.
	}
}
//获取或设置玩家免控状态.
void IsPlayerControlStatus(int client, const char[] auth, char[][] sBuffer, int numStrings, int maxLength)
{
	char sData[128];
	ImplodeStrings(sBuffer, numStrings, "|", sData, sizeof(sData));//打包字符串.
	if(!g_sArraySteamID.GetString(auth, sData, sizeof(sData)))
		g_sArraySteamID.SetString(auth, sData);

	char[][] sInfo = new char[numStrings][maxLength];
	ExplodeString(sData, "|", sInfo, numStrings, maxLength);//拆分字符串.

	for(int i = 0; i < numStrings; i++)
		g_bIgnoreAbility[i][client] = view_as<bool>(StringToInt(sInfo[i]));
}
//玩家离开.
public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event,"userid"));
	
	if (client > 0 && !IsFakeClient(client))
	{
		char auth[MAX_LENGTH];
		GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
		g_sArraySteamID.Remove(auth);
	}
}
public Action MenuSurvivorsControl(int client, int args)
{
	if(bCheckClientAccess(client))
		OpenPlayerMenu(client, 0, false);
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}
bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}
public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		g_hTopMenu = null;
}
 
public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (topmenu == g_hTopMenu)
		return;
	
	g_hTopMenu = topmenu;
	
	TopMenuObject hTopMenuObject = FindTopMenuCategory(g_hTopMenu, "OtherFeatures");
	if (hTopMenuObject == INVALID_TOPMENUOBJECT)
		hTopMenuObject = AddToTopMenu(g_hTopMenu, "OtherFeatures", TopMenuObject_Category, hMenuHandler, INVALID_TOPMENUOBJECT);
	
	hOtherFeatures = AddToTopMenu(g_hTopMenu,"sm_control",TopMenuObject_Item, hHandlerMenu, hTopMenuObject,"sm_control",ADMFLAG_ROOT);
}

void hMenuHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength, "选择功能:", param);//主菜单名称.
	}
	else if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "其它功能", param);//二级菜单名称.
	}
}

void hHandlerMenu(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == hOtherFeatures)
			Format(buffer, maxlength, "生还免控", param);//二级菜单标题.
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hOtherFeatures)
		{
			OpenPlayerMenu(param, 0, true);
		}
	}
}
void OpenPlayerMenu(int client, int index, bool bButton = false)
{
	char line[32];
	char sName[128];
	char sInfo[256];
	char sData[5][64];
	Menu menu = new Menu(MenuOpenPlayerHandler);
	Format(line, sizeof(line), "玩家免控:");
	SetMenuTitle(menu, "%s", line);

	strcopy(sData[0], sizeof(sData[]), "全部玩家");
	IntToString(index, sData[1], sizeof(sData[]));
	IntToString(bButton, sData[2], sizeof(sData[]));
	strcopy(sData[3], sizeof(sData[]), "全部玩家");
	IntToString(-1, sData[4], sizeof(sData[]));
	ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.
	FormatEx(sName, sizeof(sName), "[%s]%s", GetAllPlayerControlData(sizeof(g_bIgnoreAbility), sizeof(g_bIgnoreAbility[])), sData[3]);
	menu.AddItem(sInfo, sName);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			int Bot = IsClientIdle(i);
			strcopy(sData[0], sizeof(sData[]), "");
			IntToString(index, sData[1], sizeof(sData[]));
			IntToString(bButton, sData[2], sizeof(sData[]));
			GetClientName(Bot != 0 ? Bot : i, sData[3], sizeof(sData[]));
			IntToString(GetClientUserId(Bot != 0 ? Bot : i), sData[4], sizeof(sData[]));
			ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.
			FormatEx(sName, sizeof(sName), "[%s]%s", GetPlayerControlData(Bot != 0 ? Bot : i, sizeof(g_bIgnoreAbility), sizeof(g_bIgnoreAbility[])), sData[3]);
			menu.AddItem(sInfo, sName);
		}
	}
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = bButton;
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}
char[] GetPlayerControlData(int client, int numStrings, int maxLength)
{
	char sData[128];
	char[][] sInfo = new char[numStrings][maxLength];
	for(int i = 0; i < numStrings; i++)
		FormatEx(sInfo[i], maxLength,  g_bIgnoreAbility[i][client] == false ? "○" : "●");
	ImplodeStrings(sInfo, numStrings, "|", sData, sizeof(sData));//打包字符串.
	return sData;
}
char[] GetAllPlayerControlData(int numStrings, int maxLength)
{
	char sData[128];
	char[][] sInfo = new char[numStrings][maxLength];
	for(int i = 0; i < numStrings; i++)
		FormatEx(sInfo[i], maxLength,  GetAllPlayerControlState(i) == false ? "○" : "●");
	ImplodeStrings(sInfo, numStrings, "|", sData, sizeof(sData));//打包字符串.
	return sData;
}
int MenuOpenPlayerHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[128], sName[32], sInfo[256], sData[5][64];
			menu.GetItem(itemNum, sItem, sizeof(sItem), _, sName, sizeof(sName));
			ExplodeString(sItem, "|", sData, sizeof(sData), sizeof(sData[]));//拆分字符串.
			IntToString(menu.Selection, sData[1], sizeof(sData[]));
			ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.
			g_iIgnoreAbility[0][client] = StringToInt(sData[1]);
			g_iIgnoreAbility[1][client] = StringToInt(sData[2]);
			DisplayOtherFeaturesMenu(client, sInfo);
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack && g_hTopMenu != null)
				g_hTopMenu.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}
void DisplayOtherFeaturesMenu(int client, char[] sInfo)
{
	char sData[5][64];
	ExplodeString(sInfo, "|", sData, sizeof(sData), sizeof(sData[]));//拆分字符串.
	if(strcmp(sData[0], "全部玩家") == 0)
	{
		char line[32], item[32];
		Menu menu = new Menu(MenuOtherFeaturesHandler);

		Format(line, sizeof(line), "生还免控:(%s)\n ", sData[3]);
		SetMenuTitle(menu, "%s", line);
		Format(item, sizeof(item), "[%s] 免疫舌头缠住", GetAllPlayerControlState(0) == false ? "○" : "●");
		menu.AddItem(sInfo, item);
		Format(item, sizeof(item), "[%s] 免疫猎人扑倒", GetAllPlayerControlState(1) == false ? "○" : "●");
		menu.AddItem(sInfo, item);
		Format(item, sizeof(item), "[%s] 免疫猴子骑乘", GetAllPlayerControlState(2) == false ? "○" : "●");
		menu.AddItem(sInfo, item);
		Format(item, sizeof(item), "[%s] 免疫牛牛控制", GetAllPlayerControlState(3) == false ? "○" : "●");
		menu.AddItem(sInfo, item);
		Format(item, sizeof(item), "[%s] 免疫坦克击倒", GetAllPlayerControlState(4) == false ? "○" : "●");
		menu.AddItem(sInfo, item);
		menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
		menu.ExitBackButton = true;//菜单首页显示数字8返回上一页选项.
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		int victim = GetClientOfUserId(StringToInt(sData[4]));
		if(IsValidClient(victim))
		{
			char line[32], item[32];
			Menu menu = new Menu(MenuOtherFeaturesHandler);

			Format(line, sizeof(line), "生还免控:(%s)\n ", sData[3]);
			SetMenuTitle(menu, "%s", line);
			Format(item, sizeof(item), "[%s] 免疫舌头缠住", g_bIgnoreAbility[0][victim] == false ? "○" : "●");
			menu.AddItem(sInfo, item);
			Format(item, sizeof(item), "[%s] 免疫猎人扑倒", g_bIgnoreAbility[1][victim] == false ? "○" : "●");
			menu.AddItem(sInfo, item);
			Format(item, sizeof(item), "[%s] 免疫猴子骑乘", g_bIgnoreAbility[2][victim] == false ? "○" : "●");
			menu.AddItem(sInfo, item);
			Format(item, sizeof(item), "[%s] 免疫牛牛控制", g_bIgnoreAbility[3][victim] == false ? "○" : "●");
			menu.AddItem(sInfo, item);
			Format(item, sizeof(item), "[%s] 免疫坦克击倒", g_bIgnoreAbility[4][victim] == false ? "○" : "●");
			menu.AddItem(sInfo, item);
			menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
			menu.ExitBackButton = true;//菜单首页显示数字8返回上一页选项.
			menu.Display(client, MENU_TIME_FOREVER);
		}
	}
}
//获取全部玩家每个类型开关状态.
bool GetAllPlayerControlState(int index)
{
	return g_bAllIgnoreAbility[index] = GetAllFreeControlState(index);
}
//每个类型都开启或关闭.
bool GetAllFreeControlState(int index)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			int Bot = IsClientIdle(i);
			if(g_bIgnoreAbility[index][Bot != 0 ? Bot : i] == false)
				return false;
		}
	}
	return true;
}
//菜单回调.
int MenuOtherFeaturesHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[256], sName[32], sData[5][64];
			menu.GetItem(itemNum, sItem, sizeof(sItem), _, sName, sizeof(sName));
			ExplodeString(sItem, "|", sData, sizeof(sData), sizeof(sData[]));//拆分字符串.

			if(strcmp(sData[0], "全部玩家") == 0)
			{
				g_bAllIgnoreAbility[itemNum] = !g_bAllIgnoreAbility[itemNum];
				
				for(int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && GetClientTeam(i) == 2)
					{
						int Bot = IsClientIdle(i);
						g_bIgnoreAbility[itemNum][Bot != 0 ? Bot : i] = g_bAllIgnoreAbility[itemNum];
						IsDisplayFreeControl(Bot != 0 ? Bot : i, client, true);//显示开关免控提示.
						//设置玩家免控配置.
						SetPlayerControlData(Bot != 0 ? Bot : i, sizeof(g_bIgnoreAbility), sizeof(g_bIgnoreAbility[]));

						if(g_bIgnoreAbility[itemNum][Bot != 0 ? Bot : i] == true)
							IsReleaseControl(i, itemNum);//解除感染者控制生还者.
					}
				}
			}
			else
			{
				int victim = GetClientOfUserId(StringToInt(sData[4]));
				if(IsValidClient(victim))
				{
					g_bIgnoreAbility[itemNum][victim] = !g_bIgnoreAbility[itemNum][victim];
					GetAllPlayerControlState(itemNum);//重置菜单全部玩家免控显示.
					IsDisplayFreeControl(victim, client, false);//显示开关免控提示.
					//设置玩家免控配置.
					SetPlayerControlData(victim, sizeof(g_bIgnoreAbility), sizeof(g_bIgnoreAbility[]));

					if(g_bIgnoreAbility[itemNum][victim] == true)
					{
						switch(GetClientTeam(victim))
						{
							case 1:
							{
								int Bot = GetBotOfIdlePlayer(victim);
								if(Bot != 0)
									IsReleaseControl(Bot, itemNum);//解除感染者控制生还者.
							}
							case 2:
								IsReleaseControl(victim, itemNum);//解除感染者控制生还者.
						}
					}
				}
			}
			DisplayOtherFeaturesMenu(client, sItem);//重新打开菜单.
		}
		//按下数字8时返回上一层.
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack && g_hTopMenu != null)
			{
				//g_hTopMenu.Display(client, TopMenuPosition_LastCategory);
				OpenPlayerMenu(client, g_iIgnoreAbility[0][client], view_as<bool>(g_iIgnoreAbility[1][client]));//重新打开菜单.
			}
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}
void IsDisplayFreeControl(int victim, int client, bool bState)
{
	if(bState == true)
	{
		if(client != victim)
			PrintHintText(victim, "免疫特感控制\n%s", GetFreeControlState(victim));
		else
			PrintHintText(client, "[全部玩家]免疫特感控制\n%s", GetAllClientFreeControlState());
	}
	else
	{
		PrintHintText(client, "[%N]免疫特感控制\n%s", victim, GetFreeControlState(victim));
		PrintHintText(victim, "[%N]免疫特感控制\n%s", victim, GetFreeControlState(victim));
	}
}
//获取单个玩家免控开关状态.
char[] GetFreeControlState(int client)
{
	char sInfo[128];
	char[][] sData = new char[sizeof(g_bIgnoreAbility)][MAX_LENGTH];//创建动态大小的字符串.
	for(int i = 0; i < sizeof(g_bIgnoreAbility); i++)
		Format(sData[i], MAX_LENGTH, "%s[%s]", g_sFreeControl[i], g_bIgnoreAbility[i][client] == false ? "○" : "●");
	ImplodeStrings(sData, sizeof(g_bIgnoreAbility), "", sInfo, sizeof(sInfo));//打包字符串.
	return sInfo;
}
//获取全部玩家免控开关状态.
char[] GetAllClientFreeControlState()
{
	char sInfo[128];
	char[][] sData = new char[sizeof(g_bAllIgnoreAbility)][MAX_LENGTH];//创建动态大小的字符串.
	for(int i = 0; i < sizeof(g_bAllIgnoreAbility); i++)
		Format(sData[i], MAX_LENGTH, "%s[%s]", g_sFreeControl[i], g_bAllIgnoreAbility[i] == false ? "○" : "●");
	ImplodeStrings(sData, sizeof(g_bAllIgnoreAbility), "", sInfo, sizeof(sInfo));//打包字符串.
	return sInfo;
}
//设置玩家免控配置.
void SetPlayerControlData(int client, int numStrings, int maxLength)
{
	char auth[MAX_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
	if(strcmp(auth, "BOT") != 0)
	{
		char sData[128];
		char[][] sInfo = new char[numStrings][maxLength];
		for(int i = 0; i < numStrings; i++)
			IntToString(g_bIgnoreAbility[i][client], sInfo[i], maxLength);
		ImplodeStrings(sInfo, numStrings, "|", sData, sizeof(sData));//打包字符串.
		g_sArraySteamID.SetString(auth, sData);
	}
}
//解除感染者控制生还者.
void IsReleaseControl(int victim, int itemNum)
{
	int attacker;
	switch(itemNum)
	{
		case 0://解除舌头控制.
		{
			attacker = GetEntPropEnt(victim, Prop_Send, "m_tongueOwner");
			if(attacker > 0)
				L4D_Smoker_ReleaseVictim(victim, attacker);
		}
		case 1://解除猎人控制.
		{
			attacker = GetEntPropEnt(victim, Prop_Send, "m_pounceAttacker");
			if(attacker > 0)
				L4D_Hunter_ReleaseVictim(victim, attacker);
		}
		case 2://解除猴子控制.
		{
			attacker = GetEntPropEnt(victim, Prop_Send, "m_jockeyAttacker");
			if(attacker > 0)
				L4D2_Jockey_EndRide(victim, attacker);
		}
		case 3://解除牛牛控制.
		{
			attacker = GetEntPropEnt(victim, Prop_Send, "m_carryAttacker");
			if(attacker > 0)
				L4D2_Charger_EndCarry(victim, attacker);
			
			attacker = GetEntPropEnt(victim, Prop_Send, "m_pummelAttacker");
			if(attacker > 0)
				L4D2_Charger_EndPummel(victim, attacker);
		}
		case 4:{}//坦克没有强控技能.
	}
}
//舌头缠住生还者时.
public Action L4D_OnGrabWithTongue(int victim, int attacker) 
{
	int Bot = IsClientIdle(victim);
	if (!g_bIgnoreAbility[0][Bot != 0 ? Bot : victim])
		return Plugin_Continue;

	return Plugin_Handled;
}
//猎人扑倒生还者时.
public Action L4D_OnPouncedOnSurvivor(int victim, int attacker) 
{
	int Bot = IsClientIdle(victim);
	if (!g_bIgnoreAbility[1][Bot != 0 ? Bot : victim])
		return Plugin_Continue;

	return Plugin_Handled;
}
//猴子骑乘生还者时.
public Action L4D2_OnJockeyRide(int victim, int attacker) 
{
	int Bot = IsClientIdle(victim);
	if (!g_bIgnoreAbility[2][Bot != 0 ? Bot : victim])
		return Plugin_Continue;

	return Plugin_Handled;
}
//牛牛携带生还者时.
public Action L4D2_OnStartCarryingVictim(int victim, int attacker) 
{
	int Bot = IsClientIdle(victim);
	if (!g_bIgnoreAbility[3][Bot != 0 ? Bot : victim])
		return Plugin_Continue;

	return Plugin_Handled;
}
//牛牛殴打生还者时.
public Action L4D2_OnPummelVictim(int attacker, int victim) 
{
	int Bot = IsClientIdle(victim);
	if (!g_bIgnoreAbility[3][Bot != 0 ? Bot : victim])
		return Plugin_Continue;

	// from "left4dhooks_test.sp"
	DataPack dPack = new DataPack();
	dPack.WriteCell(GetClientUserId(attacker));
	dPack.WriteCell(GetClientUserId(victim));
	RequestFrame(OnPummelTeleport, dPack);

	// To block the stumble animation, uncomment and use the following 2 lines:
	AnimHookEnable(victim, OnPummelOnAnimPre, INVALID_FUNCTION);
	CreateTimer(0.3, TimerOnPummelResetAnim, victim);

	return Plugin_Handled;
}
// To fix getting stuck use this:
void OnPummelTeleport(DataPack dPack) {
	dPack.Reset();
	int attacker = dPack.ReadCell();
	int victim = dPack.ReadCell();
	delete dPack;

	attacker = GetClientOfUserId(attacker);
	if (!attacker || !IsClientInGame(attacker))
		return;

	victim = GetClientOfUserId(victim);
	if (!victim || !IsClientInGame(victim))
		return;

	SetVariantString("!activator");
	AcceptEntityInput(victim, "SetParent", attacker);
	TeleportEntity(victim, view_as<float>({50.0, 0.0, 0.0}), NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(victim, "ClearParent");
}
// To block the stumble animation use the next two functions:
Action OnPummelOnAnimPre(int client, int &anim) {
	if (anim == L4D2_ACT_TERROR_SLAMMED_WALL || anim == L4D2_ACT_TERROR_SLAMMED_GROUND) {
		anim = L4D2_ACT_STAND;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}
// Don't need client userID since it's not going to be validated just removed
Action TimerOnPummelResetAnim(Handle timer, any victim) {
	AnimHookDisable(victim, OnPummelOnAnimPre);

	return Plugin_Continue;
}
//免疫坦克石头和牛牛撞倒.
public Action L4D_OnKnockedDown(int client, int reason)
{
	int Bot = IsClientIdle(client);
	
	switch(reason)
	{
		case 2:
		{
			if (!g_bIgnoreAbility[4][Bot != 0 ? Bot : client])
				return Plugin_Continue;
			return Plugin_Handled;
		}
		case 3:
		{
			if (!g_bIgnoreAbility[3][Bot != 0 ? Bot : client])
				return Plugin_Continue;
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}
//免疫坦克拳头.
public Action L4D_TankClaw_OnPlayerHit_Pre(int tank, int claw, int player)
{
	int Bot = IsClientIdle(player);
	if (!g_bIgnoreAbility[4][Bot != 0 ? Bot : player])
		return Plugin_Continue;
	return Plugin_Handled;
}
//玩家有效.
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
stock char[] GetTrueName(int client)
{
	char sName[32];
	int Bot = IsClientIdle(client);
	
	if(Bot != 0)
		FormatEx(sName, sizeof(sName), "闲置:%N", Bot);
	else
		GetClientName(client, sName, sizeof(sName));
	return sName;
}
//返回闲置玩家对应的电脑.
stock int GetBotOfIdlePlayer(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && IsClientIdle(i) == client)
			return i;
	}
	return 0;
}
stock int IsClientIdle(int client) 
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}