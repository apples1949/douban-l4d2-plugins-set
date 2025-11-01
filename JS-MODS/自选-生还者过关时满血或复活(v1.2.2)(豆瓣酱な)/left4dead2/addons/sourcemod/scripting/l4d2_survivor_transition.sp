/*
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v1.2.3
 *
 *	1:修复倒地开关变量设置成挂边变量.
 *
 */
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#define PLUGIN_VERSION 	"1.2.3"
#define NAME_RoundRespawn "CTerrorPlayer::RoundRespawn"
#define SIG_RoundRespawn_LINUX "@_ZN13CTerrorPlayer12RoundRespawnEv"
#define SIG_RoundRespawn_WINDOWS "\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\x84\\x2A\\x75\\x2A\\x8B\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\xC6\\x86"

Handle hRoundRespawn;
Address g_pStatsCondition;
bool SurvivorsHealth, SurvivorsDefaults = false;

int    g_iEnabled, g_iDefaults, g_iIsStand, g_iIsDeath, g_iHanging, g_iGround;
ConVar g_hEnabled, g_hDefaults, g_hIsStand, g_hIsDeath, g_hHanging, g_hGround;

public Plugin myinfo =
{
	name = "l4d2_survivor_transition",
	author = "豆瓣酱な", 
	description = "生还者过关时自动满血或复活.",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public void OnPluginStart() 
{
	IsLoadGameCFG();
	
	RegConsoleCmd("sm_hp", Command_ResetSurvivor, "生还者过关时自动满血或复活.");
	
	g_hEnabled		= CreateConVar("l4d2_survivor_transition_Enabled",	"1", 	"启用生还者过关时自动满血或复活? 0=禁用, 1=启用.", FCVAR_NOTIFY);
	g_hDefaults		= CreateConVar("l4d2_survivor_transition_defaults", "1", 	"设置开启或关闭生还者过关满血或复活. 0=关闭, 1=开启.", FCVAR_NOTIFY);
	g_hIsStand		= CreateConVar("l4d2_survivor_transition_IsStand", 	"100", 	"设置站立的生还者过关时有多少血量. 0=忽略(实际血量大于设定值时忽略).", FCVAR_NOTIFY);
	g_hIsDeath		= CreateConVar("l4d2_survivor_transition_IsDeath", 	"80", 	"设置死亡的生还者过关时有多少血量. 0=忽略(实际血量大于设定值时忽略).", FCVAR_NOTIFY);
	g_hHanging		= CreateConVar("l4d2_survivor_transition_Hanging", 	"80", 	"设置挂边的生还者过关时有多少血量. 0=忽略(实际血量大于设定值时忽略).", FCVAR_NOTIFY);
	g_hGround		= CreateConVar("l4d2_survivor_transition_Ground", 	"80", 	"设置倒地的生还者过关时有多少血量. 0=忽略(实际血量大于设定值时忽略).", FCVAR_NOTIFY);
	
	g_hEnabled.AddChangeHook(l4d2survivorsConVarChanged);
	g_hDefaults.AddChangeHook(l4d2survivorsConVarChanged);
	g_hIsStand.AddChangeHook(l4d2survivorsConVarChanged);
	g_hIsDeath.AddChangeHook(l4d2survivorsConVarChanged);
	g_hHanging.AddChangeHook(l4d2survivorsConVarChanged);
	g_hGround.AddChangeHook(l4d2survivorsConVarChanged);
	
	HookEvent("map_transition", Event_ResetSurvivors, EventHookMode_Pre);
	
	AutoExecConfig(true, "l4d2_survivor_transition");//生成指定文件名的CFG.
}

public void OnPluginEnd()
{
	vStatsConditionPatch(false);
}

public void OnMapStart()
{
	l4d2_cvar_survivors();
}

public void l4d2survivorsConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	l4d2_cvar_survivors();
}

