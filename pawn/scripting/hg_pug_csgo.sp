#include <sourcemod>
#include <socket>
#include <cstrike>
#include <sdktools>
#include <sdktools_functions>
#include <sdkhooks>
#include <protobuf>

// Plugin Info
#define PLUGIN_VERSION "1.0.0.9"

// Updater
#define UPDATE_FILE "hg_pug_csgo"

#include "lib/updater.sp"
// End of Updater

#define MSG_PREFIX "[HG Pug]"

#if defined MAXPLAYERS
    #undef MAXPLAYERS
    #define MAXPLAYERS 64
#endif

new Handle:hTVEnabled;
new Handle:hmeta;
new Handle:hsm;
new Handle:hpug;
new Handle:hnmap;
new String:GameName[256];
new String:GameCSS[256];
new String:GameCSGO[256];
new Handle:RestartTimers = INVALID_HANDLE;
new Handle:hMaxPlayers;
new Handle:hTournamentMode;
new Handle:hHostname;
new Handle:hHintSound;
new Handle:hFlashBangLimit;
new Handle:hSpecSlotLimit;
new Handle:hStartMoney;

#define MAX_PLAYERS_DEFAULT "10"
new OffsetAccount; // MONEY OFFSET
new bool:bPubChatMuted[MAXPLAYERS+1]=false;
new bool:bTeamChatMuted[MAXPLAYERS+1]=false;
new bool:bMuted[MAXPLAYERS+1][MAXPLAYERS+1];
new Float:fLastMessage[MAXPLAYERS+1];
new bool:bAuthed[MAXPLAYERS+1];
new Handle:hBotQuota = INVALID_HANDLE;

new Handle:g_MapList = INVALID_HANDLE;
new g_mapFileSerial = -1;

// Current match stuff
enum MatchState
{
    MS_Pre_Setup = 0,
    MS_Setup,
    MS_Setup_Pre_Captain_Round,
    MS_Setup_Live_Captain_Round,          // used for live captain round only
    MS_Setup_Post_Captain_Round, // used for after we have winning captain, another ready time while they pick players
    MS_Before_First_Half, // This is only used if the map changes.
    MS_Live_First_Half,
    MS_Before_Second_Half, // Always used.
    MS_Live_Second_Half,
    MS_Vote_Overtime,
    MS_Before_Overtime_First_Half,
    MS_Live_Overtime_First_Half,
    MS_Before_Overtime_Second_Half,
    MS_Live_Overtime_Second_Half,
    MS_Post_Match,
};

new MatchState:gMatchState = MS_Pre_Setup;
new TeamAScore; // Team A goes CT first.
new TeamBScore; // Team B goes T first.
// Keep in mind team A and B are always randomized / captains.
// In the case of captains, it is still random which captains will be on which team, A or B.
new CurrentRound = 0;
new bool:bFreezeTimeEnded = false;
new String:MatchMap[32] = ""; // Map name.
enum RuleType
{
    Rules_PUG = 0,
    Rules_CGS,
};
new RuleType:Ruleset = Rules_PUG;
#define ROUNDS_HALF_PUG 15
#define ROUNDS_HALF_CGS 11
#define ROUNDS_OVERTIME_HALF_PUG 3
#define ROUNDS_OVERTIME_HALF_CGS 3  
#define MAX_ROUNDS 50 // We won't exceed 50 rounds for now.
new Handle:hMatchDamage[MAX_ROUNDS]; // Vector of all the damage.
new Handle:hMatchKills[MAX_ROUNDS]; // Vector of all the kills.
new bool:TournamentMode = false; // removed captain and ramdom team voting. locks players to their team after readyup. lets them map vote.
new bool:CaptainMode = false;
new bool:RandomizerMode = false;
new bool:BunnyHopMode = false;
new bool:KnifeOnly = false; // for knifeonly round enforcement
new KnifeWinner;  // placeholder for captain
new KnifeWinner2; // placeholder for second captain
new CaptainTeam;
new ownerOffset;
new g_iDelayStart = 0;
#define MAX_MAPS 50 // For now.
new String:MapNames[MAX_MAPS][32]; // Loaded OnPluginStart()
#define TEAM_A 0
#define TEAM_B 1
#define TEAM_COUNT 2
#define TEAM_CAPTAIN 0
new String:TeamPlayers[TEAM_COUNT][5][24]; // Steam ID's. Cached before map change.
new String:TeamPlayersMoney[TEAM_COUNT][5][5]; // for leave money storage
new bool:RoundCounterOn = false;
#define CS_TEAM_T 2
#define CS_TEAM_CT 3
#define CS_TEAM_SPEC 1
#define CS_TEAM_AUTO 0

//Clients
new bool:bReady[MAXPLAYERS+1];
new String:clientUsername[MAXPLAYERS+1][24];
new readyUpTime[MAXPLAYERS+1];
new notReadyTime[MAXPLAYERS+1];
new bool:FirstSpawn[MAXPLAYERS+1] = true;
new bool:AutoDmg[MAXPLAYERS+1] = false;
new bool:bDisconnecting[MAXPLAYERS+1] = true;
new bool:ForceSpec[MAXPLAYERS+1] = false;

// SourceMod Plugin Info
public Plugin:myinfo =
{
    name = "HGPug - Pug Mod / Tournament Mod",
    author = "HeLLsGamers",
    description = "Match Mod for CS:S and CS:GO",
    version = PLUGIN_VERSION,
    url = "http://www.hellsgamers.com/"
};

OnAllReady()
{
/*
enum MatchState
{
    MS_Pre_Setup = 0,
    MS_Setup,
    MS_Setup_Live_Captain_Round,          // used for live captain round only
    MS_Setup_Post_Captain_Round,
    MS_Before_First_Half, // This is only used if the map changes.
    MS_Live_First_Half,
    MS_Before_Second_Half, // Always used.
    MS_Live_Second_Half,
    MS_Vote_Overtime,
    MS_Before_Overtime_First_Half,
    MS_Live_Overtime_First_Half,
    MS_Before_Overtime_Second_Half,
    MS_Live_Overtime_Second_Half,
    MS_Post_Match,
};
*/
    if(gMatchState == MS_Pre_Setup)
    {
        StartMatchSetup();
    }
    else if(gMatchState == MS_Before_First_Half)
    {
        StartFirstHalf();
    }
    else if(gMatchState == MS_Before_Second_Half)
    {
        StartSecondHalf();
    }
    else if(gMatchState == MS_Before_Overtime_First_Half)
    {
        StartOTFirstHalf();
    }
    else if(gMatchState == MS_Before_Overtime_Second_Half)
    {
        StartOTSecondHalf();
    }
}

PartialNameClient(const String:matchText[])
{
    new Client = 0;
    for(new x=1;x<=MAXPLAYERS;x++)
    {
        if(ValidClient(x) && !IsSourceTV(x))
        {
            new String:clName[32];
            GetClientName(x, clName, 32);
            if(StrContains(clName, matchText, false)>=0)
            {
                if(Client!=0)
                {
                    return -1; // -1 == multiple
                }
                else
                {
                    Client = x;
                }
            }
        }
    }
    return Client;
}

CSLTeam(client)
{
    if(!ValidClient(client) || IsSourceTV(client))
    {
        return -1;
    }
    new String:steamID[24];
    GetClientAuthString(client, steamID, 24);
    return CSLTeamOfSteam(steamID);
}

CSLTeamOfSteam(const String:steamID[])
{
    for(new x=0;x<5;x++)
    {
        if(StrEqual(steamID, TeamPlayers[TEAM_A][x]))
        {
            return TEAM_A;
        }        
    }
    for(new x=0;x<5;x++)
    {
        if(StrEqual(steamID, TeamPlayers[TEAM_B][x]))
        {
            return TEAM_B;
        }        
    }
    return -1;
}

bool:AllowBots()
{
    return false; // Temp.
}

ClientDefaults(client)
{
    fLastMessage[client] = 0.0;
    AutoDmg[client] = false;
    FirstSpawn[client] = true;
    if(ValidClient(client)) {
        GetClientName(client, clientUsername[client], 24);
    }
    bAuthed[client] = false;
    bReady[client] = false;
    readyUpTime[client] = 0;
    notReadyTime[client] = 0;
    bDisconnecting[client] = true;
    bPubChatMuted[client] = false;
    bTeamChatMuted[client] = false;
    for(new x=0;x<=MAXPLAYERS;x++)
    {
        bMuted[client][x] = false;
    }
}

Kick(client, String:format[], any:...)
{
    if(!ValidClient(client))
    {
        return;
    }
    new String:reason[256];
    VFormat(reason, sizeof(reason), format, 3);
    if(StrEqual(reason,""))
    {
        KickClient(client);
    }
    else
    {
        KickClient(client,"%s",reason);
    }
    PrintToServer("KICK (%d): %s",client,reason);
}

bool:ReadyUpState()
{
    if(gMatchState==MS_Pre_Setup || gMatchState==MS_Before_First_Half || gMatchState==MS_Before_Second_Half
    || gMatchState==MS_Before_Overtime_First_Half || gMatchState==MS_Before_Overtime_Second_Half)
    {
        return true;
    }
    return false;
}

ChangeCvar(const String:cvarName[], const String:newValue[])
{
    new Handle:hVar = FindConVar(cvarName);
    new oldFlags = GetConVarFlags(hVar);
    new newFlags = oldFlags;
    newFlags &= ~FCVAR_NOTIFY;
    SetConVarFlags(hVar, newFlags);
    SetConVarString(hVar, newValue);
    SetConVarFlags(hVar, oldFlags);
}

EnterReadyUpState()
{
    // Just a hack for freeze time.
    ChangeCvar("mp_roundtime", "9");
    ChangeCvar("mp_freezetime", "0");
    ChangeCvar("mp_buytime", "999");
    ChangeCvar("mp_forcecamera", "0");
    for(new x=0;x<=MAXPLAYERS;x++)
    {
        notReadyTime[x] = GetTime();
        bReady[x] = false;
    }
}

public Action:WarmUpSpawner(Handle:timer)
{
    if(ReadyUpState())
    {
        DeleteBomb();
        for(new x=1;x<=MAXPLAYERS;x++)
        {
            if(ValidClient(x) && !IsSourceTV(x) && !IsPlayerAlive(x))
            {
                // Is it warm up?
                if(ReadyUpState() && GetClientTeam(x)>1)
                {
                    CS_RespawnPlayer(x);
                }
            }
        }
    }
}

public Action:OneSecCheck(Handle:timer)
{
    for(new x=1;x<=MAXPLAYERS;x++)
    {
        if(ValidClient(x) && !IsFakeClient(x))
        {
            if(ReadyUpState())
            {
                if(!bReady[x] && GetClientTeam(x) > 1 && notReadyTime[x] + 180 <= GetTime())
                {
                    Kick(x, "You must ready up within 3 minutes");
                    continue;
                }            
                new Handle:hBuffer = StartMessageOne("KeyHintText", x);
                new String:tmptext[256];
                Format(tmptext, 256, "READY:\n");
                //new String:optComma[32] = "";
                // do ready players
                for(new y=1;y<=MAXPLAYERS;y++)
                {
                    if(ValidClient(y) && !IsSourceTV(y))
                    {
                        if(bReady[y] && GetClientTeam(y) > 1) // only show players on a team
                        {
                            new String:plName[32];
                            new String:plNameTrun[24];
                            GetClientName(y, plName, 32);
                            if(strlen(plName)>21)
                            {
                                for(new z=0;z<20;z++)
                                {
                                    plNameTrun[z] = plName[z];
                                }
                                plNameTrun[20] = '.';
                            }
                            else
                            {
                                Format(plNameTrun, 24, "%s", plName);
                            }
                            Format(tmptext, 256, "%s%s\n", tmptext, plNameTrun);
                            //Format(optComma, 32, ", ");
                        }
                    }
                }
                Format(tmptext, 256, "%s\nNOT READY:\n", tmptext);
                // do notready players
                for(new y=1;y<=MAXPLAYERS;y++)
                {
                    if(ValidClient(y) && !IsSourceTV(y))
                    {
                        if(!bReady[y] && GetClientTeam(y) > 1) // only show players on a team
                        {
                            new String:plName[32];
                            new String:plNameTrun[24];
                            GetClientName(y, plName, 32);
                            if(strlen(plName)>21)
                            {
                                for(new z=0;z<20;z++)
                                {
                                    plNameTrun[z] = plName[z];
                                }
                                plNameTrun[20] = '.';
                            }
                            else
                            {
                                Format(plNameTrun, 24, "%s", plName);
                            }
                            Format(tmptext, 256, "%s%s\n", tmptext, plNameTrun);
                        }
                    }
                }

                EndMessage();
                
                if(CaptainMode && gMatchState==MS_Before_First_Half) // if they switched maps show this
                {
                    if(TournamentMode)
                    {
                        PrintHintTextToAll("HG: Waiting on Teams to join sides\n.ready up!");
                    }
                    else
                    {
                        PrintHintTextToAll("HG: Waiting on Captains to pick players..\n.ready up when you're on a team!");
                    }
                }
            }
        }
    }
    return Plugin_Continue;
}

