
new Handle:hPerksGiven = INVALID_HANDLE;

/* ----- Events ----- */


public GangMembers_OnPluginStart()
{
    RegConsoleCmd("sm_gangpoints", Command_TellGangPoints);
    RegConsoleCmd("sm_donate", Command_DonatePoints);
    RegConsoleCmd("sm_identify", Command_IdentifyPlayers);
    RegConsoleCmd("sm_players", Command_ShowPlayers);

    hJoinGangMenu = CreateMenu(JoinLeaveGangMenuSelect);
    SetMenuTitle(hJoinGangMenu, "Gangs");

    AddMenuItem(hJoinGangMenu, "", "Join By Name");
    AddMenuItem(hJoinGangMenu, "", "Join By Owner");
    AddMenuItem(hJoinGangMenu, "", "Leave Current Gang");

    SetMenuExitBackButton(hJoinGangMenu, true);

    hPerksGiven = CreateTrie();
}

stock GangMembers_OnPlayerSpawn(client)
{
    if (GetClientTeam(client) == TEAM_T)
    {
        if (GetFeatureStatus(FeatureType_Native, "JB_IsPlayerAlive") == FeatureStatus_Available &&
            !JB_IsPlayerAlive(client))
        {
            return;
        }

        if (g_iGame != GAMETYPE_TF2)
            SetEntData(client, m_iAccount, GetPoints(client));

        if (!StrEqual("None", sCacheGang[client]))
        {
            if (!bPerkEnabled[client])
            {
                PrintToChat(client, "%s Your perk is currently \x04disabled\x01.", MSG_PREFIX);
                PrintToChat(client, "%s Type \x04!menu\x01 to reenable it.", MSG_PREFIX);

                return;
            }

            decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
            SQL_EscapeString(hDrugDB,
                             sCacheGang[client], sNewName, sizeof(sNewName));

            decl String:query[256];
            Format(query, sizeof(query),
                   "SELECT perk, level FROM gangs WHERE name = '%s'",
                   sNewName);

            SQL_TQuery(hDrugDB,
                       SetGangPerkCallback, query, GetClientUserIdSafe(client));
        }
    }
}

stock GangMembers_OnRoundStart()
{
    ClearTrie(hPerksGiven);
}


/* ----- Commands ----- */


public Action:Command_ShowPlayers(client, args)
{
    DisplayMenu(hCurrentPlayersMenu, client, DEFAULT_TIMEOUT);
    return Plugin_Handled;
}

public Action:Command_IdentifyPlayers(client, args)
{
    DisplayMenu(hIdentifyPlayersMenu, client, DEFAULT_TIMEOUT);
    return Plugin_Handled;
}

public Action:Command_TellGangPoints(client, args)
{
    if (StrEqual(sCacheGang[client], "None"))
        PrintToChat(client, "%s You are not in a gang", MSG_PREFIX);

    else
        PrintToChat(client, "%s \x04%s\x01 has \x04%d\x01 gang points",
                    MSG_PREFIX, sCacheGang[client],
                    GetRepByGang(sCacheGang[client]));

    return Plugin_Handled;
}

public Action:Command_DonatePoints(client, args)
{
    if (StrEqual(sCacheGang[client], "None"))
    {
        PrintToChat(client, "%s You are not in a gang", MSG_PREFIX);
        return Plugin_Handled;
    }

    decl String:sAmount[8];
    GetCmdArg(1, sAmount, sizeof(sAmount));

    new amount = StringToInt(sAmount);
    new points = GetPoints(client);

    if (StrEqual(sAmount, "all", false))
        amount = points;

    if (amount < 1)
    {
        PrintToChat(client,
                    "%s Please enter a number greater than \x040", MSG_PREFIX);
        return Plugin_Handled;
    }

    if (points < amount)
    {
        PrintToChat(client,
                    "%s You only have \x04%d\x01 points", MSG_PREFIX, points);
        return Plugin_Handled;
    }

    AddPoints(client, -amount, false, true);
    AddRepByGang(sCacheGang[client], amount);

    TellPoints(client);
    TellRep(client);

    if (amount >= 500)
    {
        decl String:path[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, path, sizeof(path), "scripting/donate.log");

        new Handle:iFile = OpenFile(path, "a");

        decl String:client_steamid[32];
        GetClientAuthString2(client, client_steamid, sizeof(client_steamid));

        LogToOpenFile(iFile,
                      "%N (%s) donated %d to %s",
                      client, client_steamid, amount, sCacheGang[client]);

        CloseHandle(iFile);
        BuildPath(Path_SM, path, sizeof(path), "logs/donate.log");

        iFile = OpenFile(path, "a");
        LogToOpenFile(iFile,
                      "%N (%s) donated %d to %s",
                      client, client_steamid, amount, sCacheGang[client]);

        CloseHandle(iFile);
    }

    return Plugin_Handled;
}


