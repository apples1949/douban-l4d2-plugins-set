/*
 * v1.9.7
 *	
 *	1:修复换角色后弹夹异常补满的问题.
 *	2:换角色指令!csm改成闲置状态也能使用.
 *	3:选择角色后菜单自动重新打开.
 *
 * v1.9.8
 *	
 *	1:快捷指令更改角色不自动打开更换角色菜单.
 *
 * v1.9.9
 *	
 *	1:修复被控制，起身时等情况下菜单打不开的问题.
 *
 * v1.9.10
 *	
 *	1:修复特感团队可以打开更换生还者模型菜单的问题.
 *
 * v1.9.11
 *	
 *	1:修复了一些细节方面的问题.
 *	2:管理员菜单列表从玩家功能更改到其它功能里.
 *
 * v1.9.12
 *	
 *	1:补充了一些动画序列号.
 *
 */
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>
#include <dhooks>
#include <sdkhooks>

#define PLUGIN_PREFIX			"\x01[\x04SCS\x01]"
#define PLUGIN_NAME				"Survivor Chat Select"
#define PLUGIN_AUTHOR			"DeatChaos25, Mi123456 & Merudo, Lux, SilverShot"
#define PLUGIN_DESCRIPTION		"Select a survivor character by typing their name into the chat."
#define PLUGIN_VERSION			"1.9.12"
#define PLUGIN_URL				"https://forums.alliedmods.net/showthread.php?p=2399163#post2399163"

#define GAMEDATA				"survivor_chat_select"

#define DEBUG					0

#define	 NICK					0, 0
#define	 ROCHELLE				1, 1
#define	 COACH					2, 2
#define	 ELLIS					3, 3
#define	 BILL					4, 4
#define	 ZOEY					5, 5
#define	 FRANCIS				6, 6
#define	 LOUIS					7, 7

Handle
	g_hSDK_CTerrorGameRules_GetMissionInfo,
	g_hSDK_CDirector_IsInTransition,
	g_hSDK_KeyValues_GetInt;

DynamicDetour
	g_ddRestoreTransitionedSurvivorBot,
	g_ddInfoChangelevel_ChangeLevelNow;

StringMap
	g_smSurModels,
	g_sArraySteamID;

TopMenu g_hTopMenu;
TopMenuObject hOtherFeatures = INVALID_TOPMENUOBJECT;

Address
	g_pDirector,
	g_pSavedPlayersCount,
	g_pSavedSurvivorBotsCount;

ConVar
	g_cAutoModel,
	g_cTabHUDBar,
	g_cAdminFlags,
	g_cInTransition,
	g_cPrecacheAllSur;

int
	g_iTabHUDBar,
	g_iAdminFlags,
	g_iOrignalSet,
	g_iTransitioning[MAXPLAYERS + 1];

bool
	g_bAutoModel,
	g_bTransition,
	g_bTransitioned,
	g_bInTransition,
	g_bBlockUserMsg,
	g_bRestoringBots,
	g_bBotPlayer[MAXPLAYERS + 1],
	g_bPlayerBot[MAXPLAYERS + 1],
	g_bJoinStatus[MAXPLAYERS + 1],
	g_bFirstSpawn[MAXPLAYERS + 1],
	g_bPlayerButton[MAXPLAYERS + 1];

static const char
	g_sSurNames[][] = {
		"Nick",
		"Rochelle",
		"Coach",
		"Ellis",
		"Bill",
		"Zoey",
		"Francis",
		"Louis",
	},
	g_sSurModels[][] = {
		"models/survivors/survivor_gambler.mdl",
		"models/survivors/survivor_producer.mdl",
		"models/survivors/survivor_coach.mdl",
		"models/survivors/survivor_mechanic.mdl",
		"models/survivors/survivor_namvet.mdl",
		"models/survivors/survivor_teenangst.mdl",
		"models/survivors/survivor_biker.mdl",
		"models/survivors/survivor_manager.mdl"
	};

methodmap CPlayerResource {
	public CPlayerResource() {
		return view_as<CPlayerResource>(GetPlayerResourceEntity());
	}

	public int m_iTeam(int client) {
		return GetEntProp(view_as<int>(this), Prop_Send, "m_iTeam", _, client);
	}

	public int m_bConnected(int client) {
		return GetEntProp(view_as<int>(this), Prop_Send, "m_bConnected", _, client);
	}
}

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	InitGameData();
	g_smSurModels = new StringMap();
	g_sArraySteamID = new StringMap();
	HookUserMessage(GetUserMessageId("SayText2"), umSayText2, true);
