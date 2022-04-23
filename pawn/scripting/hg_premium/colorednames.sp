
#define COLOREDNAME_MAX_LENGTH 128

#define TEAMCOLOR_LIGHTGREEN -1
#define TEAMCOLOR_TEAM 0
#define TEAMCOLOR_GREY 1
#define TEAMCOLOR_RED 2
#define TEAMCOLOR_BLUE 3

// ###################### GLOBALS ######################

// Cookie to look for in client prefs.
new Handle:g_hCookieCodName;
new Handle:g_hCookieCodChat;

// Array to store the replacement names of each player.
new String:g_sColoredNames[MAXPLAYERS + 1][COLOREDNAME_MAX_LENGTH];
new String:g_sColoredChat[MAXPLAYERS + 1][MAX_NAME_LENGTH];

// They have enough rep to own limited colorednames on JB
new bool:g_bEnabledByJB[MAXPLAYERS + 1];

// sv_deadtalk
new Handle:g_hDeadTalkConVar = INVALID_HANDLE;
new bool:g_bDeadTalk;

// ###################### EVENTS ######################

ClrNms_OnPluginStart()
{
    RegConsoleCmd("sm_coloredname", Command_SetColoredName, "Sets the current players colored name");
    RegConsoleCmd("sm_colorednames", Command_ListUsers, "Lists all users with their real and colored names");
    RegConsoleCmd("sm_coloredname_list", Command_ListUsers, "Lists all users with their real and colored names");
    RegConsoleCmd("sm_colorednames_list", Command_ListUsers, "Lists all users with their real and colored names");

    RegConsoleCmd("sm_coloredchat", Command_SetColoredChat, "Sets the current players chat color");

    g_hCookieCodName = RegClientCookie("cookie_coloredname", "Colored name replacement", CookieAccess_Public);
    g_hCookieCodChat = RegClientCookie("cookie_coloredchat", "Colored chat replacement", CookieAccess_Public);

    // Currently only CS:GO has this ConVar
    if ((g_hDeadTalkConVar = FindConVar("sv_deadtalk")) == INVALID_HANDLE)
    {
        g_hDeadTalkConVar = CreateConVar("sv_deadtalk", "0", "Dead players can speak (voice, text) to the living");
    }

    HookConVarChange(g_hDeadTalkConVar, DeadTalkChanged);
}

public DeadTalkChanged(Handle:cvar, const String:old[], const String:newv[])
{
    g_bDeadTalk = GetConVarInt(g_hDeadTalkConVar) == 1;
}

ClrNms_OnConfigsExecuted()
{
    g_bDeadTalk = GetConVarInt(g_hDeadTalkConVar) == 1;
}

ClrNms_OnClientFullyAuthorized(client)
{
    g_sColoredNames[client][0] = '\0';
    g_sColoredChat[client][0] = '\0';

    GetClientCookie(client, g_hCookieCodName,
                    g_sColoredNames[client], COLOREDNAME_MAX_LENGTH);

    GetClientCookie(client, g_hCookieCodChat,
                    g_sColoredChat[client], MAX_NAME_LENGTH);

    SetColoredName(client, g_sColoredNames[client]);
    SetColoredChat(client, g_sColoredChat[client]);
}

ClrNms_OnClientDisconnect(client)
{
    g_sColoredNames[client][0] = '\0';
}

// ###################### COMMANDS ######################


