// ###################### GLOBALS ######################


// Tracks all the items by type
new Handle:g_hHats = INVALID_HANDLE;
new Handle:g_hItems = INVALID_HANDLE;
new Handle:g_hTrails = INVALID_HANDLE;
new Handle:g_hModels = INVALID_HANDLE;

new Handle:g_hItemPrices = INVALID_HANDLE;
new Handle:g_hPlayerCredits = INVALID_HANDLE;

new g_iShopSubTypeSelected[MAXPLAYERS + 1];
new g_iShopAtItem[MAXPLAYERS + 1];

new String:g_sSubTypeChosen[MAXPLAYERS + 1][MAX_NAME_LENGTH];

// ###################### EVENTS ######################


stock Shop_OnPluginStart()
{
    g_hHats = CreateArray(LEN_NAMES);
    g_hItems = CreateArray(LEN_NAMES);
    g_hTrails = CreateArray(LEN_NAMES);
    g_hModels = CreateArray(LEN_NAMES);

    g_hItemPrices = CreateTrie();
    g_hPlayerCredits = CreateTrie();

    RegConsoleCmd("sm_shop", Command_ShopMenu);
    RegConsoleCmd("sm_store", Command_ShopMenu);
    RegConsoleCmd("shop", Command_ShopMenu);
    RegConsoleCmd("store", Command_ShopMenu);

    RegServerCmd("hg_premium_resync", Command_ReSync, "Resync a player's items");
    RegServerCmd("youbetternotusethis", Command_GiveAllItems);
}

stock Shop_OnDBConnect()
{
    decl String:query[256];
    Format(query, sizeof(query),
           "SELECT type, cost, name, subtype, vip_only, admin_only FROM items WHERE (servertype & %d) and (servertype > 0) ORDER BY name",
           g_iServerType);

    SQL_TQuery(g_hDbConn, GrabItemsCallback, query);
}

stock Shop_OnClientFullyAuthorized(client, const String:steamid[])
{
    decl String:query[512];
    Format(query, sizeof(query),
           "SELECT credits FROM players WHERE steamid = '%s'", steamid);

    SQL_TQuery(g_hDbConn, CachePlayerCredits, query, GetClientUserId(client));

    Format(query, sizeof(query),
           "SELECT type, subtype, name, filepath FROM items WHERE (default_model > 0) and (servertype & %d) and (type = %d) and (servertype > 0)",
           g_iServerType, ITEMTYPE_MODEL);

    SQL_TQuery(g_hDbConn,
               GrabClientShitCallback, query, -1 * GetClientUserId(client));

    Format(query, sizeof(query),
           "SELECT i.type, i.subtype, i.name, i.filepath FROM items i JOIN playeritems pi ON pi.itemid = i.id JOIN players p ON p.id = pi.playerid WHERE (p.steamid = '%s') and (i.servertype & %d) and (i.default_model = 0) and (i.servertype > 0) ORDER BY i.name",
           steamid, g_iServerType);

    SQL_TQuery(g_hDbConn,
               GrabClientShitCallback, query, GetClientUserId(client));
}

stock Shop_OnClientDisconnect(client)
{
    decl String:steamid[LEN_STEAMIDS];
    GetClientAuthString2(client, steamid, sizeof(steamid));

    // Who care's if they were in it or not, no error will be thrown if they aren't.
    RemoveFromTrie(g_hPlayerCredits, steamid);
}


// ###################### COMMANDS ######################