void l4d2_cvar_survivors()
{
	g_iEnabled	= g_hEnabled.IntValue;
	g_iDefaults	= g_hDefaults.IntValue;
	g_iIsStand	= g_hIsStand.IntValue;
	g_iIsDeath	= g_hIsDeath.IntValue;
	g_iHanging	= g_hHanging.IntValue;
	g_iGround	= g_hGround.IntValue;
}

public Action Command_ResetSurvivor(int client, int args)
{
	if(bCheckClientAccess(client))
	{
		if (SurvivorsHealth)
		{
			SurvivorsHealth = false;
			SurvivorsDefaults = true;
			PrintToChat(client, "\x04[提示]\x03已关闭\x05生还者过关时自动满血.");
		}
		else
		{
			SurvivorsHealth = true;
			SurvivorsDefaults = true;
			PrintToChat(client, "\x04[提示]\x03已开启\x05生还者过关时自动满血.");
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

public void OnConfigsExecuted()
{
	IsLoadGameCFG();
	
	if(!SurvivorsDefaults)
	{
		switch (g_iDefaults)
		{
			case 0:
				SurvivorsHealth = false;
			case 1:
				SurvivorsHealth = true;
		}
	}
}
public void Event_ResetSurvivors(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iEnabled != 0 && SurvivorsHealth)
		ResetSurvivorsiMaxHealth();
}

stock char[] GetGameMode()
{
	char g_sMode[32];
	GetConVarString(FindConVar("mp_gamemode"), g_sMode, sizeof(g_sMode));
	return g_sMode;
}

void ResetSurvivorsiMaxHealth()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			if (!IsAlive(i))//死亡状态.
				vRoundRespawn(i);//复活玩家.
			else
				IsSurvivoHealth(i);//加满血量.
		}
	}
}

//复活死亡的生还者.
stock void vRoundRespawn(int client)
{
	if(g_iIsDeath > 0)
	{
		vStatsConditionPatch(true);
		SDKCall(hRoundRespawn, client);
		vStatsConditionPatch(false);
		TeleportClient(client);//复活后随机传送到其他幸存者身边.
		SetSurvivoHealth(client, g_iIsDeath);
	}
}
//设置生还者血量.
stock void IsSurvivoHealth(int client)
{
	if (IsPlayerState(client))//正常状态.
	{
		if(g_iIsStand > 0)
		{
			int iHealth = GetClientHealth(client);//获取玩家实血.
			CheatCommand(client, "give", "health");//加满血量.
	
			if (iHealth < g_iIsStand)//总血量大于设置的血量.
				iHealth = g_iIsStand;
			SetSurvivoHealth(client, iHealth);
		}
	}
	else if(IsPlayerFalling(client))//挂边状态.
	{
		if(g_iHanging > 0)
		{
			SetSurvivoHealth(client, g_iHanging);
		}
	}
	else if(IsPlayerFallen(client))//倒地状态.
	{
		if(g_iGround > 0)
		{
			CheatCommand(client, "give", "health");//加满血量.
			SetSurvivoHealth(client, g_iGround);
		}
	}
}
//
stock void ResetSurvivorStatus(int client)
{
	SetEntProp(client, Prop_Send, "m_isGoingToDie", 0);//拉起来后流血到一点血时的移速.
	SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);//取消黑白状态.
	SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);//重置倒地次数.
	StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");//去除黑白心跳声.
}

stock void vStatsConditionPatch(bool bPatch)
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
//设置生还者血量.
stock void SetSurvivoHealth(int client, int value)
{
	if (strcmp(GetGameMode(), "mutation3", false) == 0)//虚血模式
	{
		SetEntityHealth(client, 1);//设置玩家实血.
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", float(value - 1));
	}	
	else
	{
		SetEntityHealth(client, value);//设置玩家实血.
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	}
}

stock void CheatCommand(int client, char[] strCommand, char[] strParam1)
{
	int flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}
//死亡状态.
stock bool IsAlive(int client)
{
	return !GetEntProp(client, Prop_Send, "m_lifeState");
}
//正常状态.
stock bool IsPlayerState(int client)
{
	return !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}
