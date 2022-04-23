
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

new String:g_sCTGunsPath[PLATFORM_MAX_PATH];
new String:g_sCoolWeapons[4][LEN_ITEMNAMES] = {"weapon_sg552",
                                               "weapon_ump45",
                                               "weapon_mac10",
                                               "weapon_tmp"};
new String:g_sStartPistol[MAXPLAYERS + 1][LEN_ITEMNAMES];
new String:g_sStartPrimary[MAXPLAYERS + 1][LEN_ITEMNAMES];
new Handle:g_hGiveAmmo = INVALID_HANDLE;
new Handle:g_hPistolCookie;
new Handle:g_hPrimaryCookie;
new Handle:g_hPistols;
new Handle:g_hPrimaries;

// ####################################################################################
// ####################################### EVENTS #####################################
// ####################################################################################

stock Weapons_OnPluginStart()
{
    BuildPath(Path_SM, g_sCTGunsPath, PLATFORM_MAX_PATH, "data/jbctguns.txt");

    g_hGiveAmmo = CreateArray();
    g_hPistolCookie = RegClientCookie("hgjb_pistol", "Round Start Pistol", CookieAccess_Protected);
    g_hPrimaryCookie = RegClientCookie("hgjb_primary", "Round Start Primary", CookieAccess_Protected);

    if (g_iGame != GAMETYPE_TF2)
    {
        RegConsoleCmd("sm_gun", Command_SelectGuns);
        RegConsoleCmd("sm_guns", Command_SelectGuns);
        RegConsoleCmd("sm_weapons", Command_SelectGuns);
        RegConsoleCmd("sm_spawnweapons", Command_SelectGuns);
        RegConsoleCmd("sm_pistol", Command_SelectPistol);
        RegConsoleCmd("sm_pistols", Command_SelectPistol);
        RegConsoleCmd("sm_secondary", Command_SelectPistol);
        RegConsoleCmd("sm_primary", Command_SelectPrimary);
        RegConsoleCmd("sm_primaries", Command_SelectPrimary);
    }

    g_hPistols = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
    g_hPrimaries = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));

    if (g_iGame != GAMETYPE_TF2)
    {
        PopulateWeaponsArrays();
    }
}

stock Weapons_OnRndStrt_General()
{
    // This will dynamically spawn enough glocks (warning weapons) for each CT.
    // This is basically a spiral algorithm, which spirals out glocks from the center point
    // The center point being center of armory.

    if (g_iGame != GAMETYPE_CSS)
        return;

    decl Float:origin[3] = {1093.81, -3022.63, 1.0};

    if (GetTrieArray(g_hDbCoords, "Armory", Float:origin, 3))
    {
        new Float:step = 20.0;
        new Float:step2 = -110.0;

        new direction;

        decl String:coolName[LEN_ITEMNAMES];
        coolName = g_sCoolWeapons[GetRandomInt(0, 3)];

        for (new i = 0; i < GetTeamClientCount(TEAM_GUARDS); i++)
        {
            decl Float:temp[3];
            decl Float:temp2[3];

            temp = origin;
            temp2 = origin;

            if (!(i % 3))
            {
                temp2[2] += 90.0;

                temp2[0] += step2;
                step2 += 55.0;

                new cool = CreateEntityByName(coolName);
                PushArrayCell(g_hGiveAmmo, cool);

                DispatchKeyValue(cool, "spawnflags", "1");
                DispatchSpawn(cool);

                TeleportEntity(cool, temp2, NULL_VECTOR, NULL_VECTOR);
            }

            if (!(i % 2))
            {
                switch (direction)
                {
                    case 0:
                        temp[0] += step;

                    case 1:
                        temp[0] -= step;

                    case 2:
                        temp[1] += step;

                    case 3:
                    {
                        temp[1] -= step;
                        step += 20.0;
                    }
                }

                new glock = CreateEntityByName("weapon_glock");

                DispatchKeyValue(glock, "ammo", "60");
                DispatchSpawn(glock);

                TeleportEntity(glock, temp, NULL_VECTOR, NULL_VECTOR);

                // increment direction, or put it back to zero if it's greater than 3.
                direction = ++direction > 3 ? 0 : direction;
            }
        }
    }
}

bool:Weapons_PlayerHurt(attacker, victim)
{
    decl String:weapon[LEN_ITEMNAMES];
    GetClientWeapon(attacker, weapon, sizeof(weapon));

    if (StrEqual(weapon, "weapon_glock"))
    {
        new health = GetClientHealth(victim);
        PrintToChat(victim, "%s \x03%N\x04 gave you a warning.", MSG_PREFIX, attacker);

        if (health > 1)
            SetEntityHealth(victim, health - 1);

        return false;
    }

    return true;
}

