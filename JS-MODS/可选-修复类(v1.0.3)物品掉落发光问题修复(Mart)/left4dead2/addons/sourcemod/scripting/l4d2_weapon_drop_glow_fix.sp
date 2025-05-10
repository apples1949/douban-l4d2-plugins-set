/**
// ====================================================================================================
Change Log:

1.0.3 (25-December-2021)
    - Changed WeaponEquipPost to weapon_drop event.
    - Fixed weapons glowing on hands. (thanks "Tonblader" for reporting)

1.0.2 (08-March-2021)
    - Fixed invalid weapon index on SDKHook_WeaponSwitch/Post (thanks "HarryPotter" for reporting)

1.0.1 (17-December-2020)
    - Renamed the plugin.
    - Changed Use/UsePost for WeaponEquip/WeaponEquipPost hooks.
    - Fixed glow disappearing while using "take a break" holding an item (thanks "HarryPotter" for reporting)
    - Added support for all equipable items.

1.0.0 (28-November-2020)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D2] Weapon Drop Glow Fix"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Fix glow disappearing from a weapon when player dies or take a break while holding it"
#define PLUGIN_VERSION                "1.0.3"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=328841"

// ====================================================================================================
// Plugin Info
// ====================================================================================================
public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = PLUGIN_URL
}

// ====================================================================================================
// Includes
// ====================================================================================================
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// ====================================================================================================
// Pragmas
// ====================================================================================================
#pragma semicolon 1
#pragma newdecls required

// ====================================================================================================
// Cvar Flags
// ====================================================================================================
#define CVAR_FLAGS                    FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION     FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY

// ====================================================================================================
// Filenames
// ====================================================================================================
#define CONFIG_FILENAME               "l4d2_weapon_drop_glow_fix"

// ====================================================================================================
// Defines
// ====================================================================================================
#define MAXENTITIES                   2048

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
ConVar g_hCvar_Enabled;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
bool g_bEventsHooked;
bool g_bCvar_Enabled;

// ====================================================================================================
// client - Plugin Variables
// ====================================================================================================
bool gc_bWeaponEquipHooked[MAXPLAYERS+1];

// ====================================================================================================
// entity - Plugin Variables
// ====================================================================================================
int ge_iGlowType[MAXENTITIES+1] = { -1, ... };

// ====================================================================================================
// Plugin Start
// ====================================================================================================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion engine = GetEngineVersion();

    if (engine != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "This plugin only runs in \"Left 4 Dead 2\" game");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

/****************************************************************************************************/

public void OnPluginStart()
{
    CreateConVar("l4d2_weapon_drop_glow_fix_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled = CreateConVar("l4d2_weapon_drop_glow_fix_enable", "1", "启用物品掉落发光修复. 0=禁用, 1=启用.", CVAR_FLAGS, true, 0.0, true, 1.0);

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d2_weapon_drop_glow_fix", CmdPrintCvars, ADMFLAG_ROOT, "Print the plugin related cvars and their respective values to the console.");
}

/****************************************************************************************************/

public void OnConfigsExecuted()
{
    GetCvars();

    HookEvents();

    LateLoad();
}

/****************************************************************************************************/

void Event_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GetCvars();

    HookEvents();
}

/****************************************************************************************************/

void GetCvars()
{
    g_bCvar_Enabled = g_hCvar_Enabled.BoolValue;
}

/****************************************************************************************************/

void LateLoad()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client))
            continue;

        OnClientPutInServer(client);
    }
}

/****************************************************************************************************/

public void OnClientPutInServer(int client)
{
    if (gc_bWeaponEquipHooked[client])
        return;

    gc_bWeaponEquipHooked[client] = true;
    SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
}

/****************************************************************************************************/

public void OnClientDisconnect(int client)
{
    gc_bWeaponEquipHooked[client] = false;
}

/****************************************************************************************************/

public void OnEntityDestroyed(int entity)
{
    if (entity < 0)
        return;

    ge_iGlowType[entity] = -1;
}

/****************************************************************************************************/

void HookEvents()
{
    if (g_bCvar_Enabled && !g_bEventsHooked)
    {
        g_bEventsHooked = true;

        HookEvent("weapon_drop", Event_WeaponDrop);

        return;
    }

    if (!g_bCvar_Enabled && g_bEventsHooked)
    {
        g_bEventsHooked = false;

        UnhookEvent("weapon_drop", Event_WeaponDrop);

        return;
    }
}

/****************************************************************************************************/

Action OnWeaponEquip(int client, int weapon)
{
    if (!g_bCvar_Enabled)
        return Plugin_Continue;

    if (!IsValidEntity(weapon))
        return Plugin_Continue;

    if (ge_iGlowType[weapon] != -1) // "take a break" bug fix
        return Plugin_Continue;

    ge_iGlowType[weapon] = GetEntProp(weapon, Prop_Send, "m_iGlowType");

    return Plugin_Continue;
}

/****************************************************************************************************/

void Event_WeaponDrop(Event event, const char[] name, bool dontBroadcast)
{
    int entity = event.GetInt("propid");

    if (ge_iGlowType[entity] != -1)
        SetEntProp(entity, Prop_Send, "m_iGlowType", ge_iGlowType[entity]);
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "-------------- Plugin Cvars (l4d2_weapon_drop_glow_fix) --------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d2_weapon_drop_glow_fix_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d2_weapon_drop_glow_fix_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");

    return Plugin_Handled;
}