public Action:Command_ListUsers(client, args)
{
    new clientCount = 0;
    for(new i = 1; i <= MaxClients; i++)
    {
        if(IsClientConnected(i) && !IsFakeClient(i))
        {
            if ((!g_bClientEquippedItem[i][Item_ColoredName] &&
                 !g_bEnabledByJB[i]) ||
                g_bClientEquippedItem[i][Item_StealthMode])
                continue;

            decl String:name[LEN_NAMES];
            decl String:coloredname[LEN_NAMES];
            GetClientName(i, name, LEN_NAMES);
            GetClientCookie(i, g_hCookieCodName, coloredname, sizeof(coloredname));

            // Only show people who have a colored name set
            if (StrEqual(coloredname, "")) continue;

            ReplaceString(coloredname, sizeof(coloredname), "\x07", "");
            ReplaceString(coloredname, sizeof(coloredname), "\x08", "");
    
            if(client > 0)
                PrintToChat(client, "%s %s === %s", MSG_PREFIX, name, coloredname);
            else
                PrintToConsole(0, "%s %s === %s", MSG_PREFIX_CONSOLE, name, coloredname);

            clientCount++;
        }
    }
    if(client > 0)
        PrintToChat(client, "%s %i clients listed", MSG_PREFIX, clientCount);
    else
        PrintToConsole(0, "%s %i clients listed", MSG_PREFIX_CONSOLE, clientCount);

    return Plugin_Handled;
}

bool:ClrNms_CanUseFromJB(client)
{
    if (g_iServerType & SERVER_JAILBREAK ||
        g_iServerType & SERVER_CSGOJB ||
        g_iServerType & SERVER_TF2JB)
    {
        if (PrisonRep_GetPoints(client) >= GetConVarInt(FindConVar("aio_rep_level_coloredname")))
        {
            g_bEnabledByJB[client] = true;
            return true;
        }

        else
            g_bEnabledByJB[client] = false;
    }

    return false;
}

public Action:Command_SetColoredChat(client, args)
{
    // Well, I wrote it might as well let someone use it...
    if (!IsClientInGame(client) || !(GetUserFlagBits(client) & ADMFLAG_ROOT))
        return Plugin_Continue;

    if (!IsAuthed(client, "Team Colored Chat") ||
        !g_bClientHasItem[client][Item_ColoredChat])
    {
        PrintToChat(client,
                    "%s You do not own \x03Colored Chat",
                    MSG_PREFIX);

        PrintToChat(client,
                    "%s You can purchase it by typing \x03!shop",
                    MSG_PREFIX);

        return Plugin_Handled;
    }

    decl String:coloredchat[LEN_NAMES];

    if(args)
    {
        // Get the name they specified from the argument.
        GetCmdArgString(coloredchat, sizeof(coloredchat));
        StripQuotes(coloredchat);

        SetClientCookie(client, g_hCookieCodChat, coloredchat);
        ReplyToCommand(client, "Chat color set");

        SetColoredChat(client, coloredchat);
    }

    else
    {
        // No args.  Show help.
        GetClientCookie(client, g_hCookieCodChat, coloredchat, sizeof(coloredchat));
        ReplyToCommand(client, "-------- CURRENT --------");
        ReplyToCommand(client, "Your current chat color: %s", coloredchat);
        ReplyToCommand(client, "-------- USAGE ----------");
        ReplyToCommand(client, "sm_coloredchat \"Chat color here\" - Sets your chat color");
        ReplyToCommand(client, "sm_coloredname \"\" - Disables your chat color");
        ReplyToCommand(client, "-------- COLORS ---------");

        if (g_iGame == GAMETYPE_CSGO)
            ReplyToCommand(client, "team, olive, green, darkgreen, palered, red, grey");

        else
            ReplyToCommand(client, "visit http://hellsgamers.com/topic/77728-colored-names/ for the list of colors");
    }

    return Plugin_Handled;
}

