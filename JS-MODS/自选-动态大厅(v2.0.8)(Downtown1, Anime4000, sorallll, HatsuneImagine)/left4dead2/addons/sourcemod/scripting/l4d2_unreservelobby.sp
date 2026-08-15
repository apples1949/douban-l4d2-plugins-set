#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_NAME				"L4D 1/2 Remove Lobby Reservation"
#define PLUGIN_AUTHOR			"Downtown1, Anime4000, sorallll, HatsuneImagine"
#define PLUGIN_DESCRIPTION		"Removes lobby reservation when server is full"
#define PLUGIN_VERSION			"2.0.8"
#define PLUGIN_URL				"http://forums.alliedmods.net/showthread.php?t=87759"

ConVar cv_unreserveMode, cv_unreserveTrigger, cv_hibernate, cv_emptyAllowLobby;
int unreserveMode, unreserveTrigger, emptyAllowLobby;
char reservationID[20]; // 重新启用 reservationID
Handle g_hEmptyCheckTimer = null;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	SetConVarInt(FindConVar("sv_reservation_timeout"), 10);
	CreateConVar("l4d_unreserve_version", PLUGIN_VERSION, "插件版本", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	cv_unreserveMode = CreateConVar("l4d_unreserve_mode", "1", "移除大厅保留模式.\n0 = 禁用.\n1 = 人满自动移除保留，有空位自动恢复保留.\n2 = 人满自动移除保留，不再自动恢复保留.", FCVAR_SPONLY|FCVAR_NOTIFY);
	
	cv_unreserveTrigger = CreateConVar("l4d_unreserve_trigger", "0", "触发移除保留的人数阈值. 当玩家数量达到此数值时移除保留.\n-1 = 从服务器内存自动获取大厅槽位数.\n0 = 对抗和清道夫模式为8人，其他模式为4人.\n>0 = 自定义人数.", FCVAR_NOTIFY);
	
	cv_emptyAllowLobby = CreateConVar("l4d_unreserve_empty_allow_lobby", "0", "当服务器变空/重置时，sv_allow_lobby_connect_only 的值.\n0 = 允许任意连接 (推荐: 可解决会话不可用).\n1 = 仅允许大厅匹配连接.", FCVAR_NOTIFY);
	
	cv_hibernate = FindConVar("sv_hibernate_when_empty");

	cv_unreserveMode.AddChangeHook(CvarChanged);
	cv_unreserveTrigger.AddChangeHook(CvarChanged);
	cv_emptyAllowLobby.AddChangeHook(CvarChanged);
	
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	RegAdminCmd("sm_unreserve", cmdUnreserve, ADMFLAG_BAN, "sm_unreserve - 手动强制移除大厅保留");
	RegAdminCmd("sm_reserve", cmdReserve, ADMFLAG_BAN, "sm_reserve - 手动恢复大厅保留");
	RegConsoleCmd("sm_lobby_status", CmdLobbyStatus, "查看当前大厅和服务器状态");

	AutoExecConfig(true, "l4d2_unreservelobby");//生成指定文件名的CFG.

	CreateTimer(60.0, Timer_Heartbeat, _, TIMER_REPEAT);
}

public void OnConfigsExecuted() {
	GetCvars();

	if (IsServerLobbyFull(-1)) {
		LogMessage("[动态大厅] 插件加载: 服务器已满，正在移除大厅匹配...");
		Unreserve();
	}
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	unreserveMode = GetConVarInt(cv_unreserveMode);
	unreserveTrigger = GetConVarInt(cv_unreserveTrigger);
	emptyAllowLobby = GetConVarInt(cv_emptyAllowLobby);
}