/*
	RegConsoleCmd("sm_zoey",		cmdZoeyUse,		"Changes your survivor character into Zoey");
	RegConsoleCmd("sm_nick",		cmdNickUse,		"Changes your survivor character into Nick");
	RegConsoleCmd("sm_ellis",		cmdEllisUse,	"Changes your survivor character into Ellis");
	RegConsoleCmd("sm_coach",		cmdCoachUse,	"Changes your survivor character into Coach");
	RegConsoleCmd("sm_rochelle",	cmdRochelleUse,	"Changes your survivor character into Rochelle");
	RegConsoleCmd("sm_bill",		cmdBillUse,		"Changes your survivor character into Bill");
	RegConsoleCmd("sm_francis",		cmdBikerUse,	"Changes your survivor character into Francis");
	RegConsoleCmd("sm_louis",		cmdLouisUse,	"Changes your survivor character into Louis");

	RegConsoleCmd("sm_z",			cmdZoeyUse,		"Changes your survivor character into Zoey");
	RegConsoleCmd("sm_n",			cmdNickUse,		"Changes your survivor character into Nick");
	RegConsoleCmd("sm_e",			cmdEllisUse,	"Changes your survivor character into Ellis");
	RegConsoleCmd("sm_c",			cmdCoachUse,	"Changes your survivor character into Coach");
	RegConsoleCmd("sm_r",			cmdRochelleUse,	"Changes your survivor character into Rochelle");
	RegConsoleCmd("sm_b",			cmdBillUse,		"Changes your survivor character into Bill");
	RegConsoleCmd("sm_f",			cmdBikerUse,	"Changes your survivor character into Francis");
	RegConsoleCmd("sm_l",			cmdLouisUse,	"Changes your survivor character into Louis");
*/
	RegConsoleCmd("sm_csm",			cmdCsm,			"Brings up a menu to select a client's character");

	RegAdminCmd("sm_csc",			cmdCsc,			ADMFLAG_ROOT, "Brings up a menu to select a client's character");
	RegAdminCmd("sm_setleast",		cmdSetLeast,	ADMFLAG_ROOT, "重新将所有生还者模型设置为重复次数最少的");

	g_cAutoModel =			CreateConVar("l4d_scs_auto_model",		"1",	"开关8人独立模型?", FCVAR_NOTIFY);
	g_cTabHUDBar =			CreateConVar("l4d_scs_tab_hud_bar",		"1",	"在哪些地图上显示一代人物的TAB状态栏? \n0=默认, 1=一代图, 2=二代图, 3=一代和二代图.", FCVAR_NOTIFY);
	g_cAdminFlags =			CreateConVar("l4d_csm_admin_flags",		"z",	"允许哪些玩家使用csm命令(flag参考admin_levels.cfg)? \n留空=所有玩家都能使用, z=仅限root权限的玩家使用.", FCVAR_NOTIFY);
	g_cInTransition =		CreateConVar("l4d_csm_in_transition",	"1",	"启用8人独立模型后不对正在过渡的玩家设置?", FCVAR_NOTIFY);
	g_cPrecacheAllSur =		FindConVar("precache_all_survivors");

	g_cAutoModel.AddChangeHook(CvarChanged);
	g_cTabHUDBar.AddChangeHook(CvarChanged);
	g_cAdminFlags.AddChangeHook(CvarChanged);
	g_cInTransition.AddChangeHook(CvarChanged);

	AutoExecConfig(true, "survivor_chat_select");//生成指定文件名的CFG.

	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);

	for (int i; i < sizeof g_sSurModels; i++)
		g_smSurModels.SetValue(g_sSurModels[i], i);
}

//玩家加入.
public void OnClientAuthorized(int client, const char[] auth)
{
	if(!IsFakeClient(client))
	{
		g_bJoinStatus[client] = false;
		g_sArraySteamID.GetValue(auth, g_bJoinStatus[client]);
	}
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
	
	hOtherFeatures = AddToTopMenu(g_hTopMenu,"sm_csc",TopMenuObject_Item, hHandlerMenu, hTopMenuObject,"sm_csc",ADMFLAG_ROOT);
}

void hMenuHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength, "选择功能:", param);
	}
	else if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "其它功能", param);
	}
}

void hHandlerMenu(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == hOtherFeatures)
			Format(buffer, maxlength, "更改模型", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hOtherFeatures)
		{
			//cmdCsc(param, 0, false);
			OpenCscMenu(param, true);
		}
	}
}

Action cmdSetLeast(int client, int args) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
			SetLeastCharacter(i);
	}

	return Plugin_Handled;
}

Action cmdCsc(int client, int args) {
	if (!client || !IsClientInGame(client))
		return Plugin_Handled;

	OpenCscMenu(client, false);
	return Plugin_Handled;
}
void OpenCscMenu(int client, bool bButton = false)
{
	g_bPlayerButton[client] = bButton;
	char info[128], disp[128], data[2][32];
	Menu menu = new Menu(Csc_MenuHandler);
	menu.SetTitle("目标玩家:");

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != 2)
			continue;

		IntToString(bButton, data[0], sizeof(data[]));
		IntToString(GetClientUserId(i), data[1], sizeof(data[]));
		ImplodeStrings(data, sizeof(data), "|", info, sizeof(info));//打包字符串.
		FormatEx(disp, sizeof disp, "%s - %s", GetModelName(i), GetTrueName(i));
		menu.AddItem(info, disp);
	}

	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = bButton;//菜单首页显示数字8返回上一页选项.
	menu.Display(client, MENU_TIME_FOREVER);
}

