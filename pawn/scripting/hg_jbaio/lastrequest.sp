
// Constants.
#define LOCALDEF_LR_CONTINUE_CHECKING 0
#define LOCALDEF_LR_ALL_INTERFERENCE_HANDLED 1
#define LOCALDEF_LR_ATTACKER_INTERFERED 2
#define LOCALDEF_LR_VICTIM_GOT_INTERFERED_WITH 3

// LR Game Data.
new Handle:g_hLRs = INVALID_HANDLE;
new Handle:g_hSubLRs = INVALID_HANDLE;
new Handle:g_hLRStartFunctions = INVALID_HANDLE;
new Handle:g_hLREndFunctions = INVALID_HANDLE;
new Handle:g_hLRData = INVALID_HANDLE;
new Handle:g_hLRIgnoreDamage = INVALID_HANDLE;
new Handle:g_hLRAllowedWeapons = INVALID_HANDLE;

// LR Player Data.
new Handle:g_hLRTs = INVALID_HANDLE;
new Handle:g_hLRCTs = INVALID_HANDLE;
new Handle:g_hLRPlaying = INVALID_HANDLE;
new Handle:g_hLRWinners = INVALID_HANDLE;

new g_iIsS4SInUse;

new g_iLRTeamColors[2][4] = {{255, 0, 0, 255},      // Red
                             {0, 0, 255, 255}};     // Blue

#include "hg_jbaio/lrs/cleaver.sp"
#include "hg_jbaio/lrs/charizard.sp"
#include "hg_jbaio/lrs/chicken_fight.sp"
#include "hg_jbaio/lrs/climb.sp"
#include "hg_jbaio/lrs/custom.sp"
#include "hg_jbaio/lrs/deagtoss.sp"
#include "hg_jbaio/lrs/dodgeball.sp"
#include "hg_jbaio/lrs/fragwars.sp"
#include "hg_jbaio/lrs/fountain_jump.sp"
#include "hg_jbaio/lrs/headshot.sp"
#include "hg_jbaio/lrs/horseman.sp"
#include "hg_jbaio/lrs/hot_potatoe.sp"
#include "hg_jbaio/lrs/knifefight.sp"
#include "hg_jbaio/lrs/mag4mag.sp"
#include "hg_jbaio/lrs/noscope.sp"
#include "hg_jbaio/lrs/obstacle_race.sp"
#include "hg_jbaio/lrs/race.sp"
#include "hg_jbaio/lrs/rebel.sp"
#include "hg_jbaio/lrs/rock_paper_scissors.sp"
#include "hg_jbaio/lrs/russian_roulette.sp"
#include "hg_jbaio/lrs/shot4shot.sp"
#include "hg_jbaio/lrs/starwars.sp"
#include "hg_jbaio/lrs/throwingknives.sp"
#include "hg_jbaio/lrs/golf.sp"


new g_iWantsToLR[MAXPLAYERS + 1];
new g_iLRColors[9][4] = {{255, 75, 75, 255},        // Red
                         {75, 75, 255, 255},        // Blue
                         {75, 255, 75, 255},        // Green
                         {255, 128, 0, 255},        // Orange
                         {255, 75, 75, 255},        // Red
                         {255, 75, 75, 255},        // Red
                         {255, 75, 75, 255},        // Red
                         {255, 75, 75, 255},        // Red
                         {255, 75, 75, 255}};       // Red

new Handle:g_hLRBeacon = INVALID_HANDLE;
new Handle:g_hBuildFromArray[MAXPLAYERS + 1];
new Handle:g_hLRCountDown[MAXPLAYERS + 1];

new String:g_sChoosingLR[MAXPLAYERS + 1][MAX_NAME_LENGTH];

/* ----- Events ----- */

