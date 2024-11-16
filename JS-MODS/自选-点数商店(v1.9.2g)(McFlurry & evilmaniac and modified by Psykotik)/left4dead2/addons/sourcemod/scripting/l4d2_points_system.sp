
/*
 *
 *	v1.9.2c
 *
 *	1:新增成功读取玩家数据的转发Forwards(OnPSDataLoad).
 *	2:新增查询数据读取状态的函数Native(PS_GetDataLoadState)
 *	3:修复数据未成功读取时可以打开购物菜单的问题.
 *	4:旁观者使用指令时增加提示,避免指令使用者陷入混乱.
 *
 *	v1.9.2d
 *
 *	1:新增生还者闲置购物武器或物品.
 *
 *	v1.9.2e
 *
 *	1:生还者闲置了购买武器，杂物等.
 *
 *	v1.9.2f
 *
 *	1:购物菜单新增复购功能,没有购买过物品则不显示,不影响原来的复购指令.
 *	2:修复复购功能不兼容生还者闲置购物.
 *
 *	v1.9.2g
 *
 *	1:修复生还者购买复活时忘记添加传送功能.
 *
 */
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
//#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.9.2"

#define MSGTAG "\x04[PS]\x01"
#define MODULES_SIZE 128

GlobalForward
	g_fwdOnPSLoaded,
	g_fwdOnPSUnloaded,
	g_fwdOnPSDataLoad;

Database
	g_dbSQL;

ArrayList
	g_aModules;

bool
	g_bLateLoad,
	g_bMapStarted,
	g_bSettingAllow,
	g_bWeaponFire[MAXPLAYERS + 1],
	g_bIgnoreAbility[MAXPLAYERS + 1];

//汉化@夏恋灬花火碎片 
enum struct Player {
	char Bought[64];
	char Command[64];
	char AuthId[32];
	
	int ItemCost;
	int KillCount;
	int HurtCount;
	int BoughtCost;
	int ProtectCount;
	int HeadShotCount;
	int PlayerPoints;
	int LeechHealth;

	bool DatabaseLoaded;

	float RealodSpeedUp;
}

Player
	g_ePlayer[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "Points System",
	author = "McFlurry & evilmaniac and modified by Psykotik",
	description = "Customized edition of McFlurry's points system",
	version = PLUGIN_VERSION,
	url = "http://www.evilmania.net"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	CreateNatives();
	GlobalForwards();
	g_bLateLoad = late;
	RegPluginLibrary("ps_natives");
	return APLRes_Success;
}

void CreateNatives() {
	CreateNative("PS_IsSystemEnabled", Native_PS_IsSystemEnabled);
	CreateNative("PS_GetVersion", Native_PS_GetVersion);
	CreateNative("PS_GetPoints", Native_PS_GetPoints);
	CreateNative("PS_SetPoints", Native_PS_SetPoints);
	CreateNative("PS_RemovePoints", Native_PS_RemovePoints);
	CreateNative("PS_GetItem", Native_PS_GetItem);
	CreateNative("PS_SetItem", Native_PS_SetItem);
	CreateNative("PS_GetCost", Native_PS_GetCost);
	CreateNative("PS_SetCost", Native_PS_SetCost);
	CreateNative("PS_GetBought", Native_PS_GetBought);
	CreateNative("PS_SetBought", Native_PS_SetBought);
	CreateNative("PS_GetBoughtCost", Native_PS_GetBoughtCost);
	CreateNative("PS_SetBoughtCost", Native_PS_SetBoughtCost);
	CreateNative("PS_RegisterModule", Native_PS_RegisterModule);
	CreateNative("PS_UnregisterModule", Native_PS_UnregisterModule);
	CreateNative("PS_GetDataLoadState", Native_PS_GetDataLoadState);
}

public void OnAllPluginsLoaded() {
	Call_StartForward(g_fwdOnPSLoaded);
	Call_Finish();
}

public void OnPluginEnd() {
	SQL_SaveAll();
	MultiTargetFilters(false);

	Call_StartForward(g_fwdOnPSUnloaded);
	Call_Finish();
}

void SQL_SaveAll() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i))
			SQL_Save(i);
	}
}

any Native_PS_IsSystemEnabled(Handle plugin, int numParams) {
	return IsModEnabled();
}

any Native_PS_GetVersion(Handle plugin, int numParams) {
	return StringToFloat(PLUGIN_VERSION);
}

any Native_PS_GetPoints(Handle plugin, int numParams) {
	return g_ePlayer[GetNativeCell(1)].PlayerPoints;
}

any Native_PS_SetPoints(Handle plugin, int numParams) {
	g_ePlayer[GetNativeCell(1)].PlayerPoints = GetNativeCell(2);
	return 0;
}

any Native_PS_RemovePoints(Handle plugin, int numParams) {
	RemovePoints(GetNativeCell(1), GetNativeCell(2));
	return 0;
}

any Native_PS_GetItem(Handle plugin, int numParams) {
	SetNativeString(2, g_ePlayer[GetNativeCell(1)].Command, GetNativeCell(3));
	return 0;
}

any Native_PS_SetItem(Handle plugin, int numParams) {
	GetNativeString(2, g_ePlayer[GetNativeCell(1)].Command, sizeof Player::Command);
	return 0;
}

any Native_PS_GetCost(Handle plugin, int numParams) {
	return g_ePlayer[GetNativeCell(1)].ItemCost;
}

any Native_PS_SetCost(Handle plugin, int numParams) {
	g_ePlayer[GetNativeCell(1)].ItemCost = GetNativeCell(2);
	return 0;
}

any Native_PS_GetBought(Handle plugin, int numParams) {
	SetNativeString(2, g_ePlayer[GetNativeCell(1)].Bought, sizeof Player::Bought);
	return 0;
}

any Native_PS_SetBought(Handle plugin, int numParams) {
	GetNativeString(2, g_ePlayer[GetNativeCell(1)].Bought, sizeof Player::Bought);
	return 0;
}

any Native_PS_GetBoughtCost(Handle plugin, int numParams) {
	return g_ePlayer[GetNativeCell(1)].BoughtCost;
}

any Native_PS_SetBoughtCost(Handle plugin, int numParams) {
	g_ePlayer[GetNativeCell(1)].BoughtCost = GetNativeCell(2);
	return 0;
}

any Native_PS_RegisterModule(Handle plugin, int numParams) {
	char sNewModule[MODULES_SIZE];
	GetNativeString(1, sNewModule, MODULES_SIZE);
	if (sNewModule[0] == '\0')
		return false;

	if (g_aModules.FindString(sNewModule) != -1)
		return false;

	g_aModules.PushString(sNewModule);
	return true;
}

any Native_PS_UnregisterModule(Handle plugin, int numParams) {
	char sUnloadModule[MODULES_SIZE];
	GetNativeString(1, sUnloadModule, MODULES_SIZE);
	if (sUnloadModule[0] == '\0')
		return false;

	int iModule = g_aModules.FindString(sUnloadModule);
	if (iModule != -1) {
		g_aModules.Erase(iModule);
		return true;
	}
	return false;
}

any Native_PS_GetDataLoadState(Handle plugin, int numParams) 
{
	return g_ePlayer[GetNativeCell(1)].DatabaseLoaded;
}

bool g_bWeaponHandling;
public void OnLibraryAdded(const char[] name) {
	if (strcmp(name, "WeaponHandling") == 0)
		g_bWeaponHandling = true;
}

public void OnLibraryRemoved(const char[] name) {
	if (strcmp(name, "WeaponHandling") == 0)
		g_bWeaponHandling = false;
}

enum {
	SettingAllow,
	SettingModes,
	SettingModesOff,
	SettingModesTog,
	SettingNotifications,
	SettingKillSpreeNum,
	SettingHeadShotNum,
	SettingTankLimit,
	SettingWitchLimit,
	SettingStartPoints,
	SettingTraitorLimit,
	SettingSurvivorRequired,
	SettingMax
}

enum {
	CategoryWeapon,
	CategoryHealth,
	CategoryUpgrade,
	CategoryTraitor,
	CategorySpecial,
	CategoryMelee,
	CategoryRifle,
	CategorySMG,
	CategorySniper,
	CategoryShotgun,
	CategoryThrowable,
	CategoryMisc,
	CategoryMax
}

enum {
	RewardSKillSpree,
	RewardSHeadShots,
	RewardSKillI,
	RewardSKillTank,
	RewardSKillWitch,
	RewardSCrownWitch,
	RewardSTeamHeal,
	RewardSHealFarm,
	RewardSProtect,
	RewardSTeamRevive,
	RewardSTeamLedge,
	RewardSTeamDefib,
	RewardSBileTank,
	RewardSSoloTank,
	RewardIChokeS,
	RewardIPounceS,
	RewardIChargeS,
	RewardIImpactS,
	RewardIRideS,
	RewardIVomitS,
	RewardIIncapS,
	RewardIHurtS,
	RewardIKillS,
	RewardMax
}

enum {
	CostP220,
	CostMagnum,
	CostUZI,
	CostSilenced,
	CostMP5,
	CostM16,
	CostAK47,
	CostSCAR,
	CostSG552,
	CostHunting,
	CostMilitary,
	CostAWP,
	CostScout,
	CostPump,
	CostChrome,
	CostAuto,
	CostSPAS,
	CostGrenade,
	CostM60,
	CostGasCan,
	CostOxygen,
	CostPropane,
	CostGnome,
	CostCola,
	CostFireworks,
	CostFireaxe,
	CostFryingpan,
	CostMachete,
	CostBaseballbat,
	CostCrowbar,
	CostCricketbat,
	CostTonfa,
	CostKatana,
	CostElectricguitar,
	CostKnife,
	CostGolfclub,
	CostShovel,
	CostPitchfork,
	CostCustomMelee,
	CostChainsaw,
	CostPipe,
	CostMolotov,
	CostBile,
	CostHealthKit,
	CostDefib,
	CostAdren,
	CostPills,
	CostExplosiveAmmo,
	CostIncendiaryAmmo,
	CostExplosivePack,
	CostIncendiaryPack,
	CostLaserSight,
	CostAmmo,
	CostHeal,
	Costresurrection,
	CostSuicide,
	CostPZHeal,
	CostSmoker,
	CostBoomer,
	CostHunter,
	CostSpitter,
	CostJockey,
	CostCharger,
	CostWitch,
	CostTank,
	CostTankHealMulti,
	CostHorde,
	CostMob,
	CostTraitor,
	CostMax
}

enum {
	TankSpawned,
	WitchSpawned
}

enum struct General {
	ConVar cGameMode;
	ConVar cSettings[SettingMax];
	ConVar cCategories[CategoryMax];
	ConVar cItemCosts[CostMax];
	ConVar cPointRewards[RewardMax];

	int Counter[2];

	char CurrentMap[64];
}

General
	g_eGeneral;

enum struct Special {
	ConVar cfree_control;
	ConVar cplayer_teleport;
	ConVar cweapon_reload;
	ConVar cLeechHealth[5];
	ConVar cRealodSpeedUp[5];
}

Special
	g_eSpecial;


int
	g_iMeleeCount;

char
	g_sMeleeClass[16][32];

static const char
	g_sMeleeModels[][] = {
		"models/weapons/melee/v_fireaxe.mdl",
		"models/weapons/melee/w_fireaxe.mdl",
		"models/weapons/melee/v_frying_pan.mdl",
		"models/weapons/melee/w_frying_pan.mdl",
		"models/weapons/melee/v_machete.mdl",
		"models/weapons/melee/w_machete.mdl",
		"models/weapons/melee/v_bat.mdl",
		"models/weapons/melee/w_bat.mdl",
		"models/weapons/melee/v_crowbar.mdl",
		"models/weapons/melee/w_crowbar.mdl",
		"models/weapons/melee/v_cricket_bat.mdl",
		"models/weapons/melee/w_cricket_bat.mdl",
		"models/weapons/melee/v_tonfa.mdl",
		"models/weapons/melee/w_tonfa.mdl",
		"models/weapons/melee/v_katana.mdl",
		"models/weapons/melee/w_katana.mdl",
		"models/weapons/melee/v_electric_guitar.mdl",
		"models/weapons/melee/w_electric_guitar.mdl",
		"models/v_models/v_knife_t.mdl",
		"models/w_models/weapons/w_knife_t.mdl",
		"models/weapons/melee/v_golfclub.mdl",
		"models/weapons/melee/w_golfclub.mdl",
		"models/weapons/melee/v_shovel.mdl",
		"models/weapons/melee/w_shovel.mdl",
		"models/weapons/melee/v_pitchfork.mdl",
		"models/weapons/melee/w_pitchfork.mdl",
		"models/weapons/melee/v_riotshield.mdl",
		"models/weapons/melee/w_riotshield.mdl"
	},
	g_sMeleeName[][] = {
		"fireaxe",			//斧头
		"frying_pan",		//平底锅
		"machete",			//砍刀
		"baseball_bat",		//棒球棒
		"crowbar",			//撬棍
		"cricket_bat",		//球拍
		"tonfa",			//警棍
		"katana",			//武士刀
		"electric_guitar",	//吉他
		"knife",			//小刀
		"golfclub",			//高尔夫球棍
		"shovel",			//铁铲
		"pitchfork",		//草叉
	};

void InitSettings() {
	CreateConVar("em_points_sys_version", PLUGIN_VERSION, "积分系统版本.", FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_REPLICATED);

	g_eGeneral.cSettings[SettingAllow] 				= CreateConVar("l4d2_points_allow", "1", "0=禁用插件, 1=启用插件.");
	g_eGeneral.cSettings[SettingModes] 				= CreateConVar("l4d2_points_modes", "", "在这些游戏模式下打开插件,用逗号分隔(无空格).(留空=全部).");
	g_eGeneral.cSettings[SettingModesOff] 			= CreateConVar("l4d2_points_modes_off", "", "在这些游戏模式下关闭插件,用逗号分隔(无空格).(留空=无).");
	g_eGeneral.cSettings[SettingModesTog] 			= CreateConVar("l4d2_points_modes_tog", "0", "在这些游戏模式下打开插件. 0=全部, 1=合作社, 2=生存, 4=对战, 8=清道夫.将数字相加.");
	g_eGeneral.cSettings[SettingStartPoints]		= CreateConVar("l4d2_points_start", "200", "玩家初始积分");
	g_eGeneral.cSettings[SettingNotifications]		= CreateConVar("l4d2_points_notify", "0", "开关提示信息?");
	g_eGeneral.cSettings[SettingTankLimit] 			= CreateConVar("l4d2_points_tank_limit", "2", "每回合允许购买多少只坦克");
	g_eGeneral.cSettings[SettingWitchLimit]			= CreateConVar("l4d2_points_witch_limit", "5", "每回合允许购买多少只女巫");
	g_eGeneral.cSettings[SettingKillSpreeNum] 		= CreateConVar("l4d2_points_cikills", "15", "你需要杀多少普通感染者才能获得杀戮赏金");
	g_eGeneral.cSettings[SettingHeadShotNum] 		= CreateConVar("l4d2_points_headshots", "15", "你需要多少次爆头感染者才能获得猎头奖金");
	g_eGeneral.cSettings[SettingTraitorLimit] 		= CreateConVar("l4d2_points_traitor_limit", "2", "允许同时存在多少个被感染者玩家");
	g_eGeneral.cSettings[SettingSurvivorRequired]	= CreateConVar("l4d2_points_survivor_required", "5", "至少需要存在多少名真人生还者才允许购买到感染者团队");

	g_eGeneral.cGameMode = FindConVar("mp_gamemode");
	g_eGeneral.cGameMode.AddChangeHook(CvarChanged_Allow);
	g_eGeneral.cSettings[SettingAllow].AddChangeHook(CvarChanged_Allow);
	g_eGeneral.cSettings[SettingModes].AddChangeHook(CvarChanged_Allow);
	g_eGeneral.cSettings[SettingModesOff].AddChangeHook(CvarChanged_Allow);
	g_eGeneral.cSettings[SettingModesTog].AddChangeHook(CvarChanged_Allow);
}

void InitCategories() {
	g_eGeneral.cCategories[CategoryWeapon] 		= CreateConVar("l4d2_points_cat_weapons", "1", "启用武器项目购买");
	g_eGeneral.cCategories[CategoryUpgrade] 	= CreateConVar("l4d2_points_cat_upgrades", "1", "启用升级项目购买");
	g_eGeneral.cCategories[CategoryHealth] 		= CreateConVar("l4d2_points_cat_health", "1", "启用生命项目购买");
	g_eGeneral.cCategories[CategoryTraitor]		= CreateConVar("l4d2_points_cat_traitor", "1", "启用内鬼项目购买");
	g_eGeneral.cCategories[CategorySpecial] 	= CreateConVar("l4d2_points_cat_special", "1", "启用特殊项目购买");
	g_eGeneral.cCategories[CategoryMelee]		= CreateConVar("l4d2_points_cat_melee", "1", "启用近战项目购买");
	g_eGeneral.cCategories[CategoryRifle] 		= CreateConVar("l4d2_points_cat_rifles", "1", "启用步枪项目购买");
	g_eGeneral.cCategories[CategorySMG] 		= CreateConVar("l4d2_points_cat_smg", "1", "启用冲锋项目购买");
	g_eGeneral.cCategories[CategorySniper] 		= CreateConVar("l4d2_points_cat_snipers", "1", "启用狙击项目购买");
	g_eGeneral.cCategories[CategoryShotgun] 	= CreateConVar("l4d2_points_cat_shotguns", "1", "启动散弹项目购买");
	g_eGeneral.cCategories[CategoryThrowable]	= CreateConVar("l4d2_points_cat_throwables", "1", "启用投掷项目购买");
	g_eGeneral.cCategories[CategoryMisc] 		= CreateConVar("l4d2_points_cat_misc", "1", "启用杂项项目购买");
}