/* ----- Functions ----- */


stock TogglePerk(client)
{
    if (bPerkEnabled[client])
    {
        bPerkEnabled[client] = false;
        SetClientCookie(client, hPerksEnabled, "0");

        PrintToChat(client, "%s Your perk is now \x04disabled", MSG_PREFIX);
    }

    else
    {
        bPerkEnabled[client] = true;
        SetClientCookie(client, hPerksEnabled, "1");

        PrintToChat(client, "%s Your perk is now \x04enabled", MSG_PREFIX);
    }
}

stock ConstructGangMenus()
{
    decl String:query[256];

    if (hJoinGangByNameMenu != INVALID_HANDLE)
        CloseHandle(hJoinGangByNameMenu);

    if (hJoinGangByOwnerMenu != INVALID_HANDLE)
        CloseHandle(hJoinGangByOwnerMenu);

    hJoinGangByNameMenu = CreateMenu(JoinGangMenuSelect);
    hJoinGangByOwnerMenu = CreateMenu(JoinGangMenuSelect);

    SetMenuTitle(hJoinGangByNameMenu, "Join Gang By Name");
    SetMenuTitle(hJoinGangByOwnerMenu, "Join Gang By Owner");

    SetMenuExitBackButton(hJoinGangByNameMenu, true);
    SetMenuExitBackButton(hJoinGangByOwnerMenu, true);

    Format(query, sizeof(query),
           "SELECT name, level, private, ownername FROM gangs WHERE private = 0 ORDER BY name");
    SQL_TQuery(hDrugDB, ConstructGangMenusCallback, query, 1);

    Format(query, sizeof(query),
           "SELECT name, level, private, ownername FROM gangs WHERE private = 0 ORDER BY ownername");
    SQL_TQuery(hDrugDB, ConstructGangMenusCallback, query, 0);
}


/* ----- Menus ----- */


public JoinLeaveGangMenuSelect(Handle:menu,
                               MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayMenu(hMainMenu, client, DEFAULT_TIMEOUT);

    if (action == MenuAction_Select)
    {
        switch (selected + 1)
        {
            case 1:
                DisplayMenu(hJoinGangByNameMenu, client, DEFAULT_TIMEOUT);

            case 2:
                DisplayMenu(hJoinGangByOwnerMenu, client, DEFAULT_TIMEOUT);

            case 3:
                DisplayMenu(hConfirmLeaveGangMenu, client, DEFAULT_TIMEOUT);
        }
    }
}

public JoinGangMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
        {
            // It's a temp "invite" menu.
            if (menu != hJoinGangByNameMenu && menu != hJoinGangByOwnerMenu)
                CloseHandle(menu);
        }

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                DisplayMenu(hJoinGangMenu, client, DEFAULT_TIMEOUT);
        }

        case MenuAction_Select:
        {
            new Handle:hData = CreateDataPack();

            decl String:text[MAX_NAME_LENGTH + 10];
            decl String:sParts[2][MAX_NAME_LENGTH];

            GetMenuItem(menu, selected, text, sizeof(text));
            ExplodeString(text, " - ", sParts, 2, MAX_NAME_LENGTH);

            if (!selected && StrEqual(text, "meow - 0"))
                return;

            /* Error */
            if (!StringToInt(sParts[1]))
                CloseHandle(hData);

            new cost = StringToInt(sParts[1]);
            new points = GetPoints(client);

            if (points < cost)
            {
                PrintToChat(client,
                            "%s You need \x04%d\x01 points to join \x04%d",
                            MSG_PREFIX, cost, sParts[0]);
                return;
            }

            if (!StrEqual(sCacheGang[client], "None"))
            {
                PrintToChat(client,
                            "%s You must leave \x04%s \x01first",
                            MSG_PREFIX, sCacheGang[client]);
                return;
            }

            AddPoints(client, -cost);
            TellPoints(client);

            strcopy(sCacheGang[client], MAX_NAME_LENGTH, sParts[0]);
            memberType[client] = MEMBERTYPE_MEMBER;

            decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
            SQL_EscapeString(hDrugDB, sParts[0], sNewName, sizeof(sNewName));

            decl String:query[256];
            decl String:steamid[32];

            GetClientAuthString2(client, steamid, sizeof(steamid));

            Format(query, sizeof(query),
                   "UPDATE playerdata SET gang = '%s' WHERE steamid = '%s'",
                   sNewName, steamid);

            SQL_TQuery(hDrugDB, EmptyCallback, query);

            Format(query, sizeof(query),
                   "UPDATE gangs SET membercount = membercount + 1 WHERE name = '%s'",
                   sNewName);

            SQL_TQuery(hDrugDB, EmptyCallback, query);
        }
    }
}

