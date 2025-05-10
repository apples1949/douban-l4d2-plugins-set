/*
*	https://forums.alliedmods.net/showthread.php?t=336287
*/

#if defined _transition_restore_fix_included
#endinput
#endif
#define _transition_restore_fix_included

/**
*	@需要 transition_restore_fix 插件此转发才有用.
*	
*	游戏原生 "PlayerSaveData::Restore" 还原函数不准.
*
*	@param	pThis		游戏原生数据包.
*	@param	client	    开始还原的玩家.
*	@no return
*/
forward void OnPlayerSaveDataRestoreFix_Pre(Address pThis, int client);

/**
*	@需要 transition_restore_fix 插件此转发才有用.
*	
*	游戏原生 "PlayerSaveData::Restore" 还原函数不准.
*
*	@param	pThis		游戏原生数据包.
*	@param	client	    完成还原的玩家.
*	@no return
*/
forward void OnPlayerSaveDataRestoreFix_Post(Address pThis, int client);

public SharedPlugin __pl_transition_restore_fix  =
{
    name = "transition_restore_fix",
    file = "transition_restore_fix.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
