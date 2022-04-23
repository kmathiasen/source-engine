
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Constants.
#define LOCALDEF_STRIP_MENUCHOICE_ALL -1111
#define LOCALDEF_STRIP_MENUCHOICE_ALLT -2222
#define LOCALDEF_STRIP_MENUCHOICE_ALLCT -3333
#define LOCALDEF_STRIP_CMDTYPE_STRIP 0
#define LOCALDEF_STRIP_CMDTYPE_STRIPALL 1

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

Strip_OnPluginStart()
{
    RegAdminCmd("strip", Command_Strip, ADMFLAG_CHANGEMAP, "Strips everything except knife from a player.");
    RegAdminCmd("stripall", Command_Strip, ADMFLAG_CHANGEMAP, "Strips everything including knife from a player.");
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_Strip(admin, args)
{
    // The command itself could be different things (strip, stripall, etc).
    decl String:cmd[LEN_CONVARS];
    GetCmdArg(0, cmd, sizeof(cmd));
    new cmdType;
    if (StrEqual(cmd, "stripall"))
        cmdType = LOCALDEF_STRIP_CMDTYPE_STRIPALL;
    else
        cmdType = LOCALDEF_STRIP_CMDTYPE_STRIP;

    // If no arguments, create menu with all players to let the admin select one.
    if (!args)
    {
        new Handle:menu = CreateMenu(Strip_MenuSelect);
        SetMenuTitle(menu, "Select Player To Strip");
        g_iCmdMenuCategories[admin] = cmdType;
        g_iCmdMenuDurations[admin] = -1; // Duration not applicable
        Format(g_sCmdMenuReasons[admin], LEN_CONVARS, ""); // Reason not applicable
        decl String:sUserid[LEN_INTSTRING];
        decl String:name[MAX_NAME_LENGTH];

        // Add team choices.
        IntToString(LOCALDEF_STRIP_MENUCHOICE_ALL, sUserid, sizeof(sUserid));
        AddMenuItem(menu, sUserid, "All");
        IntToString(LOCALDEF_STRIP_MENUCHOICE_ALLT, sUserid, sizeof(sUserid));
        AddMenuItem(menu, sUserid, "All Prisoners");
        IntToString(LOCALDEF_STRIP_MENUCHOICE_ALLCT, sUserid, sizeof(sUserid));
        AddMenuItem(menu, sUserid, "All Guards");

        // Add spacer.
        AddMenuItem(menu, "9999", "~~~~~~~~~~~~~~~~~", ITEMDRAW_DISABLED);

        // Add individual player choices.
        for (new i = 1; i <= MaxClients; i++)
        {
            if (!IsClientInGame(i))
                continue;
            if (!JB_IsPlayerAlive(i))
                continue;
            GetClientName(i, name, sizeof(name));
            IntToString(GetClientUserId(i), sUserid, sizeof(sUserid));
            AddMenuItem(menu, sUserid, name);
        }
        DisplayMenu(menu, admin, MENU_TIMEOUT_NORMAL);
        return Plugin_Handled;
    }

    // Get arguments.
    decl String:argString[LEN_CONVARS * 2];
    GetCmdArgString(argString, sizeof(argString));

    // Analyse arg string.
    decl String:sExtractedTarget[LEN_CONVARS];
    decl String:sExtractedReason[LEN_CONVARS];
    new iExtractedDuration = -1;
    new iAssumedTargetType = -1;
    if (!TryGetArgs(argString, sizeof(argString),
                   sExtractedTarget, sizeof(sExtractedTarget),
                   iAssumedTargetType, iExtractedDuration,
                   sExtractedReason, sizeof(sExtractedReason)))
    {
        ReplyToCommandGood(admin, "%s Target could not be identified", MSG_PREFIX);
        return Plugin_Handled;
    }
    switch(iAssumedTargetType)
    {
        case TARGET_TYPE_MAGICWORD:
        {
            if (strcmp(sExtractedTarget, "me", false) == 0)
            {
                Strip_DoClient(admin, admin, (cmdType == LOCALDEF_STRIP_CMDTYPE_STRIP), (iExtractedDuration != 0)); // <--- target is admin himself
                return Plugin_Handled;
            }
            if (strcmp(sExtractedTarget, "t", false) == 0)
            {
                Strip_DoTeam(admin, TEAM_PRISONERS, (cmdType == LOCALDEF_STRIP_CMDTYPE_STRIP), (iExtractedDuration != 0));
                return Plugin_Handled;
            }
            if (strcmp(sExtractedTarget, "ct", false) == 0)
            {
                Strip_DoTeam(admin, TEAM_GUARDS, (cmdType == LOCALDEF_STRIP_CMDTYPE_STRIP), (iExtractedDuration != 0));
                return Plugin_Handled;
            }
            if (strcmp(sExtractedTarget, "all", false) == 0 || strcmp(sExtractedTarget, "dead", false) == 0)
            {
                Strip_DoTeam(admin, TEAM_PRISONERS, (cmdType == LOCALDEF_STRIP_CMDTYPE_STRIP), (iExtractedDuration != 0));
                Strip_DoTeam(admin, TEAM_GUARDS, (cmdType == LOCALDEF_STRIP_CMDTYPE_STRIP), (iExtractedDuration != 0));
                return Plugin_Handled;
            }
            else
            {
                ReplyToCommandGood(admin, "%s Target identifier \x03@%s\x04 is not valid for this command", MSG_PREFIX, sExtractedTarget);
                return Plugin_Handled;
            }
        }
        case TARGET_TYPE_USERID:
        {
            new target = GetClientOfUserId(StringToInt(sExtractedTarget));
            if (!target)
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            else
                Strip_DoClient(admin, target, (cmdType == LOCALDEF_STRIP_CMDTYPE_STRIP), (iExtractedDuration != 0));
        }
        case TARGET_TYPE_STEAM:
        {
            new target = GetClientOfSteam(sExtractedTarget);
            if (!target)
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            else
                Strip_DoClient(admin, target, (cmdType == LOCALDEF_STRIP_CMDTYPE_STRIP), (iExtractedDuration != 0));
        }
        case TARGET_TYPE_NAME:
        {
            decl targets[MAXPLAYERS + 1];
            new numFound;
            GetClientOfPartialName(sExtractedTarget, targets, numFound);
            if (numFound <= 0)
                ReplyToCommandGood(admin, "%s No matches found for \x01[\x03%s\x01]", MSG_PREFIX, sExtractedTarget);
            else if (numFound == 1)
            {
                new target = targets[0];
                if (!IsClientInGame(target))
                    ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
                else
                    Strip_DoClient(admin, target, (cmdType == LOCALDEF_STRIP_CMDTYPE_STRIP), (iExtractedDuration != 0));
            }
            else
            {
                // Multiple hits.  Show a menu to the admin.
                if (admin <= 0 || !IsClientInGame(admin))
                    ReplyToCommandGood(admin, "%s Multiple matches found for \x01[\x03%s\x01]", MSG_PREFIX);
                else
                {
                    new Handle:menu = CreateMenu(Strip_MenuSelect);
                    SetMenuTitle(menu, "Select Player To Strip");
                    g_iCmdMenuCategories[admin] = cmdType;
                    g_iCmdMenuDurations[admin] = iExtractedDuration;
                    Format(g_sCmdMenuReasons[admin], LEN_CONVARS, sExtractedReason); // Reason not applicable
                    decl String:sUserid[LEN_INTSTRING];
                    decl String:name[MAX_NAME_LENGTH];
                    for (new i = 0; i < numFound; i++)
                    {
                        new t = targets[i];
                        GetClientName(t, name, sizeof(name));
                        IntToString(GetClientUserId(t), sUserid, sizeof(sUserid));
                        AddMenuItem(menu, sUserid, name);
                    }
                    DisplayMenu(menu, admin, MENU_TIMEOUT_NORMAL);
                }
            }
        }
        default:
        {
            ReplyToCommandGood(admin, "%s Target type could not be identified", MSG_PREFIX);
        }
    }
    return Plugin_Handled;
}

// ####################################################################################
// ##################################### FUNCTIONS ####################################
// ####################################################################################

Strip_DoClient(admin, target, bool:giveKnife=true, bool:message=true)
{
    // Ensure target is in-game.
    if ((target <= 0) || (!IsClientInGame(target)))
    {
        ReplyToCommandGood(admin, "%s ERROR: Target %i not in game", MSG_PREFIX, target);
        return;
    }

    // Ensure target is alive.
    if (!JB_IsPlayerAlive(target))
    {
        ReplyToCommandGood(admin, "%s ERROR: %N is already alive", MSG_PREFIX, target);
        return;
    }

    // Ensure target is on a valid team.
    new team = GetClientTeam(target);
    if ((team != TEAM_GUARDS) && (team != TEAM_PRISONERS))
    {
        ReplyToCommandGood(admin, "%s ERROR: %N is not on a team", MSG_PREFIX, target);
        return;
    }

    // Get admin info.
    decl String:adminName[MAX_NAME_LENGTH];
    if ((admin <= 0) || (!IsClientInGame(admin)))
        Format(adminName, sizeof(adminName), "CONSOLE");
    else
        GetClientName(admin, adminName, sizeof(adminName));

    // Strip.
    g_bHasBomb[target] = false;

    new wepid = -1;
    for (new i = 0; i <= 5; i++)
    {
        if ((wepid = GetPlayerWeaponSlot(target, i)) != -1)
        {
            if (g_iGame == GAMETYPE_TF2)
            {
                if (i <= WEPSLOT_SECONDARY)
                {
                    StripWeaponAmmo(target, wepid, i);
                }
            }
            
            else
            {
                RemovePlayerItem(target, wepid);
                AcceptEntityInput(wepid, "kill");
            }
        }
    }
    if (giveKnife && g_iGame != GAMETYPE_TF2)
        GivePlayerItem(target, "weapon_knife");

    // Display messages.
    if (message)
        PrintToChatAll("%s \x03%N\x04 was stripped by \x03%s", MSG_PREFIX, target, adminName);
}

Strip_DoTeam(admin, team, bool:giveKnife=true, bool:message=true)
{
    // Get admin info.
    decl String:adminName[MAX_NAME_LENGTH];
    if ((admin <= 0) || (!IsClientInGame(admin)))
        Format(adminName, sizeof(adminName), "CONSOLE");
    else
        GetClientName(admin, adminName, sizeof(adminName));

    // Strip.
    new wepid = -1;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;
        if (!JB_IsPlayerAlive(i))
            continue;
        if (GetClientTeam(i) != team)
            continue;

        for(new j = 0; j <= WEPSLOT_ITEM; j++)
        {
            
            if ((wepid = GetPlayerWeaponSlot(i, j)) != -1)
            {
                if (g_iGame == GAMETYPE_TF2)
                {
                    if (j <= WEPSLOT_SECONDARY)
                        StripWeaponAmmo(i, wepid, j);
                }

                else
                {
                    RemovePlayerItem(i, wepid);
                    RemoveEdict(wepid);
                    
                    if (j == WEPSLOT_NADE && GetPlayerWeaponSlot(i, j) != -1)
                    {
                        j--;
                    }
                }
            }
        }

        if (giveKnife && g_iGame != GAMETYPE_TF2) GivePlayerItem(i, "weapon_knife");
    }

    // Display messages.
    if (message)
    {
        PrintToChatAll("%s All \x03%s\x04 were stripped by \x03%s",
                       MSG_PREFIX,
                       (team == TEAM_PRISONERS ? "Prisoners" : "Guards"),
                       adminName);
    }
}

