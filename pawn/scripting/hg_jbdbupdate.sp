
// Includes.
#pragma semicolon 1
#include <sourcemod>

// Plugin definitions.
#define PLUGIN_NAME "hg_jbdbupdate"
#define PLUGIN_VERSION "0.0.1"
#define MSG_PREFIX "\x01[\x04HG DB UPDATE\x01]\x04"

// Common string lengths.
#define LEN_CONVARS 255
#define LEN_RECORDNAMES 64

#pragma semicolon 1
#include <sourcemod>

// Plugin display info.
public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "HeLLsGamers",
    description = "HG DB Update",
    version = PLUGIN_VERSION,
    url = "http://www.hellsgamers.com/"
};

// Imported functions.
#include "hg_jbdbupdate/common.sp"
#include "hg_jbdbupdate/db_connect.sp"
#include "hg_jbdbupdate/mapcoords.sp"

// ###################### EVENTS, FORWARDS, AND COMMANDS ######################

public OnPluginStart()
{
    // Initial connect to database.
    CreateTimer(0.5, DB_Connect);

    // Perform applicable tasks.
    MapCoords_OnPluginStart();
}

OnDbConnect_Main(Handle:conn)
{
    MapCoords_OnDbConnect(conn);
}
