/*有很多代码嫖至superversus.sp*/
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define GAMEDATA 		"l4d2_multislots"

#define TEAM_SPECTATOR	1
#define TEAM_SURVIVOR	2
#define TEAM_INFECTED   3
#define TEAM_PASSING	4

#define PLUGIN_VERSION	"1.0.2"
#define CVAR_FLAGS		FCVAR_NOTIFY

#define NAME_RoundRespawn "CTerrorPlayer::RoundRespawn"
#define SIG_RoundRespawn_LINUX "@_ZN13CTerrorPlayer12RoundRespawnEv"
#define SIG_RoundRespawn_WINDOWS "\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\x84\\x2A\\x75\\x2A\\x8B\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\xC6\\x86"

#define NAME_SetHumanSpectator "SurvivorBot::SetHumanSpectator"
#define SIG_SetHumanSpectator_LINUX "@_ZN11SurvivorBot17SetHumanSpectatorEP13CTerrorPlayer"
#define SIG_SetHumanSpectator_WINDOWS "\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x83\\xBE\\x2A\\x2A\\x2A\\x2A\\x2A\\x7E\\x2A\\x32\\x2A\\x5E\\x5D\\xC2\\x2A\\x2A\\x8B\\x0D"

#define NAME_TakeOverBot "CTerrorPlayer::TakeOverBot"
#define SIG_TakeOverBot_LINUX "@_ZN13CTerrorPlayer11TakeOverBotEb"
#define SIG_TakeOverBot_WINDOWS "\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x53\\x56\\x8D"

ConVar g_hSLimit;
int    g_iGive0, g_iGive1, g_iGive2, g_iGive3, g_iGive4, g_iGive5;
ConVar g_hGive0, g_hGive1, g_hGive2, g_hGive3, g_hGive4, g_hGive5;
int    g_iAway, g_iKick, g_iSset, g_iMaxs, g_iLimit, g_iTeam;
ConVar g_hAway, g_hKick, g_hSset, g_hMaxs, g_hLimit, g_hTeam;

int g_iMaxplayers;

bool bMaxplayers, g_bRoundStarted, gbVehicleLeaving, gbFirstItemPickedUp;
bool PlayerWentAFK[MAXPLAYERS+1], MenuFunc_SpecNext[MAXPLAYERS+1];
Handle g_TimerSpecCheck, g_hBotsUpdateTimer;
Handle hRoundRespawn, hTakeOverBot, hSetHumanSpec;
Handle ClientTimer_Index[MAXPLAYERS+1], hJoinsSurvivor[MAXPLAYERS+1];
int g_iBotPlayer[MAXPLAYERS+1], ClientSpawnMaxTimer[MAXPLAYERS+1], iDelayedValidationStatus[MAXPLAYERS+1];

Address g_pStatsCondition;

public Plugin myinfo = 
{
	name 		= "L4D2 MultiSlots",
	author 		= "SwiftReal, MI 5 | 修改:豆瓣酱な",
	description 	= "战役多人插件.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	char GameName[64];
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrContains(GameName, "left4dead", false) == -1)
		return APLRes_Failure; 
	
	return APLRes_Success; 
}