stock StripWeaponAmmo(client, wepid, slot)
{
    if (slot == WEPSLOT_PRIMARY)
    {
        SetWeaponAmmo(wepid, client, min(0, g_iMaxPrimaryClip[client]), min(0, g_iMaxPrimaryAmmo[client]));
    }

    else if (slot == WEPSLOT_SECONDARY)
    {
        SetWeaponAmmo(wepid, client, min(0, g_iMaxSecondaryClip[client]), min(0, g_iMaxSecondaryAmmo[client]));
    }
}


// ####################################################################################
// ####################################### MENUS ######################################
// ####################################################################################

public Strip_MenuSelect(Handle:menu, MenuAction:action, admin, selected)
{
    if (action == MenuAction_Select)
    {
        decl String:sUserid[LEN_INTSTRING];
        GetMenuItem(menu, selected, sUserid, sizeof(sUserid));
        new iUserid = StringToInt(sUserid);
        if (iUserid < 0)
        {
            if (iUserid == LOCALDEF_STRIP_MENUCHOICE_ALL)
            {
                Strip_DoTeam(admin, TEAM_PRISONERS, (g_iCmdMenuCategories[admin] == LOCALDEF_STRIP_CMDTYPE_STRIP), (g_iCmdMenuDurations[admin] != 0));
                Strip_DoTeam(admin, TEAM_GUARDS, (g_iCmdMenuCategories[admin] == LOCALDEF_STRIP_CMDTYPE_STRIP), (g_iCmdMenuDurations[admin] != 0));
            }
            else if (iUserid == LOCALDEF_STRIP_MENUCHOICE_ALLT)
                Strip_DoTeam(admin, TEAM_PRISONERS, (g_iCmdMenuCategories[admin] == LOCALDEF_STRIP_CMDTYPE_STRIP), (g_iCmdMenuDurations[admin] != 0));
            else if (iUserid == LOCALDEF_STRIP_MENUCHOICE_ALLCT)
                Strip_DoTeam(admin, TEAM_GUARDS, (g_iCmdMenuCategories[admin] == LOCALDEF_STRIP_CMDTYPE_STRIP), (g_iCmdMenuDurations[admin] != 0));
            else
                ReplyToCommandGood(admin, "%s Invalid selection for strip", MSG_PREFIX);
        }
        else
        {
            new target = GetClientOfUserId(iUserid);
            if (!target)
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            else
                Strip_DoClient(admin, target, (g_iCmdMenuCategories[admin] == LOCALDEF_STRIP_CMDTYPE_STRIP), (g_iCmdMenuDurations[admin] != 0));
        }
    }
    else if (action == MenuAction_End)
        CloseHandle(menu);
}