Action CmdLobbyStatus(int client, int args) {
	int allow = GetConVarInt(FindConVar("sv_allow_lobby_connect_only"));
	int hibernate = (cv_hibernate != null) ? GetConVarInt(cv_hibernate) : -1;
	// bool isReserved = L4D_LobbyIsReserved(); // 移除废弃函数调用
	
	char sHostingLobby[20];
	GetConVarString(FindConVar("sv_hosting_lobby"), sHostingLobby, sizeof(sHostingLobby));
	
	PrintToConsole(client, "========== [动态大厅状态] ==========");
	PrintToConsole(client, "sv_allow_lobby_connect_only (仅允许大厅连接): %d", allow);
	PrintToConsole(client, "sv_hibernate_when_empty (空服休眠): %d", hibernate);
	// PrintToConsole(client, "L4D_LobbyIsReserved (引擎大厅保留状态): %s", "未知 (函数已禁用)");
	PrintToConsole(client, "sv_hosting_lobby (大厅ID): %s", sHostingLobby);
	PrintToConsole(client, "缓存的 Reservation ID: %s", reservationID[0] ? reservationID : "无");
	PrintToConsole(client, "当前玩家数 (GetConnectedPlayer): %d", GetConnectedPlayer(0));
	PrintToConsole(client, "触发移除保留人数阈值: %d", unreserveTrigger);
	PrintToConsole(client, "====================================");
	
	if (client > 0) ReplyToCommand(client, "[动态大厅] 已在控制台打印当前状态详情。");
	
	return Plugin_Handled;
}


Action cmdUnreserve(int client, int args) {
	LogMessage("[动态大厅] 管理员 %L 手动移除了大厅匹配。", client);
	Unreserve();
	ReplyToCommand(client, "[UL] 大厅匹配已移除 (Lobby reservation has been removed).");
	return Plugin_Handled;
}

Action cmdReserve(int client, int args) {
	LogMessage("[动态大厅] 管理员 %L 手动恢复了大厅匹配。", client);
	Reserve();
	ReplyToCommand(client, "[UL] 大厅匹配已恢复 (Lobby reservation has been restored).");
	return Plugin_Handled;
}

Action Timer_Heartbeat(Handle timer) {
	if (unreserveMode == 0 || unreserveMode == 2)
		return Plugin_Continue;

	if (IsServerLobbyFull(-1)) {
		// LogMessage("[动态大厅] 心跳检测: 服务器已满，准备恢复并重新移除大厅...");
		Reserve();
		CreateTimer(5.0, Timer_Unreserve);
	}

	return Plugin_Continue;
}

Action Timer_Unreserve(Handle timer) {
	// LogMessage("[动态大厅] 延时触发: 正在移除大厅匹配...");
	Unreserve();
	return Plugin_Continue;
}

public void OnClientConnected(int client) {
	if (g_hEmptyCheckTimer != null && !IsFakeClient(client)) {
		LogMessage("[动态大厅] 玩家 %N 连接，取消空服休眠检查。", client);
		KillTimer(g_hEmptyCheckTimer);
		g_hEmptyCheckTimer = null;
		if (cv_hibernate != null) 
		{
			cv_hibernate.SetInt(1);
			LogMessage("[动态大厅] 恢复休眠设置: sv_hibernate_when_empty = 1");
		}
	}

	if (unreserveMode == 0)
		return;

	if (IsFakeClient(client))
		return;

	if (!IsServerLobbyFull(-1))
		return;

	LogMessage("[动态大厅] 玩家连接 (%N)，服务器已满，触发移除大厅匹配。", client);
	Unreserve();
}

//OnClientDisconnect will fired when changing map, issued by gH0sTy at http://docs.sourcemod.net/api/index.php?fastload=show&id=390&
void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	if (unreserveMode == 0 || unreserveMode == 2)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	if (IsFakeClient(client))
		return;

	if (IsServerLobbyFull(client))
		return;

	if (IsServerEmpty(client)) {
		if (g_hEmptyCheckTimer == null) {
			if (cv_hibernate != null) 
			{
				cv_hibernate.SetInt(0);
				LogMessage("[动态大厅] 服务器即将变空: 暂时禁用休眠 (sv_hibernate_when_empty = 0) 并启动10秒检查定时器.");
			}
			g_hEmptyCheckTimer = CreateTimer(10.0, Timer_CheckServerEmpty);
		}
		return;
	}

	// Not full, not empty -> Restore reservation
	LogMessage("[动态大厅] 玩家离开 (%N)，服务器未满且非空，恢复大厅匹配。", client);
	Reserve();
}

