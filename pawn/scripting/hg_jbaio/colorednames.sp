
// ####################################################################################
// ##################################### GLOBALS ######################################
// ####################################################################################

// Cookie to look for in client prefs.
new Handle:g_hCookieCodName;

// Array to store whether this player's colored name was looked up or not.
new bool:g_bColoredLookedUp[MAXPLAYERS + 1];

// Array to store the replacement names of each player.
new String:g_sColoredNames[MAXPLAYERS + 1][LEN_COLOREDNAMES];

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

ClrNms_OnPluginStart()
{
    RegConsoleCmd("sm_coloredname", Command_SetColoredName, "Sets the current players colored name");
    RegConsoleCmd("sm_colorednames", Command_ListUsers, "Lists all users with their real and colored names", ADMFLAG_KICK);
    RegConsoleCmd("sm_coloredname_list", Command_ListUsers, "Lists all users with their real and colored names", ADMFLAG_KICK);
    RegConsoleCmd("sm_colorednames_list", Command_ListUsers, "Lists all users with their real and colored names", ADMFLAG_KICK);

    g_hCookieCodName = RegClientCookie("cookie_coloredname", "Colored name replacement", CookieAccess_Public);

    // Set initial colored name state for all clients.
    for (new i = 1; i <= MaxClients; i++)
    {
        g_bColoredLookedUp[i] = false;
        g_sColoredNames[i][0] = '\0';
    }
}

ClrNms_OnClientAuthorized(client)
{
    g_bColoredLookedUp[client] = false;
    g_sColoredNames[client][0] = '\0';
}

ClrNms_OnClientDisconnect(client)
{
    g_bColoredLookedUp[client] = false;
    g_sColoredNames[client][0] = '\0';
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_ListUsers(client, args)
{
    new clientCount = 0;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i) && !IsFakeClient(i))
        {
            decl String:name[MAX_NAME_LENGTH];
            decl String:coloredname[MAX_NAME_LENGTH];
            GetClientName(i, name, MAX_NAME_LENGTH);
            GetClientCookie(i, g_hCookieCodName, coloredname, sizeof(coloredname));

            if (g_iGame != GAMETYPE_CSGO)
            {
                ReplaceString(coloredname, sizeof(coloredname), "\x07", "");
                ReplaceString(coloredname, sizeof(coloredname), "\x08", "");
            }

            // Only show people who have a colored name set
            if (StrEqual(coloredname, "")) continue;

            if (client > 0)
                PrintToChat(client, "%s %s === %s", MSG_PREFIX, name, coloredname);
            else
                PrintToConsole(0, "%s %s === %s", MSG_PREFIX_CONSOLE, name, coloredname);

            clientCount++;
        }
    }
    if (client > 0)
        PrintToChat(client, "%s %i clients listed", MSG_PREFIX, clientCount);
    else
        PrintToConsole(0, "%s %i clients listed", MSG_PREFIX_CONSOLE, clientCount);
}

public Action:Command_SetColoredName(client, args)
{
    if (client != 0)
    {
        decl String:coloredname[LEN_COLOREDNAMES];
        if (GetCmdArgs() == 1)
        {
            // Is client admin or has high prison rep?
            new rep_needed = GetConVarInt(g_hCvRepLevelColoredName);
            new rep = PrisonRep_GetPoints(client);
            new AdminId:id = GetUserAdmin(client);
            if ((id == INVALID_ADMIN_ID) && (rep < rep_needed))
            {
                ReplyToCommand(client, "You must be an admin or have %i prison rep to use this feature", rep_needed);
            }
            else
            {
                decl String:steam[LEN_STEAMIDS];
                GetClientAuthString2(client, steam, sizeof(steam));

                LogMessage("%N (%s) changed their colored name to \"%s\"", client, steam, coloredname);

                // Get the name they specified from the argument.
                GetCmdArg(1, coloredname, sizeof(coloredname));

                SetClientCookie(client, g_hCookieCodName, coloredname);
                ReplyToCommand(client, "Colored name set");

                // Set replacement name array.
                Format(g_sColoredNames[client], LEN_COLOREDNAMES, coloredname);
                g_bColoredLookedUp[client] = false;

            }
        }
        else
        {
            // No args.  Show help.
            GetClientCookie(client, g_hCookieCodName, coloredname, sizeof(coloredname));
            ReplyToCommand(client, "-------- CURRENT --------");
            ReplyToCommand(client, "Your current colored chat name: %s", coloredname);
            ReplyToCommand(client, "-------- USAGE ----------");
            ReplyToCommand(client, "sm_coloredname \"colored name here\" - Sets your colored name");
            ReplyToCommand(client, "sm_coloredname \"\" - Disables your colored name");
            ReplyToCommand(client, "sm_colorednames - Displays people's real names");
            ReplyToCommand(client, "-------- COLORS ---------");
            ReplyToCommand(client, "visit http://hellsgamers.com/topic/77728-colored-names/ for available color codes");
          //ReplyToCommand(client, "^0 - Default");
          //ReplyToCommand(client, "^1 - Default");
          //ReplyToCommand(client, "^2 - White");
          //ReplyToCommand(client, "^3 - Team color");
          //ReplyToCommand(client, "^4 - Green");
          //ReplyToCommand(client, "^5 - Olive green");
          //ReplyToCommand(client, "^6 - Item color (usually yellow, black if the client hasn't seen an item found or crafted yet)");
          //ReplyToCommand(client, "^7 - Default");
          //ReplyToCommand(client, "^8 - Team");
          //ReplyToCommand(client, "^9 - Green");
        }
    }
    else
    {
        PrintToServer("This command is only available to in-game players");
    }

    return Plugin_Handled;
}