LR_OnPluginStart()
{
    g_hLRTs = CreateArray();
    g_hLRCTs = CreateArray();
    g_hLRWinners = CreateArray();
    g_hLRPlaying = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
    g_hLRs = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));

    g_hSubLRs = CreateTrie();
    g_hLRStartFunctions = CreateTrie();
    g_hLREndFunctions = CreateTrie();
    g_hLRData = CreateTrie();
    g_hLRIgnoreDamage = CreateTrie();
    g_hLRAllowedWeapons = CreateTrie();

    // Working on TF2
    RegisterLR("Rebel", RBL_OnLRStart, RBL_OnLREnd);
    RegisterLR("Custom LR", CL_OnLRStart, CL_OnLREnd);
    RegisterLR("Legally Blind Fight", KF_OnLRStart, KF_OnLREnd, "Knife Fight", "blind", "knife,holy_mackerel,tf_weapon_bat_fish,knife_t,bayonet,knifegg");
    RegisterLR("Speedy Knife Fight", KF_OnLRStart, KF_OnLREnd, "Knife Fight", "speedy", "knife,holy_mackerel,tf_weapon_bat_fish,knife_t,bayonet,knifegg");
    RegisterLR("Sudden Death Knife Fight", KF_OnLRStart, KF_OnLREnd, "Knife Fight", "sudden death", "knife,holy_mackerel,tf_weapon_bat_fish,knife_t,bayonet,knifegg");
    RegisterLR("Tank Knife Fight", KF_OnLRStart, KF_OnLREnd, "Knife Fight", "tank", "knife,apocofists,fists,knife_t,bayonet,knifegg");
    RegisterLR("Third Person Knives", KF_OnLRStart, KF_OnLREnd, "Knife Fight", "thirdperson", "knife,holy_mackerel,tf_weapon_bat_fish,knife_t,bayonet,knifegg");
    RegisterLR("Vanilla Knife Fight", KF_OnLRStart, KF_OnLREnd, "Knife Fight", "vanilla", "knife,holy_mackerel,tf_weapon_bat_fish,knife_t,bayonet,knifegg");

    RegisterLR("Race", Race_OnLRStart, Race_OnLREnd);
    RegisterLR("Rock-Paper-Scissors", RPS_OnLRStart, RPS_OnLREnd);
    RegisterLR("Fountain Jump", FJ_OnLRStart, FJ_OnLREnd);
    RegisterLR("Golf", Golf_OnLRStart, Golf_OnLREnd);

    if (g_iGame == GAMETYPE_CSGO)
    {
        RegisterLR("NEG EV SW", SW_OnLRStart, SW_OnLREnd, "Star Wars", "weapon_negev", "negev");
        RegisterLR("Nova Toss", DT_OnLRStart, DT_OnLREnd, "Guntoss", "weapon_nova");
        RegisterLR("HK P2000 S4S", S4S_OnLRStart, S4S_OnLREnd, "Shot-4-Shot", "weapon_hkp2000", "hkp2000,usp,usp_silencer,usp_silencer_off");
        RegisterLR("HK P2000 HSO", HS_OnLRStart, HS_OnLREnd, "Headshot Only", "weapon_hkp2000", "hkp2000,usp,usp_silencer,usp_silencer_off");
        RegisterLR("Shotgun HSO", HS_OnLRStart, HS_OnLREnd, "Headshot Only", "weapon_nova", "nova");
        RegisterLR("P250 S4S", S4S_OnLRStart, S4S_OnLREnd, "Shot-4-Shot", "weapon_p250", "p250");
        RegisterLR("MP7 S4S", S4S_OnLRStart, S4S_OnLREnd, "Shot-4-Shot", "weapon_mp7", "mp7");
        RegisterLR("HK P200 M4M", M4M_OnLRStart, M4M_OnLREnd, "Mag-4-Mag", "weapon_hkp2000", "hkp2000,usp,usp_silencer,usp_silencer_off");
        RegisterLR("P250 M4M", M4M_OnLRStart, M4M_OnLREnd, "Mag-4-Mag", "weapon_p250", "p250");
        RegisterLR("MP7 M4M", M4M_OnLRStart, M4M_OnLREnd, "Mag-4-Mag", "weapon_mp7", "mp7");
        RegisterLR("Tec-9 M4M", M4M_OnLRStart, M4M_OnLREnd, "Mag-4-Mag", "weapon_tec9", "tec9");
        RegisterLR("SCAR No Scope", NS_OnLRStart, NS_OnLREnd, "No Scope", "weapon_scar20", "scar20");
        RegisterLR("SSG 08 No Scope", NS_OnLRStart, NS_OnLREnd, "No Scope", "weapon_ssg08", "ssg08");
        RegisterLR("Scouts Knives", KF_OnLRStart, KF_OnLREnd, "Knife Fight", "ssg08", "knife,ssg08,knife_t,bayonet,knifegg");
        RegisterLR("Molotov Cockwar", FW_OnLRStart, FW_OnLREnd, "", "weapon_molotov", "molotov,inferno");
        RegisterLR("Climb Race", Climb_OnLRStart, Climb_OnLREnd);
    }

    else if (g_iGame == GAMETYPE_CSS)
    {
        RegisterLR("M3 Toss", DT_OnLRStart, DT_OnLREnd, "Guntoss", "weapon_m3");
        RegisterLR("USP S4S", S4S_OnLRStart, S4S_OnLREnd, "Shot-4-Shot", "weapon_usp", "usp");
        RegisterLR("USP HSO", HS_OnLRStart, HS_OnLREnd, "Headshot Only", "weapon_usp", "usp");
        RegisterLR("Shotgun HSO", HS_OnLRStart, HS_OnLREnd, "Headshot Only", "weapon_m3", "m3");
        RegisterLR("P228 S4S", S4S_OnLRStart, S4S_OnLREnd, "Shot-4-Shot", "weapon_p228", "p228");
        RegisterLR("MP5Navy S4S", S4S_OnLRStart, S4S_OnLREnd, "Shot-4-Shot", "weapon_mp5navy", "mp5navy");
        RegisterLR("USP M4M", M4M_OnLRStart, M4M_OnLREnd, "Mag-4-Mag", "weapon_usp", "usp");
        RegisterLR("P228 M4M", M4M_OnLRStart, M4M_OnLREnd, "Mag-4-Mag", "weapon_p228", "p228");
        RegisterLR("MP5Navy M4M", M4M_OnLRStart, M4M_OnLREnd, "Mag-4-Mag", "weapon_mp5navy", "mp5navy");
        RegisterLR("SG550 No Scope", NS_OnLRStart, NS_OnLREnd, "No Scope", "weapon_sg550", "sg550");
        RegisterLR("Scout No Scope", NS_OnLRStart, NS_OnLREnd, "No Scope", "weapon_scout", "scout");
        RegisterLR("Scouts Knives", KF_OnLRStart, KF_OnLREnd, "Knife Fight", "scout", "knife,scout");
        RegisterLR("Acid-Trip Knife Fight", KF_OnLRStart, KF_OnLREnd, "Knife Fight", "acid", "knife");
        RegisterLR("Dizzy Knife Fight", KF_OnLRStart, KF_OnLREnd, "Knife Fight", "dizzy", "knife");
    }

    if (g_iGame == GAMETYPE_TF2)
    {
        RegisterLR("Cleaver Fight", CLE_OnLRStart, CLE_OnLREnd, "", "", "bleed_kill,guillotine,tf_weapon_cleaver,cleaver");
        RegisterLR("Guntoss", DT_OnLRStart, DT_OnLREnd);

        RegisterLR("Pistol HSO", HS_OnLRStart, HS_OnLREnd, "Headshot Only", "pistol", "pistol_scout,tf_weapon_pistol_scout");
        RegisterLR("Minigun HSO", HS_OnLRStart, HS_OnLREnd, "Headshot Only", "minigun", "brass_beast,minigun");
        RegisterLR("Huntsman HSO", HS_OnLRStart, HS_OnLREnd, "Headshot Only", "huntsman", "huntsman,tf_projectile_arrow");

        RegisterLR("Pistol S4S", S4S_OnLRStart, S4S_OnLREnd, "Shot-4-Shot", "pistol", "pistol_scout,tf_weapon_pistol_scout");
        RegisterLR("Huntsman S4S", S4S_OnLRStart, S4S_OnLREnd, "Shot-4-Shot", "huntsman", "huntsman,tf_projectile_arrow");
        RegisterLR("Headless Horseman", HM_OnLRStart, HM_OnLREnd, "", "", "Sword,tf_weapon_sword");
    }

    else
    {
        RegisterLR("Charizard", CZ_OnLRStart, CZ_OnLREnd, "", "", "knife,ent_fire,point_hurt,knife_t,knifegg,bayonet");

        RegisterLR("Auto Shotty SW", SW_OnLRStart, SW_OnLREnd, "Star Wars", "weapon_xm1014", "xm1014");
        RegisterLR("Mac Daddy SW", SW_OnLRStart, SW_OnLREnd, "Star Wars", "weapon_mac10", "mac10");
        RegisterLR("Para SW", SW_OnLRStart, SW_OnLREnd, "Star Wars", "weapon_m249", "m249");

        RegisterLR("Deagle Toss", DT_OnLRStart, DT_OnLREnd, "Guntoss", "weapon_deagle");
        RegisterLR("M4A1 Toss", DT_OnLRStart, DT_OnLREnd, "Guntoss", "weapon_m4a1");
        RegisterLR("Para Toss", DT_OnLRStart, DT_OnLREnd, "Guntoss", "weapon_m249");

        RegisterLR("Deagle HSO", HS_OnLRStart, HS_OnLREnd, "Headshot Only", "weapon_deagle", "deagle");
        RegisterLR("Glock HSO", HS_OnLRStart, HS_OnLREnd, "Headshot Only", "weapon_glock", "glock");
        RegisterLR("Para HSO", HS_OnLRStart, HS_OnLREnd, "Headshot Only", "weapon_m249", "m249");

        RegisterLR("Deagle S4S", S4S_OnLRStart, S4S_OnLREnd, "Shot-4-Shot", "weapon_deagle", "deagle");
        RegisterLR("AK-47 S4S", S4S_OnLRStart, S4S_OnLREnd, "Shot-4-Shot", "weapon_ak47", "ak47");
        RegisterLR("M4A1 S4S", S4S_OnLRStart, S4S_OnLREnd, "Shot-4-Shot", "weapon_m4a1", "m4a1");
        RegisterLR("Bonbon G3SG1 S4S", S4S_OnLRStart, S4S_OnLREnd, "Shot-4-Shot", "weapon_g3sg1", "g3sg1");

        RegisterLR("Deagle M4M", M4M_OnLRStart, M4M_OnLREnd, "Mag-4-Mag", "weapon_deagle", "deagle");
        RegisterLR("AK-47 M4M", M4M_OnLRStart, M4M_OnLREnd, "Mag-4-Mag", "weapon_ak47", "ak47");
        RegisterLR("M4A1 M4M", M4M_OnLRStart, M4M_OnLREnd, "Mag-4-Mag", "weapon_m4a1", "m4a1");
        RegisterLR("Bonbon G3SG1 M4M", M4M_OnLRStart, M4M_OnLREnd, "Mag-4-Mag", "weapon_g3sg1", "g3sg1");

        RegisterLR("AWP No Scope", NS_OnLRStart, NS_OnLREnd, "No Scope", "weapon_awp", "awp");
        RegisterLR("Bonbon G3SG1 No Scope", NS_OnLRStart, NS_OnLREnd, "No Scope", "weapon_g3sg1", "g3sg1");

        RegisterLR("Chicken Fight", CF_OnLRStart, CF_OnLREnd);
        RegisterLR("Frag Wars", FW_OnLRStart, FW_OnLREnd, "", "weapon_hegrenade", "hegrenade");
        RegisterLR("Hot Potato", HP_OnLRStart, HP_OnLREnd);
        RegisterLR("Backstab Only Knife Fight", KF_OnLRStart, KF_OnLREnd, "Knife Fight", "backstab", "knife,knifegg,knife_t,bayonet");
        RegisterLR("Obstacle Race", OR_OnLRStart, OR_OnLREnd, "", "", "flashbang,smokegrenade");
        RegisterLR("Dodgeball", DB_OnLRStart, DB_OnLREnd, "", "", "flashbang");

        RegisterLR("Russian Roulette", RR_OnLRStart, RR_OnLREnd, "", "", "deagle");

        RegisterLR("Throwing Knives", TK_OnLRStart, TK_OnLREnd, "", "", "point_hurt,tknife,ctknife");
    }

    CL_OnPluginStart();
    DT_OnPluginStart();
    RR_OnPluginStart();
    Golf_OnPluginStart();

    RegConsoleCmd("sm_lr", Command_LR);
    RegConsoleCmd("sm_customlr", Command_CustomLR);

    SortADTArray(g_hLRs, Sort_Ascending, Sort_String);
}