Action Timer_CheckServerEmpty(Handle timer) {
	g_hEmptyCheckTimer = null;
	if (cv_hibernate != null) 
	{
		cv_hibernate.SetInt(1);
		LogMessage("[动态大厅] 空服检查结束: 重新启用休眠 (sv_hibernate_when_empty = 1). 当前连接数: %d", GetConnectedPlayer(0));
	}
	
	if (GetConnectedPlayer(0) == 0) {
		LogMessage("[动态大厅] 服务器确认已空，清除缓存的 Lobby ID。");
		// LogMessage("[动态大厅] 重置为任意连接模式 (sv_allow_lobby_connect_only = 0)，防止会话不可用...");
		ClearSavedLobbyId();
	} else {
		LogMessage("[动态大厅] 服务器非空，恢复大厅匹配。");
		Reserve();
	}

	return Plugin_Stop;
}

bool IsServerEmpty(int client) {
	return GetConnectedPlayer(client) == 0;
}

bool IsServerLobbyFull(int client) {
	int slots;

	if (unreserveTrigger < 0)
		slots = LoadFromAddress(L4D_GetPointer(POINTER_SERVER) + view_as<Address>(L4D_GetServerOS() ? 380 : 384), NumberType_Int32);
	else if (unreserveTrigger == 0)
		slots = L4D_IsVersusMode() || L4D2_IsScavengeMode() ? 8 : 4;
	else
		slots = unreserveTrigger;

	return GetConnectedPlayer(client) >= slots;
}

int GetConnectedPlayer(int client) {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientConnected(i) && !IsFakeClient(i))
			count++;
	}
	return count;
}

void Unreserve() {
	// Use sv_hosting_lobby CVar instead of deprecated/missing natives
	ConVar hHostingLobby = FindConVar("sv_hosting_lobby");
	if (hHostingLobby != null) {
		char sLobbyID[20];
		hHostingLobby.GetString(sLobbyID, sizeof(sLobbyID));
		
		// If ID is valid and not "0", save it
		if (sLobbyID[0] != '\0' && !StrEqual(sLobbyID, "0")) {
			strcopy(reservationID, sizeof(reservationID), sLobbyID);
			LogMessage("[动态大厅] 检测到大厅保留 (sv_hosting_lobby: %s)，已缓存 ID。", reservationID);
		}
	}

	// L4D_LobbyUnreserve(); // Use native if available, or just set cvar
	if (hHostingLobby != null) {
		hHostingLobby.SetString("0"); // Force unreserve via CVar
	}
	L4D_LobbyUnreserve(); // Double tap with native just in case
	
	LogMessage("[动态大厅] 已移除大厅保留状态。");
	SetAllowLobby(0);
}

void Reserve() {
	// Restore reservation if we have a valid ID
	if (reservationID[0] != '\0' && !StrEqual(reservationID, "0")) {
		ConVar hHostingLobby = FindConVar("sv_hosting_lobby");
		if (hHostingLobby != null) {
			char currentID[20];
			hHostingLobby.GetString(currentID, sizeof(currentID));
			
			// Only restore if currently unreserved
			if (currentID[0] == '\0' || StrEqual(currentID, "0")) {
				hHostingLobby.SetString(reservationID);
				LogMessage("[动态大厅] 已恢复大厅保留 ID: %s", reservationID);
			}
		}
	} else {
		LogMessage("[动态大厅] 没有缓存的有效大厅 ID，无法恢复。");
	}

	// SetAllowLobby(1);
	ServerCommand("heartbeat"); // Force heartbeat to master server
}

void ClearSavedLobbyId() {
	reservationID = "";
	// SetAllowLobby(1);
	// SetAllowLobby(0); // 允许任意连接，防止会话不可用
	
	SetAllowLobby(emptyAllowLobby); // 使用 CVAR 控制的值
	LogMessage("[动态大厅] 根据配置 l4d_unreserve_empty_allow_lobby = %d 重置连接权限.", emptyAllowLobby);
}

void SetAllowLobby(int value) {
	ConVar cvar = FindConVar("sv_allow_lobby_connect_only");
	if (cvar != null) {
		int oldValue = cvar.IntValue;
		if (oldValue != value) {
			cvar.SetInt(value);
			LogMessage("[动态大厅] 修改 sv_allow_lobby_connect_only: %d -> %d", oldValue, value);
		}
	}
}
