/*  DESCRIPTION:
        This file has all the things that happen to connect/reconnect to the database.
        The first sub here, DB_Connect(), is called on a timer by OnConfigsExecuted().
        Each sub in this file essentially calls the next one down.  It basically goes
        from top to bottom, one after another.  The first thing that happens is in here
        is the global handle to the DB connection, g_hDbConn, is invalidated.  This
        means that while this reconnect action is going on, no subs can look up anything
        from the DB.  If there is a problem anywhere in these subs, the plugin will stay
        in an unconnected state until the timer ticks again and we give it another try.
        On the other hand, if it gets to the end, then g_hDbConn is assigned a valid
        connection handle and we're good to go.
*/

new Handle:g_hConnectingTimer = INVALID_HANDLE;

public Action:DB_Connect(Handle:timer)
{
    g_hConnectingTimer = INVALID_HANDLE;

    // Invalidate DB handle.
    if(g_hDbConn != INVALID_HANDLE)
    {
        CloseHandle(g_hDbConn);
        g_hDbConn = INVALID_HANDLE;
    }

    // Was this server setup with the proper config?
    if(!SQL_CheckConfig(PLUGIN_NAME))
    {
        LogMessage("ERROR: There is no entry for %s in databases.cfg", PLUGIN_NAME);
        return Plugin_Stop;
    }

    // Connect to database.
    if(g_bCvarVerbose) LogMessage("Connecting to database...");
    SQL_TConnect(DB_Connect_Finish, PLUGIN_NAME);
    return Plugin_Continue;
}

public DB_Connect_Finish(Handle:driver, Handle:conn, const String:error[], any:data)
{
    g_hConnectingTimer = INVALID_HANDLE;

    // Exit if unsuccessful.
    if(conn == INVALID_HANDLE)
    {
        LogMessage("ERROR IN DB_Connect_Finish: Could not connect: %s", error);

        g_hConnectingTimer = CreateTimer(g_fCvarUpdateFrequency, DB_Connect);
        return;
    }
    
    g_hDbConn = CloneHandle(conn);

    // Do shit.
    OnDBConnect();
}


/* ----- Functions ----- */


bool:CheckConnection(Handle:hndl, const String:error[])
{
    if (hndl == INVALID_HANDLE)
    {
        if (!StrEqual(error, ""))
            LogError(error);

        if (g_hConnectingTimer == INVALID_HANDLE)
            g_hConnectingTimer = CreateTimer(g_fCvarUpdateFrequency, DB_Connect);

        return false;
    }

    return true;
}

bool:DatabaseFailure(client)
{
    if (g_hConnectingTimer != INVALID_HANDLE)
    {
        PrintToChat(client,
                    "%s It seems like there has been some issue connected to the database...",
                    MSG_PREFIX);

        PrintToChat(client, "%s Please try again soon", MSG_PREFIX);
        return true;
    }

    return false;
}