LR_OnClientDisconnect(client)
{
    StopLR(client);
    CL_OnClientDisconnect();
}

LR_OnRoundEnd()
{
    while (GetArraySize(g_hLRTs))
        StopLR(GetArrayCell(g_hLRTs, 0));
}

bool:LR_OnWeaponCanUse(client, weapon)
{
    if (GetIndex(client) == -1)
        return true;

    if (!DT_OnWeaponCanUse(client, weapon))
        return false;

    if (!Golf_OnWeaponCanUse(client, weapon))
        return false;

    return true;
}

LR_OnPlayerDamagedOrDied(victim, attacker, bool:kill, const String:weapon[], bool:skipForTF2)
{
    // If the victim is a rebel...
    if (IsRebel(victim))
        return;

    // If there is a CUSTOM LR going on now...
    new toDo = LOCALDEF_LR_CONTINUE_CHECKING;
    if (CL_IsThereACustomLrNow())
    {
        // Get LR participation info for attacker & victim.
        new bool:attackerIsInCustomLr = CL_IsInCustomLr(attacker);
        new bool:victimIsInCustomLr = CL_IsInCustomLr(victim);

        // If this damage event involves somebody in a CUSTOM LR...
        if (attackerIsInCustomLr || victimIsInCustomLr)
        {
            toDo = CL_OnTakeDamage(victim, attacker, victimIsInCustomLr, attackerIsInCustomLr, kill);
            if (toDo == LOCALDEF_LR_ALL_INTERFERENCE_HANDLED)
                return;
        }
    }

    // Make sure the LR ends no matter what if there's a death (unless it's custom LR)
    if (kill)
        CreateTimer(0.1, Timer_EndLRForDeath, GetClientUserId(victim));

    // Ensure attacker is in-game and not on the same team as the victim.
    if (attacker != victim && attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))
    {
        new attackerTeam = GetClientTeam(attacker);
        new victimTeam = GetClientTeam(victim);

        if (attackerTeam != victimTeam)
        {
            // Get LR participation info for attacker & victim.
            new tIndex  = FindValueInArray(g_hLRTs,  attackerTeam == TEAM_PRISONERS ? attacker : victim);
            new ctIndex = FindValueInArray(g_hLRCTs, attackerTeam == TEAM_GUARDS    ? attacker : victim);
            new bool:attackerIsInLr = (attackerTeam == TEAM_PRISONERS ? tIndex != -1 : ctIndex != -1);
            new bool:victimIsInLr   = (victimTeam   == TEAM_PRISONERS ? tIndex != -1 : ctIndex != -1);

            // We shouldn't end a CTs LR if he shoots a rebel... That's just silly.
            if ((victimTeam == TEAM_PRISONERS &&
                !IsRebel(victim) &&
                !g_bIsInvisible[victim]) || 
                attackerTeam == TEAM_PRISONERS)
            {
                // Do we have any tasks to finish up from the CUSTOM LR?
                if (toDo == LOCALDEF_LR_ATTACKER_INTERFERED && attackerIsInLr)
                {
                    PrintToChatAll("%s \x03%N\x04's ruined his LR by interfering with \x03%N",
                                   MSG_PREFIX, attacker, victim);

                    StopLR(attacker);
                    return;
                }

                if (toDo == LOCALDEF_LR_VICTIM_GOT_INTERFERED_WITH && victimIsInLr)
                {
                    PrintToChatAll("%s \x03%N\x04's LR was cancelled because of interference from \x03%N",
                                   MSG_PREFIX, victim, attacker);

                    StopLR(victim);
                    return;
                }
            }

            //
            // If we've reached this point, neither the victim nor the attacker are involved with a CUSTOM LR.
            //

            // If this damage event involves somebody in a REGULAR LR...
            if (attackerIsInLr || victimIsInLr)
            {
                LR_OnTakeDamage(victim, attacker, victimIsInLr, attackerIsInLr, kill, attackerTeam, tIndex, ctIndex, weapon, skipForTF2);
                return;
            }

            //
            // This damage event does NOT involve anybody in an REGULAR LR.
            //

            // If the attacker is a Prisoner -- he is rebelling.
            if (attackerTeam == TEAM_PRISONERS)
                MakeRebel(attacker, kill);

            // The attacker is a Guard -- he is freeshooting.
            else
            {
                if (kill)
                    RebelTrk_OnGuardKilledPrisoner(attacker, victim);
                else
                    RebelTrk_OnGuardHurtPrisoner(attacker, victim);
            }
        }
    }
}