public Action:Command_GiveAllItems(args)
{
    if (args != 2)
    {
        ReplyToCommand(0, "Invalid syntax -- youbetternotusethis \"<steamid>\" <level (1 = UM, 2 = DL, 3 = DA)>");
        return Plugin_Handled;
    }

    decl String:steamid[32];
    decl String:sAmount[8];

    GetCmdArg(1, steamid, sizeof(steamid));
    GetCmdArg(2, sAmount, sizeof(steamid));

    new level = StringToInt(sAmount);

    if (!level)
    {
        ReplyToCommand(0, "Invalid amount");
        return Plugin_Handled;
    }

    if (SimpleRegexMatch(steamid, REGEX_STEAMID) <= 0)
    {
        ReplyToCommand(0, "Invalid Steamid");
        return Plugin_Handled;
    }

    decl String:query[512];
    Format(query, sizeof(query),
           "INSERT INTO playeritems (playerid, itemid) SELECT p.id, i.id FROM players p JOIN items i WHERE p.steamid = '%s' AND not (i.id %% %d)",
           steamid, level);

    decl String:path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "scripting/hg_premium_admingiveitems.log");

    LogToFile(path, query);
    SQL_TQuery(g_hDbConn, EmptyCallback, query);

    return Plugin_Handled;
}

public Action:Command_ReSync(args)
{
    if (!args)
    {
        new count;
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && GetUserFlagBits(i))
            {
                Resync(i);
                count++;
            }
        }

        ReplyToCommand(0, "HG Premium: Successfuly found %d players to resync", count);
        return Plugin_Handled;
    }

    decl String:target_steamid[LEN_STEAMIDS];
    decl String:client_steamid[LEN_STEAMIDS];

    for (new i = 1; i <= MaxClients; i++)
    {
        GetClientAuthString2(i, client_steamid, sizeof(client_steamid));
        if (StrEqual(client_steamid, target_steamid))
        {
            Resync(i);
            ReplyToCommand(0, "HG Premium: Successfully found \"%N\" to resync", i);

            return Plugin_Handled;
        }
    }

    ReplyToCommand(0, "HG Premium: Failed to find players to update");
    return Plugin_Handled;
}

public Action:Command_ShopMenu(client, args)
{
    if (IsAuthed(client) && !DatabaseFailure(client))
        ShopMainMenu(client);
    return Plugin_Handled;
}


// ###################### FUNCTIONS ######################


stock Resync(client)
{
    decl String:steamid[LEN_STEAMIDS];
    GetClientAuthString2(client, steamid, sizeof(steamid));

    Shop_OnClientFullyAuthorized(client, steamid);
    Hats_OnClientFullyAuthorized(client, steamid);
    Trails_OnClientFullyAuthorized(client, steamid);
}

