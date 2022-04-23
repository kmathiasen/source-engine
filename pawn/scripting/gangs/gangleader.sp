#define OWNERTYPE_OWNER 1
#define OWNERTYPE_COOWNER 2

new Handle:hGangPerks = INVALID_HANDLE;
new Handle:hConfirmUpgradeMenu = INVALID_HANDLE;
new Handle:hInvitePlayerMenu = INVALID_HANDLE;
new Handle:hConfirmCreateGangMenu = INVALID_HANDLE;
new Handle:hGangMemberOptionsMenu = INVALID_HANDLE;

new String:sGangPerkPath[PLATFORM_MAX_PATH];
new iOwnerType[MAXPLAYERS + 1];

/* ----- Events ----- */

stock GangLeader_OnPluginStart()
{
    BuildPath(Path_SM,
              sGangPerkPath, PLATFORM_MAX_PATH, "data/gangperks.txt");

    BuildGangLeaderMenus();

    RegConsoleCmd("sm_create", Command_CreateGang);
}

stock GangLeader_OnRoundStart()
{
    if (hInvitePlayerMenu != INVALID_HANDLE)
        CloseHandle(hInvitePlayerMenu);

    hInvitePlayerMenu = CreateMenu(InvitePlayerMenuSelect);
    SetMenuTitle(hInvitePlayerMenu, "Invite Player To Your Gang");
    SetMenuExitBackButton(hInvitePlayerMenu, true);
}


/* ----- Commands ----- */


public Action:Command_CreateGang(client, args)
{
    if (!args)
    {
        PrintToChat(client,
                    "%s Invalid Syntax -- \x04!create <gangname>", MSG_PREFIX);
        return Plugin_Handled;
    }

    decl String:sGangName[MAX_NAME_LENGTH];
    GetCmdArgString(sGangName, sizeof(sGangName));

    if (StrContains(sGangName, " - ") != -1)
    {
        PrintToChat(client,
                    "%s Please remove the ' - ' from your gang", MSG_PREFIX);
        return Plugin_Handled;
    }

    ResetPack(hLevelCosts);
    new cost = ReadPackCell(hLevelCosts);

    if (GetPoints(client) < cost)
    {
        PrintToChat(client,
                    "%s You need \x04%d\x01 points to create a gang",
                    MSG_PREFIX, cost);
        return Plugin_Handled;
    }

    if (StrEqual("none", sGangName, false))
    {
        PrintToChat(client,
                    "%s No. The name \x04'None'\x01 will break the script", MSG_PREFIX);
        return Plugin_Handled;
    }

    if (!StrEqual("None", sCacheGang[client]))
    {
        PrintToChat(client,
                    "%s You must leave your current gang first", MSG_PREFIX);
        return Plugin_Handled;
    }

    decl dummy[GangData];

    if (GetTrieArray(hRepData, sGangName, dummy, GangData))
    {
        PrintToChat(client,
                    "%s \x04%s\x01 is already taken", MSG_PREFIX, sGangName);
        return Plugin_Handled;
    }

    PrintToChat(client,
                "%s You are about to create the gang \x04%s",
                MSG_PREFIX, sGangName);

    sGangNames[client] = sGangName;
    DisplayMenu(hConfirmCreateGangMenu, client, DEFAULT_TIMEOUT);

    return Plugin_Handled;
}

/* ----- Functions ----- */


stock DisplayOptionsMenu(client)
{
    if (iOwnerType[client] == OWNERTYPE_OWNER)
        DisplayMenu(hGangOptionsMenu, client, DEFAULT_TIMEOUT);

    else
        DisplayMenu(hGangCoOwnerMenu, client, DEFAULT_TIMEOUT);
}