public Action:OneSecCheckPanel(Handle:timer)
{
    for(new x=1;x<=MAXPLAYERS;x++)
    {
        if(ValidClient(x) && !IsFakeClient(x))
        {
            if(ReadyUpState())
            {
                if(!bReady[x] && GetClientTeam(x) > 1 && notReadyTime[x] + 180 <= GetTime())
                {
                    Kick(x, "You must ready up within 3 minutes");
                    continue;
                }
                //new Handle:hBuffer = StartMessageOne("KeyHintText", x);
                new Handle:readyPanel = CreatePanel();
                SetPanelTitle(readyPanel, "HellsGamers PugMod");
                
                new String:tmptext[192];
                Format(tmptext, 192, "READY:\n");
                //new String:optComma[32] = "";
                // do ready players
                for(new y=1;y<=MAXPLAYERS;y++)
                {
                    if(ValidClient(y) && !IsSourceTV(y))
                    {
                        if(bReady[y] && GetClientTeam(y) > 1) // only show players on a team
                        {
                            new String:plName[32];
                            new String:plNameTrun[24];
                            GetClientName(y, plName, 32);
                            if(strlen(plName)>21)
                            {
                                for(new z=0;z<20;z++)
                                {
                                    plNameTrun[z] = plName[z];
                                }
                                plNameTrun[20] = '.';
                            }
                            else
                            {
                                Format(plNameTrun, 24, "%s", plName);
                            }
                            Format(tmptext, 192, "%s%s\n", tmptext, plNameTrun);
                        }
                    }
                }
                new String:tmptext2[192];
                Format(tmptext2, 192, "NOT READY:\n", tmptext2);
                // do notready players
                for(new y=1;y<=MAXPLAYERS;y++)
                {
                    if(ValidClient(y) && !IsSourceTV(y))
                    {
                        if(!bReady[y] && GetClientTeam(y) > 1) // only show players on a team
                        {
                            new String:plName[32];
                            new String:plNameTrun[24];
                            GetClientName(y, plName, 32);
                            if(strlen(plName)>21)
                            {
                                for(new z=0;z<20;z++)
                                {
                                    plNameTrun[z] = plName[z];
                                }
                                plNameTrun[20] = '.';
                            }
                            else
                            {
                                Format(plNameTrun, 24, "%s", plName);
                            }
                            Format(tmptext2, 192, "%s%s\n", tmptext2, plNameTrun);
                        }
                    }
                }
 
                //EndMessage();
                DrawPanelText(readyPanel, tmptext);
                DrawPanelItem(readyPanel, "", ITEMDRAW_SPACER);
                DrawPanelText(readyPanel, tmptext2);
                for(new i = 1; i <= MaxClients; i++)
                {
                    if(IsClientInGame(i) && !IsFakeClient(i))
                    {
                        SendPanelToClient(readyPanel, i, Handler_DoNothing, 10);
                    }
                }
                CloseHandle(readyPanel);
                
                if(CaptainMode && gMatchState==MS_Before_First_Half) // if they switched maps show this
                {
                    if(TournamentMode)
                    {
                        PrintHintTextToAll("HG: Waiting on Teams to join sides\n.ready up!");
                    }
                    else
                    {
                        PrintHintTextToAll("HG: Waiting on Captains to pick players..\n.ready up when you're on a team!");
                    }
                }
            }
        }
    }
    return Plugin_Continue;
}

public Handler_DoNothing(Handle:menu, MenuAction:action, param1, param2)
{
	/* Do nothing */
}

// This function checks if a STEAMID is valid.
// AS VALVE UPDATES THEIR STANDARDS CHANGE THIS
bool:BadSteamId(const String:steamID[])
{
    if(!AllowBots() && StrEqual(steamID,"BOT"))
        return true;
        
    return false; // It's good.
}

bool:ValidClient(client,bool:check_alive=false)
{
    if(client>0 && client<=MaxClients && IsClientConnected(client) && IsClientInGame(client))
    {
        if(check_alive && !IsPlayerAlive(client))
        {
            return false;
        }
        return true;
    }
    return false;
}

public Action:MapDelayed(Handle:timer)
{
    ChangeMatchState(MS_Before_First_Half);
    new String:curmap[32];
    GetCurrentMap(curmap, 32);
    if(!StrEqual(curmap, MatchMap))
    {
        ForceChangeLevel(MatchMap, "Setting up match");
    }
}

TeamSize(teamCSL)
{
    new i = 0;
    for(new x=0;x<5;x++)
    {
        if(!StrEqual(TeamPlayers[teamCSL][x],""))
        {
            i++;
        }
    }
    return i;
}

TeamSizeActive(teamCSL)
{
    new i = 0;
    for(new x=0;x<5;x++)
    {
        if(!StrEqual(TeamPlayers[teamCSL][x],""))
        {
            new cAtX = ClientOfSteamId(TeamPlayers[teamCSL][x]);
            if(ValidClient(cAtX))
            {
                i++;
            }
        }
    }
    return i;
}

AddSteamToTeam(const String:steamID[], teamNum)
{
    // If the team is full, look for a disconnect. They are going to be replaced and will probably be penelized.
    new TeamCount = TeamSize(teamNum);
    if(TeamCount<5)
    {
        //PrintToServer("DEBUG: TeamCount<5");
        for(new x=0;x<5;x++)
        {
            //PrintToServer("DEBUG: TeamCount<5 x: %i", x);
            if(StrEqual(TeamPlayers[teamNum][x],""))
            {
                //PrintToServer("DEBUG: TeamCount<5 x: %i is null return", x);
                Format(TeamPlayers[teamNum][x], 24, "%s", steamID);
                return;
            }
        }
    }
    else
    {
        //PrintToServer("DEBUG: TeamCount<5 else");
        // Sorry, whoever left is bound to cry if they were trying to come back :(
        for(new x=0;x<5;x++)
        {
            //PrintToServer("DEBUG: for x: %i", x);
            new ClientAt = ClientOfSteamId(TeamPlayers[teamNum][x]);
            // if player joined back give money back

            if(StrEqual(steamID,TeamPlayers[teamNum][x]))
            {
                //PrintToServer("DEBUG: for x: %i player joined back steamid: %s", x, steamID);
                // get his money
                new money = StringToInt(TeamPlayersMoney[teamNum][x]);
                //Format(TeamPlayersMoney[teamNum][x], 5, "%i", money);
                
                new client = ClientOfSteamId(steamID);
                new StartMoney = GetConVarInt(hStartMoney);
                //PrintToServer("DEBUG: StartMoney: %i", StartMoney);
                if(money>StartMoney)
                {
                    SetMoney(client, money);
                }
                else
                {
                    money = StartMoney;
                }
                PrintToChat(client, "%s Welcome back! Your money has been restored to %i", MSG_PREFIX, money);
                return;
            }
            if(!ValidClient(ClientAt) || !(GetClientTeam(ClientAt) > 1))
            {
                //PrintToServer("DEBUG: removing ClientAt: %i", ClientAt);
                // set money of removed team player
                new money = StringToInt(TeamPlayersMoney[teamNum][x]);
                //Format(TeamPlayersMoney[teamNum][x], 5, "%i", money);
                
                new client = ClientOfSteamId(steamID);
                //PrintToServer("DEBUG: client: %i steamid: %s sub money: %i teamNum: %i x: %i oldclient: %i", client, steamID, money, teamNum, x, ClientAt);
                
                new StartMoney = GetConVarInt(hStartMoney);
                if(money>StartMoney)
                {
                    SetMoney(client, money);
                }
                else
                {
                    money = StartMoney;
                }
                PrintToChat(client, "%s You have subbed in for a teammate, your money is %i", MSG_PREFIX, money);
                //PrintToServer("DEBUG: steamid: %s sub money: %i", steamID, money);
                // set new person is open slot
                Format(TeamPlayers[teamNum][x], 24, "%s", steamID);
                return;
            }
        }
    }    
}

StartKnifeRound()
{
    ChangeMatchState(MS_Setup_Pre_Captain_Round);
    if(TournamentMode)
    {
        PrintToChatAll("%s Starting knife round for team side...", MSG_PREFIX);
    }
    else
    {
        PrintToChatAll("%s Starting pistol round for captains...", MSG_PREFIX);
    }
    //EnforceMatchCvars();
    KnifeWinner = 0;  // clear captains
    KnifeWinner2 = 0; // clear captains
    CaptainTeam = 0;
    EnforceKnifeOnly(true); // remove buyzone and weapons can use
    
    ServerCommand("mp_restartgame 3\n");
    RestartTimers = CreateTimer(2.5, KnifeMessageTimer);
}

public Action:KnifeMessageTimer(Handle:timer)
{
    RestartTimers = INVALID_HANDLE;
    if(TournamentMode)
    {
        PrintCenterTextAll("KNIFE ROUND IS LIVE!");
        PrintToChatAll("%s Knife round is live!", MSG_PREFIX);
    }
    else
    {
        PrintCenterTextAll("CAPTAIN ROUND IS LIVE!");
        PrintToChatAll("%s Captain round is live!", MSG_PREFIX);
    }
}