public Action:Command_SetColoredName(client, args)
{
    if (!ClrNms_CanUseFromJB(client) &&
        !IsAuthed(client, "Custom Colored Names"))
    {
        if (client != 0)
            PrintToChat(client,
                        "%s But you can see a list of current players colorednames by typing \x03sm_colorednames\x04 in console",
                        MSG_PREFIX);

        return Plugin_Handled;
    }

    if (!g_bClientHasItem[client][Item_ColoredName] &&
        !g_bEnabledByJB[client])
    {
        PrintToChat(client,
                    "%s You do not own \x03Colored Names",
                    MSG_PREFIX);

        PrintToChat(client,
                    "%s You can purchase it by typing \x03!shop",
                    MSG_PREFIX);

        return Plugin_Handled;
    }

    decl String:coloredname[LEN_NAMES];
    if(args)
    {
        // Get the name they specified from the argument.
        GetCmdArgString(coloredname, sizeof(coloredname));
        StripQuotes(coloredname);

        SetClientCookie(client, g_hCookieCodName, coloredname);
        ReplyToCommand(client, "Colored name set");

        SetColoredName(client, coloredname);
    }

    else
    {
        // No args.  Show help.
        GetClientCookie(client, g_hCookieCodName, coloredname, sizeof(coloredname));
        ReplyToCommand(client, "-------- CURRENT --------");
        ReplyToCommand(client, "Your current colored chat name: %s", coloredname);
        ReplyToCommand(client, "-------- USAGE ----------");
        ReplyToCommand(client, "sm_coloredname \"colored name here\" - Sets your colored name (QUOTES REQUIRED)");
        ReplyToCommand(client, "sm_coloredname \"\" - Disables your colored name");
        ReplyToCommand(client, "sm_colorednames - Displays people's real names");
        ReplyToCommand(client, "-------- COLORS ---------");
        ReplyToCommand(client, "^1, ^2, ^3, ^4, ^5, ^6, ^7, ^8");
        ReplyToCommand(client, "visit http://hellsgamers.com/topic/77728-colored-names/ for more info");
    }

    return Plugin_Handled;
}

public Action:OnSay(client, const String:text[], maxlength)
{
    return OnSayEx(client, text, true);
}

public Action:OnSayTeam(client, const String:text[], maxlength)
{
    return OnSayEx(client, text, true);
}

public OnSayPost(client, const String:text[], maxlength)
{
    OnSayPostEx(client, text, false);
}

public OnSayTeamPost(client, const String:text[], maxlength)
{
    OnSayPostEx(client, text, true);
}

public Action:OnSayEx(client, const String:text[], bool:teamonly)
{
    if (GetFeatureStatus(FeatureType_Native, "HG_IsClientGagged") == FeatureStatus_Available &&
        HG_IsClientGagged(client))
        return Plugin_Stop;

    if ((!g_bClientEquippedItem[client][Item_ColoredName] &&
         !g_bEnabledByJB[client]) ||
        g_bClientEquippedItem[client][Item_StealthMode])
    {
        if (g_iGame == GAMETYPE_CSGO && ShouldApplyColoredName(client, true))
            return Plugin_Handled;

        return Plugin_Continue;
    }

    return Plugin_Handled;
}

public Action:OnSayPostEx(client, const String:text[], bool:teamonly)
{
    if (g_iGame == GAMETYPE_CSGO)
    {
        LogChatToConsole(client, text, teamonly);
    }

    if ((!g_bClientEquippedItem[client][Item_ColoredName] &&
         !g_bEnabledByJB[client]) ||
        g_bClientEquippedItem[client][Item_StealthMode])
    {
        if (g_iGame == GAMETYPE_CSGO)
            ApplyColoredName(client, text, teamonly, true);
    }

    else
    {
        ApplyColoredName(client, text, teamonly);
    }
}


// ###################### FUNCTIONS ######################

bool:Chat_IsPlayerAlive(client)
{
    if (GetFeatureStatus(FeatureType_Native, "JB_IsPlayerAlive") == FeatureStatus_Available)
        return JB_IsPlayerAlive(client);
    return IsPlayerAlive(client);
}

stock DelayPrint(Float:delay, client, const String:message[], any:...)
{
    decl String:formatted[LEN_MESSAGES];
    VFormat(formatted, sizeof(formatted), message, 4);

    new Handle:hData = CreateDataPack();

    WritePackCell(hData, client);
    WritePackString(hData, formatted);

    CreateTimer(delay, Timer_DelayPrint, hData);
}

