#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#define WEPSLOT_PRIMARY 0
#define WEPSLOT_SECONDARY 1
#define WEPSLOT_KNIFE 2
#define WEPSLOT_NADE 3
#define WEPSLOT_BOMB 4
#define WEPSLOT_ITEM 5

new m_iClip1 = -1;
new m_iAmmo = -1;
new g_iOffsetState = -1;
new g_iOffsetOwner = -1;

new Handle:g_hWeaponSwitch;

new g_iMaxPrimaryClip[MAXPLAYERS + 1];
new g_iMaxPrimaryAmmo[MAXPLAYERS + 1];
new g_iMaxSecondaryClip[MAXPLAYERS + 1];
new g_iMaxSecondaryAmmo[MAXPLAYERS + 1];


// ----- Events ----- //


public OnPluginStart()
{
    RegConsoleCmd("aio_strip_meh", Command_StripMeh);
    HookEvent("player_spawn", OnPlayerSpawn);

    m_iClip1 = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
    m_iAmmo = FindSendPropInfo("CCSPlayer", "m_iAmmo");
    g_iOffsetState = FindSendPropInfo("CTFMinigun", "m_iWeaponState");
    g_iOffsetOwner = FindSendPropInfo("CBasePlayer", "m_hActiveWeapon");

    if (m_iAmmo == -1)
        m_iAmmo = FindSendPropInfo("CTFPlayer", "m_iAmmo");

    new Handle:hConf = LoadGameConfigFile("sdkhooks.games");
    if(hConf == INVALID_HANDLE)
    {
        SetFailState("Could not read sdkhooks.games gamedata.");
        return;
    }

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "Weapon_Switch");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    g_hWeaponSwitch = EndPrepSDKCall();

    if(g_hWeaponSwitch == INVALID_HANDLE)
    {
        SetFailState("Could not initialize call for CTFPlayer::Weapon_Switch");
        CloseHandle(hConf);
        return;
    }
}

public Action:Command_StripMeh(client, args)
{
    if (client <= 0 ||
        !IsClientInGame(client) ||
        !IsPlayerAlive(client))
        return Plugin_Handled;

    new wepid = -1;
    for (new i = 0; i <= WEPSLOT_SECONDARY; i++)
    {
        if ((wepid = GetPlayerWeaponSlot(client, i)) != -1)
        {
            StripWeaponAmmo(client, wepid, i);
        }
    }

    return Plugin_Handled;
}


public OnPlayerSpawn(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new primary = GetPlayerWeaponSlot(client, WEPSLOT_PRIMARY);
    new secondary = GetPlayerWeaponSlot(client, WEPSLOT_SECONDARY);

    if (primary > 0)
    {
        g_iMaxPrimaryAmmo[client] = GetWeaponAmmo(primary, client);
        g_iMaxPrimaryClip[client] = GetWeaponClip(primary);
    }

    if (secondary > 0)
    {
        g_iMaxSecondaryAmmo[client] = GetWeaponAmmo(secondary, client);
        g_iMaxSecondaryClip[client] = GetWeaponClip(secondary);
    }
}


public OnGameFrame()
{
    decl String:strClass[30];
    decl Float:origin[3];

    for(new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !IsPlayerAlive(i))
            continue;

        new iWeapon = GetPlayerWeaponSlot(i, WEPSLOT_KNIFE);
        new iActive = GetActiveWeapon(i);
        
        if(iWeapon != iActive &&
           iWeapon > 0 &&
            IsValidEntity(iWeapon) &&
            iActive > 0 && 
            IsValidEntity(iActive))
        {
            GetClientAbsOrigin(i, origin);

            // Don't even know what fucking map this is. God damnit.
            // if (origin[0] > -4008 && origin[0] < -2640 &&
                // origin[1] > 690 && origin[1] < 2060 &&
                // origin[2] > 880 && origin[2] < 1200)

            // trade_minecraft_2014_v1
            if (origin[0] > -510 && origin[0] < 510 &&
                origin[1] > -1050 && origin[1] < -100 &&
                origin[2] > -450 && origin[2] < -100)
            {
                GetEdictClassname(iActive, strClass, sizeof(strClass));

                if(strcmp(strClass, "tf_weapon_minigun") == 0)
                {
                    ResetMinigun(iActive, 0);
                    TF2_RemoveCondition(i, TFCond_Slowed);
                }

                SetActiveWeapon(i, iWeapon);
            }
        }
    }
}


// ----- Help Functions ----- //


SetActiveWeapon(client, weapon)
{
    SDKCall(g_hWeaponSwitch, client, weapon, 0);
}

GetActiveWeapon(client)
{
    return GetEntDataEnt2(client, g_iOffsetOwner);
}

ResetMinigun(weapon, iState)
{
    // 0 - idle | 1 - lowering | 2 - shooting | 3 - reving | 4 - click click
    SetEntData(weapon, g_iOffsetState, iState);
}

GetWeaponClip(weapon)
{
    return GetEntData(weapon, m_iClip1);
}

GetWeaponAmmo(weapon, owner)
{
    return GetEntData(owner, m_iAmmo +
                      GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType") * 4);
}

SetWeaponAmmo(weapon, owner, clip=0, ammo=-1)
{
    if (weapon <= 0 || owner > MaxClients || owner <= 0 || !IsClientInGame(owner))
        return;

    if (clip > -1)
        SetEntData(weapon, m_iClip1, clip);

    if (ammo > -1)
        SetEntData(owner, m_iAmmo +
                   GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType") * 4,
                   ammo, _, true);
}

stock StripWeaponAmmo(client, wepid, slot)
{
    if (slot == WEPSLOT_PRIMARY)
        SetWeaponAmmo(wepid, client, min(0, g_iMaxPrimaryClip[client]), min(0, g_iMaxPrimaryAmmo[client]));

    else if (slot == WEPSLOT_SECONDARY)
        SetWeaponAmmo(wepid, client, min(0, g_iMaxSecondaryClip[client]), min(0, g_iMaxSecondaryAmmo[client]));
}

min(x, y)
{
    return x > y ? y : x;
}