stock BuildGangLeaderMenus()
{
    hConfirmUpgradeMenu = CreateMenu(ConfirmUpgradeMenuSelect);
    SetMenuExitBackButton(hConfirmUpgradeMenu, true);

    AddMenuItem(hConfirmUpgradeMenu, "", "No");
    AddMenuItem(hConfirmUpgradeMenu, "", "Yes");

    hGangCoOwnerMenu = CreateMenu(GangCoOwnerMenuSelect);
    SetMenuTitle(hGangCoOwnerMenu, "Gang Options");

    AddMenuItem(hGangCoOwnerMenu, "", "Upgrade Level");
    AddMenuItem(hGangCoOwnerMenu, "", "Change Perk");
    AddMenuItem(hGangCoOwnerMenu, "", "Invite Player");
    AddMenuItem(hGangCoOwnerMenu, "", "Toggle Perk For You");
    AddMenuItem(hGangCoOwnerMenu, "", "Enable/Disable Gang Trail For You");

    SetMenuExitBackButton(hGangCoOwnerMenu, true);

    hGangMemberOptionsMenu = CreateMenu(GangMemberOptionsSelect);
    SetMenuTitle(hGangMemberOptionsMenu, "Gang Options");

    AddMenuItem(hGangMemberOptionsMenu, "", "Toggle Perk For You");
    AddMenuItem(hGangMemberOptionsMenu, "", "Enable/Disable Gang Trail For You");
    SetMenuExitBackButton(hGangMemberOptionsMenu, true);

    hGangOptionsMenu = CreateMenu(GangOptionsMenuSelect);
    SetMenuTitle(hGangOptionsMenu, "Gang Options");

    AddMenuItem(hGangOptionsMenu, "upgrade", "Upgrade Level");
    AddMenuItem(hGangOptionsMenu, "changeperk", "Change Perk");
    AddMenuItem(hGangOptionsMenu, "pass", "Pass Leadership");
    AddMenuItem(hGangOptionsMenu, "invite", "Invite Player");
    AddMenuItem(hGangOptionsMenu, "private", "Turn On/Off Private Membership");
    AddMenuItem(hGangOptionsMenu, "coowners", "Manage Co-Owners");
    AddMenuItem(hGangOptionsMenu, "kick", "Kick Members");
    AddMenuItem(hGangOptionsMenu, "toggleperk", "Toggle Perk For You");
    AddMenuItem(hGangOptionsMenu, "trail", "Trails");
    AddMenuItem(hGangOptionsMenu, "enabledisabletrail", "Enable/Disable Gang Trail For You");

    SetMenuExitBackButton(hGangOptionsMenu, true);

    hManageCoOwnerMenu = CreateMenu(ManageCoOwnerMenuSelect);
    SetMenuTitle(hManageCoOwnerMenu, "Manage Co Owners");

    AddMenuItem(hManageCoOwnerMenu, "", "Add Co Owner");
    AddMenuItem(hManageCoOwnerMenu, "", "Delete Co Owner");

    SetMenuExitBackButton(hManageCoOwnerMenu, true);
    
    /* Change Gang Perk */
    hGangPerksMenu = CreateMenu(GangPerksMenuSelect);
    SetMenuTitle(hGangPerksMenu, "Select Gang Perk - Cost, Drain Per Level");

    SetMenuExitBackButton(hGangPerksMenu, true);

    decl String:sKeyName[48];
    decl String:sDisplay[64];
    decl String:sCost[8];
    decl String:sDrain[8];

    hGangPerks = CreateKeyValues("gang perks");
    FileToKeyValues(hGangPerks, sGangPerkPath);

    KvGotoFirstSubKey(hGangPerks);

    do
    {
        KvGetSectionName(hGangPerks, sKeyName, sizeof(sKeyName));

        KvGetString(hGangPerks, "cost", sCost, sizeof(sCost));
        KvGetString(hGangPerks, "drain", sDrain, sizeof(sCost));

        Format(sDisplay, sizeof(sDisplay),
               "%s - %s, %s", sKeyName, sCost, sDrain);

        if (StrContains(sKeyName, "scout", false) > -1)
            AddMenuItem(hGangPerksMenu, sKeyName, "ºaQº Scout");      // lol

        else
            AddMenuItem(hGangPerksMenu, sKeyName, sDisplay);
    } while (KvGotoNextKey(hGangPerks));
}


/* ----- Menus ----- */


public InvitePlayerMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayOptionsMenu(client);

    if (action != MenuAction_Select)
        return;

    decl String:sUserid[8];
    GetMenuItem(menu, selected, sUserid, sizeof(sUserid));

    new userid = StringToInt(sUserid);
    new tClient = GetClientOfUserId(userid);

    if (!tClient)
    {
        PrintToChat(client, "%s That player has left the server", MSG_PREFIX);
        return;
    }

    decl String:name[MAX_NAME_LENGTH];
    decl String:title[64];

    GetClientName(client, name, sizeof(name));
    Format(title, sizeof(title), "Join %s's Gang?", name);

    new Handle:menu2 = CreateMenu(JoinGangMenuSelect);
    SetMenuTitle(menu2, title);

    AddMenuItem(menu2, "meow - 0", "No");
 
    decl String:query[256];
    decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];

    SQL_EscapeString(hDrugDB, sCacheGang[client], sNewName, sizeof(sNewName));

    Format(query, sizeof(query),
           "SELECT name, level FROM gangs WHERE name = '%s'", sNewName);

    new Handle:hData = CreateDataPack();

    WritePackCell(hData, GetClientUserIdSafe(tClient));
    WritePackCell(hData, _:menu2);

    SQL_TQuery(hDrugDB,
               AddGangInviteInfoCallback, query, hData);
}

public PassLeaderMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
    {
        DisplayMenu(hGangOptionsMenu, client, DEFAULT_TIMEOUT);
        return;
    }

    if (action != MenuAction_Select)
        return;

    decl String:query[256];
    decl String:text[MAX_NAME_LENGTH * 2 + 4];
    decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];

    /*
     * sParts[0] - Steamid
     * sParts[1] - Gang Name
     */

    decl String:sParts[2][MAX_NAME_LENGTH];
    
    GetMenuItem(menu, selected, text, sizeof(text));
    ExplodeString(text, " - ", sParts, 2, MAX_NAME_LENGTH);

    SQL_EscapeString(hDrugDB, sParts[1], sNewName, sizeof(sNewName));

    Format(query, sizeof(query),
           "UPDATE gangs SET ownersteamid = '%s' WHERE name = '%s'",
           sParts[0], sNewName);

    new target = FindClientFromSteamid(sParts[0]);
    if (target)
        memberType[target] = MEMBERTYPE_OWNER;

    PrintToChat(client,
                "%s Passing ownership to \x04%s", MSG_PREFIX, sParts[0]);

    SQL_TQuery(hDrugDB, EmptyCallback, query);

    Format(query, sizeof(query),
           "UPDATE playerdata SET isowner = 1, joined = 0 WHERE steamid = '%s'", sParts[0]);
    SQL_TQuery(hDrugDB, EmptyCallback, query);

    decl String:steamid[32];
    GetClientAuthString2(client, steamid, sizeof(steamid));

    Format(query, sizeof(query),
           "UPDATE playerdata SET isowner = 0 WHERE steamid = '%s'", steamid);
    SQL_TQuery(hDrugDB, EmptyCallback, query);

    memberType[client] = MEMBERTYPE_MEMBER;
    CreateGangInfoMenus();
}

public AreYouSurePassLeaderSelect(Handle:menu,
                                  MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayMenu(hGangOptionsMenu, client, DEFAULT_TIMEOUT);

    if (action == MenuAction_Select && selected == 1)
    {
        decl String:query[256];
        decl String:steamid[32];

        GetClientAuthString2(client, steamid, sizeof(steamid));
        if (hPassLeaderMenus[client] != INVALID_HANDLE)
            CloseHandle(hPassLeaderMenus[client]);

        hPassLeaderMenus[client] = CreateMenu(PassLeaderMenuSelect);

        SetMenuTitle(hPassLeaderMenus[client], "Pass Leader");
        SetMenuExitBackButton(hPassLeaderMenus[client], true);

        decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
        SQL_EscapeString(hDrugDB, sCacheGang[client], sNewName, sizeof(sNewName));

        Format(query, sizeof(query),
               "SELECT name, steamid, gang FROM playerdata WHERE gang = '%s' and steamid != '%s' ORDER BY points DESC",
               sNewName, steamid);

        SQL_TQuery(hDrugDB,
                   PopulatePassLeaderMenuCallback, query, GetClientUserIdSafe(client));
    }
}

public AddCoOwnerMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                DisplayMenu(hManageCoOwnerMenu, client, DEFAULT_TIMEOUT);        
        }

        case MenuAction_Select:
        {
            decl String:steamid[32];
            GetMenuItem(menu, selected, steamid, sizeof(steamid));

            decl String:query[256];
            Format(query, sizeof(query),
                   "UPDATE playerdata SET joined = 1 WHERE steamid = '%s'",
                   steamid);

            new target = FindClientFromSteamid(steamid);
            if (target)
                memberType[target] = MEMBERTYPE_COOWNER;

            PrintToChat(client, "%s Adding player to co owner list", MSG_PREFIX);
            SQL_TQuery(hDrugDB, EmptyCallback, query);
        }
    }

}

public ManageCoOwnerMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayMenu(hGangOptionsMenu, client, DEFAULT_TIMEOUT);

    else if (action == MenuAction_Select)
    {
        decl String:query[256];
        decl String:steamid[32];

        GetClientAuthString2(client, steamid, sizeof(steamid));

        /* Add Co Owner */
        if (selected == 0)
        {
            decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
            SQL_EscapeString(hDrugDB,
                             sCacheGang[client], sNewName, sizeof(sNewName));

            Format(query, sizeof(query),
                   "SELECT steamid, name FROM playerdata WHERE gang = '%s' and joined = 0 and isowner = 0",
                   sNewName, steamid);

            new Handle:menu2 = CreateMenu(AddCoOwnerMenuSelect);
            new Handle:hData = CreateDataPack();

            SetMenuTitle(menu2, "Add Co Owner");

            WritePackCell(hData, GetClientUserIdSafe(client));
            WritePackCell(hData, _:menu2);

            SetMenuExitBackButton(menu2, true);
            SQL_TQuery(hDrugDB, PopulateCoOwnerMenuCallback,
                       query, hData);

        }

        /* Remove Co Owner */
        else if (selected == 1)
        {
            decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
            SQL_EscapeString(hDrugDB,
                             sCacheGang[client], sNewName, sizeof(sNewName));

            Format(query, sizeof(query),
                   "SELECT steamid, name FROM playerdata WHERE gang = '%s' and joined = 1",
                   sNewName, steamid);

            new Handle:menu2 = CreateMenu(RemoveCoOwnerMenuSelect);
            new Handle:hData = CreateDataPack();

            SetMenuTitle(menu, "Remove Co Owner");

            WritePackCell(hData, GetClientUserIdSafe(client));
            WritePackCell(hData, _:menu2);

            SetMenuExitBackButton(menu2, true);
            SQL_TQuery(hDrugDB, PopulateCoOwnerMenuCallback,
                       query, hData);
        }
    }
}

public RemoveCoOwnerMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                DisplayMenu(hManageCoOwnerMenu, client, DEFAULT_TIMEOUT);
        }

        case MenuAction_Select:
        {
            decl String:steamid[32];
            GetMenuItem(menu, selected, steamid, sizeof(steamid));

            decl String:query[256];
            Format(query, sizeof(query),
                   "UPDATE playerdata SET joined = 0 WHERE steamid = '%s'",
                   steamid);

            new target = FindClientFromSteamid(steamid);
            if (target)
                memberType[target] = MEMBERTYPE_MEMBER;

            PrintToChat(client,
                        "%s Removing player from co owner list", MSG_PREFIX);
            SQL_TQuery(hDrugDB, EmptyCallback, query);
        }
    }
}

public GangOptionsMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayMenu(hMainMenu, client, DEFAULT_TIMEOUT);

    if (action != MenuAction_Select)
        return;

    decl String:query[256];
    decl String:steamid[32];
    decl String:choice[MAX_NAME_LENGTH];

    GetClientAuthString2(client, steamid, sizeof(steamid));
    GetMenuItem(menu, selected, choice, sizeof(choice));

    /* Upgrade Level */
    if (StrEqual(choice, "upgrade"))
    {
        Format(query, sizeof(query),
               "SELECT level FROM gangs WHERE ownersteamid = '%s'",
               steamid);

        SQL_TQuery(hDrugDB, ConfirmUpgradeCallback,
                   query, GetClientUserIdSafe(client));
    }

    /* Change Perk */
    else if (StrEqual(choice, "changeperk"))
    {
        Format(query, sizeof(query),
               "SELECT lastchange FROM gangs WHERE ownersteamid = '%s'",
               steamid);

        SQL_TQuery(hDrugDB, CheckLastChangeCallback,
                   query, GetClientUserIdSafe(client));
    }

    /* Pass Leadership */
    else if (StrEqual(choice, "pass"))
    {
        if (hPassLeaderMenus[client] != INVALID_HANDLE)
            CloseHandle(hPassLeaderMenus[client]);

        hPassLeaderMenus[client] = CreateMenu(AreYouSurePassLeaderSelect);

        SetMenuExitBackButton(hPassLeaderMenus[client], true);
        SetMenuTitle(hPassLeaderMenus[client],
                    "Pass Leadership? Can't be undone");

        AddMenuItem(hPassLeaderMenus[client], "No", "No");
        AddMenuItem(hPassLeaderMenus[client], "Yes", "Yes");

        DisplayMenu(hPassLeaderMenus[client], client, DEFAULT_TIMEOUT);
    }

    /* Invite Player */
    else if (StrEqual(choice, "invite"))
        DisplayMenu(hInvitePlayerMenu, client, DEFAULT_TIMEOUT);

    /* Turn On/Off Private Membership */
    else if (StrEqual(choice, "private"))
    {
        Format(query, sizeof(query),
               "SELECT private FROM gangs WHERE ownersteamid = '%s'",
               steamid);

        SQL_TQuery(hDrugDB,
                   ChangePrivateCalback, query, GetClientUserIdSafe(client));
    }

    /* Manage Co-Owners */
    else if (StrEqual(choice, "coowners"))
        DisplayMenu(hManageCoOwnerMenu, client, DEFAULT_TIMEOUT);

    /* Kick Members */
    else if (StrEqual(choice, "kick"))
    {
        new Handle:menu2 = CreateMenu(KickMembersMenuSelect);
        new Handle:hData = CreateDataPack();

        WritePackCell(hData, GetClientUserIdSafe(client));
        WritePackCell(hData, _:menu2);

        SetMenuTitle(menu2, "Kick Members");
        SetMenuExitBackButton(menu2, true);

        decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
        SQL_EscapeString(hDrugDB,
                         sCacheGang[client], sNewName, sizeof(sNewName));

        Format(query, sizeof(query),
               "SELECT steamid, name, contributed FROM playerdata WHERE gang = '%s'",
               sNewName);

        SQL_TQuery(hDrugDB, PopulateKickMembersCallback,
                   query, hData);
    }

    /* Toggle Perk For You */
    else if (StrEqual(choice, "toggleperk"))
        TogglePerk(client);

    /* Trail */
    else if (StrEqual(choice, "trail"))
        Trails_OwnerTrailMainMenu(client);

    /* Enable/Disable Gang Trail For You */
    else if (StrEqual(choice, "enabledisabletrail"))
        Trails_EnableDisableTrailForOne(client);
}

public KickMembersMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                DisplayMenu(hGangOptionsMenu, client, DEFAULT_TIMEOUT);
        }

        case MenuAction_Select:
        {
            decl String:info[40];
            decl String:sParts[2][32];

            GetMenuItem(menu, selected, info, sizeof(info));
            ExplodeString(info, "|", sParts, 2, 32);

            /*
             * sParts[0] - Steamid
             * sParts[1] - Cost
             */

            new Handle:menu2 = CreateMenu(AreYouSureKickMemberSelect);

            decl String:title[64];
            Format(title, sizeof(title), "Are you sure? Cost - %s", sParts[1]);

            SetMenuTitle(menu2, title);
            SetMenuExitBackButton(menu2, true);

            AddMenuItem(menu2, "No", "No");
            AddMenuItem(menu2, info, "Yes");

            DisplayMenu(menu2, client, DEFAULT_TIMEOUT);
        }
    }
}

public AreYouSureKickMemberSelect(Handle:menu,
                                  MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                DisplayMenu(hGangOptionsMenu, client, DEFAULT_TIMEOUT);
        }

        case MenuAction_Select:
        {
            decl String:info[40];
            decl String:sParts[2][32];

            GetMenuItem(menu, selected, info, sizeof(info));
            if (StrEqual(info, "No"))
                return;

            /*
             * sParts[0] - steamid
             * sParts[1] - cost
             */

            ExplodeString(info, "|", sParts, 2, 32);
            new cost = StringToInt(sParts[1]);

            new rep = GetRepByGang(sCacheGang[client]);
            if (rep < cost)
            {
                PrintToChat(client,
                            "%s \x04%s\x01 only has \x04%d\x01 gang points, \x04%d\x01 needed",
                            MSG_PREFIX, sCacheGang[client], rep, cost);
                return;
            }

            AddRepByGang(sCacheGang[client], -cost);

            decl String:query[256];
            decl String:ownersteamid[32];

            GetClientAuthString2(client, ownersteamid, sizeof(ownersteamid));
            AddRep(ownersteamid, -cost);

            Format(query, sizeof(query),
                   "UPDATE playerdata SET gang = 'None', joined = 0, contributed = 0 WHERE steamid = '%s'",
                   sParts[0]);

            SQL_TQuery(hDrugDB, EmptyCallback, query);

            Format(query, sizeof(query),
                   "UPDATE gangs SET membercount = membercount - 1 WHERE ownersteamid = '%s'",
                   ownersteamid);

            SQL_TQuery(hDrugDB, EmptyCallback, query);
            PrintToChat(client,
                        "%s Kicking steamid \x04%s\x01 from your gang",
                        MSG_PREFIX, sParts[0]);

            new kicked = FindClientFromSteamid(sParts[0]);
            if (kicked > 0)
            {
                Format(sCacheGang[kicked], MAX_NAME_LENGTH, "None");
                memberType[kicked] = MEMBERTYPE_NONE;
            }
        }
    }
}

public GangMemberOptionsSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayMenu(hMainMenu, client, DEFAULT_TIMEOUT);

    else if (action == MenuAction_Select)
    {
        switch (selected + 1)
        {
            /* Toggle Perk For You */
            case 1:
                TogglePerk(client);

            /* Enable/Disable Gang Trail For You */
            case 2:
                Trails_EnableDisableTrailForOne(client);
        }
    }
}

public GangCoOwnerMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayMenu(hMainMenu, client, DEFAULT_TIMEOUT);

    else if (action == MenuAction_Select)
    {
        decl String:steamid[32];
        decl String:query[256];

        GetClientAuthString2(client, steamid, sizeof(steamid));

        switch (selected + 1)
        {
            /* Upgrade Level */
            case 1:
            {
                decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
                SQL_EscapeString(hDrugDB, sCacheGang[client],
                                 sNewName, sizeof(sNewName));

                Format(query, sizeof(query),
                       "SELECT level FROM gangs WHERE name = '%s'", sNewName);

                SQL_TQuery(hDrugDB, ConfirmUpgradeCallback,
                           query, GetClientUserIdSafe(client));
            }

            /* Change Perk */
            case 2:
            {
                decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
                SQL_EscapeString(hDrugDB, sCacheGang[client],
                                 sNewName, sizeof(sNewName));

                Format(query, sizeof(query),
                       "SELECT lastchange FROM gangs WHERE name = '%s'",
                       sNewName);

                SQL_TQuery(hDrugDB, CheckLastChangeCallback,
                           query, GetClientUserIdSafe(client));
            }

            /* Invite Player */
            case 3:
                DisplayMenu(hInvitePlayerMenu, client, DEFAULT_TIMEOUT);

            /* Toggle Perk For You */
            case 4:
                TogglePerk(client);

            /* Enable/Disable Gang Trail For You */
            case 5:
                Trails_EnableDisableTrailForOne(client);
        }
    }
}

public GangPerksMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayOptionsMenu(client);

    if (action != MenuAction_Select)
        return;

    decl String:sKeyName[48];
    decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];

    GetMenuItem(menu, selected, sKeyName, sizeof(sKeyName));
    SQL_EscapeString(hDrugDB, sCacheGang[client], sNewName, sizeof(sNewName));

    decl String:sCost[8];
    decl String:sDrain[8];
    decl String:sMultiplier[8];
    decl String:sGiveType[8];
    decl String:sCommand[128];
    decl String:sPerkName[48];

    KvRewind(hGangPerks);
    KvJumpToKey(hGangPerks, sKeyName);

    KvGetSectionName(hGangPerks, sPerkName, sizeof(sPerkName));

    KvGetString(hGangPerks, "cost", sCost, sizeof(sCost));
    KvGetString(hGangPerks, "drain", sDrain, sizeof(sDrain));
    KvGetString(hGangPerks, "command", sCommand, sizeof(sCommand));
    KvGetString(hGangPerks, "multiplier", sMultiplier, sizeof(sMultiplier));
    KvGetString(hGangPerks, "givetype", sGiveType, sizeof(sGiveType));

    new rep = GetRepByGang(sCacheGang[client]);
    new cost = StringToInt(sCost);

    if (rep < cost)
    {
        PrintToChat(client,
                    "%s You need \x04%i\x01 points to switch perks",
                    MSG_PREFIX, cost);
        return;
    }

    decl String:query[512];
    Format(query, sizeof(query),
           "UPDATE gangs SET perk = '%s', perkschanged = perkschanged + 1, perkdrain = %d, perkcommand = '%s', perkmultiplier = %f, lastchange = %d, givetype = %d WHERE name = '%s'",
           sPerkName, StringToInt(sDrain), sCommand, StringToFloat(sMultiplier),
           GetTime(), StringToInt(sGiveType), sNewName);

    SQL_TQuery(hDrugDB, EmptyCallback, query);

    AddRepByGang(sCacheGang[client], -cost);
    TellRep(client);
}

public ConfirmUpgradeMenuSelect(Handle:menu,
                                MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayOptionsMenu(client);

    else if (action == MenuAction_Select && selected == 1)
    {
        new rep = GetRepByGang(sCacheGang[client]);

        if (rep < upgradeCosts[client])
        {
            PrintToChat(client,
                        "%s \x04%s\x01 only has \x04%d\x01 gang points",
                        MSG_PREFIX, sCacheGang[client], rep);
            return;
        }

        decl String:query[256];
        decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];

        AddRepByGang(sCacheGang[client], -upgradeCosts[client]);
        TellRep(client);

        SQL_EscapeString(hDrugDB, sCacheGang[client], sNewName, sizeof(sNewName));

        Format(query, sizeof(query),
               "UPDATE gangs SET level = level + 1 WHERE name = '%s'",
               sNewName);

        SQL_TQuery(hDrugDB, EmptyCallback, query);
        ConstructGangMenus();
    }
}

