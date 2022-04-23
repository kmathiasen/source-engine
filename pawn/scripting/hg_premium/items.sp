// ###################### GLOBALS ######################

enum Items
{
    Item_LaserAim = 0,
    Item_RagDoll,
    Item_MultiNade,
    Item_ExplosiveHeadShot,
    Item_DeathBeam,
    Item_Semtex,
    Item_JoinMessage,
    Item_StealthMode,
    Item_Tracers,
    Item_KnifeSyphon,
    Item_ColoredName,
    Item_MultipleAttachments,
    Item_ColoredChat,
    Item_Knives,
};


new bool:g_bClientEquippedItem[MAXPLAYERS + 1][Items];
new bool:g_bClientHasItem[MAXPLAYERS + 1][Items];
new bool:g_bItemInSubType[MAXPLAYERS + 1];

new Handle:g_hPlayerSubItems[MAXPLAYERS + 1][Items];
new Handle:g_hItemCookies[Items];
new String:g_sClientSubValue[MAXPLAYERS + 1][Items][PLATFORM_MAX_PATH];
new String:g_sItemCookieKeys[Items][MAX_NAME_LENGTH];
new String:g_sItemName[Items][LEN_NAMES];

// ###################### EVENTS ######################


stock Items_OnPluginStart()
{
    g_sItemCookieKeys[Item_LaserAim] = "hg_items_laser";
    g_sItemCookieKeys[Item_RagDoll] = "hg_items_ragdolls";
    g_sItemCookieKeys[Item_MultiNade] = "hg_items_multinade";
    g_sItemCookieKeys[Item_ExplosiveHeadShot] = "hg_items_explosive_headshots";
    g_sItemCookieKeys[Item_DeathBeam] = "hg_items_deathbeam";
    g_sItemCookieKeys[Item_Semtex] = "hg_items_semtex";
    g_sItemCookieKeys[Item_JoinMessage] = "hg_items_join_message_enabled";
    g_sItemCookieKeys[Item_StealthMode] = "hg_items_stealth_mode";
    g_sItemCookieKeys[Item_Tracers] = "hg_items_tracers";
    g_sItemCookieKeys[Item_KnifeSyphon] = "hg_items_knife_syphon";
    g_sItemCookieKeys[Item_ColoredName] = "hg_items_colored_name_enabled";
    g_sItemCookieKeys[Item_MultipleAttachments] = "hg_items_multiple_attachments";
    g_sItemCookieKeys[Item_ColoredChat] = "hg_items_colored_chat";
    g_sItemCookieKeys[Item_Knives] = "hg_items_knives";

    g_sItemName[Item_LaserAim] = "Laser Sights (Snipers)";
    g_sItemName[Item_RagDoll] = "Dissolving Ragdolls";
    g_sItemName[Item_MultiNade] = "Multiple HE Grenades";
    g_sItemName[Item_ExplosiveHeadShot] = "Explosive Headshots";
    g_sItemName[Item_DeathBeam] = "Deathbeams";
    g_sItemName[Item_Semtex] = "Semtex Grenades";
    g_sItemName[Item_JoinMessage] = "Custom Join Message";
    g_sItemName[Item_StealthMode] = "Stealth Mode";
    g_sItemName[Item_Tracers] = "Bullet Tracers";
    g_sItemName[Item_KnifeSyphon] = "Advanced Knife Syphon";
    g_sItemName[Item_ColoredName] = "Custom Colored Names";
    g_sItemName[Item_MultipleAttachments] = "Multiple Player Attachments";
    g_sItemName[Item_ColoredChat] = "Team Colored Chat";
    g_sItemName[Item_Knives] = "Knife Selection";

    for (new i = 0; i < _:Items; i++)
    {
        g_hItemCookies[i] = RegClientCookie(g_sItemCookieKeys[i],
                                            g_sItemName[i],
                                            CookieAccess_Protected);
    }

    RegConsoleCmd("sm_items", Command_ItemsMenu);
}

stock Items_OnClientDisconnect(client)
{
    for (new i = 0; i < _:Items; i++)
    {
        if (g_hPlayerSubItems[client][i] != INVALID_HANDLE)
        {
            CloseHandle(g_hPlayerSubItems[client][i]);
            g_hPlayerSubItems[client][i] = INVALID_HANDLE;
        }
    }
}

