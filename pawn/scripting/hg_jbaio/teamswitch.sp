
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Constants.
#define LOCALDEF_TEAMSWITCH_CMDTYPE_MOVET 0
#define LOCALDEF_TEAMSWITCH_CMDTYPE_MOVECT 1
#define LOCALDEF_TEAMSWITCH_CMDTYPE_MOVESPEC 2

// ####################################################################################
// ####################################### EVENTS #####################################
// ####################################################################################

TeamSwitch_OnPluginStart()
{
    RegAdminCmd("movet", Command_TeamSwitch, ADMFLAG_GENERIC, "Switches a player to T");
    RegAdminCmd("movect", Command_TeamSwitch, ADMFLAG_GENERIC, "Switches a player to CT");
    RegAdminCmd("movespec", Command_TeamSwitch, ADMFLAG_GENERIC, "Switches a player to spec");
    RegAdminCmd("teamswitch", Command_NotifyWrongCmd, ADMFLAG_GENERIC, "Lets players know they are using the old cmd");
    RegAdminCmd("teamswap", Command_NotifyWrongCmd, ADMFLAG_GENERIC, "Lets players know they are using the old cmd");
    RegAdminCmd("swapteam", Command_NotifyWrongCmd, ADMFLAG_GENERIC, "Lets players know they are using the old cmd");
    RegAdminCmd("switchteam", Command_NotifyWrongCmd, ADMFLAG_GENERIC, "Lets players know they are using the old cmd");
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_NotifyWrongCmd(client, args)
{
    PrintToChat(client, "%s Use \x03!\x01movet\x04, \x03!\x01movect\x04, \x03!\x01movespec \x04(@me or partial name)", MSG_PREFIX);
    PrintToChat(client, "%s Use \x03!\x01movet\x04, \x03!\x01movect\x04, \x03!\x01movespec \x04(@me or partial name)", MSG_PREFIX);
    PrintToChat(client, "%s Use \x03!\x01movet\x04, \x03!\x01movect\x04, \x03!\x01movespec \x04(@me or partial name)", MSG_PREFIX);
}

public Action:Command_TeamSwitch(admin, args)
{
    // The command itself could be different things (movet, movect, etc).
    decl String:cmd[LEN_CONVARS];
    GetCmdArg(0, cmd, sizeof(cmd));
    new cmdType;
    if (strcmp(cmd, "movet", false) == 0)
        cmdType = LOCALDEF_TEAMSWITCH_CMDTYPE_MOVET;
    else if (strcmp(cmd, "movect", false) == 0)
        cmdType = LOCALDEF_TEAMSWITCH_CMDTYPE_MOVECT;
    else // if (strcmp(cmd, "movespec", false) == 0)
        cmdType = LOCALDEF_TEAMSWITCH_CMDTYPE_MOVESPEC;

    // If no arguments, create menu with all players to let the admin select one.
    if (!args)
    {
        new Handle:menu = CreateMenu(TeamSwitch_MenuSelect);
        SetMenuTitle(menu, "Select Player To Move");
        g_iCmdMenuCategories[admin] = cmdType;
        g_iCmdMenuDurations[admin] = 1;
        Format(g_sCmdMenuReasons[admin], LEN_CONVARS, "");
        decl String:sUserid[LEN_INTSTRING];
        decl String:name[MAX_NAME_LENGTH];
        new cnt;
        for (new i = 1; i <= MaxClients; i++)
        {
            if (!IsClientInGame(i))
                continue;
            new team = GetClientTeam(i);
            if (cmdType == LOCALDEF_TEAMSWITCH_CMDTYPE_MOVET)
            {
                if (team == TEAM_PRISONERS)
                    continue;
            }
            else if (cmdType == LOCALDEF_TEAMSWITCH_CMDTYPE_MOVECT)
            {
                if (team == TEAM_GUARDS)
                    continue;
            }
            else // if (cmdType == LOCALDEF_TEAMSWITCH_CMDTYPE_MOVESPEC)
            {
                if (team == TEAM_SPEC || team == TEAM_UNASSIGNED)
                    continue;
            }
            cnt++;
            GetClientName(i, name, sizeof(name));
            IntToString(GetClientUserId(i), sUserid, sizeof(sUserid));
            AddMenuItem(menu, sUserid, name);
        }
        if (cnt)
            DisplayMenu(menu, admin, MENU_TIMEOUT_NORMAL);
        else
        {
            EmitSoundToClient(admin, g_sSoundDeny);
            ReplyToCommandGood(admin, "%s There is nobody available to move", MSG_PREFIX);
            CloseHandle(menu);
        }
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
        EmitSoundToClient(admin, g_sSoundDeny);
        ReplyToCommandGood(admin, "%s Target could not be identified", MSG_PREFIX);
        return Plugin_Handled;
    }
    switch(iAssumedTargetType)
    {
        case TARGET_TYPE_MAGICWORD:
        {
            if (strcmp(sExtractedTarget, "me", false) == 0)
            {
                TeamSwitch_DoClient(admin, admin, cmdType); // <--- target is admin himself
                return Plugin_Handled;
            }
            else
            {
                EmitSoundToClient(admin, g_sSoundDeny);
                ReplyToCommandGood(admin, "%s Target identifier \x03@%s\x04 is not valid for this command", MSG_PREFIX, sExtractedTarget);
                return Plugin_Handled;
            }
        }
        case TARGET_TYPE_USERID:
        {
            new target = GetClientOfUserId(StringToInt(sExtractedTarget));
            if (!target)
            {
                EmitSoundToClient(admin, g_sSoundDeny);
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            }
            else
                TeamSwitch_DoClient(admin, target, cmdType);
        }
        case TARGET_TYPE_STEAM:
        {
            new target = GetClientOfSteam(sExtractedTarget);
            if (!target)
            {
                EmitSoundToClient(admin, g_sSoundDeny);
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            }
            else
                TeamSwitch_DoClient(admin, target, cmdType);
        }
        case TARGET_TYPE_NAME:
        {
            decl targets[MAXPLAYERS + 1];
            new numFound;
            GetClientOfPartialName(sExtractedTarget, targets, numFound);
            if (numFound <= 0)
            {
                EmitSoundToClient(admin, g_sSoundDeny);
                ReplyToCommandGood(admin, "%s No matches found for \x01[\x03%s\x01]", MSG_PREFIX, sExtractedTarget);
            }
            else if (numFound == 1)
            {
                new target = targets[0];
                if (!IsClientInGame(target))
                {
                    EmitSoundToClient(admin, g_sSoundDeny);
                    ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
                }
                else
                    TeamSwitch_DoClient(admin, target, cmdType);
            }
            else
            {
                // Multiple hits.  Show a menu to the admin.
                if (admin <= 0 || !IsClientInGame(admin))
                    ReplyToCommandGood(admin, "%s Multiple matches found for \x01[\x03%s\x01]", MSG_PREFIX);
                else
                {
                    new Handle:menu = CreateMenu(TeamSwitch_MenuSelect);
                    SetMenuTitle(menu, "Select Player To Move");
                    g_iCmdMenuCategories[admin] = cmdType;
                    g_iCmdMenuDurations[admin] = iExtractedDuration;
                    Format(g_sCmdMenuReasons[admin], LEN_CONVARS, sExtractedReason);
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
            EmitSoundToClient(admin, g_sSoundDeny);
            ReplyToCommandGood(admin, "%s Target type could not be identified", MSG_PREFIX);
        }
    }
    return Plugin_Handled;
}

// ####################################################################################
// ##################################### FUNCTIONS ####################################
// ####################################################################################

TeamSwitch_DoClient(admin, target, cmdType)
{
    new flags = GetUserFlagBits(admin);
    if (!(flags & ADMFLAG_KICK) && !(flags & ADMFLAG_ROOT))
    {
        if (admin != target)
        {
            EmitSoundToClient(admin, g_sSoundDeny);
            PrintToChat(admin, "%s \x03VIP\x04 members may only teamswitch themselves.", MSG_PREFIX);
            return;
        }
    }

    // Ensure target is in-game.
    if ((target <= 0) || (!IsClientInGame(target)))
    {
        EmitSoundToClient(admin, g_sSoundDeny);
        ReplyToCommandGood(admin, "%s ERROR: Target %i not in game", MSG_PREFIX, target);
        return;
    }

    if (GetClientTeam(target) <= 0)
    {
        ReplyToCommandGood(admin,
                           "%s ERROR: Target must have previously joined a team by themselves (spec, prisoner, guard)",
                           MSG_PREFIX, target);

        EmitSoundToClient(admin, g_sSoundDeny);
        return;
    }

    // Get admin info
    decl String:adminName[MAX_NAME_LENGTH];
    if ((admin <= 0) || (!IsClientInGame(admin)))
        Format(adminName, sizeof(adminName), "CONSOLE");
    else
        GetClientName(admin, adminName, sizeof(adminName));

    if (cmdType == LOCALDEF_TEAMSWITCH_CMDTYPE_MOVET)
    {
        new team = GetClientTeam(target);
        if (team == TEAM_PRISONERS)
        {
            EmitSoundToClient(admin, g_sSoundDeny);
            ReplyToCommandGood(admin, "%s Target is already on specified team", MSG_PREFIX);
            return;
        }

        g_bWasAuthedToJoin[target] = true;

        // Move.
        SwitchTeam(target, TEAM_PRISONERS);
        SetEntProp(target, Prop_Send, "m_iTeamNum", TEAM_PRISONERS);
        if (team <= TEAM_SPEC)
            RespawnPlayer(target);
        if (IsPlayerAlive(target))   // Don't use JB_IsPlayerAlive
            CreateTimer(0.1, DelaySlay, target);

        // Display messages.
        PrintToChatAll("%s \x03%N\x04 was moved to Prisoners by \x03%s", MSG_PREFIX, target, adminName);
    }

    else if (cmdType == LOCALDEF_TEAMSWITCH_CMDTYPE_MOVECT)
    {
        new team = GetClientTeam(target);
        if (team == TEAM_GUARDS)
        {
            EmitSoundToClient(admin, g_sSoundDeny);
            ReplyToCommandGood(admin, "%s Target is already on specified team", MSG_PREFIX);
            return;
        }

        // Don't let them be switched to CT if they're Temp-Locked.
        if (!Tlock_AllowedToJoinGuards(target))
        {
            EmitSoundToClient(admin, g_sSoundDeny);
            ReplyToCommandGood(admin, "%s You can not team switch a Temp-Locked player to the Guard team", MSG_PREFIX);
            return;
        }

        // Don't let them be switched to CT if they're T-Listed.
        if (!Tlist_AllowedToJoinGuards(target))
        {
            EmitSoundToClient(admin, g_sSoundDeny);
            ReplyToCommandGood(admin, "%s You can not team switch a T-Listed player to the Guard team", MSG_PREFIX);
            return;
        }

        new admin_add = 2;
        new bits = GetUserFlagBits(admin);

        if (target == admin)
            admin_add += 2;

        if (bits & ADMFLAG_ROOT)
            admin_add += 4;

        else if (bits & ADMFLAG_CHANGEMAP)
            admin_add += 2;

        if (!CTSlotOpen(team == TEAM_PRISONERS, admin_add))
        {
            EmitSoundToClient(admin, g_sSoundDeny);
            ReplyToCommandGood(admin, "%s Good Sir, please check \x05Dat Ratio\x04 before you move someone", MSG_PREFIX);
            return;
        }

        g_bWasAuthedToJoin[target] = true;

        // Move.
        SwitchTeam(target, TEAM_GUARDS);
        SetEntProp(target, Prop_Send, "m_iTeamNum", TEAM_GUARDS);

        if (team <= TEAM_SPEC)
            RespawnPlayer(target);

        if (IsPlayerAlive(target))   // Don't use JB_IsPlayerAlive
            CreateTimer(0.1, DelaySlay, target);

        // Display messages.
        PrintToChatAll("%s \x03%N\x04 was moved to Guards by \x03%s", MSG_PREFIX, target, adminName);
    }

    else // if (cmdType == LOCALDEF_TEAMSWITCH_CMDTYPE_MOVESPEC)
    {
        // Move.
        if (IsPlayerAlive(target))  // Don't use JB_IsPlayerAlive
            ForcePlayerSuicide(target);

        if (GetClientTeam(target) > TEAM_SPEC)
            ChangeClientTeam(target, TEAM_SPEC);

        // Display messages.
        PrintToChatAll("%s \x03%N\x04 was moved to Spec by \x03%s", MSG_PREFIX, target, adminName);
    }
}

// ####################################################################################
// ####################################### MENUS ######################################
// ####################################################################################

public TeamSwitch_MenuSelect(Handle:menu, MenuAction:action, admin, selected)
{
    if (action == MenuAction_Select)
    {
        decl String:sUserid[LEN_INTSTRING];
        GetMenuItem(menu, selected, sUserid, sizeof(sUserid));
        new target = GetClientOfUserId(StringToInt(sUserid));
        if (!target)
        {
            EmitSoundToClient(admin, g_sSoundDeny);
            ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
        }
        else
            TeamSwitch_DoClient(admin,
                                target,
                                g_iCmdMenuCategories[admin]);
    }
    else if (action == MenuAction_End)
        CloseHandle(menu);
}