StartFirstHalf()
{
    // Record.
    // Map.
    decl String:sTime[64];
    FormatTime(sTime, sizeof(sTime), "%Y-%m-%d_%Hh-%Mm-%Ss%p", GetTime());
    ServerCommand("tv_record %s_%i_%s_%s\n", GetServerIp(), GetServerPort(), sTime, MatchMap);
    
    // set hostname to LIVE
    SetHostnameLive(true);

    if(RandomizerMode)
    {
        // Go through each person (random order), if they aren't on a team assign them to the team lacking players, or random.
        new bool:ClientIterated[MAXPLAYERS+1] = false;
        for(new i=1;i<=MAXPLAYERS;i++)
        {
            new RandClient = GetRandomInt(1,MAXPLAYERS);
            while(ClientIterated[RandClient])
            {
                RandClient = GetRandomInt(1,MAXPLAYERS);
            }
            ClientIterated[RandClient] = true;
            if(!ValidClient(RandClient) || IsSourceTV(RandClient))
            {
                continue;
            }
            new String:steamID[24];
            GetClientAuthString(RandClient, steamID, 24);
            if(CSLTeam(RandClient)!=-1)
            {
                continue; // Already on a team, on a group likely.
            }
            // Now put them on a team.
            new RandClientTeam = GetClientTeam(RandClient);
            if(RandClientTeam > 1)
            {
                // Now put them on a team.
                new TeamACount = TeamSizeActive(TEAM_A);
                new TeamBCount = TeamSizeActive(TEAM_B);
                if(TeamACount < TeamBCount)
                {
                    AddSteamToTeam(steamID, TEAM_A);
                }
                else if(TeamBCount < TeamACount)
                {
                    AddSteamToTeam(steamID, TEAM_B);
                }
                else
                {
                    new RandTeam = GetRandomInt(TEAM_A, TEAM_B);
                    AddSteamToTeam(steamID, RandTeam);
                }
            }
        }
    }
    else // must be captainmode or tournament mode, so should lock teams.
    {
        // Go through each person and lock them to the team they are on. if person joins late auto put them on the lowest team.
        new bool:ClientIterated[MAXPLAYERS+1] = false;
        for(new i=1;i<=MAXPLAYERS;i++)
        {
            new RandClient = GetRandomInt(1,MAXPLAYERS);
            while(ClientIterated[RandClient])
            {
                RandClient = GetRandomInt(1,MAXPLAYERS);
            }
            ClientIterated[RandClient] = true;
            if(!ValidClient(RandClient) || IsSourceTV(RandClient))
            {
                continue;
            }
            new String:steamID[24];
            GetClientAuthString(RandClient, steamID, 24);
            if(CSLTeam(RandClient)!=-1)
            {
                continue; // Already on a team, on a group likely.
            }
            // Now put them on a team.
            new RandClientTeam = GetClientTeam(RandClient);
            if(RandClientTeam > 1) // only put players on a team that are ct or t
            {
                if(CaptainMode && ValidClient(KnifeWinner) && CaptainTeam > 1) // only true if captain CHOSE a team
                {
                    if(CaptainTeam == GetClientTeam(KnifeWinner))
                    {
                        if(RandClientTeam == CS_TEAM_T)
                        {
                            AddSteamToTeam(steamID, TEAM_A);
                        }
                        else if(RandClientTeam == CS_TEAM_CT)
                        {
                            AddSteamToTeam(steamID, TEAM_B);
                        }
                    }
                    else
                    {
                        if(RandClientTeam == CS_TEAM_T)
                        {
                            AddSteamToTeam(steamID, TEAM_B);
                        }
                        else if(RandClientTeam == CS_TEAM_CT)
                        {
                            AddSteamToTeam(steamID, TEAM_A);
                        }
                    }
                }
                else
                {
                    if(RandClientTeam == CS_TEAM_T)
                    {
                        AddSteamToTeam(steamID, TEAM_A);
                    }
                    else if(RandClientTeam == CS_TEAM_CT)
                    {
                        AddSteamToTeam(steamID, TEAM_B);
                    }
                    else
                    {
                        // they are spec, leave them..
                        //new RandTeam = GetRandomInt(TEAM_A, TEAM_B);
                        //AddSteamToTeam(steamID, RandTeam);
                    }
                }
            }
        }
    }

    /*
    else
    {
        Later
    }    
    */
    // Clear scores just incase.
    TeamAScore = 0;
    TeamBScore = 0;
    // Team A goes T first
    for(new x=1;x<=MAXPLAYERS;x++)
    {
        if(ValidClient(x) && !IsSourceTV(x))
        {
            new Team = CSLTeam(x);
            if(Team==TEAM_A)
            {
                CS_SwitchTeam(x, CS_TEAM_T);
            }
            else if(Team==TEAM_B)
            {
                CS_SwitchTeam(x, CS_TEAM_CT);
            }
            else
            {
                //Kick(x, "Sorry, you aren't supposed to be here");
                ChangeClientTeam(x, CS_TEAM_SPEC);
                PrintToChat(x, "%s Sorry, you aren't supposed to be here.", MSG_PREFIX);
            }
        }        
    }

    ChangeMatchState(MS_Live_First_Half);
    
    //PrintToChatAll("%s Match will start in 15 seconds. Setup channels..", MSG_PREFIX);
    ResetMoneyStorage();
    EnforceMatchCvars();
    g_iDelayStart = 15;
    RestartTimers = CreateTimer(1.0, RestartDelayTime, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:RestartDelayTime(Handle:timer)
{
    if(g_iDelayStart > 0)
    {
        PrintCenterTextAll("%s Match will start in %i seconds", MSG_PREFIX, g_iDelayStart);
        g_iDelayStart--;
        return Plugin_Continue;
    }
    
    PrintToChatAll("%s Starting the first half...", MSG_PREFIX);
    ServerCommand("mp_restartgame 1\n");
    RestartTimers = CreateTimer(2.0, RestartSecondTime);

    return Plugin_Stop;
}

public Action:RestartSecondTime(Handle:timer)
{
    ServerCommand("mp_restartgame 5\n");
    RestartTimers = CreateTimer(6.0, RestartThirdTime);
}

public Action:RestartThirdTime(Handle:timer)
{
    ServerCommand("mp_restartgame 5\n");
    PrintToChatAll("%s Next round is live.", MSG_PREFIX);
    RestartTimers = CreateTimer(4.9, LiveMessageTimer);
}

public Action:LiveMessageTimer(Handle:timer)
{
    RestartTimers = INVALID_HANDLE;
    PrintCenterTextAll("MATCH IS LIVE!");
    RoundCounterOn = true;
    PrintToChatAll("%s Match is live!", MSG_PREFIX);
    PrintToChatAll("%s Match is live!", MSG_PREFIX);
    PrintToChatAll("%s Match is live!", MSG_PREFIX);
}

bool:TeamsSetup()
{
    if(gMatchState>=MS_Live_First_Half && gMatchState<MS_Post_Match)
    {
        return true;
    }
    return false;
}

ClientKnifeOnly(client)
{
    // for ClientPutInServer late joiners
    SDKHook(client, SDKHook_PostThinkPost, Hook_PostThinkPost);      
    SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse); 
}

EnforceKnifeOnly(bool:hook = false)
{
    if(hook)
    {
        KnifeOnly = true;
        for(new i=1;i<=MAXPLAYERS;i++)
        {
            if(ValidClient(i))
            {
                SDKHook(i, SDKHook_PostThinkPost, Hook_PostThinkPost);
                SDKHook(i, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
            }
        }
    }
    else
    {
        KnifeOnly = false;
        for(new i=1;i<=MAXPLAYERS;i++)
        {
            if(ValidClient(i))
            {
                SDKUnhook(i, SDKHook_PostThinkPost, Hook_PostThinkPost);
                SDKUnhook(i, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
            }
        }
    }
}
public Hook_PostThinkPost(entity)  
{
    if(TournamentMode)
    {
        SetEntProp(entity, Prop_Send, "m_bInBuyZone", 0);
    }
}

public Action:Hook_WeaponCanUse(client, weapon)  
{
    new String:gweapon[64];
    GetEntityClassname(weapon, gweapon, sizeof(gweapon));
    
    if(TournamentMode)
    {
        if(!StrEqual(gweapon,"weapon_knife")) 
        {
            return Plugin_Handled;
        }
    }
    else
    {
        if(!StrEqual(gweapon,"weapon_knife") && 
            !StrEqual(gweapon,"weapon_usp") && 
            !StrEqual(gweapon,"weapon_glock") && 
            !StrEqual(gweapon,"weapon_deagle") && 
            !StrEqual(gweapon,"weapon_p228") && 
            !StrEqual(gweapon,"weapon_elite") && 
            !StrEqual(gweapon,"weapon_fiveseven") && 
            !StrEqual(gweapon,"weapon_p250") && 
            !StrEqual(gweapon,"weapon_tec9") && 
            !StrEqual(gweapon,"weapon_hkp2000")) 
        {
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

EnforceMatchCvars(bool:ot = false)
{
    ChangeCvar("mp_freezetime", "15");
    ChangeCvar("mp_forcecamera", "1");
    ChangeCvar("mp_buytime", "15"); // buytime is in second for csgo
    if(BunnyHopMode)
    {
        ChangeCvar("sv_enablebunnyhopping", "1");
    }
    else
    {
        ChangeCvar("sv_enablebunnyhopping", "0");
    }
    if(Ruleset==Rules_PUG)
    {
        ChangeCvar("mp_roundtime", "1.75");
    }
    else if(Ruleset==Rules_CGS)
    {
        ChangeCvar("mp_roundtime", "1.50");
    }
    if(ot)
    {
        if(Ruleset==Rules_PUG)
        {
            ChangeCvar("mp_startmoney", "10000");
        }
        else if(Ruleset==Rules_CGS)
        {
            ChangeCvar("mp_startmoney", "16000");
        }
    }
    else
    {
        if(Ruleset==Rules_PUG)
        {
            ChangeCvar("mp_startmoney", "800");
        }
        else if(Ruleset==Rules_CGS)
        {
            ChangeCvar("mp_startmoney", "8000");
        }
    }
}

StartSecondHalf()
{
    ChangeMatchState(MS_Live_Second_Half);
    EnforceMatchCvars();
    ResetMoneyStorage();
    PrintToChatAll("%s Starting the second half...", MSG_PREFIX);
    ServerCommand("mp_restartgame 1\n");
    RestartTimers = CreateTimer(2.0, RestartSecondTime);
}

StartOTFirstHalf()
{
    ChangeMatchState(MS_Live_Overtime_First_Half);

    PrintToChatAll("%s Starting the first half of overtime...", MSG_PREFIX);
    EnforceMatchCvars(true);
    ResetMoneyStorage();
    ServerCommand("mp_restartgame 1\n");
    RestartTimers = CreateTimer(2.0, RestartSecondTime);
}

StartOTSecondHalf()
{
    ChangeMatchState(MS_Live_Overtime_Second_Half);

    PrintToChatAll("%s Starting the second half of overtime...", MSG_PREFIX);
    EnforceMatchCvars(true);
    ResetMoneyStorage();
    ServerCommand("mp_restartgame 1\n");
    RestartTimers = CreateTimer(2.0, RestartSecondTime);
}

// BUG: Votes dont continue if failed.
TryStartMatch()
{
    // Are we on the correct map?
    new String:curmap[32];
    GetCurrentMap(curmap, 32);
    if(!StrEqual(curmap, MatchMap))
    {
        PrintToChatAll("%s Map is changing in 5 seconds, brace yourselves.", MSG_PREFIX);
        CreateTimer(5.0, MapDelayed);
    }
    else
    {
        if(CaptainMode)
        {
            //change state, readyup on same map
            ChangeMatchState(MS_Before_First_Half);
        }
        else
        {
            StartFirstHalf();
        }
    }                                                                                                   
}

RulesCSL()
{
    PrintToChatAll("%s Ruleset will be: (15 Round Halves, $800)", MSG_PREFIX);
    Ruleset = Rules_PUG;
    TeamVote();
}

SetMatchMap(const String:mapname[])
{
    PrintToChatAll("%s Map will be: %s", MSG_PREFIX, mapname);
    Format(MatchMap, 32, mapname);
    if(CaptainMode)
    {
        StartChooseSide(); //TryStartMatch();
    }
    else
    {
        TryStartMatch();
    }
}

public Handle_MapVote(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_End)
    {
        CloseHandle(menu);
    } else if (action == MenuAction_VoteEnd) {
        new String:map[32];
        GetMenuItem(menu, param1, map, sizeof(map));
        if(StrEqual(map,"Random"))
        {
            SetMatchMap(MapNames[GetRandomInt(0, GetMapCount()-1)]);        
        }
        else
        {
            SetMatchMap(map);
        }
    }
    else if(action==MenuAction_VoteCancel)
    {
        // Choose a random map.
        SetMatchMap(MapNames[GetRandomInt(0, GetMapCount()-1)]);
    }
}

StartMapVoteCaptain()
{
    // Choose a rule set.
    if (IsVoteInProgress())
    {
        CancelVote();
    }
 
    new Handle:menu = CreateMenu(Handle_MapVote);
    SetMenuTitle(menu, "Vote for the map");
    // Random order.
    new bool:bShowed[MAX_MAPS];
    for(new x=0;x<GetMapCount();x++)
    {        
        new Rand = GetRandomInt(0, GetMapCount()-1);
        while(bShowed[Rand])
        {
            Rand = GetRandomInt(0, GetMapCount()-1);
        } 
        bShowed[Rand] = true;
        AddMenuItem(menu, MapNames[Rand], MapNames[Rand]);
    }
    SetMenuExitButton(menu, false);
    
    new Clients[MaxClients], iCount;
    Clients[iCount++] = KnifeWinner2;
    VoteMenu(menu, Clients, iCount, 25);
}

StartMapVote()
{
    // Choose a rule set.
    if (IsVoteInProgress())
    {
        CancelVote();
    }
 
    new Handle:menu = CreateMenu(Handle_MapVote);
    SetMenuTitle(menu, "Vote for the map");
    // Random order.
    new bool:bShowed[MAX_MAPS];
    for(new x=0;x<GetMapCount();x++)
    {        
        new Rand = GetRandomInt(0, GetMapCount()-1);
        while(bShowed[Rand])
        {
            Rand = GetRandomInt(0, GetMapCount()-1);
        } 
        bShowed[Rand] = true;
        AddMenuItem(menu, MapNames[Rand], MapNames[Rand]);
    }
    SetMenuExitButton(menu, false);
    
    new Clients[MaxClients], iCount;   
    for(new a=1;a<=MAXPLAYERS;a++)
    {
        if(ValidClient(a) && !IsSourceTV(a) && GetClientTeam(a) > 1)
        {
            Clients[iCount++] = a;
        }
    }
    VoteMenu(menu, Clients, iCount, 25);
    //VoteMenuToAll(menu, 15);
}

// for captain mode
public Handle_ChooseSide(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_End)
    {
        CloseHandle(menu);
    } else if (action == MenuAction_VoteEnd) {
        // 0 = t
        // 1 = ct
        if(param1 == 0)
        {
            new String:KnifeWinnerName[32];
            GetClientName(KnifeWinner, KnifeWinnerName, sizeof(KnifeWinnerName));
            PrintToChatAll("%s %s chose side Terrorist.", MSG_PREFIX, KnifeWinnerName);
            // set side
            SetCaptainSide(CS_TEAM_T);
            TryStartMatch();
        }
        else
        {
            new String:KnifeWinnerName[32];
            GetClientName(KnifeWinner, KnifeWinnerName, sizeof(KnifeWinnerName));
            PrintToChatAll("%s %s chose side Counter-Terrorist.", MSG_PREFIX, KnifeWinnerName);
            // set side
            SetCaptainSide(CS_TEAM_CT);
            TryStartMatch();
        }
    }
    else if(action==MenuAction_VoteCancel)
    {
        TryStartMatch();
    }
}

StartChooseSide()
{
    if(IsVoteInProgress())
    {
        CancelVote();
    }
    new Handle:menu = CreateMenu(Handle_ChooseSide);
    SetMenuTitle(menu, "Choose side for %s", MatchMap);
    AddMenuItem(menu, "t", "Terrorist");
    AddMenuItem(menu, "ct", "Counter-Terrorist");
    SetMenuExitButton(menu, false);
    new Clients[MaxClients], iCount;
    Clients[iCount++] = KnifeWinner;
    VoteMenu(menu, Clients, iCount, 15);
    PrintToChat(KnifeWinner, "%s You must choose a side for next map!", MSG_PREFIX);
}

SetCaptainSide(team)
{
    CaptainTeam = team;
}

public Handle_VoteForOT(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_End)
    {
        CloseHandle(menu);
    } else if (action == MenuAction_VoteEnd) {
        // 0 = yes
        // 1 = no
        if(param1 == 0)
        {
            PrintToChatAll("%s OT vote YES.", MSG_PREFIX);
            // start overtime
            TransOTFirstHalfWarmup();
        }
        else
        {
            PrintToChatAll("%s OT vote NO.", MSG_PREFIX);
            // end game in tie
            MatchTieOT();
        }
    }
    else if(action==MenuAction_VoteCancel)
    {
        // end game in tie
        MatchTieOT();
    }
}

StartVoteForOT()
{
    TransOTVoteTime();
    
    if(IsVoteInProgress())
    {
        CancelVote();
    }
    new Handle:menu = CreateMenu(Handle_VoteForOT);
    SetMenuTitle(menu, "Vote for Overtime");
    AddMenuItem(menu, "yes", "Yes");
    AddMenuItem(menu, "no", "No (Tie Game)");
    SetMenuExitButton(menu, false);
    
    new Clients[MaxClients], iCount;   
    for(new a=1;a<=MAXPLAYERS;a++)
    {
        if(ValidClient(a) && !IsSourceTV(a) && GetClientTeam(a) > 1)
        {
            Clients[iCount++] = a;
        }
    }
    VoteMenu(menu, Clients, iCount, 15);
}

/*
BHopOn()
{
    PrintToChatAll("[PUG] Bunnyhopping will be enabled.");
    BunnyHopMode = true;
    StartMapVote();
}

BHopOff()
{
    PrintToChatAll("[PUG] Bunnyhopping will be disabled.");
    BunnyHopMode = false;
    StartMapVote();
}

public Handle_BHopVote(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_End)
    {
        CloseHandle(menu);
    } else if (action == MenuAction_VoteEnd) {
        // 0 = Off
        // 1 = On
        if(param1 == 0)
        {
            BHopOff();
        }
        else
        {
            BHopOn();
        }
    }
    else if(action==MenuAction_VoteCancel)
    {
        BHopOff();
    }
}

BHopVote()
{
    if(IsVoteInProgress())
    {
        CancelVote();
    }
 
    new Handle:menu = CreateMenu(Handle_BHopVote);
    SetMenuTitle(menu, "Vote for bunny hopping");
    AddMenuItem(menu, "off", "Off");
    AddMenuItem(menu, "on", "On");
    SetMenuExitButton(menu, false);
    VoteMenuToAll(menu, 15);
}
*/
TeamsTournament()
{
     RandomizerMode = false;
     CaptainMode = true;
     StartKnifeRound(); //StartMapVote();
}
TeamsRandom()
{
     RandomizerMode = true;
     CaptainMode = false;
     StartMapVote();
}
TeamsCaptains()
{
     RandomizerMode = false;
     CaptainMode = true;
     StartKnifeRound(); //StartMapVote(); // remove SetMatchMap
}

public Handle_TeamVote(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_End)
    {
        CloseHandle(menu);
    } else if (action == MenuAction_VoteEnd) {
        // 0 = Captains
        // 1 = Random
        if(param1 == 0)
        {
            TeamsCaptains();
        }
        else
        {
            TeamsRandom();
        }
    }
}

TeamVote()
{
    if(TournamentMode)
    {
        TeamsTournament(); // no team sorting options, we are in tournament mode..
    }
    else
    {
        // For now random teams.
        //TeamsRandom();
        // Choose a team set.
        if (IsVoteInProgress())
        {
            CancelVote();
        }
     
        new Handle:menu = CreateMenu(Handle_TeamVote);
        SetMenuTitle(menu, "Vote for team sorting");
        AddMenuItem(menu, "capt", "Captains");
        AddMenuItem(menu, "rand", "Random");
        SetMenuExitButton(menu, false);
        VoteMenuToAll(menu, 15);
    }
}

RulesCGS()
{
    PrintToChatAll("%s Ruleset will be: CGS (9 Round Halves, $8000)", MSG_PREFIX);
    Ruleset = Rules_CGS;
    TeamVote();
}

public Handle_RulesVote(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_End)
    {
        CloseHandle(menu);
    } else if (action == MenuAction_VoteEnd) {
        // 0 = CSL
        // 1 = Pug
        if(param1 == 0)
        {
            RulesCSL();
        }
        else
        {
            RulesCGS();
        }
    }
    else if(action==MenuAction_VoteCancel)
    {
        RulesCSL();
    }
}

stock StartRulesVote()
{
    // Choose a rule set.
    if (IsVoteInProgress())
    {
        CancelVote();
    }
 
    new Handle:menu = CreateMenu(Handle_RulesVote);
    SetMenuTitle(menu, "Vote for rule set");
    AddMenuItem(menu, "csl", "PUG (15 Round Halves, $800)");
    //AddMenuItem(menu, "cgs", "CGS (9 Round Halves, $8000)");
    SetMenuExitButton(menu, false);
    VoteMenuToAll(menu, 15);
}

ChangeMatchState(MatchState:newState)
{
    gMatchState = newState;
    
    if(ReadyUpState())
    {
        EnterReadyUpState();
    }
}

StartMatchSetup()
{
    // Vote for rule set.
    PrintToChatAll("%s Starting match setup.", MSG_PREFIX);
    ChangeMatchState(MS_Setup);
    RulesCSL(); //StartRulesVote(); skip rules vote
}

public Action:SayTeamHook(client,args)
{
    return SayHook(client, args, true);
}

public Action:SayPubHook(client,args)
{
    return SayHook(client, args, false);
}

ReadyUp(client) {
    new String:plName[32];
    GetClientName(client, plName, 32);
    bReady[client] = true;
    readyUpTime[client] = GetTime();
    PrintToChatAll("%s %s is now ready.", MSG_PREFIX, plName);
    // If this is the last ready up.
    new bool:bStillMore = false;
    new PlCount = 0;
    for(new a=1;a<=MAXPLAYERS;a++)
    {
        if(ValidClient(a) && !IsSourceTV(a) && GetClientTeam(a) > 1)
        {
            PlCount++;
            if(!bReady[a])
            {
                bStillMore = true;
            }
        }
    }
    if(!bStillMore)
    {
        if(PlCount == GetConVarInt(hMaxPlayers))
        {
            OnAllReady();
        }
        else
        {
            new NeedPl = GetConVarInt(hMaxPlayers) - PlCount;
            PrintToChatAll("%s Still waiting on %d players...", MSG_PREFIX, NeedPl);
        }
    }
}

public Action:SayHook(client,args,bool:team)
{
    if(!client)
        return Plugin_Continue; // Don't block the server ever.
    
    decl String:ChatText[256];
    GetCmdArgString(ChatText,256);
    StripQuotes(ChatText);
    new String:Words[100][256];
    new WordCount = ExplodeString(ChatText, " ", Words, 100, 256);
    new bool:bHookMessage = false;
    new bool:bCommand = true;

    if(StrEqual(Words[0],"/ready", false) || StrEqual(Words[0],".ready", false) || StrEqual(Words[0],".r", false))
    {
        if(!ReadyUpState())
        {
            PrintToChat(client, "%s You don't need to ready up right now.", MSG_PREFIX);
            bHookMessage = true; 
        }
        else
        {
            if(bReady[client])
            {
                PrintToChat(client,"%s You are already ready.", MSG_PREFIX);
                bHookMessage = true;
            }
            else
            {
                if(GetClientTeam(client) > 1)
                {
                    ReadyUp(client);
                }
                else
                {
                    PrintToChat(client,"%s You are not on a team.", MSG_PREFIX);
                }
            }
        }
    }
    else if(StrEqual(Words[0], "/mute", false) || StrEqual(Words[0], ".mute", false))
    {
        bHookMessage = true;
        new String:fullSecond[256];
        Format(fullSecond, 256, "%s", Words[1]);
        for(new x=2;x<WordCount;x++)
        {
            Format(fullSecond, 256, "%s %s", fullSecond, Words[x]);
        }
        if(StrEqual(fullSecond,""))
        {
            PrintToChat(client, "%s Syntax: /mute <part of name>", MSG_PREFIX);
        }
        else
        {
            new cl = PartialNameClient(fullSecond);
            if(cl==-1)
            {
                PrintToChat(client, "%s Be more specific, multiple matches.", MSG_PREFIX);
            }
            else if(cl==0)
            {
                PrintToChat(client, "%s No matches for \"%s\".", MSG_PREFIX, fullSecond);
            }
            else
            {
                if(client==cl)
                {
                    PrintToChat(client, "%s You can't mute yourself.", MSG_PREFIX);
                }
                else if(IsPlayerMuted(client, cl))
                {
                    PrintToChat(client, "%s Player already muted.", MSG_PREFIX);
                }
                else
                {
                    PrintToChat(client, "%s Player muted.", MSG_PREFIX);
                    bMuted[client][cl] = true;
                }
            }
        }
    }
    else if(StrEqual(Words[0], "/unmute", false) || StrEqual(Words[0], ".unmute", false))
    {
        bHookMessage = true;
        new String:fullSecond[256];
        Format(fullSecond, 256, "%s", Words[1]);
        for(new x=2;x<WordCount;x++)
        {
            Format(fullSecond, 256, "%s %s", fullSecond, Words[x]);
        }
        if(StrEqual(fullSecond,""))
        {
            PrintToChat(client, "%s Syntax: /unmute <part of name>", MSG_PREFIX);
        }
        else
        {
            new cl = PartialNameClient(fullSecond);
            if(cl==-1)
            {
                PrintToChat(client, "%s Be more specific, multiple matches.", MSG_PREFIX);
            }
            else if(cl==0)
            {
                PrintToChat(client, "%s No matches for \"%s\".", MSG_PREFIX, fullSecond);
            }
            else
            {
                if(client==cl)
                {
                    PrintToChat(client, "%s You can't mute yourself.", MSG_PREFIX);
                }
                else if(!IsPlayerMuted(client, cl))
                {
                    PrintToChat(client, "%s Player isn't muted.", MSG_PREFIX);
                }
                else
                {
                    PrintToChat(client, "%s Player unmuted.", MSG_PREFIX);
                    bMuted[client][cl] = false;
                }
            }
        }        
    }
    else if(StrEqual(Words[0], "/chat", false) || StrEqual(Words[0], ".chat", false))
    {
        bHookMessage = true;
        if(IsPubChatMuted(client))
        {
            bPubChatMuted[client] = false;
            PrintToChat(client, "%s Public chat unmuted", MSG_PREFIX);
        }
        else
        {
            bPubChatMuted[client] = true;
            PrintToChat(client, "%s Public chat muted.", MSG_PREFIX);
        }
    }
    else if(StrEqual(Words[0], "/teamchat", false) || StrEqual(Words[0], ".teamchat", false))
    {
        bHookMessage = true;
        if(IsTeamChatMuted(client))
        {
            bTeamChatMuted[client] = false;
            PrintToChat(client, "%s Team chat unmuted.", MSG_PREFIX);
        }
        else
        {
            bTeamChatMuted[client] = true;
            PrintToChat(client, "%s Team chat muted.", MSG_PREFIX);
        }
    }
    else if(StrEqual(Words[0], "/notready", false) || StrEqual(Words[0], ".notready", false) || StrEqual(Words[0], ".nr", false))
    {
        if(!bReady[client])
        {
            PrintToChat(client, "%s You already are not ready.", MSG_PREFIX);
            bHookMessage = true;
        }
        else
        {
            new curTime = GetTime();
            if(readyUpTime[client] + 15 > curTime)
            {
                PrintToChat(client, "%s You must wait 15 seconds between ready commands.", MSG_PREFIX);
                bHookMessage = true;
            }
            else
            {
                if(GetClientTeam(client) > 1)
                {
                    bReady[client] = false;
                    new String:plName[32];
                    GetClientName(client, plName, 32);
                    PrintToChatAll("%s %s is no longer ready.", MSG_PREFIX, plName);
                    notReadyTime[client] = GetTime();
                }
                else
                {
                    PrintToChat(client,"%s You are not on a team.", MSG_PREFIX);
                }
            }
        }
    }
    else if(StrEqual(Words[0], "/autodmg",false) || StrEqual(Words[0], ".autodmg",false))
    {
        if(AutoDmg[client])
        {
            AutoDmg[client] = false;
            PrintToChat(client, "%s Auto /dmg has been toggled off.", MSG_PREFIX);
        }
        else
        {
            AutoDmg[client] = true;
            PrintToChat(client, "%s Auto /dmg has been toggled on.", MSG_PREFIX);
        }
    }
    else if(StrEqual(Words[0], "/dmg", false) || StrEqual(Words[0], ".dmg", false))
    {
        if(!MatchLive())
        {
            PrintToChat(client, "%s You can't use this now.", MSG_PREFIX);
            bHookMessage = true;
        }
        else
        {
            if(IsPlayerAlive(client))
            {
                PrintToChat(client, "%s You must be dead to use this.", MSG_PREFIX);
                bHookMessage = true;
            }
            else
            {
                PrintDmgReport(client);
            }
        }
    }
    else if(StrEqual(Words[0], "/pause", false) || StrEqual(Words[0], ".pause", false))
    {
        if(!bFreezeTimeEnded)
        {
            new String:plName[32];
            GetClientName(client, plName, 32);
            PrintToChatAll("%s %s has paused the match.", MSG_PREFIX, plName);
            ServerCommand("mp_pause_match");
        }
        else
        {
            PrintToChat(client, "%s Match can only be paused during freeze time.", MSG_PREFIX);
        }
    }
    else if(StrEqual(Words[0], "/unpause", false) || StrEqual(Words[0], ".unpause", false))
    {
        ServerCommand("mp_unpause_match");
    }
    else if(StrEqual(Words[0], "/help", false) || StrEqual(Words[0], ".help", false))
    {
        PrintToChat(client, "%s Commands: .ready, .notready, .help, .dmg, .autodmg, .mute, .chat .pause .unpause", MSG_PREFIX);
        bHookMessage = true;
    }
    else
    {
        bCommand = false;
    }
    new bool:bCanChat = (fLastMessage[client] + 0.5 <= GetEngineTime());
    if(!bCommand && !bHookMessage && team && IsTeamChatMuted(client))
    {
        PrintToChat(client, "%s You can't team chat until you re-enable it with /teamchat.", MSG_PREFIX);
        return Plugin_Handled;
    }
    if(!bCommand && !bHookMessage && !team && IsPubChatMuted(client))
    {
        PrintToChat(client, "%s You can't public chat until you re-enable it with /chat.", MSG_PREFIX);
        return Plugin_Handled;
    }
    if(!bHookMessage && bCanChat)
    {
        fLastMessage[client] = GetEngineTime();
        ChatMsg(client, team, ChatText);
    }
    return Plugin_Handled;
}

public Action:RespawnCheck(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);
    if(ReadyUpState() && ValidClient(client) && !IsSourceTV(client) && !IsPlayerAlive(client) && GetClientTeam(client)>1)
    {
        CS_RespawnPlayer(client);
    }    
}

