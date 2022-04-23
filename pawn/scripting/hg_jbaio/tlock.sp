
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Constants.
#define LOCALDEF_TLOCK_CMDTYPE_TLOCK 0
#define LOCALDEF_TLOCK_CMDTYPE_UNTLOCK 1

// Stores if the player is temp locked.
new g_iTempLockedRounds[MAXPLAYERS + 1];

// ####################################################################################
// ####################################### EVENTS #####################################
// ####################################################################################

Tlock_OnPluginStart()
{
    RegAdminCmd("lock", Command_Tlock, ADMFLAG_KICK, "Temporarily locks a player on T");
    RegAdminCmd("tlock", Command_Tlock, ADMFLAG_KICK, "Temporarily locks a player on T");
    RegAdminCmd("teamlock", Command_Tlock, ADMFLAG_KICK, "Temporarily locks a player on T");
    RegAdminCmd("templock", Command_Tlock, ADMFLAG_KICK, "Temporarily locks a player on T");
    RegAdminCmd("unlock", Command_Tlock, ADMFLAG_KICK, "Unlock a player from T");
    RegAdminCmd("untlock", Command_Tlock, ADMFLAG_KICK, "Unlock a player from T");
    RegAdminCmd("unteamlock", Command_Tlock, ADMFLAG_KICK, "Unlock a player from T");
    RegAdminCmd("untemplock", Command_Tlock, ADMFLAG_KICK, "Unlock a player from T");
}

Tlock_OnRndStart_General()
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (g_iTempLockedRounds[i] > 0)
            g_iTempLockedRounds[i]--;
    }
}

Tlock_OnClientPutInServer(client)
{
    g_iTempLockedRounds[client] = 0;
}

