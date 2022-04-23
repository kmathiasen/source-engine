
// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

Db_OnPluginStart()
{
    // Is the database connection info provided in the config file?
    if(!SQL_CheckConfig(PLUGIN_NAME))
    {
        for(new i = 0; i < 3; i++)
            LogError("%s No entry \"%s\" in databases.cfg", MSG_PREFIX_NOFORMAT, PLUGIN_NAME);
        SetFailState("%s No entry \"%s\" in databases.cfg", MSG_PREFIX_NOFORMAT, PLUGIN_NAME);
    }

    // Connect to database.
    CreateTimer(UPDATE_FREQ, DB_CheckConnection, _, TIMER_REPEAT);
    DB_CheckConnection(INVALID_HANDLE);
}

// ####################################################################################
// ##################################### TIMERS #######################################
// ####################################################################################

public Action:DB_CheckConnection(Handle:timer)
{
    // If we were disconnected, try connecting again.
    if(g_hDbConn_Main == INVALID_HANDLE)
    {
        SQL_TConnect(Db_Connect_CB, PLUGIN_NAME);
        return Plugin_Continue;
    }

    // Yay it's still connected.  Call the DB successful tick event.
    OnDbTickSuccess(g_hDbConn_Main);

    // Exit while keeping repeating timer alive.
    return Plugin_Continue;
}

// ####################################################################################
// #################################### CALLBACKS #####################################
// ####################################################################################

public Db_Connect_CB(Handle:driver, Handle:conn, const String:error[], any:data)
{
    if(conn == INVALID_HANDLE)
    {
        Db_Disconnect(conn);
        LogError("%s Error connecting to the DB: %s", MSG_PREFIX_NOFORMAT, error);
        return;
    }

    /*** The database has been successfully connected to ***/

    // Ensure the global handle references the latest resource.
    // Remember, conn is a local reference to the database resource
    // and will go out of scope when this callback finishes.  We need
    // to clone it if we want to keep a valid reference to the resource.
    if(g_hDbConn_Main != INVALID_HANDLE)
        CloseHandle(g_hDbConn_Main);
    g_hDbConn_Main = CloneHandle(conn);

    // Call DB success event.
    OnDbTickSuccess(g_hDbConn_Main);
}

public EmptySqlCallback(Handle:conn, Handle:fetch, const String:error[], any:data)
{
    Db_QueryFailed(conn, fetch, error);
}

public Db_Disconnect(Handle:conn)
{
    if(conn != INVALID_HANDLE)
    {
        CloseHandle(conn);
        conn = INVALID_HANDLE;
    }
}

bool:Db_QueryFailed(Handle:conn, Handle:fetch, const String:error[])
{
    if(conn == INVALID_HANDLE || fetch == INVALID_HANDLE)
    {
        LogError(error);
        Db_Disconnect(conn);
        return true;
    }
    return false;
}