public void OnPluginStart()
{
	IsLoadGameCFG();
	
	CreateConVar("l4d_multislots_version", PLUGIN_VERSION, "多人插件的版本.(注意:由于三方图可能限制某种近战刷出,请安装解除限制的插件)", CVAR_FLAGS|FCVAR_SPONLY|FCVAR_REPLICATED);
	SetConVarString(FindConVar("l4d_multislots_version"), PLUGIN_VERSION);
	
	RegConsoleCmd("sm_afk", GoAwayFromKeyboard, "幸存者快速休息指令.");
	RegConsoleCmd("sm_away", GoAFK, "幸存者强制加入旁观者.");
	RegConsoleCmd("sm_jg", JoinTeam_Type, "加入幸存者.");
	RegConsoleCmd("sm_join", JoinTeam_Type, "加入幸存者.");
	
	RegConsoleCmd("sm_addbot", AddBot, "管理员添加电脑幸存者.");
	RegConsoleCmd("sm_sset", Command_sset, "更改服务器人数.");
	RegConsoleCmd("sm_kb", Command_kickbot, "踢出所有电脑幸存者.");
	
	g_hSLimit	= FindConVar("survivor_limit");
	g_hGive0	= CreateConVar("l4d2_multislots_Survivor_spawn0",		"1",	"启用给予玩家武器和物品. 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hGive1	= CreateConVar("l4d2_multislots_Survivor_spawn1",		"1",	"启用给予主武器. 0=禁用, 1=启用(随机获得:冲锋枪,消音冲锋枪).", CVAR_FLAGS);
	g_hGive2	= CreateConVar("l4d2_multislots_Survivor_spawn2",		"1",	"启用给予副武器. 0=禁用, 1=启用(随机获得:小手枪,马格南,斧头), 2=斧头.", CVAR_FLAGS);
	g_hGive3	= CreateConVar("l4d2_multislots_Survivor_spawn3",		"0",	"启用给予投掷武器. 0=禁用, 1=启用(随机获得:胆汁罐,燃烧瓶,土制炸弹).", CVAR_FLAGS);
	g_hGive4	= CreateConVar("l4d2_multislots_Survivor_spawn4",		"0",	"启用给予医疗物品. 0=禁用, 1=启用(随机获得:电击器,医疗包).", CVAR_FLAGS);
	g_hGive5	= CreateConVar("l4d2_multislots_Survivor_spawn5",		"0",	"启用给予急救物品. 0=禁用, 1=启用(随机获得:止痛药,肾上腺素).", CVAR_FLAGS);
	g_hAway		= CreateConVar("l4d2_multislots_enabled_away",			"2",	"启用指令 !away 强制加入旁观者. 0=禁用, 1=启用(公共), 2=启用(只限管理员).", CVAR_FLAGS);
	g_hKick		= CreateConVar("l4d2_multislots_enabled_kick",			"1",	"启用指令 !kb 踢出所有电脑幸存者(包括闲置玩家的电脑幸存者). 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hLimit	= CreateConVar("l4d2_multislots_enabled_sv_Limit",		"4",	"设置开局时的幸存者数量(注意:幸存者+感染者最大不能超过31).", CVAR_FLAGS);
	g_hSset		= CreateConVar("l4d2_multislots_enabled_sv_Sset",		"1",	"启用指令 !sset 设置服务器人数. 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hMaxs		= CreateConVar("l4d2_multislots_enabled_sv_maxs",		"8",	"设置服务器的默认最大人数(本地服务器最大人数为:8).", CVAR_FLAGS);
	g_hTeam		= CreateConVar("l4d2_multislots_enabled_player_team",	"1",	"启用玩家转换队伍提示? 0=禁用 1=启用.", CVAR_FLAGS);
	
	g_hSLimit.Flags &= ~FCVAR_NOTIFY; //移除ConVar变动提示
	g_hSLimit.SetBounds(ConVarBound_Upper, true, 31.0);
	
	g_hGive0.AddChangeHook(IsOtherConVarChanged);
	g_hGive1.AddChangeHook(IsOtherConVarChanged);
	g_hGive2.AddChangeHook(IsOtherConVarChanged);
	g_hGive3.AddChangeHook(IsOtherConVarChanged);
	g_hGive4.AddChangeHook(IsOtherConVarChanged);
	g_hGive5.AddChangeHook(IsOtherConVarChanged);
	
	g_hAway.AddChangeHook(IsOtherConVarChanged);
	g_hKick.AddChangeHook(IsOtherConVarChanged);
	g_hSset.AddChangeHook(IsOtherConVarChanged);
	g_hMaxs.AddChangeHook(IsOtherConVarChanged);
	g_hTeam.AddChangeHook(IsOtherConVarChanged);
	g_hLimit.AddChangeHook(IsOtherConVarChanged);
	
	HookEvent("item_pickup", Event_ItemPickup);//玩家拾取武器或物品.
	HookEvent("round_start", Event_RoundStart);//回合开始.
	HookEvent("round_end", Event_RoundEnd);//回合结束.
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving, EventHookMode_Pre);//救援离开.
	HookEvent("player_connect", Event_Playerconnect);//玩家连接.
	HookEvent("player_disconnect", Event_Playerdisconnect, EventHookMode_Pre);//玩家离开.
	HookEvent("player_team", Event_PlayerTeam);//玩家转换队伍.
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	//玩家在旁观者按鼠标右键自动加入幸存者.
	AddCommandListener(CommandListener_SpecPrev, "spec_prev");
	//禁用游戏自带的闲置提示.
	HookUserMessage(GetUserMessageId("TextMsg"), TextMsg, true);

	AutoExecConfig(true, "l4d2_multislots");
}

public void OnConfigsExecuted()
{
	IsLoadGameCFG();
	IsGetOtherCvars();
}

/// 初始化
public void IsLoadGameCFG()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	
	//判断是否有文件
	if (FileExists(sPath))
	{
		GameData hGameData = new GameData(GAMEDATA);

		if (!hGameData)
			SetFailState("无法加载 \"%s.txt\" gamedata.", GAMEDATA);

		StartPrepSDKCall(SDKCall_Player);
		if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::RoundRespawn") == false)
			SetFailState("[提示] 找不到 Signature: \"RoundRespawn\"签名.");
		else
		{
			hRoundRespawn = EndPrepSDKCall();
			if (hRoundRespawn == null)
				SetFailState("[提示] 创建 SDKCall: \"RoundRespawn\" 失败.");
		}
			
		StartPrepSDKCall(SDKCall_Player);
		if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "SurvivorBot::SetHumanSpectator") == false)
			SetFailState("[提示] 找不到 Signature: \"SetHumanSpec\"签名.");
		else
		{
			PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
			hSetHumanSpec = EndPrepSDKCall();
			if (hSetHumanSpec == null)
				SetFailState("[提示] 创建 SDKCall: \"SetHumanSpec\" 失败.");
		}
		
		StartPrepSDKCall(SDKCall_Player);
		if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::TakeOverBot") == false)
			SetFailState("[提示] 找不到 Signature: \"TakeOverBot\"签名.");
		else
		{
			PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
			hTakeOverBot = EndPrepSDKCall();
			if (hTakeOverBot == null)
				SetFailState("[提示] 创建 SDKCall: \"TakeOverBot\" 失败.");
		}

		vInitPatchs(hGameData);
		delete hGameData;
	}
	else
	{
		//在控制台输出。游戏中看不到
		PrintToServer("[提示] 未发现 %s.txt 文件,创建中...", GAMEDATA);
		//签名与偏移文件生成.
		File hFile = OpenFile(sPath, "w", false);
		if (hFile == null)
			SetFailState("[提示] 创建 %s.txt 文件失败.", GAMEDATA);
		
		WriteFileLine(hFile, "\"Games\"");
		WriteFileLine(hFile, "{");

		WriteFileLine(hFile, "	\"left4dead2\"");
		WriteFileLine(hFile, "	{");
		WriteFileLine(hFile, "		\"Signatures\"");
		WriteFileLine(hFile, "		{");
		
		WriteFileLine(hFile, "			\"%s\"", NAME_RoundRespawn);
		WriteFileLine(hFile, "			{");
		WriteFileLine(hFile, "				\"library\"	\"server\"");
		WriteFileLine(hFile, "				\"linux\"	\"%s\"", SIG_RoundRespawn_LINUX);
		WriteFileLine(hFile, "				\"windows\"	\"%s\"", SIG_RoundRespawn_WINDOWS);
		WriteFileLine(hFile, "			}");
		
		WriteFileLine(hFile, "			\"%s\"", NAME_SetHumanSpectator);
		WriteFileLine(hFile, "			{");
		WriteFileLine(hFile, "				\"library\"	\"server\"");
		WriteFileLine(hFile, "				\"linux\"	\"%s\"", SIG_SetHumanSpectator_LINUX);
		WriteFileLine(hFile, "				\"windows\"	\"%s\"", SIG_SetHumanSpectator_WINDOWS);
		WriteFileLine(hFile, "			}");
		
		WriteFileLine(hFile, "			\"%s\"", NAME_TakeOverBot);
		WriteFileLine(hFile, "			{");
		WriteFileLine(hFile, "				\"library\"	\"server\"");
		WriteFileLine(hFile, "				\"linux\"	\"%s\"", SIG_TakeOverBot_LINUX);
		WriteFileLine(hFile, "				\"windows\"	\"%s\"", SIG_TakeOverBot_WINDOWS);
		WriteFileLine(hFile, "			}");
		
		WriteFileLine(hFile, "		}");

		WriteFileLine(hFile, "		\"Offsets\"");
		WriteFileLine(hFile, "		{");
		
		WriteFileLine(hFile, "			\"RoundRespawn_Offset\"");
		WriteFileLine(hFile, "			{");
		WriteFileLine(hFile, "				\"linux\"	\"25\"");
		WriteFileLine(hFile, "				\"windows\"	\"15\"");
		WriteFileLine(hFile, "			}");

		WriteFileLine(hFile, "			\"RoundRespawn_Byte\"");
		WriteFileLine(hFile, "			{");
		WriteFileLine(hFile, "				\"linux\"	\"117\"");
		WriteFileLine(hFile, "				\"windows\"	\"117\"");
		WriteFileLine(hFile, "			}");
		
		WriteFileLine(hFile, "		}");

		WriteFileLine(hFile, "		\"Addresses\"");
		WriteFileLine(hFile, "		{");
		
		WriteFileLine(hFile, "			\"CTerrorPlayer::RoundRespawn\"");
		WriteFileLine(hFile, "			{");
		WriteFileLine(hFile, "				\"linux\"");
		WriteFileLine(hFile, "				{");
		WriteFileLine(hFile, "					\"signature\"	\"CTerrorPlayer::RoundRespawn\"");
		WriteFileLine(hFile, "				}");
		WriteFileLine(hFile, "				\"windows\"");
		WriteFileLine(hFile, "				{");
		WriteFileLine(hFile, "					\"signature\"	\"CTerrorPlayer::RoundRespawn\"");
		WriteFileLine(hFile, "				}");
		WriteFileLine(hFile, "			}");
		
		WriteFileLine(hFile, "		}");

		WriteFileLine(hFile, "	}");
		WriteFileLine(hFile, "}");
		
		delete hFile;
	}
}