// ####################################################################################
// #################################### FUNCTIONS #####################################
// ####################################################################################

ClrNms_LookupColoredName(client)
{
    // Is client admin or has high prison rep?
    new rep_needed = GetConVarInt(g_hCvRepLevelColoredName);
    new rep = PrisonRep_GetPoints(client);
    new AdminId:id = GetUserAdmin(client);
    if ((id == INVALID_ADMIN_ID) && (rep < rep_needed))
    {
        g_bColoredLookedUp[client] = true;
        g_sColoredNames[client][0] = '\0';
        return;
    }

  //if (!AreClientCookiesCached(client)) return;

    // Get the replacement name, which is stored in a client cookie.
    decl String:coloredname[LEN_COLOREDNAMES];
    GetClientCookie(client, g_hCookieCodName, coloredname, sizeof(coloredname));

    // Did the client store any replacement name?
    if (StrEqual(coloredname, ""))
    {
        g_bColoredLookedUp[client] = true;
        g_sColoredNames[client][0] = '\0';
        return;
    }

    // Apply color codes to the replacement name.
    ReplaceString(coloredname, sizeof(coloredname), "^1", "\x01");
    ReplaceString(coloredname, sizeof(coloredname), "^2", "\x02");
    ReplaceString(coloredname, sizeof(coloredname), "^3", "\x03");
    ReplaceString(coloredname, sizeof(coloredname), "^4", "\x04");
    ReplaceString(coloredname, sizeof(coloredname), "^5", "\x05");
    ReplaceString(coloredname, sizeof(coloredname), "^6", "\x06");

    if (g_iGame == GAMETYPE_CSGO)
    {
        ReplaceString(coloredname, sizeof(coloredname), "^7", "\x07");
        ReplaceString(coloredname, sizeof(coloredname), "^8", "\x08");
    }

    if (GetUserFlagBits(client) && g_iGame != GAMETYPE_CSGO)
    {
        CReplaceColorCodes(coloredname, client, false, LEN_COLOREDNAMES);

        ReplaceString(coloredname[LEN_COLOREDNAMES - 7], 7, "\x07", "");
        ReplaceString(coloredname[LEN_COLOREDNAMES - 10], 10, "\x08", "");
    }

    else if (g_iGame != GAMETYPE_CSGO)
    {
        ReplaceString(coloredname, sizeof(coloredname), "\x07", "");
        ReplaceString(coloredname, sizeof(coloredname), "\x08", "");
    }


    // Get rid of when people manually put admin in their name.
    ReplaceString(coloredname, sizeof(coloredname), "admin", "", false);

    // Store the replacement name in the array.
    Format(g_sColoredNames[client], LEN_COLOREDNAMES, coloredname);
    g_bColoredLookedUp[client] = true;
}