LR_OnTakeDamage(victim, attacker, victimIsInLr, attackerIsInLr, bool:kill, attackerTeam, tIndex, ctIndex, const String:weapon[], bool:skipForTF2)
{
    // Find out if they are LR partners.
    new tClient;
    new ctClient;
    new bool:theyAreInSameLr = false;

    if (attackerIsInLr && victimIsInLr)
    {
        tClient  = (tIndex  == -1 ? 0 : GetArrayCell(g_hLRTs,  tIndex));
        ctClient = (ctIndex == -1 ? 0 : GetArrayCell(g_hLRCTs, ctIndex));
        theyAreInSameLr = (attackerTeam == TEAM_PRISONERS ? victim == ctClient : victim == tClient);
    }

    if (IsInLR(attacker, "Rebel") || IsInLR(victim, "Rebel"))
        return;

    // If they ARE LR partners...
    if (theyAreInSameLr)
    {
        if (skipForTF2)
            return;

        //
        // Even in non-violent LR's (like deagle-toss), the winner can kill the loser.
        //
        // If the attacker is the winner...
        if (FindValueInArray(g_hLRWinners, attacker) >= 0)
        {
            // If the winner killed the loser, stop the LR and provide the reward.
            if (kill)
            {
                // Make winner, give rep, and notify all.
                MakeWinner(attacker);
                StopLR(attacker);
            }
        }

        // If the attacker is not the winner...
        else
        {
            //
            // Some LR's allow participants to attack each other.
            //

            // Get the name of the LR.
            decl String:lr[MAX_NAME_LENGTH];
            GetArrayString(g_hLRPlaying, tIndex, lr, sizeof(lr));

            // We need to see if this LR is one of those that allows attacking.
            new bool:ignore;
            GetTrieValue(g_hLRIgnoreDamage, lr, ignore);

            // If the attacker is ALLOWED to shoot his LR partner...
            if (ignore)
            {
                //
                // Since this LR is about killing each other, killing is OK.
                //

                // If the attacker won by killing the victim...
                if (kill)
                {
                    // Make winner, give rep, and notify all.
                    MakeWinner(attacker);
                    StopLR(attacker);
                }
            }

            // If the attacker is NOT allowed to shoot his LR partner...
            else
            {
                //
                // HOWEVER, some LR's allow the Prisoner to attack the Guard with a particular weapon.
                //

                // What is the allowed weapon for this LR?
                decl String:allowed[256];
                GetTrieString(g_hLRAllowedWeapons, lr, allowed, sizeof(allowed));

                // debug
                //PrintToChatAll(weapon);

                // If the weapon that was used is *NOT* allowed for this LR...
                if ((StrEqual(allowed, "") ||
                    StrContains(allowed, weapon, false) == -1) &&
                    !(g_iGame == GAMETYPE_CSGO &&
                    (StrContains(allowed, "knife") > -1) &&
                    ((StrContains(weapon, "knife") > -1) || (StrContains(weapon, "bayonet") > -1))))
                {
                    // The attacker should not have shot the victim.
                    PrintToChatAll("%s \x03%N\x04's LR was cancelled because of foul play by \x03%N\x04 against \x03%N",
                                   MSG_PREFIX, tClient, attacker, victim);
                    StopLR(attacker);

                    // Try to prevent further damage by this mean person.
                    // This crashes during LR on CS:GO, and I don't know why
                    // See the function for the exact lines

                    if (g_iGame == GAMETYPE_CSS)
                        StripWeps(attacker, false);

                    // If the attacker is a Prisoner -- he is rebelling...
                    if (attackerTeam == TEAM_PRISONERS)
                        MakeRebel(attacker, kill);

                    // If the attacker is a Guard -- he is freeshooting...
                    else
                    {
                        if (kill)
                            RebelTrk_OnGuardKilledPrisoner(attacker, victim);
                        else
                            RebelTrk_OnGuardHurtPrisoner(attacker, victim);
                    }
                }

                // If the weapon that was used *IS* allowed for this LR...
                else
                {
                    // If the attacker won by killing the victim...
                    if (kill)
                    {
                        // Make winner, give rep, and notify all.
                        MakeWinner(attacker);
                        StopLR(attacker);
                    }
                }
            }
        }
    }

    // If they are NOT LR partners...
    else
    {
        // If the victim was in an LR of his own (a different LR)...
        // But again, if the T was a rebel, no LR should end.

        if (!IsRebel(victim))
        {
            if (victimIsInLr)
            {
                // The attacker should not have shot the victim.
                PrintToChatAll("%s \x03%N\x04's LR was cancelled due to interference from \x03%N",
                               MSG_PREFIX, victim, attacker);
                StopLR(victim);
            }

            // If the attacker was in an LR of his own (a different LR)...
            if (attackerIsInLr)
            {
                // The attacker should not have shot the victim.
                PrintToChatAll("%s \x03%N\x04 ruined their LR by interfering with \x03%N",
                               MSG_PREFIX, attacker, victim);

                StopLR(attacker);
            }

            // Try to prevent further damage by this mean person.
            // Although during LR this crashes the server.
            // See the function for which lines
            if (g_iGame == GAMETYPE_CSS)
                StripWeps(attacker, false);

            // If the attacker is a Prisoner -- he is rebelling.
            if (attackerTeam == TEAM_PRISONERS)
                MakeRebel(attacker, kill);

            // The attacker is a Guard -- he is freeshooting.
            else
            {
                if (kill)
                    RebelTrk_OnGuardKilledPrisoner(attacker, victim);
                else
                    RebelTrk_OnGuardHurtPrisoner(attacker, victim);
            }
        }
    }
}



