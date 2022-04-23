
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Constants.
#define LOCALDEF_TELE_MENUCHOICE_ALL -1111
#define LOCALDEF_TELE_MENUCHOICE_ALLT -2222
#define LOCALDEF_TELE_MENUCHOICE_ALLCT -3333

// Menu globals.
new Handle:g_hDestinationsMenu = INVALID_HANDLE;
new g_iPreviouslySelectedTarget[MAXPLAYERS + 1];

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

Tele_OnPluginStart()
{
    RegAdminCmd("tele", Command_Tele, ADMFLAG_ROOT, "Teleports people.");
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_Tele(admin, args)
{
    // If no arguments, create menu with all players to let the admin select one.
    if (!args)
    {
        new Handle:menu = CreateMenu(Tele_MenuSelect_Target);
        SetMenuTitle(menu, "Select Player To Teleport");
        g_iCmdMenuCategories[admin] = -1; // Category not applicable
        g_iCmdMenuDurations[admin] = -1; // Duration not applicable
        Format(g_sCmdMenuReasons[admin], LEN_CONVARS, ""); // Reason not applicable
        decl String:sUserid[LEN_INTSTRING];
        decl String:name[MAX_NAME_LENGTH];

        // Add team choices.
        IntToString(LOCALDEF_TELE_MENUCHOICE_ALL, sUserid, sizeof(sUserid));
        AddMenuItem(menu, sUserid, "All");
        IntToString(LOCALDEF_TELE_MENUCHOICE_ALLT, sUserid, sizeof(sUserid));
        AddMenuItem(menu, sUserid, "All Prisoners");
        IntToString(LOCALDEF_TELE_MENUCHOICE_ALLCT, sUserid, sizeof(sUserid));
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
                g_iPreviouslySelectedTarget[admin] = GetClientUserId(admin); // Store for the destination selection menu
                g_iCmdMenuDurations[admin] = iExtractedDuration; // Store for the destination selection menu
                Tele_DoClient(admin, admin, sExtractedReason, (iExtractedDuration != 0)); // <--- target is admin himself
                return Plugin_Handled;
            }
            if (strcmp(sExtractedTarget, "t", false) == 0)
            {
                g_iPreviouslySelectedTarget[admin] = LOCALDEF_TELE_MENUCHOICE_ALLT; // Store for the destination selection menu
                g_iCmdMenuDurations[admin] = iExtractedDuration; // Store for the destination selection menu
                Tele_DoTeam(admin, TEAM_PRISONERS, sExtractedReason, (iExtractedDuration != 0));
                return Plugin_Handled;
            }
            if (strcmp(sExtractedTarget, "ct", false) == 0)
            {
                g_iPreviouslySelectedTarget[admin] = LOCALDEF_TELE_MENUCHOICE_ALLCT; // Store for the destination selection menu
                g_iCmdMenuDurations[admin] = iExtractedDuration; // Store for the destination selection menu
                Tele_DoTeam(admin, TEAM_GUARDS, sExtractedReason, (iExtractedDuration != 0));
                return Plugin_Handled;
            }
            if (strcmp(sExtractedTarget, "all", false) == 0 || strcmp(sExtractedTarget, "dead", false) == 0)
            {
                g_iPreviouslySelectedTarget[admin] = LOCALDEF_TELE_MENUCHOICE_ALL; // Store for the destination selection menu
                g_iCmdMenuDurations[admin] = iExtractedDuration; // Store for the destination selection menu
                Tele_DoTeam(admin, TEAM_PRISONERS, sExtractedReason, (iExtractedDuration != 0));
                Tele_DoTeam(admin, TEAM_GUARDS, sExtractedReason, (iExtractedDuration != 0));
                return Plugin_Handled;
            }
            if (strcmp(sExtractedTarget, "lead", false) == 0)
            {
                if (g_iLeadGuard <= 0)
                {
                    ReplyToCommandGood(admin, "%s There is currently no Lead Guard", MSG_PREFIX);
                    return Plugin_Handled;
                }
                g_iPreviouslySelectedTarget[admin] = GetClientUserId(g_iLeadGuard); // Store for the destination selection menu
                g_iCmdMenuDurations[admin] = iExtractedDuration; // Store for the destination selection menu
                Tele_DoClient(admin, g_iLeadGuard, sExtractedReason, (iExtractedDuration != 0)); // <--- target is admin himself
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
            new targetUserid = StringToInt(sExtractedTarget);
            new target = GetClientOfUserId(targetUserid);
            if (!target)
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            else
            {
                g_iPreviouslySelectedTarget[admin] = targetUserid; // Store for the destination selection menu
                g_iCmdMenuDurations[admin] = iExtractedDuration; // Store for the destination selection menu
                Tele_DoClient(admin, target, sExtractedReason, (iExtractedDuration != 0));
            }
        }
        case TARGET_TYPE_STEAM:
        {
            new target = GetClientOfSteam(sExtractedTarget);
            if (!target)
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            else
            {
                g_iPreviouslySelectedTarget[admin] = GetClientUserId(target); // Store for the destination selection menu
                g_iCmdMenuDurations[admin] = iExtractedDuration; // Store for the destination selection menu
                Tele_DoClient(admin, target, sExtractedReason, (iExtractedDuration != 0));
            }
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
                {
                    g_iPreviouslySelectedTarget[admin] = GetClientUserId(target); // Store for the destination selection menu
                    g_iCmdMenuDurations[admin] = iExtractedDuration; // Store for the destination selection menu
                    Tele_DoClient(admin, target, sExtractedReason, (iExtractedDuration != 0));
                }
            }
            else
            {
                // Multiple hits.  Show a menu to the admin.
                if (admin <= 0 || !IsClientInGame(admin))
                    ReplyToCommandGood(admin, "%s Multiple matches found for \x01[\x03%s\x01]", MSG_PREFIX);
                else
                {
                    new Handle:menu = CreateMenu(Tele_MenuSelect_Target);
                    SetMenuTitle(menu, "Select Player To Teleport");
                    g_iCmdMenuCategories[admin] = -1; // Category not applicable
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

bool:Tele_DoClient(admin, target, const String:destination[], bool:message=true, bool:teledead=false)
{
    // If destination was not supplied, have player choose using menu.
    if (StrEqual(destination, ""))
    {
        if (admin <= 0)
            ReplyToCommandGood(admin, "%s ERROR: You must be able to use a menu to perform this command", MSG_PREFIX);
        else
            DisplayMenu(g_hDestinationsMenu, admin, MENU_TIMEOUT_NORMAL);
        return false;
    }

    // Ensure target is in-game.
    if ((target <= 0) || (!IsClientInGame(target)))
    {
        ReplyToCommandGood(admin, "%s ERROR: Target %i not in game", MSG_PREFIX, target);
        return false;
    }

    // Ensure target is alive.
    if (!JB_IsPlayerAlive(target) && !teledead)
    {
        ReplyToCommandGood(admin, "%s ERROR: %N is not alive", MSG_PREFIX, target);
        return false;
    }

    // Ensure target is on a valid team.
    new team = GetClientTeam(target);
    if ((team != TEAM_GUARDS) && (team != TEAM_PRISONERS))
    {
        ReplyToCommandGood(admin, "%s ERROR: %N is not on a team", MSG_PREFIX, target);
        return false;
    }

    // Get admin info.
    decl String:adminName[MAX_NAME_LENGTH];
    if ((admin <= 0) || (!IsClientInGame(admin)))
        Format(adminName, sizeof(adminName), "CONSOLE");
    else
        GetClientName(admin, adminName, sizeof(adminName));

    // Get teleport coordinates.
    decl Float:teledata[4];
    if (!GetTrieArray(g_hDbCoords, destination, Float:teledata, 4))
    {
        // Could not find coordinates for supplied destination.
        LogMessage("ERROR in Tele_DoClient: No coords found for [%s]", destination);
        return false;
    }
    /*
        teledata[0] = pos_x
        teledata[1] = pos_y
        teledata[2] = pos_z
        teledata[3] = horiz_angle
    */
    decl Float:pos[3];
    decl Float:ang[3];
    pos[0] = teledata[0];
    pos[1] = teledata[1];
    pos[2] = teledata[2] + 5.0; // Adjust hight (Z coord) so its slightly above the floor level.
    ang[0] = 0.0;
    ang[1] = teledata[3];
    ang[2] = 0.0;

    // Teleport.
    TeleportEntity(target, pos, ang, NULL_VECTOR);

    // Display messages.
    if (message)
        PrintToChatAll("%s \x03%N\x04 was teleported by \x03%s", MSG_PREFIX, target, adminName);

    // Success.
    return true;
}

bool:Tele_DoTeam(admin, team, const String:destination[], bool:message=true)
{
    // If destination was not supplied, have player choose using menu.
    if (StrEqual(destination, ""))
    {
        if (admin <= 0)
            ReplyToCommandGood(admin, "%s ERROR: You must be able to use a menu to perform this command", MSG_PREFIX);
        else
            DisplayMenu(g_hDestinationsMenu, admin, MENU_TIMEOUT_NORMAL);
        return false;
    }

    // Get admin info.
    decl String:adminName[MAX_NAME_LENGTH];
    if ((admin <= 0) || (!IsClientInGame(admin)))
        Format(adminName, sizeof(adminName), "CONSOLE");
    else
        GetClientName(admin, adminName, sizeof(adminName));

    // Get teleport coordinates.
    decl Float:teledata[4];
    if (!GetTrieArray(g_hDbCoords, destination, Float:teledata, 4))
    {
        // Could not find coordinates for supplied destination.
        LogMessage("ERROR in Tele_DoTeam: No coords found for [%s]", destination);
        return false;
    }
    /*
        teledata[0] = pos_x
        teledata[1] = pos_y
        teledata[2] = pos_z
        teledata[3] = horiz_angle
    */
    decl Float:pos[3];
    decl Float:ang[3];
    pos[0] = teledata[0];
    pos[1] = teledata[1];
    pos[2] = teledata[2] + 5.0; // Adjust hight (Z coord) so its slightly above the floor level.
    ang[0] = 0.0;
    ang[1] = teledata[3];
    ang[2] = 0.0;

    // Teleport.
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;
        if (!JB_IsPlayerAlive(i))
            continue;
        if (GetClientTeam(i) != team)
            continue;

        TeleportEntity(i, pos, ang, NULL_VECTOR);
    }

    // Display messages.
    if (message)
        PrintToChatAll("%s All \x03%s\x04 were teleported by \x03%s",
                       MSG_PREFIX,
                       (team == TEAM_PRISONERS ? "Prisoners" : "Guards"),
                       adminName);

    // Success.
    return true;
}

Tele_RecreateDestinationsMenu()
{
    if (g_hDestinationsMenu != INVALID_HANDLE)
    {
        RemoveAllMenuItems(g_hDestinationsMenu);
        CloseHandle(g_hDestinationsMenu);
        g_hDestinationsMenu = INVALID_HANDLE;
    }

    g_hDestinationsMenu = CreateMenu(Tele_MenuSelect_Destination);
    SetMenuTitle(g_hDestinationsMenu, "Select Teleport Destination");
  //SetMenuExitBackButton(g_hDestinationsMenu, true);
}

Tele_RegisterDestination(const String:dest[])
{
    AddMenuItem(g_hDestinationsMenu, dest, dest);
}

// ####################################################################################
// ####################################### MENUS ######################################
// ####################################################################################

public Tele_MenuSelect_Target(Handle:menu, MenuAction:action, admin, selected)
{
    if (action == MenuAction_Select)
    {
        // Store for the destination selection menu.
        decl String:sUserid[LEN_INTSTRING];
        GetMenuItem(menu, selected, sUserid, sizeof(sUserid));
        new iUserid = StringToInt(sUserid);
        g_iPreviouslySelectedTarget[admin] = iUserid;

        // Display the destination selection menu.
        DisplayMenu(g_hDestinationsMenu, admin, MENU_TIMEOUT_NORMAL);
    }
    else if (action == MenuAction_End)
        CloseHandle(menu);
}

public Tele_MenuSelect_Destination(Handle:menu, MenuAction:action, admin, selected)
{
    if (action == MenuAction_Select)
    {
        decl String:dest[LEN_MAPCOORDS];
        GetMenuItem(menu, selected, dest, sizeof(dest));

        // Retrieve the stored target.
        new iUserid = g_iPreviouslySelectedTarget[admin];

        if (iUserid < 0)
        {
            if (iUserid == LOCALDEF_TELE_MENUCHOICE_ALL)
            {
                Tele_DoTeam(admin, TEAM_PRISONERS, dest, (g_iCmdMenuDurations[admin] != 0));
                Tele_DoTeam(admin, TEAM_GUARDS, dest, (g_iCmdMenuDurations[admin] != 0));
            }
            else if (iUserid == LOCALDEF_TELE_MENUCHOICE_ALLT)
                Tele_DoTeam(admin, TEAM_PRISONERS, dest, (g_iCmdMenuDurations[admin] != 0));
            else if (iUserid == LOCALDEF_TELE_MENUCHOICE_ALLCT)
                Tele_DoTeam(admin, TEAM_GUARDS, dest, (g_iCmdMenuDurations[admin] != 0));
            else
                ReplyToCommandGood(admin, "%s Invalid selection for teleport", MSG_PREFIX);
        }
        else
        {
            new target = GetClientOfUserId(iUserid);
            if (!target)
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            else
                Tele_DoClient(admin, target, dest, (g_iCmdMenuDurations[admin] != 0));
        }
    }
    else if (action == MenuAction_End)
    {
        //pass
    }
}