void vInitPatchs(GameData hGameData = null)
{
	int iOffset = hGameData.GetOffset("RoundRespawn_Offset");
	if(iOffset == -1)
		SetFailState("Failed to find offset: RoundRespawn_Offset");

	int iByteMatch = hGameData.GetOffset("RoundRespawn_Byte");
	if(iByteMatch == -1)
		SetFailState("Failed to find byte: RoundRespawn_Byte");

	g_pStatsCondition = hGameData.GetAddress("CTerrorPlayer::RoundRespawn");
	if(!g_pStatsCondition)
		SetFailState("Failed to find address: CTerrorPlayer::RoundRespawn");
	
	g_pStatsCondition += view_as<Address>(iOffset);
	
	int iByteOrigin = LoadFromAddress(g_pStatsCondition, NumberType_Int8);
	if(iByteOrigin != iByteMatch)
		SetFailState("Failed to load 'CTerrorPlayer::RoundRespawn', byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, iByteOrigin, iByteMatch);
}

void vRoundRespawn(int client)
{
	vStatsConditionPatch(true);
	SDKCall(hRoundRespawn, client);
	vStatsConditionPatch(false);
	TeleportClient(client);//复活电脑幸存者后传送.
}

void vStatsConditionPatch(bool bPatch)
{
	static bool bPatched;
	if(!bPatched && bPatch)
	{
		bPatched = true;
		StoreToAddress(g_pStatsCondition, 0x79, NumberType_Int8);
	}
	else if(bPatched && !bPatch)
	{
		bPatched = false;
		StoreToAddress(g_pStatsCondition, 0x75, NumberType_Int8);
	}
}

public void OnMapStart()
{
	g_bRoundStarted = true;
	gbFirstItemPickedUp = false;
	
	ServerCommand("exec banned_user.cfg");//加载服务器封禁列表.
	
	SetConVarInt(FindConVar("sv_consistency"), 0);//关闭服务器的一致性检查(普通战役服建议设置关闭)? 0=关闭, 1=开启.
	SetConVarInt(FindConVar("z_spawn_flow_limit"), 50000);
	
	//修复女巫模型没预载而引起的游戏闪退,必备.
	if (!IsModelPrecached("models/infected/witch.mdl")) 				PrecacheModel("models/infected/witch.mdl", false);
	if (!IsModelPrecached("models/infected/witch_bride.mdl")) 			PrecacheModel("models/infected/witch_bride.mdl", false);
	
	//修复幸存者模型没预载而引起的游戏闪退,必备.
	if (!IsModelPrecached("models/survivors/survivor_teenangst.mdl"))	PrecacheModel("models/survivors/survivor_teenangst.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_biker.mdl"))		PrecacheModel("models/survivors/survivor_biker.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_manager.mdl"))		PrecacheModel("models/survivors/survivor_manager.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_namvet.mdl"))		PrecacheModel("models/survivors/survivor_namvet.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_gambler.mdl"))		PrecacheModel("models/survivors/survivor_gambler.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_coach.mdl"))		PrecacheModel("models/survivors/survivor_coach.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_mechanic.mdl"))	PrecacheModel("models/survivors/survivor_mechanic.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_producer.mdl"))	PrecacheModel("models/survivors/survivor_producer.mdl", false);
}

//地图结束.
public void OnMapEnd()
{
	StopTimers();
	Iskilltimer();
	
	g_bRoundStarted = false;
	gbVehicleLeaving = false;
	gbFirstItemPickedUp = false;
}

public void IsOtherConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsGetOtherCvars();
}