/* ----- Functions ----- */


bool:IsInLR(client, const String:to_check[])
{
    new index = GetIndex(client);

    if (index == -1)
        return false;

    decl String:lr[MAX_NAME_LENGTH];
    GetArrayString(g_hLRPlaying, index, lr, sizeof(lr));

    return StrEqual(to_check, lr);
}

CountDownLR(t, ct, time, callback)
{
    if (g_iGame == GAMETYPE_TF2)
    {
        SetEntityHealth(t, TF2_GetMaxHealth(t));
        SetEntityHealth(ct, TF2_GetMaxHealth(ct));
    }

    else
    {
        SetEntityHealth(t, 100);
        SetEntityHealth(ct, 100);

        SetEntProp(t, Prop_Send, "m_ArmorValue", 100);
        SetEntProp(ct, Prop_Send, "m_ArmorValue", 100);
    }

    StripWeps(t, false);
    StripWeps(ct, false);

    new Handle:data = CreateArray();

    PushArrayCell(data, time);
    PushArrayCell(data, t);
    PushArrayCell(data, ct);
    PushArrayCell(data, callback);

    PrintCenterText(t, "%d", time);
    PrintCenterText(ct, "%d", time);

    SetEntityMoveType(t, MOVETYPE_NONE);
    SetEntityMoveType(ct, MOVETYPE_NONE);

    g_hLRCountDown[t] = CreateTimer(1.0, Timer_CountDownLR, data, TIMER_REPEAT);
}

TeleportToS4S(t, ct)
{
    new one = GetRandomInt(0, 1) ? t : ct;
    new two = one == t ? ct : t;

    decl Float:dummy[4];

    if (g_iIsS4SInUse && 
        GetTrieArray(g_hDbCoords, "S4S 3", dummy, sizeof(dummy)) &&
        GetTrieArray(g_hDbCoords, "S4S 4", dummy, sizeof(dummy)))
    {
        Tele_DoClient(0, one, "S4S 3", false);
        Tele_DoClient(0, two, "S4S 4", false);
    }

    else
    {
        Tele_DoClient(0, one, "S4S 1", false);
        Tele_DoClient(0, two, "S4S 2", false);

        g_iIsS4SInUse = t;
    }
}

bool:IsElligibleCT(client)
{
    if (!IsClientInGame(client) ||
        GetClientTeam(client) != TEAM_GUARDS ||
        !JB_IsPlayerAlive(client) ||
        FindValueInArray(g_hLRCTs, client) > -1 ||
        CL_IsInCustomLr(client))
        return false;
    return true;
}

GetIndex(client)
{
    new index = FindValueInArray(g_hLRTs, client);
    if (index > -1)
        return index;

    return FindValueInArray(g_hLRCTs, client);
}