stock CreateShopMenu(client, Handle:arr, const String:name[], itemtype, at_item, bool:subtype=false)
{
    new credits = Shop_GetCredits(client);
    new Handle:menu = CreateMenu(ItemsShopSelect);
    new Handle:already_subs = CreateArray(ByteCountToCells(LEN_NAMES));

    // If someone has less than 0 credits, then there must have been a DB error.
    // So let's let them know that, so they don't freak out and rage on the forums.

    decl String:title[64] = "HG Shop (ERROR GETTING CREDITS)";
    if (credits > -1)
        Format(title, sizeof(title), "HG %s Shop (%d credits)", name, credits);

    SetMenuTitle(menu, title);
    SetMenuExitBackButton(menu, true);

    decl String:item[LEN_NAMES];
    decl String:sub[LEN_NAMES];
    decl String:display[LEN_NAMES + LEN_INTSTRING + 8];

    new i, cost;
    new bool:found;

    for (i = 0; i < GetArraySize(arr); i++)
    {
        GetArrayString(arr, i, item, sizeof(item));
        GetTrieValue(g_hItemPrices, item, cost);

        new bool:to_add;

        switch(itemtype)
        {
            case ITEMTYPE_NONE:
            {
                if (GetTrieString(g_hItemSubTypes, item, sub, sizeof(sub)))
                {
                    new item_index = GetItemIndex(sub);

                    if (!Items_HasSubItem(client, item, item_index))
                        to_add = true;
                }

                else
                {
                    new item_index = GetItemIndex(item);

                    if (!g_bClientHasItem[client][item_index])
                        to_add = true;
                }
            }

            case ITEMTYPE_HAT:
            {
                if (FindStringInArray(g_hPlayerHats[client], item) == -1)
                    to_add = true;
            }

            case ITEMTYPE_TRAIL:
            {
                if (FindStringInArray(g_hPlayerTrails[client], item) == -1)
                    to_add = true;
            }

            case ITEMTYPE_COMMAND:
            {
                if (FindStringInArray(g_hPlayerCommands[client], item) == -1)
                    to_add = true;
            }

            case ITEMTYPE_MODEL:
            {
                if (FindStringInArray(g_hPlayerModels[client], item) == -1)
                    to_add = true;
            }
        }

        if (to_add)
        {
            found = true;

            if (!subtype)
            {
                if (GetTrieString(g_hItemSubTypes, item, sub, sizeof(sub)))
                {
                    if (FindStringInArray(already_subs, sub) > -1)
                        continue;

                    AddMenuItem(menu, sub, sub);
                    PushArrayString(already_subs, sub);

                    continue;
                }
            }

            decl String:sCost[16];
            IntToString(cost, sCost, sizeof(sCost));

            if (cost <= 0)
                Format(sCost, sizeof(sCost), "Free");
    
            decl String:restricted[24];
            new drawtype = GetRestrictedPrefix(item, client, restricted, sizeof(restricted));

            Format(display, sizeof(display), "%s - %s%s", item, sCost, restricted);
            AddMenuItem(menu, item, display, drawtype);
        }
    }

    g_iShopSubTypeSelected[client] = subtype ? itemtype : SUBTYPE_NONE;

    // No items were found, gotta add something or the menu won't send.
    if (!i)
        AddMenuItem(menu, "", "NONE ENABLED FOR THIS GAME", ITEMDRAW_DISABLED);

    else if (!found)
        AddMenuItem(menu, "", "No more :(", ITEMDRAW_DISABLED);

    DisplayMenuAtItem(menu, client, at_item, MENU_TIME_FOREVER);
}

stock ItemsShop(client, at_item=0)
{
    CreateShopMenu(client, g_hItems, "Items", ITEMTYPE_NONE, at_item);
}

stock HatsShop(client, at_item=0)
{
    CreateShopMenu(client, g_hHats, "Attachments", ITEMTYPE_HAT, at_item);
}

stock TrailsShop(client, at_item=0)
{
    CreateShopMenu(client, g_hTrails, "Trails", ITEMTYPE_TRAIL, at_item);
}

stock CommandsShop(client, at_item=0)
{
    CreateShopMenu(client, g_hCommands, "Commands", ITEMTYPE_COMMAND, at_item);
}

stock ModelsShop(client, at_item=0)
{
    CreateShopMenu(client, g_hModels, "Models", ITEMTYPE_MODEL, at_item);
}

stock ShopMainMenu(client)
{
    new credits = Shop_GetCredits(client);
    new Handle:menu = CreateMenu(ShopMainMenuSelect);

    decl String:title[64] = "HG Items Shop (ERROR GETTING CREDITS)";
    if (credits > -1)
        Format(title, sizeof(title), "HG Items Shop (%d credits)", credits);

    SetMenuTitle(menu, title);
    SetMenuExitBackButton(menu, true);

    AddMenuItem(menu, "", "Items");
    AddMenuItem(menu, "", "Attachments");
    AddMenuItem(menu, "", "Trails");
    AddMenuItem(menu, "", "Commands");
    AddMenuItem(menu, "", "Models");

    DisplayMenu(menu, client, MENU_TIME_FOREVER);
    g_iShopAtItem[client] = 0;
}

Shop_GetCredits(client)
{
    decl String:steamid[LEN_STEAMIDS];
    GetClientAuthString2(client, steamid, sizeof(steamid));

    new credits;
    return GetTrieValue(g_hPlayerCredits, steamid, credits) ? credits : -1;
}

// This function is used generally for purchases.
// Because purchases involve real money, we don't care about server strain.