public ConfirmLeaveGangMenuSelect(Handle:menu,
                                  MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayMenu(hJoinGangMenu, client, DEFAULT_TIMEOUT);

    if (action == MenuAction_Select && selected == 1)
    {
        if (StrEqual(sCacheGang[client], "None"))
        {
            PrintToChat(client, "%s You aren't in a gang...", MSG_PREFIX);
            return;
        }

        decl String:query[256];
        decl String:steamid[32];
        decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];

        SQL_EscapeString(hDrugDB, sCacheGang[client], sNewName, sizeof(sNewName));
        GetClientAuthString2(client, steamid, sizeof(steamid));

        Format(query, sizeof(query),
               "UPDATE playerdata SET gang = 'None', contributed = 0, isowner = 0, joined = 0 WHERE steamid = '%s'",
               steamid);

        SQL_TQuery(hDrugDB, EmptyCallback, query);
        PrintToChat(client, "%s Leaving current gang...", MSG_PREFIX);

        /* Check if the person who just left was the leader of the gang */
        Format(query, sizeof(query),
               "SELECT name FROM gangs WHERE ownersteamid = '%s'", steamid);
        SQL_TQuery(hDrugDB, LeaveGangMenuCheckPassCallback, query, client);
        
        Format(query, sizeof(query),
               "UPDATE gangs SET membercount = membercount - 1 WHERE name = '%s'",
               sNewName);

        SQL_TQuery(hDrugDB, EmptyCallback, query);
        sCacheGang[client] = "None";

        memberType[client] = MEMBERTYPE_NONE;
    }
}


/* ----- Callbacks ----- */


public ConstructGangMenusCallback(Handle:hGang, Handle:hndl,
                                  const String:error[], any:type)
{
    new iCostPerLevel = GetConVarInt(hCostPerLevel);

    if (!SQL_GetRowCount(hndl))
        AddMenuItem(type ? hJoinGangByNameMenu : hJoinGangByOwnerMenu,
                    "", "No Valid Gangs", ITEMDRAW_DISABLED);

    while (SQL_FetchRow(hndl))
    {
        /* Is the gang private */
        if (SQL_FetchInt(hndl, 2))
            return;

        new level = SQL_FetchInt(hndl, 1);
        new cost = iCostPerLevel * level;

        decl String:sGangName[MAX_NAME_LENGTH];
        decl String:sOwnerName[MAX_NAME_LENGTH];
        decl String:sPassText[MAX_NAME_LENGTH + 10];

        SQL_FetchString(hndl, 0, sGangName, sizeof(sGangName));
        SQL_FetchString(hndl, 3, sOwnerName, sizeof(sOwnerName));

        Format(sPassText, sizeof(sPassText),
                "%s - %i", sGangName, cost);

        /* Add the the menu based on gang name */
        if (type)
            AddMenuItem(hJoinGangByNameMenu, sPassText, sPassText);

        /* Add to the menu based on owner name */
        else
        {
            decl String:sDisplay[MAX_NAME_LENGTH + 10];
            Format(sDisplay, sizeof(sDisplay), "%s - %i", sOwnerName, cost);

            AddMenuItem(hJoinGangByOwnerMenu, sPassText, sDisplay);
        }
    }
}

public LeaveGangMenuCheckPassCallback(Handle:hGang,
                                      Handle:hndl, const String:error[], any:client)
{
    if (SQL_FetchRow(hndl))
    {
        decl String:query[256];
        decl String:sGangName[MAX_NAME_LENGTH];
        decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];

        SQL_FetchString(hndl, 0, sGangName, sizeof(sGangName));
        SQL_EscapeString(hDrugDB, sGangName, sNewName, sizeof(sNewName));

        Format(query, sizeof(query),
               "SELECT steamid, name FROM playerdata WHERE gang = '%s' ORDER BY contributed DESC LIMIT 1",
               sNewName);

        new Handle:hData = CreateDataPack();

        WritePackCell(hData, GetClientUserIdSafe(client));
        WritePackString(hData, sNewName);

        SQL_TQuery(hDrugDB, PassLeaderCallback, query, hData);
    }
}