void InitItemCosts() {
	g_eGeneral.cItemCosts[CostP220]				= CreateConVar("l4d2_points_pistol", "5", "购买小手枪需要多少积分");
	g_eGeneral.cItemCosts[CostMagnum] 			= CreateConVar("l4d2_points_magnum", "10", "购买马格南手枪需要多少积分");
	g_eGeneral.cItemCosts[CostUZI] 				= CreateConVar("l4d2_points_smg", "20", "购买乌兹冲锋枪需要多少积分");
	g_eGeneral.cItemCosts[CostSilenced] 		= CreateConVar("l4d2_points_silenced", "20", "购买消音冲锋枪需要多少积分");
	g_eGeneral.cItemCosts[CostMP5] 				= CreateConVar("l4d2_points_mp5", "20", "购买MP5冲锋枪需要多少积分");
	g_eGeneral.cItemCosts[CostM16] 				= CreateConVar("l4d2_points_m16", "80", "购买M16突击步枪需要多少积分");
	g_eGeneral.cItemCosts[CostAK47] 			= CreateConVar("l4d2_points_ak47", "80", "购买AK47突击步枪需要多少积分");
	g_eGeneral.cItemCosts[CostSCAR] 			= CreateConVar("l4d2_points_scar", "50", "购买SCAR-H突击步枪需要多少积分");
	g_eGeneral.cItemCosts[CostSG552] 			= CreateConVar("l4d2_points_sg552", "30", "购买SG552突击步枪需要多少积分");
	g_eGeneral.cItemCosts[CostMilitary] 		= CreateConVar("l4d2_points_military", "150", "购买30发连发狙击枪需要多少积分");
	g_eGeneral.cItemCosts[CostAWP] 				= CreateConVar("l4d2_points_awp", "500", "购买awp狙击枪需要多少积分");
	g_eGeneral.cItemCosts[CostScout] 			= CreateConVar("l4d2_points_scout", "400", "购买侦察狙击步枪(鸟狙)需要多少积分");
	g_eGeneral.cItemCosts[CostHunting] 			= CreateConVar("l4d2_points_hunting", "80", "购买狩猎狙击步枪(猎枪)需要多少积分");
	g_eGeneral.cItemCosts[CostPump] 			= CreateConVar("l4d2_points_pump", "25", "购买一代木喷需要多少积分");
	g_eGeneral.cItemCosts[CostChrome] 			= CreateConVar("l4d2_points_chrome", "25", "购买二代铁喷需要多少积分");
	g_eGeneral.cItemCosts[CostAuto] 			= CreateConVar("l4d2_points_auto", "120", "购买一代连喷需要多少积分");
	g_eGeneral.cItemCosts[CostSPAS] 			= CreateConVar("l4d2_points_spas", "120", "购买二代连喷需要多少积分");
	g_eGeneral.cItemCosts[CostGrenade] 			= CreateConVar("l4d2_points_grenade", "500", "购买榴弹发射器需要多少积分");
	g_eGeneral.cItemCosts[CostM60] 				= CreateConVar("l4d2_points_m60", "500", "购买M60机枪需要多少积分");
	g_eGeneral.cItemCosts[CostGasCan] 			= CreateConVar("l4d2_points_gascan", "150", "购买汽油桶需要多少积分");
	g_eGeneral.cItemCosts[CostOxygen] 			= CreateConVar("l4d2_points_oxygen", "50", "购买氧气罐需要多少积分");
	g_eGeneral.cItemCosts[CostPropane] 			= CreateConVar("l4d2_points_propane", "50", "购买燃气罐需要多少积分");
	g_eGeneral.cItemCosts[CostGnome] 			= CreateConVar("l4d2_points_gnome", "50", "购买侏儒人偶需要多少积分");
	g_eGeneral.cItemCosts[CostCola] 			= CreateConVar("l4d2_points_cola", "50", "购买可乐瓶需要多少积分");
	g_eGeneral.cItemCosts[CostFireworks] 		= CreateConVar("l4d2_points_fireworks", "50", "购买烟花盒需要多少积分");
	g_eGeneral.cItemCosts[CostFireaxe] 			= CreateConVar("l4d2_points_fireaxe", "55", "购买消防斧需要多少积分");
	g_eGeneral.cItemCosts[CostFryingpan]		= CreateConVar("l4d2_points_fryingpan", "45", "购买平底锅需要多少积分");
	g_eGeneral.cItemCosts[CostMachete] 			= CreateConVar("l4d2_points_machete", "100", "购买小砍刀需要多少积分");
	g_eGeneral.cItemCosts[CostBaseballbat] 		= CreateConVar("l4d2_points_baseballbat", "30", "购买棒球棒需要多少积分");
	g_eGeneral.cItemCosts[CostCrowbar] 			= CreateConVar("l4d2_points_crowbar", "30", "购买撬棍需要多少积分");
	g_eGeneral.cItemCosts[CostCricketbat] 		= CreateConVar("l4d2_points_cricketbat", "30", "购买板球棒需要多少积分");
	g_eGeneral.cItemCosts[CostTonfa] 			= CreateConVar("l4d2_points_tonfa", "35", "购买警棍需要多少积分");
	g_eGeneral.cItemCosts[CostKatana] 			= CreateConVar("l4d2_points_katana", "100", "购买武士刀需要多少积分");
	g_eGeneral.cItemCosts[CostElectricguitar]	= CreateConVar("l4d2_points_electricguitar", "30", "购买电吉他需要多少积分");
	g_eGeneral.cItemCosts[CostKnife] 			= CreateConVar("l4d2_points_knife", "30", "购买小刀需要多少积分");
	g_eGeneral.cItemCosts[CostGolfclub] 		= CreateConVar("l4d2_points_golfclub", "30", "购买高尔夫球棍需要多少积分");
	g_eGeneral.cItemCosts[CostShovel] 			= CreateConVar("l4d2_points_shovel", "25", "购买铁铲需要多少积分");
	g_eGeneral.cItemCosts[CostPitchfork] 		= CreateConVar("l4d2_points_pitchfork", "20", "购买干草叉需要多少积分");
	g_eGeneral.cItemCosts[CostCustomMelee] 		= CreateConVar("l4d2_points_custommelee", "200", "购买自定义近战需要多少积分");
	g_eGeneral.cItemCosts[CostChainsaw] 		= CreateConVar("l4d2_points_chainsaw", "20", "购买电锯需要多少积分");
	g_eGeneral.cItemCosts[CostPipe] 			= CreateConVar("l4d2_points_pipe", "100", "购买土制炸弹需要多少积分");
	g_eGeneral.cItemCosts[CostMolotov] 			= CreateConVar("l4d2_points_molotov", "100", "购买燃烧瓶需要多少积分");
	g_eGeneral.cItemCosts[CostBile] 			= CreateConVar("l4d2_points_bile", "100", "购买胆汁需要多少积分");
	g_eGeneral.cItemCosts[CostHealthKit]		= CreateConVar("l4d2_points_medkit", "80", "购买医疗包需要多少积分");
	g_eGeneral.cItemCosts[CostDefib] 			= CreateConVar("l4d2_points_defib", "20", "购买电击器需要多少积分");
	g_eGeneral.cItemCosts[CostAdren] 			= CreateConVar("l4d2_points_adrenaline", "50", "购买肾上腺素需要多少积分");
	g_eGeneral.cItemCosts[CostPills] 			= CreateConVar("l4d2_points_pills", "50", "购买止痛药需要多少积分");
	g_eGeneral.cItemCosts[CostExplosiveAmmo] 	= CreateConVar("l4d2_points_explosive_ammo", "20", "购买高爆弹药需要多少积分");
	g_eGeneral.cItemCosts[CostIncendiaryAmmo] 	= CreateConVar("l4d2_points_incendiary_ammo", "20", "购买燃烧弹药需要多少积分");
	g_eGeneral.cItemCosts[CostExplosivePack] 	= CreateConVar("l4d2_points_explosive_ammo_pack", "35", "购买高爆弹药包需要多少积分");
	g_eGeneral.cItemCosts[CostIncendiaryPack] 	= CreateConVar("l4d2_points_incendiary_ammo_pack", "35", "购买燃烧弹药包需要多少积分");
	g_eGeneral.cItemCosts[CostLaserSight] 		= CreateConVar("l4d2_points_laser", "25", "购买激光瞄准器需要多少积分");
	g_eGeneral.cItemCosts[CostHeal] 			= CreateConVar("l4d2_points_survivor_heal", "300", "购买回满血量需要多少积分");
	g_eGeneral.cItemCosts[Costresurrection] 	= CreateConVar("l4d2_points_survivor_resurrection", "500", "购买复活需要多少积分");
	
	g_eGeneral.cItemCosts[CostAmmo] 			= CreateConVar("l4d2_points_refill", "35", "购买弹药补充需要多少积分");
	g_eGeneral.cItemCosts[CostSuicide] 			= CreateConVar("l4d2_points_suicide", "20", "特感玩家购买自杀需要多少积分");
	g_eGeneral.cItemCosts[CostPZHeal] 			= CreateConVar("l4d2_points_infected_heal", "250", "感染者治愈自己需要多少积分");
	g_eGeneral.cItemCosts[CostSmoker] 			= CreateConVar("l4d2_points_smoker", "50", "购买一次成为smoker的机会需要多少积分");
	g_eGeneral.cItemCosts[CostBoomer] 			= CreateConVar("l4d2_points_boomer", "50", "购买一次成为boomer的机会需要多少积分");
	g_eGeneral.cItemCosts[CostHunter]			= CreateConVar("l4d2_points_hunter", "50", "购买一次成为hunter的机会需要多少积分");
	g_eGeneral.cItemCosts[CostSpitter] 			= CreateConVar("l4d2_points_spitter", "50", "购买一次成为spitter的机会需要多少积分");
	g_eGeneral.cItemCosts[CostJockey] 			= CreateConVar("l4d2_points_jockey", "50", "购买一次成为jockey的机会需要多少积分");
	g_eGeneral.cItemCosts[CostCharger] 			= CreateConVar("l4d2_points_charger", "80", "购买一次成为charger的机会需要多少积分");
	g_eGeneral.cItemCosts[CostWitch] 			= CreateConVar("l4d2_points_witch", "80", "购买一次witch需要多少积分");
	g_eGeneral.cItemCosts[CostTank] 			= CreateConVar("l4d2_points_tank", "1200", "购买一次成为tank的机会需要多少积分");
	g_eGeneral.cItemCosts[CostTankHealMulti] 	= CreateConVar("l4d2_points_tank_heal_mult", "4", "坦克玩家购买治愈相对于其他特感需要多少倍的积分消耗");
	g_eGeneral.cItemCosts[CostHorde] 			= CreateConVar("l4d2_points_horde", "50", "购买一次horde需要多少积分");
	g_eGeneral.cItemCosts[CostMob] 				= CreateConVar("l4d2_points_mob", "50", "购买一次mob需要多少积分");
	g_eGeneral.cItemCosts[CostTraitor] 			= CreateConVar("l4d2_points_traitor", "50", "购买一个感染者位置需要多少积分");
}

void InitPointRewards() {
	g_eGeneral.cPointRewards[RewardSKillSpree] 	= CreateConVar("l4d2_points_cikill_value", "50", "击杀一定数量的普通感染者可以获得多少积分");
	g_eGeneral.cPointRewards[RewardSHeadShots]	= CreateConVar("l4d2_points_headshots_value", "100", "爆头击杀一定数量的感染者可以获得多少积分");
	g_eGeneral.cPointRewards[RewardSKillI] 		= CreateConVar("l4d2_points_sikill", "5", "击杀一个特感可以获得多少积分");
	g_eGeneral.cPointRewards[RewardSKillTank] 	= CreateConVar("l4d2_points_tankkill", "100", "击杀一只坦克可以获得多少积分");
	g_eGeneral.cPointRewards[RewardSKillWitch] 	= CreateConVar("l4d2_points_witchkill", "50", "击杀一个女巫可以获得多少积分");
	g_eGeneral.cPointRewards[RewardSCrownWitch] = CreateConVar("l4d2_points_witchcrown", "70", "秒杀一个女巫可以获得多少积分");
	g_eGeneral.cPointRewards[RewardSTeamHeal] 	= CreateConVar("l4d2_points_heal", "40", "治疗一个队友可以得到多少积分");
	g_eGeneral.cPointRewards[RewardSHealFarm] 	= CreateConVar("l4d2_points_heal_warning", "0", "治疗一个不需要治疗的队友可以得到多少积分");
	g_eGeneral.cPointRewards[RewardSProtect] 	= CreateConVar("l4d2_points_protect", "2", "保护队友可以得到多少积分");
	g_eGeneral.cPointRewards[RewardSTeamRevive] = CreateConVar("l4d2_points_revive", "5", "拉起一个倒地的队友可以得到多少积分");
	g_eGeneral.cPointRewards[RewardSTeamLedge] 	= CreateConVar("l4d2_points_ledge", "5", "拉起一个挂边的队友可以得到多少积分");
	g_eGeneral.cPointRewards[RewardSTeamDefib] 	= CreateConVar("l4d2_points_defib_action", "100", "电击器复活一个队友可以获得多少积分");
	g_eGeneral.cPointRewards[RewardSSoloTank] 	= CreateConVar("l4d2_points_tanksolo", "10", "单独击杀一只坦克可以获得多少积分");
	g_eGeneral.cPointRewards[RewardSBileTank] 	= CreateConVar("l4d2_points_bile_tank", "2", "投掷胆汁命中坦克可以获得多少积分");
	g_eGeneral.cPointRewards[RewardIChokeS] 	= CreateConVar("l4d2_points_smoke", "2", "smoker舌头拉住生还者可以获得多少积分");
	g_eGeneral.cPointRewards[RewardIPounceS] 	= CreateConVar("l4d2_points_pounce", "2", "hunter扑倒生还者可以获得多少积分");
	g_eGeneral.cPointRewards[RewardIChargeS] 	= CreateConVar("l4d2_points_charge", "2", "charge冲撞生还者可以获得多少积分");
	g_eGeneral.cPointRewards[RewardIImpactS] 	= CreateConVar("l4d2_points_impact", "2", "spitter吐痰生还者可以获得多少积分");
	g_eGeneral.cPointRewards[RewardIRideS] 		= CreateConVar("l4d2_points_ride", "2", "jokey骑乘生还者可以获得多少积分");
	g_eGeneral.cPointRewards[RewardIVomitS] 	= CreateConVar("l4d2_points_boom", "2", "boomer喷吐生还者可以获得多少积分");
	g_eGeneral.cPointRewards[RewardIIncapS] 	= CreateConVar("l4d2_points_incap", "10", "击倒一个生还者可以获得多少积分");
	g_eGeneral.cPointRewards[RewardIHurtS] 		= CreateConVar("l4d2_points_damage", "2", "造成伤害能得到多少积分");
	g_eGeneral.cPointRewards[RewardIKillS] 		= CreateConVar("l4d2_points_kill", "1000", "击杀一个生还者可以获得多少积分");
}

void InitSpecialCosts() {
	g_eSpecial.cLeechHealth[0] 					= CreateConVar("l4d2_points_special_leech0", "10", "购买2生命汲取需要多少积分");
	g_eSpecial.cLeechHealth[1] 					= CreateConVar("l4d2_points_special_leech1", "40", "购买4生命汲取需要多少积分");
	g_eSpecial.cLeechHealth[2] 					= CreateConVar("l4d2_points_special_leech2", "60", "购买6生命汲取需要多少积分");
	g_eSpecial.cLeechHealth[3] 					= CreateConVar("l4d2_points_special_leech3", "80", "购买8生命汲取需要多少积分");
	g_eSpecial.cLeechHealth[4] 					= CreateConVar("l4d2_points_special_leech4", "100", "购买10生命汲取需要多少积分");
	g_eSpecial.cRealodSpeedUp[0] 				= CreateConVar("l4d2_points_special_reload0", "30", "购买1.5x加速装填需要多少积分");
	g_eSpecial.cRealodSpeedUp[1] 				= CreateConVar("l4d2_points_special_reload1", "60", "购买2.0x加速装填需要多少积分");
	g_eSpecial.cRealodSpeedUp[2] 				= CreateConVar("l4d2_points_special_reload2", "100", "购买2.5x加速装填需要多少积分");
	g_eSpecial.cRealodSpeedUp[3] 				= CreateConVar("l4d2_points_special_reload3", "150", "购买3.0x加速装填需要多少积分");
	g_eSpecial.cRealodSpeedUp[4] 				= CreateConVar("l4d2_points_special_reload4", "200", "购买3.5x加速装填需要多少积分");
	g_eSpecial.cfree_control 					= CreateConVar("l4d2_points_free_control", "800", "购买当前章节免控需要多少积分");
	g_eSpecial.cplayer_teleport 				= CreateConVar("l4d2_points_player_teleport", "100", "购买传送自己需要多少积分");
	g_eSpecial.cweapon_reload 					= CreateConVar("l4d2_points_weapon_reload", "800", "购买免换弹夹需要多少积分");
}

void CreateConVars() {
	InitSettings();
	InitCategories();
	InitItemCosts();
	InitPointRewards();
	InitSpecialCosts();
	AutoExecConfig(true, "l4d2_points_system");//生成指定文件名的CFG.
}

void RegisterCommands() {
	RegAdminCmd("sm_heal", cmdHealPlayer, ADMFLAG_SLAY, "sm_heal <目标>给玩家XXX回血");
	RegAdminCmd("sm_delold",	cmdDelOld,	ADMFLAG_ROOT, "sm_delold <天数> 删除超过多少天未上线的玩家记录");
	RegAdminCmd("sm_listpoints", cmdListPoints, ADMFLAG_ROOT, "列出每个玩家的积分数量.");
	RegAdminCmd("sm_setpoints", cmdSetPoints, ADMFLAG_ROOT, "sm_setpoints <目标> [数量]设置玩家XXX拥有XXX数量的积分");
	RegAdminCmd("sm_givepoints", cmdGivePoints, ADMFLAG_ROOT, "sm_givepoints <目标> [数量]给玩家XXX发XXX数量的积分");
	RegAdminCmd("sm_listmodules", cmdListModules, ADMFLAG_GENERIC, "列出当前加载到积分系统的模块");

	RegConsoleCmd("sm_points", cmdShowPoints, "显示个人积分(只能在游戏中)");
	RegConsoleCmd("sm_buy", cmdBuyMenu, "打开购买菜单(只能在游戏中)");
	RegConsoleCmd("sm_shop", cmdBuyMenu, "打开购买菜单(只能在游戏中)");
	RegConsoleCmd("sm_store", cmdBuyMenu, "打开购买菜单(只能在游戏中)");
	RegConsoleCmd("sm_repeatbuy", cmdRepeatBuy, "重复购买上一次购买的物品");
}

