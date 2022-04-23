// ###################### GLOBALS ######################

new Handle:g_hJoinMessage = INVALID_HANDLE;
new Handle:g_hJoinMessagesEnabled = INVALID_HANDLE;

new bool:g_bJoinMessageEnabled = true;
new bool:g_bAlreadyDisplayedMessage[MAXPLAYERS + 1];

// ###################### EVENTS ######################

stock JoinMessage_OnPluginStart()
{
    g_hJoinMessage = RegClientCookie("hg_items_join_message",
                                     "Custom Join Message", CookieAccess_Protected);

    g_hJoinMessagesEnabled = CreateConVar("hg_premium_join_messages_enabled",
                                          "1", "Enable/Disable custom join messages");

    HookConVarChange(g_hJoinMessagesEnabled, JoinMessage_OnConVarChanged);

    RegConsoleCmd("sm_joinmsg",
                  Command_JoinMessage, "Set your custom join message");

    RegConsoleCmd("sm_joinmessage",
                  Command_JoinMessage, "Set your custom join message");

    HookEvent("player_connect", JoinMessage_OnPlayerConnect, EventHookMode_Pre);
    HookEvent("player_disconnect", JoinMessage_OnPlayerDisconnect, EventHookMode_Pre);
}

stock JoinMessage_OnConfigsExecuted()
{
    g_bJoinMessageEnabled = GetConVarBool(g_hJoinMessagesEnabled);
}

public JoinMessage_OnConVarChanged(Handle:CVar, const String:oldv[], const String:newv[])
{
    if (CVar == g_hJoinMessagesEnabled)
        g_bJoinMessageEnabled = GetConVarBool(g_hJoinMessagesEnabled);
}

stock JoinMessage_OnClientPutInServer(client)
{
    g_bAlreadyDisplayedMessage[client] = false;
}

stock JoinMessage_OnClientFullyAuthorized(client)
{
    if (GetUserFlagBits(client))
        return;

    DisplayConnectInfo(client);
}

stock JoinMessage_DisplayAdminMessage(client)
{
    if (g_bJoinMessageEnabled &&
        g_bClientEquippedItem[client][Item_JoinMessage] &&
        !g_bClientEquippedItem[client][Item_StealthMode])
    {
        decl String:message[LEN_JOINMESSAGES];
        GetClientCookie(client, g_hJoinMessage, message, sizeof(message));

        if (!StrEqual(message, ""))
        {
            DisplayConnectInfo(client, message);
            return;
        }
    }

    DisplayConnectInfo(client);
}

// Following two functions copied from "Connect Announce" by "Arg!"
public Action:JoinMessage_OnPlayerConnect(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!dontBroadcast)
    {
        decl String:clientName[33], String:networkID[22], String:address[32];
        GetEventString(event, "name", clientName, sizeof(clientName));
        GetEventString(event, "networkid", networkID, sizeof(networkID));
        GetEventString(event, "address", address, sizeof(address));

        new Handle:newEvent = CreateEvent("player_connect", true);
        SetEventString(newEvent, "name", clientName);
        SetEventInt(newEvent, "index", GetEventInt(event, "index"));
        SetEventInt(newEvent, "userid", GetEventInt(event, "userid"));
        SetEventString(newEvent, "networkid", networkID);
        SetEventString(newEvent, "address", address);

        FireEvent(newEvent, true);

        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action:JoinMessage_OnPlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!dontBroadcast)
    {
        decl String:clientName[MAX_NAME_LENGTH], String:networkID[LEN_STEAMIDS], String:reason[LEN_JOINMESSAGES];
        GetEventString(event, "name", clientName, sizeof(clientName));
        GetEventString(event, "networkid", networkID, sizeof(networkID));
        GetEventString(event, "reason", reason, sizeof(reason));

        new Handle:newEvent = CreateEvent("player_disconnect", true);
        SetEventInt(newEvent, "userid", GetEventInt(event, "userid"));
        SetEventString(newEvent, "reason", reason);
        SetEventString(newEvent, "name", clientName);        
        SetEventString(newEvent, "networkid", networkID);

        FireEvent(newEvent, true);

        PrintToChatAll("\x01Player \x04%s \x01[\x03%s\x01] disconnected \"\x04%s\x01\"",
                       clientName, networkID, reason);

        return Plugin_Handled;
    }

    return Plugin_Continue;
}

// ###################### CALLBACKS ######################


public Action:Command_JoinMessage(client, args)
{
    if (!IsAuthed(client))
        return Plugin_Handled;

    if (!g_bClientHasItem[client][Item_JoinMessage])
    {
        PrintToChat(client,
                    "%s You do not own this item, type !shop to purchase it.",
                    MSG_PREFIX);
        return Plugin_Handled;
    }

    if (!args)
    {
        decl String:message[LEN_JOINMESSAGES];
        GetClientCookie(client, g_hJoinMessage, message, sizeof(message));

        if (g_bClientEquippedItem[client][Item_JoinMessage])
            PrintToChat(client,
                        "%s Your \x03Join Message \x04is currently \x03Equipped",
                        MSG_PREFIX);

        else
            PrintToChat(client,
                        "%s Your \x03Join Message \x04is currently \x03Disabled",
                        MSG_PREFIX);

        PrintToChat(client,
                    "%s Your \x03Join Message\x04 is set to \"\x03%s\x04\"",
                    MSG_PREFIX, message);
        return Plugin_Handled;
    }

    decl String:message[LEN_JOINMESSAGES];
    GetCmdArgString(message, sizeof(message));

    StripQuotes(message);
    SetClientCookie(client, g_hJoinMessage, message);

    PrintToChat(client,
                "%s Your \x03Join Message\x04 has been set to \"\x03%s\x04\"",
                MSG_PREFIX, message);
    return Plugin_Handled;
}


// ###################### FUNCTIONS ######################


stock DisplayConnectInfo(client, const String:message[]="")
{
    if (g_bAlreadyDisplayedMessage[client])
        return;

    decl String:display[LEN_MESSAGES + 10];
    new String:steamid[LEN_STEAMIDS];

    GetClientAuthString2(client, steamid, sizeof(steamid));

    if (StrEqual(message, ""))
        Format(display, sizeof(display),
               "\x01Player \x04%N \x01[\x03%s\x01] connected",
               client, steamid);

    else
        Format(display, sizeof(display),
               "\x01Player \x04%N \x01[\x03%s\x01] connected \"\x05%s\x01\"",
               client, steamid, message);

    PrintToChatAll(display);
    g_bAlreadyDisplayedMessage[client] = true;
}
