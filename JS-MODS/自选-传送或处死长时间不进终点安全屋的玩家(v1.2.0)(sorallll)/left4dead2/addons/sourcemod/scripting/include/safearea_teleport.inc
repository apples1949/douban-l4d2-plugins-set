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
 * 启动终点处死或传送倒计时时调用.
 *
 * @noreturn
 */
forward void OnSafeareaTeleport();