//挂边状态.
stock bool IsPlayerFalling(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}
//倒地状态.
stock bool IsPlayerFallen(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}
//随机传送幸存者到其他幸存者身边.
stock void TeleportClient(int client)
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
//获取可传送的玩家坐标.
stock int GetTeleportTarget(int client)
{
	int iNormal, iIncap, iHanging;
	int[] iNormalSurvivors = new int[MaxClients];
	int[] iIncapSurvivors = new int[MaxClients];
	int[] iHangingSurvivors = new int[MaxClients];
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsAlive(i))
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
//传送时强制蹲下防止卡住.
stock void ForceCrouch(int client)
{
	SetEntProp(client, Prop_Send, "m_bDucked", 1);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_DUCKING);
}
//获取虚血值.
stock int GetPlayerTempHealth(int client)
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
/// 初始化
stock void IsLoadGameCFG()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/l4d2_survivor_transition.txt");
	
	//判断是否有文件
	if (FileExists(sPath))
	{
		GameData hGameData = new GameData("l4d2_survivor_transition");
		if(hGameData == null) 
			SetFailState("Failed to load gamedata/l4d2_survivor_transition.txt");
			
		StartPrepSDKCall(SDKCall_Player);
		if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::RoundRespawn") == false)
			SetFailState("Failed to find signature: CTerrorPlayer::RoundRespawn");
		else
		{
			hRoundRespawn = EndPrepSDKCall();
			if(hRoundRespawn == null)
				SetFailState("Failed to create SDKCall: CTerrorPlayer::RoundRespawn");
		}
		
		vRegisterStatsConditionPatch(hGameData);
		
		delete hGameData;
	}
	else
	{
		//创建偏移文件.
		PrintToServer("[提示] 未发现%s文件,创建中...", sPath);
		File hFile = OpenFile(sPath, "w", false);
	
		hFile.WriteLine("\"Games\"");
		hFile.WriteLine("{");

		hFile.WriteLine("	\"left4dead2\"");
		hFile.WriteLine("	{");
		
		hFile.WriteLine("		\"Addresses\"");
		hFile.WriteLine("		{");
		
		hFile.WriteLine("			\"CTerrorPlayer::RoundRespawn\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"linux\"");
		hFile.WriteLine("				{");
		hFile.WriteLine("					\"signature\"	\"CTerrorPlayer::RoundRespawn\"");
		hFile.WriteLine("				}");
		hFile.WriteLine("				\"windows\"");
		hFile.WriteLine("				{");
		hFile.WriteLine("					\"signature\"	\"CTerrorPlayer::RoundRespawn\"");
		hFile.WriteLine("				}");
		hFile.WriteLine("			}");
		
		hFile.WriteLine("		}");
		
		hFile.WriteLine("		\"Offsets\"");
		hFile.WriteLine("		{");
		
		hFile.WriteLine("			\"RoundRespawn_Offset\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"linux\"	\"25\"");
		hFile.WriteLine("				\"windows\"	\"15\"");
		hFile.WriteLine("			}");
		
		hFile.WriteLine("			\"RoundRespawn_Byte\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"linux\"	\"117\"");
		hFile.WriteLine("				\"windows\"	\"117\"");
		hFile.WriteLine("			}");
		
		hFile.WriteLine("		}");
		
		hFile.WriteLine("		\"Signatures\"");
		hFile.WriteLine("		{");
		
		hFile.WriteLine("			\"%s\"", NAME_RoundRespawn);
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"library\"	\"server\"");
		hFile.WriteLine("				\"linux\"	\"%s\"", SIG_RoundRespawn_LINUX);
		hFile.WriteLine("				\"windows\"	\"%s\"", SIG_RoundRespawn_WINDOWS);
		hFile.WriteLine("			}");
		
		hFile.WriteLine("		}");
			
		hFile.WriteLine("	}");
		hFile.WriteLine("}");
		
		FlushFile(hFile);
		delete hFile;
	}
}

stock void vRegisterStatsConditionPatch(GameData hGameData = null)
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