#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

ConVar g_hMaxReviveCount, g_hSoundFlags;
int g_iMaxReviveCount, g_iSoundHeartFlags, g_iSoundThumpFlags, g_iSoundInjuryFlags;

public Plugin myinfo = 
{
	name = "Sound Manipulation: REWORK",
	author = "Sir",
	description = "Allows control over certain sounds",
	version = "1.0",
	url = "The webternet."
}

public void OnPluginStart()
{
	g_hMaxReviveCount	= FindConVar("survivor_max_incapacitated_count");
	g_hSoundHeartFlags	= CreateConVar("l4d2_sound_heartbeatloop_flags", "1", "阻止幸存者不正常的心跳声音. 0=禁用, 1=启用.");
	g_hSoundThumpFlags	= CreateConVar("l4d2_sound_vehicle_impact_heavy_flags", "1", "阻止幸存者死亡时的重击声音. 0=禁用, 1=启用.");
	g_hSoundInjuryFlags	= CreateConVar("l4d2_sound_incapacitatedinjury_flags", "1", "阻止幸存者死亡后播放的音乐. 0=禁用, 1=启用.");

	hMaxReviveCount.AddChangeHook(FlagsChanged);
	cvarSoundFlags.AddChangeHook(FlagsChanged);

	AutoExecConfig(true, "l4d2_sound_manipulation");
	
	AddNormalSoundHook(SoundHook);
}

public void OnConfigsExecuted()
{
	cvarSoundFlagsConfigs();
}

public void FlagsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    cvarSoundFlagsConfigs();
}

void cvarSoundFlagsConfigs()
{
	g_iMaxReviveCount = g_hMaxReviveCount.IntValue;
	g_iSoundHeartFlags = g_hSoundHeartFlags.IntValue;
	g_iSoundThumpFlags = g_hSoundThumpFlags.IntValue;
	g_iSoundInjuryFlags = g_hSoundInjuryFlags.IntValue;
}

public Action SoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (g_iSoundFlags <= 0)
		return Plugin_Continue;

	if (g_iMaxReviveCount == 1 && g_iMaxReviveCount <= 0)
	{
		if (StrEqual(sample, "player/heartbeatloop.wav", false))//阻止心跳声.
			return Plugin_Stop;
	}
	if (g_iMaxReviveCount == 1)
	{
		if (StrContains(sample, "vehicle_impact_heavy") != -1)//阻止重击声音.
			return Plugin_Stop;
	}
	if (g_iMaxReviveCount == 1)
	{
		if (StrContains(sample, "incapacitatedinjury", false) != -1)//阻止死亡后的声音.
			return Plugin_Stop;
	}
	return Plugin_Continue;
}