LogKillLocalStats(const String:steamAttacker[], const String:steamVictim[], const String:weapon[], bool:headshot)
{
    if(!MatchLive())
    {
        return;
    }
    if(CurrentRound<1)
    {
        return;
    }
    // Create a new array.
    new Handle:newArray = CreateArray(24);
    PushArrayString(newArray, steamAttacker);
    PushArrayString(newArray, steamVictim);
    PushArrayString(newArray, weapon);
    PushArrayCell(newArray, headshot);
}

LogKill(attacker, victim, const String:weapon[], bool:headshot)
{
    if(MatchLive())
    {
        new String:steamAttacker[24];
        new String:steamVictim[24];
        GetClientAuthString(attacker, steamAttacker, 24);
        GetClientAuthString(victim, steamVictim, 24);
        LogKillLocalStats(steamAttacker, steamVictim, weapon, headshot);
    }
}

ProcessCaptainRoundDeaths(client, attacker)
{
    KnifeWinner = client; // set incase last player leaves?
    KnifeWinner2 = client; // now second place (storage)

    // check if there is one left standing to end knife round(s)
    new alive = 0;
    for(new i=1;i<=MAXPLAYERS;i++)
    {
        if(ValidClient(i) && IsPlayerAlive(i))
        {
            alive++;
            KnifeWinner = i; // now first place
        }
    }
    if(alive==1)
    {
        // we got a wiener
        ChangeMatchState(MS_Setup_Post_Captain_Round); // idling time, time for captain voting, then map change which will put game into first half.
        EnforceKnifeOnly(false); // unhooks all players, allows buyzone and weapons
        
        for(new i=1;i<=MAXPLAYERS;i++)
        {
            ForceSpec[i] = false;
        }
        
        new String:KnifeWinnerName[32];
        new String:KnifeWinnerName2[32];
        GetClientName(KnifeWinner, KnifeWinnerName, sizeof(KnifeWinnerName));
        GetClientName(KnifeWinner2, KnifeWinnerName2, sizeof(KnifeWinnerName2));
        
        if(TournamentMode)
        {
            PrintToChatAll("%s %s will pick team side.", MSG_PREFIX, KnifeWinnerName);
            // send choose team to captain1
            StartChooseSide(); // sends KnifeWinner choose team
        }
        else
        {
            //PrintToChatAll("%s Captains are: #1 %s, #2 %s. Pick your players now!", MSG_PREFIX, KnifeWinnerName, KnifeWinnerName2);
            PrintToChatAll("%s %s will pick team side.", MSG_PREFIX, KnifeWinnerName);
            PrintToChatAll("%s %s will pick next map.", MSG_PREFIX, KnifeWinnerName2);
            // send map vote to captain2
            PrintToChat(KnifeWinner2, "%s You must vote for next map!", MSG_PREFIX);
            StartMapVoteCaptain();
            // then start side picking :)
        }
    }
    else // all but the last two it should move to spec
    {
        // move(force) them to spectator
        ForceToSpectate(client);

        if(GetTeamClientCount(CS_TEAM_T) < 1 || GetTeamClientCount(CS_TEAM_CT) < 1) // one of the teams has no players
        {
            if(TournamentMode)
            {
                ChangeMatchState(MS_Setup_Post_Captain_Round); // put players on team.
                EnforceKnifeOnly(false);
                
                for(new i=1;i<=MAXPLAYERS;i++)
                {
                    ForceSpec[i] = false;
                }
                
                KnifeWinner = attacker; // now knife winner
        
                // last attacker gets team pick
                new String:KnifeWinnerName[32];
                GetClientName(KnifeWinner, KnifeWinnerName, sizeof(KnifeWinnerName));
                PrintToChatAll("%s %s will pick team side.", MSG_PREFIX, KnifeWinnerName);
                StartChooseSide(); // sends KnifeWinner choose team
            }
            else
            {
                ChangeMatchState(MS_Setup_Pre_Captain_Round);
                PrintToChatAll("%s Fixing teams...", MSG_PREFIX);
                //ServerCommand("mp_scrambleteams\n");
                new p;
                for(new x=1;x<=MAXPLAYERS;x++)
                {
                    if(ValidClient(x) && !IsSourceTV(x) && GetClientTeam(x)>=CS_TEAM_T && IsPlayerAlive(x))
                    {
                        p++;
                        if(p % 2)
                        {
                            ChangeClientTeam(x, CS_TEAM_CT);
                        }
                        else
                        {
                            ChangeClientTeam(x, CS_TEAM_T);
                        }
                    }
                }
                ServerCommand("mp_restartgame 1\n");            
                // restart round
            }
        }
    }
}