void HookEvents(bool hook) {
	switch (hook) {
		case true: {
			HookEvent("round_end", Event_RoundEnd);
			HookEvent("infected_death", Event_InfectedDeath);
			HookEvent("player_incapacitated", Event_PlayerIncapacitated);
			HookEvent("player_death", Event_PlayerDeath);
			HookEvent("tank_killed", Event_TankKilled);
			HookEvent("witch_killed", Event_WitchKilled);
			HookEvent("heal_success", Event_HealSuccess);
			HookEvent("award_earned", Event_AwardEarned);
			HookEvent("revive_success", Event_ReviveSuccess);
			HookEvent("defibrillator_used", Event_DefibrillatorUsed);
			HookEvent("choke_start", Event_ChokeStart);
			HookEvent("player_now_it", Event_PlayerNowIt);
			HookEvent("lunge_pounce", Event_LungePounce);
			HookEvent("jockey_ride", Event_JockeyRide);
			HookEvent("charger_carry_start", Event_ChargerCarryStart);
			HookEvent("charger_impact", Event_ChargerImpact);
			HookEvent("player_hurt", Event_PlayerHurt);
		}

		case false: {
			UnhookEvent("round_end", Event_RoundEnd);
			UnhookEvent("infected_death", Event_InfectedDeath);
			UnhookEvent("player_incapacitated", Event_PlayerIncapacitated);
			UnhookEvent("player_death", Event_PlayerDeath);
			UnhookEvent("tank_killed", Event_TankKilled);
			UnhookEvent("witch_killed", Event_WitchKilled);
			UnhookEvent("heal_success", Event_HealSuccess);
			UnhookEvent("award_earned", Event_AwardEarned);
			UnhookEvent("revive_success", Event_ReviveSuccess);
			UnhookEvent("defibrillator_used", Event_DefibrillatorUsed);
			UnhookEvent("choke_start", Event_ChokeStart);
			UnhookEvent("player_now_it", Event_PlayerNowIt);
			UnhookEvent("lunge_pounce", Event_LungePounce);
			UnhookEvent("jockey_ride", Event_JockeyRide);
			UnhookEvent("charger_carry_start", Event_ChargerCarryStart);
			UnhookEvent("charger_impact", Event_ChargerImpact);
			UnhookEvent("player_hurt", Event_PlayerHurt);
		}
	}
	
}

void _LoadTranslations() {
	LoadTranslations("core.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("points_system.phrases");
	LoadTranslations("points_system_menus.phrases");
}
//创建转发.
void GlobalForwards() 
{
	g_fwdOnPSLoaded = new GlobalForward("OnPSLoaded", ET_Ignore);
	g_fwdOnPSUnloaded = new GlobalForward("OnPSUnloaded", ET_Ignore);
	g_fwdOnPSDataLoad = new GlobalForward("OnPSDataLoad", ET_Event, Param_Cell);//玩家数据读取成功时.
}
public void OnPluginStart() {
	g_aModules = new ArrayList(ByteCountToCells(MODULES_SIZE));

	HookEvent("weapon_fire", Event_WeaponFire);//玩家开火.
	HookEvent("player_disconnect", Event_PlayerDisconnect);//玩家离开.
	
	_LoadTranslations();
	CreateConVars();
	IsAllowed();
	RegisterCommands();
	InitSpecialValue();

	if (!g_dbSQL)
		IniSQLite();

	if (g_bLateLoad)
		SQL_LoadAll();
}
//枪械武器.
char g_sWeaponFirearms[][][] = 
{
	{"小手枪", "weapon_pistol"},
	{"马格南", "weapon_pistol_magnum"},
	{"微型冲锋枪", "weapon_smg"},
	{"MP5冲锋枪", "weapon_smg_mp5"},
	{"消音冲锋枪", "weapon_smg_silenced"},
	{"单发木喷", "weapon_pumpshotgun"},
	{"铁喷木喷", "weapon_shotgun_chrome"},
	{"M16步枪", "weapon_rifle"},
	{"三连发步枪", "weapon_rifle_desert"},
	{"AK47步枪", "weapon_rifle_ak47"},
	{"SG552步枪", "weapon_rifle_sg552"},
	{"一代连喷", "weapon_autoshotgun"},
	{"二代连喷", "weapon_shotgun_spas"},
	{"连发木狙", "weapon_hunting_rifle"},
	{"军用狙击枪", "weapon_sniper_military"},
	{"单发鸟狙", "weapon_sniper_scout"},
	{"AWP大狙", "weapon_sniper_awp"},
	{"M60机关枪", "weapon_rifle_m60"},
	{"榴弹发射器", "weapon_grenade_launcher"}
};
//玩家开火.
public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (IsValidClient(client) && GetClientTeam(client) == 2)
	{
		RequestFrame(IsPlayerWeaponFire, GetClientUserId(client));
	}
}

//玩家开火.
void IsPlayerWeaponFire(int client)
{
	if((client = GetClientOfUserId(client)))
	{
		int iBot = IsClientIdle(client);
		int iWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");

		if(g_bWeaponFire[iBot != 0 ? iBot : client] && IsValidEdict(iWeapon))
		{
			char classname[64];
			GetEntityClassname(iWeapon, classname, sizeof(classname));

			if(GetWeaponFirearms(classname))
			{
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", L4D2_GetIntWeaponAttribute(classname, L4D2IWA_ClipSize));
			}
		}
	}
}
//主武器.
bool GetWeaponFirearms(char[] sName)
{
	for(int i = 0; i < sizeof(g_sWeaponFirearms); i++)
		if(strcmp(sName, g_sWeaponFirearms[i][1]) == 0)
			return true;

	return false;
}
//玩家离开.
public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event,"userid"));
	
	if (client > 0 && !IsFakeClient(client))
	{
		g_ePlayer[client].ItemCost = 0;
		g_ePlayer[client].Command[0] = '\0';
	}
}
void SQL_LoadAll() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			//SetPlayerStartPoints(i);
			SQL_Load(i);
		}
	}
}

void MultiTargetFilters(bool add) {
	switch (add) {
		case true: {
			AddMultiTargetFilter("@s", SurvivorFilter, "all Survivor", false);
			AddMultiTargetFilter("@survivor", SurvivorFilter, "all Survivor", false);
			AddMultiTargetFilter("@i", InfectedFilter, "all Infected", false);
			AddMultiTargetFilter("@infected", InfectedFilter, "all Infected", false);
		}

		case false: {
			RemoveMultiTargetFilter("@s", SurvivorFilter);
			RemoveMultiTargetFilter("@survivor", SurvivorFilter);
			RemoveMultiTargetFilter("@i", InfectedFilter);
			RemoveMultiTargetFilter("@infected", InfectedFilter);
		}
	}
}

bool SurvivorFilter(const char[] pattern, Handle clients) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
			PushArrayCell(clients, i);
	}
	return true;
}

bool InfectedFilter(const char[] pattern, Handle clients) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 3)
			PushArrayCell(clients, i);
	}
	return true;
}

public void OnConfigsExecuted() {
	IsAllowed();
}

void CvarChanged_Allow(ConVar convar, const char[] oldValue, const char[] newValue) {
	IsAllowed();
}

void IsAllowed() {
	bool allow = g_eGeneral.cSettings[SettingAllow].BoolValue;
	bool allowMode = IsAllowedGameMode();

	if (g_bSettingAllow == false && allow == true && allowMode == true) {
		g_bSettingAllow = true;

		MultiTargetFilters(true);
		HookEvents(true);
	}
	else if (g_bSettingAllow == true && (allow == false || allowMode == false)) {
		g_bSettingAllow = false;

		MultiTargetFilters(false);
		HookEvents(false);
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode() {
	if (!g_eGeneral.cGameMode)
		return false;

	int modesTog = g_eGeneral.cSettings[SettingModesTog].IntValue;
	if (modesTog != 0) {
		if (g_bMapStarted == false)
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if (IsValidEntity(entity)) {
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if (IsValidEntity(entity)) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity);// Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}

		if (g_iCurrentMode == 0)
			return false;

		if (!(modesTog & g_iCurrentMode))
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_eGeneral.cGameMode.GetString(sGameMode, sizeof sGameMode);
	Format(sGameMode, sizeof sGameMode, ",%s,", sGameMode);

	g_eGeneral.cSettings[SettingModes].GetString(sGameModes, sizeof sGameModes);
	if (sGameModes[0]) {
		Format(sGameModes, sizeof sGameModes, ",%s,", sGameModes);
		if (StrContains(sGameModes, sGameMode, false) == -1)
			return false;
	}

	g_eGeneral.cSettings[SettingModesOff].GetString(sGameModes, sizeof sGameModes);
	if (sGameModes[0]) {
		Format(sGameModes, sizeof sGameModes, ",%s,", sGameModes);
		if (StrContains(sGameModes, sGameMode, false) != -1)
			return false;
	}

	return true;
}

void OnGamemode(const char[] output, int caller, int activator, float delay) {
	if (strcmp(output, "OnCoop") == 0)
		g_iCurrentMode = 1;
	else if (strcmp(output, "OnSurvival") == 0)
		g_iCurrentMode = 2;
	else if (strcmp(output, "OnVersus") == 0)
		g_iCurrentMode = 4;
	else if (strcmp(output, "OnScavenge") == 0)
		g_iCurrentMode = 8;
}

void IniSQLite() {	
	char sError[1024];
	if (!(g_dbSQL = SQLite_UseDatabase("PointsSystem", sError, sizeof sError)))
		SetFailState("Could not connect to the database \"PointsSystem\" at the following error:\n%s", sError);

	SQL_FastQuery(g_dbSQL, "CREATE TABLE IF NOT EXISTS PS_Core(SteamID NVARCHAR(32) NOT NULL DEFAULT '', Points INT NOT NULL DEFAULT 0, UnixTime INT NOT NULL DEFAULT 0);");
}

Action cmdHealPlayer(int client, int args) {
	if (args == 0) {
		CheatCommandEx(client, "give", "health");
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
		return Plugin_Handled;
	}

	if (args == 1) {
		char arg[65];
		GetCmdArg(1, arg, sizeof arg);
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		if ((target_count = ProcessTargetString(
				arg,
				client,
				target_list,
				MAXPLAYERS,
				COMMAND_FILTER_ALIVE,
				target_name,
				sizeof target_name,
				tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
		else {
			//ShowActivity2(client, MSGTAG, " %t", "Give Health", target_name);

			for (int i; i < target_count; i++) {
				int targetclient = target_list[i];
				CheatCommandEx(targetclient, "give", "health");
				SetEntPropFloat(targetclient, Prop_Send, "m_healthBuffer", 0.0);
			}
			return Plugin_Handled;
		}
	}
	else {
		ReplyToCommand(client, "%s%T", MSGTAG, "Usage sm_heal", client);
		return Plugin_Handled;
	}
}

Action cmdDelOld(int client, int args) {
	if (args < 1) {
		ReplyToCommand(client, "sm_delold <days>");
		return Plugin_Handled;
	}
	
	if (args == 1) {
		if (!g_dbSQL) {
			ReplyToCommand(client, "无效的数据库句柄");
			return Plugin_Handled;
		}

		char sDays[8];
		GetCmdArg(1, sDays, sizeof sDays);
	
		int iUnixTime = GetTime() - (StringToInt(sDays) * 60 * 60 * 24);
	
		char query[1024];
		FormatEx(query, sizeof query, "DELETE FROM PS_Core WHERE UnixTime < %d;", iUnixTime);
		g_dbSQL.Query(SQL_CallbackDelOld, query, GetClientUserId(client));
	}

	return Plugin_Handled;
}

void SQL_CallbackDelOld(Database db, DBResultSet results, const char[] error, any data) {
	if (!db || !results) {
		LogError(error);
		return;
	}

	ReplyToCommand(GetClientOfUserId(data), "总计删除玩家记录: %d 条", results.AffectedRows);
}

Action cmdListPoints(int client, int args) {
	if (args == 0) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && !IsFakeClient(i)) 
				ReplyToCommand(client, "%s %N: %d", MSGTAG, i, g_ePlayer[i].PlayerPoints);
		}
	}
	return Plugin_Handled;
}

Action cmdSetPoints(int client, int args) {
	if (args == 2) {
		char arg[MAX_NAME_LENGTH], arg2[32];
		GetCmdArg(1, arg, sizeof arg);
		GetCmdArg(2, arg2, sizeof arg2);
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		int targetclient, amount = StringToInt(arg2);
		if ((target_count = ProcessTargetString(
				arg,
				client,
				target_list,
				MAXPLAYERS,
				COMMAND_FILTER_NO_BOTS,
				target_name,
				sizeof target_name,
				tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
		//ShowActivity2(client, MSGTAG, "%t", "Set Points", target_name, amount);
		for (int i; i < target_count; i++) {
			targetclient = target_list[i];
			g_ePlayer[targetclient].PlayerPoints = amount;
			SQL_Save(targetclient);
			ReplyToCommand(client, "%s %T", MSGTAG, "Set Points", client, targetclient, amount);
			ReplyToCommand(targetclient, "%s %T", MSGTAG, "Set Target", targetclient, client, amount);
		}
	}
	else
		ReplyToCommand(client, "%s %T", MSGTAG, "Usage sm_setpoints", client, MSGTAG);

	return Plugin_Handled;
}

Action cmdGivePoints(int client, int args) {
	if (args == 2) {
		char arg[MAX_NAME_LENGTH], arg2[32];
		GetCmdArg(1, arg, sizeof arg);
		GetCmdArg(2, arg2, sizeof arg2);
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		int targetclient, amount = StringToInt(arg2);
		if ((target_count = ProcessTargetString(
				arg,
				client,
				target_list,
				MAXPLAYERS,
				COMMAND_FILTER_NO_BOTS,
				target_name,
				sizeof target_name,
				tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
	
		for (int i; i < target_count; i++) {
			targetclient = target_list[i];
			g_ePlayer[targetclient].PlayerPoints += amount;
			SQL_Save(targetclient);
			ReplyToCommand(client, "%s %T", MSGTAG, "Give Points", client, amount, targetclient);
			ReplyToCommand(targetclient, "%s %T", MSGTAG, "Give Target", targetclient, client, amount);
		}
	}
	else
		ReplyToCommand(client, "%s %T", MSGTAG, "Usage sm_givepoints", client);

	return Plugin_Handled;
}

Action cmdListModules(int client, int args) {
	if (args == 0) {
		ReplyToCommand(client, "%s %T", MSGTAG, "Modules", client);

		int iLength = g_aModules.Length;
		for (int i; i < iLength; i++) {
			char sModule[MODULES_SIZE];
			g_aModules.GetString(i, sModule, MODULES_SIZE);
			ReplyToCommand(client, "%d %s", i, sModule);
		}
	}
	return Plugin_Handled;
}

Action cmdShowPoints(int client, int args) {
	if (args || !IsModEnabled())
		return Plugin_Handled;
	if (!g_ePlayer[client].DatabaseLoaded)
	{
		PrintToChat(client, "\x04[提示]\x05你的数据还未读取成功,请稍后再试.");
		return Plugin_Handled;
	}
	if (!IsClientPlaying(client))
	{
		PrintToChat(client, "\x04[提示]\x05旁观者无权使用该指令.");
		return Plugin_Handled;
	}
	ReplyToCommand(client, "%s %T", MSGTAG, "Your Points", client, g_ePlayer[client].PlayerPoints);
	return Plugin_Handled;
}

Action cmdBuyMenu(int client, int args) {
	if (args || !IsModEnabled())
		return Plugin_Handled;
	
	if (!g_ePlayer[client].DatabaseLoaded)
	{
		PrintToChat(client, "\x04[提示]\x05你的数据还未读取成功,请稍后再试.");
		return Plugin_Handled;
	}
	//if (!IsClientPlaying(client))
	//{
	//	PrintToChat(client, "\x04[提示]\x05旁观者无权使用该指令.");
	//	return Plugin_Handled;
	//}
	BuildBuyMenu(client);
	return Plugin_Handled;
}

Action cmdRepeatBuy(int client, int args) {
	if (args)
		return Plugin_Handled;
	if (!g_ePlayer[client].DatabaseLoaded)
	{
		PrintToChat(client, "\x04[提示]\x05你的数据还未读取成功,请稍后再试.");
		return Plugin_Handled;
	}
	if (!CheckPurchase(client, g_ePlayer[client].ItemCost))
	{
		PrintToChat(client, "\x04[提示]\x05你的点数不足,请稍后再试.");
		return Plugin_Handled;
	}
	//if (!IsClientPlaying(client))
	//{
	//	PrintToChat(client, "\x04[提示]\x05旁观者无权使用该指令.");
	//	return Plugin_Handled;
	//}
	int pos;
	char cmd[32], arg[32];
	if ((pos = SplitString(g_ePlayer[client].Command, " ", cmd, sizeof cmd)) == -1)
		strcopy(cmd, sizeof cmd, g_ePlayer[client].Command);
	else {
		strcopy(arg, sizeof arg, g_ePlayer[client].Command[pos]);
		TrimString(arg);
	}

	if (arg[0] == '\0') 
	{
		if (strcmp(cmd, "suicide") == 0)
		{
			if (!PerformSuicide(client))
				return Plugin_Handled;
		}
		else if (strcmp(cmd, "respawn") == 0)
		{
			if (!IsRespawnPlayer(client))
			{
				PrintToChat(client, "\x04[提示]\x05你已是存活状态,复购复活失败.");
				return Plugin_Handled;
			}
		}
	}
	else 
	{
		if (strcmp(arg, "health") == 0) 
		{
			if (!IsPlayerAlive(client))
				return Plugin_Handled;
		}
		else if (strcmp(cmd, "z_spawn_old") == 0) 
		{
			if (strcmp(arg, "tank") == 0) {
				if (ReachedTankLimit(client))
					return Plugin_Handled;
			}
			else if (strncmp(arg, "witch", 5) == 0) {
				if (ReachedWitchLimit(client))
					return Plugin_Handled;
			}

			static StringMap zombieClass;
			if (!zombieClass)
				zombieClass = InitZombieClass(zombieClass);

			int class;
			zombieClass.GetValue(arg, class);
			if (class) {
				L4D_State_Transition(client, STATE_GHOST);
				L4D_SetClass(client, class);
				if (GetEntProp(client, Prop_Send, "m_zombieClass") != class)
					L4D_SetClass(client, class);

				if (!IsPlayerAlive(client) || !GetEntProp(client, Prop_Send, "m_isGhost", 1) || GetEntProp(client, Prop_Send, "m_zombieClass") != class)
					return Plugin_Handled;

				RemovePoints(client, g_ePlayer[client].ItemCost);
			}
			return Plugin_Handled;
		}
		if(cmd[0] != '\0' && arg[0] != '\0')
		{
			switch (GetClientTeam(client)) 
			{
				case 1: 
				{
					int victim = iGetBotOfIdlePlayer(client);
					if(victim != 0)
					{
						CheatCommandEx(victim, cmd, arg);
						RemovePoints(client, g_ePlayer[client].ItemCost);
					}
				}
				case 2,3: 
				{
					if (IsPlayerAlive(client))
					{
						CheatCommandEx(client, cmd, arg);
						RemovePoints(client, g_ePlayer[client].ItemCost);
					}
					else
						PrintToChat(client, "\x04[提示]\x05你已死亡,复购失败.");
				}
			}
		}
		else
		{
			//cmdRepeatBuy(client, 0);
			PrintToChat(client, "\x04[提示]\x05你没有购买过任何物品.");
		}
	}
	return Plugin_Handled;
}

bool IsModEnabled() {
	return g_bSettingAllow;
}

bool IsClientPlaying(int client) {
	return client > 0 && IsClientInGame(client) && GetClientTeam(client) > 1;
}

bool IsRealClient(int client) {
	return IsClientInGame(client) && !IsFakeClient(client);
}

bool IsSur(int client) {
	return GetClientTeam(client) == 2;
}

bool IsInf(int client) {
	return GetClientTeam(client) == 3;
}

bool IsTank(int client) {
	return GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
}

void SetPlayerStartPoints(int client) {
	g_ePlayer[client].PlayerPoints = g_eGeneral.cSettings[SettingStartPoints].IntValue;
}

void AddPoints(int client, int points, const char[] message) {
	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client)) {
		g_ePlayer[client].PlayerPoints += points;
		if (g_eGeneral.cSettings[SettingNotifications].BoolValue)
			PrintToChat(client, "%s %T", MSGTAG, message, client, points);
	}
}

void RemovePoints(int client, int points) {
	g_ePlayer[client].PlayerPoints -= points;
}

public void OnMapEnd() {
	g_bMapStarted = false;
	g_eGeneral.Counter[TankSpawned] = 0;
	g_eGeneral.Counter[WitchSpawned] = 0;
}

public void OnMapStart() {
	g_bMapStarted = true;

	GetCurrentMap(g_eGeneral.CurrentMap, sizeof General::CurrentMap);

	PrecacheModel("models/v_models/v_m60.mdl");
	PrecacheModel("models/w_models/weapons/w_m60.mdl");
	PrecacheModel("models/infected/witch.mdl");
	PrecacheModel("models/infected/witch_bride.mdl");

	int i;
	for (; i < sizeof g_sMeleeModels; i++)
		PrecacheModel(g_sMeleeModels[i], true);

	char buffer[64];
	for (i = 0; i < sizeof g_sMeleeName; i++) {
		FormatEx(buffer, sizeof buffer, "scripts/melee/%s.txt", g_sMeleeName[i]);
		PrecacheGeneric(buffer, true);
	}

	GetMeleeStringTable();
}

void GetMeleeStringTable() {
	int table = FindStringTable("MeleeWeapons");
	g_iMeleeCount = GetStringTableNumStrings(table);

	for (int i; i < g_iMeleeCount; i++)
		ReadStringTable(table, i, g_sMeleeClass[i], sizeof g_sMeleeClass[]);
}

public void OnClientPostAdminCheck(int client) {
	if (IsFakeClient(client))
		return;

	ResetClientData(client);
	//SetPlayerStartPoints(client);
	SQL_Load(client);
}

public void OnClientDisconnect(int client) {
	if (!IsFakeClient(client))
		SQL_Save(client);
}

public void OnClientDisconnect_Post(int client) {
	ResetClientData(client);
	//SetPlayerStartPoints(client);
}

bool CacheSteamID(int client) {
	if (g_ePlayer[client].AuthId[0])
		return true;

	if (GetClientAuthId(client, AuthId_Steam2, g_ePlayer[client].AuthId, sizeof Player::AuthId))
		return true;

	g_ePlayer[client].AuthId[0] = '\0';
	return false;
}

void ResetClientData(int client) {
	g_ePlayer[client].AuthId[0] = '\0';
	g_ePlayer[client].KillCount = 0;
	g_ePlayer[client].HurtCount = 0;
	g_ePlayer[client].ProtectCount = 0;
	g_ePlayer[client].HeadShotCount = 0;
	g_ePlayer[client].LeechHealth = 0;
	g_ePlayer[client].RealodSpeedUp = 1.0;
	g_ePlayer[client].DatabaseLoaded = false;
	g_bWeaponFire[client] = false;//【注释】
	g_bIgnoreAbility[client] = false;//【注释】
}

void SQL_Save(int client) {
	if (!g_dbSQL)
		return;

	if (!g_ePlayer[client].DatabaseLoaded)
		return;

	if (!CacheSteamID(client))
		return;

	char query[1024];
	FormatEx(query, sizeof query, "UPDATE PS_Core SET Points = %d, UnixTime = %d WHERE SteamID = '%s';", g_ePlayer[client].PlayerPoints, GetTime(), g_ePlayer[client].AuthId);
	SQL_FastQuery(g_dbSQL, query);
}

void SQL_Load(int client) {
	if (!g_dbSQL)
		return;

	if (!CacheSteamID(client))
		return;

	char query[1024];
	FormatEx(query, sizeof query, "SELECT * FROM PS_Core WHERE SteamId = '%s';", g_ePlayer[client].AuthId);
	g_dbSQL.Query(SQL_CallbackLoad, query, GetClientUserId(client));
}

void SQL_CallbackLoad(Database db, DBResultSet results, const char[] error, any data) {
	if (!db || !results) {
		LogError(error);
		return;
	}

	int client;
	if (!(client = GetClientOfUserId(data)))
		return;

	if (results.FetchRow())
		g_ePlayer[client].PlayerPoints = results.FetchInt(1);
	else 
	{
		char query[1024];
		SetPlayerStartPoints(client);//给新玩家写入初始点数.
		FormatEx(query, sizeof query, "INSERT INTO PS_Core(SteamID, Points, UnixTime) VALUES ('%s', %d, %d);", g_ePlayer[client].AuthId, g_ePlayer[client].PlayerPoints, GetTime());
		SQL_FastQuery(g_dbSQL, query);
	}

	g_ePlayer[client].DatabaseLoaded = true;

	Call_StartForward(g_fwdOnPSDataLoad);
	Call_PushCell(client);
	Call_Finish();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	g_eGeneral.Counter[TankSpawned] = 0;
	g_eGeneral.Counter[WitchSpawned] = 0;
}

void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsRealClient(attacker) || !IsSur(attacker))
		return;

	if (event.GetBool("headshot"))
		EventHeadShots(attacker);

	int reward = g_eGeneral.cPointRewards[RewardSKillSpree].IntValue;
	if (reward > 0) {
		g_ePlayer[attacker].KillCount++;

		int required = g_eGeneral.cSettings[SettingKillSpreeNum].IntValue;
		if (g_ePlayer[attacker].KillCount >= required) {
			AddPoints(attacker, reward, "Killing Spree");
			g_ePlayer[attacker].KillCount -= required;
		}
	}
}

void Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsRealClient(attacker) || !IsInf(attacker))
		return;

	int incapPoints = g_eGeneral.cPointRewards[RewardIIncapS].IntValue;
	if (incapPoints > 0)
		AddPoints(attacker, incapPoints, "Incapped Survivor");
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsRealClient(attacker))
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	switch (GetClientTeam(attacker)) {
		case 2: {
			if (client && IsInf(client) && !IsTank(client)) {
				if (g_ePlayer[attacker].LeechHealth && !GetEntProp(attacker, Prop_Send, "m_isIncapacitated"))
					SetEntityHealth(attacker, GetClientHealth(attacker) + g_ePlayer[attacker].LeechHealth); 

				if (event.GetBool("headshot"))
					EventHeadShots(attacker);
			
				int reward = g_eGeneral.cPointRewards[RewardSKillI].IntValue;
				if (reward > 0)
					AddPoints(attacker, reward, "Killed SI");
			}
		}

		case 3: {
			if (client && IsSur(client)) {// If the person killed by the infected is a survivor
				int reward = g_eGeneral.cPointRewards[RewardIKillS].IntValue;
				if (reward > 0)
					AddPoints(attacker, reward, "Killed Survivor");
			}
		}
	}
}

void EventHeadShots(int client) {
	int reward = g_eGeneral.cPointRewards[RewardSHeadShots].IntValue;
	if (reward > 0) {
		g_ePlayer[client].HeadShotCount++;

		int required = g_eGeneral.cSettings[SettingHeadShotNum].IntValue;
		if (g_ePlayer[client].HeadShotCount >= required) {
			AddPoints(client, reward, "Head Hunter");
			g_ePlayer[client].HeadShotCount -= required;
		}
	}
}

void Event_TankKilled(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsRealClient(attacker) || !IsSur(attacker))
		return;

	if (event.GetBool("solo")) {
		int reward = g_eGeneral.cPointRewards[RewardSSoloTank].IntValue;
		if (reward > 0)
			AddPoints(attacker, reward, "TANK SOLO");
	}
	else {
		int reward = g_eGeneral.cPointRewards[RewardSKillTank].IntValue;
		if (reward > 0) {
			for (int i = 1; i <= MaxClients; i++) {
				if (IsRealClient(i) && IsSur(i) && IsPlayerAlive(i))
					AddPoints(i, reward, "Killed Tank");
			}
		}
	}
}

void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsRealClient(client) || !IsSur(client))
		return;

	int reward = g_eGeneral.cPointRewards[RewardSKillWitch].IntValue;
	if (reward > 0)
		AddPoints(client, reward, "Killed Witch");

	if (event.GetBool("oneshot")) {
		reward = g_eGeneral.cPointRewards[RewardSCrownWitch].IntValue;
		if (reward > 0)
			AddPoints(client, reward, "Crowned Witch");
	}
}