public Action:Timer_DelayPrint(Handle:timer, any:hData)
{
    ResetPack(hData);
    new client = ReadPackCell(hData);

    decl String:message[LEN_MESSAGES];
    ReadPackString(hData, message, sizeof(message));

    if (IsClientInGame(client))
        PrintToConsole(client, message);

    CloseHandle(hData);
}

stock LogChatToConsole(client, const String:text[], bool:teamonly)
{
    // Player chat doesn't show up in CS:GO console
    if ((Chat_IsPlayerAlive(client) || g_bDeadTalk) && !teamonly)
    {
        PrintToConsoleAll("%N: %s", client, text);
    }

    else if ((Chat_IsPlayerAlive(client) || g_bDeadTalk) && teamonly)
    {
        new targetTeam = GetClientTeam(client);

        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && GetClientTeam(i) == targetTeam)
            {
                PrintToConsole(i, "%N: %s", client, text);
            }
        }
    }

    else if (teamonly)
    {
        new targetTeam = GetClientTeam(client);

        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !Chat_IsPlayerAlive(i) && GetClientTeam(i) == targetTeam)
            {
                PrintToConsole(i, "*DEAD TEAM* %N: %s", client, text);
            }
        }
    }

    else
    {
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !Chat_IsPlayerAlive(i))
            {
                PrintToConsole(i, "*DEAD* %N: %s", client, text);
            }
        }
    }
}

bool:ShouldApplyColoredName(client, normalplayer)
{
    if (StrEqual(g_sColoredNames[client], "") &&
            !g_bClientEquippedItem[client][Item_ColoredChat] &&
            !normalplayer)
            return false;

    return true;
}

