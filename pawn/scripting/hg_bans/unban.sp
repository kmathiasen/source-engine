
// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

Unban_OnPluginStart()
{
    RegAdminCmd("sm_unban", Unban_Cmd, ADMFLAG_UNBAN,
                "Unbans a user -- sm_unban <steam>");
    RegAdminCmd("sm_untlist", Unban_Cmd, ADMFLAG_KICK,
                "Un-T-Lists a user -- sm_tlist [partialname/\"partial name with spaces\"/userid/steam/@magicword] [duration] [reason]");
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Unban_Cmd(adminClient, args)
{
    // The command itself could be different things (sm_unban, sm_untlist, etc).
    decl String:cmd[LEN_CONVARS];
    GetCmdArg(0, cmd, sizeof(cmd));
    new category;
    if(strcmp(cmd, "sm_unban", false) == 0)
        category = BAN_CAT_REGULARBAN;
    else
        category = BAN_CAT_TLIST;

    // Is T-Listing enabled on this server?
    if(category == BAN_CAT_TLIST && !g_bTlistEnabled)
    {
        ReplyToCommandGood(adminClient, "%s T-Listing is not enabled on this server", MSG_PREFIX);
        return Plugin_Handled;
    }

    // Find target Steam ID.
    // Unbanning only accepts Steam IDs, but Un-T-Listing accepts all usual targeting types.
    switch(category)
    {
        case BAN_CAT_REGULARBAN:
        {
            // Check for valid command usage.
            if(!args)
            {
                ReplyToCommandGood(adminClient, "%s Invalid syntax -- \x01sm_unban \x03<steam>", MSG_PREFIX);
                return Plugin_Handled;
            }

            // Grab Steam ID from arg string.
            decl String:argString[LEN_STEAMIDS + 2]; // Account for quotes
            GetCmdArgString(argString, sizeof(argString));
            StripQuotes(argString);
            ReplaceString(argString, sizeof(argString), " ", "");

            // Perform a RegEx evaluation to be sure if it's a valid Steam ID.
            if(MatchRegex(g_hPatternSteam, argString) > 0)
            {
                // The Steam ID is valid, but ensure it's uppercase.
                for(new i = 0; i <= 6; i++)
                    argString[i] = CharToUpper(argString[i]);
            }
            else
            {
                ReplyToCommandGood(adminClient, "%s You may only unban by Steam ID", MSG_PREFIX);
                return Plugin_Handled;
            }

            // It is a valid Steam ID.  Redim it so the function signature matches.
            decl String:targetSteam[LEN_STEAMIDS];
            Format(targetSteam, sizeof(targetSteam), argString);

            // Try unbanning it.
            PrepUnban_BySteam(targetSteam, category, adminClient);
        }
        case BAN_CAT_TLIST:
        {
            // If no arguments, create menu with all players to let the admin select one.
            if(!args)
            {
                new Handle:menu = CreateMenu(UnbanPlayerSelect);
                SetMenuTitle(menu, "Select Player To Un-T-List");
                g_iBanCategories[adminClient] = category;
                decl String:sUserid[LEN_INTSTRING];
                decl String:name[MAX_NAME_LENGTH];
                for(new i = 1; i <= MaxClients; i++)
                {
                    if(!IsClientInGame(i) || IsFakeClient(i))
                        continue;
                    GetClientName(i, name, sizeof(name));
                    IntToString(GetClientUserId(i), sUserid, sizeof(sUserid));
                    AddMenuItem(menu, sUserid, name);
                }
                DisplayMenu(menu, adminClient, 60);
                return Plugin_Handled;
            }

            // Get arguments.
            decl String:argString[LEN_CONVARS * 2];
            GetCmdArgString(argString, sizeof(argString));

            // Analyse arg string.
            decl String:target[LEN_CONVARS];
            decl String:reason[LEN_CONVARS];
            new targetType = -1;
            new duration = -1;
            if(!TryGetArgs(argString, sizeof(argString), target, sizeof(target), targetType, duration, reason, sizeof(reason)))
            {
                ReplyToCommandGood(adminClient, "%s Target could not be identified", MSG_PREFIX);
                return Plugin_Handled;
            }
            switch(targetType)
            {
                case TARGET_TYPE_MAGICWORD:
                {
                    ReplyToCommandGood(adminClient, "%s There are no magic words supported for this command", MSG_PREFIX);
                  //ReplyToCommandGood(adminClient, "%s DEBUG: target [%s]", MSG_PREFIX, target);
                  //ReplyToCommandGood(adminClient, "%s DEBUG: duration [%i]", MSG_PREFIX, duration);
                  //ReplyToCommandGood(adminClient, "%s DEBUG: reason [%s]", MSG_PREFIX, reason);
                }
                case TARGET_TYPE_USERID:
                {
                    new targetClient = GetClientOfUserId(StringToInt(target));
                    if(!targetClient)
                        ReplyToCommandGood(adminClient, "%s Target has left the server", MSG_PREFIX);
                    else
                        PrepUnban_ByClient(targetClient, category, adminClient);
                }
                case TARGET_TYPE_STEAM:
                {
                    decl String:targetSteam[LEN_STEAMIDS];
                    Format(targetSteam, sizeof(targetSteam), target);
                    PrepUnban_BySteam(targetSteam, category, adminClient);
                }
                case TARGET_TYPE_NAME:
                {
                    // Try to match this name against someone in the server.
                    decl targets[MAXPLAYERS + 1];
                    new numFound;
                    GetClientOfPartialName(target, targets, numFound);
                    if(numFound <= 0)
                        ReplyToCommandGood(adminClient, "%s No matches found for \x01[\x03%s\x01]", MSG_PREFIX, target);
                    else if(numFound == 1)
                    {
                        new targetClient = targets[0];
                        if(!IsClientInGame(targetClient))
                            ReplyToCommandGood(adminClient, "%s Target has left the server", MSG_PREFIX);
                        else
                            PrepUnban_ByClient(targetClient, category, adminClient);
                    }
                    else
                    {
                        // Multiple hits.  Show a menu to the admin.
                        if(adminClient <= 0 || !IsClientInGame(adminClient))
                            ReplyToCommandGood(adminClient, "%s Multiple matches found for \x01[\x03%s\x01]", MSG_PREFIX);
                        else
                        {
                            new Handle:menu = CreateMenu(BanPlayerSelect);
                            SetMenuTitle(menu, "Select Player To Un-T-List");
                            g_iBanCategories[adminClient] = category;
                            for(new i = 0; i < numFound; i++)
                            {
                                new t = targets[i];
                                decl String:sUserid[LEN_INTSTRING];
                                decl String:name[MAX_NAME_LENGTH];
                                GetClientName(t, name, sizeof(name));
                                IntToString(GetClientUserId(t), sUserid, sizeof(sUserid));
                                AddMenuItem(menu, sUserid, name);
                            }
                            DisplayMenu(menu, adminClient, 60);
                        }
                    }
                }
                default:
                {
                    ReplyToCommandGood(adminClient, "%s Target type could not be identified", MSG_PREFIX);
                }
            }
        }
    }
    return Plugin_Handled;
}

// ####################################################################################
// ################################# MAIN FUNCTIONS ###################################
// ####################################################################################

stock PrepUnban_ByClient(targetClient, category, adminClient)
{
    // Check valid target.
    if(!IsClientInGame(targetClient) || IsFakeClient(targetClient))
        return;

    // Get target info.
    decl String:targetSteam[LEN_STEAMIDS];
    GetClientAuthString(targetClient, targetSteam, sizeof(targetSteam));

    // Do unban.
    DoUnban(targetSteam, category, adminClient);
}

stock PrepUnban_BySteam(const String:targetSteam[LEN_STEAMIDS], category, adminClient)
{
    DoUnban(targetSteam, category, adminClient);
}

stock DoUnban(const String:targetSteam[LEN_STEAMIDS], category, adminClient)
{
    // Are we disconnected?
    if(g_hDbConn_Main == INVALID_HANDLE)
    {
        LogMessage("ERROR in Unban_Cmd: The DB handle was invalid");
        ReplyToCommandGood(adminClient, "%s ERROR: Lost connection to database. Could not unban", MSG_PREFIX);
        return;
    }

    // Pack info to pass into callback.
    new Handle:data = CreateDataPack();
    WritePackCell(data, adminClient ? GetClientUserId(adminClient) : 0);
    WritePackCell(data, category);
    WritePackString(data, targetSteam);


    // Remove STEAM_0: prefix from subject's Steam ID.
    decl String:targetSteam_short[LEN_STEAMIDS - 8];
    CopyStringFrom(targetSteam_short, sizeof(targetSteam_short), targetSteam, sizeof(targetSteam), 8);

    // Select.
    decl String:query[512];
    Format(query, sizeof(query),
            "SELECT \
                HEX(uuid), \
                approved_state AS uuid \
            FROM bans \
            WHERE subject_steamid = '%s' \
            AND category = %i \
            AND (approved_state = %d OR approved_state = %d) \
            AND (((datetime_added + duration_seconds) > UNIX_TIMESTAMP()) OR duration_seconds = 0) \
            LIMIT 20",
            targetSteam_short,
            category,
            APPROVED_STATE_APPROVED,
            APPROVED_STATE_SERVERBAN);
    SQL_TQuery(g_hDbConn_Main, Unban_CheckCanUnban_CB, query, any:data);
}

// ####################################################################################
// ####################################### MENUS ######################################
// ####################################################################################

public UnbanPlayerSelect(Handle:menu, MenuAction:action, adminClient, selected)
{
    if(action == MenuAction_Select)
    {
        decl String:sUserid[LEN_INTSTRING];
        GetMenuItem(menu, selected, sUserid, sizeof(sUserid));
        new targetClient = GetClientOfUserId(StringToInt(sUserid));
        if(!targetClient)
            PrintToChat(adminClient, "%s Target has left the server", MSG_PREFIX);
        else
            PrepUnban_ByClient(targetClient,
                               g_iBanCategories[adminClient],
                               adminClient);
    }
    else if(action == MenuAction_End)
        CloseHandle(menu);
}

// ####################################################################################
// #################################### CALLBACKS #####################################
// ####################################################################################

public Unban_CheckCanUnban_CB(Handle:conn, Handle:fetch, const String:error[], any:data)
{
    // Extract passed data.
    ResetPack(Handle:data);
    new adminClient = GetClientOfUserId(ReadPackCell(Handle:data));
    new category = ReadPackCell(Handle:data);
    decl String:targetSteam[LEN_STEAMIDS];
    ReadPackString(Handle:data, targetSteam, sizeof(targetSteam));
    CloseHandle(Handle:data);

    // Did it fail?
    if(Db_QueryFailed(conn, fetch, error))
    {
        LogMessage("ERROR in Unban_CheckCanUnban_CB: %s", error);
        ReplyToCommandGood(adminClient, "%s ERROR: Lost connection to database. Could not query bans", MSG_PREFIX);
        return;
    }
    if(!SQL_FetchRow(fetch))
    {
        ReplyToCommandGood(adminClient, "%s No active records found for \x03%s", MSG_PREFIX, targetSteam);
        return;
    }

    // Store the unique IDs of all the bans we're going to remove.
    decl String:uuids[20][LEN_HEXUUID];

    // And the old approved states.
    decl old_approved_states[20];

    new total;
    new staff;
    do
    {
        // Fetch the unique ID.
        SQL_FetchString(fetch, 0, uuids[total], LEN_HEXUUID);

        // And the old approved state.
        old_approved_states[total] = SQL_FetchInt(fetch, 1);

        // If the ban was already approved, then it cannot be undone from in game by a regular admin.
        if(old_approved_states[total] == APPROVED_STATE_APPROVED)
            staff++;

        total++;
    } while(SQL_FetchRow(fetch));

    // One or more of the bans were already approved, so regular admins can't unban him.
    if(adminClient && staff)
    {
        new admin_flags = GetUserFlagBits(adminClient);
        if(!(admin_flags & ADMFLAG_CHANGEMAP) && !(admin_flags & ADMFLAG_ROOT))
        {
            // We already know it's an in game admin.
            PrintToChat(adminClient,
                        "%s \x01%d/%d\x04 of the ban(s) on \x03%s\x04 were already approved by staff.",
                        MSG_PREFIX, staff, total, targetSteam);
            PrintToChat(adminClient,
                        "%s You can not unban this person from in game; please post on the bans topic",
                        MSG_PREFIX);
            return;
        }
    }

    ReplyToCommandGood(adminClient,
                       "%s There were \x03%d\x04 active records on \x03%s",
                       MSG_PREFIX, total, targetSteam);
    // Notify players of unban or Un-T-List.
    PrintToChatAll("%s \x03%N \x04%s \x03%s",
                   MSG_PREFIX, adminClient,
                   (category == BAN_CAT_REGULARBAN ? "unbanned" : "Un-T-Listed"),
                   targetSteam);
    DisplayMSayAll((category == BAN_CAT_REGULARBAN ? "Player unbanned" : "Player Un-T-Listed"),
                   MENU_TIMEOUT_QUICK,
                   "%s\nwas%sby\n%N",
                   targetSteam,
                   (category == BAN_CAT_REGULARBAN ? "unbanned" : "Un-T-Listed"),
                   adminClient);

    // Delete the temporary IP ban from the server.
    decl String:storedTargetIp[LEN_IPSTRING];
    if(GetTrieString(g_hBannedIps, targetSteam, storedTargetIp, sizeof(storedTargetIp)))
    {
        ServerCommand("removeip %s", storedTargetIp);
        RemoveFromTrie(g_hBannedIps, targetSteam);
    }

    // Remove STEAM_0: prefix from subject's Steam ID.
    decl String:targetSteam_short[LEN_STEAMIDS - 8];
    CopyStringFrom(targetSteam_short, sizeof(targetSteam_short), targetSteam, sizeof(targetSteam), 8);

    /**************************** Execute unban query ****************************/

    decl String:query[512];
    Format(query, sizeof(query),
           "UPDATE bans SET approved_state = %d WHERE subject_steamid = '%s' AND category = %i",
           APPROVED_STATE_DISAPPROVED, targetSteam_short, category);
    SQL_TQuery(g_hDbConn_Main, EmptySqlCallback, query);

    /*********************** Add UPDATE HISTORY for this unban *******************/

    // Get the admin's Steam ID.
    decl String:adminSteam_short[LEN_STEAMIDS - 8] = "CONSOLE";
    if(adminClient)
    {
        decl String:adminSteam[LEN_STEAMIDS];
        GetClientAuthString(adminClient, adminSteam, sizeof(adminSteam));

        // Remove STEAM_0: prefix.
        CopyStringFrom(adminSteam_short, sizeof(adminSteam_short), adminSteam, sizeof(adminSteam), 8);
    }

    // Get, and escape, the admin's name.
    decl String:adminName[MAX_NAME_LENGTH] = "CONSOLE";
    decl String:esc_adminName[MAX_NAME_LENGTH * 2 + 1];
    if(adminClient)
        GetClientName(adminClient, adminName, sizeof(adminName));
    SQL_EscapeString(g_hDbConn_Main, adminName, esc_adminName, sizeof(esc_adminName));

    for(new i = 0; i < total; i++)
    {
        Format(query, sizeof(query),
                "INSERT INTO updates (\
                    ban_uuid, \
                    datetime, \
                    admin_forumid_or_steamid, \
                    admin_name, \
                    field, \
                    old_value, \
                    new_value) \
                VALUES (\
                    UNHEX('%s'), \
                    UNIX_TIMESTAMP(), \
                    '%s', \
                    '%s', \
                    'approved_state', \
                    %d, \
                    %d)",
                uuids[i],
                adminSteam_short,
                esc_adminName,
                old_approved_states[i],
                APPROVED_STATE_DISAPPROVED);
        SQL_TQuery(g_hDbConn_Main, EmptySqlCallback, query);
    }
}