void Event_HealSuccess(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || client == GetClientOfUserId(event.GetInt("subject")) || !IsRealClient(client) || !IsSur(client))
		return;
	
	if (event.GetInt("health_restored") > 39) {
		int reward = g_eGeneral.cPointRewards[RewardSTeamHeal].IntValue;
		if (reward > 0)
			AddPoints(client, reward, "Team Heal");
	}
	else {
		int reward = g_eGeneral.cPointRewards[RewardSHealFarm].IntValue;
		if (reward > 0)
			AddPoints(client, reward, "Team Heal Warning");
	}
}

void Event_AwardEarned(Event event, const char[] name, bool dontBroadcast) {
	if (event.GetInt("award") != 67)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsRealClient(client) || !IsSur(client))
		return;

	
	int reward = g_eGeneral.cPointRewards[RewardSProtect].IntValue;
	if (reward > 0) {
		g_ePlayer[client].ProtectCount++;
		if (g_ePlayer[client].ProtectCount >= 6) {
			AddPoints(client, reward, "Protect");
			g_ePlayer[client].ProtectCount -= 6;
		}
	}
}

void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || client == GetClientOfUserId(event.GetInt("subject")) || !IsRealClient(client) || !IsSur(client))
		return;

	if (event.GetBool("ledge_hang")) {
		int reward = g_eGeneral.cPointRewards[RewardSTeamLedge].IntValue;
		if (reward > 0)
			AddPoints(client, reward, "Ledge Revive");
	}
	else {
		int reward = g_eGeneral.cPointRewards[RewardSTeamRevive].IntValue;
		if (reward > 0)
			AddPoints(client, reward, "Revive");
	}
}

void Event_DefibrillatorUsed(Event event, const char[] name, bool dontBroadcast)
{ // Defib
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsRealClient(client) || !IsSur(client))
		return;
	
	int reward = g_eGeneral.cPointRewards[RewardSTeamDefib].IntValue;
	if (reward > 0)
		AddPoints(client, reward, "Defib");
}

void Event_ChokeStart(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsRealClient(client) || !IsInf(client))
		return;
	
	int reward = g_eGeneral.cPointRewards[RewardIChokeS].IntValue;
	if (reward > 0)
		AddPoints(client, reward, "Smoke");
}

void Event_PlayerNowIt(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsRealClient(attacker))
		return;

	switch (GetClientTeam(attacker)) {
		case 2: {
			int client = GetClientOfUserId(event.GetInt("userid"));
			if (client && IsInf(client) && IsTank(client)) {
				int reward = g_eGeneral.cPointRewards[RewardSBileTank].IntValue;
				if (reward > 0)
					AddPoints(attacker, reward, "Biled");
			}
		}

		case 3: {
			int reward = g_eGeneral.cPointRewards[RewardIVomitS].IntValue;
			if (reward > 0)
				AddPoints(attacker, reward, "Boom");
		}
	}
}

void Event_LungePounce(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsRealClient(client) || !IsInf(client))
		return;

	int reward = g_eGeneral.cPointRewards[RewardIPounceS].IntValue;
	if (reward > 0)
		AddPoints(client, reward, "Pounce");
}

void Event_JockeyRide(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsRealClient(client) || !IsInf(client))
		return;

	int reward = g_eGeneral.cPointRewards[RewardIRideS].IntValue;
	if (reward > 0)
		AddPoints(client, reward, "Jockey Ride");
}

void Event_ChargerCarryStart(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsRealClient(client) || !IsInf(client))
		return;
	
	int reward = g_eGeneral.cPointRewards[RewardIChargeS].IntValue;
	if (reward > 0)
		AddPoints(client, reward, "Charge");
}

void Event_ChargerImpact(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsRealClient(client) || !IsInf(client))
		return;
	
	int reward = g_eGeneral.cPointRewards[RewardIImpactS].IntValue;
	if (reward > 0)
		AddPoints(client, reward, "Charge Collateral");
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsRealClient(attacker) || !IsInf(attacker))
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsSur(client))
		return;

	g_ePlayer[attacker].HurtCount++;
	int reward = g_eGeneral.cPointRewards[RewardIHurtS].IntValue;
	if (reward > 0) {
		int damagetype = event.GetInt("type");
		if (IsFireDamage(damagetype)) // If infected is dealing fire damage, ignore
			return;
	
		if (IsSpitterDamage(damagetype)) {
			if (g_ePlayer[attacker].HurtCount >= 8) {
				AddPoints(attacker, reward, "Spit Damage");
				g_ePlayer[attacker].HurtCount -= 8;
			}
		}
		else {
			if (g_ePlayer[attacker].HurtCount >= 3) {
				AddPoints(attacker, reward, "Damage");
				g_ePlayer[attacker].HurtCount -= 3;
			}
		}
	}
}

bool IsFireDamage(int damagetype) {
	return damagetype == 8 || damagetype == 2056;
}

bool IsSpitterDamage(int damagetype) {
   return damagetype == 263168 || damagetype == 265216;
}

bool CheckPurchase(int client, int cost) {
	return IsItemEnabled(client, cost) && HasEnoughPoints(client, cost);
}

bool IsItemEnabled(int client, int cost) {
	if (cost >= 0)
		return true;

	ReplyToCommand(client, "%s %T", MSGTAG, "Item Disabled", client);
	return false;
}

bool HasEnoughPoints(int client, int cost) {
	if (g_ePlayer[client].PlayerPoints >= cost)
		return true;

	ReplyToCommand(client, "%s %T", MSGTAG, "Insufficient Funds", client);
	return false;
}

void JoinInfected(int client, int cost) {
	if (IsSur(client)) {
		ChangeClientTeam(client, 3);
		RemovePoints(client, cost);
		FakeClientCommand(client,"sm_buy"); //【注释】自动进入内鬼菜单
		PrintHintText(client, "输入!buy进入商店菜单(内鬼版)");	
		PrintToChat(client, "\x04[提示]\x05输入\x03!buy\x05进入\x05商店菜单(\x04内鬼版\x05)");	
	}
}

bool PerformSuicide(int client) {
	if (IsInf(client) && IsPlayerAlive(client)) {
		ForcePlayerSuicide(client);
		return true;
	}
	return false;
}

