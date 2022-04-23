
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Constants.
#define LOCALDEF_RESPAWN_MENUCHOICE_ALL -1111
#define LOCALDEF_RESPAWN_MENUCHOICE_ALLT -2222
#define LOCALDEF_RESPAWN_MENUCHOICE_ALLCT -3333

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

Respawn_OnPluginStart()
{
    RegAdminCmd("respawn", Command_Respawn, ADMFLAG_ROOT, "Respawn a player, like a bauce.");
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_Respawn(admin, args)
{
    // If no arguments, create menu with all players to let the admin select one.
    if (!args)
    {
        new Handle:menu = CreateMenu(Respawn_MenuSelect);
        SetMenuTitle(menu, "Select Player To Respawn");
        g_iCmdMenuCategories[admin] = -1; // Category not applicable
        g_iCmdMenuDurations[admin] = -1; // Duration not applicable
        Format(g_sCmdMenuReasons[admin], LEN_CONVARS, ""); // Reason not applicable
        decl String:sUserid[LEN_INTSTRING];
        decl String:name[MAX_NAME_LENGTH];

        // Add team choices.
        IntToString(LOCALDEF_RESPAWN_MENUCHOICE_ALL, sUserid, sizeof(sUserid));
        AddMenuItem(menu, sUserid, "All dead");
        IntToString(LOCALDEF_RESPAWN_MENUCHOICE_ALLT, sUserid, sizeof(sUserid));
        AddMenuItem(menu, sUserid, "All dead Prisoners");
        IntToString(LOCALDEF_RESPAWN_MENUCHOICE_ALLCT, sUserid, sizeof(sUserid));
        AddMenuItem(menu, sUserid, "All dead Guards");

        // Add spacer.
        AddMenuItem(menu, "9999", "~~~~~~~~~~~~~~~~~", ITEMDRAW_DISABLED);

        // Add individual player choices.
        for (new i = 1; i <= MaxClients; i++)
        {
            if (!IsClientInGame(i))
                continue;
            if (JB_IsPlayerAlive(i))
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
                Respawn_DoClient(admin, admin, (iExtractedDuration != 0), (g_iEndGame == ENDGAME_WARDAY || (g_iEndGame == ENDGAME_NONE && GetClientTeam(admin) == TEAM_GUARDS))); // <--- target is admin himself
                return Plugin_Handled;
            }
            if (strcmp(sExtractedTarget, "t", false) == 0)
            {
                Respawn_DoTeam(admin, TEAM_PRISONERS, (iExtractedDuration != 0), (g_iEndGame == ENDGAME_WARDAY));
                return Plugin_Handled;
            }
            if (strcmp(sExtractedTarget, "ct", false) == 0)
            {
                Respawn_DoTeam(admin, TEAM_GUARDS, (iExtractedDuration != 0), (g_iEndGame == ENDGAME_WARDAY || g_iEndGame == ENDGAME_NONE));
                return Plugin_Handled;
            }
            if (strcmp(sExtractedTarget, "all", false) == 0 || strcmp(sExtractedTarget, "dead", false) == 0)
            {
                Respawn_DoTeam(admin, TEAM_PRISONERS, (iExtractedDuration != 0), (g_iEndGame == ENDGAME_WARDAY));
                Respawn_DoTeam(admin, TEAM_GUARDS, (iExtractedDuration != 0), (g_iEndGame == ENDGAME_WARDAY || g_iEndGame == ENDGAME_NONE));
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
                Respawn_DoClient(admin, target, (iExtractedDuration != 0), (g_iEndGame == ENDGAME_WARDAY || (g_iEndGame == ENDGAME_NONE && GetClientTeam(target) == TEAM_GUARDS)));
        }
        case TARGET_TYPE_STEAM:
        {
            new target = GetClientOfSteam(sExtractedTarget);
            if (!target)
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            else
                Respawn_DoClient(admin, target, (iExtractedDuration != 0), (g_iEndGame == ENDGAME_WARDAY || (g_iEndGame == ENDGAME_NONE && GetClientTeam(target) == TEAM_GUARDS)));
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
                    Respawn_DoClient(admin, target, (iExtractedDuration != 0), (g_iEndGame == ENDGAME_WARDAY || (g_iEndGame == ENDGAME_NONE && GetClientTeam(target) == TEAM_GUARDS)));
            }
            else
            {
                // Multiple hits.  Show a menu to the admin.
                if (admin <= 0 || !IsClientInGame(admin))
                    ReplyToCommandGood(admin, "%s Multiple matches found for \x01[\x03%s\x01]", MSG_PREFIX);
                else
                {
                    new Handle:menu = CreateMenu(Respawn_MenuSelect);
                    SetMenuTitle(menu, "Select Player To Respawn");
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

Respawn_DoClient(admin, target, bool:message=true, bool:weapons=false)
{
    // Ensure target is in-game.
    if ((target <= 0) || (!IsClientInGame(target)))
    {
        ReplyToCommandGood(admin, "%s ERROR: Target %i not in game", MSG_PREFIX, target);
        return;
    }

    // Ensure target is dead.
    if (JB_IsPlayerAlive(target))
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

    // Get respawn location and direction.
    new spawnOn = FindPlayerClump(team); // It used to always teleport to solitary -->  Tele_DoClient(0, target, "Solitary", false);
    if (spawnOn <= 0 || !IsClientInGame(spawnOn) || !JB_IsPlayerAlive(spawnOn))
    {
        ReplyToCommandGood(admin, "%s ERROR: no client [%i] for %N to spawn on", MSG_PREFIX, spawnOn, target);
        return;
    }
    decl Float:pos[LEN_VEC];
    decl Float:ang[LEN_VEC];
    GetClientAbsOrigin(spawnOn, pos);
    GetClientAbsAngles(spawnOn, ang);

    // Respawn.
    RespawnPlayer(target);
    TeleportEntity(target, pos, ang, NULL_VECTOR);

    // Equip weapons.
    if (weapons)
    {
        GivePlayerItem(target, "weapon_m4a1");
        GivePlayerItem(target, "weapon_deagle");
    }

    // Display messages.
    if (message)
        PrintToChatAll("%s \x03%N\x04 was respawned by \x03%s", MSG_PREFIX, target, adminName);
}

Respawn_DoTeam(admin, team, bool:message=true, bool:weapons=false)
{
    // Get admin info.
    decl String:adminName[MAX_NAME_LENGTH];
    if ((admin <= 0) || (!IsClientInGame(admin)))
        Format(adminName, sizeof(adminName), "CONSOLE");
    else
        GetClientName(admin, adminName, sizeof(adminName));

    // Get respawn location and direction.
    new spawnOn = FindPlayerClump(team);
    if (spawnOn <= 0 || !IsClientInGame(spawnOn) || !JB_IsPlayerAlive(spawnOn))
    {
        ReplyToCommandGood(admin,
                           "%s ERROR: no client [%i] for %s to spawn on",
                           MSG_PREFIX,
                           spawnOn,
                           team == TEAM_GUARDS ? "GUARDS" : "PRISONERS");
        return;
    }
    decl Float:pos[LEN_VEC];
    decl Float:ang[LEN_VEC];
    GetClientAbsOrigin(spawnOn, pos);
    GetClientAbsAngles(spawnOn, ang);

    // Respawn.
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;
        if (JB_IsPlayerAlive(i))
            continue;
        if (GetClientTeam(i) != team)
            continue;
        RespawnPlayer(i);
        TeleportEntity(i, pos, ang, NULL_VECTOR);

        if (weapons)
        {
            GivePlayerItem(i, "weapon_m4a1");
            GivePlayerItem(i, "weapon_deagle");
        }
    }

    // Display messages.
    if (message)
        PrintToChatAll("%s All dead \x03%s\x04 were respawned by \x03%s",
                       MSG_PREFIX,
                       (team == TEAM_PRISONERS ? "Prisoners" : "Guards"),
                       adminName);
}

// ####################################################################################
// ####################################### MENUS ######################################
// ####################################################################################

public Respawn_MenuSelect(Handle:menu, MenuAction:action, admin, selected)
{
    if (action == MenuAction_Select)
    {
        decl String:sUserid[LEN_INTSTRING];
        GetMenuItem(menu, selected, sUserid, sizeof(sUserid));
        new iUserid = StringToInt(sUserid);
        if (iUserid < 0)
        {
            if (iUserid == LOCALDEF_RESPAWN_MENUCHOICE_ALL)
            {
                Respawn_DoTeam(admin, TEAM_PRISONERS, (g_iCmdMenuDurations[admin] != 0), (g_iEndGame == ENDGAME_WARDAY));
                Respawn_DoTeam(admin, TEAM_GUARDS, (g_iCmdMenuDurations[admin] != 0), (g_iEndGame == ENDGAME_WARDAY || g_iEndGame == ENDGAME_NONE));
            }
            else if (iUserid == LOCALDEF_RESPAWN_MENUCHOICE_ALLT)
                Respawn_DoTeam(admin, TEAM_PRISONERS, (g_iCmdMenuDurations[admin] != 0), (g_iEndGame == ENDGAME_WARDAY));
            else if (iUserid == LOCALDEF_RESPAWN_MENUCHOICE_ALLCT)
                Respawn_DoTeam(admin, TEAM_GUARDS, (g_iCmdMenuDurations[admin] != 0), (g_iEndGame == ENDGAME_WARDAY || g_iEndGame == ENDGAME_NONE));
            else
                ReplyToCommandGood(admin, "%s Invalid selection for respawn", MSG_PREFIX);
        }
        else
        {
            new target = GetClientOfUserId(iUserid);
            if (!target)
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            else
                Respawn_DoClient(admin, target, (g_iCmdMenuDurations[admin] != 0), (g_iEndGame == ENDGAME_WARDAY || (g_iEndGame == ENDGAME_NONE && GetClientTeam(target) == TEAM_GUARDS)));
        }
    }
    else if (action == MenuAction_End)
        CloseHandle(menu);
}