bool:ClrNms_ApplyColor(client, bool:teamchat=false)
{
    // Returning TRUE means this function shall handle the Chat command.

    // Not sure what this is.
  //if (!IsChatTrigger()) return false;

    // Get message from arg.
    decl String:msg[LEN_CONVARS];
    GetCmdArgString(msg, sizeof(msg));
    StripQuotes(msg);

    // Is it admin chat?
    if (msg[0] == '@' || !StrContains(msg, "!!!!"))
        return false;

    // Get replacement name from array.
    if (!g_bColoredLookedUp[client])
        ClrNms_LookupColoredName(client);
    decl String:coloredname[LEN_COLOREDNAMES];
    Format(coloredname, sizeof(coloredname), g_sColoredNames[client]);
    TrimString(coloredname);

    // Get rid of HEX code colors (for now).
    ReplaceString(msg, sizeof(msg), "\x01", "");
    ReplaceString(msg, sizeof(msg), "\x02", "");
    ReplaceString(msg, sizeof(msg), "\x03", "");
    ReplaceString(msg, sizeof(msg), "\x04", "");
    ReplaceString(msg, sizeof(msg), "\x05", "");
    ReplaceString(msg, sizeof(msg), "\x06", "");

    // Is admin?
    decl String:AdmnPrefix[64];
    new bits = GetUserFlagBits(client);

    if (!(bits & ADMFLAG_ROOT))
    {
        ReplaceString(msg, sizeof(msg), "\x07", "");
        ReplaceString(msg, sizeof(msg), "\x08", "");
    }

    if ((bits & ADMFLAG_ROOT) || (bits & ADMFLAG_KICK))
        Format(AdmnPrefix, sizeof(AdmnPrefix), "\x01\x0B\x04[\x03admin\x04]\x03 ");

    else if (bits)
        Format(AdmnPrefix, sizeof(AdmnPrefix), "\x01\x0B\x04[\x03VIP\x04]\x03 ");

    else
    {
        if (g_iGame != GAMETYPE_CSGO)
        {
            ReplaceString(coloredname, sizeof(coloredname), "\x07", "");
            ReplaceString(coloredname, sizeof(coloredname), "\x08", "");
        }

        // We need somthing in front of their name to at least show their team color, since a CT could
        // choose an all-red name or a T could choose an all-blue name, just to trick people.
        Format(AdmnPrefix, sizeof(AdmnPrefix), "\x01\x0B\x04[\x03REP\x01:\x03%i\x04]\x03 ", PrisonRep_GetPoints(client));
    }
    // To be here, the player either has admin or high rep. But does the player have a colored name set?

    /* No colored name is set... */

    if (StrEqual(coloredname, ""))
    {
        // Is he an admin?  If so, we should prefix the "[admin]" word before his name.
        if (!bits)
        {
            // He has no colored name, and he is not an admin.  Return false so his name/message is not modified by this func.
            return false;
        }
        else
        {
            // He has no colored name, but he is an admin.
            // We will use his normal name, so he can still get the [admin] prefix below.
            Format(coloredname, sizeof(coloredname), "%N", client);
        }
    }

    /* He does have a colored name... Use it... */

    // Is dead?
    new bool:IsSenderAlive = JB_IsPlayerAlive(client);
    decl String:DeadPrefix[14];
    if (!IsSenderAlive)
        Format(DeadPrefix, sizeof(DeadPrefix), "\x01*DEAD* ");
    else
        Format(DeadPrefix, sizeof(DeadPrefix), "");

    // Is team chat?
    decl String:TeamPrefix[14];
    if (teamchat)
        Format(TeamPrefix, sizeof(TeamPrefix), "\x01(TEAM) ");
    else
        Format(TeamPrefix, sizeof(TeamPrefix), "");

    if (StrEqual(msg, "") || StrEqual(msg, " "))
        return true;

    // Assemble output message.
    decl String:buffer[sizeof(DeadPrefix) + sizeof(TeamPrefix) + sizeof(AdmnPrefix) + sizeof(coloredname) + sizeof(msg)];
    Format(buffer, sizeof(buffer), "%s%s%s%s \x01:  %s", DeadPrefix, TeamPrefix, AdmnPrefix, coloredname, msg);

    // Send message to clients.
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i) && IsClientInGame(i))
        {
            // Don't send a living person the message from a dead person.
            if (JB_IsPlayerAlive(i) && !IsSenderAlive) continue;

            // Don't send an enemy the message if it is a Team Chat.
            if (teamchat && (GetClientTeam(client) != GetClientTeam(i))) continue;

            // Send message.
            // I believe this more direct message-sending approach is required to get around
            // color limitations of normal "chat" messages.
            SayText2(i, client, buffer);

            // SayText2 and PrintToChat aren't logged to console in CS:GO
            if (g_iGame == GAMETYPE_CSGO)
                PrintToConsole(i, buffer);
        }
    }

    // Log.
    if (teamchat)
        WriteChatLog(client, "say_team", msg);
    else
        WriteChatLog(client, "say", msg);

    // Play nice with other plugins and fire the "player_say" event.
    // Hopefully this will fix admins not being able to type !bort and other commands like that

    new Handle:player_say = CreateEvent("player_say", true);

    SetEventInt(player_say, "userid", GetClientUserId(client));
    SetEventString(player_say, "text", msg);

    FireEvent(player_say, true);

    // Prevent normal chat msg from showing up because we are handling it here.
    return true;
}

stock SayText2(recipient, author, const String:message[])
{
    new Handle:hBuffer = StartMessageOne("SayText2", recipient);

    if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available &&
        GetUserMessageType() == UM_Protobuf)
    {
        PbSetInt(hBuffer, "ent_idx", author);
        PbSetBool(hBuffer, "chat", false);

        PbSetString(hBuffer, "msg_name", message);
        PbAddString(hBuffer, "params", "");
        PbAddString(hBuffer, "params", "");
        PbAddString(hBuffer, "params", "");
        PbAddString(hBuffer, "params", "");
    }

    else
    {
        BfWriteByte(hBuffer, author);
        BfWriteByte(hBuffer, true);
        BfWriteString(hBuffer, message);
    }

    EndMessage();
}

stock WriteChatLog(client, const String:sayOrSayTeam[], const String:msg[LEN_CONVARS])
{
    decl String:name[MAX_NAME_LENGTH];
    decl String:steam[LEN_STEAMIDS];
    decl String:teamName[10];

    GetClientName(client, name, MAX_NAME_LENGTH);
    GetTeamName(GetClientTeam(client), teamName, sizeof(teamName));
    GetClientAuthString2(client, steam, sizeof(steam));
    LogToGame("\"%s<%i><%s><%s>\" %s \"%s\"", name, GetClientUserId(client), steam, teamName, sayOrSayTeam, msg);
}