void IsGetOtherCvars()
{
	g_iGive0 = g_hGive0.IntValue;
	g_iGive1 = g_hGive1.IntValue;
	g_iGive2 = g_hGive2.IntValue;
	g_iGive3 = g_hGive3.IntValue;
	g_iGive4 = g_hGive4.IntValue;
	g_iGive5 = g_hGive5.IntValue;
	
	g_iAway	= g_hAway.IntValue;
	g_iKick	= g_hKick.IntValue;
	g_iSset	= g_hSset.IntValue;
	g_iMaxs	= g_hMaxs.IntValue;
	g_iTeam	= g_hTeam.IntValue;
	g_hSLimit.IntValue = g_iLimit = g_hLimit.IntValue;
	
	if (g_iMaxs < 1)
		g_iMaxs = 1;

	if (g_iMaxs > 8 && !IsDedicatedServer())
		g_iMaxs = 8;
	
	SetConVarInt(FindConVar("sv_maxplayers"), !bMaxplayers ? g_iMaxs : g_iMaxplayers, false, false);
	SetConVarInt(FindConVar("sv_visiblemaxplayers"), !bMaxplayers ? g_iMaxs : g_iMaxplayers, false, false);
}

void Iskilltimer()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		delete hJoinsSurvivor[i];
		delete ClientTimer_Index[i];
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(g_iGive0 != 0 && g_iGive0 == 1)
	{
		if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_SURVIVOR)
		{	
			if (GetEntProp(client, Prop_Send, "m_isIncapacitated") == 0)
			{
				int slot1 = GetPlayerWeaponSlot(client, 1);
					
				if (IsValidEdict(slot1))
				{
					char classname[128];
					GetEntityClassname(slot1, classname, sizeof(classname));
				
					if(StrEqual(classname, "weapon_pistol"))
					{
						StripWeapons(client);
						GiveWeapon(client);
					}
				}
			}
		}
	}
}

void GiveWeapon(int client)
{
	switch(g_iGive2)
	{
		case 1:
		{
			l4d2_GiveWeapon_pistol_2(client);
		}
		case 2:
		{
			BypassAndExecuteCommand(client, "give", "fireaxe");//斧头.
		}
	}
	switch(g_iGive3)
	{
		case 1:
		{
			l4d2_GiveWeapon_pistol_3(client);
		}
	}
	switch(g_iGive4)
	{
		case 1:
		{
			l4d2_GiveWeapon_pistol_4(client);
		}
	}
	switch(g_iGive5)
	{
		case 1:
		{
			l4d2_GiveWeapon_pistol_5(client);
		}
	}
	switch(g_iGive1)
	{
		case 1:
		{
			l4d2_GiveWeapon_pistol_1(client);
		}
	}
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int oldteam = event.GetInt("oldteam");
	int iTeam = event.GetInt("team");
	
	if(client > 0 && !IsFakeClient(client))
	{
		if(oldteam == 2 && iTeam != 2)
			RequestFrame(l4d2_kick_SurvivorBot);

		if(g_iTeam != 0 && g_iTeam == 1)
		{
			switch(iTeam)
			{
				case 1:
					PrintToChatAll("\x04[提示]\x03%N\x05加入了观察者.", client);
				case 2:
					PrintToChatAll("\x04[提示]\x03%N\x05加入了幸存者.", client);
				case 3:
					PrintToChatAll("\x04[提示]\x03%N\x05加入了感染者.", client);
			}
		}
	}
}

public Action JoinTeam_Type(int client, int args)
{
	if (IsClientInGame(client) && !IsFakeClient(client))
	{
		int iTeam = GetClientTeam(client);

		switch(iTeam)
		{
			case 1:
			{
				if (iGetBotOfIdle(client))
					PrintHintText(client, "请按下鼠标左键加入幸存者.");
				else
				{
					if(ClientTimer_Index[client] == null)
					{
						ClientSpawnMaxTimer[client] = 1;
						DataPack hPack;
						ClientTimer_Index[client] = CreateDataTimer(1.0, CheckClientState, hPack, TIMER_REPEAT);
						hPack.WriteCell(GetClientUserId(client));
						hPack.WriteCell(true);
					}
				}
			}
			case 2:
			{
				if(DispatchKeyValue(client, "classname", "player") == true)
					PrintHintText(client, "[提示] 你已经加入了幸存者.");
			}
		}
	}
	return Plugin_Handled;
}

public Action CheckClientState(Handle Timer, DataPack hPack)
{
	hPack.Reset();
	int client = GetClientOfUserId(hPack.ReadCell());
	bool ClientTakeOverBot = hPack.ReadCell();
	{
		if(!IsClientInGame(client))
			return Plugin_Continue;
		
		if(TotalFreeBots() > 0)
		{
			int bot = FindBotToTakeOver();
			
			if (bot <= 0)
				IsGetTakeOverTarget();
			
			if (ClientTakeOverBot)
				TakeOverBot(client, true);//更改为 true 则自动加入幸存者,反之是闲置状态.
			else
				TakeOverBot(client, false);//更改为 true 则自动加入幸存者,反之是闲置状态.
			ClientSpawnMaxTimer[client] = 0;
		}
		if(!client || ClientSpawnMaxTimer[client] >= 60 || !IsClientConnected(client) || !ClientSpawnMaxTimer[client] || (GetClientTeam(client) == 1 && iGetBotOfIdle(client)))
		{
			ClientSpawnMaxTimer[client] = 0;
			ClientTimer_Index[client] = null;
			return Plugin_Stop;
		}
		
		ClientSpawnMaxTimer[client]++;

		if(TotalFreeBots() <= 0)
			vSpawnFakeSurvivorClient();
	}
	return Plugin_Continue;
}

void IsGetTakeOverTarget()
{
	int iTakget = GetTakeOverTarget();
	
	if(iTakget != -1)
	{
		//如果玩家加入时电脑幸存者是死亡的则复活.
		if(!IsAlive(iTakget))
			vRoundRespawn(iTakget);//如果电脑幸存者是死亡的则复活.
	}
}

