#pragma semicolon 1

#include <sdktools>

// Team definitions.
#define TEAM_UNASSIGNED 0
#define TEAM_SPEC 1
#define TEAM_PRISONERS 2
#define TEAM_GUARDS 3

// Other constants.
#define MAX_NUM_PHRASES 192
#define LEN_PHRASE 256
#define TIMER_DELAY 5.0

new g_iDays[MAXPLAYERS + 1];
new g_iPhraseCount;
new String:g_sPhrases[MAX_NUM_PHRASES][LEN_PHRASE];

public Plugin:myinfo =
{
    name = "SM Jailed Reasons",
    author = "Franc1sco steam: franug",
    description = "Shows the reasons for incarceration",
    version = "v1.hg",
    url = "http://servers-cfg.foroactivo.com/"
};

public OnPluginStart()
{
    HookEvent("round_end", OnRoundEnd);
    HookEvent("player_spawn", OnPlayerSpawn);
    g_iPhraseCount = BuildPhrases();
}

public OnClientPostAdminCheck(client)
{
    g_iDays[client] = 1;
}

public Action:OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    for(new i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i))
            g_iDays[i] += 1;
    }
}

public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new userid = GetEventInt(event, "userid");
    new client = GetClientOfUserId(userid);
    if(client > 0 &&
       IsClientInGame(client) &&
       IsPlayerAlive(client) &&
       GetClientTeam(client) == TEAM_PRISONERS)
    {
        CreateTimer(TIMER_DELAY, ShowDelayedMessage, userid);
    }
}

BuildPhrases()
{
    decl String:fullFileName[PLATFORM_MAX_PATH];
    decl String:line[LEN_PHRASE];
    new i;

    BuildPath(Path_SM, fullFileName, sizeof(fullFileName), "configs/franug_days_jail.ini");
    new Handle:file = OpenFile(fullFileName, "rt");
    if(file != INVALID_HANDLE)
    {
        while(!IsEndOfFile(file))
        {
            if(!ReadFileLine(file, line, sizeof(line)))
                break;

            TrimString(line);
            if(strlen(line))
            {
                Format(g_sPhrases[i], LEN_PHRASE, "%s", line);
                i++;
            }

            //Ensure we don't try to write to many strings into the buffer.
            if(i >= MAX_NUM_PHRASES)
            {
                LogMessage("There are more phrases in the file [%s] than the internal limit of %i.  Please edit the script and raise the limit.",
                           fullFileName,
                           MAX_NUM_PHRASES);
                break;
            }
        }
        CloseHandle(file);
    }
    else
        SetFailState("ERROR: No phrase file found at [%s]", fullFileName);

    return i; // This is the num of phrases in the buffer.
}

public Action:ShowDelayedMessage(Handle:timer, any:data)
{
    new client = GetClientOfUserId(_:data);
    if(client > 0 &&
       IsClientInGame(client) &&
       IsPlayerAlive(client) &&
       GetClientTeam(client) == TEAM_PRISONERS)
    {
        // Get random phrase.
        new phraseToUse = GetRandomInt(0, g_iPhraseCount -1);
        decl String:phrase[LEN_PHRASE];
        Format(phrase, sizeof(phrase), "%s", g_sPhrases[phraseToUse]);

        // Display phrase.
        PrintCenterText(client, "Day %i: %s", g_iDays[client], phrase);
        PrintHintText(client, "Day %i: %s", g_iDays[client],phrase);
    }
    return Plugin_Stop;
}
