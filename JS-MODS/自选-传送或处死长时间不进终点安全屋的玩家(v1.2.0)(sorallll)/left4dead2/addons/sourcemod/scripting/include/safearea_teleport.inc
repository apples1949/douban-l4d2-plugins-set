#if defined _Evilsafearea_teleport
 #endinput
#endif
#define _Evilsafearea_teleport

public SharedPlugin __pl_safearea_teleport = 
{
	name = "safearea_teleport",
	file = "safearea_teleport.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_DropMoney_SetNTVOptional()
{}
#endif

/**
 * 玩家离开终点区域时.
 *
 * @param client          玩家索引.
 *
 * @noreturn
 */
//forward void OnSafeareaEnd(int client);

/**
 * 玩家进入终点区域时.
 *
 * @param client          玩家索引.
 *
 * @noreturn
 */
//forward void OnSafeareaStart(int client);

/**
 * 启动终点处死或传送倒计时时调用.
 *
 * @noreturn
 */
forward void OnSafeareaTeleport();