stock Weapons_OnClientCookiesCached(client)
{
    GetClientCookie(client, g_hPistolCookie, g_sStartPistol[client], LEN_ITEMNAMES);
    GetClientCookie(client, g_hPrimaryCookie, g_sStartPrimary[client], LEN_ITEMNAMES);
}

stock Weapons_OnEntityCreated(entity, const String:classname[])
{
    PushArrayCell(g_hGiveAmmo, entity);
}

stock Weapons_OnPlayerDeath(attacker, const String:weapon[])
{
    // There was an error getting the attacker's weapon if attacker was the world or self.
    if (attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker) || !IsPlayerAlive(attacker))    // Don't use JB_IsPlayerAlive
        return;

    if (g_iGame == GAMETYPE_TF2)
    {
        new slot;

        if (!GetTrieValue(g_hWepsAndItems, weapon, slot))
        {
            LogError("TF2: NEW WEAPON (Weapons_OnPlayerDeath)? %s", weapon);
            return;
        }

        if (slot == WEPSLOT_KNIFE)
        {
            new add = GetConVarInt(g_hCvWeaponKnifeSyphonHealth);
            if (add > 0)
            {
                SetEntityHealth(attacker, GetClientHealth(attacker) + add);
                PrintToChat(attacker, "%s You gained an extra \x03%d\x04 health for killing with a knife", MSG_PREFIX, add);
            }
        }
    }

    if (StrEqual(weapon, "weapon_knife"))
    {
        new add = GetConVarInt(g_hCvWeaponKnifeSyphonHealth);
        if (add > 0)
        {
            SetEntityHealth(attacker, GetClientHealth(attacker) + add);
            PrintToChat(attacker, "%s You gained an extra \x03%d\x04 health for killing with a knife", MSG_PREFIX, add);
        }
    }
}

stock Weapons_OnItemPickup(client, wepid, const String:itemname[], slot)
{
    if (slot == 1)
    {
        if (GetClientTeam(client) == TEAM_GUARDS)
        {
            if (StrEqual(itemname, "glock"))
                PrintToChat(client, "%s You picked up a \x03Warning Weapon\x04. This gun does\x03 1\x04 damage", MSG_PREFIX);
        }

        else
        {
            if (GetEntData(wepid, m_iClip1) > 20)
                SetEntData(wepid, m_iClip1, 20);
        }
    }

    new m_iPrimaryAmmoType = GetEntProp(wepid, Prop_Send, "m_iPrimaryAmmoType") * 4;
    if (!GetEntData(client, m_iAmmo + m_iPrimaryAmmoType))
    {
        new index = FindValueInArray(g_hGiveAmmo, wepid);

        if (index > -1)
        {
            RemoveFromArray(g_hGiveAmmo, index);
            SetEntData(client, m_iAmmo + m_iPrimaryAmmoType,
                       GetEntData(wepid, m_iClip1) * (3 + (slot == 1 ? 2 : 0)), _, true);
        }
    }
}

stock Weapons_OnClientPutInServer(client)
{
    g_sStartPistol[client] = "";
    g_sStartPrimary[client] = "";
}

/* ----- Commands ----- */