stock ApplyColoredName(client, const String:text[], bool:teamonly, bool:normalplayer=false)
{
    new bits = GetUserFlagBits(client);
    new team = GetClientTeam(client);
    new bool:isalive = Chat_IsPlayerAlive(client);

    decl String:display[LEN_MESSAGES];
    decl String:teamcolor[4];

    display[0] = '\0';
    GetTeamColor(team, teamcolor, sizeof(teamcolor));

    if (!normalplayer &&
        !bits &&
        g_bEnabledByJB[client] && 
        !g_bClientEquippedItem[client][Item_ColoredName])
        Format(display, sizeof(display), "\x01\x03[%srep:%d\x03] ", teamcolor, PrisonRep_GetPoints(client));

    else if ((bits & ADMFLAG_KICK || bits & ADMFLAG_ROOT) &&
             !g_bClientEquippedItem[client][Item_StealthMode])
        Format(display, sizeof(display), "\x01\x03[%sadmin\x03] ", teamcolor);

    else if (bits && !g_bClientEquippedItem[client][Item_StealthMode])
        Format(display, sizeof(display), "\x01\x03[%sVIP\x03] ", teamcolor);

    else if (normalplayer)
    {
        if (g_iGame == GAMETYPE_CSGO)
            Format(display, sizeof(display), "\x01 \x03");

        else
            Format(display, sizeof(display), "\x03");
    }

    if (team <= TEAM_SPEC && !teamonly)
        StrCat(display, sizeof(display), "*SPEC* ");

    if (team > TEAM_SPEC && !isalive)
        StrCat(display, sizeof(display), "*DEAD* ");

    if (teamonly)
    {
        switch(team)
        {
            case TEAM_T:
                StrCat(display, sizeof(display), "(Terrorist) ");

            case TEAM_CT:
                StrCat(display, sizeof(display), "(Counter-Terrorist) ");

            default:
                StrCat(display, sizeof(display), "(Spectator) ");
        }
    }

    decl String:nomocolo[LEN_MESSAGES];
    Format(nomocolo, sizeof(nomocolo), text);

    ReplaceString(nomocolo, sizeof(nomocolo), "\x01", "");
    ReplaceString(nomocolo, sizeof(nomocolo), "\x02", "");
    ReplaceString(nomocolo, sizeof(nomocolo), "\x03", "");
    ReplaceString(nomocolo, sizeof(nomocolo), "\x04", "");
    ReplaceString(nomocolo, sizeof(nomocolo), "\x05", "");
    ReplaceString(nomocolo, sizeof(nomocolo), "\x06", "");
    ReplaceString(nomocolo, sizeof(nomocolo), "\x07", "");
    ReplaceString(nomocolo, sizeof(nomocolo), "\x08", "");

    if (normalplayer)
    {
        decl String:clientname[MAX_NAME_LENGTH + 5];
        Format(clientname, sizeof(clientname), "\x03%N", client);

        ReplaceString(clientname, sizeof(clientname), "\x01", "");
        ReplaceString(clientname, sizeof(clientname), "\x02", "");
        ReplaceString(clientname, sizeof(clientname), "\x04", "");
        ReplaceString(clientname, sizeof(clientname), "\x05", "");
        ReplaceString(clientname, sizeof(clientname), "\x06", "");
        ReplaceString(clientname, sizeof(clientname), "\x07", "");
        ReplaceString(clientname, sizeof(clientname), "\x08", "");

        StrCat(display, sizeof(display), clientname);
    }

    else if (g_sColoredNames[client][0] == '\0')
    {
        decl String:clientname[MAX_NAME_LENGTH + 5];
        Format(clientname, sizeof(clientname), "\x03%N", client);

        StrCat(display, sizeof(display), clientname);
    }

    else
        StrCat(display, sizeof(display), g_sColoredNames[client]);

    StrCat(display, sizeof(display), "\x01: ");

    if (!g_bClientEquippedItem[client][Item_StealthMode])
    {
        if (GetUserFlagBits(client) & ADMFLAG_ROOT &&
            g_sColoredChat[client][0] != '\0')
            StrCat(display, sizeof(display), g_sColoredChat[client]);

        else if (g_bClientEquippedItem[client][Item_ColoredChat])
            StrCat(display, sizeof(display), teamcolor);
    }

    StrCat(display, sizeof(display), nomocolo);

    new author = client;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            if (isalive || g_bDeadTalk || !Chat_IsPlayerAlive(i))
            {
                if (!teamonly || GetClientTeam(i) == team)
                {
                    SayText2(i, author, display);
                }
            }
        }
    }

    WriteChatLog(client, teamonly ? "say_team" : "say", text);
}

stock SetColoredChat(client, const String:color[])
{
    if (!client || !IsAuthed(client, "Team Colored Chat"))
        return;

    new String:newcolor[MAX_NAME_LENGTH];

    if (g_iGame == GAMETYPE_CSGO)
    {
        if (StrEqual(color, "white"))
            Format(newcolor, sizeof(newcolor), "\x01");

        else if (StrEqual(color, "red"))
            Format(newcolor, sizeof(newcolor), "\x02");

        else if (StrEqual(color, "team"))
            Format(newcolor, sizeof(newcolor), "\x03");

        else if (StrEqual(color, "green"))
            Format(newcolor, sizeof(newcolor), "\x04");

        else if (StrEqual(color, "olive"))
            Format(newcolor, sizeof(newcolor), "\x05");

        else if (StrEqual(color, "darkgreen"))
            Format(newcolor, sizeof(newcolor), "\x06");

        else if (StrEqual(color, "palered"))
            Format(newcolor, sizeof(newcolor), "\x07");

        else if (StrEqual(color, "grey"))
            Format(newcolor, sizeof(newcolor), "\x08");
    }

    else
    {
        new color_hex;
        CCheckTrie();

        if (GetTrieValue(CTrie, color, color_hex))
            Format(newcolor, sizeof(newcolor), "\x07%06X", color_hex);

        else
            newcolor[0] = '\0';
    }

    Format(g_sColoredChat[client], MAX_NAME_LENGTH, newcolor);
}

