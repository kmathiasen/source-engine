
new g_iDisabledRounds = 0;
new iLastPurchase[MAXPLAYERS + 1];

new Handle:hPerksMenu = INVALID_HANDLE;
new Handle:hPerks = INVALID_HANDLE;
new Handle:hUseEveryTrie = INVALID_HANDLE;
new Handle:hUseEveryArray = INVALID_HANDLE;
new Handle:hUsedThisRound = INVALID_HANDLE;
new Handle:hCoolDownTrie = INVALID_HANDLE;
new Handle:hCoolDownArray = INVALID_HANDLE;

new String:sPerkPath[PLATFORM_MAX_PATH];

/* ----- Events ----- */


public BuyMenu_OnPluginStart()
{
    BuildPath(Path_SM, sPerkPath, PLATFORM_MAX_PATH, "data/perks.txt");
    if (!FileExists(sPerkPath))
        SetFailState("No location data file \"./data/perks.txt\"");

    RegConsoleCmd("buy", Command_BuyPerks);
    RegConsoleCmd("sm_buy", Command_BuyPerks);

    /* Buy Perks, !buy, Menu */
    hPerksMenu = CreateMenu(PerksMenuSelect);
    SetMenuTitle(hPerksMenu, "Select Your Perk");

    BuildPerksMenu();

    hUseEveryTrie = CreateTrie();
    hUsedThisRound = CreateTrie();
    hCoolDownTrie = CreateTrie();

    hCoolDownArray = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
    hUseEveryArray = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
}

public BuyMenu_OnRoundStart()
{
    ClearTrie(hUsedThisRound);
    g_iDisabledRounds--;

    for (new i = 0; i < GetArraySize(hUseEveryArray); i++)
    {
        decl String:key[MAX_NAME_LENGTH];
        GetArrayString(hUseEveryArray, i, key, sizeof(key));

        new rounds_left;
        GetTrieValue(hUseEveryTrie, key, rounds_left);

        if (--rounds_left <= 0)
        {
            RemoveFromTrie(hUseEveryTrie, key);
            RemoveFromArray(hUseEveryArray, i--);
        }

        else
            SetTrieValue(hUseEveryTrie, key, rounds_left);
    }

    for (new i = 0; i < GetArraySize(hCoolDownArray); i++)
    {
        decl String:steamid[32];
        GetArrayString(hCoolDownArray, i, steamid, sizeof(steamid));

        new rounds_left;
        GetTrieValue(hCoolDownTrie, steamid, rounds_left);

        if (--rounds_left <= 0)
        {
            RemoveFromTrie(hCoolDownTrie, steamid);
            RemoveFromArray(hCoolDownArray, i--);
        }

        else
            SetTrieValue(hCoolDownTrie, steamid, rounds_left);
    }
}


/* ----- Commands ----- */


public Action:Command_BuyPerks(client, args)
{
    if (!client)
    {
        PrintToServer("[Gangs]: You must be in game to use this command");
        return Plugin_Handled;
    }

    if (bIsThursday)
    {
        PrintToChat(client, "%s Sorry, this feature is disabled due to \x04Throwback Thursday", MSG_PREFIX);
        return Plugin_Handled;
    }

    /* Player's a CT, let the AIO script handle it */
    if (GetClientTeam(client) == 3)
        return Plugin_Continue;

    if ((GetTime() - iRoundStartTime) > GetConVarInt(hBuyTime))
    {
        PrintToChat(client, "%s Buy time is up!", MSG_PREFIX);
        return Plugin_Handled;
    }

    if (GetClientTeam(client) != 2 || !JB_IsPlayerAlive(client))
    {
        PrintToChat(client,
                    "%s You must be an alive terrorist to use this command",
                    MSG_PREFIX);
        return Plugin_Handled;
    }

    DisplayMenu(hPerksMenu, client, GetConVarInt(hBuyTime));
    TellPoints(client);

    return Plugin_Handled;
}


/* ----- Functions ----- */


stock BuildPerksMenu()
{
    decl String:sKeyName[MAX_NAME_LENGTH];
    decl String:title[MAX_NAME_LENGTH + 12];

    hPerks = CreateKeyValues("perks");
    FileToKeyValues(hPerks, sPerkPath);

    KvGotoFirstSubKey(hPerks);

    do
    {
        KvGetSectionName(hPerks, sKeyName, sizeof(sKeyName));

        Format(title, sizeof(title),
               "%s - %d", sKeyName, KvGetNum(hPerks, "cost"));

        AddMenuItem(hPerksMenu, sKeyName, title);
    } while (KvGotoNextKey(hPerks));
}