public Action:Command_SelectGuns(client, args)
{
    new Handle:menu = CreateMenu(MenuHandler_SelectGuns);
    SetMenuTitle(menu, "Select Your Spawn Weapons");

    if (g_iGame == GAMETYPE_CSGO)
    {
        if (GetUserFlagBits(client))
        {
            AddMenuItem(menu, "sm_knives", "Knife");
        }

        else
        {
            AddMenuItem(menu, "", "Knife (VIP+ Only)", ITEMDRAW_DISABLED);
        }
    }

    AddMenuItem(menu, "sm_pistols", "Pistol");
    AddMenuItem(menu, "sm_primary", "Primary");

    DisplayMenu(menu, client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public MenuHandler_SelectGuns(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Select:
        {
            decl String:command[32];
            GetMenuItem(menu, selected, command, sizeof(command));
            FakeClientCommand(client, command);
        }
    }
}

public Action:Command_SelectPistol(client, args)
{
    new Handle:menu = CreateMenu(MenuHandler_SelectPistol);
    SetMenuTitle(menu, "Select Your Spawn Pistol");
    SetMenuExitBackButton(menu, true);

    for (new i = 0; i < GetArraySize(g_hPistols) / 2; i++)
    {
        decl String:weapon[MAX_NAME_LENGTH];
        decl String:name[MAX_NAME_LENGTH];

        GetArrayString(g_hPistols, i * 2, weapon, sizeof(weapon));
        GetArrayString(g_hPistols, i * 2 + 1, name, sizeof(name));

        AddMenuItem(menu, weapon, name, StrEqual(g_sStartPistol[client], weapon) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    }

    DisplayMenu(menu, client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public MenuHandler_SelectPistol(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
            {
                Command_SelectGuns(client, 0);
            }
        }

        case MenuAction_Select:
        {
            new style;
            decl String:weapon[MAX_NAME_LENGTH];
            decl String:name[MAX_NAME_LENGTH];
            GetMenuItem(menu, selected, weapon, sizeof(weapon), style, name, sizeof(name));

            Format(g_sStartPistol[client], MAX_NAME_LENGTH, weapon);
            SetClientCookie(client, g_hPistolCookie, weapon);

            PrintToChat(client, "%s You have selected the \x03%s\x04 as your spawn pistol", MSG_PREFIX, name);
        }
    }
}

public Action:Command_SelectPrimary(client, args)
{
    new Handle:menu = CreateMenu(MenuHandler_SelectPrimary);
    SetMenuTitle(menu, "Select Your Spawn Primary");
    SetMenuExitBackButton(menu, true);

    AddMenuItem(menu, "", "No Weapon");

    for (new i = 0; i < GetArraySize(g_hPrimaries) / 2; i++)
    {
        decl String:weapon[MAX_NAME_LENGTH];
        decl String:name[MAX_NAME_LENGTH];

        GetArrayString(g_hPrimaries, i * 2, weapon, sizeof(weapon));
        GetArrayString(g_hPrimaries, i * 2 + 1, name, sizeof(name));

        AddMenuItem(menu, weapon, name, StrEqual(g_sStartPrimary[client], weapon) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    }

    DisplayMenu(menu, client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public MenuHandler_SelectPrimary(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
            {
                Command_SelectGuns(client, 0);
            }
        }

        case MenuAction_Select:
        {
            new style;
            decl String:weapon[MAX_NAME_LENGTH];
            decl String:name[MAX_NAME_LENGTH];
            GetMenuItem(menu, selected, weapon, sizeof(weapon), style, name, sizeof(name));

            Format(g_sStartPrimary[client], MAX_NAME_LENGTH, weapon);
            SetClientCookie(client, g_hPrimaryCookie, weapon);

            PrintToChat(client, "%s You have selected the \x03%s\x04 as your spawn weapon", MSG_PREFIX, name);
        }
    }
}

/* ----- Natives ----- */

public Native_JB_DontGiveAmmo(Handle:plugin, args)
{
    new entity = GetNativeCell(1);
    new index = FindValueInArray(g_hGiveAmmo, entity);

    if (index > -1)
    {
        RemoveFromArray(g_hGiveAmmo, index);
    }
}

/* ----- Functions ----- */

stock Weapons_GiveStartWeapons(client)
{
    if (IsPlayerAlive(client))  // Don't use JB_IsPlayerAlive
    {
        new bool:unset = true;

        if (StrEqual(g_sStartPistol[client], ""))
        {
            GivePlayerItem(client, "weapon_deagle");
        }

        else
        {
            GivePlayerItem(client, g_sStartPistol[client]);
            unset= false;
        }

        if (!StrEqual(g_sStartPrimary[client], ""))
        {
            GivePlayerItem(client, g_sStartPrimary[client]);
            unset = false;
        }

        if (unset && IsPlayerInDM(client))
        {
            PrintToChat(client, "%s You have not yet selected your start weapons", MSG_PREFIX);
            PrintToChat(client, "%s Type \x03guns\x04 in chat to do so", MSG_PREFIX);
        }
    }
}

stock PopulateWeaponsArrays()
{
    decl String:sKeyName[MAX_NAME_LENGTH];
    decl String:sWeaponName[MAX_NAME_LENGTH];
    decl String:sWeaponPrettyName[MAX_NAME_LENGTH];
    decl String:sWeaponType[MAX_NAME_LENGTH];

    new Handle:hWeps = CreateKeyValues("Weapons");
    FileToKeyValues(hWeps, g_sCTGunsPath);

    if (g_iGame == GAMETYPE_CSS)
    {
        KvJumpToKey(hWeps, "cstrike");
    }

    else if (g_iGame == GAMETYPE_CSGO)
    {
        KvJumpToKey(hWeps, "csgo");
    }

    else
        return;

    KvGotoFirstSubKey(hWeps);

    do
    {
        KvGetSectionName(hWeps, sKeyName, sizeof(sKeyName));
        Format(sWeaponName, sizeof(sWeaponName), "weapon_%s", sKeyName);

        KvGetString(hWeps, "name", sWeaponPrettyName, sizeof(sWeaponPrettyName));
        KvGetString(hWeps, "type", sWeaponType, sizeof(sWeaponType));

        if (StrEqual(sWeaponType, "primary"))
        {
            PushArrayString(g_hPrimaries, sWeaponName);
            PushArrayString(g_hPrimaries, sWeaponPrettyName);
        }

        else if (StrEqual(sWeaponType, "secondary"))
        {
            PushArrayString(g_hPistols, sWeaponName);
            PushArrayString(g_hPistols, sWeaponPrettyName);
        }
    } while (KvGotoNextKey(hWeps));
}