public ConfirmCreateGangMenuSelect(Handle:menu,
                                   MenuAction:action, client, selected)
{
    if (action == MenuAction_Select && selected == 1)
    {
        ResetPack(hLevelCosts);
        new cost = ReadPackCell(hLevelCosts);

        if (GetPoints(client) < cost)
        {
            PrintToChat(client,
                        "%s You need \x04%d\x01 points to create a gang",
                        MSG_PREFIX, cost);
            return;
        }

        decl String:name[MAX_NAME_LENGTH];
        decl String:steamid[32];

        GetClientName(client, name, sizeof(name));
        GetClientAuthString2(client, steamid, sizeof(steamid));

        AddPoints(client, -cost);
        TellPoints(client);

        /* Change the players gang name */

        decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
        SQL_EscapeString(hDrugDB,
                         sGangNames[client], sNewName, sizeof(sNewName));

        decl String:query[256];
        Format(query, sizeof(query),
               "UPDATE playerdata SET gang = '%s' WHERE steamid = '%s'",
               sNewName, steamid);

        SQL_TQuery(hDrugDB, EmptyCallback, query);
        sCacheGang[client] = sGangNames[client];

        /* Create the new gang */

        memberType[client] = MEMBERTYPE_OWNER;
        decl String:sNewGang[MAX_NAME_LENGTH * 2 + 1];

        SQL_EscapeString(hDrugDB, name, sNewName, sizeof(sNewName));
        SQL_EscapeString(hDrugDB, sGangNames[client], sNewGang, sizeof(sNewGang));

        Format(query, sizeof(query),
               "INSERT INTO gangs VALUES ('%s', '%s', '%s','None', 'None', 0, 1, 0, 0, 1, %d, 0, 0, 0, 0, 0.0, '', 0)",
               sNewGang, steamid, sNewName, GetTime());

        SQL_TQuery(hDrugDB, EmptyCallback, query);

        Format(query, sizeof(query),
               "UPDATE playerdata SET isowner = 1 WHERE steamid = '%s'",
               steamid);

        SQL_TQuery(hDrugDB, EmptyCallback, query);
    
        Format(query, sizeof(query),
               "SELECT name, rep, totalspent FROM gangs WHERE name = '%s'",
               sNewName);

        SQL_TQuery(hDrugDB, CacheGangDataCallback, query);
        CreateGangInfoMenus();
    }
}

/* ----- Callbacks ----- */


public AddGangInviteInfoCallback(Handle:hGang, Handle:hndl,
                                 const String:error[], any:hData)
{
    ResetPack(hData);

    new client = GetClientOfUserId(ReadPackCell(hData));
    new Handle:menu = Handle:ReadPackCell(hData);

    CloseHandle(hData);

    if (!client || !SQL_FetchRow(hndl))
    {
        CloseHandle(menu);
        return;
    }

    decl String:send[MAX_NAME_LENGTH + 10];
    decl String:sGangName[MAX_NAME_LENGTH];
    decl String:display[32];

    new cost = SQL_FetchInt(hndl, 1) * GetConVarInt(hCostPerLevel);
    SQL_FetchString(hndl, 0, sGangName, sizeof(sGangName));

    Format(send, sizeof(send), "%s - %d", sGangName, cost);
    Format(display, sizeof(display), "Yes, Cost = %d", cost);

    AddMenuItem(menu, send, display);
    DisplayMenu(menu, client, DEFAULT_TIMEOUT);
}

public PopulateCoOwnerMenuCallback(Handle:hGang, Handle:hndl,
                                   const String:error[], any:hData)
{
    ResetPack(hData);

    new client = GetClientOfUserId(ReadPackCell(hData));
    new Handle:menu = Handle:ReadPackCell(hData);

    CloseHandle(hData);

    if (!client)
    {
        CloseHandle(menu);
        return;
    }

    if (!SQL_GetRowCount(hndl))
        AddMenuItem(menu, "", "No Gang Members", ITEMDRAW_DISABLED);

    while (SQL_FetchRow(hndl))
    {
        decl String:steamid[32];
        decl String:name[MAX_NAME_LENGTH];

        SQL_FetchString(hndl, 0, steamid, sizeof(steamid));
        SQL_FetchString(hndl, 1, name, sizeof(name));

        AddMenuItem(menu, steamid, name);
    }

    DisplayMenu(menu, client, DEFAULT_TIMEOUT);
}

public PopulateKickMembersCallback(Handle:hGang, Handle:hndl,
                                   const String:error[], any:hData)
{
    ResetPack(hData);

    new client = GetClientOfUserId(ReadPackCell(hData));
    new Handle:menu = Handle:ReadPackCell(hData);

    CloseHandle(hData);

    if (!client)
    {
        CloseHandle(menu);
        return;
    }

    decl String:steamid[32];
    decl String:name[MAX_NAME_LENGTH];

    decl String:display[MAX_NAME_LENGTH + 10];
    decl String:info[MAX_NAME_LENGTH + 8];

    new contributed;
    new costPlus = GetConVarInt(hMinBootCost);
    new Float:costPerContributed = GetConVarFloat(hCostPerContributed);

    decl String:ownersteamid[32];
    GetClientAuthString2(client, ownersteamid, sizeof(ownersteamid));

    if (!SQL_GetRowCount(hndl))
        AddMenuItem(menu, "", "No Valid Members", ITEMDRAW_DISABLED);

    while (SQL_FetchRow(hndl))
    {
        SQL_FetchString(hndl, 0, steamid, sizeof(steamid));
        SQL_FetchString(hndl, 1, name, sizeof(name));

        if (StrEqual(ownersteamid, steamid))
            continue;

        contributed = SQL_FetchInt(hndl, 2);

        Format(display, sizeof(display), "%s - %d",
               name, costPlus + RoundToNearest(contributed * costPerContributed));

        Format(info, sizeof(display), "%s|%d",
               steamid, costPlus + RoundToNearest(contributed * costPerContributed));

        AddMenuItem(menu, info, display);
    }

    DisplayMenu(menu, client, DEFAULT_TIMEOUT);
}