stock DoBuy(client, const String:key[])
{
    KvRewind(hPerks);
    KvJumpToKey(hPerks, key);

    new cost = KvGetNum(hPerks, "cost");
    new useevery = KvGetNum(hPerks, "use every");
    new maxround = KvGetNum(hPerks, "maxround");
    new new_cooldown = KvGetNum(hPerks, "cooldown");
    new global = KvGetNum(hPerks, "global");
    new rounds_left;
    new cooldown;

    if (GetPoints(client) < cost)
    {
        PrintToChat(client,
                    "%s You need \x04%d\x01 points to buy this",
                    MSG_PREFIX, cost);
        return;
    }

    decl String:steamid[32];
    GetClientAuthString2(client, steamid, sizeof(steamid));

    if (GetTrieValue(hCoolDownTrie, steamid, cooldown))
    {
        PrintToChat(client,
                    "%s Woh hold on a minute there pardna'. We're outa stock in this hur buy menu.",
                    MSG_PREFIX);

        PrintToChat(client,
                    "%s Try comin' back in \x04%d\x01 round(s), ya hear?",
                    MSG_PREFIX, cooldown);

        return;
    }

    new used_this_round;
    GetTrieValue(hUsedThisRound, key, used_this_round);

    if (maxround && used_this_round >= maxround)
    {
        PrintToChat(client,
                    "%s This command has already been used \x03%d\x04 times this round",
                    MSG_PREFIX, used_this_round);
        return;
    }

    if (GetTrieValue(hUseEveryTrie, key, rounds_left))
    {
        PrintToChat(client,
                    "%s This command can not be used for another \x04%d\x01 rounds",
                    MSG_PREFIX, rounds_left);
        return;
    }

    if (GetTime() == iLastPurchase[client])
    {
        PrintToChat(client,
                    "%s WOOH. Slow down there, pardna. Your girlfriend wouldn't like it if you were that quick with her.",
                    MSG_PREFIX);
        return;
    }

    iLastPurchase[client] = GetTime(); 
    SetTrieValue(hUsedThisRound, key, used_this_round + 1);

    if (useevery)
    {
        PushArrayString(hUseEveryArray, key);
        SetTrieValue(hUseEveryTrie, key, useevery);
    }

    if (new_cooldown && !maxround)
    {
        PushArrayString(hCoolDownArray, steamid);
        SetTrieValue(hCoolDownTrie, steamid, new_cooldown);
    }

    else if (maxround && used_this_round >= maxround - 1)
    {
        PushArrayString(hCoolDownArray, steamid);
        SetTrieValue(hCoolDownTrie, steamid, new_cooldown);
    }

    if (global > 0 && global > g_iDisabledRounds)
        g_iDisabledRounds = global + 1;

    decl String:sUserid[7];
    decl String:sCommand[255];

    KvGetString(hPerks, "command", sCommand, sizeof(sCommand));
    IntToString(GetClientUserIdSafe(client), sUserid, sizeof(sUserid));
    ReplaceString(sCommand, sizeof(sCommand), "%userid", sUserid, false);

    AddPoints(client, -cost);
    ServerCommand(sCommand);

    decl String:path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "scripting/buymenu.log");

    new Handle:iFile = OpenFile(path, "a");

    decl String:client_steamid[32];
    GetClientAuthString2(client, client_steamid, sizeof(client_steamid));

    LogToOpenFile(iFile,
                  "%N (%s) bought %s for %d",
                  client, client_steamid, key, cost);

    CloseHandle(iFile);
    BuildPath(Path_SM, path, sizeof(path), "logs/buymenu.log");

    iFile = OpenFile(path, "a");
    LogToOpenFile(iFile,
                  "%N (%s) bought %s for %d",
                  client, client_steamid, key, cost);

    CloseHandle(iFile);
}

bool:CanBuy(client)
{
    if ((GetTime() - iRoundStartTime) > GetConVarInt(hBuyTime))
    {
        PrintToChat(client, "%s Buy time is up!", MSG_PREFIX);
        return false;
    }

    if (g_iDisabledRounds > 0)
    {
        PrintToChat(client,
                    "%s The guards have become suspicious of our shop... Come back in \x03%d\x01 rounds",
                    MSG_PREFIX, g_iDisabledRounds);
        return false;
    }

    if (GetClientTeam(client) != 2 || !JB_IsPlayerAlive(client))
    {
        PrintToChat(client,
                    "%s You must be an alive terrorist to use this command",
                    MSG_PREFIX);
        return false;
    }

    return true;
}


/* ----- Menus ----- */


public PerksConfirmMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                FakeClientCommand(client, "sm_buy");
        }

        case MenuAction_Select:
        {
            if (selected == 1 && CanBuy(client))
            {
                decl String:key[MAX_NAME_LENGTH];
                GetMenuItem(menu, selected, key, sizeof(key));

                DoBuy(client, key);
            }
        }
    }
}

public PerksMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (action != MenuAction_Select || !CanBuy(client))
        return;

    decl String:key[MAX_NAME_LENGTH];
    GetMenuItem(menu, selected, key, sizeof(key));

    KvRewind(hPerks);
    KvJumpToKey(hPerks, key);

    new cost = KvGetNum(hPerks, "cost");

    if (cost >= 1000)
    {
        new Handle:hConfirmBuy = CreateMenu(PerksConfirmMenuSelect);

        decl String:title[MAX_NAME_LENGTH + 6];
        Format(title, sizeof(title), "Buy %s?", key);

        SetMenuTitle(hConfirmBuy, title);
        SetMenuExitBackButton(hConfirmBuy, true);

        AddMenuItem(hConfirmBuy, "", "No");
        AddMenuItem(hConfirmBuy, key, "Yes");

        DisplayMenu(hConfirmBuy, client,
                    GetConVarInt(hBuyTime) - (GetTime() - iRoundStartTime));
    }

    else
        DoBuy(client, key);
}
