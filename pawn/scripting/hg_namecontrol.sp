
// Includes.
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <regex>

// Plugin definitions.
#define PLUGIN_NAME "hg_namecontrol"
#define PLUGIN_VERSION "0.0.9"
#define MSG_PREFIX "\x01[\x04HG NAMECTRL\x01]\x04"

// Common string lengths.
#define LEN_STEAMIDS 24
#define LEN_CONVARS 255

// Team definitions.
#define TEAM_SPEC 1 // 1=spec, 2=t, 3=ct

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <regex>

// Name change spam trackers.
new String:g_sNames[MAXPLAYERS + 1][MAX_NAME_LENGTH];       // Array to store the name of each player when changes their name.
new g_iNameChangeCounts[MAXPLAYERS + 1];                    // Array to hold how many times each player changes their name.

// Plugin display info.
public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "HeLLsGamers",
    description = "HG Name Control",
    version = PLUGIN_VERSION,
    url = "http://www.hellsgamers.com/"
};

// Imported functions.
#include "hg_namecontrol/common.sp"
#include "hg_namecontrol/convars.sp"
#include "hg_namecontrol/chatfilter.sp"
#include "hg_namecontrol/db_connect.sp"
#include "hg_namecontrol/namecontrol.sp"

// ###################### EVENTS, FORWARDS, AND COMMANDS ######################

// Forward definitions for bad words.
/*
forward Action:OnSay(client, String:message[], maxlen);
forward Action:OnSayTeam(client, String:message[], maxlen);
*/

public OnPluginStart()
{
    // Create ConVars.
    Convars_OnPluginStart();
    AutoExecConfig(true);

    // Do common stock functions.
    CompileCommonRegexes();

    // Monitor commands.
    AddCommandListener(OnJoinTeam, "jointeam");

    // Applicable tasks.
    NameControl_OnPluginStart();
    ChatFilter_OnPluginStart();
}

public OnConfigsExecuted()
{
    // Initial connect to database.
    CreateTimer(0.5, DB_Connect);

    // Monitor name changes, so we can ban people who have a namechange script.
    CreateTimer(GetConVarFloat(g_hCvNameChangeSeconds), DecNameChangeCount, _, TIMER_REPEAT);

    // Read & hook various ConVars.
    NameControl_OnConfigsExecuted();
}

OnDbConnect_NC(Handle:conn)
{
    NameControl_OnDbConnect(conn);
    ChatFilter_OnDbConnect(conn);
}

public OnClientPutInServer(client)
{
    // Reset name spam tracking.
    g_sNames[client][0] = '\0';
    g_iNameChangeCounts[client] = 0;

    // Perform applicable tasks.
    NameControl_OnClientPutInServer(client);
}

public Action:OnJoinTeam(client, const String:command[], argc)
{
    // What team did the client join?
    decl String:info[7];
    GetCmdArg(1, info, sizeof(info));
    new team = StringToInt(info); // 0=autoassign, 1=spec, 2=prisoner, 3=guard

    // Allow if joining spec.
    if (team == TEAM_SPEC)
        return Plugin_Continue;

    // Applicable tasks.
    if (!NameControl_OnJoinTeam(client))
        return Plugin_Handled;

    return Plugin_Continue;
}

public OnClientSettingsChanged(client)
{
    // Ensure client is valid player.
    if (!IsClientInGame(client) || IsFakeClient(client))
        return;

    // Was the name changed?
    decl String:oldName[MAX_NAME_LENGTH];
    decl String:newName[MAX_NAME_LENGTH];
    Format(oldName, MAX_NAME_LENGTH, g_sNames[client]);
    GetClientName(client, newName, MAX_NAME_LENGTH);

    // The name did not change.  It must have been another setting that changed.
    if (strcmp(newName, oldName) == 0)
        return;

    // The name changed.  Keep track of the new name, so we know next time whether a name changed or not.
    Format(g_sNames[client], MAX_NAME_LENGTH, newName);

    // Track number of name changes.
    new numChanges = g_iNameChangeCounts[client] + 1;
    new nameChangeLimit = GetConVarInt(g_hCvNameChangeLimit);

    if (nameChangeLimit > 1)
    {
        if (numChanges > nameChangeLimit)
        {
            // Too many name changes.  Reset tracker and take action.
            g_iNameChangeCounts[client] = 0;

            // Put together reason.
            new Float:nameChangeTimespan = GetConVarFloat(g_hCvNameChangeSeconds);
            if (nameChangeTimespan > 10.0)
            {
                decl String:reason[LEN_CONVARS];
                Format(reason, LEN_CONVARS, "%i name changes in %i seconds", numChanges - 1, RoundToNearest(nameChangeTimespan));

                // Ban.
                ServerCommand("sm_ban #%d %f \"%s\"", GetClientUserId(client), 0.0, reason);
            }
            else
            {
                LogMessage("ERROR: nameChangeTimespan was %f", nameChangeTimespan);
            }
        }
        else
        {
            // Not too many changes yet, but keep tracking the number of changes.
            g_iNameChangeCounts[client] = numChanges;

            /******** SINCE HIS NAME CHANGED, CHECK IT ********/

            NameControl_OnNameChange(client);
        }
    }
    else
    {
        LogMessage("ERROR: nameChangeLimit was %i", nameChangeLimit);
    }
}

// Bad words filter.
/*
public Action:OnSay(client, String:message[], maxlen)
{
	new String:f_sTemp[128], f_iPos, bool:f_bWarn = false;
	for(new i=0;i<GetArraySize(g_hBadWords);i++)
	{
		GetArrayString(g_hBadWords, i, f_sTemp, sizeof(f_sTemp));
		f_iPos = StrContains(message, f_sTemp, false);
		if ( f_iPos != -1 )
		{
			f_bWarn = true;
			for(new t=f_iPos;t<f_iPos+strlen(f_sTemp);t++)
				message[t] = '*';
		}
	}
	if ( f_bWarn )
	{
		PrintToChat(client, "\x04Do not use foul language here. You have been warned!");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
public Action:OnSayTeam(client, String:message[], maxlen)
{
	new String:f_sTemp[128], f_iPos, bool:f_bWarn = false;
	for(new i=0;i<GetArraySize(g_hBadWords);i++)
	{
		GetArrayString(g_hBadWords, i, f_sTemp, sizeof(f_sTemp));
		f_iPos = StrContains(message, f_sTemp, false);
		if ( f_iPos != -1 )
		{
			f_bWarn = true;
			for(new t=f_iPos;t<f_iPos+strlen(f_sTemp);t++)
				message[t] = '*';
		}
	}
	if ( f_bWarn )
	{
		PrintToChat(client, "\x04Do not use foul language here. You have been warned!");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
*/

public Action:DecNameChangeCount(Handle:timer, any:data)
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (g_iNameChangeCounts[i] > 0)
            g_iNameChangeCounts[i] -= 1;
    }
    return Plugin_Continue;
}