stock Shop_AddCredits(client, amount)
{
    new credits;
    decl String:query[256];
    decl String:steamid[LEN_STEAMIDS];

    GetClientAuthString2(client, steamid, sizeof(steamid));
    Format(query, sizeof(query),
           "UPDATE players SET credits = credits + %d WHERE steamid = '%s'",
           amount, steamid);

    decl String:path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "scripting/hg_premium.log");

    LogToFile(path, query);

    SQL_TQuery(g_hDbConn, EmptyCallback, query);

    GetTrieValue(g_hPlayerCredits, steamid, credits);
    SetTrieValue(g_hPlayerCredits, steamid, credits + amount);
}

stock Shop_GiveItem(client, const String:item[])
{
    decl String:steamid[LEN_STEAMIDS];
    decl String:query[512];
    decl String:esc_item[LEN_NAMES * 2 + 1];

    GetClientAuthString2(client, steamid, sizeof(steamid));
    SQL_EscapeString(g_hDbConn, item, esc_item, sizeof(esc_item));

    Format(query, sizeof(query),
           "INSERT INTO playeritems (playerid, itemid) VALUES ((SELECT id FROM players WHERE steamid = '%s'), (SELECT id FROM items WHERE name = '%s'))",
           steamid, esc_item);

    decl String:path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "scripting/hg_premium.log");

    LogToFile(path, query);

    SQL_TQuery(g_hDbConn, EmptyCallback, query);
    PrintToChat(client, "%s You bought \x03%s", MSG_PREFIX, item);
}

// ###################### CALLBACKS ######################


public GrabClientShitCallback(Handle:main, Handle:hndl, const String:error[], any:client)
{
    new bool:default_model = (client < 0);

    client = GetClientOfUserId(client < 0 ? -client : client);
    if (!client)
        return;

    if (!CheckConnection(hndl, error))
        return;

    decl String:name[LEN_NAMES];
    decl String:subtype[LEN_NAMES];
    decl String:filepath[PLATFORM_MAX_PATH];
    decl String:val[8];

    if (g_hPlayerCommands[client] == INVALID_HANDLE)
        g_hPlayerCommands[client] = CreateArray(ByteCountToCells(LEN_NAMES));

    else
        ClearArray(g_hPlayerCommands[client]);

    while (SQL_FetchRow(hndl))
    {
        new itemtype = SQL_FetchInt(hndl, 0);

        SQL_FetchString(hndl, 1, subtype, sizeof(subtype));
        SQL_FetchString(hndl, 2, name, sizeof(name));
        SQL_FetchString(hndl, 3, filepath, sizeof(filepath));

        switch (itemtype)
        {
            case ITEMTYPE_NONE:
            {
                new index = GetItemIndex(name);

                if (index == -1)
                {
                    index = GetItemIndex(subtype);

                    if (index == -1)
                    {
                        LogError("HG Items: Item in database, \"%s\", was not found in the script", name);
                        continue;
                    }

                    decl String:active[PLATFORM_MAX_PATH];
                    GetClientCookie(client, g_hItemCookies[index], active, sizeof(active));

                    decl String:sval[PLATFORM_MAX_PATH];
                    GetTrieString(g_hSubTypesItemValues, active, sval, sizeof(sval));

                    Items_GivePlayerSubItem(client, name, index);
                    strcopy(g_sClientSubValue[client][index], PLATFORM_MAX_PATH, sval);
                }

                g_bClientHasItem[client][index] = true;

                if (IsAuthed(client, name, false))
                {
                    GetClientCookie(client, g_hItemCookies[index], val, sizeof(val));
                    g_bClientEquippedItem[client][index] = StrEqual(val, "0") ? false : true;
    
                    if (index == _:Item_ColoredName)
                        ClrNms_OnClientFullyAuthorized(client);
                }
            }

            case ITEMTYPE_HAT:
            {
                if (FindStringInArray(g_hPlayerHats[client], name) == -1)
                    PushArrayString(g_hPlayerHats[client], name);
            }

            case ITEMTYPE_TRAIL:
            {
                if (!GetTrieString(g_hTrailPaths, name, val, sizeof(val)))
                    continue;

                if (FindStringInArray(g_hPlayerTrails[client], name) == -1)
                    PushArrayString(g_hPlayerTrails[client], name);
            }

            case ITEMTYPE_COMMAND:
            {
                if (FindStringInArray(g_hPlayerCommands[client], name) == -1)
                    PushArrayString(g_hPlayerCommands[client], name);
            }

            case ITEMTYPE_MODEL:
            {
                if (FindStringInArray(g_hPlayerModels[client], name) == -1)
                    PushArrayString(g_hPlayerModels[client], name);
            }
        }
    }

    if (!default_model)
        JoinMessage_DisplayAdminMessage(client);
}

public ItemsShopSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch(action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
            {
                ShopMainMenuSelect(INVALID_HANDLE,
                                   MenuAction_Select,
                                   client, g_iShopSubTypeSelected[client]);

                g_sSubTypeChosen[client][0] = '\0';
            }
        }

        case MenuAction_Select:
        {
            decl String:item[LEN_NAMES];
            GetMenuItem(menu, selected, item, sizeof(item));

            decl Handle:hArrayOfShit;

            if (GetTrieValue(g_hSubTypes, item, hArrayOfShit))
            {
                new itemtype;
                GetTrieValue(g_hSubTypesItemTypes, item, itemtype);

                Format(g_sSubTypeChosen[client], MAX_NAME_LENGTH, item);
                CreateShopMenu(client, hArrayOfShit, item, itemtype, 0, true);

                return;
            }


            new cost;
            GetTrieValue(g_hItemPrices, item, cost);

            if (Shop_GetCredits(client) < cost)
            {
                PrintToChat(client,
                            "%s You need \x03%d\x04 credits to buy \x03%s",
                            MSG_PREFIX, cost, item);
                return;
            }

            Shop_AddCredits(client, -cost);
            Shop_GiveItem(client, item);

            new at_item = (selected / 7) * 7;
            new item_index = GetItemIndex(item);

            decl String:dummy[3];
            decl String:sub[LEN_NAMES];

            g_iShopAtItem[client] = at_item;

            if (GetTrieString(g_hItemSubTypes, item, sub, sizeof(sub)))
            {
                item_index = GetItemIndex(sub);
                if (item_index > -1)
                    Items_GivePlayerSubItem(client, item, item_index);
            }

            if (item_index > -1)
            {
                g_bClientHasItem[client][item_index] = true;
                g_iShopSubTypeSelected[client] = ITEMTYPE_NONE;
            }

            else if (HatFound(item))
            {
                PushArrayString(g_hPlayerHats[client], item);
                g_iShopSubTypeSelected[client] = ITEMTYPE_HAT;
            }

            else if (GetTrieString(g_hTrailPaths, item, dummy, sizeof(dummy)))
            {
                PushArrayString(g_hPlayerTrails[client], item);
                g_iShopSubTypeSelected[client] = ITEMTYPE_TRAIL;
            }

            else if (GetTrieString(g_hCommandExecuteTries, item, dummy, sizeof(dummy)))
            {
                PushArrayString(g_hPlayerCommands[client], item);
                g_iShopSubTypeSelected[client] = ITEMTYPE_COMMAND;
            }

            else if (GetTrieString(g_hPlayerModelPaths, item, dummy, sizeof(dummy)))
            {
                PushArrayString(g_hPlayerModels[client], item);
                g_iShopSubTypeSelected[client] = ITEMTYPE_MODEL;
            }

            else
                LogError("Unknown item \"%s\"", item);

            if (!StrEqual(g_sSubTypeChosen[client], "") &&
                GetTrieValue(g_hSubTypes, g_sSubTypeChosen[client], hArrayOfShit))
                CreateShopMenu(client,
                               hArrayOfShit,
                               g_sSubTypeChosen[client],
                               g_iShopSubTypeSelected[client],
                               0, true);

            else
                ShopMainMenuSelect(INVALID_HANDLE,
                                   MenuAction_Select,
                                   client, g_iShopSubTypeSelected[client]);
        }
    }
}

public ShopMainMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch(action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if(selected == MenuCancel_ExitBack)
                MainMenu(client);
        }

        case MenuAction_Select:
        {
            switch (selected)
            {
                case SUBTYPE_NONE:
                    ShopMainMenu(client);

                case ITEMTYPE_NONE:
                    ItemsShop(client, g_iShopAtItem[client]);

                case ITEMTYPE_HAT:
                    HatsShop(client, g_iShopAtItem[client]);

                case ITEMTYPE_TRAIL:
                    TrailsShop(client, g_iShopAtItem[client]);

                case ITEMTYPE_COMMAND:
                    CommandsShop(client, g_iShopAtItem[client]);

                case ITEMTYPE_MODEL:
                    ModelsShop(client, g_iShopAtItem[client]);
            }

            g_iShopAtItem[client] = 0;
            g_sSubTypeChosen[client][0] = '\0';
        }
    }
}

public CachePlayerCredits(Handle:main,
                          Handle:hndl, const String:error[], any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    if (!CheckConnection(hndl, error))
        return;

    decl String:steamid[LEN_STEAMIDS];
    GetClientAuthString2(client, steamid, sizeof(steamid));

    SQL_FetchRow(hndl);
    SetTrieValue(g_hPlayerCredits, steamid, SQL_FetchInt(hndl, 0));
}

public GrabItemsCallback(Handle:main,
                         Handle:hndl, const String:error[], any:data)
{
    if (!CheckConnection(hndl, error))
        return;

    // Since this happens every time the DB connects, clear all the arrays to avoid double entries.
    ClearArray(g_hHats);
    ClearArray(g_hItems);
    ClearArray(g_hTrails);
    ClearArray(g_hCommands);
    ClearArray(g_hModels);

    decl String:name[LEN_NAMES];
    decl String:subtype[LEN_NAMES];

    while(SQL_FetchRow(hndl))
    {
        new type = SQL_FetchInt(hndl, 0);
        new cost = SQL_FetchInt(hndl, 1);
        new vip_only = SQL_FetchInt(hndl, 4);
        new admin_only = SQL_FetchInt(hndl, 5);

        SQL_FetchString(hndl, 2, name, sizeof(name));
        SQL_FetchString(hndl, 3, subtype, sizeof(subtype));

        SetTrieValue(g_hItemPrices, name, cost);

        if (vip_only)
            PushArrayString(g_hVIPOnly, name);

        if (admin_only)
            PushArrayString(g_hAdminOnly, name);

        if (!StrEqual(subtype, ""))
        {
            SetTrieString(g_hItemSubTypes, name, subtype);
            SetTrieValue(g_hSubTypesItemTypes, subtype, type);

            decl Handle:hSubTypesArray;
            if (!GetTrieValue(g_hSubTypes, subtype, hSubTypesArray))
                hSubTypesArray = CreateArray(ByteCountToCells(LEN_NAMES));

            if (FindStringInArray(hSubTypesArray, name) == -1)
            {
                PushArrayString(hSubTypesArray, name);
                SetTrieValue(g_hSubTypes, subtype, hSubTypesArray);
            }
        }

        switch(type)
        {
            case ITEMTYPE_NONE:
            {
                if (GetItemIndex(name) == -1 && GetItemIndex(subtype) == -1)
                {
                    LogError("HG Items: item \"%s\" was found in the database, but not the script", name);
                    continue;
                }

                PushArrayString(g_hItems, name);
            }

            case ITEMTYPE_HAT:
                PushArrayString(g_hHats, name);

            case ITEMTYPE_TRAIL:
                PushArrayString(g_hTrails, name);

            case ITEMTYPE_COMMAND:
                PushArrayString(g_hCommands, name);

            case ITEMTYPE_MODEL:
                PushArrayString(g_hModels, name);
        }
    }
}