GetPartner(client)
{
    if (GetClientTeam(client) == TEAM_PRISONERS)
        return GetArrayCell(g_hLRCTs, GetIndex(client));

    return GetArrayCell(g_hLRTs, GetIndex(client));
}

ChoosePlayerToLR(client, const String:lr[])
{
    new Handle:menu = CreateMenu(ChoosePlayerToLRSelect);

    SetMenuTitle(menu, "Choose Your Opponent");
    SetMenuExitBackButton(menu, true);

    new bool:any;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsElligibleCT(i))
            continue;

        decl String:sUserid[8];
        IntToString(GetClientUserId(i), sUserid, sizeof(sUserid));

        decl String:name[MAX_NAME_LENGTH];
        GetClientName(i, name, sizeof(name));

        any = true;
        AddMenuItem(menu, sUserid, name);
    }

    if (!any)
        AddMenuItem(menu, "", "No eligible CTs", ITEMDRAW_DISABLED);

    DisplayMenu(menu, client, MENU_TIMEOUT_NORMAL);
    Format(g_sChoosingLR[client], MAX_NAME_LENGTH, lr);
}

GiveWinRep(client)
{
    PrisonRep_AddPoints(client, GetConVarInt(g_hCvLrWinRep));
}

MakeWinner(client, bool:message=true)
{
    PushArrayCell(g_hLRWinners, client);
    GiveWinRep(client);

    if (g_iGame == GAMETYPE_TF2)
    {
        SetEntityHealth(client, TF2_GetMaxHealth(client));
        TF2_GiveFullAmmo(client);
    }

    else
    {
        SetEntityHealth(client, 100);

        StripWeps(client);
        CreateTimer(0.3, Timer_GiveWinWeapons, client);
    }

    new index = GetIndex(client);
    if (index == -1)
        return;

    new t = GetArrayCell(g_hLRTs, index);
    new ct = GetArrayCell(g_hLRCTs, index);
    new other = (client == t ? ct : t);

    // Strip other's weapons.
    new Handle:data = CreateDataPack();
    WritePackCell(data, other);
    WritePackCell(data, 1);
    CreateTimer(0.3, StripWeapsDelay, any:data);

    if (message)
    {
        decl String:lr[MAX_NAME_LENGTH];
        GetArrayString(g_hLRPlaying, index, lr, sizeof(lr));

        PrintToChatAll("%s \x03%N\x04 won against \x03%N\x04 in a \x05%s",
                       MSG_PREFIX, client, other, lr);
    }

    if (JB_IsPlayerAlive(other))
    {
        // If the loser was a T, make them a rebel so anyone can kill him.
        if (GetClientTeam(other) == TEAM_PRISONERS)
        {
            // make them permanently a rebel
            g_bIsInvisible[other] = true;

            SetEntityRenderMode(other, RENDER_TRANSCOLOR);
            SetEntityRenderColor(other, 255, 0, 0, 255);
        }

        // Otherwise, we don't want CTs delaying.
        else
            SetEntPropFloat(other, Prop_Data, "m_flLaggedMovementValue", 0.5);
    }
}

StopLR(client)
{
    // Client can be EITHER member of an LR (the T or the CT).
    new index = GetIndex(client);
    if (index == -1)
        return;

    new t = GetArrayCell(g_hLRTs, index);
    new ct = GetArrayCell(g_hLRCTs, index);

    if (g_iIsS4SInUse == t)
        g_iIsS4SInUse = 0;

    decl String:lr[MAX_NAME_LENGTH];
    GetArrayString(g_hLRPlaying, index, lr, sizeof(lr));

    RemoveFromArray(g_hLRTs, index);
    RemoveFromArray(g_hLRCTs, index);
    RemoveFromArray(g_hLRPlaying, index);

    decl Function:end;
    GetTrieValue(g_hLREndFunctions, lr, end);

    Call_StartFunction(INVALID_HANDLE, end);

    Call_PushCell(t);
    Call_PushCell(ct);

    Call_Finish();

    new winner_index;
    while ((winner_index = FindValueInArray(g_hLRWinners, t)) > -1)
        RemoveFromArray(g_hLRWinners, winner_index);

    while ((winner_index = FindValueInArray(g_hLRWinners, ct)) > -1)
        RemoveFromArray(g_hLRWinners, winner_index);

    if (ct > 0 && JB_IsPlayerAlive(ct))
    {
        SetEntityRenderMode(ct, RENDER_TRANSCOLOR);
        SetEntityRenderColor(ct, 255, 255, 255, 255);
        UnfreezePlayer(ct);
    }

    if (JB_IsPlayerAlive(t))
    {
        if (!IsRebel(t))
        {
            SetEntityRenderMode(t, RENDER_TRANSCOLOR);     // This said "client" before, instead of "t"
            SetEntityRenderColor(t, 255, 255, 255, 255);   // This said "client" before, instead of "t"
        }

        UnfreezePlayer(t);
    }

    if (!GetArraySize(g_hLRTs) && g_hLRBeacon != INVALID_HANDLE)
    {
        CloseHandle(g_hLRBeacon);
        g_hLRBeacon = INVALID_HANDLE;
    }

    if (g_hLRCountDown[t] != INVALID_HANDLE)
        CloseHandle(g_hLRCountDown[t]);
    g_hLRCountDown[t] = INVALID_HANDLE;
}

stock RegisterLR(const String:name[],
                 Function:start, Function:end,
                 const String:subtype[]="", const String:data[]="",
                 const String:allowed_weapon[]="", bool:ignore_damage=false)
{
    SetTrieValue(g_hLRStartFunctions, name, start);
    SetTrieValue(g_hLREndFunctions, name, end);
    SetTrieValue(g_hLRIgnoreDamage, name, ignore_damage);
    SetTrieString(g_hLRData, name, data);
    SetTrieString(g_hLRAllowedWeapons, name, allowed_weapon);

    if (StrEqual(subtype, ""))
        PushArrayString(g_hLRs, name);

    else
    {
        if (FindStringInArray(g_hLRs, subtype) == -1)
            PushArrayString(g_hLRs, subtype);

        decl Handle:hndl;
        if (!GetTrieValue(g_hSubLRs, subtype, hndl))
            hndl = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));

        PushArrayString(hndl, name);
        SetTrieValue(g_hSubLRs, subtype, hndl);
    }
}