int GetTakeOverTarget()
{
	int iAlive, iDeath;
	int[] iAliveBots = new int[MaxClients];
	int[] iDeathBots = new int[MaxClients];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && !iHasIdlePlayer(i))
		{
			if(IsPlayerAlive(i))
				iAliveBots[iAlive++] = i;
			else
				iDeathBots[iDeath++] = i;
		}
	}
	return (iAlive == 0) ? (iDeath == 0 ? -1 : iDeathBots[GetRandomInt(0, iDeath - 1)]) : iAliveBots[GetRandomInt(0, iAlive - 1)];
}

void TakeOverBot(int client, bool completely)
{
	if (!IsClientInGame(client))
		return;
	if (GetClientTeam(client) == 2)
		return;
	if (IsFakeClient(client))
		return;
	
	int bot = FindBotToTakeOver();
	
	if (bot==0)
	{
		PrintHintText(client, "[提示] 目前没有存活的电脑接管.");
		return;
	}
	
	if(completely)
	{
		SDKCall(hSetHumanSpec, bot, client);
		SDKCall(hTakeOverBot, client, true);
	}
	else
	{
		SDKCall(hSetHumanSpec, bot, client);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
	}
	return;
}

//玩家离开.
public void OnClientDisconnect(int client)
{
	PlayerWentAFK[client] = false;
}

//开局提示.
public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client))
		return;

	//延迟五秒验证玩家队伍.
	IsPlayerJoinsVerificationStatus(client);
		
	if(g_bRoundStarted == true)
	{
		delete g_hBotsUpdateTimer;
		g_hBotsUpdateTimer = CreateTimer(1.0, Timer_BotsUpdate);
	}
}

void IsPlayerJoinsVerificationStatus(int client)
{
	delete hJoinsSurvivor[client];
	iDelayedValidationStatus[client] = 0;
	hJoinsSurvivor[client] = CreateTimer(1.0, iPlayerJoinsSurvivor, GetClientUserId(client), TIMER_REPEAT);
}

public Action iPlayerJoinsSurvivor(Handle timer, any client)
{
	if((client = GetClientOfUserId(client)))
	{
		if(!IsClientInGame(client))
			return Plugin_Continue;

		iDelayedValidationStatus[client] += 1;
		
		if (iDelayedValidationStatus[client] <= 5)
		{
			if (GetClientTeam(client) == 1)
			{
				if (!iGetBotOfIdle(client))
				{
					if (!iGetBotOfIdle(client))
					{
						if(ClientTimer_Index[client] == null)
						{
							ClientSpawnMaxTimer[client] = 1;
							DataPack hPack;
							ClientTimer_Index[client] = CreateDataTimer(1.0, CheckClientState, hPack, TIMER_REPEAT);
							hPack.WriteCell(GetClientUserId(client));
							hPack.WriteCell(false);
						}
					}
				}
			}
		}
		else
		{
			iDelayedValidationStatus[client] = 0;
			hJoinsSurvivor[client] = null;
			return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}

//玩家连接.
public void Event_Playerconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(client > 0 && !IsFakeClient(client))
		MenuFunc_SpecNext[client] = false;
}

//玩家离开.
public void Event_Playerdisconnect(Event event, const char[] name, bool dontBroadcast)
{
	//禁用游戏自带的玩家离开提示.
	SetEventBroadcast(event, true);

	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(client > 0 && !IsFakeClient(client))
	{
		delete hJoinsSurvivor[client];
		delete ClientTimer_Index[client];
		RequestFrame(l4d2_kick_SurvivorBot);
	}
}

//回合结束.
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	StopTimers();
	Iskilltimer();
	
	g_bRoundStarted = false;
	gbFirstItemPickedUp = false;
}

//回合开始.
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundStarted = true;
}

public Action Timer_BotsUpdate(Handle timer)
{
	g_hBotsUpdateTimer = null;

	if(AreAllInGame() == true)
		vSpawnCheck();
	else
		g_hBotsUpdateTimer = CreateTimer(1.0, Timer_BotsUpdate);

	return Plugin_Continue;
}

//检查所有玩家是否加载完成.
bool AreAllInGame()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsClientInGame(i) && !IsFakeClient(i))
			return false;
	}
	return true;
}

void vSpawnCheck()
{
	if(g_bRoundStarted == false)
		return;

	int iSurvivor		= iGetTeamPlayers(TEAM_SURVIVOR, true);
	int iHumanSurvivor	= iGetTeamPlayers(TEAM_SURVIVOR, false);
	int iSurvivorLimit	= g_iLimit;
	int iSurvivorMax	= iHumanSurvivor > iSurvivorLimit ? iHumanSurvivor : iSurvivorLimit;

	if(iSurvivor > iSurvivorMax)
		PrintToConsoleAll("Kicking %d bot(s)", iSurvivor - iSurvivorMax);

	if(iSurvivor < iSurvivorLimit)
		PrintToConsoleAll("Spawning %d bot(s)", iSurvivorLimit - iSurvivor);

	for(; iSurvivorMax < iSurvivor; iSurvivorMax++)
		vKickUnusedSurvivorBot();
	
	for(; iSurvivor < iSurvivorLimit; iSurvivor++)
		vSpawnFakeSurvivorClient();
}

static int iGetTeamPlayers(int team, bool bIncludeBots)
{
	static int i;
	static int iPlayers;

	iPlayers = 0;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == team)
		{
			if(!bIncludeBots && IsFakeClient(i) && !iHasIdlePlayer(i))
				continue;

			iPlayers++;
		}
	}
	return iPlayers;
}

int iGetBotOfIdle(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && (iHasIdlePlayer(i) == client))
			return i;
	}
	return 0;
}

static int iHasIdlePlayer(int client)
{
	char sNetClass[64];
	if(!GetEntityNetClass(client, sNetClass, sizeof(sNetClass)))
		return 0;

	if(FindSendPropInfo(sNetClass, "m_humanSpectatorUserID") < 1)
		return 0;

	client = GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));			
	if(client && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SPECTATOR)
		return client;

	return 0;
}