stock Items_OnClientPutInServer(client)
{
    // Set the status of client owned items to false.
    // Later these will be set to true, if they have the item.

    for (new i = 0; i < _:Items; i++)
    {
        g_bClientHasItem[client][i] = false;
        g_bClientEquippedItem[client][i] = false;
        g_sClientSubValue[client][i][0] = '\0';
    }

    // Items that EVERYONE has
    g_bClientHasItem[client][Item_StealthMode] = true;
}

stock Items_OnDBConnect()
{
    decl String:query[256];

    Format(query, sizeof(query),
           "SELECT name, subtype, filepath FROM items WHERE (type = %d) and (servertype & %d) and (servertype > 0)",
           ITEMTYPE_NONE, g_iServerType);

    SQL_TQuery(g_hDbConn, GetItemValues, query);
}

// ###################### FUNCTIONS ######################


stock Items_GivePlayerSubItem(client, const String:item[], item_index)
{
    if (g_hPlayerSubItems[client][item_index] == INVALID_HANDLE)
        g_hPlayerSubItems[client][item_index] = CreateArray(ByteCountToCells(LEN_NAMES));

    if (FindStringInArray(g_hPlayerSubItems[client][item_index], item) == -1)
        PushArrayString(g_hPlayerSubItems[client][item_index], item);
}

bool:Items_HasSubItem(client, const String:item[], item_index)
{
    if (g_hPlayerSubItems[client][item_index] == INVALID_HANDLE ||
        FindStringInArray(g_hPlayerSubItems[client][item_index], item) == -1)
        return false;

    return true;
}

GetItemIndex(const String:name[])
{
    for (new i = 0; i < _:Items; i++)
    {
        if (StrEqual(name, g_sItemName[i], false))
            return i;
    }

    return -1;
}