public PassLeaderCallback(Handle:hGang,
                          Handle:hndl, const String:error[], any:hData)
{
    ResetPack(hData);
    new client = GetClientOfUserId(ReadPackCell(hData));

    if (!client)
    {
        CloseHandle(hData);
        return;
    }

    decl String:query[256];
    decl String:steamid[32];

    if (!SQL_FetchRow(hndl))
    {
        GetClientAuthString2(client, steamid, sizeof(steamid));
        Format(query, sizeof(query),
               "DELETE FROM gangs WHERE ownersteamid = '%s'", steamid);

        SQL_TQuery(hDrugDB, EmptyCallback, query);
        PrintToChat(client, "%s A gang died today. Tragic.", MSG_PREFIX);

        CloseHandle(hData);
        return;
    }

    decl String:sGangName[MAX_NAME_LENGTH * 2 + 1];
    ReadPackString(hData, sGangName, sizeof(sGangName));

    SQL_FetchString(hndl, 0, steamid, sizeof(steamid));

    decl String:name[MAX_NAME_LENGTH];
    SQL_FetchString(hndl, 1, name, sizeof(name));

    decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
    SQL_EscapeString(hDrugDB, name, sNewName, sizeof(sNewName));

    Format(query, sizeof(query),
           "UPDATE gangs SET ownersteamid = '%s', ownername = '%s' WHERE name = '%s'",
           steamid, sNewName, sGangName);

    SQL_TQuery(hDrugDB, EmptyCallback, query);
    CloseHandle(hData);

    Format(query, sizeof(query),
           "UPDATE playerdata SET isowner = 1 WHERE steamid = '%s'", steamid);
    SQL_TQuery(hDrugDB, EmptyCallback, query);
}

public SetGangPerkCallback(Handle:hDrug,
                           Handle:hndl, const String:error[], any:client)
{
    client = GetClientOfUserId(client);
    if (!client || !JB_IsPlayerAlive(client))
        return;

    if (SQL_FetchRow(hndl))
    {
        decl String:sPerkName[48];
        decl String:sCost[8];
        decl String:sDrain[8];
        decl String:sMultiplier[8];
        decl String:sGiveType[8];
        decl String:sCommand[128];

        SQL_FetchString(hndl, 0, sPerkName, sizeof(sPerkName));

        if (StrEqual("None", sPerkName))
            return;

        KvRewind(hGangPerks);
        KvJumpToKey(hGangPerks, sPerkName);

        KvGetSectionName(hGangPerks, sPerkName, sizeof(sPerkName));

        KvGetString(hGangPerks, "cost", sCost, sizeof(sCost));
        KvGetString(hGangPerks, "drain", sDrain, sizeof(sDrain));
        KvGetString(hGangPerks, "command", sCommand, sizeof(sCommand));
        KvGetString(hGangPerks, "multiplier", sMultiplier, sizeof(sMultiplier));
        KvGetString(hGangPerks, "givetype", sGiveType, sizeof(sGiveType));

        new rep = GetRepByGang(sCacheGang[client]);
        new perkdrain_per = StringToInt(sDrain);
        new level = SQL_FetchInt(hndl, 1);
        new givetype = StringToInt(sGiveType);
        new Float:perkmultiplier = StringToFloat(sMultiplier);
        new Float:basechance = KvGetFloat(hGangPerks, "basechance");
        new Float:baseadd = KvGetFloat(hGangPerks, "baseadd");
        new perkdrain;

        if (!GetTrieValue(hPerksGiven, sCacheGang[client], perkdrain))
            perkdrain = 1;

        SetTrieValue(hPerksGiven, sCacheGang[client], perkdrain + 1);
        perkdrain = RoundToNearest((1.0 / perkdrain) * perkdrain_per);

        if (rep < perkdrain)
        {
            PrintHintText(client,
                          "!donate <amount> to keep your gang perk active");
            return;
        }

        AddRepByGang(sCacheGang[client], -perkdrain);

        decl String:sAmount[8];
        FloatToString(baseadd + (level * perkmultiplier), sAmount, sizeof(sAmount));

        decl String:sUserid[8];
        IntToString(GetClientUserIdSafe(client), sUserid, sizeof(sUserid));

        ReplaceString(sCommand,
                      sizeof(sCommand), "%userid", sUserid, false);

        ReplaceString(sCommand,
                      sizeof(sCommand), "%multiplier", sAmount, false);

        if (givetype)
        {
            if (GetRandomFloat() <= basechance || !basechance)
                ServerCommand(sCommand);
    
            else
                PrintToChat(client, "%s No perk this time :(", MSG_PREFIX);
        }

        else if (GetRandomFloat() <= StringToFloat(sAmount))
            ServerCommand(sCommand);

        else
            PrintToChat(client, "%s No perk this time :(", MSG_PREFIX);
    }
}