int Csc_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[128], data[2][32];
			menu.GetItem(param2, item, sizeof item);
			ExplodeString(item, "|", data, sizeof(data), sizeof(data[]));//拆分字符串.
			ShowMenuAdmin(client, 0, data[1], view_as<bool>(StringToInt(data[0])));
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack && g_hTopMenu != null)
				g_hTopMenu.Display(client, TopMenuPosition_LastCategory);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void ShowMenuAdmin(int client, int index, char[] item, bool bButton) {
	Menu menu = new Menu(ShowMenuAdmin_MenuHandler);
	menu.SetTitle("人物:");

	char sInfo[128], sData[3][32];

	for (int i = 0; i < sizeof g_sSurNames; i++)
	{
		strcopy(sData[0], sizeof(sData[]), item);
		IntToString(index, sData[1], sizeof(sData[]));
		IntToString(bButton, sData[2], sizeof(sData[]));
		ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.
		menu.AddItem(sInfo, g_sSurNames[i]);
	}

	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = true;//菜单首页显示数字8返回上一页选项.
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

int ShowMenuAdmin_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: 
		{
			if (param2 >= 0 && param2 <= 7)
			{
				char item[128], data[3][32];
				menu.GetItem(param2, item, sizeof item);
				ExplodeString(item, "|", data, sizeof(data), sizeof(data[]));//拆分字符串.
				SetCharacter(client, GetClientOfUserId(StringToInt(item)), param2, true, true, view_as<bool>(StringToInt(data[2])), param2, param2);
				ShowMenuAdmin(client, menu.Selection, data[0], view_as<bool>(StringToInt(data[2])));
			}
		}
		case MenuAction_Cancel: {
			OpenCscMenu(client, g_bPlayerButton[client]);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

Action cmdCsm(int client, int args) {
	if (!client || !IsClientInGame(client))
		return Plugin_Handled;

	Panel panel = new Panel();
	panel.SetTitle("选择人物:");
	//panel.DrawItem(" ", ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);
	for (int i = 0; i < sizeof g_sSurNames; i++) 
		panel.DrawItem(g_sSurNames[i]);
	panel.DrawItem(" ", ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);
	panel.DrawItem("0. 退出", ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);
	panel.Send(client, Csm_MenuHandler, 8);

	return Plugin_Handled;
}

int Csm_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: 
		{
			param2 -= 1;
			if (param2 >= 0 && param2 <= 7)
				if (CanUse(client, client, param2))
					SetCharacter(client, client, param2, true, false, false, param2, param2);
				else
					cmdCsm(client, 0);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

bool CanUse(int client, int victim, int index, bool checkAdmin = true) {
	//if (!client || !IsClientInGame(client)) {
	//	ReplyToCommand(client, "\x04[提示]\x05角色选择菜单仅适用于游戏中的玩家.");
	//	return false;
	//}

	if (checkAdmin && !CheckCommandAccess(client, "", g_iAdminFlags)) {
		PrintToChat(client, "\x04[提示]\x05只有管理员才能使用该菜单.");
		return false;
	}

	//if (GetClientTeam(client) != 2) {
	//	ReplyToCommand(client, "\x04[提示]\x05角色选择菜单仅适用于幸存者.");
	//	return false;
	//}

	if(GetClientTeam(client) == 1 && iGetBotOfIdlePlayer(client) == 0)
	{
		PrintToChat(client, "\x04[提示]\x05旁观者无法使用该指令.");
		return false;
	}

	switch (GetClientTeam(client)) 
	{
		case 1:
		{
			int iBot = iGetBotOfIdlePlayer(victim);

			if(iBot != 0)
			{
				if(g_bJoinStatus[victim] == false)
				{
					PrintToChat(client, "\x04[提示]\x05必须先加入一次生还者团队才能闲置使用此功能.");
					return false;
				}

				int iModel = iGetPlayerModel(iBot);

				if (iModel == -1) 
				{
					PrintToChat(client, "\x04[提示]\x05当前角色不支持该功能.");
					return false;
				}
				else if(iModel == index)
				{
					//PrintToChat(client, "\x04[提示]\x05选择的角色与当前角色相同.");
					return false;
				}

				if (L4D_IsPlayerStaggering(iBot)) 
				{
					PrintToChat(client, "\x04[提示]\x05硬直状态下临时禁止使用该功能.");
					return false;
				}
				if (IsGettingUp(iBot)) 
				{
					PrintToChat(client, "\x04[提示]\x05起身过程中临时禁止使用该功能.");
					return false;
				}
				if (IsPinned(iBot)) 
				{
					PrintToChat(client, "\x04[提示]\x05被控制时临时禁止使用该功能.");
					return false;
				}
			}
			else
			{
				PrintToChat(client, "\x04[提示]\x05旁观者临时禁止使用该功能.");
				return false;
			}
		}
		case 2:
		{
			int iModel = iGetPlayerModel(victim);

			if (iModel == -1) 
			{
				PrintToChat(client, "\x04[提示]\x05当前角色不支持该功能.");
				return false;
			}
			else if(iModel == index)
			{
				//PrintToChat(client, "\x04[提示]\x05选择的角色与当前角色相同.");
				return false;
			}
			if (L4D_IsPlayerStaggering(victim)) 
			{
				PrintToChat(client, "\x04[提示]\x05硬直状态下临时禁止使用该功能.");
				return false;
			}
			if (IsGettingUp(victim)) 
			{
				PrintToChat(client, "\x04[提示]\x05起身过程中临时禁止使用该功能.");
				return false;
			}
			if (IsPinned(victim)) 
			{
				PrintToChat(client, "\x04\x04[提示]\x05\x05被控制时临时禁止使用该功能.");
				return false;
			}
		}
		case 3:
		{
			PrintToChat(client, "\x04\x04[提示]\x05\x05特感团队禁止使用该指令.");
			return false;
		}
		default:
		{
			PrintToChat(client, "\x04[提示]\x05其它团队禁止使用该指令.");
			return false;
		}
	}
	return true;
}

int iGetPlayerModel(int client)
{
	char model[31];
	GetClientModel(client, model, sizeof model);
	switch (model[29]) {
		case 'b': {	//nick
			return 0;
		}

		case 'd': {	//rochelle
			return 1;
		}

		case 'c': {	//coach
			return 2;
		}

		case 'h': {	//ellis
			return 3;
		}

		case 'v': {	//bill
			return 4;
		}

		case 'n': {	//zoey
			return 5;
		}

		case 'e': {	//francis
			return 6;
		}

		case 'a': {	//louis
			return 7;
		}
	}

	return -1;
}

/**
 * @brief Checks if a Survivor is currently staggering
 *
 * @param client			Client ID of the player to affect
 *
 * @return Returns true if player is staggering, false otherwise
 */
stock bool L4D_IsPlayerStaggering(int client)
{
	static int m_iQueuedStaggerType = -1;
	if( m_iQueuedStaggerType == -1 )
	m_iQueuedStaggerType = FindSendPropInfo("CTerrorPlayer", "m_staggerDist") + 4;

	if( GetEntData(client, m_iQueuedStaggerType, 4) == -1 )
	{
		if( GetGameTime() >= GetEntPropFloat(client, Prop_Send, "m_staggerTimer", 1) )
		{
			return false;
		}

		static float vStgDist[3], vOrigin[3];
		GetEntPropVector(client, Prop_Send, "m_staggerStart", vStgDist);
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", vOrigin);

		static float fStgDist2;
		fStgDist2 = GetEntPropFloat(client, Prop_Send, "m_staggerDist");

		return GetVectorDistance(vStgDist, vOrigin) <= fStgDist2;
	}

	return true;
}

//返回对应的内容.
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
// L4D2_Adrenaline_Recovery (https://github.com/LuxLuma/L4D2_Adrenaline_Recovery/blob/ac3f62eebe95d80fcf610fb6c7c1ed56bf4b31d2/%5BL4D2%5DAdrenaline_Recovery.sp#L96-L177)
char[] GetModelName(int client) {
	int idx;
	char model[31];
	GetClientModel(client, model, sizeof model);
	switch (model[29]) {
		case 'b'://nick
			idx = 0;
		case 'd'://rochelle
			idx = 1;
		case 'c'://coach
			idx = 2;
		case 'h'://ellis
			idx = 3;
		case 'v'://bill
			idx = 4;
		case 'n'://zoey
			idx = 5;
		case 'e'://francis
			idx = 6;
		case 'a'://louis
			idx = 7;
		default:
			idx = 8;
	}

	strcopy(model, sizeof model, idx == 8 ? "未知" : g_sSurNames[idx]);
	return model;
}

// L4D2_Adrenaline_Recovery (https://github.com/LuxLuma/L4D2_Adrenaline_Recovery/blob/ac3f62eebe95d80fcf610fb6c7c1ed56bf4b31d2/%5BL4D2%5DAdrenaline_Recovery.sp#L96-L177)
bool IsGettingUp(int client) {
	char model[31];
	GetClientModel(client, model, sizeof model);
	switch (model[29]) {
		case 'b': {	//nick
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 661,669,628,629,667,671,672,627,630,620:
					return true;
			}
		}

		case 'd': {	//rochelle
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 668,676,636,637,674,678,679,635,638,629:
					return true;
			}
		}

		case 'c': {	//coach
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 650,658,628,629,656,660,661,627,630,621:
					return true;
			}
		}

		case 'h': {	//ellis
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 665,673,633,634,671,675,676,632,635,625:
					return true;
			}
		}

		case 'v': {	//bill
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 753,761,536,537,759,763,764,535,538,528:
					return true;
			}
		}

		case 'n': {	//zoey
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 813,821,545,546,819,823,824,544,547,537:
					return true;
			}
		}

		case 'e': {	//francis
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 756,764,539,540,762,766,767,538,541,531:
					return true;
			}
		}

		case 'a': {	//louis
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 753,761,536,537,759,763,764,535,538,528:
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

bool IsPinned(int client) {
	if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	return false;
}
/*
Action cmdNickUse(int client, int args) {
	if (!CanUse(client, client, 0))
		return Plugin_Handled;

	SetCharacter(client, client, 0, false, false, false, NICK);
	return Plugin_Handled;
}

Action cmdRochelleUse(int client, int args) {
	if (!CanUse(client, client, 1))
		return Plugin_Handled;

	SetCharacter(client, client, 1, false, false, false, ROCHELLE);
	return Plugin_Handled;
}

Action cmdCoachUse(int client, int args) {
	if (!CanUse(client, client, 2))
		return Plugin_Handled;

	SetCharacter(client, client, 2, false, false, false, COACH);
	return Plugin_Handled;
}

Action cmdEllisUse(int client, int args) {
	if (!CanUse(client, client, 3))
		return Plugin_Handled;

	SetCharacter(client, client, 3, false, false, false, ELLIS);
	return Plugin_Handled;
}

Action cmdBillUse(int client, int args) {
	if (!CanUse(client, client, 4))
		return Plugin_Handled;

	SetCharacter(client, client, 4, false, false, false, BILL);
	return Plugin_Handled;
}

Action cmdZoeyUse(int client, int args) {
	if (!CanUse(client, client, 5))
		return Plugin_Handled;

	SetCharacter(client, client, 5, false, false, false, ZOEY);
	return Plugin_Handled;
}

Action cmdBikerUse(int client, int args) {
	if (!CanUse(client, client, 6))
		return Plugin_Handled;

	SetCharacter(client, client, 6, false, false, false, FRANCIS);
	return Plugin_Handled;
}

Action cmdLouisUse(int client, int args) {
	if (!CanUse(client, client, 7))
		return Plugin_Handled;

	SetCharacter(client, client, 7, false, false, false, LOUIS);
	return Plugin_Handled;
}
*/
Action umSayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	if (!g_bBlockUserMsg)
		return Plugin_Continue;

	msg.ReadByte();
	msg.ReadByte();

	char buffer[254];
	msg.ReadString(buffer, sizeof buffer, true);
	if (strcmp(buffer, "#Cstrike_Name_Change") == 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

public void OnMapStart() {
	GetSurvivorSetMap();
	g_cPrecacheAllSur.IntValue = 1;
	for (int i; i < sizeof g_sSurModels; i++)
		PrecacheModel(g_sSurModels[i], true);
}

int GetSurvivorSetMap() {
	Address pMissionInfo = SDKCall(g_hSDK_CTerrorGameRules_GetMissionInfo);
	g_iOrignalSet = pMissionInfo ? SDKCall(g_hSDK_KeyValues_GetInt, pMissionInfo, "survivor_set", 2) : 0;
	return g_iOrignalSet;
}

public void OnConfigsExecuted() {
	GetCvars();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_bAutoModel =		g_cAutoModel.BoolValue;

	Toggle(g_bAutoModel);

	g_iTabHUDBar =		g_cTabHUDBar.IntValue;
	char flags[16];
	g_cAdminFlags.GetString(flags, sizeof flags);
	g_iAdminFlags = ReadFlagString(flags);
	g_bInTransition =	g_cInTransition.BoolValue;
}

void Toggle(bool enable) {
	static bool enabled;
	if (!enabled && enable) {
		enabled = true;

		HookEvent("round_start",			Event_RoundStart,			EventHookMode_PostNoCopy);
		HookEvent("player_bot_replace",		Event_PlayerBotReplace,		EventHookMode_Pre);
		HookEvent("bot_player_replace",		Event_BotPlayerReplace,		EventHookMode_Pre);
		HookEvent("player_team",			Event_PlayerTeam,			EventHookMode_Pre);
		HookEvent("player_disconnect", 		Event_PlayerDisconnect,		EventHookMode_Pre);//玩家离开.

		if (!g_ddRestoreTransitionedSurvivorBot.Enable(Hook_Pre, DD_RestoreTransitionedSurvivorBot_Pre))
			SetFailState("Failed to detour pre: \"DD::RestoreTransitionedSurvivorBots\"");

		if (!g_ddRestoreTransitionedSurvivorBot.Enable(Hook_Post, DD_RestoreTransitionedSurvivorBot_Post))
			SetFailState("Failed to detour post: \"DD::RestoreTransitionedSurvivorBots\"");

		if (!g_ddInfoChangelevel_ChangeLevelNow.Enable(Hook_Post, DD_InfoChangelevel_ChangeLevelNow_Post))
			SetFailState("Failed to detour post: \"DD::InfoChangelevel::ChangeLevelNow\"");
	}
	else if (enabled && !enable) {
		enabled = false;

		UnhookEvent("round_start",			Event_RoundStart,			EventHookMode_PostNoCopy);
		UnhookEvent("player_bot_replace",	Event_PlayerBotReplace,		EventHookMode_Pre);
		UnhookEvent("bot_player_replace",	Event_BotPlayerReplace,		EventHookMode_Pre);
		UnhookEvent("player_team",			Event_PlayerTeam,			EventHookMode_Pre);
		UnhookEvent("player_disconnect", 	Event_PlayerDisconnect,		EventHookMode_Pre);//玩家离开.

		if (!g_ddRestoreTransitionedSurvivorBot.Disable(Hook_Pre, DD_RestoreTransitionedSurvivorBot_Pre))
			SetFailState("Failed to disable detour pre: \"DD::RestoreTransitionedSurvivorBots\"");

		if (!g_ddRestoreTransitionedSurvivorBot.Disable(Hook_Post, DD_RestoreTransitionedSurvivorBot_Post))
			SetFailState("Failed to disable detour post: \"DD::RestoreTransitionedSurvivorBots\"");

		if (!g_ddInfoChangelevel_ChangeLevelNow.Disable(Hook_Post, DD_InfoChangelevel_ChangeLevelNow_Post))
			SetFailState("Failed to disable detour post: \"DD::InfoChangelevel::ChangeLevelNow\"");

		g_bTransition = false;
		g_bTransitioned = false;

		for (int i = 1; i <= MaxClients; i++) {
			g_bBotPlayer[i] = false;
			g_bPlayerBot[i] = false;
			g_iTransitioning[i] = 0;
			if (IsClientInGame(i))
				SDKUnhook(i, SDKHook_SpawnPost, IsFakeClient(i) ? BotSpawnPost : PlayerSpawnPost);
		}
	}
}

void Event_RoundStart(Event event, char[] name, bool dontBroadcast) {
	for (int i; i <= MaxClients; i++) {
		g_bBotPlayer[i] = false;
		g_bPlayerBot[i] = false;
	}
}

void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast) {
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (!bot || !IsClientInGame(bot))
		return;

	int player = GetClientOfUserId(event.GetInt("player"));
	if (!player || !IsClientInGame(player) || GetClientTeam(player) != 2)
		return;

	if (IsFakeClient(player)) {
		RequestFrame(NextFrame_PlayerBot, bot);
		return;
	}

	g_bPlayerBot[bot] = true;
	g_bBotPlayer[player] = false;
	RequestFrame(NextFrame_PlayerBot, bot);
}

void Event_BotPlayerReplace(Event event, char[] name, bool dontBroadcast) {
	int player = GetClientOfUserId(event.GetInt("player"));
	if (!player || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != 2)
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (!bot || !IsClientInGame(bot) || !CPlayerResource().m_bConnected(bot))
		return;

	g_bPlayerBot[bot] = false;
	g_bBotPlayer[player] = true;
	RequestFrame(NextFrame_BotPlayer, player);
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return;

	if (event.GetInt("team") != 2)
		return;

	if(g_bJoinStatus[client] == false)
	{
		char auth[32];
		GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
		g_sArraySteamID.SetValue(auth, g_bJoinStatus[client] = true);
	}
		

	switch (event.GetInt("oldteam")) {
		case 1, 3, 4:
			RequestFrame(NextFrame_Player, event.GetInt("userid"));
	}
}
//玩家离开.
void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event,"userid"));
	
	if (client > 0 && !IsFakeClient(client))
	{
		char auth[32];
		GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
		g_sArraySteamID.Remove(auth);//删除储存的玩家数据.
	}
}

