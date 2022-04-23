
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

#define LOCALDEF_GAG_CMDTYPE_GAG 0
#define LOCALDEF_GAG_CMDTYPE_UNGAG 1

new Handle:g_hGaggedByAdmin = INVALID_HANDLE;               // Trie to hold how many rounds a Steam ID should stay gagged.
new Handle:g_hGaggedByAdminArray = INVALID_HANDLE;          // Parallel array
new g_iIsGagged[MAXPLAYERS + 1];

// ####################################################################################
// ####################################### EVENTS #####################################
// ####################################################################################

Gag_OnPluginStart()
{
    RegAdminCmd("gag", Command_Gag, ADMFLAG_KICK, "Gag a player, like a bauce.");
    RegAdminCmd("ungag", Command_Gag, ADMFLAG_KICK, "Ungag a player, like a bawce");

    AddCommandOverride("sm_gag", Override_Command, ADMFLAG_ROOT);
    AddCommandOverride("sm_ungag", Override_Command, ADMFLAG_ROOT);
    AddCommandOverride("sm_silence", Override_Command, ADMFLAG_ROOT);

    g_hGaggedByAdmin = CreateTrie();
    g_hGaggedByAdminArray = CreateArray(ByteCountToCells(LEN_STEAMIDS));
}

Gag_OnClientAuthorized(client, const String:steam[])
{
    new dummy;
    if (GetTrieValue(g_hGaggedByAdmin, steam, dummy))
        g_iIsGagged[client] = 1;
    else
        g_iIsGagged[client] = 0;
}

