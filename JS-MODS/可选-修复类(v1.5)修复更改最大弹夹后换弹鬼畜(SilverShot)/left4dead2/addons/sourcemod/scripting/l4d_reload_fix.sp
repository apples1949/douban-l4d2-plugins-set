/*
*	Reload Fix - Max Clip Size
*	Copyright (C) 2024 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION		"1.5"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Reload Fix - Max Clip Size
*	Author	:	SilverShot
*	Descrp	:	Fixes glitchy animation when the max clip sized was changed.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=327105
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.5 (21-Apr-2024)
	- Added cvar "l4d_reload_fix_m60" to control if the M60 should be fixed or not, since I encounter no bug with changed clip size.
	- Fixed the Grenade Launcher and M60 playing the reload animation when a modified clip size is full. Thanks to "chungocanh12" for reporting.

1.4 (20-Nov-2023)
	- Fixed not deleting 2 handles. Thanks to "HarryPotter" for reporting.

1.3a (08-Sep-2021)
	- GameData file updated. Wildcarded "CTerrorGun::Reload" to support other plugins detouring this function.
	- Thanks to "vikingo12" for reporting.

1.3 (05-Jul-2021)
	- L4D2: Added support for the "weapon_smg_mp5" weapon. Thanks to "Alexmy" for reporting.

1.2 (29-Jun-2021)
	- L4D2: Added support for the Magnum "weapon_pistol_magnum" pistol.

1.1b (17-Jun-2021)
	- Compatibility update for L4D2's "2.2.1.3" game update. Thanks to "Crasher_3637" for fixing.
	- GameData .txt file updated.

1.1a (24-Sep-2020)
	- Compatibility update for L4D2's "The Last Stand" update.
	- GameData .txt file updated.

1.1 (05-Sep-2020)
	- Now prevents changing anything when the max clip size is unchanged.
	- Added a fix for shotgun reload animation stopping when reloading >= 15 bullets at one time.
	- Thanks to "fbef0102" for reporting.
	- GameData file updated.

1.0 (25-Aug-2020)
	- Initial release.

===================================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>

#define GAMEDATA		"l4d_reload_fix"
#define CLIP_BUG		15

bool g_bLeft4Dead2;
StringMap g_hClipSize;
StringMap g_hDefaults;
ConVar g_hCvarM60;

char g_sWeapons[][] =
{
	"weapon_rifle",
	"weapon_autoshotgun",
	"weapon_hunting_rifle",
	"weapon_smg",
	"weapon_pumpshotgun",
	"weapon_pistol"
};

// From Left4Dhooks - put here to prevent using include and left4dhooks requirement for L4D1.
enum L4D2IntWeaponAttributes
{
	L4D2IWA_Damage,
	L4D2IWA_Bullets,
	L4D2IWA_ClipSize,
	MAX_SIZE_L4D2IntWeaponAttributes
};

native int L4D2_GetIntWeaponAttribute(const char[] weaponName, L4D2IntWeaponAttributes attr);



// ====================================================================================================
//										PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Reload Fix - Max Clip Size",
	author = "SilverShot",
	description = "Fixes glitchy animation when the max clip sized was changed.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=327105"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	if( !g_bLeft4Dead2 )
		MarkNativeAsOptional("L4D2_GetIntWeaponAttribute");

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	if( g_bLeft4Dead2 && LibraryExists("left4dhooks") == false )
	{
		SetFailState("\n==========\nMissing required plugin: \"Left 4 DHooks Direct\".\nRead installation instructions again.\n==========");
	}
}

Handle g_hSDK_Call_AbortReload;
Handle g_hSDK_Call_FinishReload;
Handle g_hSDK_Call_StartReload;

public void OnPluginStart()
{
	g_hCvarM60 = CreateConVar("l4d_reload_fix_m60", "1", "0=关闭, 1=修复M60的重新加载错误问题.", FCVAR_NOTIFY);
	CreateConVar("l4d_reload_fix_version", PLUGIN_VERSION, "Reload Fix - Max Clip Size plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true, "l4d_reload_fix");

	// =========================
	// GAMEDATA
	// =========================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	// =========================
	// SDKCALLS
	// =========================
	StartPrepSDKCall(SDKCall_Entity);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTerrorGun::AbortReload") == false )
		SetFailState("Failed to find offset: CTerrorGun::AbortReload");
	g_hSDK_Call_AbortReload = EndPrepSDKCall();
	if( g_hSDK_Call_AbortReload == null )
		SetFailState("Failed to create SDKCall: CTerrorGun::AbortReload");

	StartPrepSDKCall(SDKCall_Entity);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTerrorGun::FinishReload") == false )
		SetFailState("Failed to find offset: CTerrorGun::FinishReload");
	g_hSDK_Call_FinishReload = EndPrepSDKCall();
	if( g_hSDK_Call_FinishReload == null )
		SetFailState("Failed to create SDKCall: CTerrorGun::FinishReload");

	StartPrepSDKCall(SDKCall_Entity);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTerrorGun::Reload") == false )
		SetFailState("Failed to find offset: CTerrorGun::Reload");
	g_hSDK_Call_StartReload = EndPrepSDKCall();
	if( g_hSDK_Call_StartReload == null )
		SetFailState("Failed to create SDKCall: CTerrorGun::Reload");

	// =========================
	// DETOUR
	// =========================
	Handle hDetour = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Bool, ThisPointer_CBaseEntity);
	if( !hDetour )
		SetFailState("Failed to setup detour handle: CTerrorGun::Reload");

	if( !DHookSetFromConf(hDetour, hGameData, SDKConf_Signature, "CTerrorGun::Reload") )
		SetFailState("Failed to find signature: CTerrorGun::Reload");

	if( !DHookEnableDetour(hDetour, false, OnGunReload) )
		SetFailState("Failed to detour: CTerrorGun::Reload");

	delete hDetour;
	delete hGameData;

	// =========================
	// CLIP SIZE
	// =========================
	g_hDefaults = new StringMap();

	g_hDefaults.SetValue("weapon_rifle",			50);
	g_hDefaults.SetValue("weapon_autoshotgun",		10);
	g_hDefaults.SetValue("weapon_hunting_rifle",	15);
	g_hDefaults.SetValue("weapon_smg",				50);
	g_hDefaults.SetValue("weapon_pumpshotgun",		8);
	g_hDefaults.SetValue("weapon_pistol",			15);

	if( g_bLeft4Dead2 )
	{
		g_hDefaults.SetValue("weapon_pistol_magnum",	8);
		g_hDefaults.SetValue("weapon_rifle_ak47",		40);
		g_hDefaults.SetValue("weapon_rifle_desert",		60);
		g_hDefaults.SetValue("weapon_rifle_sg552",		50);
		g_hDefaults.SetValue("weapon_smg_silenced",		50);
		g_hDefaults.SetValue("weapon_smg_mp5",			50);
		g_hDefaults.SetValue("weapon_shotgun_spas",		10);
		g_hDefaults.SetValue("weapon_shotgun_chrome",	8);
		g_hDefaults.SetValue("weapon_sniper_awp",		20);
		g_hDefaults.SetValue("weapon_sniper_military",	30);
		g_hDefaults.SetValue("weapon_sniper_scout",		15);
		g_hDefaults.SetValue("weapon_grenade_launcher",	1);
		g_hDefaults.SetValue("weapon_rifle_m60",		150);
	}

	// =========================
	// EVENT
	// =========================
	HookEvent("weapon_reload", Event_Reload);
}

public void OnMapStart()
{
	// Get L4D1 weapons max clip size, does not support any servers that dynamically change during gameplay.
	if( !g_bLeft4Dead2 )
	{
		delete g_hClipSize;
		g_hClipSize = new StringMap();

		int index, entity;
		while( index < sizeof(g_sWeapons) )
		{
			entity = CreateEntityByName(g_sWeapons[index]);
			DispatchSpawn(entity);

			g_hClipSize.SetValue(g_sWeapons[index], GetEntProp(entity, Prop_Send, "m_iClip1"));
			RemoveEdict(entity);
			index++;
		}
	}
}

void Event_Reload(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if( weapon == -1 ) return;

	// Validate shotgun only
	static char classname[32];
	GetEdictClassname(weapon, classname, sizeof classname);
	if(
		(strcmp(classname[7], "autoshotgun") == 0 ||
		strcmp(classname[7], "pumpshotgun") == 0) ||
		(g_bLeft4Dead2 &&
		(strcmp(classname[7], "shotgun_spas") == 0 ||
		strcmp(classname[7], "shotgun_chrome") == 0))
	)
	{
		int ammo;
		if( g_bLeft4Dead2 )
		{
			ammo = L4D2_GetIntWeaponAttribute(classname, L4D2IWA_ClipSize);
		}
		else
		{
			if( !g_hClipSize.GetValue(classname, ammo) )
				return;
		}

		// Ammo to refill is greater than bug size
		if( ammo - GetEntProp(weapon, Prop_Send, "m_iClip1") >= CLIP_BUG )
		{
			CreateTimer(0.5, TimerReload, EntIndexToEntRef(weapon), TIMER_REPEAT);
		}
	}
}

Action TimerReload(Handle timer, int weapon)
{
	// Valid shotgun weapon and is reloading
	if( (weapon = EntRefToEntIndex(weapon)) != INVALID_ENT_REFERENCE && GetEntProp(weapon, Prop_Send, "m_bInReload") )
	{
		// Verify equipped in hand
		int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
		if( weapon != GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") )
			return Plugin_Stop;

		static char classname[32];
		GetEdictClassname(weapon, classname, sizeof classname);

		// Get max clip ammo
		int ammo;
		if( g_bLeft4Dead2 )
		{
			ammo = L4D2_GetIntWeaponAttribute(classname, L4D2IWA_ClipSize);
		}
		else
		{
			if( !g_hClipSize.GetValue(classname, ammo) )
				return Plugin_Stop;
		}

		// Clip size > than bug and clip not full
		if( ammo >= CLIP_BUG && ammo != GetEntProp(weapon, Prop_Send, "m_iClip1") )
		{
			// Have we reached the bug, if so abort and start reload again.
			if( GetEntProp(weapon, Prop_Send, "m_shellsInserted") >= CLIP_BUG )
			{
				SDKCall(g_hSDK_Call_AbortReload, weapon);
				SDKCall(g_hSDK_Call_FinishReload, weapon);
				SDKCall(g_hSDK_Call_StartReload, weapon);
				return Plugin_Stop;
			} else {
				return Plugin_Continue;
			}
		}
	}

	return Plugin_Stop;
}

MRESReturn OnGunReload(int pThis, Handle hReturn, Handle hParams)
{
	// Validate weapon
	if( pThis > MaxClients )
	{
		int client = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");

		// Validate weapon owner
		if( client > 0 && client <= MaxClients && !IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) )
		{
			// Validate weapon in hand
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if( weapon > MaxClients && pThis == weapon )
			{
				static char classname[32];
				GetEdictClassname(weapon, classname, sizeof classname);

				// Get max clip ammo
				int ammo;
				if( g_bLeft4Dead2 )
				{
					ammo = L4D2_GetIntWeaponAttribute(classname, L4D2IWA_ClipSize);
				}
				else
				{
					if( !g_hClipSize.GetValue(classname, ammo) )
						return MRES_Ignored;
				}

				if( ammo != -1 )
				{
					// Verify clip size is not stock clip size
					int main;
					if( !g_hDefaults.GetValue(classname, main) )
						return MRES_Ignored;

					if( main != ammo )
					{
						// Dual wielding pistol doubles ammo size
						if( GetEntProp(weapon, Prop_Send, "m_isDualWielding") )
							ammo *= 2;

						// Is the clip full
						if( ammo == GetEntProp(weapon, Prop_Send, "m_iClip1") )
						{
							// Fix animation glitch
							SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.1);

							// Stop reloading GL
							if( strcmp(classname[7], "grenade_launcher") == 0 || (g_hCvarM60.BoolValue && strcmp(classname[7], "rifle_m60") == 0) )
							{
								RemovePlayerItem(client, weapon);
								EquipPlayerWeapon(client, weapon);
							}

							// Stop reloading
							DHookSetReturn(hReturn, 0);
							return MRES_Supercede;
						}
					}
				}
			}
		}
	}

	return MRES_Ignored;
}