void NextFrame_PlayerBot(int bot) {
	g_bPlayerBot[bot] = false;
}

void NextFrame_BotPlayer(int player) {
	g_bPlayerBot[player] = false;
}

void SetCharacter(int client, int victim, int index, bool back, bool type, bool bButton, int character, int modelIndex) {
	if (!CanUse(client, victim, index, false))
		return;

	SetCharacterInfo(client, victim, index, character, modelIndex);

	if(back == false)
		return;
	
	if(type == false)
		cmdCsm(client, 0);
	else
		OpenCscMenu(client, bButton);
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (!g_bAutoModel)
		return;

	if (entity < 1 || entity > MaxClients)
		return;

	if (classname[0] == 'p' && strcmp(classname[1], "layer", false) == 0) {
		g_bFirstSpawn[entity] = true;
		SDKHook(entity, SDKHook_SpawnPost, PlayerSpawnPost);

		if (g_iTransitioning[entity])
			g_iTransitioning[entity] = -1;
		else
			g_iTransitioning[entity] = IsTransitioning(GetClientUserId(entity)) ? 1 : -1;
	}

	if (classname[0] == 's' && strcmp(classname[1], "urvivor_bot", false) == 0) {
		if (!g_bInTransition || !PrepRestoreBots())
			SDKHook(entity, SDKHook_SpawnPost, BotSpawnPost);
	}
}

