#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#pragma semicolon 1

#define CS_SLOT_PISTOL 1
#define CS_SLOT_KNIFE 2
#define MSG_PREFIX "\x01[\x04HG Items\x01]\x04"

new g_iPlayerKnives[MAXPLAYERS + 1];
new Handle:g_hKnifeCookie = INVALID_HANDLE;

new m_iAmmo = -1;
new m_iClip1 = -1;

public OnPluginStart()
{
    HookEvent("item_pickup", OnItemPickup, EventHookMode_Post);
    HookEvent("player_spawn", OnPlayerSpawn);

    RegConsoleCmd("sm_knife", Command_SelectKnife);
    RegConsoleCmd("sm_knives", Command_SelectKnife);

    g_hKnifeCookie = RegClientCookie("hg_premium_knife", "Premium Knife", CookieAccess_Public);

    m_iAmmo = FindSendPropInfo("CCSPlayer", "m_iAmmo");
    m_iClip1 = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
}

public OnClientPutInServer(client)
{
    g_iPlayerKnives[client] = 0;
}

public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (GetUserFlagBits(client))
    {
        decl String:knife[8];
        GetClientCookie(client, g_hKnifeCookie, knife, sizeof(knife));

        g_iPlayerKnives[client] = StringToInt(knife);
    }

    else
    {
        g_iPlayerKnives[client] = 0;
    }
}

public Action:OnItemPickup(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (g_iPlayerKnives[client] == 0)
        return Plugin_Continue;

    decl String:sWeapon[64];
    GetEventString(event, "item", sWeapon, sizeof(sWeapon));

    if (StrContains(sWeapon, "knife", false) >= 0)
    {
        CreateTimer(0.1, Timer_GiveKnife, client);
    }

    return Plugin_Continue;
}

public Action:GNIEcon_OnGiveNamedItem(client, iDefIndex, iTeam, iLoadoutSlot, const String:szItem[])
{
    if (StrContains(szItem, "knife") >= 0)
        return Plugin_Handled;

    return Plugin_Continue;
}

public Action:Timer_GiveKnife(Handle:timer, any:client)
{
    new iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);
    if (iWeapon != -1)
    {
        new iItem;

        RemovePlayerItem(client, iWeapon);
        AcceptEntityInput(iWeapon, "kill");

        switch(g_iPlayerKnives[client])
        {
            case 1: {iItem = GivePlayerItem(client, "weapon_bayonet");}
            case 2: {iItem = GivePlayerItem(client, "weapon_knife_flip");}
            case 3: {iItem = GivePlayerItem(client, "weapon_knife_gut");}
            case 4: {iItem = GivePlayerItem(client, "weapon_knife_karambit");}
            case 5: {iItem = GivePlayerItem(client, "weapon_knife_m9_bayonet");}
            case 6: {iItem = GivePlayerItem(client, "weapon_knife_tactical");}
            case 7: {iItem = GivePlayerItem(client, "weapon_knife_t");}
            case 8: {iItem = GivePlayerItem(client, "weapon_knifegg");}
            case 9: {iItem = GivePlayerItem(client, "weapon_knife_butterfly");}
            default: {return Plugin_Continue;}
        }

        EquipPlayerWeapon(client, iItem);
    }

    return Plugin_Continue;
}


public Action:Command_SelectKnife(client, args)
{
    if (!GetUserFlagBits(client))
    {
        PrintToChat(client, "%s You must be a \x03VIP+\x04 member to use this feature.", MSG_PREFIX);
        PrintToChat(client, "%s Sign up at \x03http://hellsgamers.com/vip", MSG_PREFIX);

        return Plugin_Handled;
    }

    new Handle:menu = CreateMenu(MenuHandler_SelectKnife);
    SetMenuTitle(menu, "Select Your Knife");
    SetMenuExitBackButton(menu, true);

    AddMenuItem(menu, "Default", "Default");
    AddMenuItem(menu, "Bayonet", "Bayonet");
    AddMenuItem(menu, "Flip", "Flip");
    AddMenuItem(menu, "Gutting", "Gutting");
    AddMenuItem(menu, "Karambit", "Karambit");
    AddMenuItem(menu, "M9 Bayonet", "M9 Bayonet");
    AddMenuItem(menu, "Tactical", "Tactical");
    AddMenuItem(menu, "Terrorist Knife", "Terrorist Knife");
    AddMenuItem(menu, "Golden Knife", "Golden Knife");
    AddMenuItem(menu, "Butterfly Knife", "Butterfly Knife");

    DisplayMenu(menu, client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public MenuHandler_SelectKnife(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
            {
                FakeClientCommand(client, "sm_guns");
            }
        }

        case MenuAction_Select:
        {
            decl String:name[MAX_NAME_LENGTH];
            decl String:sInt[8];

            GetMenuItem(menu, selected, name, sizeof(name));
            IntToString(selected, sInt, sizeof(sInt));

            g_iPlayerKnives[client] = selected;
            SetClientCookie(client, g_hKnifeCookie, sInt);

            PrintToChat(client, "%s You have selected the \x03%s\x04 knife model", MSG_PREFIX, name);
            PrintToChat(client, "%s It will be active when you next pick up a knife", MSG_PREFIX);
        }
    }
}


SetWeaponAmmo(weapon, owner, ammo)
{
    if (weapon <= 0 || owner > MaxClients || owner <= 0 || !IsClientInGame(owner))
        return;

    SetEntData(owner, m_iAmmo +
               GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType") * 4,
               ammo, _, true);
}

GetWeaponClip(weapon)
{
    return GetEntData(weapon, m_iClip1);
}