public Action:DeathCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
    new userid = GetEventInt(event, "userid");
    CreateTimer(2.0, RespawnCheck, userid);
    new client = GetClientOfUserId(userid);
    new attacker_userid = GetEventInt(event, "attacker");
    new attacker = GetClientOfUserId(attacker_userid);
    new String:weapon[64];
    GetEventString(event, "weapon", weapon, 64);
    new bool:Headshot = (GetEventInt(event, "headshot")==0)?false:true;
    if(ValidClient(client))
    {
        if(attacker==client || attacker==0)
        {
            LogKill(client, client, weapon, false);
        }
        else if(ValidClient(attacker))
        {
            LogKill(attacker, client, weapon, Headshot);
        }
    }
    
    if(MatchLive() && AutoDmg[client])
    {
        PrintDmgReport(client);
    }
    
    if(gMatchState == MS_Setup_Live_Captain_Round)
    {
        ProcessCaptainRoundDeaths(client,attacker);
    }
    
    return Plugin_Continue;
}

public Action:RoundStartCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
    if(ReadyUpState())
    {
        RemoveGroundWeapons(INVALID_HANDLE);
    }
    if(gMatchState == MS_Setup_Pre_Captain_Round)
    {
        ChangeMatchState(MS_Setup_Live_Captain_Round);
    }
    if(RoundCounterOn == true)
    {
        CurrentRound++;
        // Create an array here.
        hMatchDamage[CurrentRound] = CreateArray();
        hMatchKills[CurrentRound] = CreateArray();
        
        SetMoneyStorage();
         
        // Who is winning?
        if(TeamAScore>TeamBScore)
        {
            // Is team A ct or t?
            if(CSTeamToCSL(CS_TEAM_CT) == TEAM_A)
            {
                // They are CT's.
                PrintToChatAll("%s Round %d. CT's winning %d - %d", MSG_PREFIX, CurrentRound, TeamAScore, TeamBScore);
            }
            else
            {
                PrintToChatAll("%s Round %d. T's winning %d - %d", MSG_PREFIX, CurrentRound, TeamAScore, TeamBScore);
            }
        }
        else if(TeamBScore>TeamAScore)
        {
            if(CSTeamToCSL(CS_TEAM_CT) == TEAM_B)
            {
                // They are CT's.
                PrintToChatAll("%s Round %d. CT's winning %d - %d", MSG_PREFIX, CurrentRound, TeamBScore, TeamAScore);
            }
            else
            {
                PrintToChatAll("%s Round %d. T's winning %d - %d", MSG_PREFIX, CurrentRound, TeamBScore, TeamAScore);
            }
        }
        else
        {
            PrintToChatAll("%s Round %d. Tie game, %d - %d", MSG_PREFIX, CurrentRound, TeamAScore, TeamBScore);
        }
    }
    return Plugin_Continue;
}

public Action:Event_Round_Freeze_End(Handle:event, const String:name[], bool:dontBroadcast)
{
    bFreezeTimeEnded = true;
}
public Action:RoundEndCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
    bFreezeTimeEnded = false;
    //new reason = GetEventInt(event, "reason");
    new winner = GetEventInt(event, "winner");
    
    if(RoundCounterOn == true)
    {
        SetMoneyStorage();
        
        if(winner==CS_TEAM_T)
        {
            new CSLT = CSTeamToCSL(CS_TEAM_T);
            if(CSLT == TEAM_A)
            {
                TeamAScore++;
            }
            else
            {
                TeamBScore++;
            }
        }
        else if(winner==CS_TEAM_CT)
        {
            new CSLCT = CSTeamToCSL(CS_TEAM_CT);
            if(CSLCT == TEAM_A)
            {
                TeamAScore++;
            }
            else
            {
                TeamBScore++;
            }
        }
        
        // Is this CSL or CGS rules?
        // Check score first, if there is a winner call WinLegit or whatever.
        // Are we in overtime?
        // Check for a winner, then check for transitioning stuff. If there is a winner, no need to go to Half, etc...
        if(gMatchState >= MS_Before_Overtime_First_Half && gMatchState!=MS_Post_Match)
        {
            // If CSL, overtime start score is 15-15
            // Otherwise, 9 - 9
            if(Ruleset==Rules_PUG)
            {
                if(TeamAScore >= 19)
                {
                    MatchWinOT(TEAM_A);
                    return Plugin_Continue;
                }
                else if(TeamBScore >= 19)
                {
                    MatchWinOT(TEAM_B);
                    return Plugin_Continue;
                }
                else if(TeamAScore == 18 && TeamBScore == 18)
                {
                    // Tie.
                    MatchTieOT();
                    return Plugin_Continue;
                }
            }
            else if(Ruleset==Rules_CGS)
            {
                if(TeamAScore >= 13)
                {
                    MatchWinOT(TEAM_A);
                    return Plugin_Continue;
                }
                else if(TeamBScore >= 13)
                {
                    MatchWinOT(TEAM_B);
                    return Plugin_Continue;
                }
                else if(TeamAScore == 12 && TeamBScore == 12)
                {
                    // Tie.
                    MatchTieOT();
                    return Plugin_Continue;
                }
            }
        }
        else
        {
            if(Ruleset==Rules_PUG)
            {
                // Check of score >=16.
                if(TeamAScore>=16)
                {
                    MatchWin(TEAM_A);
                }
                else if(TeamBScore>=16)
                {
                    MatchWin(TEAM_B);
                }
            }
            else if(Ruleset==Rules_CGS)
            {
                // Check of score >=10.
                if(TeamAScore>=10)
                {
                    MatchWin(TEAM_A);
                }
                else if(TeamBScore>=10)
                {
                    MatchWin(TEAM_B);
                }
            }
        }
        
        // Now do our checks for transitions.
        if(Ruleset==Rules_PUG)
        {
            if(CurrentRound==15)
            {
                // Go to second half.
                TransSecondHalfWarmup();
                return Plugin_Continue;
            }
            else if(CurrentRound==30)
            {
                // Previous checks allow for no use of ==15, ==15
                StartVoteForOT(); //TransOTFirstHalfWarmup();
                return Plugin_Continue;
            }
            else if(CurrentRound==33)
            {
                TransOTSecondHalfWarmup();
                return Plugin_Continue;
            }
        }
        else if(Ruleset==Rules_CGS)
        {
            if(CurrentRound==9)
            {
                // Go to second half.
                TransSecondHalfWarmup();
                return Plugin_Continue;
            }
            else if(CurrentRound==18)
            {
                // Previous checks allow for no use of ==15, ==15
                StartVoteForOT(); //TransOTFirstHalfWarmup();
                return Plugin_Continue;
            }
            else if(CurrentRound==21)
            {
                TransOTSecondHalfWarmup();
                return Plugin_Continue;
            }
        }
    }
    return Plugin_Continue;
}

public Action:RemoveGroundWeapons(Handle:timer)
{
	if (ReadyUpState())
	{
		new maxEntities = GetMaxEntities();
		decl String:class[20];
		
		for (new i = MaxClients + 1; i < maxEntities; i++)
		{
			if (IsValidEdict(i) && (GetEntDataEnt2(i, ownerOffset) == -1))
			{
				GetEdictClassname(i, class, sizeof(class));
				if ((StrContains(class, "weapon_") != -1) || (StrContains(class, "item_") != -1))
				{
					if (StrEqual(class, "weapon_c4"))
					{
						// removing c4 too, not: continue;
					}
					AcceptEntityInput(i, "Kill");
				}
			}
		}
	}
	return Plugin_Continue;
}

MoveAfterTrans()
{
    for(new x=1;x<=MAXPLAYERS;x++)
    {
        if(ValidClient(x) && !IsSourceTV(x))
        {
            new cslTeam = CSLTeam(x);
            if(cslTeam!=TEAM_A && cslTeam!=TEAM_B)
            {
                continue; // Should we kick him? Probably not. This shouldn't happen.
            }
            else
            {
                new csTeam = CSLToCSTeam(cslTeam);
                new curTeam = GetClientTeam(x);
                if(curTeam!=csTeam)
                {
                    CS_SwitchTeam(x, csTeam);
                }
            } 
        }
    }
}

TransSecondHalfWarmup()
{
    // All stop the round counter.
    RoundCounterOn = false;
    // Change state.
    ChangeMatchState(MS_Before_Second_Half);
    // Move them.
    MoveAfterTrans();
}

TransOTVoteTime()
{
    RoundCounterOn = false;
    ChangeMatchState(MS_Vote_Overtime);
}

TransOTFirstHalfWarmup()
{
    RoundCounterOn = false;
    ChangeMatchState(MS_Before_Overtime_First_Half);
    //MoveAfterTrans(); // do not switch when starting OT
}

TransOTSecondHalfWarmup()
{
    RoundCounterOn = false;
    ChangeMatchState(MS_Before_Overtime_Second_Half);
    MoveAfterTrans();
}



public Action:ReduceToOneHundred(Handle:timer, any:client)
{
    if(ValidClient(client) && ReadyUpState() && IsPlayerAlive(client))
    {
        if(GetClientHealth(client)>100)
        {
            SetEntityHealth(client, 100);
        }
    }
}

public Action:SpawnCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
    new userid = GetEventInt(event, "userid");
    new client = GetClientOfUserId(userid);
    if(!ValidClient(client) || IsSourceTV(client))
    {
        return Plugin_Continue;
    }
    if(GetClientTeam(client) > 1)
    {
        CreateTimer(0.01, SpawnStuff, client);
    }
    
    return Plugin_Continue;
}

public Action:SpawnStuff(Handle:timer, any:client)
{
    if(!ValidClient(client))
    {
        return;
    }
    if(ReadyUpState())
    {
        if(FirstSpawn[client])
        {
            FirstSpawn[client] = false;
            PrintToChat(client, "%s Welcome! Please .ready up or type .help for available commands.", MSG_PREFIX);
        }
        else if(!bReady[client])
        {
            PrintToChat(client, "%s Type .ready in chat when you are ready.", MSG_PREFIX);
        }
        if(GetMoney(client)!=16000)
        {
            SetMoney(client, 16000);
        }
        
        if(!bReady[client] && IsFakeClient(client)) {
            ReadyUp(client);
        }
        
        // Spawn protection.
        SetEntityHealth(client, 500);
        CreateTimer(3.0, ReduceToOneHundred, client);
    }
    else
    {
        if(FirstSpawn[client])
        {
            PrintToChat(client, "%s Welcome! Match is LIVE, type .help for help.", MSG_PREFIX);
            FirstSpawn[client] = false;
        }
    }
}

PrintDmgReport(client)
{
    // Get current round.
    new OurTeam = GetClientTeam(client);
    for(new x=1;x<=MAXPLAYERS;x++)
    {
        if(ValidClient(x) && !IsSourceTV(x) && GetClientTeam(x)!=OurTeam)
        {
            new Handle:dmgRound = hMatchDamage[CurrentRound];
            new dmgSize = GetArraySize(dmgRound);
            new dmgTo = 0;
            new dmgHits = 0;
            new String:clName[24];
            GetClientName(x, clName, 24);
            for(new y=0;y<dmgSize;y++)
            {
                new String:Att[24];
                new String:Vic[24];
                new Handle:singleDmg = GetArrayCell(dmgRound, y);
                GetArrayString(singleDmg, 0, Att, 24);
                GetArrayString(singleDmg, 1, Vic, 24);
                new dM = GetArrayCell(singleDmg, 2);
                new IndAtt = ClientOfSteamId(Att);
                new IndVic = ClientOfSteamId(Vic);
                if(ValidClient(IndAtt) && ValidClient(IndVic) && IndAtt==client && IndVic==x)
                {
                    dmgTo+=dM;
                    dmgHits++;
                }
            }
            PrintToChat(client, "%s %s - Damage Given: %d (%d hits)", MSG_PREFIX, clName, dmgTo, dmgHits);
        }
    }
    
}

LogDmg(Attacker, Victim, Dmg)
{
    if(!MatchLive())
    {
        return;
    }
    if(CurrentRound<1)
    {
        return;
    }
    new String:AttackerSteam[24];
    new String:VictimSteam[24];
    GetClientAuthString(Attacker, AttackerSteam, 24);
    GetClientAuthString(Victim, VictimSteam, 24);
    // Create a new array.
    new Handle:newArray = CreateArray(24);
    PushArrayString(newArray, AttackerSteam);
    PushArrayString(newArray, VictimSteam);
    PushArrayCell(newArray, Dmg);
    PushArrayCell(hMatchDamage[CurrentRound], newArray);
}