bool:Tlock_AllowedToJoinGuards(client)
{
    if (g_iTempLockedRounds[client])
        return false;
    return true;
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_Tlock(admin, args)
{
    // The command itself could be different things (tlock, untlock, etc).
    decl String:cmd[LEN_CONVARS];
    GetCmdArg(0, cmd, sizeof(cmd));
    new cmdType;
    if ((cmd[0] == 'u' || cmd[0] == 'U') && (cmd[1] == 'n' || cmd[1] == 'N'))
        cmdType = LOCALDEF_TLOCK_CMDTYPE_UNTLOCK;
    else
        cmdType = LOCALDEF_TLOCK_CMDTYPE_TLOCK;

    // If no arguments, create menu with all players to let the admin select one.
    if (!args)
    {
        new Handle:menu = CreateMenu(Tlock_MenuSelect);
        SetMenuTitle(menu, (cmdType == LOCALDEF_TLOCK_CMDTYPE_TLOCK ?
                            "Select Player To Temp-Lock" :
                            "Select Player To Un-Temp-Lock"));
        g_iCmdMenuCategories[admin] = cmdType;
        g_iCmdMenuDurations[admin] = 1;
        Format(g_sCmdMenuReasons[admin], LEN_CONVARS, "");
        decl String:sUserid[LEN_INTSTRING];
        decl String:name[MAX_NAME_LENGTH];
        new cnt;
        for (new i = 1; i <= MaxClients; i++)
        {
            if (!IsClientInGame(i) || IsFakeClient(i))
                continue;
            if (cmdType == LOCALDEF_TLOCK_CMDTYPE_TLOCK)
            {
                if (g_iTempLockedRounds[i])
                    continue;
            }
            else // if (cmdType == LOCALDEF_TLOCK_CMDTYPE_UNTLOCK)
            {
                if (!g_iTempLockedRounds[i])
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
            ReplyToCommandGood(admin,
                               "%s There is nobody %s",
                               MSG_PREFIX,
                               (cmdType == LOCALDEF_TLOCK_CMDTYPE_TLOCK
                                    ? "Un-Temp-Locked to Temp-Lock"
                                    : "Temp-Locked to Un-Temp-Lock"));
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
                Tlock_DoClient(admin, admin, iExtractedDuration, cmdType); // <--- target is admin himself
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
                Tlock_DoClient(admin, target, iExtractedDuration, cmdType);
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
                Tlock_DoClient(admin, target, iExtractedDuration, cmdType);
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
                    Tlock_DoClient(admin, target, iExtractedDuration, cmdType);
            }
            else
            {
                // Multiple hits.  Show a menu to the admin.
                if (admin <= 0 || !IsClientInGame(admin))
                    ReplyToCommandGood(admin, "%s Multiple matches found for \x01[\x03%s\x01]", MSG_PREFIX);
                else
                {
                    new Handle:menu = CreateMenu(Tlock_MenuSelect);
                    SetMenuTitle(menu, (cmdType == LOCALDEF_TLOCK_CMDTYPE_TLOCK ?
                                        "Select Player To Temp-Lock" :
                                        "Select Player To Un-Temp-Lock"));
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

Tlock_DoClient(admin, target, duration, cmdType)
{
    // Ensure target is in-game.
    if ((target <= 0) || (!IsClientInGame(target)))
    {
        EmitSoundToClient(admin, g_sSoundDeny);
        ReplyToCommandGood(admin, "%s ERROR: Target %i not in game", MSG_PREFIX, target);
        return;
    }

    // Is subject a bot?
    if (IsFakeClient(target))
    {
        KickClient(target);
        ReplyToCommandGood(admin, "%s Bot kicked", MSG_PREFIX);
        return;
    }

    // Get admin info.
    decl String:adminName[MAX_NAME_LENGTH];
    if ((admin <= 0) || (!IsClientInGame(admin)))
        Format(adminName, sizeof(adminName), "CONSOLE");
    else
        GetClientName(admin, adminName, sizeof(adminName));

    // Get target info.
    decl String:target_name[MAX_NAME_LENGTH];
    GetClientName(target, target_name, sizeof(target_name));

    if (cmdType == LOCALDEF_TLOCK_CMDTYPE_TLOCK)
    {
        // Templock is supposed to be a temporary thing.
        new max_rounds = GetConVarInt(g_hCvAdminMaxTLockRounds);
        if (duration <= 0) duration = 1;
        if (duration > max_rounds) duration = max_rounds;

        // Team switch and slay them if they're on CT
        TeamSwitchSlay(target, TEAM_PRISONERS);

        // Set how many rounds they should be temp locked for, -1 = until they leave.
        g_iTempLockedRounds[target] = duration;

        // Display notice to players.
        decl String:sDisplay[LEN_CONVARS];
        Format(sDisplay, sizeof(sDisplay), "%s \x03%s\x04 was Temp-Locked by \x03%s", MSG_PREFIX, target_name, adminName);
        if (duration > 0)
        {
            decl String:tocat[LEN_CONVARS];
            Format(tocat, sizeof(tocat), " \x04for \x03%d\x04 rounds", duration);
            StrCat(sDisplay, sizeof(sDisplay), tocat);
        }

        PrintToChatAll(sDisplay);
        LogAction(admin, target, "\"%L\" Temp-Locked \"%L\" (rounds \"%d\")", admin, target, duration);
    }

    else // if (cmdType == LOCALDEF_TLOCK_CMDTYPE_UNTLOCK)
    {
        g_iTempLockedRounds[target] = 0;
        PrintToChatAll("%s \x03%s\x04 was Un-Temp-Locked by \x03%s", MSG_PREFIX, target_name, adminName);
        LogAction(admin, target, "\"%L\" Un-Temp-Locked \"%L\"", admin, target);
    }
}

// ####################################################################################
// ####################################### MENUS ######################################
// ####################################################################################

public Tlock_MenuSelect(Handle:menu, MenuAction:action, admin, selected)
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
            Tlock_DoClient(admin,
                         target,
                         g_iCmdMenuDurations[admin],
                         g_iCmdMenuCategories[admin]);
    }
    else if (action == MenuAction_End)
        CloseHandle(menu);
}

// ####################################################################################
// ##################################### CALLBACKS ####################################
// ####################################################################################

public Action:Tlock_ShowBlockReason(Handle:timer, any:client)
{
    if (IsClientInGame(client))
    {
        PrintToChat(client, "%s You are currently Temp-Locked.", MSG_PREFIX);
        PrintToChat(client, "%s This means you cannot be a Guard.", MSG_PREFIX);
        PrintToChat(client, "%s Please do not break MOTD rules.", MSG_PREFIX);
    }
    return Plugin_Continue;
}