void PlayerSpawnPost(int client) {
	if (GetClientTeam(client) != 4) {
		switch (CPlayerResource().m_iTeam(client)) {
			case 0: {
				if (g_bInTransition && g_iTransitioning[client] == 1)
					g_bFirstSpawn[client] = false;
				else
					RequestFrame(NextFrame_Player, GetClientUserId(client));
			}

			case 1, 3, 4:
				RequestFrame(NextFrame_Player, GetClientUserId(client));
		}
	}
}

void NextFrame_Player(int client) {
	client = GetClientOfUserId(client);
	if (!client)
		return;

	if (!IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if ((!g_bFirstSpawn[client] && g_bBotPlayer[client]) || g_bPlayerBot[client])
		return;

	static bool once[MAXPLAYERS + 1];
	if (once[client] && !PrepTransition() && !PrepRestoreBots()) {
		once[client] = false;
		SetLeastCharacter(client);
		g_bFirstSpawn[client] = false;
	}
	else {
		once[client] = !PrepTransition() && !PrepRestoreBots();

		if (!g_bInTransition) {
			SetLeastCharacter(client);
			g_bFirstSpawn[client] = false;
		}
		else
			RequestFrame(NextFrame_Player, GetClientUserId(client));
	}
}

void BotSpawnPost(int client) {
	if (GetClientTeam(client) == 4)
		return;

	SDKUnhook(client, SDKHook_SpawnPost, BotSpawnPost);
	RequestFrame(NextFrame_Bot, GetClientUserId(client));
}

void NextFrame_Bot(int client) {
	client = GetClientOfUserId(client);
	if (!client)
		return;

	if (g_bPlayerBot[client] || g_bBotPlayer[client])
		return;

	if (!IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if (g_bInTransition) {
		int userid = GetEntProp(client, Prop_Send, "m_humanSpectatorUserID");
		if (GetClientOfUserId(userid) && IsTransitioning(userid))
			return;
	}

	SetLeastCharacter(client);
}

void SetLeastCharacter(int client) {
	int index = GetLeastCharacter(client);
	switch (index) {
		case 0:
			SetCharacterInfo(client, client, index, NICK);

		case 1:
			SetCharacterInfo(client, client, index, ROCHELLE);

		case 2:
			SetCharacterInfo(client, client, index, COACH);

		case 3:
			SetCharacterInfo(client, client, index, ELLIS);

		case 4:
			SetCharacterInfo(client, client, index, BILL);

		case 5:
			SetCharacterInfo(client, client, index, ZOEY);

		case 6:
			SetCharacterInfo(client, client, index, FRANCIS);

		case 7:
			SetCharacterInfo(client, client, index, LOUIS);
	}
}

int GetLeastCharacter(int client) {
	int i = 1, buf, least[8];
	static char ModelName[128];
	for (; i <= MaxClients; i++) {
		if (i == client || !IsClientInGame(i) || IsClientInKickQueue(i) || GetClientTeam(i) != 2)
			continue;

		GetClientModel(i, ModelName, sizeof ModelName);
		if (g_smSurModels.GetValue(ModelName, buf))
			least[buf]++;
	}

	switch ((g_iOrignalSet > 0 || GetSurvivorSetMap() > 0) ? g_iOrignalSet : 2) {
		case 1: {
			buf = 7;
			int tempChar = least[7];
			for (i = 7; i >= 0; i--) {
				if (least[i] < tempChar) {
					tempChar = least[i];
					buf = i;
				}
			}
		}

		case 2: {
			buf = 0;
			int tempChar = least[0];
			for (i = 0; i <= 7; i++) {
				if (least[i] < tempChar) {
					tempChar = least[i];
					buf = i;
				}
			}
		}
	}

	return buf;
}

void SetCharacterInfo(int client, int victim, int index, int character, int modelIndex) {
	if (g_iTabHUDBar && g_iTabHUDBar & ((g_iOrignalSet > 0 || GetSurvivorSetMap() > 0) ? g_iOrignalSet : 2))
		character = ConvertToInternalCharacter(character);

	#if DEBUG
	int buf = -1;
	static char ModelName[128];
	GetClientModel(victim, ModelName, sizeof ModelName);
	g_smSurModels.GetValue(ModelName, buf);
	LogError("Set \"%N\" Character \"%s\" to \"%s\"", victim, buf != -1 ? g_sSurNames[buf] : ModelName, g_sSurNames[modelIndex]);
	#endif

	switch (GetClientTeam(victim)) 
	{
		case 1:
		{
			int iBot = iGetBotOfIdlePlayer(victim);

			if(iBot != 0)
			{
				SetEntProp(iBot, Prop_Send, "m_survivorCharacter", character, 2);
				SetEntityModel(iBot, g_sSurModels[modelIndex]);
				ReEquipWeapons(iBot);
				PrintToConsole(client, "\x04[提示]\x05角色已更改为\x04:\x03%s\x04.", g_sSurNames[index]);
			}
		}
		case 2:
		{
			SetEntProp(victim, Prop_Send, "m_survivorCharacter", character, 2);
			SetEntityModel(victim, g_sSurModels[modelIndex]);

			if (IsFakeClient(victim)) {
				g_bBlockUserMsg = true;
				SetClientInfo(victim, "name", g_sSurNames[modelIndex]);
				g_bBlockUserMsg = false;
			}

			ReEquipWeapons(victim);
			PrintToConsole(client, "\x04[提示]\x05角色已更改为\x04:\x03%s\x04.", g_sSurNames[index]);
		}
	}
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

// https://github.com/LuxLuma/Left-4-fix/blob/master/left%204%20fix/Defib_Fix/scripting/Defib_Fix.sp
int ConvertToInternalCharacter(int SurvivorCharacterType) {
	switch (SurvivorCharacterType) {
		case 4:
			return 0;

		case 5:
			return 1;

		case 6:
			return 3;

		case 7:
			return 2;

		case 9:
			return 8;
	}

	return SurvivorCharacterType;
}

void ReEquipWeapons(int client) {
	if (!IsPlayerAlive(client))
		return;

	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon <= MaxClients)
		return;

	char active[32];
	GetEntityClassname(weapon, active, sizeof active);

	char cls[32];
	for (int i; i <= 1; i++) {
		weapon = GetPlayerWeaponSlot(client, i);
		if (weapon <= MaxClients)
			continue;

		switch (i) {
			case 0: {
				GetEntityClassname(weapon, cls, sizeof cls);

				int clip1 = GetEntProp(weapon, Prop_Send, "m_iClip1");
				int ammo = GetOrSetPlayerAmmo(client, weapon);
				int upgrade = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
				int upgradeAmmo = GetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
				int weaponSkin = GetEntProp(weapon, Prop_Send, "m_nSkin");

				RemovePlayerSlot(client, weapon);
				GivePlayerItem(client, cls);

				weapon = GetPlayerWeaponSlot(client, 0);
				if (weapon > MaxClients) {
					DataPack hPack = new DataPack();//创建数据包.
					RequestFrame(SetWeaponClip1, hPack);//下一帧设置弹夹弹药数量.
					hPack.WriteCell(EntIndexToEntRef(weapon));
					hPack.WriteCell(clip1);
					GetOrSetPlayerAmmo(client, weapon, ammo);

					if (upgrade > 0)
						SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", upgrade);

					if (upgradeAmmo > 0)
						SetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", upgradeAmmo);

					if (weaponSkin > 0)
						SetEntProp(weapon, Prop_Send, "m_nSkin", weaponSkin);
				}
			}

			case 1: {
				int clip1 = -1;
				int weaponSkin;
				bool dualWielding;

				GetEntityClassname(weapon, cls, sizeof cls);
				if (strcmp(cls, "weapon_melee") == 0) {
					GetEntPropString(weapon, Prop_Data, "m_strMapSetScriptName", cls, sizeof cls);
					if (cls[0] == '\0') {
						// 防爆警察掉落的警棍m_strMapSetScriptName为空字符串 (感谢little_froy的提醒)
						char ModelName[128];
						GetEntPropString(weapon, Prop_Data, "m_ModelName", ModelName, sizeof ModelName);
						if (strcmp(ModelName, "models/weapons/melee/v_tonfa.mdl") == 0)
							strcopy(cls, sizeof cls, "tonfa");
					}
				}
				else {
					if (strncmp(cls, "weapon_pistol", 13) == 0 || strcmp(cls, "weapon_chainsaw") == 0)
						clip1 = GetEntProp(weapon, Prop_Send, "m_iClip1");

					dualWielding = strcmp(cls, "weapon_pistol") == 0 && GetEntProp(weapon, Prop_Send, "m_isDualWielding");
				}

				weaponSkin = GetEntProp(weapon, Prop_Send, "m_nSkin");

				RemovePlayerSlot(client, weapon);

				switch (dualWielding) {
					case true: {
						GivePlayerItem(client, "weapon_pistol");
						GivePlayerItem(client, "weapon_pistol");
					}

					case false:
						GivePlayerItem(client, cls);
				}

				weapon = GetPlayerWeaponSlot(client, 1);
				if (weapon > MaxClients) {
					if (clip1 != -1)
					{
						DataPack hPack = new DataPack();//创建数据包.
						RequestFrame(SetWeaponClip1, hPack);//下一帧设置弹夹弹药数量.
						hPack.WriteCell(EntIndexToEntRef(weapon));
						hPack.WriteCell(clip1);
						//SetEntProp(weapon, Prop_Send, "m_iClip1", clip1);
					}
					if (weaponSkin > 0)
						SetEntProp(weapon, Prop_Send, "m_nSkin", weaponSkin);
				}
			}
		}
	}

	FakeClientCommand(client, "use %s", active);
}
//设置弹夹弹药数量.
void SetWeaponClip1(DataPack hPack)
{
	hPack.Reset();
	int weapon = EntRefToEntIndex(hPack.ReadCell());
	int clip1 = hPack.ReadCell();
	if(IsValidEntity(weapon))
		SetEntProp(weapon, Prop_Send, "m_iClip1", clip1);
	delete hPack;
}
int GetOrSetPlayerAmmo(int client, int weapon, int ammo = -1) {
	int m_iPrimaryAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (m_iPrimaryAmmoType != -1) {
		if (ammo != -1)
			SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, m_iPrimaryAmmoType);
		else
			return GetEntProp(client, Prop_Send, "m_iAmmo", _, m_iPrimaryAmmoType);
	}
	return 0;
}

void RemovePlayerSlot(int client, int weapon) {
	RemovePlayerItem(client, weapon);
	RemoveEntity(weapon);
}

void InitGameData() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_pDirector = hGameData.GetAddress("CDirector");
	if (!g_pDirector)
		SetFailState("Failed to find address: \"CDirector\"");

	g_pSavedPlayersCount = hGameData.GetAddress("SavedPlayersCount");
	if (!g_pSavedPlayersCount)
		SetFailState("Failed to find address: \"SavedPlayersCount\"");

	g_pSavedSurvivorBotsCount = hGameData.GetAddress("SavedSurvivorBotsCount");
	if (!g_pSavedSurvivorBotsCount)
		SetFailState("Failed to find address: \"SavedSurvivorBotsCount\"");

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorGameRules::GetMissionInfo"))
		SetFailState("Failed to find signature: \"CTerrorGameRules::GetMissionInfo\"");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if (!(g_hSDK_CTerrorGameRules_GetMissionInfo = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorGameRules::GetMissionInfo\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::IsInTransition"))
		SetFailState("Failed to find signature: \"CDirector::IsInTransition\"");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_CDirector_IsInTransition = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CDirector::IsInTransition\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetInt"))
		SetFailState("Failed to find signature: \"KeyValues::GetInt\"");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_KeyValues_GetInt = EndPrepSDKCall();
	if (!(g_hSDK_KeyValues_GetInt = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"KeyValues::GetInt\"");

	SetupDetours(hGameData);

	delete hGameData;
}

void SetupDetours(GameData hGameData = null) {
	g_ddRestoreTransitionedSurvivorBot = DynamicDetour.FromConf(hGameData, "DD::RestoreTransitionedSurvivorBots");
	if (!g_ddRestoreTransitionedSurvivorBot)
		SetFailState("Failed to create DynamicDetour: \"DD::RestoreTransitionedSurvivorBots\"");

	g_ddInfoChangelevel_ChangeLevelNow = DynamicDetour.FromConf(hGameData, "DD::InfoChangelevel::ChangeLevelNow");
	if (!g_ddInfoChangelevel_ChangeLevelNow)
		SetFailState("Failed to create DynamicDetour: \"DD::InfoChangelevel::ChangeLevelNow\"");
}

MRESReturn DD_RestoreTransitionedSurvivorBot_Pre() {
	g_bRestoringBots = true;
	return MRES_Ignored;
}

MRESReturn DD_RestoreTransitionedSurvivorBot_Post() {
	g_bRestoringBots = false;
	return MRES_Ignored;
}

MRESReturn DD_InfoChangelevel_ChangeLevelNow_Post(Address pThis) {
	g_bTransition = true;
	return MRES_Ignored;
}

public void OnMapEnd() {
	int val;
	if (g_bTransition)
		g_bTransitioned = true;
	else {
		val = -1;
		g_bTransitioned = false;
	}

	for (int i; i <= MaxClients; i++)
		g_iTransitioning[i] = val;

	g_bTransition = false;
	g_bRestoringBots = false;
}

bool PrepRestoreBots() {
	return g_bTransitioned && (g_bRestoringBots || (SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector) && LoadFromAddress(g_pSavedSurvivorBotsCount, NumberType_Int32)));
}

bool PrepTransition() {
	if (!g_bTransitioned)
		return false;

	if (!SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector))
		return false;

	int count = LoadFromAddress(g_pSavedPlayersCount, NumberType_Int32);
	if (!count)
		return false;

	Address kv = view_as<Address>(LoadFromAddress(g_pSavedPlayersCount + view_as<Address>(4), NumberType_Int32));
	if (!kv)
		return false;

	Address ptr;
	for (int i; i < count; i++) {
		ptr = view_as<Address>(LoadFromAddress(kv + view_as<Address>(4 * i), NumberType_Int32));
		if (!ptr)
			continue;

		if (SDKCall(g_hSDK_KeyValues_GetInt, ptr, "teamNumber", 0) != 2)
			continue;

		if (SDKCall(g_hSDK_KeyValues_GetInt, ptr, "restoreState", 0))
			return false;
	}

	return true;
}

bool IsTransitioning(int userid) {
	if (!g_bTransitioned)
		return false;

	if (!SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector))
		return false;

	int count = LoadFromAddress(g_pSavedPlayersCount, NumberType_Int32);
	if (!count)
		return false;

	Address kv = view_as<Address>(LoadFromAddress(g_pSavedPlayersCount + view_as<Address>(4), NumberType_Int32));
	if (!kv)
		return false;

	Address ptr;
	for (int i; i < count; i++) {
		ptr = view_as<Address>(LoadFromAddress(kv + view_as<Address>(4 * i), NumberType_Int32));
		if (!ptr)
			continue;

		if (SDKCall(g_hSDK_KeyValues_GetInt, ptr, "userID", 0) != userid)
			continue;

		if (SDKCall(g_hSDK_KeyValues_GetInt, ptr, "teamNumber", 0) != 2)
			continue;

		if (!SDKCall(g_hSDK_KeyValues_GetInt, ptr, "restoreState", 0))
			return true;
	}

	return false;
}