void BuildBuyMenu(int client) {
	switch (GetClientTeam(client)) {
		case 1: {
			int bot = iGetBotOfIdlePlayer(client);
			if(bot != 0)
			{
				char info[32];
				Menu menu = new Menu(iSurvivorMenuHandler);
				FormatEx(info, sizeof info, "%T", "Points Left", client, g_ePlayer[client].PlayerPoints);
				menu.SetTitle(info);

				if (g_eGeneral.cCategories[CategoryWeapon].IntValue == 1) {
					FormatEx(info, sizeof info, "%T", "Weapons", client);
					menu.AddItem("w", info);
				}
				if (g_eGeneral.cCategories[CategoryUpgrade].IntValue == 1) {
					FormatEx(info, sizeof info, "%T", "Upgrades", client);
					menu.AddItem("u", info);
				}
				if (g_eGeneral.cCategories[CategoryHealth].IntValue == 1) {
					FormatEx(info, sizeof info, "%T", "Health", client);
					menu.AddItem("h", info);
				}
				if (g_eGeneral.cCategories[CategoryTraitor].IntValue == 1) {
					FormatEx(info, sizeof info, "%T", "Traitor", client);
					menu.AddItem("i", info);
				}
				if (g_eGeneral.cCategories[CategorySpecial].IntValue == 1)
					menu.AddItem("s", "特殊能力");

				if(g_ePlayer[client].Command[0] != '\0')
					menu.AddItem("r", "复购");

				menu.Display(client, MENU_TIME_FOREVER);
			}
			else
			{
				PrintToChat(client, "\x04[提示]\x05旁观者无权使用购物指令指令.");
			}
		}
		case 2: {
			char info[32];
			Menu menu = new Menu(iSurvivorMenuHandler);
			FormatEx(info, sizeof info, "%T", "Points Left", client, g_ePlayer[client].PlayerPoints);
			menu.SetTitle(info);

			if (g_eGeneral.cCategories[CategoryWeapon].IntValue == 1) {
				FormatEx(info, sizeof info, "%T", "Weapons", client);
				menu.AddItem("w", info);
			}
			if (g_eGeneral.cCategories[CategoryUpgrade].IntValue == 1) {
				FormatEx(info, sizeof info, "%T", "Upgrades", client);
				menu.AddItem("u", info);
			}
			if (g_eGeneral.cCategories[CategoryHealth].IntValue == 1) {
				FormatEx(info, sizeof info, "%T", "Health", client);
				menu.AddItem("h", info);
			}
			if (g_eGeneral.cCategories[CategoryTraitor].IntValue == 1) {
				FormatEx(info, sizeof info, "%T", "Traitor", client);
				menu.AddItem("i", info);
			}
			if (g_eGeneral.cCategories[CategorySpecial].IntValue == 1)
				menu.AddItem("s", "特殊");

			if(g_ePlayer[client].Command[0] != '\0')
					menu.AddItem("r", "复购");

			menu.Display(client, MENU_TIME_FOREVER);
		}

		case 3: {
			char info[32];
			Menu menu = new Menu(iInfectedMenuHandler);
			FormatEx(info, sizeof info, "%T", "Points Left", client, g_ePlayer[client].PlayerPoints);
			menu.SetTitle(info);
			if (g_eGeneral.cItemCosts[CostPZHeal].IntValue > -1) {
				FormatEx(info, sizeof info, "%T", "Heal", client);
				menu.AddItem("heal", info);
			}
			if (g_eGeneral.cItemCosts[CostSuicide].IntValue > -1) {
				FormatEx(info, sizeof info, "%T", "Suicide", client);
				menu.AddItem("suicide", info);
			}
			if (g_eGeneral.cItemCosts[CostSmoker].IntValue > -1) {
				FormatEx(info, sizeof info, "%T", "Smoker", client);
				menu.AddItem("smoker", info);
			}
			if (g_eGeneral.cItemCosts[CostBoomer].IntValue > -1) {
				FormatEx(info, sizeof info, "%T", "Boomer", client);
				menu.AddItem("boomer", info);
			}
			if (g_eGeneral.cItemCosts[CostHunter].IntValue > -1) {
				FormatEx(info, sizeof info, "%T", "Hunter", client);
				menu.AddItem("hunter", info);
			}
			if (g_eGeneral.cItemCosts[CostSpitter].IntValue > -1) {
				FormatEx(info, sizeof info, "%T", "Spitter", client);
				menu.AddItem("spitter", info);
			}
			if (g_eGeneral.cItemCosts[CostJockey].IntValue > -1) {
				FormatEx(info, sizeof info, "%T", "Jockey", client);
				menu.AddItem("jockey", info);
			}
			if (g_eGeneral.cItemCosts[CostCharger].IntValue > -1) {
				FormatEx(info, sizeof info, "%T", "Charger", client);
				menu.AddItem("charger", info);
			}
			if (g_eGeneral.cItemCosts[CostTank].IntValue > -1) {
				FormatEx(info, sizeof info, "%T", "Tank", client);
				menu.AddItem("tank", info);
			}
			if (strcmp(g_eGeneral.CurrentMap, "c6m1_riverbank", false) == 0 && g_eGeneral.cItemCosts[CostWitch].IntValue > -1) {
				FormatEx(info, sizeof info, "%T", "Witch Bride", client);
				menu.AddItem("witch_bride", info);
			}
			else if (g_eGeneral.cItemCosts[CostWitch].IntValue > -1) {
				FormatEx(info, sizeof info, "%T", "Witch", client);
				menu.AddItem("witch", info);
			}
			if (g_eGeneral.cItemCosts[CostHorde].IntValue > -1) {
				FormatEx(info, sizeof info, "%T", "Horde", client);
				menu.AddItem("horde", info);
			}
			if (g_eGeneral.cItemCosts[CostMob].IntValue > -1) {
				FormatEx(info, sizeof info, "%T", "Mob", client);
				menu.AddItem("mob", info);
			}
			FormatEx(info, sizeof info, "%T", "Human", client);
			menu.AddItem("Human", info); //【注释】增加重新做人
			menu.Display(client, MENU_TIME_FOREVER);
		}
	}
}

void BuildWeaponMenu(int client) {
	char info[32];
	Menu menu = new Menu(iWeaponMenuHandler);
	FormatEx(info, sizeof info,"%T", "Points Left", client, g_ePlayer[client].PlayerPoints);
	menu.SetTitle(info);
	if (g_eGeneral.cCategories[CategoryMelee].IntValue == 1) {
		FormatEx(info, sizeof info, "%T", "Melee", client);
		menu.AddItem("a", info);
	}
	if (g_eGeneral.cCategories[CategorySniper].IntValue == 1) {
		FormatEx(info, sizeof info, "%T", "Sniper Rifles", client);
		menu.AddItem("b", info);
	}
	if (g_eGeneral.cCategories[CategoryRifle].IntValue == 1) {
		FormatEx(info, sizeof info, "%T", "Assault Rifles", client);
		menu.AddItem("c", info);
	}
	if (g_eGeneral.cCategories[CategoryShotgun].IntValue == 1) {
		FormatEx(info, sizeof info, "%T", "Shotguns", client);
		menu.AddItem("d", info);
	}
	if (g_eGeneral.cCategories[CategorySMG].IntValue == 1) {
		FormatEx(info, sizeof info, "%T", "Submachine Guns", client);
		menu.AddItem("e", info);
	}
	if (g_eGeneral.cCategories[CategoryThrowable].IntValue == 1) {
		FormatEx(info, sizeof info, "%T", "Throwables", client);
		menu.AddItem("f", info);
	}
	if (g_eGeneral.cCategories[CategoryMisc].IntValue == 1) {
		FormatEx(info, sizeof info, "%T", "Misc", client);
		menu.AddItem("g", info);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iSurvivorMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[2];
			menu.GetItem(param2, item, sizeof item);
			switch (item[0]) {
				case 'w':
					BuildWeaponMenu(param1);

				case 'h':
					BuildHealthMenu(param1);

				case 'u':
					BuildUpgradeMenu(param1);

				case 'i': {
					g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostTraitor].IntValue;

					char info[32];
					Menu menu1 = new Menu(iTraitorMenuHandler);
					FormatEx(info, sizeof info,"%T", "Cost", param1, g_ePlayer[param1].ItemCost);
					menu1.SetTitle(info);
					FormatEx(info, sizeof info,"%T", "Yes", param1);
					menu1.AddItem("y", info);
					FormatEx(info, sizeof info,"%T", "No", param1);
					menu1.AddItem("n", info);
					menu1.ExitButton = true;
					menu1.ExitBackButton = true;
					menu1.Display(param1, MENU_TIME_FOREVER);
				}
				case 's':
					BuildSpecialMenu(param1);
				case 'r':
					cmdRepeatBuy(param1, 0);
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iTraitorMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[2];
			menu.GetItem(param2, item, sizeof item);
			switch (item[0]) {
				case 'n':
					BuildBuyMenu(param1);

				case 'y': {
					if (!HasEnoughPoints(param1, g_ePlayer[param1].ItemCost))
						return 0;

					if (GetPlayerSurvivor() < g_eGeneral.cSettings[SettingSurvivorRequired].IntValue || GetPlayerZombie() >= g_eGeneral.cSettings[SettingTraitorLimit].IntValue)
						PrintToChat(param1,  "%T", "Traitor Limit", param1);
					else
						JoinInfected(param1, g_ePlayer[param1].ItemCost);
				}
			}
		}
	
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildBuyMenu(param1);
		}
	
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int GetPlayerSurvivor() {
	int sur;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2)
			sur++;
	}
	return sur;
}

int GetPlayerZombie() {
	int pz;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3)
			pz++;
	}
	return pz;
}

int iWeaponMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[2];
			menu.GetItem(param2, item, sizeof item);
			switch (item[0]) {
				case 'a':
					BuildMeleeMenu(param1);
			
				case 'b':
					BuildSniperMenu(param1);
		
				case 'c':
					BuildRifleMenu(param1);
			
				case 'd':
					BuildShotgunMenu(param1);
				
				case 'e':
					BuildSMGMenu(param1);
		
				case 'f':
					BuildThrowableMenu(param1);
			
				case 'g':
					BuildMiscMenu(param1);
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildBuyMenu(param1);
		}
		
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void BuildMeleeMenu(int client) {
	char info[32];
	Menu menu = new Menu(iMeleeMenuHandler);
	FormatEx(info, sizeof info,"%T", "Points Left", client, g_ePlayer[client].PlayerPoints);
	menu.SetTitle(info);
	for (int i; i < g_iMeleeCount; i++) {
		int pos = GetMeleePos(g_sMeleeClass[i]);
		int cost = pos != -1 ? g_eGeneral.cItemCosts[pos + CostFireaxe].IntValue : g_eGeneral.cItemCosts[CostCustomMelee].IntValue;

		if (cost < 0)
			continue;

		if (pos != -1)
			FormatEx(info, sizeof info, "%T", g_sMeleeClass[i], client);
		else
			FormatEx(info, sizeof info, g_sMeleeClass[i]);
		menu.AddItem(g_sMeleeClass[i], info);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int GetMeleePos(const char[] sMelee) {
	for (int i; i < sizeof g_sMeleeName; i++) {
		if (strcmp(g_sMeleeName[i], sMelee) == 0)
			return i;
	}
	return -1;
}

void BuildSniperMenu(int client) {
	char info[32];
	Menu menu = new Menu(iSniperMenuHandler);
	FormatEx(info, sizeof info,"%T", "Points Left", client, g_ePlayer[client].PlayerPoints);
	menu.SetTitle(info);
	if (g_eGeneral.cItemCosts[CostHunting].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Hunting Rifle", client);
		menu.AddItem("hunting_rifle", info);
	}
	if (g_eGeneral.cItemCosts[CostMilitary].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Military Sniper Rifle", client);
		menu.AddItem("sniper_military", info);
	}
	if (g_eGeneral.cItemCosts[CostAWP].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "AWP Sniper Rifle", client);
		menu.AddItem("sniper_awp", info);
	}
	if (g_eGeneral.cItemCosts[CostScout].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Scout Sniper Rifle", client);
		menu.AddItem("sniper_scout", info);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void BuildRifleMenu(int client) {
	char info[32];
	Menu menu = new Menu(iRifleMenuHandler);
	FormatEx(info, sizeof info,"%T", "Points Left", client, g_ePlayer[client].PlayerPoints);
	menu.SetTitle(info);
	if (g_eGeneral.cItemCosts[CostM60].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "M60 Assault Rifle", client);
		menu.AddItem("rifle_m60", info);
	}
	if (g_eGeneral.cItemCosts[CostM16].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "M16 Assault Rifle", client);
		menu.AddItem("rifle", info);
	}
	if (g_eGeneral.cItemCosts[CostSCAR].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "SCAR-L Assault Rifle", client);
		menu.AddItem("rifle_desert", info);
	}
	if (g_eGeneral.cItemCosts[CostAK47].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "AK-47 Assault Rifle", client);
		menu.AddItem("rifle_ak47", info);
	}
	if (g_eGeneral.cItemCosts[CostSG552].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "SG552 Assault Rifle", client);
		menu.AddItem("rifle_sg552", info);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void BuildShotgunMenu(int client) {
	char info[32];
	Menu menu = new Menu(iShotgunMenuHandler);
	FormatEx(info, sizeof info,"%T", "Points Left", client, g_ePlayer[client].PlayerPoints);
	menu.SetTitle(info);
	if (g_eGeneral.cItemCosts[CostPump].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Pump Shotgun", client);
		menu.AddItem("pumpshotgun", info);
	}
	if (g_eGeneral.cItemCosts[CostChrome].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Chrome Shotgun", client);
		menu.AddItem("shotgun_chrome", info);
	}
	if (g_eGeneral.cItemCosts[CostAuto].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Tactical Shotgun", client);
		menu.AddItem("autoshotgun", info);
	}
	if (g_eGeneral.cItemCosts[CostSPAS].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "SPAS Shotgun", client);
		menu.AddItem("shotgun_spas", info);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void BuildSMGMenu(int client) {
	char info[32];
	Menu menu = new Menu(iSMGMenuHandler);
	FormatEx(info, sizeof info,"%T", "Points Left", client, g_ePlayer[client].PlayerPoints);
	menu.SetTitle(info);
	if (g_eGeneral.cItemCosts[CostUZI].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Uzi", client);
		menu.AddItem("smg", info);
	}
	if (g_eGeneral.cItemCosts[CostSilenced].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Silenced SMG", client);
		menu.AddItem("smg_silenced", info);
	}
	if (g_eGeneral.cItemCosts[CostMP5].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "MP5 SMG", client);
		menu.AddItem("smg_mp5", info);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void BuildHealthMenu(int client) {
	char info[32];
	Menu menu = new Menu(iHealthMenuHandler);
	FormatEx(info, sizeof info,"%T", "Points Left", client, g_ePlayer[client].PlayerPoints);
	menu.SetTitle(info);
	if (g_eGeneral.cItemCosts[CostHealthKit].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "First Aid Kit", client);
		menu.AddItem("first_aid_kit", info);
	}
	if (g_eGeneral.cItemCosts[CostDefib].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Defibrillator", client);
		menu.AddItem("defibrillator", info);
	}
	if (g_eGeneral.cItemCosts[CostPills].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Pills", client);
		menu.AddItem("pain_pills", info);
	}
	if (g_eGeneral.cItemCosts[CostAdren].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Adrenaline", client);
		menu.AddItem("adrenaline", info);
	}
	if (g_eGeneral.cItemCosts[CostHeal].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Full Heal", client);
		menu.AddItem("health", info);
	}
	if (g_eGeneral.cItemCosts[Costresurrection].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Now Respawn", client);
		menu.AddItem("respawn", info);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void BuildThrowableMenu(int client) {
	char info[32];
	Menu menu = new Menu(iThrowableMenuHandler);
	FormatEx(info, sizeof info,"%T", "Points Left", client, g_ePlayer[client].PlayerPoints);
	menu.SetTitle(info);
	if (g_eGeneral.cItemCosts[CostMolotov].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Molotov", client);
		menu.AddItem("molotov", info);
	}
	if (g_eGeneral.cItemCosts[CostPipe].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Pipe Bomb", client);
		menu.AddItem("pipe_bomb", info);
	}
	if (g_eGeneral.cItemCosts[CostBile].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Bile Bomb", client);
		menu.AddItem("vomitjar", info);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void BuildMiscMenu(int client) {
	char info[32];
	Menu menu = new Menu(iMiscMenuHandler);
	FormatEx(info, sizeof info,"%T", "Points Left", client, g_ePlayer[client].PlayerPoints);
	menu.SetTitle(info);
	if (g_eGeneral.cItemCosts[CostGrenade].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Grenade Launcher", client);
		menu.AddItem("grenade_launcher", info);
	}
	if (g_eGeneral.cItemCosts[CostP220].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "P220 Pistol", client);
		menu.AddItem("pistol", info);
	}
	if (g_eGeneral.cItemCosts[CostMagnum].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Magnum Pistol", client);
		menu.AddItem("pistol_magnum", info);
	}
	if (g_eGeneral.cItemCosts[CostChainsaw].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Chainsaw", client);
		menu.AddItem("chainsaw", info);
	}
	if (g_eGeneral.cItemCosts[CostGnome].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Gnome", client);
		menu.AddItem("gnome", info);
	}
	if (strcmp(g_eGeneral.CurrentMap, "c1m2_streets", false) != 0 && g_eGeneral.cItemCosts[CostCola].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Cola Bottles", client);
		menu.AddItem("cola_bottles", info);
	}
	if (g_eGeneral.cItemCosts[CostFireworks].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Fireworks Crate", client);
		menu.AddItem("fireworkcrate", info);
	}
	if (g_iCurrentMode != 8 && g_eGeneral.cItemCosts[CostGasCan].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Gascan", client);
		menu.AddItem("gascan", info);
	}
	if (g_eGeneral.cItemCosts[CostOxygen].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Oxygen Tank", client);
		menu.AddItem("oxygentank", info);
	}
	if (g_eGeneral.cItemCosts[CostPropane].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Propane Tank", client);
		menu.AddItem("propanetank", info);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void BuildUpgradeMenu(int client) {
	char info[32];
	Menu menu = new Menu(iUpgradeMenuHandler);
	FormatEx(info, sizeof info,"%T", "Points Left", client, g_ePlayer[client].PlayerPoints);
	menu.SetTitle(info);
	if (g_eGeneral.cItemCosts[CostLaserSight].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Laser Sight", client);
		menu.AddItem("laser_sight", info);
	}
	if (g_eGeneral.cItemCosts[CostExplosiveAmmo].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Explosive Ammo", client);
		menu.AddItem("explosive_ammo", info);
	}
	if (g_eGeneral.cItemCosts[CostIncendiaryAmmo].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Incendiary Ammo", client);
		menu.AddItem("incendiary_ammo", info);
	}
	if (g_eGeneral.cItemCosts[CostExplosivePack].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Explosive Ammo Pack", client);
		menu.AddItem("upgradepack_explosive", info);
	}
	if (g_eGeneral.cItemCosts[CostIncendiaryPack].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Incendiary Ammo Pack", client);
		menu.AddItem("upgradepack_incendiary", info);
	}
	if (g_eGeneral.cItemCosts[CostAmmo].IntValue > -1) {
		FormatEx(info, sizeof info, "%T", "Ammo", client);
		menu.AddItem("ammo", info);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iMeleeMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			menu.GetItem(param2, item, sizeof item);
			FormatEx(g_ePlayer[param1].Command, sizeof Player::Command, "give %s", item);
			int sequence = GetMeleePos(item);
			if (sequence != -1)
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[sequence + 25].IntValue;
			else
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostCustomMelee].IntValue;
			DisplayMeleeConfirmMenu(param1);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildWeaponMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iSMGMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			menu.GetItem(param2, item, sizeof item);
			if (strcmp(item, "smg") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give smg");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostUZI].IntValue;
			}
			else if (strcmp(item, "smg_silenced") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give smg_silenced");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostSilenced].IntValue;
			}
			else if (strcmp(item, "smg_mp5") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give smg_mp5");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostMP5].IntValue;
			}
			DisplaySMGConfirmMenu(param1);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildWeaponMenu(param1);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iRifleMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			menu.GetItem(param2, item, sizeof item);
			if (strcmp(item, "rifle") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give rifle");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostM16].IntValue;
			}
			else if (strcmp(item, "rifle_desert") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give rifle_desert");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostSCAR].IntValue;
			}
			else if (strcmp(item, "rifle_ak47") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give rifle_ak47");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostAK47].IntValue;
			}
			else if (strcmp(item, "rifle_sg552") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give rifle_sg552");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostSG552].IntValue;
			}
			else if (strcmp(item, "rifle_m60") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give rifle_m60");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostM60].IntValue;
			}
			DisplayRifleConfirmMenu(param1);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildWeaponMenu(param1);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iSniperMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			menu.GetItem(param2, item, sizeof item);
			if (strcmp(item, "hunting_rifle") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give hunting_rifle");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostHunting].IntValue;
			}
			else if (strcmp(item, "sniper_scout") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give sniper_scout");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostScout].IntValue;
			}
			else if (strcmp(item, "sniper_awp") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give sniper_awp");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostAWP].IntValue;
			}
			else if (strcmp(item, "sniper_military") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give sniper_military");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostMilitary].IntValue;
			}
			DisplaySniperConfirmMenu(param1);
		}
	
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildWeaponMenu(param1);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iShotgunMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			menu.GetItem(param2, item, sizeof item);
			if (strcmp(item, "pumpshotgun") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give pumpshotgun");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostPump].IntValue;
			}
			else if (strcmp(item, "shotgun_chrome") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give shotgun_chrome");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostChrome].IntValue;
			}
			else if (strcmp(item, "autoshotgun") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give autoshotgun");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostAuto].IntValue;
			}
			else if (strcmp(item, "shotgun_spas") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give shotgun_spas");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostSPAS].IntValue;
			}
			DisplayShotgunConfirmMenu(param1);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildWeaponMenu(param1);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iThrowableMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			menu.GetItem(param2, item, sizeof item);
			if (strcmp(item, "molotov") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give molotov");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostMolotov].IntValue;
			}
			else if (strcmp(item, "pipe_bomb") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give pipe_bomb");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostPipe].IntValue;
			}
			else if (strcmp(item, "vomitjar") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give vomitjar");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostBile].IntValue;
			}
			DisplayThrowableConfirmMenu(param1);
		}
	
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildWeaponMenu(param1);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iMiscMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			menu.GetItem(param2, item, sizeof item);
			if (strcmp(item, "pistol") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give pistol");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostP220].IntValue;
			}
			else if (strcmp(item, "pistol_magnum") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give pistol_magnum");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostMagnum].IntValue;
			}
			else if (strcmp(item, "grenade_launcher") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give grenade_launcher");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostGrenade].IntValue;
			}
			else if (strcmp(item, "chainsaw") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give chainsaw");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostChainsaw].IntValue;
			}
			else if (strcmp(item, "gnome") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give gnome");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostGnome].IntValue;
			}
			else if (strcmp(item, "cola_bottles") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give cola_bottles");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostCola].IntValue;
			}
			else if (strcmp(item, "gascan") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give gascan");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostGasCan].IntValue;
			}
			else if (strcmp(item, "propanetank") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give propanetank");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostPropane].IntValue;
			}
			else if (strcmp(item, "fireworkcrate") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give fireworkcrate");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostFireworks].IntValue;
			}
			else if (strcmp(item, "oxygentank") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give oxygentank");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostOxygen].IntValue;
			}
			DisplayMiscConfirmMenu(param1);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildWeaponMenu(param1);
		}
	
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iHealthMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			menu.GetItem(param2, item, sizeof item);
			if (strcmp(item, "first_aid_kit") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give first_aid_kit");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostHealthKit].IntValue;
			}
			else if (strcmp(item, "defibrillator") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give defibrillator");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostDefib].IntValue;
			}
			else if (strcmp(item, "pain_pills") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give pain_pills");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostPills].IntValue;
			}
			else if (strcmp(item, "adrenaline") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give adrenaline");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostAdren].IntValue;
			}
			else if (strcmp(item, "health") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give health");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostHeal].IntValue;
			}
			else if (strcmp(item, "respawn") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "respawn");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[Costresurrection].IntValue;
			}
			DisplayHealthConfirmMenu(param1);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildBuyMenu(param1);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

bool IsRespawnPlayer(int client) {
	if (IsSur(client) && !IsPlayerAlive(client)) {
		L4D_RespawnPlayer(client);
		TeleportClient(client);//随机传送到其他幸存者身边.
		return true;
	}
	return false;
}

int iUpgradeMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			menu.GetItem(param2, item, sizeof item);
			if (strcmp(item, "upgradepack_explosive") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give upgradepack_explosive");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostExplosivePack].IntValue;
			}
			else if (strcmp(item, "upgradepack_incendiary") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give upgradepack_incendiary");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostIncendiaryPack].IntValue;
			}
			else if (strcmp(item, "explosive_ammo") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "upgrade_add EXPLOSIVE_AMMO");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostExplosiveAmmo].IntValue;
			}
			else if (strcmp(item, "incendiary_ammo") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "upgrade_add INCENDIARY_AMMO");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostIncendiaryAmmo].IntValue;
			}
			else if (strcmp(item, "laser_sight") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "upgrade_add LASER_SIGHT");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostLaserSight].IntValue;
			}
			else if (strcmp(item, "ammo") == 0) {
				strcopy(g_ePlayer[param1].Command, sizeof Player::Command, "give ammo");
				g_ePlayer[param1].ItemCost = g_eGeneral.cItemCosts[CostAmmo].IntValue;
			}
			DisplayUpgradeConfirmMenu(param1);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildBuyMenu(param1);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iInfectedMenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			menu.GetItem(param2, item, sizeof item);
			if (strcmp(item, "heal") == 0) {
				strcopy(g_ePlayer[client].Command, sizeof Player::Command, "give health");
				if (IsTank(client))
					g_ePlayer[client].ItemCost = g_eGeneral.cItemCosts[CostPZHeal].IntValue * g_eGeneral.cItemCosts[CostTankHealMulti].IntValue;
				else
					g_ePlayer[client].ItemCost = g_eGeneral.cItemCosts[CostPZHeal].IntValue;
			}
			else if (strcmp(item, "suicide") == 0) {
				strcopy(g_ePlayer[client].Command, sizeof Player::Command, "suicide");
				g_ePlayer[client].ItemCost = g_eGeneral.cItemCosts[CostSuicide].IntValue;
			}
			else if (strcmp(item, "smoker") == 0) {
				strcopy(g_ePlayer[client].Command, sizeof Player::Command, "z_spawn_old smoker");
				g_ePlayer[client].ItemCost = g_eGeneral.cItemCosts[CostSmoker].IntValue;
			}
			else if (strcmp(item, "boomer") == 0) {
				strcopy(g_ePlayer[client].Command, sizeof Player::Command, "z_spawn_old boomer");
				g_ePlayer[client].ItemCost = g_eGeneral.cItemCosts[CostBoomer].IntValue;
			}
			else if (strcmp(item, "hunter") == 0) {
				strcopy(g_ePlayer[client].Command, sizeof Player::Command, "z_spawn_old hunter");
				g_ePlayer[client].ItemCost = g_eGeneral.cItemCosts[CostHunter].IntValue;
			}
			else if (strcmp(item, "spitter") == 0) {
				strcopy(g_ePlayer[client].Command, sizeof Player::Command, "z_spawn_old spitter");
				g_ePlayer[client].ItemCost = g_eGeneral.cItemCosts[CostSpitter].IntValue;
			}
			else if (strcmp(item, "jockey") == 0) {
				strcopy(g_ePlayer[client].Command, sizeof Player::Command, "z_spawn_old jockey");
				g_ePlayer[client].ItemCost = g_eGeneral.cItemCosts[CostJockey].IntValue;
			}
			else if (strcmp(item, "charger") == 0) {
				strcopy(g_ePlayer[client].Command, sizeof Player::Command, "z_spawn_old charger");
				g_ePlayer[client].ItemCost = g_eGeneral.cItemCosts[CostCharger].IntValue;
			}
			else if (strcmp(item, "witch") == 0) {
				strcopy(g_ePlayer[client].Command, sizeof Player::Command, "z_spawn_old witch");
				g_ePlayer[client].ItemCost = g_eGeneral.cItemCosts[CostWitch].IntValue;
			}
			else if (strcmp(item, "witch_bride") == 0) {
				strcopy(g_ePlayer[client].Command, sizeof Player::Command, "z_spawn_old witch_bride");
				g_ePlayer[client].ItemCost = g_eGeneral.cItemCosts[CostWitch].IntValue;
			}
			else if (strcmp(item, "tank") == 0) {
				strcopy(g_ePlayer[client].Command, sizeof Player::Command, "z_spawn_old tank");
				g_ePlayer[client].ItemCost = g_eGeneral.cItemCosts[CostTank].IntValue;
			}
			else if (strcmp(item, "horde") == 0) {
				strcopy(g_ePlayer[client].Command, sizeof Player::Command, "director_force_panic_event");
				g_ePlayer[client].ItemCost = g_eGeneral.cItemCosts[CostHorde].IntValue;
			}
			else if (strcmp(item, "mob") == 0) {
				strcopy(g_ePlayer[client].Command, sizeof Player::Command, "z_spawn_old mob");
				g_ePlayer[client].ItemCost = g_eGeneral.cItemCosts[CostMob].IntValue;
			}
			else if (strcmp(item, "Human") == 0) {
				FakeClientCommand(client,"sm_join");
				delete menu;
				return 0;
			}
			DisplayInfectedConfirmMenu(client);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void DisplayMeleeConfirmMenu(int client) {
	char info[32];
	Menu menu = new Menu(iMeleeConfirmMenuHandler);
	FormatEx(info, sizeof info,"%T", "Cost", client, g_ePlayer[client].ItemCost);
	menu.SetTitle(info);
	FormatEx(info, sizeof info,"%T", "Yes", client);
	menu.AddItem("y", info);
	FormatEx(info, sizeof info,"%T", "No", client);
	menu.AddItem("n", info);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplaySMGConfirmMenu(int client) {
	char info[32];
	Menu menu = new Menu(iSMGConfirmMenuHandler);
	FormatEx(info, sizeof info,"%T", "Cost", client, g_ePlayer[client].ItemCost);
	menu.SetTitle(info);
	FormatEx(info, sizeof info,"%T", "Yes", client);
	menu.AddItem("y", info);
	FormatEx(info, sizeof info,"%T", "No", client);
	menu.AddItem("n", info);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayRifleConfirmMenu(int client) {
	char info[32];
	Menu menu = new Menu(iRifleConfirmMenuHandler);
	FormatEx(info, sizeof info,"%T", "Cost", client, g_ePlayer[client].ItemCost);
	menu.SetTitle(info);
	FormatEx(info, sizeof info,"%T", "Yes", client);
	menu.AddItem("y", info);
	FormatEx(info, sizeof info,"%T", "No", client);
	menu.AddItem("n", info);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplaySniperConfirmMenu(int client) {
	char info[32];
	Menu menu = new Menu(iSniperConfirmMenuHandler);
	FormatEx(info, sizeof info,"%T", "Cost", client, g_ePlayer[client].ItemCost);
	menu.SetTitle(info);
	FormatEx(info, sizeof info,"%T", "Yes", client);
	menu.AddItem("y", info);
	FormatEx(info, sizeof info,"%T", "No", client);
	menu.AddItem("n", info);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayShotgunConfirmMenu(int client) {
	char info[32];
	Menu menu = new Menu(iShotgunConfirmMenuHandler);
	FormatEx(info, sizeof info,"%T", "Cost", client, g_ePlayer[client].ItemCost);
	menu.SetTitle(info);
	FormatEx(info, sizeof info,"%T", "Yes", client);
	menu.AddItem("y", info);
	FormatEx(info, sizeof info,"%T", "No", client);
	menu.AddItem("n", info);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayThrowableConfirmMenu(int client) {
	char info[32];
	Menu menu = new Menu(iThrowableConfirmMenuHandler);
	FormatEx(info, sizeof info,"%T", "Cost", client, g_ePlayer[client].ItemCost);
	menu.SetTitle(info);
	FormatEx(info, sizeof info,"%T", "Yes", client);
	menu.AddItem("y", info);
	FormatEx(info, sizeof info,"%T", "No", client);
	menu.AddItem("n", info);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayMiscConfirmMenu(int client) {
	char info[32];
	Menu menu = new Menu(iMiscConfirmMenuHandler);
	FormatEx(info, sizeof info,"%T", "Cost", client, g_ePlayer[client].ItemCost);
	menu.SetTitle(info);
	FormatEx(info, sizeof info,"%T", "Yes", client);
	menu.AddItem("y", info);
	FormatEx(info, sizeof info,"%T", "No", client);
	menu.AddItem("n", info);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayHealthConfirmMenu(int client) {
	char info[32];
	Menu menu = new Menu(iHealthConfirmMenuHandler);
	FormatEx(info, sizeof info,"%T", "Cost", client, g_ePlayer[client].ItemCost);
	menu.SetTitle(info);
	FormatEx(info, sizeof info,"%T", "Yes", client);
	menu.AddItem("y", info);
	FormatEx(info, sizeof info,"%T", "No", client);
	menu.AddItem("n", info);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayUpgradeConfirmMenu(int client) {
	char info[32];
	Menu menu = new Menu(iUpgradeConfirmMenuHandler);
	FormatEx(info, sizeof info,"%T", "Cost", client, g_ePlayer[client].ItemCost);
	menu.SetTitle(info);
	FormatEx(info, sizeof info,"%T", "Yes", client);
	menu.AddItem("y", info);
	FormatEx(info, sizeof info,"%T", "No", client);
	menu.AddItem("n", info);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayInfectedConfirmMenu(int client) {
	char info[32];
	Menu menu = new Menu(iInfectedConfirmMenuHandler);
	FormatEx(info, sizeof info,"%T", "Cost", client, g_ePlayer[client].ItemCost);
	menu.SetTitle(info);
	FormatEx(info, sizeof info,"%T", "Yes", client);
	menu.AddItem("y", info);
	FormatEx(info, sizeof info,"%T", "No", client);
	menu.AddItem("n", info);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iMeleeConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[2];
			menu.GetItem(param2, item, sizeof item);
			switch (item[0]) {
				case 'n': {
					BuildMeleeMenu(param1);
					strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
					g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
				}

				case 'y': {
					if (HasEnoughPoints(param1, g_ePlayer[param1].ItemCost)) {
						strcopy(g_ePlayer[param1].Bought, sizeof Player::Bought, g_ePlayer[param1].Command);
						g_ePlayer[param1].BoughtCost = g_ePlayer[param1].ItemCost;
						
						switch (GetClientTeam(param1)) 
						{
							case 1: 
							{
								int client = iGetBotOfIdlePlayer(param1);
								if(client != 0)
								{
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									CheatCommand(client, g_ePlayer[param1].Command);
								}
							}
							case 2: 
							{
								RemovePoints(param1, g_ePlayer[param1].ItemCost);
								CheatCommand(param1, g_ePlayer[param1].Command);
							}
						}
					}
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildMeleeMenu(param1);

			strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
			g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iRifleConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[2];
			menu.GetItem(param2, item, sizeof item);
			switch (item[0]) {
				case 'n': {
					BuildRifleMenu(param1);
					strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
					g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
				}

				case 'y': {
					if (HasEnoughPoints(param1, g_ePlayer[param1].ItemCost)) {
						strcopy(g_ePlayer[param1].Bought, sizeof Player::Bought, g_ePlayer[param1].Command);
						g_ePlayer[param1].BoughtCost = g_ePlayer[param1].ItemCost;
						//RemovePoints(param1, g_ePlayer[param1].ItemCost);
						//CheatCommand(param1, g_ePlayer[param1].Command);
						switch (GetClientTeam(param1)) 
						{
							case 1: 
							{
								int client = iGetBotOfIdlePlayer(param1);
								if(client != 0)
								{
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									CheatCommand(client, g_ePlayer[param1].Command);
								}
							}
							case 2: 
							{
								if (IsPlayerAlive(param1)) 
								{
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									CheatCommand(param1, g_ePlayer[param1].Command);
								}
							}
						}
					}
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildRifleMenu(param1);

			strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
			g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iSniperConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[2];
			menu.GetItem(param2, item, sizeof item);
			switch (item[0]) {
				case 'n': {
					BuildSniperMenu(param1);
					strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
					g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
				}

				case 'y': {
					if (HasEnoughPoints(param1, g_ePlayer[param1].ItemCost)) {
						strcopy(g_ePlayer[param1].Bought,sizeof Player::Bought, g_ePlayer[param1].Command);
						g_ePlayer[param1].BoughtCost = g_ePlayer[param1].ItemCost;
						//RemovePoints(param1, g_ePlayer[param1].ItemCost);
						//CheatCommand(param1, g_ePlayer[param1].Command);
						switch (GetClientTeam(param1)) 
						{
							case 1: 
							{
								int client = iGetBotOfIdlePlayer(param1);
								if(client != 0)
								{
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									CheatCommand(client, g_ePlayer[param1].Command);
								}
							}
							case 2: 
							{
								if (IsPlayerAlive(param1)) 
								{
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									CheatCommand(param1, g_ePlayer[param1].Command);
								}
							}
						}
					}
				}
			}
		}
	
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildSniperMenu(param1);

			strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
			g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
		}
	
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iSMGConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[2];
			menu.GetItem(param2, item, sizeof item);
			switch (item[0]) {
				case 'n': {
					BuildSMGMenu(param1);
					strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
					g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
				}

				case 'y': {
					if (HasEnoughPoints(param1, g_ePlayer[param1].ItemCost)) {
						strcopy(g_ePlayer[param1].Bought, sizeof Player::Bought, g_ePlayer[param1].Command);
						g_ePlayer[param1].BoughtCost = g_ePlayer[param1].ItemCost;
						//RemovePoints(param1, g_ePlayer[param1].ItemCost);
						//CheatCommand(param1, g_ePlayer[param1].Command);
						switch (GetClientTeam(param1)) 
						{
							case 1: 
							{
								int client = iGetBotOfIdlePlayer(param1);
								if(client != 0)
								{
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									CheatCommand(client, g_ePlayer[param1].Command);
								}
							}
							case 2: 
							{
								if (IsPlayerAlive(param1)) 
								{
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									CheatCommand(param1, g_ePlayer[param1].Command);
								}
							}
						}
					}
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildSMGMenu(param1);

			strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
			g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iShotgunConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[2];
			menu.GetItem(param2, item, sizeof item);
			switch (item[0]) {
				case 'n': {
					BuildShotgunMenu(param1);
					strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
					g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
				}

				case 'y': {
					if (HasEnoughPoints(param1, g_ePlayer[param1].ItemCost)) {
						strcopy(g_ePlayer[param1].Bought, sizeof Player::Bought, g_ePlayer[param1].Command);
						g_ePlayer[param1].BoughtCost = g_ePlayer[param1].ItemCost;
						//RemovePoints(param1, g_ePlayer[param1].ItemCost);
						//CheatCommand(param1, g_ePlayer[param1].Command);
						switch (GetClientTeam(param1)) 
						{
							case 1: 
							{
								int client = iGetBotOfIdlePlayer(param1);
								if(client != 0)
								{
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									CheatCommand(client, g_ePlayer[param1].Command);
								}
							}
							case 2: 
							{
								if (IsPlayerAlive(param1)) 
								{
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									CheatCommand(param1, g_ePlayer[param1].Command);
								}
							}
						}
					}
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildShotgunMenu(param1);

			strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
			g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iThrowableConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[2];
			menu.GetItem(param2, item, sizeof item);
			switch (item[0]) {
				case 'n': {
					BuildThrowableMenu(param1);
					strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
					g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
				}

				case 'y': {
					if (HasEnoughPoints(param1, g_ePlayer[param1].ItemCost)) {
						strcopy(g_ePlayer[param1].Bought, sizeof Player::Bought, g_ePlayer[param1].Command);
						g_ePlayer[param1].BoughtCost = g_ePlayer[param1].ItemCost;
						//RemovePoints(param1, g_ePlayer[param1].ItemCost);
						//CheatCommand(param1, g_ePlayer[param1].Command);
						switch (GetClientTeam(param1)) 
						{
							case 1: 
							{
								int client = iGetBotOfIdlePlayer(param1);
								if(client != 0)
								{
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									CheatCommand(client, g_ePlayer[param1].Command);
								}
							}
							case 2: 
							{
								if (IsPlayerAlive(param1)) 
								{
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									CheatCommand(param1, g_ePlayer[param1].Command);
								}
							}
						}
					}
				}
			}
		}
	
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildThrowableMenu(param1);

			strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
			g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iMiscConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[2];
			menu.GetItem(param2, item, sizeof item);
			switch (item[0]) {
				case 'n': {
					BuildMiscMenu(param1);
					strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
					g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
				}

				case 'y': {
					if (HasEnoughPoints(param1, g_ePlayer[param1].ItemCost)) {
						strcopy(g_ePlayer[param1].Bought, sizeof Player::Bought, g_ePlayer[param1].Command);
						g_ePlayer[param1].BoughtCost = g_ePlayer[param1].ItemCost;
						//RemovePoints(param1, g_ePlayer[param1].ItemCost);
						//CheatCommand(param1, g_ePlayer[param1].Command);
						switch (GetClientTeam(param1)) 
						{
							case 1: 
							{
								int client = iGetBotOfIdlePlayer(param1);
								if(client != 0)
								{
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									CheatCommand(client, g_ePlayer[param1].Command);
								}
							}
							case 2: 
							{
								if (IsPlayerAlive(param1)) 
								{
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									CheatCommand(param1, g_ePlayer[param1].Command);
								}
							}
						}
					}
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildMiscMenu(param1);

			strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
			g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iHealthConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[2];
			menu.GetItem(param2, item, sizeof item);
			switch (item[0]) {
				case 'n': {
					BuildHealthMenu(param1);
					strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
					g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
				}

				case 'y': {
					if (HasEnoughPoints(param1, g_ePlayer[param1].ItemCost)) {
						if (strcmp(g_ePlayer[param1].Command, "give health") == 0) 
						{
							strcopy(g_ePlayer[param1].Bought, sizeof Player::Bought, g_ePlayer[param1].Command);
							g_ePlayer[param1].BoughtCost = g_ePlayer[param1].ItemCost;
							
							switch (GetClientTeam(param1)) 
							{
								case 1: 
								{
									int client = iGetBotOfIdlePlayer(param1);
									if(client != 0)
									{
										RemovePoints(param1, g_ePlayer[param1].ItemCost);
										CheatCommand(client, g_ePlayer[param1].Command);
									}
								}
								case 2: 
								{
									if (IsPlayerAlive(param1)) 
									{
										RemovePoints(param1, g_ePlayer[param1].ItemCost);
										CheatCommand(param1, g_ePlayer[param1].Command);
									}
								}
							}
						}
						else if (strcmp(g_ePlayer[param1].Command, "respawn") == 0) 
						{
							strcopy(g_ePlayer[param1].Bought, sizeof Player::Bought, g_ePlayer[param1].Command);
							g_ePlayer[param1].BoughtCost = g_ePlayer[param1].ItemCost;
							
							if(IsRespawnPlayer(param1)) {
								RemovePoints(param1, g_ePlayer[param1].ItemCost);
								PrintToChatAll("\x04[提示]\x05%N复活了自己！", param1);
							}
							else {
								PrintToChat(param1, "\x04[提示]\x05你当前已是存活状态.");
							}
						}
						else {
							strcopy(g_ePlayer[param1].Bought, sizeof Player::Bought, g_ePlayer[param1].Command);
							g_ePlayer[param1].BoughtCost = g_ePlayer[param1].ItemCost;
							
							switch (GetClientTeam(param1)) 
							{
								case 1: 
								{
									int client = iGetBotOfIdlePlayer(param1);
									if(client != 0)
									{
										RemovePoints(param1, g_ePlayer[param1].ItemCost);
										CheatCommand(client, g_ePlayer[param1].Command);
									}
								}
								case 2: 
								{
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									CheatCommand(param1, g_ePlayer[param1].Command);
								}
							}
						}
					}
				}	
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildHealthMenu(param1);

			strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
			g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iUpgradeConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[2];
			menu.GetItem(param2, item, sizeof item);
			switch (item[0]) {
				case 'n': {
					BuildUpgradeMenu(param1);
					strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
					g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
				}

				case 'y': {
					if (HasEnoughPoints(param1, g_ePlayer[param1].ItemCost)) {
						if (strcmp(g_ePlayer[param1].Command, "give ammo") == 0)
						{
							switch (GetClientTeam(param1)) 
							{
								case 1: 
								{
									int client = iGetBotOfIdlePlayer(param1);
									if(client != 0)
									{
										ReloadAmmo(param1, client, g_ePlayer[param1].ItemCost, g_ePlayer[param1].Command);
									}
								}
								case 2: 
								{
									ReloadAmmo(param1, param1, g_ePlayer[param1].ItemCost, g_ePlayer[param1].Command);
								}
							}
							
						}
						else {
							strcopy(g_ePlayer[param1].Bought, sizeof Player::Bought, g_ePlayer[param1].Command);
							g_ePlayer[param1].BoughtCost = g_ePlayer[param1].ItemCost;

							switch (GetClientTeam(param1)) 
							{
								case 1: 
								{
									int client = iGetBotOfIdlePlayer(param1);
									if(client != 0)
									{
										RemovePoints(param1, g_ePlayer[param1].ItemCost);
										CheatCommand(client, g_ePlayer[param1].Command);
									}
								}
								case 2: 
								{
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									CheatCommand(param1, g_ePlayer[param1].Command);
								}
							}
						}
					}
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildUpgradeMenu(param1);

			strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
			g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
		}
	
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void ReloadAmmo(int client, int victim, int cost, const char[] item) {
	int weapon = GetPlayerWeaponSlot(victim, 0);
	if (weapon <= MaxClients || !IsValidEntity(weapon)) {
		PrintToChat(client, "%s %T", MSGTAG, "Primary Warning", client);
		return;
	}

	int m_iPrimaryAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (m_iPrimaryAmmoType == -1)
		return;

	char cls[32];
	GetEntityClassname(weapon, cls, sizeof cls);
	if (strcmp(cls, "weapon_rifle_m60") == 0) {
		static ConVar cM60;
		if (!cM60)
			cM60 = FindConVar("ammo_m60_max");

		SetEntProp(weapon, Prop_Send, "m_iClip1", L4D2_GetIntWeaponAttribute(cls, L4D2IWA_ClipSize));
		SetEntProp(victim, Prop_Send, "m_iAmmo", cM60.IntValue, _, m_iPrimaryAmmoType);
	}
	else if (strcmp(cls, "weapon_grenade_launcher") == 0) {
		static ConVar cGrenadelau;
		if (!cGrenadelau)
			cGrenadelau = FindConVar("ammo_grenadelauncher_max");

		SetEntProp(weapon, Prop_Send, "m_iClip1", L4D2_GetIntWeaponAttribute(cls, L4D2IWA_ClipSize));
		SetEntProp(victim, Prop_Send, "m_iAmmo", cGrenadelau.IntValue, _, m_iPrimaryAmmoType);
	}
	else
		CheatCommand(victim, item);

	RemovePoints(client, cost);
}

int iInfectedConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[2];
			menu.GetItem(param2, item, sizeof item);
			switch (item[0]) {
				case 'n': {
					BuildBuyMenu(param1);
					strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
					g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
				}

				case 'y': {
					if (!HasEnoughPoints(param1, g_ePlayer[param1].ItemCost))
						return 0;

					int pos;
					char cmd[32], arg[32];
					if ((pos = SplitString(g_ePlayer[param1].Command, " ", cmd, sizeof cmd)) == -1)
						strcopy(cmd, sizeof cmd, g_ePlayer[param1].Command);
					else {
						strcopy(arg, sizeof arg, g_ePlayer[param1].Command[pos]);
						TrimString(arg);
					}

					if (arg[0] == '\0' && strcmp(cmd, "suicide") == 0) {
						if (!PerformSuicide(param1))
							return 0;
					}
					else {
						if (strcmp(arg, "health") == 0) {
							if (!IsPlayerAlive(param1))
								return 0;
						}
						else if (strcmp(cmd, "z_spawn_old") == 0) {
							if (strcmp(arg, "tank") == 0) {
								if (ReachedTankLimit(param1))
									return 0;
							}
							else if (strncmp(arg, "witch", 5) == 0) {
								if (ReachedWitchLimit(param1))
									return 0;
							}

							if (arg[0] != 'm' && arg[0] != 'w') {
								if (IsPlayerAlive(param1))
									return 0;
					
								static StringMap zombieClass;
								if (!zombieClass)
									zombieClass = InitZombieClass(zombieClass);

								int class;
								zombieClass.GetValue(arg, class);
								if (class) {
									L4D_SetClass(param1, class);
									L4D_State_Transition(param1, STATE_GHOST);
									if (GetEntProp(param1, Prop_Send, "m_zombieClass") != class)
										L4D_SetClass(param1, class);

									if (!IsPlayerAlive(param1) || !GetEntProp(param1, Prop_Send, "m_isGhost", 1) || GetEntProp(param1, Prop_Send, "m_zombieClass") != class)
										return 0;

									strcopy(g_ePlayer[param1].Bought, sizeof Player::Bought, g_ePlayer[param1].Command);
									g_ePlayer[param1].BoughtCost = g_ePlayer[param1].ItemCost;
									RemovePoints(param1, g_ePlayer[param1].ItemCost);
									PrintToChatAll("\x04注意：%N当内鬼啦！", param1); //【注释：我加这里试试】
									PrintHintTextToAll("注意：%N当内鬼啦！", param1);	
								}
								return 0;
							}
						}
						CheatCommandEx(param1, cmd, arg);
						strcopy(g_ePlayer[param1].Bought, sizeof Player::Bought, g_ePlayer[param1].Command);
						g_ePlayer[param1].BoughtCost = g_ePlayer[param1].ItemCost;
						RemovePoints(param1, g_ePlayer[param1].ItemCost);
					}
				}
			}
		}

		case MenuAction_Cancel: {
			strcopy(g_ePlayer[param1].Command, sizeof Player::Command, g_ePlayer[param1].Bought);
			g_ePlayer[param1].ItemCost = g_ePlayer[param1].BoughtCost;
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

bool ReachedTankLimit(int client) {
	if (g_eGeneral.Counter[TankSpawned] >= g_eGeneral.cSettings[SettingTankLimit].IntValue) {
		PrintToChat(client,  "%T", "Tank Limit", client);
		return true;
	}
	g_eGeneral.Counter[TankSpawned]++;
	return false;
}

bool ReachedWitchLimit(int client) {
	if (g_eGeneral.Counter[WitchSpawned] >= g_eGeneral.cSettings[SettingWitchLimit].IntValue) {
		PrintToChat(client,  "%T", "Witch Limit", client);
		return true;
	}
	g_eGeneral.Counter[WitchSpawned]++;
	return false;
}

StringMap InitZombieClass(StringMap zombieClass) {
	zombieClass = new StringMap();
	zombieClass.SetValue("smoker", 1);
	zombieClass.SetValue("boomer", 2);
	zombieClass.SetValue("hunter", 3);
	zombieClass.SetValue("spitter", 4);
	zombieClass.SetValue("jockey", 5);
	zombieClass.SetValue("charger", 6);
	zombieClass.SetValue("tank", 8);
	return zombieClass;
}

void CheatCommandEx(int client, const char[] cmd, const char[] arg = "") {
	int bits = GetUserFlagBits(client);
	int flags = GetCommandFlags(cmd);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(cmd, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", cmd, arg);
	SetUserFlagBits(client, bits);
	SetCommandFlags(cmd, flags);
}

void CheatCommand(int client, const char[] cmd) {
	char sCmd[32];
	if (SplitString(cmd, " ", sCmd, sizeof sCmd) == -1)
		strcopy(sCmd, sizeof sCmd, cmd);

	static int bits, flags;
	bits = GetUserFlagBits(client);
	flags = GetCommandFlags(sCmd);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(sCmd, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, cmd);
	SetUserFlagBits(client, bits);
	SetCommandFlags(sCmd, flags);
	
	if (strcmp(sCmd, "give") == 0 && strcmp(cmd[5], "health") == 0) {
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	}
}

void BuildSpecialMenu(int client) {
	char info[32];
	Menu menu = new Menu(iSpecialMenuHandler);
	FormatEx(info, sizeof info,"%T", "Points Left", client, g_ePlayer[client].PlayerPoints);
	menu.SetTitle(info);
	menu.AddItem("h", "杀特回血");
	if (g_bWeaponHandling)
		menu.AddItem("r", "战斗加速");
	if (g_eSpecial.cfree_control.IntValue > -1)
		menu.AddItem("j", "免疫控制");//【免疫特感加了这里】
	if (g_eSpecial.cplayer_teleport.IntValue > -1)
		menu.AddItem("t", "传送自己");//【传送自己加了这里】
	if (g_eSpecial.cweapon_reload.IntValue > -1)
		menu.AddItem("e", "免换弹夹");//【免换弹夹加了这里】
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iSpecialMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[2];
			menu.GetItem(param2, item, sizeof item);
			switch (item[0]) {
				case 'h':
					HealthLeechMenu(param1);
			
				case 'r':
					SpeedUpRealodMenu(param1);

				case 'j'://【免疫特感加了这里】
					DisplayIgnoreAbilityMenu(param1,g_eSpecial.cfree_control.IntValue);

				case 't'://【传送自己加了这里】
					DisplayPlayerTeleportList(param1);

				case 'e'://【免换弹夹加了这里】
					DisplayWeaponReloadMenu(param1);
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildBuyMenu(param1);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}
//【免换弹夹加了这里】
void DisplayWeaponReloadMenu(int client) 
{
	char info[32];
	Menu menu = new Menu(MenuWeaponReloadHandler);
	menu.SetTitle("消耗: %d (仅本关有效)[%s]", g_eSpecial.cweapon_reload.IntValue, g_bWeaponFire[client] ? "已开启" : "已关闭");
	FormatEx(info, sizeof info,"%T", "Yes", client);
	menu.AddItem("y", info);
	FormatEx(info, sizeof info,"%T", "No", client);
	menu.AddItem("n", info);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int MenuWeaponReloadHandler(Menu menu, MenuAction action, int param1, int param2) 
{
	switch (action) 
	{
		case MenuAction_Select: 
		{
			char item[32];
			char info[2][16];
			menu.GetItem(param2, item, sizeof item);
			ExplodeString(item, "|", info, sizeof info, sizeof info[]);
			switch (info[0][0]) 
			{
				case 'n':
					BuildSpecialMenu(param1);

				case 'y': 
				{
					if (IsValidClient(param1)) 
					{
						switch (GetClientTeam(param1)) 
						{
							case 1:
							{
								int target = iGetBotOfIdlePlayer(param1);
								if(target != 0)
								{
									if (HasEnoughPoints(param1, g_eSpecial.cweapon_reload.IntValue)) 
									{
										g_ePlayer[param1].ItemCost = g_eSpecial.cweapon_reload.IntValue;
										RemovePoints(param1, g_ePlayer[param1].ItemCost);

										int iWeapon = GetPlayerWeaponSlot(target, 0);
										if(IsValidEdict(iWeapon))
										{
											char classname[64];
											GetEntityClassname(iWeapon, classname, sizeof(classname));
											SetEntProp(iWeapon, Prop_Send, "m_iClip1", L4D2_GetIntWeaponAttribute(classname, L4D2IWA_ClipSize));
										}

										g_bWeaponFire[param1] = !g_bWeaponFire[param1];
										//PrintToChatAll("\x04已%s \x05%N \x01的\x04特感控制免疫", g_bWeaponFire[param1] ? "启用" : "禁用", param1);
										PrintToChatAll("\x04%N \x05的免换弹夹为\x01[\04%s\x01]", param1, g_bWeaponFire[param1] ? "开启" : "关闭");
									}
									else
										PrintToChat(param1, "[提示]点数不足%d,购买免换弹夹失败.", g_ePlayer[param1].ItemCost);
								}
								
							}
							case 2:
							{
								if (HasEnoughPoints(param1, g_eSpecial.cweapon_reload.IntValue)) 
								{
									g_ePlayer[param1].ItemCost = g_eSpecial.cweapon_reload.IntValue;
									RemovePoints(param1, g_ePlayer[param1].ItemCost);

									int iWeapon = GetPlayerWeaponSlot(param1, 0);
									if(IsValidEdict(iWeapon))
									{
										char classname[64];
										GetEntityClassname(iWeapon, classname, sizeof(classname));
										SetEntProp(iWeapon, Prop_Send, "m_iClip1", L4D2_GetIntWeaponAttribute(classname, L4D2IWA_ClipSize));
									}

									g_bWeaponFire[param1] = !g_bWeaponFire[param1];
									//PrintToChatAll("\x04已%s \x05%N \x01的\x04特感控制免疫", g_bWeaponFire[param1] ? "启用" : "禁用", param1);
									PrintToChatAll("\x04%N \x05的免换弹夹为\x01[\04%s\x01]", param1, g_bWeaponFire[param1] ? "开启" : "关闭");
								}
								else
									PrintToChat(param1, "[提示]点数不足%d,购买免换弹夹失败.", g_ePlayer[param1].ItemCost);
							}
						}
					}
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildSpecialMenu(param1);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

//【传送自己加了这里】
void DisplayPlayerTeleportList(int client) { //【传送自己加了这里】
	char info[32];
	char disp[32];
	Menu menu = new Menu(MenuPlayerTeleportListHandler);
	FormatEx(info, sizeof info,"%T", "Select Player", client);
	menu.SetTitle("%s", info);
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2) 
		{
			int iBot = IsClientIdle(i);
			if(iBot != 0)
			{
				if(iBot == client)
					continue;
				
				FormatEx(info, sizeof info, "%d", GetClientUserId(iBot));
				FormatEx(disp, sizeof disp, "%s", GetTrueName(i));
			}
			else
			{
				if (IsPlayerAlive(i))
				{
					if(i == client)
						continue;
					
					FormatEx(info, sizeof info, "%d", GetClientUserId(i));
					FormatEx(disp, sizeof disp, "%s", GetTrueName(i));
				}
			}
			menu.AddItem(info, disp);
		}
	}
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int MenuPlayerTeleportListHandler(Menu menu, MenuAction action, int param1, int param2) { //【免疫特感加了这里】
	switch (action) 
	{
		case MenuAction_Select: 
		{
			char item[32];
			
			//char info[2][16];
			menu.GetItem(param2, item, sizeof item);
			//ExplodeString(item, "|", info, 2, sizeof info[]);
			int victim = GetClientOfUserId(StringToInt(item));
			if (IsValidClient(victim)) 
			{
				IsConfirmTraitorMenu(param1, victim);
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildSpecialMenu(param1);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void IsConfirmTraitorMenu(int client, int victim) 
{
	char info[32];
	char trans[32];
	char temp[2][16];
	Menu menu = new Menu(MenuConfirmTraitorHandler);
	FormatEx(info, sizeof info,"%T", "Cost", client, g_eSpecial.cplayer_teleport.IntValue);
	menu.SetTitle(info);
	IntToString(GetClientUserId(victim), temp[1], sizeof temp[]);
	strcopy(temp[0], sizeof temp[], "y");
	ImplodeStrings(temp, sizeof temp, "|", info, sizeof info);
	FormatEx(trans, sizeof trans, "%T", "Yes", client);
	menu.AddItem(info, trans);
	strcopy(temp[0], sizeof temp[], "n");
	ImplodeStrings(temp, sizeof temp, "|", info, sizeof info);
	FormatEx(trans, sizeof trans, "%T", "No", client);
	menu.AddItem(info, trans);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int MenuConfirmTraitorHandler(Menu menu, MenuAction action, int param1, int param2) 
{
	switch (action) 
	{
		case MenuAction_Select: 
		{
			char item[32];
			char info[2][16];
			menu.GetItem(param2, item, sizeof item);
			ExplodeString(item, "|", info, sizeof info, sizeof info[]);
			switch (info[0][0]) 
			{
				case 'n':
					DisplayPlayerTeleportList(param1);

				case 'y': 
				{
					int victim  = GetClientOfUserId(StringToInt(info[1]));
					if (IsValidClient(victim)) 
					{
						switch (GetClientTeam(victim)) 
						{
							case 1:
							{
								int target = iGetBotOfIdlePlayer(victim);
								if(target != 0)
								{
									if (HasEnoughPoints(param1, g_eSpecial.cplayer_teleport.IntValue)) 
									{
										g_ePlayer[param1].ItemCost = g_eSpecial.cplayer_teleport.IntValue;
										RemovePoints(param1, g_ePlayer[param1].ItemCost);

										float vec[3];
										char name[32];
										GetClientName(target, name, sizeof name);
										GetClientAbsOrigin(target, vec);
										TeleportEntity(param1, vec, NULL_VECTOR, NULL_VECTOR);
										PrintToChat(param1, "\x04[提示]\x05已传送到\x03%N\x05身边.", target);
									}
									else
										PrintToChat(param1, "[提示]点数不足%d,传送失败.", g_ePlayer[param1].ItemCost);
								}
								
							}
							case 2:
							{
								if (HasEnoughPoints(param1, g_eSpecial.cplayer_teleport.IntValue)) 
								{
									g_ePlayer[param1].ItemCost = g_eSpecial.cplayer_teleport.IntValue;
									RemovePoints(param1, g_ePlayer[param1].ItemCost);

									float vec[3];
									char name[32];
									GetClientName(victim, name, sizeof name);
									GetClientAbsOrigin(victim, vec);
									TeleportEntity(param1, vec, NULL_VECTOR, NULL_VECTOR);
									PrintToChat(param1, "\x04[提示]\x05已传送到\x03%N\x05身边.", victim);
								}
								else
									PrintToChat(param1, "[提示]点数不足%d,传送失败.", g_ePlayer[param1].ItemCost);
							}
						}
					}
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				DisplayPlayerTeleportList(param1);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}
//【免疫特感加了这里】
void DisplayIgnoreAbilityMenu(int client, int iValue) { 
	char info[32];
	char trans[32];
	char temp[2][16];
	Menu menu = new Menu(iIgnoreAbilityConfirmMenuHandler);
	FormatEx(info, sizeof info,"%T", "Cost", client, g_ePlayer[client].ItemCost);
	menu.SetTitle("消耗: %d (仅本关有效)[%s]", iValue, g_bIgnoreAbility[client] ? "已开启" : "已关闭");
	IntToString(iValue, temp[1], sizeof temp[]);
	strcopy(temp[0], sizeof temp[], "y");
	ImplodeStrings(temp, sizeof temp, "|", info, sizeof info);
	FormatEx(trans, sizeof trans, "%T", "Yes", client);
	menu.AddItem(info, trans);
	strcopy(temp[0], sizeof temp[], "n");
	ImplodeStrings(temp, sizeof temp, "|", info, sizeof info);
	FormatEx(trans, sizeof trans, "%T", "No", client);
	menu.AddItem(info, trans);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iIgnoreAbilityConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2) { //【免疫特感加了这里】
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			char info[2][16];
			menu.GetItem(param2, item, sizeof item);
			ExplodeString(item, "|", info, 2, sizeof info[]);
			switch (info[0][0]) {
				case 'n':
					BuildSpecialMenu(param1);

				case 'y': {
					if (HasEnoughPoints(param1,StringToInt(info[1]))) {
						RemovePoints(param1,StringToInt(info[1]));
						if (param1 && IsClientInGame(param1)) {
							g_bIgnoreAbility[param1] = !g_bIgnoreAbility[param1];
							//PrintToChatAll("\x04已%s \x05%N \x01的\x04特感控制免疫", g_bIgnoreAbility[param1] ? "启用" : "禁用", param1);
							PrintToChatAll("\x04%N \x05的特感控制免疫为\x01[\04%s\x01]", param1, g_bIgnoreAbility[param1] ? "开启" : "关闭");
						}
					}
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildSpecialMenu(param1);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}
//=========【↓免疫特感加了这里↓】=========
public Action L4D_OnGrabWithTongue(int victim, int attacker) {
	if (!g_bIgnoreAbility[victim])
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action L4D_OnPouncedOnSurvivor(int victim, int attacker) {
	if (!g_bIgnoreAbility[victim])
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action L4D2_OnJockeyRide(int victim, int attacker) {
	if (!g_bIgnoreAbility[victim])
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action L4D2_OnStartCarryingVictim(int victim, int attacker) {
	if (!g_bIgnoreAbility[victim])
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action L4D2_OnPummelVictim(int attacker, int victim) {
	if (!g_bIgnoreAbility[victim])
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
//=========【↑免疫特感加了这里↑】=========

void HealthLeechMenu(int client) {
	Menu menu = new Menu(iHealthLeechMenuHandler);
	menu.SetTitle("当前回血值[%d](仅本关有效)", g_ePlayer[client].LeechHealth);
	if (g_eSpecial.cLeechHealth[0].IntValue > -1)
		menu.AddItem("2", "2");
	if (g_eSpecial.cLeechHealth[1].IntValue > -1)
		menu.AddItem("4", "4");
	if (g_eSpecial.cLeechHealth[2].IntValue > -1)
		menu.AddItem("6", "6");
	if (g_eSpecial.cLeechHealth[3].IntValue > -1)
		menu.AddItem("8", "8");
	if (g_eSpecial.cLeechHealth[4].IntValue > -1)
		menu.AddItem("10", "10");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void SpeedUpRealodMenu(int client) {
	Menu menu = new Menu(iSpeedUpRealodMenuHandler);
	menu.SetTitle("当前速率[%.1fx](仅本关有效)", g_ePlayer[client].RealodSpeedUp);
	if (g_eSpecial.cRealodSpeedUp[0].IntValue > -1)
		menu.AddItem("1.5", "1.5x");
	if (g_eSpecial.cRealodSpeedUp[1].IntValue > -1)
		menu.AddItem("2.0", "2.0x");
	if (g_eSpecial.cRealodSpeedUp[2].IntValue > -1)
		menu.AddItem("2.5", "2.5x");
	if (g_eSpecial.cRealodSpeedUp[3].IntValue > -1)
		menu.AddItem("3.0", "3.0x");
	if (g_eSpecial.cRealodSpeedUp[4].IntValue > -1)
		menu.AddItem("3.5", "3.5x");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iHealthLeechMenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[16];
			menu.GetItem(param2, item, sizeof item);
			int value = StringToInt(item);
			switch (value) {
				case 2:
					g_ePlayer[client].ItemCost = g_eSpecial.cLeechHealth[0].IntValue;
				
				case 4:
					g_ePlayer[client].ItemCost = g_eSpecial.cLeechHealth[1].IntValue;
				
				case 6:
					g_ePlayer[client].ItemCost = g_eSpecial.cLeechHealth[2].IntValue;

				case 8:
					g_ePlayer[client].ItemCost = g_eSpecial.cLeechHealth[3].IntValue;

				case 10:
					g_ePlayer[client].ItemCost = g_eSpecial.cLeechHealth[4].IntValue;
			}
			DisplayHealthLeechConfirmMenu(client, item);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildSpecialMenu(client);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iSpeedUpRealodMenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[16];
			menu.GetItem(param2, item, sizeof item);
			float value = StringToFloat(item);
			switch (value) {
				case 1.5:
					g_ePlayer[client].ItemCost = g_eSpecial.cRealodSpeedUp[0].IntValue;
				
				case 2.0:
					g_ePlayer[client].ItemCost = g_eSpecial.cRealodSpeedUp[1].IntValue;
				
				case 2.5:
					g_ePlayer[client].ItemCost = g_eSpecial.cRealodSpeedUp[2].IntValue;

				case 3.0:
					g_ePlayer[client].ItemCost = g_eSpecial.cRealodSpeedUp[3].IntValue;

				case 3.5:
					g_ePlayer[client].ItemCost = g_eSpecial.cRealodSpeedUp[4].IntValue;
			}
			DisplaySpeedUpRealodConfirmMenu(client, item);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				BuildSpecialMenu(client);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void DisplayHealthLeechConfirmMenu(int client, const char[] sValue) {
	char info[32];
	char trans[32];
	char temp[2][16];
	Menu menu = new Menu(iHealthLeechConfirmMenuHandler);
	FormatEx(info, sizeof info,"%T", "Cost", client, g_ePlayer[client].ItemCost);
	menu.SetTitle(info);
	strcopy(temp[1], sizeof temp[], sValue);

	strcopy(temp[0], sizeof temp[], "y");
	ImplodeStrings(temp, sizeof temp, "|", info, sizeof info);
	FormatEx(trans, sizeof trans, "%T", "Yes", client);
	menu.AddItem(info, trans);
	strcopy(temp[0], sizeof temp[], "n");
	ImplodeStrings(temp, sizeof temp, "|", info, sizeof info);
	FormatEx(trans, sizeof trans, "%T", "No", client);
	menu.AddItem(info, trans);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplaySpeedUpRealodConfirmMenu(int client, const char[] sValue) {
	char info[32];
	char trans[32];
	char temp[2][16];
	Menu menu = new Menu(iSpeedUpRealodConfirmMenuHandler);
	FormatEx(info, sizeof info,"%T", "Cost", client, g_ePlayer[client].ItemCost);
	menu.SetTitle(info);
	strcopy(temp[1], sizeof temp[], sValue);

	strcopy(temp[0], sizeof temp[], "y");
	ImplodeStrings(temp, sizeof temp, "|", info, sizeof info);
	FormatEx(trans, sizeof trans, "%T", "Yes", client);
	menu.AddItem(info, trans);
	strcopy(temp[0], sizeof temp[], "n");
	ImplodeStrings(temp, sizeof temp, "|", info, sizeof info);
	FormatEx(trans, sizeof trans, "%T", "No", client);
	menu.AddItem(info, trans);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iHealthLeechConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			char info[2][16];
			menu.GetItem(param2, item, sizeof item);
			ExplodeString(item, "|", info, 2, sizeof info[]);
			switch (info[0][0]) {
				case 'n':
					HealthLeechMenu(param1);

				case 'y': {
					if (HasEnoughPoints(param1, g_ePlayer[param1].ItemCost)) {
						RemovePoints(param1, g_ePlayer[param1].ItemCost);
						g_ePlayer[param1].LeechHealth = StringToInt(info[1]);
						PrintToChatAll("\x04%N \x05的击杀特感回血量调整为\x01[\x04%d\x01]", param1, g_ePlayer[param1].LeechHealth);
					}
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				HealthLeechMenu(param1);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iSpeedUpRealodConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			char info[2][16];
			menu.GetItem(param2, item, sizeof item);
			ExplodeString(item, "|", info, 2, sizeof info[]);
			switch (info[0][0]) {
				case 'n':
					HealthLeechMenu(param1);

				case 'y': {
					if (HasEnoughPoints(param1, g_ePlayer[param1].ItemCost)) {
						RemovePoints(param1, g_ePlayer[param1].ItemCost);
						g_ePlayer[param1].RealodSpeedUp = StringToFloat(info[1]);
						PrintToChatAll("\x04%N \x05的战斗速率调整为\x01[\x04%.1fx\x01]", param1, g_ePlayer[param1].RealodSpeedUp);
					}
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				SpeedUpRealodMenu(param1);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void InitSpecialValue() {
	for (int i = 1; i <= MaxClients; i++) {
		g_ePlayer[i].LeechHealth = 0;
		g_ePlayer[i].RealodSpeedUp = 1.0;
	}
}

enum L4D2WeaponType {
	L4D2WeaponType_Unknown = 0,
	L4D2WeaponType_Pistol,
	L4D2WeaponType_Magnum,
	L4D2WeaponType_Rifle,
	L4D2WeaponType_RifleAk47,
	L4D2WeaponType_RifleDesert,
	L4D2WeaponType_RifleM60,
	L4D2WeaponType_RifleSg552,
	L4D2WeaponType_HuntingRifle,
	L4D2WeaponType_SniperAwp,
	L4D2WeaponType_SniperMilitary,
	L4D2WeaponType_SniperScout,
	L4D2WeaponType_SMG,
	L4D2WeaponType_SMGSilenced,
	L4D2WeaponType_SMGMp5,
	L4D2WeaponType_Autoshotgun,
	L4D2WeaponType_AutoshotgunSpas,
	L4D2WeaponType_Pumpshotgun,
	L4D2WeaponType_PumpshotgunChrome,
	L4D2WeaponType_Molotov,
	L4D2WeaponType_Pipebomb,
	L4D2WeaponType_FirstAid,
	L4D2WeaponType_Pills,
	L4D2WeaponType_Gascan,
	L4D2WeaponType_Oxygentank,
	L4D2WeaponType_Propanetank,
	L4D2WeaponType_Vomitjar,
	L4D2WeaponType_Adrenaline,
	L4D2WeaponType_Chainsaw,
	L4D2WeaponType_Defibrilator,
	L4D2WeaponType_GrenadeLauncher,
	L4D2WeaponType_Melee,
	L4D2WeaponType_UpgradeFire,
	L4D2WeaponType_UpgradeExplosive,
	L4D2WeaponType_BoomerClaw,
	L4D2WeaponType_ChargerClaw,
	L4D2WeaponType_HunterClaw,
	L4D2WeaponType_JockeyClaw,
	L4D2WeaponType_SmokerClaw,
	L4D2WeaponType_SpitterClaw,
	L4D2WeaponType_TankClaw,
	L4D2WeaponType_Gnome
}
// ====================================================================================================
//					WEAPON HANDLING
// ====================================================================================================
public void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier) {
	speedmodifier = SpeedModifier(client, speedmodifier); //send speedmodifier to be modified
}

public void WH_OnStartThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier) {
	speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnReadyingThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier) {
	speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier) {
	speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnGetRateOfFire(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier) {
	switch (weapontype) {
		case L4D2WeaponType_Rifle, L4D2WeaponType_RifleSg552, L4D2WeaponType_SMG, L4D2WeaponType_RifleAk47, L4D2WeaponType_SMGMp5, L4D2WeaponType_SMGSilenced, L4D2WeaponType_RifleM60:
			return;
	}

	speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnDeployModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier) {
	speedmodifier = SpeedModifier(client, speedmodifier);
}

float SpeedModifier(int client, float speedmodifier) {
	if (g_ePlayer[client].RealodSpeedUp > 1.0)
		speedmodifier = speedmodifier * g_ePlayer[client].RealodSpeedUp;

	return speedmodifier;
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
char[] GetTrueName(int client)
{
	char g_sName[32];
	int iBot = IsClientIdle(client);
	
	if(iBot != 0)
		Format(g_sName, sizeof(g_sName), "闲置:%N", iBot);
	else
		GetClientName(client, g_sName, sizeof(g_sName));
	return g_sName;
}
//返回电脑幸存者对应的玩家.
int IsClientIdle(int client)
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}
bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
//随机传送幸存者到其他幸存者身边.
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
void ForceCrouch(int client)
{
	SetEntProp(client, Prop_Send, "m_bDucked", 1);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_DUCKING);
}
//死亡状态.
bool IsAlive(int client)
{
	return !GetEntProp(client, Prop_Send, "m_lifeState");
}