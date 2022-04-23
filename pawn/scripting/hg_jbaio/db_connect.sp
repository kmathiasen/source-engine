
/*  DESCRIPTION:

        This file has all the things that happen to connect/reconnect to the database.

        The first func here, DB_Connect(), it's called in:
            OnConfigsExecuted()
            The next game frame after LR occurs.
        This means that the best time to reload the plugin using "sm plugins reload hg_jbaio" is a few seconds after LR.
            That way, nobody's rep will be lost and players will have minimal disruption to gameplay (they may not even notice).

*/

// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

#define UPDATE_FREQ 300.0
#define DATABASENAME_MAIN PLUGIN_NAME
#define DATABASENAME_BANS "hg_bans"
#define DATABASENAME_NC "hg_namecontrol"

new Handle:g_hDbConn_Main = INVALID_HANDLE;
new Handle:g_hDbConn_Bans = INVALID_HANDLE;
new Handle:g_hDbConn_NC = INVALID_HANDLE;

new Handle:g_hReconnectionTimer = INVALID_HANDLE;
new bool:g_bConnectedThisRound = false;

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

DB_OnRndStrt_General()
{
    g_bConnectedThisRound = false;
}

// ####################################################################################
// ##################################### FUNCTIONS ####################################
// ####################################################################################

public Action:DB_Connect(Handle:timer)
{
    // Don't connect twice in a round.
    if (g_bConnectedThisRound)
        return Plugin_Continue;
    else
        g_bConnectedThisRound = true;

    // Invalidate DB handle(s).
    if (g_hDbConn_Main != INVALID_HANDLE)
    {
        CloseHandle(g_hDbConn_Main);
        g_hDbConn_Main = INVALID_HANDLE;
    }
    if (g_hDbConn_NC != INVALID_HANDLE)
    {
        CloseHandle(g_hDbConn_NC);
        g_hDbConn_NC = INVALID_HANDLE;
    }
    if (g_hDbConn_Bans != INVALID_HANDLE)
    {
        CloseHandle(g_hDbConn_Bans);
        g_hDbConn_Bans = INVALID_HANDLE;
    }

    // Was this server setup with the proper config(s)?
    if (!SQL_CheckConfig(DATABASENAME_MAIN))
    {
        SetFailState("ERROR: There is no entry for %s in databases.cfg", DATABASENAME_MAIN);
        return Plugin_Stop;
    }
    if (!SQL_CheckConfig(DATABASENAME_BANS))
    {
        SetFailState("ERROR: There is no entry for %s in databases.cfg", DATABASENAME_BANS);
        return Plugin_Stop;
    }
    if (!SQL_CheckConfig(DATABASENAME_NC))
    {
        SetFailState("ERROR: There is no entry for %s in databases.cfg", DATABASENAME_NC);
        return Plugin_Stop;
    }

    // Connect to databases.
    LogMessage("Connecting to database(s)...");
    SQL_TConnect(DB_Connect_Main_CB, DATABASENAME_MAIN);
    SQL_TConnect(DB_Connect_Bans_CB, DATABASENAME_BANS);
    SQL_TConnect(DB_Connect_NC_CB, DATABASENAME_NC);

    // Setup repeating database disconnections & reconnections.
    if (g_hReconnectionTimer == INVALID_HANDLE)
        g_hReconnectionTimer = CreateTimer(UPDATE_FREQ, DB_Connect, _, TIMER_REPEAT);
    return Plugin_Continue;
}

// ####################################################################################
// ################################## SQL CALLBACKS ###################################
// ####################################################################################

public DB_Connect_Main_CB(Handle:driver, Handle:conn, const String:error[], any:data)
{
    if (conn == INVALID_HANDLE)
    {
        LogMessage("ERROR in DB_Connect_NC_Finish: %s", error);
        return;
    }
    LogMessage("Successfully connected to [%s] database!", DATABASENAME_MAIN);
    g_hDbConn_Main = CloneHandle(conn);
    OnDbConnect_Main(g_hDbConn_Main);
}

public DB_Connect_Bans_CB(Handle:driver, Handle:conn, const String:error[], any:data)
{
    if (conn == INVALID_HANDLE)
    {
        LogMessage("ERROR in DB_Connect_NC_Finish: %s", error);
        return;
    }

    LogMessage("Successfully connected to [%s] database!", DATABASENAME_BANS);
    g_hDbConn_Bans = CloneHandle(conn);
    OnDbConnect_Bans(g_hDbConn_Bans);
}

public DB_Connect_NC_CB(Handle:driver, Handle:conn, const String:error[], any:data)
{
    if (conn == INVALID_HANDLE)
    {
        LogMessage("ERROR in DB_Connect_NC_Finish: %s", error);
        return;
    }
    LogMessage("Successfully connected to [%s] database!", DATABASENAME_NC);
    g_hDbConn_NC = CloneHandle(conn);
    OnDbConnect_NC(g_hDbConn_NC);
}