Gag_OnRndStart_General()
{
    // Reduce gags by one round.
    decl String:thisSteam[LEN_STEAMIDS];
    for (new i = 0; i < GetArraySize(g_hGaggedByAdminArray); i++)
    {
        new muted_rounds_left;
        GetArrayString(g_hGaggedByAdminArray, i, thisSteam, sizeof(thisSteam));
        if (!GetTrieValue(g_hGaggedByAdmin, thisSteam, muted_rounds_left) ||
            --muted_rounds_left <= 0)
        {
            RemoveFromTrie(g_hGaggedByAdmin, thisSteam);
            RemoveFromArray(g_hGaggedByAdminArray, i--);
            continue;
        }
        SetTrieValue(g_hGaggedByAdmin, thisSteam, muted_rounds_left);
    }

    // Reset clients.
    for (new i = 1; i <= MaxClients; i++)
        g_iIsGagged[i] = -1;
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_Gag(admin, args)
{
    // The command itself could be different things (gag, ungag, etc).
    decl String:cmd[LEN_CONVARS];
    GetCmdArg(0, cmd, sizeof(cmd));
    new cmdType;
    if ((cmd[0] == 'u' || cmd[0] == 'U') && (cmd[1] == 'n' || cmd[1] == 'N'))
        cmdType = LOCALDEF_GAG_CMDTYPE_UNGAG;
    else
        cmdType = LOCALDEF_GAG_CMDTYPE_GAG;

    // If no arguments, create menu with all players to let the admin select one.
    if (!args)
    {
        new Handle:menu = CreateMenu(Gag_MenuSelect);
        SetMenuTitle(menu, (cmdType == LOCALDEF_GAG_CMDTYPE_GAG ?
                            "Select Player To Gag" :
                            "Select Player To Ungag"));
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
            if (cmdType == LOCALDEF_GAG_CMDTYPE_GAG)
            {
                if (g_iIsGagged[i] == 1)
                    continue;
            }
            else // if (cmdType == LOCALDEF_GAG_CMDTYPE_UNGAG)
            {
                if (g_iIsGagged[i] == 0)
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
            ReplyToCommandGood(admin,
                               "%s There is nobody %s",
                               MSG_PREFIX,
                               (cmdType == LOCALDEF_GAG_CMDTYPE_GAG
                                    ? "Ungagged to Gag"
                                    : "Gagged to Ungag"));
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
        ReplyToCommandGood(admin, "%s Target could not be identified", MSG_PREFIX);
        return Plugin_Handled;
    }
    switch(iAssumedTargetType)
    {
        case TARGET_TYPE_MAGICWORD:
        {
            if (strcmp(sExtractedTarget, "me", false) == 0)
            {
                Gag_DoClient(admin, admin, iExtractedDuration, cmdType); // <--- target is admin himself
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
                Gag_DoClient(admin, target, iExtractedDuration, cmdType);
        }
        case TARGET_TYPE_STEAM:
        {
            new target = GetClientOfSteam(sExtractedTarget);
            if (!target)
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            else
                Gag_DoClient(admin, target, iExtractedDuration, cmdType);
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
                    Gag_DoClient(admin, target, iExtractedDuration, cmdType);
            }
            else
            {
                // Multiple hits.  Show a menu to the admin.
                if (admin <= 0 || !IsClientInGame(admin))
                    ReplyToCommandGood(admin, "%s Multiple matches found for \x01[\x03%s\x01]", MSG_PREFIX);
                else
                {
                    new Handle:menu = CreateMenu(Gag_MenuSelect);
                    SetMenuTitle(menu, (cmdType == LOCALDEF_GAG_CMDTYPE_GAG ?
                                        "Select Player To Gag" :
                                        "Select Player To Ungag"));
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
            ReplyToCommandGood(admin, "%s Target type could not be identified", MSG_PREFIX);
        }
    }
    return Plugin_Handled;
}

// ####################################################################################
// ##################################### FUNCTIONS ####################################
// ####################################################################################

public Native_JB_IsClientGagged(Handle:plugin, args)
{
    new client = GetNativeCell(1);
    return Gag_AllowedToUseChat(client) ? false : true;
}

bool:Gag_AllowedToUseChat(client)
{
    if (g_iIsGagged[client] == 0)
        return true;
    else if (g_iIsGagged[client] == 1)
        return false;
    else
    {
        // The typing client has not yet been looked up.  Look up now.
        decl String:steam[LEN_STEAMIDS];
        GetClientAuthString2(client, steam, sizeof(steam));
        new dummy;
        if (GetTrieValue(g_hGaggedByAdmin, steam, dummy))
        {
            g_iIsGagged[client] = 1;
            return false;
        }
        else
        {
            g_iIsGagged[client] = 0;
            return true;
        }
    }
}

Gag_DoClient(admin, target, duration, cmdType)
{
    // Ensure target is in-game.
    if ((target <= 0) || (!IsClientInGame(target)))
    {
        ReplyToCommandGood(admin, "%s ERROR: Target %i not in game", MSG_PREFIX, target);
        return;
    }

    // Get admin info
    decl String:adminName[MAX_NAME_LENGTH];
    if ((admin <= 0) || (!IsClientInGame(admin)))
        Format(adminName, sizeof(adminName), "CONSOLE");
    else
        GetClientName(admin, adminName, sizeof(adminName));

    // Get target info.
    decl String:targetSteam[LEN_STEAMIDS];
    GetClientAuthString2(target, targetSteam, sizeof(targetSteam));

    if (cmdType == LOCALDEF_GAG_CMDTYPE_GAG)
    {
        // Ensure duration is within limits.
        new max_rounds = GetConVarInt(g_hCvAdminMaxGagRounds);
        new bits = GetUserFlagBits(admin);

        if (bits & ADMFLAG_ROOT)
            max_rounds *= 3;

        else if (bits & ADMFLAG_CHANGEMAP)
            max_rounds *= 2;

        if (duration <= 0) duration = 1;
        if (duration > max_rounds) duration = max_rounds;

        new current_rounds;
        GetTrieValue(g_hGaggedByAdmin, targetSteam, duration);

        if (current_rounds > max_rounds)
        {
            PrintToChat(admin, "%s That player has been gagged by a staff member", MSG_PREFIX);
            PrintToChat(admin, "%s You can not change the duration", MSG_PREFIX);

            return;
        }

        // Set gag status in trie.
        SetTrieValue(g_hGaggedByAdmin, targetSteam, duration);

        // Add them to the parallel array.
        if (FindStringInArray(g_hGaggedByAdminArray, targetSteam) == -1)
            PushArrayString(g_hGaggedByAdminArray, targetSteam);

        // Gag.
        g_iIsGagged[target] = 1;

        // Display messages.
        PrintToChatAll("%s \x03%N\x04 was gagged by \x03%s\x04 for \x03%i\x04 rounds", MSG_PREFIX, target, adminName, duration);
        LogAction(admin, target, "\"%L\" gagged \"%L\" (rounds \"%d\")", admin, target, duration);
    }

    else // if (cmdType == LOCALDEF_GAG_CMDTYPE_UNGAG)
    {
        new current_rounds;
        new max_rounds = GetConVarInt(g_hCvAdminMaxGagRounds);
        new bits = GetUserFlagBits(admin);

        GetTrieValue(g_hGaggedByAdmin, targetSteam, current_rounds);
        if (bits & ADMFLAG_ROOT)
            max_rounds *= 3;

        else if (bits & ADMFLAG_CHANGEMAP)
            max_rounds *= 2;

        if (current_rounds > max_rounds)
        {
            PrintToChat(admin, "%s That player has been gagged by a HG staff member", MSG_PREFIX);
            PrintToChat(admin, "%s You can not ungag them", MSG_PREFIX);

            return;
        }

        // Set gag status in trie.
        RemoveFromTrie(g_hGaggedByAdmin, targetSteam);

        // Remove them from the parallel trie.
        new index = FindStringInArray(g_hGaggedByAdminArray, targetSteam);
        if (index > -1)
            RemoveFromArray(g_hGaggedByAdminArray, index);

        // Ungag.
        g_iIsGagged[target] = 0;

        // Display messages.
        PrintToChatAll("%s \x03%N\x04 was ungagged by \x03%s\x04", MSG_PREFIX, target, adminName);
        LogAction(admin, target, "\"%L\" ungagged \"%L\"", admin, target);
    }
}

// ####################################################################################
// ####################################### MENUS ######################################
// ####################################################################################

public Gag_MenuSelect(Handle:menu, MenuAction:action, admin, selected)
{
    if (action == MenuAction_Select)
    {
        decl String:sUserid[LEN_INTSTRING];
        GetMenuItem(menu, selected, sUserid, sizeof(sUserid));
        new target = GetClientOfUserId(StringToInt(sUserid));
        if (!target)
            ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
        else
            Gag_DoClient(admin,
                         target,
                         g_iCmdMenuDurations[admin],
                         g_iCmdMenuCategories[admin]);
    }
    else if (action == MenuAction_End)
        CloseHandle(menu);
}
