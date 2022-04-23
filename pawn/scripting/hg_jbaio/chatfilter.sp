
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Constants.
#define LEN_BADWORDS 64

// Array to hold bad chat words queried from the DB.
new Handle:g_hBadWords = INVALID_HANDLE;

// ####################################################################################
// ####################################### EVENTS #####################################
// ####################################################################################

ChatFilter_OnPluginStart()
{
    g_hBadWords = CreateArray(LEN_BADWORDS);
}

ChatFilter_OnDbConnect(Handle:conn)
{
    // Clear any existing bad chat words.
    ClearArray(g_hBadWords);

    // Create and execute SQL statement to get bad chat words.
    decl String:q[256];
    Format(q, sizeof(q), "SELECT LEFT(badword, %i) FROM badwords", (LEN_BADWORDS - 1));
    SQL_TQuery(conn, ChatFilter_GetBadWords_CB, q, _);
}

// ####################################################################################
// ################################## SQL CALLBACKS ###################################
// ####################################################################################

public ChatFilter_GetBadWords_CB(Handle:conn, Handle:fetch, const String:error[], any:data)
{
    // Did it fail?
    if (Db_QueryFailed(conn, fetch, error, 9))
    {
        LogMessage("ERROR in ChatFilter_GetBadWords_CB");
        return;
    }

    // Did the DB return results?
    if (SQL_GetRowCount(fetch) <= 0)
    {
        LogMessage("NOTICE: No bad chat words returned from DB");
    }
    else
    {
        // Holders.
        decl String:badword[LEN_BADWORDS];

        // Get results.
        while(SQL_FetchRow(fetch))
        {
            // Grab [badword].
            SQL_FetchString(fetch, 0, badword, sizeof(badword));

            // Insert into Trie(s).
            PushArrayString(g_hBadWords, badword);
        }
    }
}