public ChangePrivateCalback(Handle:hGang,
                            Handle:hndl, const String:error[], any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    if (!SQL_FetchRow(hndl))
        return;

    decl String:query[256];
    decl String:steamid[32];

    new isPrivate = SQL_FetchInt(hndl, 0);
    GetClientAuthString2(client, steamid, sizeof(steamid));

    if (isPrivate)
    {
        PrintToChat(client, "%s Your gang is now \x04Public", MSG_PREFIX);
        Format(query, sizeof(query),
               "UPDATE gangs SET private = 0 WHERE ownersteamid = '%s'",
               steamid);
    }

    else
    {
        PrintToChat(client, "%s Your gang is now \x04Private", MSG_PREFIX);
        Format(query, sizeof(query),
               "UPDATE gangs SET private = 1 WHERE ownersteamid = '%s'",
               steamid);
    }

    SQL_TQuery(hDrugDB, EmptyCallback, query);
    ConstructGangMenus();
}

public PopulatePassLeaderMenuCallback(Handle:hGang, Handle:hndl,
                                      const String:error[], any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    decl String:steamid[32];
    decl String:sName[MAX_NAME_LENGTH];
    decl String:sGangName[MAX_NAME_LENGTH];
    decl String:info[MAX_NAME_LENGTH * 2 + 4];

    if (!SQL_GetRowCount(hndl))
        AddMenuItem(hPassLeaderMenus[client],
                    "", "No Gang Members", ITEMDRAW_DISABLED);

    while (SQL_FetchRow(hndl))
    {
        SQL_FetchString(hndl, 0, sName, sizeof(sName));
        SQL_FetchString(hndl, 1, steamid, sizeof(steamid));
        SQL_FetchString(hndl, 2, sGangName, sizeof(sGangName));

        Format(info, sizeof(info), "%s - %s", steamid, sGangName);
        AddMenuItem(hPassLeaderMenus[client], info, sName);
    }

    DisplayMenu(hPassLeaderMenus[client], client, DEFAULT_TIMEOUT);
}

public CheckLastChangeCallback(Handle:hGang,
                               Handle:hndl, const String:error[], any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    if (SQL_FetchRow(hndl))
    {
        new lastChange = SQL_FetchInt(hndl, 0);
        new currentTime = GetTime();

        new timeLeft = (GetConVarInt(hChangePerkEvery) * 60 * 60) - 
                       (currentTime - lastChange);

        if (timeLeft > 0)
        {
            PrintToChat(client,
                        "%s You have to wait \x04%02d:%02d:%02d\x01 before you can change your perk",
                        MSG_PREFIX, timeLeft / 3600,
                        (timeLeft / 60) % 60, timeLeft % 60);
            return;
        }

        decl String:steamid[32];
        GetClientAuthString2(client, steamid, sizeof(steamid));

        TellRep(client);
        DisplayMenu(hGangPerksMenu, client, DEFAULT_TIMEOUT);
    }
}

public ConfirmUpgradeCallback(Handle:hDrug,
                              Handle:hndl, const String:error[], any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    if (SQL_FetchRow(hndl))
    {
        new level = SQL_FetchInt(hndl, 0);

        if (level >= levels)
        {
            PrintToChat(client, "%s Your gang is at the max level", MSG_PREFIX);
            return;
        }

        SetPackPosition(hLevelCosts, level * 8);
        new cost = ReadPackCell(hLevelCosts);

        decl String:steamid[32];
        GetClientAuthString2(client, steamid, sizeof(steamid));

        TellRep(client);

        decl String:title[64];
        Format(title, sizeof(title),
               "Upgrade To Level %i - %i", level + 1, cost);

        SetMenuTitle(hConfirmUpgradeMenu, title);
        DisplayMenu(hConfirmUpgradeMenu, client, DEFAULT_TIMEOUT);

        upgradeCosts[client] = cost;
    }
}