CreateLRMenu(client, Handle:arr, bool:back_button=false)
{
    new Handle:menu = CreateMenu(LRSelect);
    decl String:lr[MAX_NAME_LENGTH];

    SetMenuTitle(menu, "Choose your LR");
    SetMenuExitBackButton(menu, back_button);

    new alive_ts;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) &&
            JB_IsPlayerAlive(i) &&
            GetClientTeam(i) == TEAM_PRISONERS)
            alive_ts++;
    }

    for (new i = 0; i < GetArraySize(arr); i++)
    {
        GetArrayString(arr, i, lr, sizeof(lr));

        if (StrEqual(lr, "Rebel") && alive_ts != 1)
            continue;

        AddMenuItem(menu, lr, lr);
    }

    g_hBuildFromArray[client] = arr;
    DisplayMenu(menu, client, MENU_TIMEOUT_NORMAL);
}


/* ----- Commands ----- */


bool:CanLR(client, target=-1, bool:msg=true)
{
    if (!g_bHasRoundStarted)
    {
        if (msg)
            PrintToChat(client,
                        "%s You can not LR in between round end and round start",
                        MSG_PREFIX);
        return false;
    }

    if (g_iEndGame != ENDGAME_LR)
    {
        if (msg)
            PrintToChat(client, "%s It isn't LR, silly!", MSG_PREFIX);
        return false;
    }

    if (GetClientTeam(client) != TEAM_PRISONERS)
    {
        if (msg)
            PrintToChat(client, "%s Guards do not get last request.", MSG_PREFIX);
        return false;
    }

    if (!JB_IsPlayerAlive(client))
    {
        if (msg)
            PrintToChat(client,
                        "%s You must be alive to have your last request",
                        MSG_PREFIX);
        return false;
    }

    if (FindValueInArray(g_hLRTs, client) > -1)
    {
        if (msg)
            PrintToChat(client,
                        "%s You're already in an LR! Pay Attention!",
                        MSG_PREFIX);
        return false;
    }

    if (target > -1 && FindValueInArray(g_hLRCTs, target) > -1)
    {
        if (msg)
            PrintToChat(client, "%s That player is already in an LR :(", MSG_PREFIX);
        return false;
    }

    if (target > -1 && !JB_IsPlayerAlive(target))
    {
        if (msg)
            PrintToChat(client, "%s That player is no longer alive", MSG_PREFIX);
        return false;
    }

    if (target > -1 && GetClientTeam(target) != TEAM_GUARDS)
    {
        if (msg)
            PrintToChat(client, "%s That player is no longer a CT", MSG_PREFIX);
        return false;
    }

    return true;
}

public Action:Command_LR(client, args)
{
    if (!client)
        return Plugin_Continue;

    if (CanLR(client))
        CreateLRMenu(client, g_hLRs);

    return Plugin_Handled;
}

public Action:Command_CustomLR(client, args)
{
    if (!client)
        return Plugin_Continue;

    if (CanLR(client) && CL_CanCustomLR(client))
    {
        Format(g_sChoosingLR[client], MAX_NAME_LENGTH, "Custom LR");
        ChoosePlayerToLRSelect(INVALID_HANDLE, MenuAction_Select, client, -1);
    }

    return Plugin_Handled;
}


/* ----- Menus ----- */


public AcceptLRSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            new target = GetClientOfUserId(g_iWantsToLR[client]);
            if (!target)
                return;

            if (IsClientInGame(client))
                PrintToChat(target,
                            "%s Sorry... \x03%N\x04 couldn't come to your LR right now.",
                            MSG_PREFIX, client);

            else
                PrintToChat(target,
                            "%s Sorry... Someone you wanted to LR with left the server.",
                            MSG_PREFIX);
        }

        case MenuAction_Select:
        {
            new target = GetClientOfUserId(g_iWantsToLR[client]);
            if (!target)
            {
                PrintToChat(client,
                            "%s Sorry, that player has left you all alone.",
                            MSG_PREFIX);
                return;
            }

            if (!CanLR(target, client, false))
            {
                PrintToChat(target,
                            "%s \x03%N\x04 tried to accept your LR offer... But, you're no longer elligible.",
                            MSG_PREFIX, client);

                PrintToChat(client, "%s Sorry, that offer has expired.", MSG_PREFIX);
                return;
            }

            // Yes.
            if (selected == 0)
                ChoosePlayerToLRSelect(INVALID_HANDLE, MenuAction_Select, target, client);

            // No.
            else
                PrintToChat(target,
                            "%s \x03%N\x04 has declined your LR request",
                            MSG_PREFIX, client);
        }
    }
}

public ChoosePlayerToLRSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                CreateLRMenu(client, g_hBuildFromArray[client], g_hBuildFromArray[client] != g_hLRs);
        }

        case MenuAction_Select:
        {
            new target = selected;
            if (menu != INVALID_HANDLE)
            {
                decl String:sUserid[8];
                GetMenuItem(menu, selected, sUserid, sizeof(sUserid));

                target = GetClientOfUserId(StringToInt(sUserid));
                if (!target)
                {
                    PrintToChat(client,
                                "%s That player has left the server.",
                                MSG_PREFIX);
                    return;
                }

                if (CL_IsInCustomLr(target))
                {
                    PrintToChat(client,
                                "%s Sorry, that player is now in a custom LR",
                                MSG_PREFIX);
                    return;
                }
            }

            if (CanLR(client, target))
            {
                // They're a rebel and they're not choosing a bot (testing purposes).
                // So let's make the CT have to accept the LR, so the T can't aboose.

                if (IsRebel(client) &&
                    target > 0 &&
                    !IsFakeClient(target) &&
                    menu != INVALID_HANDLE)
                {
                    PrintToChat(client,
                                "%s Since you are a rebel, asking \x03%N\x04 to accept your LR...",
                                MSG_PREFIX, target);

                    decl String:title[128];
                    Format(title, sizeof(title),
                           "Accept %N's (rebel) LR?", client);

                    new Handle:amenu = CreateMenu(AcceptLRSelect);

                    SetMenuExitButton(amenu, false);
                    SetMenuTitle(amenu, title);

                    AddMenuItem(amenu, "", "Yes");
                    AddMenuItem(amenu, "", "No");

                    g_iWantsToLR[target] = GetClientUserId(client);
                    DisplayMenu(amenu, target, MENU_TIMEOUT_NORMAL);
                }

                else
                {
                    if (g_hLRBeacon == INVALID_HANDLE)
                        g_hLRBeacon = CreateTimer(1.0, Timer_LRBeacon, _, TIMER_REPEAT);

                    PushArrayCell(g_hLRTs, client);
                    PushArrayCell(g_hLRCTs, target);
                    PushArrayString(g_hLRPlaying, g_sChoosingLR[client]);

                    if (g_iGame != GAMETYPE_TF2)
                    {
                        SetEntityHealth(client, 100);
                        SetEntProp(client, Prop_Send, "m_ArmorValue", 100);
                    }

                    if (target > 0)
                    {
                        SetEntityRenderMode(target, RENDER_TRANSCOLOR);
                        SetEntityRenderColor(target, 0, 0, 255, 255);

                        PrintToChatAll("%s \x03%N\x04 has chosen to have a \x03%s\x04 with \x03%N",
                                       MSG_PREFIX, client, g_sChoosingLR[client], target);

                        if (g_iGame != GAMETYPE_TF2)
                        {
                            SetEntityHealth(target, 100);
                            SetEntProp(target, Prop_Send, "m_ArmorValue", 100);
                        }
                    }

                    else
                        PrintToChatAll("%s \x03%N\x04 has chosen to have a \x03%s",
                                       MSG_PREFIX, client, g_sChoosingLR[client], target);

                    decl Function:start;
                    GetTrieValue(g_hLRStartFunctions, g_sChoosingLR[client], start);

                    Call_StartFunction(INVALID_HANDLE, start);

                    Call_PushCell(client);
                    Call_PushCell(target);

                    decl String:arg[MAX_NAME_LENGTH];
                    GetTrieString(g_hLRData, g_sChoosingLR[client], arg, sizeof(arg));

                    Call_PushString(arg);
                    Call_Finish();

                    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
                    SetEntityRenderColor(client, 0, 0, 255, 255);
                }
            }
        }
    }
}

public LRSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                CreateLRMenu(client, g_hLRs);
        }

        case MenuAction_Select:
        {
            decl String:choice[MAX_NAME_LENGTH];
            GetMenuItem(menu, selected, choice, sizeof(choice));

            decl Handle:arr;
            if (GetTrieValue(g_hSubLRs, choice, arr))
                CreateLRMenu(client, arr, true);

            else if (CanLR(client))
            {
                if (StrEqual(choice, "Custom LR"))
                {
                    if (CL_CanCustomLR(client))
                    {
                        Format(g_sChoosingLR[client], MAX_NAME_LENGTH, "Custom LR");
                        ChoosePlayerToLRSelect(INVALID_HANDLE, MenuAction_Select, client, -1);
                    }
                }

                else if (StrEqual(choice, "Rebel"))
                {
                    Format(g_sChoosingLR[client], MAX_NAME_LENGTH, "Rebel");
                    ChoosePlayerToLRSelect(INVALID_HANDLE, MenuAction_Select, client, -1);
                }

                else
                    ChoosePlayerToLR(client, choice);
            }
        }
    }
}


/* ----- Callbacks ----- */


public Action:Timer_EndLRForDeath(Handle:timer, any:client)
{
    client = GetClientOfUserId(client);
    if (client)
        StopLR(client);
}

public Action:Timer_GiveWinWeapons(Handle:timer, any:client)
{
    if (GetPlayerWeaponSlot(client, 0) == -1)
        GivePlayerItem(client, "weapon_m4a1");

    if (GetPlayerWeaponSlot(client, 1) == -1)
        GivePlayerItem(client, "weapon_deagle");
}

public Action:Timer_LRBeacon(Handle:timer, any:data)
{
    for (new i = 0; i < GetArraySize(g_hLRTs); i++)
        CreateBeaconBlip(GetArrayCell(g_hLRTs, i), g_iLRColors[i]);

    for (new i = 0; i < GetArraySize(g_hLRCTs); i++)
        CreateBeaconBlip(GetArrayCell(g_hLRCTs, i), g_iLRColors[i]);

    return Plugin_Continue;
}

public Action:Timer_CountDownLR(Handle:timer, any:data)
{
    new time = GetArrayCell(data, 0);
    new t = GetArrayCell(data, 1);
    new ct = GetArrayCell(data, 2);
    new Function:func = GetArrayCell(data, 3);

    PrintCenterText(t, "%d", --time);
    PrintCenterText(ct, "%d", time);

    ClearArray(data);

    PushArrayCell(data, time);
    PushArrayCell(data, t);
    PushArrayCell(data, ct);
    PushArrayCell(data, func);

    if (time <= 0)
    {
        StripWeps(t, false);
        StripWeps(ct, false);

        SetEntityMoveType(t, MOVETYPE_WALK);
        SetEntityMoveType(ct, MOVETYPE_WALK);

        PrintCenterText(t, "GO!!");
        PrintCenterText(ct, "GO!!");

        Call_StartFunction(INVALID_HANDLE, func);

        Call_PushCell(t);
        Call_PushCell(ct);

        Call_Finish();

        CloseHandle(data);
        g_hLRCountDown[t] = INVALID_HANDLE;

        return Plugin_Stop;
    }

    return Plugin_Continue;
}
