#if defined _EvilWitchNumber
 #endinput
#endif
#define _EvilWitchNumber

public SharedPlugin __pl_l4d2_GetWitchNumber = 
{
	name = "l4d2_GetWitchNumber",
	file = "l4d2_GetWitchNumber.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_GetWitchNumber_SetNTVOptional()
{
	MarkNativeAsOptional("GetWitchNumber");
}
#endif

/**
 * 获取自定义的女巫编号.
 *
 * @param iWitchid			传入女巫实体ID.
 *
 * @return				    -1=数组里没有该女巫的索引.
 */
native int GetWitchNumber(int iWitchid);