public Action:HurtCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
    // userid, attacker, dmg_health
    new VictimUserid = GetEventInt(event, "userid");
    new AttackerUserid = GetEventInt(event, "attacker");
    new VictimIndex = GetClientOfUserId(VictimUserid);
    new AttackerIndex = GetClientOfUserId(AttackerUserid);
    new Dmg = GetEventInt(event, "dmg_health");
    if(VictimIndex>0 && AttackerIndex>0 && ValidClient(VictimIndex) && ValidClient(AttackerIndex) && AttackerIndex!=VictimIndex)
    {
        LogDmg(AttackerIndex, VictimIndex, Dmg);        
    }
    return Plugin_Continue;
}

SetMoney(client, money)
{
    if(ValidClient(client) && !IsSourceTV(client))
    {
        SetEntData(client, OffsetAccount, money);
    }
}

GetMoney(client)
{
    if(ValidClient(client) && !IsSourceTV(client))
    {
        return GetEntData(client, OffsetAccount);
    }
    return 0;
}

public Action:HookSpectate(client, const String:command[], argc) 
{
    // MAKE them not ready
    bReady[client] = false;
    notReadyTime[client] = GetTime();
    
    new MyTeam = CSLTeam(client); // check if they are on a team, they should stay there, or disconnect if they have to..
    if(MatchLive() && MyTeam)
    {
        //PrintCenterText(client, "PUG: You can't join spectator when match is live.");
        //return Plugin_Handled;
    }
    return Plugin_Continue;
}

ForceToSpectate(client)
{
    ForceSpec[client] = true;
    ChangeClientTeam(client, CS_TEAM_SPEC);
    PrintToChat(client, "%s You died and have been moved to spectate.", MSG_PREFIX);
}

OurAutojoin(client)
{
    // Which team are we supposed to be on?
    // Have the teams been setup yet?
    if(TeamsSetup())
    {
        new MyTeam = CSLTeam(client);
        if(MyTeam!=-1)
        {
            // Join the team we are on.
            if(GetClientTeam(client)!=CSLToCSTeam(MyTeam))
            {
                ChangeClientTeam(client, CSLToCSTeam(MyTeam));
            }
        }
        else
        {
            // Find a team for us.
            // What team has less active players?
            new String:steamID[24];
            GetClientAuthString(client, steamID, 24);
            new APTeamA = TeamSizeActive(TEAM_A);
            new APTeamB = TeamSizeActive(TEAM_B);
            if(APTeamA<APTeamB)
            {
                // Team A
                AddSteamToTeam(steamID, TEAM_A);
            }
            else if(APTeamB<APTeamA)
            {
                // Team B
                AddSteamToTeam(steamID, TEAM_B);
            }
            else
            {
                // Random
                new RandTeam = GetRandomInt(TEAM_A, TEAM_B);
                AddSteamToTeam(steamID, RandTeam);
            }
            MyTeam = CSLTeam(client);
            if(MyTeam!=-1)
            {
                // Join the team we are on.
                if(GetClientTeam(client)!=CSLToCSTeam(MyTeam))
                {
                    ChangeClientTeam(client, CSLToCSTeam(MyTeam));
                }
            }
        }
    }
}

TryGoT(client)
{
    if(TeamsSetup())
    {
        new MyTeam = CSLTeam(client);
        if(MyTeam!=-1)
        {
            // Join the team we are on.
            if(CSLToCSTeam(MyTeam)!=CS_TEAM_T)
            {
                PrintCenterText(client, "HG: You are on Team %s, they are currently Counter-Terrorist.", ((MyTeam==TEAM_A)?"A":"B"));
            }
            if(GetClientTeam(client)!=CSLToCSTeam(MyTeam))
            {
                ChangeClientTeam(client, CSLToCSTeam(MyTeam)); 
            }
        }
        else
        {
            // They clearly want to be a Terrorist, which team is T?
            new TCSL = CSTeamToCSL(CS_TEAM_T);
            new CTCSL = CSTeamToCSL(CS_TEAM_CT);
            new ATCount = TeamSizeActive(TCSL);
            new ACTCount = TeamSizeActive(CTCSL);
            new String:steamID[24];
            GetClientAuthString(client, steamID, 24);
            if(ATCount <= ACTCount)
            {
                // Let them, and add them to the team.
                AddSteamToTeam(steamID, TCSL);
                if(GetClientTeam(client)!=CS_TEAM_T)
                {
                    ChangeClientTeam(client, CS_TEAM_T);
                }
            }
            else
            {
                // They gotta go CT, add em and tell em the bad news :(
                PrintCenterText(client, "HG: Sorry, you have been forced to Team %s, the Counter-Terrorists.", ((CTCSL==TEAM_A)?"A":"B"));
                AddSteamToTeam(steamID, CTCSL);
                if(GetClientTeam(client)!=CS_TEAM_CT)
                {
                    ChangeClientTeam(client, CS_TEAM_CT);
                }
            }
        }
    }
}

CSLToCSTeam(cslTeam)
{
/*
    MS_Before_First_Half, // This is only used if the map changes.
    MS_Live_First_Half,
    MS_Before_Second_Half, // Always used. Team A is CT B is T
    MS_Live_Second_Half,    // Team A is CT team B is T
    MS_Before_Overtime_First_Half, // Team A is T, Team B is CT
    MS_Live_Overtime_First_Half, // Team A is T, Team B is CT
    MS_Before_Overtime_Second_Half, // Team A is CT, Team B is T
    MS_Live_Overtime_Second_Half, // Team A is CT, Team B is T
*/
    // This might need an edit when captains come along?
    if(gMatchState==MS_Live_First_Half)
    {
        if(cslTeam==TEAM_A)
        {
            return CS_TEAM_T;
        }
        else
        {
            return CS_TEAM_CT;
        }
    }
    else if(gMatchState==MS_Before_Second_Half || gMatchState==MS_Live_Second_Half)
    {
        if(cslTeam==TEAM_A)
        {
            return CS_TEAM_CT;
        }
        else
        {
            return CS_TEAM_T;
        }
    }
    else if(gMatchState==MS_Before_Overtime_First_Half || gMatchState==MS_Live_Overtime_First_Half)
    {
        if(cslTeam==TEAM_A)
        {
            return CS_TEAM_CT;
        }
        else
        {
            return CS_TEAM_T;
        }
    }
    else if(gMatchState==MS_Before_Overtime_Second_Half || gMatchState==MS_Live_Overtime_Second_Half)
    {
        if(cslTeam==TEAM_A)
        {
            return CS_TEAM_T;
        }
        else
        {
            return CS_TEAM_CT;
        }
    }
    else
    {
        return -1;
    }
}

CSTeamToCSL(csTeam)
{
    if(CSLToCSTeam(TEAM_A) == csTeam)
    {
        return TEAM_A;
    }
    else
    {
        return TEAM_B;
    }
}

TryGoCT(client)
{
    if(TeamsSetup())
    {
        new MyTeam = CSLTeam(client);
        if(MyTeam!=-1)
        {
            // Join the team we are on.
            if(CSLToCSTeam(MyTeam)!=CS_TEAM_CT)
            {
                PrintCenterText(client, "HG: You are on Team %s, they are currently Terrorist.", ((MyTeam==TEAM_A)?"A":"B"));
            }
            if(GetClientTeam(client)!=CSLToCSTeam(MyTeam))
            {
                ChangeClientTeam(client, CSLToCSTeam(MyTeam));
            }
        }
        else
        {
            // They clearly want to be a Counter-Terrorist, which team is CT?
            new TCSL = CSTeamToCSL(CS_TEAM_T);
            new CTCSL = CSTeamToCSL(CS_TEAM_CT);
            new ATCount = TeamSizeActive(TCSL);
            new ACTCount = TeamSizeActive(CTCSL);
            new String:steamID[24];
            GetClientAuthString(client, steamID, 24);
            if(ACTCount <= ATCount)
            {
                // Let them, and add them to the team.
                AddSteamToTeam(steamID, CTCSL);
                if(GetClientTeam(client)!=CS_TEAM_CT)
                {
                    ChangeClientTeam(client, CS_TEAM_CT);
                }
            }
            else
            {
                // They gotta go CT, add em and tell em the bad news :(
                PrintCenterText(client, "HG: Sorry, you have been forced to Team %s, the Terrorists.", ((TCSL==TEAM_A)?"A":"B"));
                AddSteamToTeam(steamID, TCSL);
                if(GetClientTeam(client)!=CS_TEAM_T)
                {
                    ChangeClientTeam(client, CS_TEAM_T);
                }
            }
        }
    }
}

public Action:HookJoinTeam(client, const String:command[], argc) 
{
    // Destined team
    new String:firstParam[16];
    GetCmdArg(1, firstParam, 16);
    StripQuotes(firstParam);
    new firstParamNumber = StringToInt(firstParam);
    if(!ValidClient(client) || IsFakeClient(client) || IsSourceTV(client))
    {
        return Plugin_Continue;        
    }
    
    if(ForceSpec[client]) // for captain deaths found only
    {
        if(GetClientTeam(client)!=CS_TEAM_SPEC)
        {
            ChangeClientTeam(client, CS_TEAM_SPEC);
        }
        PrintCenterText(client, "HG: You're DEAD! Wait till the captain round is over.");
        return Plugin_Handled;
    }

    if(firstParamNumber == CS_TEAM_SPEC)
    {
        // make them not ready
        bReady[client] = false;
        notReadyTime[client] = GetTime();
        // No.
        //PrintCenterText(client, "PUG: You can't join spectator.");
        //return Plugin_Handled;
        /*if(CaptainMode && gMatchState==MS_Before_First_Half && ValidClient(KnifeWinner) && ValidClient(KnifeWinner2)) // put the captains on the right team
        {
            if(KnifeWinner==client)
            {
                PrintCenterText(client, "HG: You're a Captain.");
                ChangeClientTeam(client, CaptainTeam);
                return Plugin_Handled;
            }
            else if(KnifeWinner2==client)
            {
                PrintCenterText(client, "HG: You're a Captain.");
                if(CaptainTeam==CS_TEAM_T)
                {
                    ChangeClientTeam(client, CS_TEAM_CT);
                    return Plugin_Handled;
                }
                else
                {
                    ChangeClientTeam(client, CS_TEAM_T);
                    return Plugin_Handled;
                }
            }
            return Plugin_Continue;
        }
        else
        {
            return Plugin_Continue;
        }*/
        return Plugin_Continue;
    }
    else if(firstParamNumber == CS_TEAM_T)
    {
        // if teams are full dont allow them to join, i.e. spectators trying to join
        new ActivePlayers = TeamSizeActive(CSTeamToCSL(CS_TEAM_T)) + TeamSizeActive(CSTeamToCSL(CS_TEAM_CT));
        if(ActivePlayers > GetConVarInt(hMaxPlayers) || GetTeamClientCount(CS_TEAM_T) >= 5)
        {
            PrintCenterText(client, "HG: Team is full, you have been moved to spectate.");
            ChangeClientTeam(client, CS_TEAM_SPEC);
            return Plugin_Handled;
        }
        
        notReadyTime[client] = GetTime();
        
        if(TeamsSetup())
        {
            TryGoT(client);
        }
        else
        {
            /*if(CaptainMode && gMatchState==MS_Before_First_Half && ValidClient(KnifeWinner)) // put the captains on the right team
            {
                if(KnifeWinner==client && CaptainTeam!=CS_TEAM_T)
                {
                    PrintCenterText(client, "HG: You're Captain for Counter-Terrorist.");
                    ChangeClientTeam(client, CS_TEAM_CT);
                    return Plugin_Handled;
                }
                else if(KnifeWinner2==client && CaptainTeam==CS_TEAM_T)
                {
                    PrintCenterText(client, "HG: You're Captain for Counter-Terrorist.");
                    ChangeClientTeam(client, CS_TEAM_CT);
                    return Plugin_Handled;
                }
                return Plugin_Continue;
            }
            else
            {
                return Plugin_Continue;
            }*/
            return Plugin_Continue;
        }
    }
    else if(firstParamNumber == CS_TEAM_CT)
    {
        // if teams are full dont allow them to join, i.e. spectators trying to join
        new ActivePlayers = TeamSizeActive(CSTeamToCSL(CS_TEAM_T)) + TeamSizeActive(CSTeamToCSL(CS_TEAM_CT));
        if(ActivePlayers > GetConVarInt(hMaxPlayers) || GetTeamClientCount(CS_TEAM_CT) >= 5)
        {
            PrintCenterText(client, "HG: Team is full.");
            ChangeClientTeam(client, CS_TEAM_SPEC);
            return Plugin_Handled;
        }
        
        notReadyTime[client] = GetTime();
        
        if(TeamsSetup())
        {
            TryGoCT(client);
        }
        else
        {
            /*if(CaptainMode && gMatchState==MS_Before_First_Half && ValidClient(KnifeWinner)) // put the captains on the right team
            {
                if(KnifeWinner==client && CaptainTeam!=CS_TEAM_CT)
                {
                    PrintCenterText(client, "HG: You're Captain for Terrorist.");
                    ChangeClientTeam(client, CS_TEAM_T);
                    return Plugin_Handled;
                }
                else if(KnifeWinner2==client && CaptainTeam==CS_TEAM_CT)
                {
                    PrintCenterText(client, "HG: You're Captain for Terrorist.");
                    ChangeClientTeam(client, CS_TEAM_T);
                    return Plugin_Handled;
                }
                return Plugin_Continue;
            }
            else
            {
                return Plugin_Continue;
            }*/
            return Plugin_Continue;
        }
    }
    else // Autojoin, our own version.
    {
        // if teams are full dont allow them to join, i.e. spectators trying to join
        new ActivePlayers = TeamSizeActive(CSTeamToCSL(CS_TEAM_T)) + TeamSizeActive(CSTeamToCSL(CS_TEAM_CT));
        if(ActivePlayers > GetConVarInt(hMaxPlayers))
        {
            PrintCenterText(client, "HG: Teams are full.");
            ChangeClientTeam(client, CS_TEAM_SPEC);
            return Plugin_Handled;
        }
        
        notReadyTime[client] = GetTime();
        
        if(TeamsSetup())
        {
            OurAutojoin(client);
        }
        else
        {
            /*if(CaptainMode && gMatchState==MS_Before_First_Half && ValidClient(KnifeWinner)) // put the captains on the right team
            {
                if(KnifeWinner==client)
                {
                    PrintCenterText(client, "HG: You're a Captain.");
                    ChangeClientTeam(client, CaptainTeam);
                    return Plugin_Handled;
                }
                else if(KnifeWinner2==client)
                {
                    PrintCenterText(client, "HG: You're a Captain.");
                    if(CaptainTeam==CS_TEAM_T)
                    {
                        ChangeClientTeam(client, CS_TEAM_CT);
                        return Plugin_Handled;
                    }
                    else
                    {
                        ChangeClientTeam(client, CS_TEAM_T);
                        return Plugin_Handled;
                    }
                }
                return Plugin_Continue;
            }
            else
            {
                return Plugin_Continue;
            }*/
            return Plugin_Continue;
        }
    }
    return Plugin_Handled;
}