void vKickUnusedSurvivorBot()
{
	int client = iGetAnyValidSurvivorBot();
	if(client)
	{
		StripWeapons(client);
		KickClient(client, "[提示] 自动踢出多余电脑");
	}
}

int iGetAnyValidSurvivorBot()
{
	int iSurvivor, iHasPlayer, iNotPlayer;
	int[] iHasPlayerBots = new int[MaxClients];
	int[] iNotPlayerBots = new int[MaxClients];
	for(int i = MaxClients; i >= 1; i--)
	{
		if(bIsValidSurvivorBot(i))
		{
			if((iSurvivor = GetClientOfUserId(g_iBotPlayer[i])) && IsClientInGame(iSurvivor) && !IsFakeClient(iSurvivor) && GetClientTeam(iSurvivor) != 2)
				iHasPlayerBots[iHasPlayer++] = i;
			else
				iNotPlayerBots[iNotPlayer++] = i;
		}
	}
	return (iNotPlayer == 0) ? (iHasPlayer == 0 ? 0 : iHasPlayerBots[0]) : iNotPlayerBots[0];
}

bool bIsValidSurvivorBot(int client)
{
	return IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR && !iHasIdlePlayer(client);
}

public Action AddBot(int client, int args)
{
	if(bCheckClientAccess(client))
	{
		if (TotalSurvivors() < l4d2_GetPlayerCount())
		{
			vSpawnFakeSurvivorClient();
			PrintToChat(client, "\x04[提示]\x05添加电脑成功.");
		}
		else
		{
			if (TotalSurvivors() < g_iLimit)
			{
				vSpawnFakeSurvivorClient();
				PrintToChat(client, "\x04[提示]\x05添加电脑成功.");
			}
			else
			{
				PrintToChat(client, "\x04[提示]\x05当前无需添加电脑.");
			}
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

int l4d2_GetPlayerCount()
{
	int intt = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
			intt++;
	
	return intt;
}

public void Event_ItemPickup(Event event, const char[] name, bool dontBroadcast)
{
	if(!gbFirstItemPickedUp)
	{
		if(g_TimerSpecCheck == INVALID_HANDLE)
			g_TimerSpecCheck = CreateTimer(15.0, Timer_SpecCheck, _, TIMER_REPEAT);
		
		gbFirstItemPickedUp = true;
	}
}

public Action Timer_SpecCheck(Handle timer)
{
	if(gbVehicleLeaving)
	{
		g_TimerSpecCheck = null;
		return Plugin_Stop;
	}
	
	for (int i = 1; i <= MaxClients; i++)
		if(IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
			if(GetClientTeam(i) == 1 && !iGetBotOfIdle(i))
			{
				char PlayerName[32];
				GetClientName(i, PlayerName, sizeof(PlayerName));
				if(l4d2_gamemode()!=2)
					if(!MenuFunc_SpecNext[i])
						PrintToChat(i, "\x04[提示]\x03%s\x04,\x05输入\x03!jg\x05或\x03!join\x05或\x03按鼠标右键\x05加入幸存者.", PlayerName);
					else
						PrintToChat(i, "\x04[提示]\x03%s\x04,\x05聊天窗输入\x03!jg\x05或\x03!join\x05加入幸存者.", PlayerName);
			}
		
	return Plugin_Continue;
}

//救援离开时.
public void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast)
{
	int entity = FindEntityByClassname(MaxClients + 1, "info_survivor_position");
	if(entity != INVALID_ENT_REFERENCE)
	{
		int iPlayer;
		float vOrigin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);
		for(int i = 1; i <= MaxClients; i++)
		{
			if(iPlayer++ < 4)
				continue;

			if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
			{
				entity = CreateEntityByName("info_survivor_position");
				DispatchSpawn(entity);
				TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
	StopTimers();
	gbVehicleLeaving = true;
}

void StopTimers()
{
	delete g_TimerSpecCheck;
}

void BypassAndExecuteCommand(int client, char[] strCommand, char[] strParam1)
{
	int flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}

int FindBotToTakeOver()
{
	for (int i = 1; i <= MaxClients; i++)
		if(IsClientConnected(i) && IsClientInGame(i))
				if (IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsAlive(i) && !iHasIdlePlayer(i))
					return i;
	return 0;
}

//玩家离开游戏时踢出多余电脑.
void l4d2_kick_SurvivorBot()
{
	//幸存者数量必须大于设置的开局时的幸存者数量.
	if (TotalSurvivors() > g_iLimit)
		for (int i =1; i <= MaxClients; i++)
			if (IsClientConnected(i) && IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR)
				if (!HasIdlePlayer(i))
				{
					StripWeapons(i);
					KickClient(i, "[提示] 自动踢出多余电脑");
					break;
				}
}

bool HasIdlePlayer(int bot)
{
	if(IsValidEntity(bot))
	{
		char sNetClass[12];
		GetEntityNetClass(bot, sNetClass, sizeof(sNetClass));

		if( strcmp(sNetClass, "SurvivorBot") == 0 )
		{
			if( !GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID") )
				return false;

			int client = GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID"));
			if(client)
			{
				if(IsClientInGame(client) && !IsFakeClient(client) && (GetClientTeam(client) != TEAM_SURVIVOR))
					return true;
			}
			else return false;
		}
	}
	return false;
}

int TotalSurvivors()
{
	int intt = 0;
	for (int i = 1; i <= MaxClients; i++)
		if(IsClientConnected(i))
			if(IsClientInGame(i) && (GetClientTeam(i) == TEAM_SURVIVOR))
				intt++;
	return intt;
}

int TotalFreeBots()
{
	int intt = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidEntity(i))continue;
		if(IsClientConnected(i) && IsClientInGame(i))
			if(IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR)
				if(!iHasIdlePlayer(i))
					intt++;
	}
	return intt;
}

void vSpawnFakeSurvivorClient()
{
	int client = CreateFakeClient("FakeClient");
	if(client == 0)
		return;

	ChangeClientTeam(client, TEAM_SURVIVOR);

	if(DispatchKeyValue(client, "classname", "SurvivorBot") == false)
		return;

	if(DispatchSpawn(client) == false)
		return;

	if(!IsAlive(client))
		vRoundRespawn(client);//如果创建的电脑幸存者是死亡的则复活.
	else
		TeleportClient(client);//如果创建的电脑幸存者是存活的则传送.
		
	if(g_iGive0 != 0 && g_iGive0 == 1)
	{
		StripWeapons(client);
		GiveWeapon(client);
	}
	
	//创建电脑幸存者后传送.
	TeleportClient(client);

	KickClient(client, "[提示] 自动踢出电脑.");
}

//随机传送新加入的幸存者到其他幸存者身边.
void TeleportClient(int client)
{
	int iTarget = GetTeleportTarget(client);
	
	if(iTarget != -1)
	{
		//传送时强制蹲下防止卡住.
		ForceCrouch(client);
		
		float vPos[3];
		GetClientAbsOrigin(iTarget, vPos);
		TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
	}
}

int GetTeleportTarget(int client)
{
	int iNormal, iIncap, iHanging;
	int[] iNormalSurvivors = new int[MaxClients];
	int[] iIncapSurvivors = new int[MaxClients];
	int[] iHangingSurvivors = new int[MaxClients];
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsAlive(i))
		{
			if(GetEntProp(i, Prop_Send, "m_isIncapacitated") > 0)
			{
				if(GetEntProp(i, Prop_Send, "m_isHangingFromLedge") > 0)
					iHangingSurvivors[iHanging++] = i;
				else
					iIncapSurvivors[iIncap++] = i;
			}
			else
				iNormalSurvivors[iNormal++] = i;
		}
	}
	return (iNormal == 0) ? (iIncap == 0 ? (iHanging == 0 ? -1 : iHangingSurvivors[GetRandomInt(0, iHanging - 1)]) : iIncapSurvivors[GetRandomInt(0, iIncap - 1)]) :iNormalSurvivors[GetRandomInt(0, iNormal - 1)];
}

void ForceCrouch(int client)
{
	SetEntProp(client, Prop_Send, "m_bDucked", 1);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_DUCKING);
}

//排除死亡的
bool IsAlive(int client)
{
	if(!GetEntProp(client, Prop_Send, "m_lifeState"))
		return true;
	return false;
}

void l4d2_GiveWeapon_pistol_2(int client)
{
	switch(GetRandomInt(0,2))
	{
		case 0:
		{
			BypassAndExecuteCommand(client, "give", "fireaxe");//斧头.
		}
		case 1:
		{
			BypassAndExecuteCommand(client, "give", "pistol");//小手枪
		}
		case 2:
		{
			BypassAndExecuteCommand(client, "give", "pistol_magnum");//马格南
		}
	}
}

void l4d2_GiveWeapon_pistol_3(int client)
{
	switch(GetRandomInt(0,2))
	{
		case 0:
		{
			BypassAndExecuteCommand(client, "give", "pipe_bomb");//土制炸弹
		}
		case 1:
		{
			BypassAndExecuteCommand(client, "give", "molotov ");//燃烧瓶
		}
		case 2:
		{
			BypassAndExecuteCommand(client, "give", "vomitjar");//胆汁
		}
	}
}

void l4d2_GiveWeapon_pistol_4(int client)
{
	switch(GetRandomInt(0,1))
	{
		case 0:
		{
			BypassAndExecuteCommand(client, "give", "first_aid_kit");//医疗包
		}
		case 1:
		{
			BypassAndExecuteCommand(client, "give", "defibrillator");//电击器
		}
	}
}

void l4d2_GiveWeapon_pistol_5(int client)
{
	switch(GetRandomInt(0,1))
	{
		case 0:
		{
			BypassAndExecuteCommand(client, "give", "adrenaline");//肾上腺素
		}
		case 1:
		{
			BypassAndExecuteCommand(client, "give", "pain_pills");//止痛药
		}
	}
}

void l4d2_GiveWeapon_pistol_1(int client)
{
	switch(GetRandomInt(0,1))
	{
		case 0:
		{
			BypassAndExecuteCommand(client, "give", "smg");//冲锋枪
		}
		case 1:
		{
			BypassAndExecuteCommand(client, "give", "smg_silenced");//消声器冲锋枪
		}
	}	
}

public Action GoAFK(int client, int args)
{ 
	switch(g_iAway)
	{
		case 0:
			PrintToChat(client, "\x04[提示]\x05加入旁观者指令已禁用,请在CFG中设为1启用.");
		case 1,2:
		{
			if(GetClientTeam(client) == 1)
				PrintToChat(client, "\x04[提示]\x05你已经是观察者.");
			else if(GetClientTeam(client) == TEAM_SURVIVOR)
			{
				if(g_iAway == 1)
					ChangeClientTeam(client, 1);
				else if(g_iAway == 2)
				{
					if(bCheckClientAccess(client))
						ChangeClientTeam(client, 1);
					else
						ReplyToCommand(client, "\x04[提示]\x05加入旁观者指令只限管理员使用.");
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action Command_kickbot(int client, int args) 
{
	if(bCheckClientAccess(client))
	{
		switch (g_iKick)
		{
			case 0:
				PrintToChat(client, "\x04[提示]\x05踢出全部电脑幸存者指令已禁用,请在CFG中设为1启用.");
			case 1:
			{
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR)
					{
						StripWeapons(i);
						KickClient(i, "[提示] 指令踢出所有电脑幸存者");
					}
				}
				PrintToChat(client, "\x04[提示]\x05已踢出所有电脑.");//此提示使用指令的玩家可见.
			}
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

public Action Command_sset(int client, int args)
{
	if(bCheckClientAccess(client))
	{
		switch (g_iSset)
		{
			case 0:
				PrintToChat(client, "\x04[提示]\x05设置服务器人数指令已禁用,请在CFG中设为1启用.");
			case 1:
				DisplaySLMenu(client, 0);
		}
	}
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

void DisplaySLMenu(int client, int index)
{
	char namelist[32], nameno[4];
	Menu menu = new Menu(SLMenuHandler);
	menu.SetTitle("设置人数:");
	
	int i = 1;
	int iMax = !IsDedicatedServer() ? 8 : 24;

	while (i <= iMax)
	{
		Format(namelist, sizeof(namelist), "%d", i);
		Format(nameno, sizeof(nameno), "%i", i);
		AddMenuItem(menu, nameno, namelist);
		i++;
	}
	//SetMenuExitButton(menu, true);
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

public int SLMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Select:
		{
			char sInfos[12];
			GetMenuItem(menu, itemNum, sInfos, sizeof(sInfos));
			int g_iUserids = StringToInt(sInfos);
			g_iMaxplayers = g_iUserids;
			bMaxplayers = g_iUserids !=  g_iMaxs ? true : false;
			SetConVarInt(FindConVar("sv_maxplayers"), g_iUserids, false, false);
			SetConVarInt(FindConVar("sv_visiblemaxplayers"), g_iUserids, false, false);
			PrintToChatAll("\x04[提示]\x05更改服务器的最大人数为\x04:\x03%i\x05人.", g_iUserids);
			DisplaySLMenu(client, menu.Selection);
		}
	}
	return 0;
}

public Action OnClientSayCommand(int client, const char[] commnad, const char[] args)
{
	if(strlen(args) <= 1 || strncmp(commnad, "say", 3, false) != 0)
		return Plugin_Continue;

	if (StrEqual(args, "闲置", false) || StrEqual(args, "休息", false))
		RequestFrame(IsFrameGoAwayFromKeyboard, GetClientUserId(client));
	return Plugin_Continue;
}

public Action GoAwayFromKeyboard(int client, int args)
{
	RequestFrame(IsFrameGoAwayFromKeyboard, GetClientUserId(client));
	return Plugin_Handled;
}

void IsFrameGoAwayFromKeyboard(int client)
{
	if ((client = GetClientOfUserId(client)))
	{
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			if (IsPlayerAlive(client) && GetClientTeam(client) == 2)
			{
				if (IsPlayerFallen(client))
					PrintToChat(client,"\x04[提示]\x05倒地时禁止使用休息.");
				else if (IsPlayerFalling(client))
					PrintToChat(client,"\x04[提示]\x05挂边时禁止使用休息.");
				else
				{
					if(IsGoAwayFromKeyboard() > 1)
						FakeClientCommand(client, "go_away_from_keyboard");
					else
						PrintToChat(client,"\x04[提示]\x05人数不足时禁止使用休息.");
				}
			}
			else if(GetClientTeam(client) == 1)
				PrintToChat(client,"\x04[提示]\x05你当前已加入了旁观者.");
			else if(!IsPlayerAlive(client))
				PrintToChat(client,"\x04[提示]\x05死亡状态禁止使用休息.");
			else
				PrintToChat(client,"\x04[提示]\x05只限幸存者使用休息.");
		}
	}
}

int IsGoAwayFromKeyboard()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && !IsFakeClient(i))
			count++;

	return count;
}

void StripWeapons(int client)
{
	int itemIdx;
	for (int x = 0; x <= 4; x++)
	{
		if((itemIdx = GetPlayerWeaponSlot(client, x)) != -1)
		{  
			RemovePlayerItem(client, itemIdx);
			RemoveEdict(itemIdx);
		}
	}
}

//倒地的.
bool IsPlayerFallen(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

//挂边的
bool IsPlayerFalling(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

int l4d2_gamemode()
{
	char gmode[32];
	GetConVarString(FindConVar("mp_gamemode"), gmode, sizeof(gmode));

	if (StrEqual(gmode, "coop", false) || StrEqual(gmode, "realism", false))
		return 1; 
	else if (StrEqual(gmode, "versus", false) || StrEqual(gmode, "teamversus", false))
		return 2;
	if (StrEqual(gmode, "survival", false))
		return 3;
	if (StrEqual(gmode, "scavenge", false) || StrEqual(gmode, "teamscavenge", false))
		return 4; 
	else
		return 0;
}

//玩家在旁观者按鼠标右键自动加入幸存者.
public Action CommandListener_SpecPrev(int client, char[] command, int argc)
{
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 1 || iGetBotOfIdle(client))
		return Plugin_Continue;
	
	MenuFunc_JoinTeam(client);
	return Plugin_Continue;
}

void MenuFunc_JoinTeam(int client)
{
	Menu menu = new Menu(MenuHandler_JoinTeam);

	menu.SetTitle("加入幸存者?");
	menu.AddItem("0", "确定");
	menu.AddItem("1", "取消");

	menu.Display(client, 5);
}

public int MenuHandler_JoinTeam(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sInfos[8];
			GetMenuItem(menu, itemNum, sInfos, sizeof(sInfos));
			int iParam = StringToInt(sInfos);

			if (iParam == 0 && IsValidClient(client) && !IsFakeClient(client) && GetClientTeam(client) == 1 && !iGetBotOfIdle(client))
				JoinTeam_Type(client, false);
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}

//禁用游戏自带的闲置提示.
public Action TextMsg(UserMsg msg_id, Handle bf, int[] players, int playersNum, bool reliable, bool init)
{
	static char sUserMess[96];
	if (GetUserMessageType() == UM_Protobuf)
	{
		PbReadString(bf, "params", sUserMess, sizeof(sUserMess), 0);
	}
	else
	{
		BfReadString(bf, sUserMess, sizeof(sUserMess));
	}

	if (StrContains(sUserMess, "L4D_idle_spectator", false) != -1)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	vTakeOver(GetClientOfUserId(event.GetInt("userid")));
}

void vTakeOver(int bot)
{
	int client;
	if(bot && IsClientInGame(bot) && IsFakeClient(bot) && GetClientTeam(bot) == TEAM_SURVIVOR && (client = iHasIdlePlayer(bot)))
	{
		SDKCall(hSetHumanSpec, bot, client);
		SDKCall(hTakeOverBot, client, true);
	}
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}