stock SetColoredName(client, const String:name[])
{
    if (client &&
        !ClrNms_CanUseFromJB(client) &&
        !IsAuthed(client, "Custom Colored Names"))
    {
        PrintToChat(client,
                    "%s But you can see a list of current players colorednames by typing \x03sm_colorednames\x04 in console",
                    MSG_PREFIX);
        return;
    }

    decl String:newname[COLOREDNAME_MAX_LENGTH];
    strcopy(newname, sizeof(newname), name);

    new len = strlen(newname);

    if (len > 0)
    {
        if (newname[len - 1] < 10)
        {
            newname[len - 1] = 'w';
        }
    }

    if (len > 1)
    {
        if (newname[len - 2] < 10)
        {
            newname[len - 2] = 'w';
        }
    }

    ReplaceString(newname, sizeof(newname), "^1", "\x01");
    ReplaceString(newname, sizeof(newname), "^2", "\x02");
    ReplaceString(newname, sizeof(newname), "^3", "\x03");
    ReplaceString(newname, sizeof(newname), "^4", "\x04");
    ReplaceString(newname, sizeof(newname), "^5", "\x05");
    ReplaceString(newname, sizeof(newname), "^6", "\x06");

    if (g_iGame == GAMETYPE_CSGO)
    {
        ReplaceString(newname, sizeof(newname), "^7", "\x07");
        ReplaceString(newname, sizeof(newname), "^8", "\x08");
    }

    // They own colorednames, and not just from enough rep, so they can have the special colors.
    else if (g_bClientEquippedItem[client][Item_ColoredName])
    {
        CReplaceColorCodes(newname, client, false, COLOREDNAME_MAX_LENGTH);

        ReplaceString(newname[COLOREDNAME_MAX_LENGTH - 7], 7, "\x07", "");
        ReplaceString(newname[COLOREDNAME_MAX_LENGTH - 10], 10, "\x08", "");
    }

    else
    {
        ReplaceString(newname, sizeof(newname), "\x07", "");
        ReplaceString(newname, sizeof(newname), "\x08", "");
    }

    new length = strlen(newname);

    for (new i = 0; i < strlen(newname); i++)
    {
        if (newname[i] >= '\x01' &&
            newname[i] <= '\x06')
            length--;

        else if (newname[i] == '\x07' ||
                 newname[i] == '\x08')
        {
            if (g_iGame == GAMETYPE_CSGO)
                length--;

            else
                length -= 7;
        }
    }

    if (length > MAX_NAME_LENGTH)
        Format(g_sColoredNames[client], COLOREDNAME_MAX_LENGTH, "LOL MY NAME IS TOO LONG");

    else
        Format(g_sColoredNames[client], COLOREDNAME_MAX_LENGTH, newname);
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

stock WriteChatLog(client, const String:sayOrSayTeam[], const String:msg[])
{
    decl String:name[LEN_NAMES];
    decl String:steamid[LEN_STEAMIDS];
    decl String:teamName[10];

    GetClientName(client, name, LEN_NAMES);
    GetTeamName(GetClientTeam(client), teamName, sizeof(teamName));
    GetClientAuthString(client, steamid, sizeof(steamid));
    LogToGame("\"%s<%i><%s><%s>\" %s \"%s\"", name, GetClientUserId(client), steamid, teamName, sayOrSayTeam, msg);
}

stock GetTeamColor(team, String:color[], maxlength)
{
    if (g_iGame == GAMETYPE_CSGO)
    {
        switch (team)
        {
            case TEAM_T:
                Format(color, maxlength, "\x02");

            case TEAM_CT:
                Format(color, maxlength, "\x03");

            default:
                Format(color, maxlength, "\x08");
        }
    }

    else
        Format(color, maxlength, "\x03");
}