public Action:HookBuy(client, const String:command[], argc) 
{
    // Destined team
    new String:firstParam[16];
    GetCmdArg(1, firstParam, 16);
    StripQuotes(firstParam);
    if(ReadyUpState() || gMatchState<MS_Before_First_Half)
    {
        if(StrEqual(firstParam,"flashbang") || StrEqual(firstParam,"hegrenade") || StrEqual(firstParam,"smokegrenade"))
        {
            PrintCenterText(client, "HG: No grenades during %s.", ((ReadyUpState()) ? "warm up" : "captain round"));
            return Plugin_Handled;
        }
    }
    
    return Plugin_Continue;
}

ClearMatch()
{
    ServerCommand("tv_stoprecord\n"); // Leet, MIRITE?!
    SetHostnameLive(false);
    if(RestartTimers!=INVALID_HANDLE)
    {
        CloseHandle(RestartTimers);
    }
    RoundCounterOn = false;
    ChangeMatchState(MS_Pre_Setup);
    TeamAScore = 0;
    TeamBScore = 0;
    CurrentRound = 0;
    Format(MatchMap, 32, "");
    for(new x=0;x<MAX_ROUNDS;x++)
    {
        if(hMatchDamage[x]!=INVALID_HANDLE)
        {
            // How big is the array?
            new s = GetArraySize(hMatchDamage[x]);
            for(new y=0;y<s;y++)
            {
                new Handle:aAt = GetArrayCell(hMatchDamage[x], y);
                CloseHandle(aAt);
            }
            CloseHandle(hMatchDamage[x]);
            hMatchDamage[x] = INVALID_HANDLE;
        }
        if(hMatchKills[x]!=INVALID_HANDLE)
        {
            new s = GetArraySize(hMatchKills[x]);
            for(new y=0;y<s;y++)
            {
                new Handle:aAt = GetArrayCell(hMatchKills[x], y);
                CloseHandle(aAt);
            }
            CloseHandle(hMatchKills[x]);
            hMatchKills[x] = INVALID_HANDLE;
        }
    }
    Ruleset = Rules_PUG;
    RandomizerMode = false;
    CaptainMode = false;
    BunnyHopMode = false;
    KnifeWinner = 0;
    KnifeWinner2 = 0;
    CaptainTeam = 0;
    for(new x=0;x<TEAM_COUNT;x++)
    {
        Format(TeamPlayers[x][0], 24, "");
        Format(TeamPlayers[x][1], 24, "");
        Format(TeamPlayers[x][2], 24, "");
        Format(TeamPlayers[x][3], 24, "");
        Format(TeamPlayers[x][4], 24, "");
    }
    EnforceKnifeOnly(false); // unhooks all players, allows buyzone and weapons  
    for(new i=1;i<=MAXPLAYERS;i++)
    {
        ForceSpec[i] = false;
    }
    
    ResetMoneyStorage();
}

GetMapCount()
{
    new mapCount = 0;
    for(new x=0;x<MAX_MAPS;x++)
    {
        if(!StrEqual(MapNames[x],""))
        {
            mapCount++;
        }
    }
    return mapCount;
}

stock AddToOurMaps(const String:mapName[])
{
    for(new x=0;x<MAX_MAPS;x++)
    {
        if(StrEqual(MapNames[x],""))
        {
            Format(MapNames[x], 32, mapName);
            break;
        }
    }
}

LoadMapCycle()
{
    if (ReadMapList(g_MapList,
					 g_mapFileSerial, 
					 "mapchooser",
					 MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER)
		!= INVALID_HANDLE)
		
	{
		if (g_mapFileSerial == -1)
		{
			LogError("Unable to create a valid map list.");
		}
	}
    decl String:map[32];
    for (new i = 0; i < GetArraySize(g_MapList); i++)
	{
	   GetArrayString(g_MapList, i, map, sizeof(map));
	   Format(MapNames[i], 32, map);
    }
}

stock LoadMapsDir()
{
    // Build path and look for .bsp files.
    new String:mapsDir[1024];
    BuildPath(Path_SM, mapsDir, 1024, "../../maps/");
    new String:path[1024];
    new Handle:dir = OpenDirectory(mapsDir);
    new FileType:type;
    while(ReadDirEntry(dir, path, sizeof(path), type))
    {
        if(type == FileType_File && StrContains(path, ".bsp") != -1)
        {
            // How many dots in the path?
            new len = strlen(path);
            new periods = 0;
            for(new x=0;x<len;x++)
            {
                if(path[x]=='.')
                {
                    periods++;
                }
            }
            if(periods==1)
            {
                ReplaceString(path, 1024, ".bsp", "", false);
                AddToOurMaps(path);
            }
        }
    }
    CloseHandle(dir);
}

GoPostgame(winning_team, bool:forfeit = false)
{
    RoundCounterOn = false;
    // Send stats?
    ChangeMatchState(MS_Post_Match);
        
    // TODO
    new bool:tie=(winning_team==-1)?true:false;
    if(tie)
    {
        forfeit = false; // Just incase? never used?
    }
    if(forfeit)
    {
        PrintToServer("PUG: Match ended in Forfeit.")
    }
    // Show everyone their stats page.
    
    ClearMatch();
}

MatchWinForfeit(winning_team)
{
    PrintToChatAll("%s %s wins due to forfeit", MSG_PREFIX, (winning_team==TEAM_A)?"Team A":"Team B");
    GoPostgame(winning_team, true);
}

MatchWin(winning_team)
{
    // Was the winning_team T or CT?
    new WinningScore = (winning_team==TEAM_A)?TeamAScore:TeamBScore;
    new LosingScore = (winning_team==TEAM_A)?TeamBScore:TeamAScore;
    PrintToChatAll("%s Match is over, %s wins the match %d - %d", MSG_PREFIX, (winning_team==TEAM_A)?"Team A":"Team B", WinningScore, LosingScore);
    
    GoPostgame(winning_team);
}

MatchWinOT(winning_team)
{
    // Was the winning_team T or CT?
    new WinningScore = (winning_team==TEAM_A)?TeamAScore:TeamBScore;
    new LosingScore = (winning_team==TEAM_A)?TeamBScore:TeamAScore;
    PrintToChatAll("%s Overtime is over, %s wins the match %d - %d", MSG_PREFIX, (winning_team==TEAM_A)?"Team A":"Team B", WinningScore, LosingScore);
    
    GoPostgame(winning_team);
}

MatchTieOT()
{
    PrintToChatAll("%s Match ends in a tie, %d - %d", MSG_PREFIX, TeamAScore, TeamBScore);
    GoPostgame(-1);
}

DeleteBomb()
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i))
        {
            new iWeapon = GetPlayerWeaponSlot(i, 4);
            
            if (iWeapon != -1 && IsValidEdict(iWeapon))
            {
                decl String:szClassName[64];
                GetEdictClassname(iWeapon, szClassName, sizeof(szClassName));
                
                if (StrEqual(szClassName, "weapon_c4"))
                {
                    RemovePlayerItem(i, iWeapon);
                    RemoveEdict(iWeapon);
                }
            }
        }
    }

}

bool:IsPubChatMuted(client)
{
    return bPubChatMuted[client];
}

bool:IsTeamChatMuted(client)
{
    return bTeamChatMuted[client];
}

bool:IsPlayerMuted(client, player)
{
    return bMuted[client][player];
}

TryTranslatePlace(const String:input[], String:output[], maxlen)
{
    new bool:bOtherCheck = false;
    if(StrEqual(input, "CTSpawn"))
    {
        Format(output, maxlen, "CT Spawn");
    }
    else if(StrEqual(input, "TSpawn"))
    {
        Format(output, maxlen, "T Spawn")
    }
    else
    {
        bOtherCheck = true;
    }
    if(!bOtherCheck)
    {
        return;
    }
    new len=strlen(input);
    // Clear the output.
    Format(output, maxlen, "");
    new bool:bPrevHadSpace = true;
    new bool:bPrevWasIndi = true;
    for(new x=0;x<len;x++)
    {
        if(input[x]==' ')
        {
            bPrevWasIndi = false;
            if(bPrevHadSpace)
            {
                bPrevHadSpace = false;
            }
            else
            {
                Format(output, maxlen, "%s ", output);
                bPrevHadSpace = true;
            }
        }
        else if( (input[x]>='A' && input[x]<='Z') || (input[x]>='1' && input[x]<='9'))
        {
            if(bPrevWasIndi)
            {
                Format(output, maxlen, "%s%c", output, input[x]);
                bPrevHadSpace = false;
            }
            else
            {
                if(bPrevHadSpace)
                {
                    Format(output, maxlen, "%s%c", output, input[x]);
                    bPrevHadSpace = false;
                }
                else
                {
                    Format(output, maxlen, "%s %c", output, input[x]);
                    bPrevHadSpace = true;
                }
            }
            bPrevWasIndi = true;
        }
        else
        {
            bPrevWasIndi = false;
            if(bPrevHadSpace)
            {
                bPrevHadSpace = false;
            }
            Format(output, maxlen, "%s%c", output, input[x]);
        }
    }
}

ChatMsg(client, bool:team, const String:chatMsg[])
{
    if(!ValidClient(client))
    {
        return;
    }
    new cTeam = GetClientTeam(client);
    if(cTeam<CS_TEAM_SPEC || cTeam>CS_TEAM_CT)
    {
        return;
    }
    new String:cTeamName[32];
    if(cTeam == CS_TEAM_T)
    {
        Format(cTeamName, 32, "Terrorist");
    }
    else if(cTeam == CS_TEAM_CT)
    {
        Format(cTeamName, 32, "Counter-Terrorist");
    }
    else
    {
        Format(cTeamName, 32, "Spectator");
    }
    new bool:bAlive = IsPlayerAlive(client);
    new String:fullChat[250];
    new String:sPlaceName[64];
    new String:sNewPlaceName[64];
    new String:plName[64];
    GetClientName(client, plName, 64);
    GetEntPropString(client, Prop_Data, "m_szLastPlaceName", sPlaceName, 64);
    TryTranslatePlace(sPlaceName, sNewPlaceName, 64);

    LogMessage("%L %s", client, chatMsg);
    LogToGame("%L %s", client, chatMsg);

    if(bAlive)
    {
        if(team)
        {
            if(StrEqual(sNewPlaceName, ""))
            {
                Format(fullChat, 250, "\x01(%s) \x03%s\x01 : %s", cTeamName, plName, chatMsg);
            }
            else
            {
                Format(fullChat, 250, "\x01(%s) \x03%s\x01 @ \x04%s\x01 : %s", cTeamName, plName, sNewPlaceName, chatMsg);    
            }
        }
        else
        {
            Format(fullChat, 250, "\x03%s\x01 : %s", plName, chatMsg);
        }
    }
    else
    {
        if(team)
        {
            if(cTeam==CS_TEAM_SPEC)
            {
                Format(fullChat, 250, "\x01(%s) \x03%s\x01 : %s", cTeamName, plName, chatMsg);
            }
            else
            {
                Format(fullChat, 250, "\x01*DEAD*(%s) \x03%s\x01 : %s", cTeamName, plName, chatMsg);
            }
        }
        else
        {
            if(cTeam==CS_TEAM_SPEC)
            {
                Format(fullChat, 250, "\x01*SPEC* \x03%s\x01 : %s", plName, chatMsg);
            }
            else
            {
                Format(fullChat, 250, "\x01*DEAD* \x03%s\x01 : %s", plName, chatMsg);
            }
        }
    }
    
    // Console friendly.
    // But first clean it up a bit ;]
    new String:fullChatClean[250];
    Format(fullChatClean, 250, "%s", fullChat);
    ReplaceString(fullChatClean, 250, "\x01", "");
    ReplaceString(fullChatClean, 250, "\x02", "");
    ReplaceString(fullChatClean, 250, "\x03", "");
    ReplaceString(fullChatClean, 250, "\x04", "");
    PrintToServer("%s", fullChatClean);
    
    for(new x=1;x<=MAXPLAYERS;x++)
    {
        if(!ValidClient(x) || IsFakeClient(x))
        {
            continue;
        }
        new bool:bForMe = true;
        if(team && GetClientTeam(x) != cTeam)
        {
            bForMe = false;
        }
        if(!bAlive)
        {
            if(IsPlayerAlive(x))
            {
                bForMe = false;
            }
        }
        if(IsPlayerMuted(x, client))
        {
            bForMe = false;
        }
        if(team && IsTeamChatMuted(x))
        {
            bForMe = false;
        }
        if(!team && IsPubChatMuted(x))
        {
            bForMe = false;
        }
        if(bForMe)
        {
            if(StrEqual(GameName,GameCSGO,false)) {            
                new Handle:pb = StartMessageOne("SayText2", x);
                if (pb != INVALID_HANDLE)
                {                
                    PbSetInt(pb, "ent_idx", client);
                    PbSetBool(pb, "chat", true);
                    PbSetString(pb, "msg_name", fullChat);
                    PbAddString(pb, "params", "");
                    PbAddString(pb, "params", "");
                    PbAddString(pb, "params", "");
                    PbAddString(pb, "params", "");
                    EndMessage();

                    PrintToConsole(x, fullChatClean);
                }
            }
            else
            {
                new Handle:hBuffer = StartMessageOne("SayText2", x);

                EndMessage();
            }            
        }
    }
}