stock ItemsMenu(client)
{
    new Handle:menu = CreateMenu(ItemsMenuSelect);
    SetMenuTitle(menu, "HG Items");
    SetMenuExitBackButton(menu, true);

    new bool:found;
    g_bItemInSubType[client] = false;

    for (new i = 0; i < _:Items; i++)
    {
        if (g_bClientHasItem[client][i])
        {
            found = true;

            decl String:restricted[24];
            decl String:newdisplay[128];

            new drawtype = GetRestrictedPrefix(g_sItemName[i], client, restricted, sizeof(restricted));

            if (g_bClientEquippedItem[client][i] &&
                g_hPlayerSubItems[client][i] == INVALID_HANDLE)
            {
                decl String:display[LEN_NAMES + 12];      // Enough for " [Equipped]"
                Format(display, sizeof(display),
                       "%s [Equipped]", g_sItemName[i]);

                Format(newdisplay, sizeof(newdisplay), "%s%s", display, restricted);
                AddMenuItem(menu, g_sItemName[i], newdisplay, drawtype);
            }

            else
            {
                Format(newdisplay, sizeof(newdisplay), "%s%s", g_sItemName[i], restricted);
                AddMenuItem(menu, g_sItemName[i], newdisplay, drawtype);
            }
        }
    }

    // They don't have any items bought; let's tell 'em how to get some.
    if (!found)
    {
        AddMenuItem(menu, "", "You have no items", ITEMDRAW_DISABLED);
        AddMenuItem(menu, "", "Please type !shop", ITEMDRAW_DISABLED);
        AddMenuItem(menu, "", "Or press back", ITEMDRAW_DISABLED);
        AddMenuItem(menu, "", "To purchase items", ITEMDRAW_DISABLED);
    }

    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

// ###################### CALLBACKS ######################


public ItemsMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
            {
                if (g_bItemInSubType[client])
                    ItemsMenu(client);

                else
                    MainMenu(client);
            }
        }

        case MenuAction_Select:
        {
            decl String:key[LEN_NAMES];
            GetMenuItem(menu, selected, key, sizeof(key));

            new index = GetItemIndex(key);

            if (index == -1)
            {
                decl String:parent[LEN_NAMES];
                GetTrieString(g_hItemSubTypes, key, parent, sizeof(parent));

                index = GetItemIndex(parent);

                decl String:active[LEN_NAMES];
                GetClientCookie(client, g_hItemCookies[index], active, sizeof(active));

                decl String:sval[PLATFORM_MAX_PATH];
                GetTrieString(g_hSubTypesItemValues, key, sval, sizeof(sval));

                strcopy(g_sClientSubValue[client][index], PLATFORM_MAX_PATH, sval);

                if (StrEqual(active, key))
                {
                    PrintToChat(client,
                                "%s You have \x01disabled \x03%s", MSG_PREFIX, key);

                    g_bClientEquippedItem[client][index] = false;
                    SetClientCookie(client, g_hItemCookies[index], "0");

                    if (index == _:Item_StealthMode)
                        PrintToChat(client, "%s Your items will be visible next spawn", MSG_PREFIX);
                }

                else
                {
                    if (!IsAuthed(client, key))
                        return;

                    PrintToChat(client,
                                "%s You have \x01enabled \x03%s", MSG_PREFIX, key);

                    if (index == _:Item_Tracers)
                        g_iPlayerTracerColors[client] = _:GetColorIndex(g_sClientSubValue[client][Item_Tracers]);

                    else if (index == _:Item_LaserAim)
                        g_iPlayerLaserColor[client] = _:GetColorIndex(g_sClientSubValue[client][Item_LaserAim]);

                    else if (index == _:Item_StealthMode)
                    {
                        Trails_Kill(client);
                        Hats_KillHat(client);
                    }

                    g_bClientEquippedItem[client][index] = true;
                    SetClientCookie(client, g_hItemCookies[index], key);
                }
            }
    
            if (g_hPlayerSubItems[client][index] != INVALID_HANDLE)
            {
                decl String:parent[LEN_NAMES];
                decl String:title[LEN_NAMES + 32];

                if (GetTrieString(g_hItemSubTypes, key, parent, sizeof(parent)))
                    Format(title, sizeof(title), "Select Value For %s", parent);

                else
                    Format(title, sizeof(title), "Select Value For %s", key);

                g_bItemInSubType[client] = true;

                new Handle:nmenu = CreateMenu(ItemsMenuSelect);
                SetMenuTitle(nmenu, title);
                SetMenuExitBackButton(nmenu, true);

                decl String:active[LEN_NAMES];
                GetClientCookie(client, g_hItemCookies[index], active, sizeof(active));

                for (new i = 0; i < GetArraySize(g_hPlayerSubItems[client][index]); i++)
                {
                    decl String:subitem[LEN_NAMES];
                    GetArrayString(g_hPlayerSubItems[client][index], i, subitem, sizeof(subitem));

                    if (StrEqual(active, subitem))
                    {
                        decl String:display[LEN_NAMES + 12];
                        Format(display, sizeof(display), "%s [Active]", active);

                        AddMenuItem(nmenu, subitem, display);
                    }

                    else
                        AddMenuItem(nmenu, subitem, subitem);
                }

                DisplayMenu(nmenu, client, MENU_TIME_FOREVER);
                return;
            }

            if (g_bClientEquippedItem[client][index])
            {
                PrintToChat(client,
                            "%s You have \x01disabled \x03%s", MSG_PREFIX, key);

                g_bClientEquippedItem[client][index] = false;
                SetClientCookie(client, g_hItemCookies[index], "0");
            }

            else
            {
                if (!IsAuthed(client, key))
                    return;

                PrintToChat(client,
                            "%s You have \x01enabled \x03%s", MSG_PREFIX, key);

                // Fuck hard coding.
                // Eventually, I'd like items.sp have it's own "RegisterItem(const String:name[], const String:cookiename[], Function:toggle_callback)"
                // or something, so it's more dynamic.

                if (index == _:Item_ColoredName)
                    PrintToChat(client,
                                "%s type \x03sm_coloredname\x04 in console for details",
                                MSG_PREFIX);

                g_bClientEquippedItem[client][index] = true;
                SetClientCookie(client, g_hItemCookies[index], "1");
            }

            ItemsMenu(client);
        }
    }
}

public Action:Command_ItemsMenu(client, args)
{
    if (IsAuthed(client) && !DatabaseFailure(client))
        ItemsMenu(client);
    return Plugin_Handled;
}

public GetItemValues(Handle:main, Handle:hndl, const String:error[], any:data)
{
    if (!CheckConnection(hndl, error))
        return;

    decl String:item_name[LEN_NAMES];

    while (SQL_FetchRow(hndl))
    {
        SQL_FetchString(hndl, 0, item_name, sizeof(item_name));
        new index = GetItemIndex(item_name);

        if (index == -1)
        {
            decl String:subtype[LEN_NAMES];
            SQL_FetchString(hndl, 1, subtype, sizeof(subtype));

            decl String:sval[PLATFORM_MAX_PATH];
            SQL_FetchString(hndl, 2, sval, sizeof(sval));

            index = GetItemIndex(subtype);
            SetTrieString(g_hSubTypesItemValues, item_name, sval);

            if (index == -1)
            {
                LogError("HG Items: Item in database, \"%s\", was not found in the script", item_name);
                continue;
            }
        }
    }
}
