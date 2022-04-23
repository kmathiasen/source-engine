
// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

Ban_OnPluginStart()
{
    RegAdminCmd("sm_ban", Ban_Cmd, ADMFLAG_BAN,
                "Bans a user -- sm_ban [partialname/\"partial name with spaces\"/userid/steam/@magicword] [duration] [reason]");
    RegAdminCmd("sm_tlist", Ban_Cmd, ADMFLAG_KICK,
                "T-Lists a user -- sm_tlist [partialname/\"partial name with spaces\"/userid/steam/@magicword] [duration] [reason]");
    g_hBannedIps = CreateTrie();
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Ban_Cmd(adminClient, args)
{
    // The command itself could be different things (sm_ban, sm_tlist, etc).
    decl String:cmd[LEN_CONVARS];
    GetCmdArg(0, cmd, sizeof(cmd));
    new category;
    if(strcmp(cmd, "sm_ban", false) == 0)
        category = BAN_CAT_REGULARBAN;
    else
        category = BAN_CAT_TLIST;

    // Is T-Listing enabled on this server?
    if(category == BAN_CAT_TLIST && !g_bTlistEnabled)
    {
        ReplyToCommandGood(adminClient, "%s T-Listing is not enabled on this server", MSG_PREFIX);
        return Plugin_Handled;
    }

    // If no arguments, create menu with all players to let the admin select one.
    if(!args)
    {
        new Handle:menu = CreateMenu(BanPlayerSelect);
        SetMenuTitle(menu, (category == BAN_CAT_REGULARBAN ?
                            "Select Player To Ban" :
                            "Select Player To T-List"));
        g_iBanCategories[adminClient] = category;
        g_iBanTimes[adminClient] = g_iDefaultBan;
        Format(g_sBanReasons[adminClient], LEN_CONVARS, "");
        decl String:sUserid[LEN_INTSTRING];
        decl String:name[MAX_NAME_LENGTH];
        switch(category)
        {
            case BAN_CAT_REGULARBAN:
            {
                // Add all players to a menu.
                for(new i = 1; i <= MaxClients; i++)
                {
                    if(!IsClientInGame(i) || IsFakeClient(i))
                        continue;
                    GetClientName(i, name, sizeof(name));
                    IntToString(GetClientUserId(i), sUserid, sizeof(sUserid));
                    AddMenuItem(menu, sUserid, name);
                }
            }
            case BAN_CAT_TLIST:
            {
                // First the CT's, then the T's.
                for(new i = 1; i <= MaxClients; i++)
                {
                    if(!IsClientInGame(i) || IsFakeClient(i))
                        continue;
                    if(GetClientTeam(i) != TEAM_GUARDS)
                        continue;
                    GetClientName(i, name, sizeof(name));
                    IntToString(GetClientUserId(i), sUserid, sizeof(sUserid));
                    AddMenuItem(menu, sUserid, name);
                }
                for(new i = 1; i <= MaxClients; i++)
                {
                    if(!IsClientInGame(i) || IsFakeClient(i))
                        continue;
                    if(GetClientTeam(i) != TEAM_PRISONERS)
                        continue;
                    GetClientName(i, name, sizeof(name));
                    IntToString(GetClientUserId(i), sUserid, sizeof(sUserid));
                    AddMenuItem(menu, sUserid, name);
                }
            }
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
                PrepBan_ByClient(targetClient, duration, reason, category, adminClient);
        }
        case TARGET_TYPE_STEAM:
        {
            decl String:targetSteam[LEN_STEAMIDS];
            Format(targetSteam, sizeof(targetSteam), target);
            PrepBan_BySteam(targetSteam, duration, reason, category, adminClient);
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
                    PrepBan_ByClient(targetClient, duration, reason, category, adminClient);
            }
            else
            {
                // Multiple hits.  Show a menu to the admin.
                if(adminClient <= 0 || !IsClientInGame(adminClient))
                    ReplyToCommandGood(adminClient, "%s Multiple matches found for \x01[\x03%s\x01]", MSG_PREFIX);
                else
                {
                    new Handle:menu = CreateMenu(BanPlayerSelect);
                    SetMenuTitle(menu, (category == BAN_CAT_REGULARBAN ?
                            "Select Player To Ban" :
                            "Select Player To T-List"));
                    g_iBanCategories[adminClient] = category;
                    g_iBanTimes[adminClient] = duration;
                    Format(g_sBanReasons[adminClient], LEN_CONVARS, reason);
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

    return Plugin_Handled;
}

// ####################################################################################
// ################################# MAIN FUNCTIONS ###################################
// ####################################################################################

// Trust me, I'm good at maths :3
// Algorithm to prevent rogue admins from mass banning.

bool:PreventMassBan(adminClient)
{
    if (!adminClient)
        return false;

    new bits = GetUserFlagBits(adminClient);
    if (!(bits & ADMFLAG_ROOT) && !(bits & ADMFLAG_CHANGEMAP))
    {
        new time_left = (120 * (1 << g_iBans[adminClient])) - (GetTime() - g_iLastBan[adminClient]);
        if (time_left >= 0)
        {
            PrintToChat(adminClient,
                        "%s To prevent mass bans, please wait \x03%d\x04 seconds",
                        MSG_PREFIX, time_left);

            return true;
        }

        new last_bit;

        for (new i = 6; i < 32; i++)
        {
            if (time_left & (1 << i))
                last_bit = i;
        }

        if (last_bit > 0)
            g_iBans[adminClient] -= last_bit - 5;

        g_iBans[adminClient] = ++g_iBans[adminClient] > 0 ? g_iBans[adminClient] : 1;
        g_iLastBan[adminClient] = GetTime();
    }

    return false;
}

stock PrepBan_ByClient(targetClient, durationMins, const String:reason[LEN_CONVARS], category, adminClient)
{
    // The subject is not a bot, is he?
    if(IsFakeClient(targetClient))
    {
        KickClient(targetClient);
        ReplyToCommandGood(adminClient, "%s Bot kicked", MSG_PREFIX);
        return;
    }

    if (PreventMassBan(adminClient))
        return;

    if (adminClient > 0)
    {
        new AdminId:clientAdmin = GetUserAdmin(adminClient);
        new AdminId:targetAdmin = GetUserAdmin(targetClient);
        new clientLevel = GetAdminImmunityLevel(clientAdmin);

        // They're not root, and they're trying to ban/tlist another admin above/same level as them.
        if (clientLevel < 100 &&
            (clientLevel <= GetAdminImmunityLevel(targetAdmin)))
        {
            PrintToChat(adminClient, "%s You may not target that player", MSG_PREFIX);
            return;
        }
    }

    // Get required info from the admin (if he's banning himself we won't have it later if we don't get it now).
    new approvedState = GetApprovedState(adminClient);
    durationMins = GetActualDuration(durationMins, adminClient);
    new adminIpUnsigned = GetPlayerUnsignedIp(adminClient);
    decl String:adminSteam[LEN_STEAMIDS] = "CONSOLE";
    decl String:adminName[MAX_NAME_LENGTH] = "CONSOLE";
    if(adminClient && IsClientInGame(adminClient))
    {
        GetClientAuthString(adminClient, adminSteam, sizeof(adminSteam));
        GetClientName(adminClient, adminName, sizeof(adminName));
    }

    // Get target info.
    decl String:targetSteam[LEN_STEAMIDS];
    decl String:targetName[MAX_NAME_LENGTH];
    GetClientAuthString(targetClient, targetSteam, sizeof(targetSteam));
    GetClientName(targetClient, targetName, sizeof(targetName));

    // Ban or T-List?
    if(category == BAN_CAT_REGULARBAN)
    {
        // Store target IP for later unban.
        decl String:targetIpToStore[LEN_IPSTRING];
        GetClientIP(targetClient, targetIpToStore, sizeof(targetIpToStore));
        SetTrieString(g_hBannedIps, targetSteam, targetIpToStore);

        // Notify players of ban.
        PrintToChatAll("%s \x03%N \x04banned \x03%N \x04for \x03%d\x04 minutes",
                       MSG_PREFIX, adminClient, targetClient, durationMins);

        // IP ban them for a little bit, so they can't reconnect spam.
        BanClient(targetClient, IP_BAN_MINUTES,
                  BANFLAG_IP, g_sBanMessage, g_sBanMessage,
                  "sm_ban", adminClient);
    }
    else
    {
        // Notify players of T-List.
        PrintToChatAll("%s \x03%N \x04T-Listed \x03%N \x04for \x03%d\x04 minutes",
                       MSG_PREFIX, adminClient, targetClient, durationMins);

        // Switch player.
        TeamCheck_TeamSwitchSlay(targetClient);
    }

    // Store the ban UUID (if applicable) for family shared ban purposes.
    new String:familyUUID[LEN_HEXUUID] = "";

    // Do ban.
    DoBan(targetSteam, targetName, durationMins, approvedState, reason, category, adminSteam, adminName, adminIpUnsigned, adminClient, "", familyUUID, sizeof(familyUUID));

    // Family sharing
    if (targetClient > 0 && !StrEqual(g_sOwnerSteamid[targetClient], ""))
    {
        decl String:familyreason[LEN_CONVARS];
        Format(familyreason, sizeof(familyreason), "Family sharing tlist from %s (%s): %s", targetName, targetSteam, reason);

        // Do ban.
        DoBan(g_sOwnerSteamid[targetClient], targetName, durationMins, approvedState, familyreason, category, adminSteam, adminName, adminIpUnsigned, adminClient, familyUUID);
    }
}

stock PrepBan_BySteam(const String:targetSteam[LEN_STEAMIDS], durationMins, const String:reason[LEN_CONVARS], category, adminClient)
{
    if (PreventMassBan(adminClient))
        return;

    // Get required info from the admin (if he's banning himself we won't have it later if we don't get it now).
    new approvedState = GetApprovedState(adminClient);
    durationMins = GetActualDuration(durationMins, adminClient);
    new adminIpUnsigned = GetPlayerUnsignedIp(adminClient);
    decl String:adminSteam[LEN_STEAMIDS] = "CONSOLE";
    decl String:adminName[MAX_NAME_LENGTH] = "CONSOLE";
    if(adminClient && IsClientInGame(adminClient))
    {
        GetClientAuthString(adminClient, adminSteam, sizeof(adminSteam));
        GetClientName(adminClient, adminName, sizeof(adminName));
    }

    // Is this Steam ID in the server?
    decl String:targetName[MAX_NAME_LENGTH] = "";
    new targetClient = GetClientOfSteam(targetSteam);
    if(targetClient && IsClientInGame(targetClient))
    {
        // Get target info.
        GetClientName(targetClient, targetName, sizeof(targetName));

        // Ban or T-List?
        if(category == BAN_CAT_REGULARBAN)
        {
            // Store target IP for later unban.
            decl String:targetIpToStore[LEN_IPSTRING];
            GetClientIP(targetClient, targetIpToStore, sizeof(targetIpToStore));
            SetTrieString(g_hBannedIps, targetSteam, targetIpToStore);

            // Notify players of ban.
            PrintToChatAll("%s \x03%N \x04banned \x03%N \x04for \x03%d\x04 minutes",
                           MSG_PREFIX, adminClient, targetClient, durationMins);

            // IP ban them for a little bit, so they can't reconnect spam.
            BanClient(targetClient, IP_BAN_MINUTES,
                      BANFLAG_IP, g_sBanMessage, g_sBanMessage,
                      "sm_ban", adminClient);
        }
        else
        {
            // Notify players of T-List.
            PrintToChatAll("%s \x03%N \x04T-Listed \x03%N \x04for \x03%d\x04 minutes",
                           MSG_PREFIX, adminClient, targetClient, durationMins);

            // Switch player.
            TeamCheck_TeamSwitchSlay(targetClient);
        }
    }
    else
    {
        // Notify players of ban or T-List.
        PrintToChatAll("%s \x03%N \x04%s \x03%s \x04for \x03%d\x04 minutes",
                       MSG_PREFIX, adminClient,
                       (category == BAN_CAT_REGULARBAN ? "banned" : "T-Listed"),
                       targetSteam, durationMins);
    }

    // Store the ban UUID (if applicable) for family shared ban purposes.
    new String:familyUUID[LEN_HEXUUID] = "";

    // Do ban.
    DoBan(targetSteam, targetName, durationMins, approvedState, reason, category, adminSteam, adminName, adminIpUnsigned, adminClient, "", familyUUID, sizeof(familyUUID));

    // Family sharing
    if (targetClient > 0 && !StrEqual(g_sOwnerSteamid[targetClient], ""))
    {
        decl String:familyreason[LEN_CONVARS];
        Format(familyreason, sizeof(familyreason), "Family sharing tlist from %s (%s): %s", targetName, targetSteam, reason);

        // Do ban.
        DoBan(g_sOwnerSteamid[targetClient], targetName, durationMins, approvedState, familyreason, category, adminSteam, adminName, adminIpUnsigned, adminClient, "", familyUUID, sizeof(familyUUID));
    }
}

// ####################################################################################
// ############################ INTERNAL HELPER FUNCTIONS #############################
// ####################################################################################

stock DoBan(const String:targetSteam[LEN_STEAMIDS],
            const String:targetName[MAX_NAME_LENGTH],
            durationMins,
            approvedState,
            const String:reason[LEN_CONVARS],
            category,
            const String:adminSteam[LEN_STEAMIDS],
            const String:adminName[MAX_NAME_LENGTH],
            adminIpUnsigned,
            adminClient,
            const String:linkToUUID[]="",
            String:banUUID[]="",
            uuid_maxlength=0)
{
    // Are we disconnected?
    if(g_hDbConn_Main == INVALID_HANDLE)
    {
        LogMessage("ERROR in DoBan: The DB handle was invalid");
        ReplyToCommandGood(adminClient, "%s ERROR: Lost connection to database. Ban has not been recorded", MSG_PREFIX);
        return;
    }

    // Shorten Steam IDs.
    decl String:adminSteam_short[LEN_STEAMIDS - 8];
    decl String:targetSteam_short[LEN_STEAMIDS - 8];
    CopyStringFrom(adminSteam_short, sizeof(adminSteam_short), adminSteam, sizeof(adminSteam), 8);
    CopyStringFrom(targetSteam_short, sizeof(targetSteam_short), targetSteam, sizeof(targetSteam), 8);

    // Escape names.
    decl String:esc_adminName[MAX_NAME_LENGTH * 2 + 1];
    decl String:esc_targetName[MAX_NAME_LENGTH * 2 + 1];
    SQL_EscapeString(g_hDbConn_Main, adminName, esc_adminName, sizeof(esc_adminName));
    SQL_EscapeString(g_hDbConn_Main, targetName, esc_targetName, sizeof(esc_targetName));

    // If there is a reason, escape the reason.
    new bool:isReason = false;
    decl String:esc_reason[LEN_CONVARS * 2 + 1] = "";
    if(strlen(reason) > 0)
    {
        isReason = true;
        SQL_EscapeString(g_hDbConn_Main, reason, esc_reason, sizeof(esc_reason));
    }

    // Create UUID string (without dashes).
    decl String:uuid[LEN_HEXUUID];
    GetUUID(uuid, false);

    // Return the UUID
    if (uuid_maxlength > 0)
    {
        Format(banUUID, uuid_maxlength, uuid);
    }

    // Pack info to pass into callback.
    new Handle:data = CreateDataPack();
    WritePackCell(data, adminClient && IsClientInGame(adminClient) ? GetClientUserId(adminClient) : 0);
    WritePackCell(data, adminIpUnsigned);
    WritePackString(data, uuid);
    WritePackString(data, linkToUUID);
    WritePackString(data, esc_reason);

    // Insert ban.
    decl String:query[2048];
    Format(query, sizeof(query),
            "INSERT INTO bans (\
                uuid, \
                category, \
                subject_steamid, \
                subject_name, \
                datetime_added, \
                duration_seconds, \
                approved_state, \
                admin_forumid_or_steamid, \
                admin_name, \
                bannedfrom_ip, \
                bannedfrom_port, \
                lastpost_formods_forumid, \
                lastpost_forregs_forumid, \
                lastpost_formods_datetime, \
                lastpost_forregs_datetime) \
            VALUES (\
                UNHEX('%s'), \
                %i, \
                '%s', \
                '%s', \
                UNIX_TIMESTAMP(), \
                %i, \
                %i, \
                '%s', \
                '%s', \
                %u, \
                %i, \
                %i, \
                %i, \
                %s, \
                %s)", // These last two %s's have no quotes on purpose.
            uuid,
            category,
            targetSteam_short,
            esc_targetName,
            durationMins * 60,
            approvedState,
            adminSteam_short,
            esc_adminName,
            g_iIP,
            g_iPort,
            (isReason ? -1 : 0), // This -1 tells the PHP script to use whoever was the banning admin as the poster.
            (isReason ? -1 : 0), // Same as above.
            (isReason ? "UNIX_TIMESTAMP()" : "0"),
            (isReason ? "UNIX_TIMESTAMP()" : "0"));
    SQL_TQuery(g_hDbConn_Main, DoBan_Finish, query, any:data);
}

// ####################################################################################
// ####################################### MENUS ######################################
// ####################################################################################

public BanPlayerSelect(Handle:menu, MenuAction:action, adminClient, selected)
{
    if(action == MenuAction_Select)
    {
        decl String:sUserid[LEN_INTSTRING];
        GetMenuItem(menu, selected, sUserid, sizeof(sUserid));
        new targetClient = GetClientOfUserId(StringToInt(sUserid));
        if(!targetClient)
            PrintToChat(adminClient, "%s Target has left the server", MSG_PREFIX);
        else
            PrepBan_ByClient(targetClient,
                             g_iBanTimes[adminClient],
                             g_sBanReasons[adminClient],
                             g_iBanCategories[adminClient],
                             adminClient);
    }
    else if(action == MenuAction_End)
        CloseHandle(menu);
}

// ####################################################################################
// #################################### CALLBACKS #####################################
// ####################################################################################

public DoBan_Finish(Handle:conn, Handle:fetch, const String:error[], any:data)
{
    // Extract passed data.
    ResetPack(Handle:data);
    new adminClient = GetClientOfUserId(ReadPackCell(Handle:data));
    new adminIpUnsigned = ReadPackCell(Handle:data);
    decl String:uuid[LEN_HEXUUID];
    decl String:linkToUUID[LEN_HEXUUID];
    ReadPackString(Handle:data, uuid, sizeof(uuid));
    ReadPackString(Handle:data, linkToUUID, sizeof(linkToUUID));
    decl String:esc_reason[LEN_CONVARS * 2 + 1];
    ReadPackString(Handle:data, esc_reason, sizeof(esc_reason));
    CloseHandle(Handle:data);

    // Did it fail?
    if(Db_QueryFailed(conn, fetch, error))
    {
        LogMessage("ERROR in DoBan_Finish: %s", error);
        ReplyToCommandGood(adminClient, "%s ERROR: Lost connection to database. Ban has not been recorded", MSG_PREFIX);
        return;
    }

    // Was ban successfully inserted?
    if(SQL_GetAffectedRows(conn) <= 0)
    {
        ReplyToCommandGood(adminClient, "%s ERROR: Ban was not inserted", MSG_PREFIX);
        return;
    }

    // If there is no reason, we're done.
    if(strlen(esc_reason) <= 0)
        return;

    // Insert reason as a new post.
    decl String:query[512 + sizeof(uuid)+ sizeof(esc_reason)];
    
    if (!StrEqual(linkToUUID, ""))
    {
        new id = SQL_GetInsertId(fetch);
        decl String:family_reason[LEN_CONVARS];

        Format(family_reason, sizeof(family_reason),
               "Family shared account ban. Reply to http://hellsgamers.com/hgbans/?i=%d", id);

        Format(query, sizeof(query),
                            "INSERT INTO posts \
                                (uuid, ban_uuid, datetime, poster_forumid, poster_ip, content) \
                            VALUES \
                                (UNHEX(REPLACE(UUID(),'-','')), UNHEX('%s'), UNIX_TIMESTAMP(), %i, %u, '%s%s')",
                            linkToUUID,
                            -1, // This tells the PHP script to use whoever was the banning admin as the poster.
                            adminIpUnsigned,
                            "__PLAIN__",
                            family_reason);

        SQL_TQuery(g_hDbConn_Main, EmptySqlCallback, query);

        Format(query, sizeof(query), "UPDATE bans SET thread_locked = 1 WHERE uuid = UNHEX('%s')", linkToUUID);
        SQL_TQuery(g_hDbConn_Main, EmptySqlCallback, query);
    }

    Format(query, sizeof(query),
                        "INSERT INTO posts \
                            (uuid, ban_uuid, datetime, poster_forumid, poster_ip, content) \
                        VALUES \
                            (UNHEX(REPLACE(UUID(),'-','')), UNHEX('%s'), UNIX_TIMESTAMP(), %i, %u, '%s%s')",
                        uuid,
                        -1, // This tells the PHP script to use whoever was the banning admin as the poster.
                        adminIpUnsigned,
                        "__PLAIN__",
                        esc_reason);
    SQL_TQuery(g_hDbConn_Main, EmptySqlCallback, query);
}