public OnPluginStart()
{
    //detect the source/ob Game
    GameCSS = "cstrike";
    GameCSGO = "csgo";
    
    GetGameFolderName(GameName, sizeof(GameName));
    
    HookEvent("server_cvar", Event_ServerCvar, EventHookMode_Pre);
    new arraySize = ByteCountToCells(33);
    g_MapList = CreateArray(arraySize);
    ServerCommand("exec server_pug.cfg\n");
    OffsetAccount = FindSendPropOffs("CCSPlayer", "m_iAccount");
    hMaxPlayers = CreateConVar("sv_maxplayers", MAX_PLAYERS_DEFAULT, "Match size.", FCVAR_PLUGIN|FCVAR_SPONLY);
    hTournamentMode = CreateConVar("sv_pug_tournament", "0", "Enable/Disable Tournament Mode.", FCVAR_PLUGIN|FCVAR_SPONLY);
    TournamentMode = GetConVarInt(hTournamentMode) ? true : false;
    CreateConVar("sm_pug_version", "1.4", "PUG Plugin Version",FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    hTVEnabled = FindConVar("tv_enable");
    hBotQuota = FindConVar("bot_quota");
    hHostname = FindConVar("hostname");
    if(StrEqual(GameName,GameCSS,false)) {
        hHintSound = FindConVar("sv_hudhint_sound");
    }

    if(StrEqual(GameName,GameCSGO,false)) {
        hFlashBangLimit = FindConVar("ammo_grenade_limit_flashbang");
        SetConVarInt(hFlashBangLimit, 2);
        
        hSpecSlotLimit = FindConVar("mp_spectators_max");
        SetConVarInt(hSpecSlotLimit, 12);
    }
    
    hStartMoney = FindConVar("mp_startmoney");
    SetConVarInt(hBotQuota, 0);
    if(StrEqual(GameName,GameCSS,false)) {
        SetConVarInt(hHintSound, 0);
    }
    ownerOffset = FindSendPropOffs("CBaseCombatWeapon", "m_hOwnerEntity");
    
    //SetConVarInt(hTVEnabled, 1);
    ClearMatch();
    new Handle:hTagsCvar = FindConVar("sv_tags");
    new oldFlags = GetConVarFlags(hTagsCvar);
    new newFlags = oldFlags;
    newFlags &= ~FCVAR_NOTIFY;
    SetConVarFlags(hTagsCvar, newFlags);
    //new Handle:hTVName = FindConVar("tv_name");
    //SetConVarString(hTVName, "PUG SourceTV");
    //new Handle:hTVTrans = FindConVar("tv_transmitall");
    CreateTimer(4.0, WarmUpSpawner, _, TIMER_REPEAT);
    //SetConVarInt(hTVTrans, 1);
    LoadMapCycle();
    //LoadMapsDir();
    HookEvent("player_spawn",SpawnCallback);
    HookEvent("player_death",DeathCallback);
    HookEvent("player_hurt",HurtCallback);
    HookEvent("round_start",RoundStartCallback);
    HookEvent("round_end",RoundEndCallback);    
    HookEvent("match_end_conditions", EndConditionsCallback);
	HookEvent("round_freeze_end", Event_Round_Freeze_End);
    AddCommandListener(HookJoinTeam, "jointeam");
    AddCommandListener(HookSpectate, "spectate");
    AddCommandListener(HookBuy, "buy");
    for(new x=0;x<MAXPLAYERS+1;x++) //[0-64]
    {
        ClientDefaults(x);
    }
    // Hooks
    RegConsoleCmd("say",SayPubHook);
    RegConsoleCmd("say_team",SayTeamHook);
    
    RegAdminCmd("endgame", Command_EndGame, ADMFLAG_KICK);
    
    if(StrEqual(GameName,GameCSGO,false)) {
        CreateTimer(2.0, OneSecCheckPanel, _, TIMER_REPEAT);
    }
    else {
        CreateTimer(2.0, OneSecCheck, _, TIMER_REPEAT);
    }


    //SetCommandFlags("sm",  FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_CHEAT);
    //SetCommandFlags("meta",  FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_CHEAT);

    hmeta = FindConVar("metamod_version");
    hsm = FindConVar("sourcemod_version");
    hpug = FindConVar("sm_pug_version");
    hnmap = FindConVar("sm_nextmap");
    RemoveNotify();
    //AddCommandListener(Block, "sm");
    //AddCommandListener(Block, "meta");
    CreateTimer(3.0, RemoveGroundWeapons, INVALID_HANDLE, TIMER_REPEAT);
    
    // Initialize Updater
    InitializeUpdater();
}

enum ConnAction
{
    ConnAction_Connect_NonMember = 0,
    ConnAction_Connect_Member,
    ConnAction_Disconnect,
};

bool:MatchLive()
{
    if(gMatchState == MS_Live_First_Half || gMatchState == MS_Live_Second_Half || gMatchState == MS_Live_Overtime_First_Half || gMatchState == MS_Live_Overtime_Second_Half)
    {
        return true;
    }
    return false;
}

public T_NoCallback(Handle:owner,Handle:hndl,const String:error[],any:data)
{
    // pst... it's quiet... too quiet? maybe log errors?
}

public StatsCallback(Handle:owner,Handle:hndl,const String:error[],any:data)
{
    new client=GetClientOfUserId(data);
    if(!ValidClient(client))
    {
        return;
    }
    if(hndl!=INVALID_HANDLE)
    {
        SQL_Rewind(hndl);
        if(!SQL_FetchRow(hndl))
        {
            PrintToChat(client, "%s Sorry, username doesn't exist.", MSG_PREFIX);
        }
        else
        {
            new steamid;
            SQL_FieldNameToNum(hndl, "steamid", steamid);
            new String:steam[24];
            SQL_FetchString(hndl, steamid, steam, 24);
            new String:fullURL[192];
            Format(fullURL, 192, "http://stats.hellsgamers.com/stats.php?steam=%s", steam);
            ShowMOTDPanel(client, "Stats", fullURL, MOTDPANEL_TYPE_URL);
        }
    }
}
        
StartAuth(client)
{
    if(!ValidClient(client) || IsSourceTV(client) || IsClientSourceTV(client))
    {
        return;        
    }
    if(!AllowBots() && IsFakeClient(client))
    {
        Kick(client,"No bots!"); // No bots stupid.    
        return;
    }
    notReadyTime[client] = GetTime();
    // Make sure they are a customer.
    decl String:steamID[24];
    GetClientAuthString(client, steamID, 24);
    if(BadSteamId(steamID))
    {
        Kick(client,"Your STEAMID isn't valid.");
        return;
    }

    notReadyTime[client] = GetTime();
    // Is the match already live? If it is put this person on a team etc...
    // TODO: This will need to be changed once we have a captain mode.
    if(TeamsSetup())
    {
        //debug DISABLED BELOW
        //OurAutojoin(client);
    }
    
    if(KnifeOnly)
    {
        ClientKnifeOnly(client);
    }
}

bool:IsSourceTV(client)
{
    if(!ValidClient(client))
        return false;
    decl String:plName[64];
    GetClientName(client, plName, 64);
    if(IsFakeClient(client) && ( StrEqual(plName,"SourceTV") || StrEqual(plName,"HG SourceTV") ))
    {
        return true;
    }
    return false;
}

public OnClientPutInServer(client)
{
    ClientDefaults(client);
    if(IsSourceTV(client))
        return; // Don't auth the SourceTV dude! :P
    new cCount = GetClientCount();
    if(GetConVarInt(hTVEnabled)==1)
        cCount -= 1;
    /*if(cCount>GetConVarInt(hMaxPlayers))
    {
        Kick(client, "Sorry, this match is full");
        return;
    }*/
    StartAuth(client);
}

ClientOfSteamId(const String:steamID[])
{
    for(new x=1;x<=MAXPLAYERS;x++)
    {
        if(ValidClient(x) && !IsSourceTV(x))
        {
            new String:mySteam[24];
            GetClientAuthString(x, mySteam, 24);
            if(StrEqual(steamID, mySteam))
            {
                return x;
            }
        }
    }
    return 0;
}

TeamOfSteamId(const String:steamID[])
{
    // Return of -1 indicates none yet.
    for(new x=0;x<TEAM_COUNT;x++)
    {
        for(new y=0;y<5;y++)
        {
            if(StrEqual(steamID, TeamPlayers[x][y]))
            {
                return x;
            }
        }
    }
    return -1;
}

public Action:DisconnectDelayed(Handle:timer)
{
    new bool:AnyOnline = false;
    for(new i=1;i<=MaxClients;i++) {
		if(IsClientConnected(i) && !IsFakeClient(i)) {
            AnyOnline = true;
		}
	}
    
    if(!AnyOnline)
    {
        MatchWinForfeit(TEAM_A);
    }
}

public OnClientDisconnect(client)
{
    bDisconnecting[client] = true;
    
    new bool:specialCase = false;
    
    if(IsFakeClient(client) && !IsSourceTV(client)) {
        specialCase = true;
    }
    
    if(IsSourceTV(client))
        return;

    if(MatchLive() || (gMatchState>=MS_Setup_Pre_Captain_Round && gMatchState<=MS_Setup_Post_Captain_Round))
    {
        CreateTimer(0.01, DisconnectDelayed);
        new bool:AnyOnline = false;
        
        new String:steamID[24];
        GetClientAuthString(client, steamID, 24);
        new TeamAB = TeamOfSteamId(steamID);
        if(TeamAB==-1)
        {
            return; // They we're on a team yet.
        }
        // Is anyone else on their team still there? If not, the match has been forfeited.
        for(new x=0;x<5;x++)
        {
            new cOfSteam = ClientOfSteamId(TeamPlayers[TeamAB][x]);
            if(ValidClient(cOfSteam) && client!=cOfSteam)
            {
                AnyOnline = true;
            }    
        }
        if(!AnyOnline && !specialCase)
        {
            MatchWinForfeit( (TeamAB==TEAM_A) ? TEAM_B : TEAM_A );
        }
    }
    /*else
    {
        // TODO: If we are picking teams? 
    }*/
}

public OnMapStart()
{
    TournamentMode = GetConVarInt(hTournamentMode) ? true : false;
    ServerCommand("mp_do_warmup_period 0");
    ServerCommand("mp_maxrounds 0");
    ServerCommand("bot_quota 0");
    ServerCommand("bot_kick");
    ChangeCvar("mp_freezetime", "0");
    ChangeCvar("mp_roundtime", "9");
    
    if(TournamentMode) // for tournament mode?
    {     
        new String:curmap[32];
        GetCurrentMap(curmap, 32);
        Format(MatchMap, 32, curmap);
    }
}

public Action:Event_ServerCvar(Handle:event, const String:name[], bool:dontBroadcast) {
    return Plugin_Handled;
}

RemoveNotify()
{
    UnNotify(hmeta);
    UnNotify(hsm);
    UnNotify(hpug);
    UnNotify(hnmap);
}

UnNotify(Handle:cvar)
{
    new flags = GetConVarFlags(cvar);
    if (flags & FCVAR_NOTIFY) // Remove notify if needed
    {
        //SetConVarFlags(cvar, flags ^ FCVAR_NOTIFY);
        SetConVarFlags(cvar, flags & ~FCVAR_NOTIFY);
    } 
}

public Action:Block(client, const String:command[], argc)
{
    return Plugin_Handled;
}

public EndConditionsCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
    PrintToServer("HG: EndConditionsCallback");

    //return Plugin_Continue;
}

public Action:Command_EndGame(client, args)
{
    if(client <= 0) {
        return;
    }

    PrintToChatAll("%s Game Reset.", MSG_PREFIX);
    GoPostgame(-1);

    return;
}

SetMoneyStorage()
{
    for(new x=0;x<TEAM_COUNT;x++)
    {
        for(new y=0;y<5;y++)
        {
            new client = ClientOfSteamId(TeamPlayers[x][y]);
            if(ValidClient(client) && GetClientTeam(client) > 1)
            {
                new money = GetMoney(client);
                Format(TeamPlayersMoney[x][y], 5, "%i", money);
                //PrintToChatAll("%s set money %i", MSG_PREFIX, GetMoney(client)); // debug
                //PrintToServer("DEBUG: client: %i TeamPlayersMoney[%i][%i] = %s saved money to %i", client, x, y, TeamPlayers[x][y], money); // debug
            }
        }
    }
}

ResetMoneyStorage()
{
    for(new x=0;x<TEAM_COUNT;x++)
    {
        for(new y=0;y<5;y++)
        {
            new client = ClientOfSteamId(TeamPlayers[x][y]);
            if(ValidClient(client))
            {
                new money = 0;
                Format(TeamPlayersMoney[x][y], 5, "%i", money);
                //PrintToServer("DEBUG: client: %i TeamPlayersMoney[%i][%i] = %s reset money to %i", client, x, y, TeamPlayers[x][y], money); // debug
            }
        }
    }
}

SetHostnameLive(bool:live=false)
{
    decl String:hostname[256];
    GetConVarString(hHostname, hostname, sizeof(hostname));
    
    if(live)
    {
        Format(hostname, sizeof(hostname), "%s -LIVE-", hostname);
    }
    else
    {
        ReplaceString(hostname, sizeof(hostname), " -LIVE-", "", false);
    }
    // set new server name
    SetConVarString(hHostname, hostname, false, false);
}

String:GetServerIp()
{
    decl String:hostip[16];
    new longip = GetConVarInt(FindConVar("hostip"));
    Format(hostip, 16, "%i_%i_%i_%i", (longip >> 24) & 0x000000FF,
                                           (longip >> 16) & 0x000000FF,
                                           (longip >>  8) & 0x000000FF,
                                            longip        & 0x000000FF);
    return hostip;
}

GetServerPort()
{
    return GetConVarInt(FindConVar("hostport"));
}
