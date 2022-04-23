
// ####################################################################################
// ##################################### GLOBALS ######################################
// ####################################################################################

new Handle:g_hCvSpawnWindowTime = INVALID_HANDLE;
new Handle:g_hCvFkpKills = INVALID_HANDLE;
new Handle:g_hCvFkpSeconds = INVALID_HANDLE;
new Handle:g_hCvFkpDuration = INVALID_HANDLE;
new Handle:g_hCvAdminMaxMuteRounds = INVALID_HANDLE;
new Handle:g_hCvAdminMaxGagRounds = INVALID_HANDLE;
new Handle:g_hCvAdminMaxTLockRounds = INVALID_HANDLE;
new Handle:g_hCvAdminMaxTlistMinutes = INVALID_HANDLE;
new Handle:g_hCvTeamJoinSpamLimit = INVALID_HANDLE;
new Handle:g_hCvTeamJoinSpamBanDur = INVALID_HANDLE;
new Handle:g_hCvRatioMinPlayers = INVALID_HANDLE;
new Handle:g_hCvRatioPrisonersToGuards = INVALID_HANDLE;
new Handle:g_hCvStartMuteLength = INVALID_HANDLE;
new Handle:g_hCvMuteOnDeathDelay = INVALID_HANDLE;
new Handle:g_hCvMaxClientsTalking = INVALID_HANDLE;
new Handle:g_hCvAdminTeamMuteSeconds = INVALID_HANDLE;

new Handle:g_hCvRebelSecondsPerTick = INVALID_HANDLE;
new Handle:g_hCvRebelGunAutoRebelTicks = INVALID_HANDLE;
new Handle:g_hCvRebelShoot = INVALID_HANDLE;
new Handle:g_hCvRebelTele = INVALID_HANDLE;
new Handle:g_hCvRebelGunAutoRebelSeconds = INVALID_HANDLE;
new Handle:g_hCvGunplantTrackSeconds = INVALID_HANDLE;

new Handle:g_hCvPrisonDiceRollsFrac = INVALID_HANDLE;
new Handle:g_hCvTopRepPlayersToQuery = INVALID_HANDLE;
new Handle:g_hCvRepWinDice = INVALID_HANDLE;
new Handle:g_hCvRepHurtGuard = INVALID_HANDLE;
new Handle:g_hCvRepKillGuard = INVALID_HANDLE;
new Handle:g_hCvRepKillLead = INVALID_HANDLE;
/*new Handle:g_hCvRepSurviveRound = INVALID_HANDLE;
new Handle:g_hCvRepGetSmokes = INVALID_HANDLE;
new Handle:g_hCvRepGetPot = INVALID_HANDLE;
new Handle:g_hCvRepGetCrack = INVALID_HANDLE;
new Handle:g_hCvRepGetHeroin = INVALID_HANDLE;*/
new Handle:g_hCvRepCostFire = INVALID_HANDLE;
new Handle:g_hCvRepCostWarday = INVALID_HANDLE;
new Handle:g_hCvRepLevelColoredName = INVALID_HANDLE;
new Handle:g_hCvRepMakeItToLr = INVALID_HANDLE;
new Handle:g_hCvRepKillRebel = INVALID_HANDLE;
new Handle:g_hCvRepIdling = INVALID_HANDLE;
new Handle:g_hCvRepIdlingInterval = INVALID_HANDLE;

new Handle:g_hCvRepFireGiveBackPercent = INVALID_HANDLE;
new Handle:g_hCvLeadFiredRoundsToBlock = INVALID_HANDLE;
new Handle:g_hCvLeadHpBonus = INVALID_HANDLE;
new Handle:g_hCvLeadRegenerateAmount = INVALID_HANDLE;
new Handle:g_hCvLeadRegenerateEvery = INVALID_HANDLE;
new Handle:g_hCvLeadFireRatio = INVALID_HANDLE;
new Handle:g_hCvLeadPassPercent = INVALID_HANDLE;

new Handle:g_hCvNameChangeLimit = INVALID_HANDLE;
new Handle:g_hCvNameChangeSeconds = INVALID_HANDLE;
new Handle:g_hCvNameControlExact = INVALID_HANDLE;
new Handle:g_hCvNameControlExclusive = INVALID_HANDLE;

new Handle:g_hCvBombRadius = INVALID_HANDLE;
new Handle:g_hCvBombMagnitude = INVALID_HANDLE;
new Handle:g_hCvBombDamageMultiplier = INVALID_HANDLE;
new Handle:g_hCvBombRadiusMultiplier = INVALID_HANDLE;
new Handle:g_hCvBombOnRoundStartChance = INVALID_HANDLE;

new Handle:g_hCvArmoryWarnTime = INVALID_HANDLE;
new Handle:g_hCvArmoryTeleportTime = INVALID_HANDLE;
new Handle:g_hCvArmorySecondTeleportTime = INVALID_HANDLE;

new Handle:g_hCvBuyMenuCtBuyTime = INVALID_HANDLE;
new Handle:g_hCvAdminRoomTime = INVALID_HANDLE;
new Handle:g_hCvAdminRoomDelay = INVALID_HANDLE;

new Handle:g_hCvWardaySndTimeAfter = INVALID_HANDLE;
new Handle:g_hCvWardayStartEarly = INVALID_HANDLE;
new Handle:g_hCvWardayMaxConsecutive = INVALID_HANDLE;

new Handle:g_hCvWeaponKnifeSyphonHealth = INVALID_HANDLE;
new Handle:g_hCvCtHealthBonusPerT = INVALID_HANDLE;
new Handle:g_hCvLrRebelHealth = INVALID_HANDLE;
new Handle:g_hCvLrWinRep = INVALID_HANDLE;
new Handle:g_hCvLrFlashbangGiveDelay = INVALID_HANDLE;
new Handle:g_hCvLrDodgeballGravity = INVALID_HANDLE;
new Handle:g_hCvLrRpsLaserswordChange = INVALID_HANDLE;

new Handle:g_hCvSungodNumDrugsEach = INVALID_HANDLE;
//new Handle:g_hCvSungodSacrificeMeter = INVALID_HANDLE;

new Handle:g_hCvRadarHackStartAfterTime = INVALID_HANDLE;
new Handle:g_hCvRadarHackStartAfterTs = INVALID_HANDLE;

new Handle:g_hCvTradeDelay = INVALID_HANDLE;

// Calling GetConVar*(handle) is MUCH more intensive than pointing to a data type.
// Commonly used (more than ~30 times in a round) CVars should be cached for faster lookup
// Remember to use HookConVar, add the code to OnConVarChanged, and OnConfigsExecuted
new g_iRadarHackStartAfterTime = 270;
new g_iRadarHackStartAfterTs = 3;

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

Convars_OnPluginStart()
{
    g_hCvSpawnWindowTime = CreateConVar(
        "aio_spawn_window_time",
        "20.0",
        "How long (in seconds) is the period of time at the begining of each round where players who join the team will be alive.",
        _, true, 1.0, true, 45.0);
    g_hCvFkpKills = CreateConVar(
        "aio_fkp_kills",
        "5.0",
        "Free-Kill Protection is triggered when a Guard kills X Prisoners within Y seconds.  This is X.",
        _, true, 2.0, true, 32.0);
    g_hCvFkpSeconds = CreateConVar(
        "aio_fkp_timespan",
        "1.333",
        "Free-Kill Protection is triggered when a Guard kills X Prisoners within Y seconds.  This is Y.",
        _, true, 0.5, true, 10.0);
    g_hCvFkpDuration = CreateConVar(
        "aio_fkp_tlist_minutes",
        "10080",
        "How many minutes to T-List someone who triggers the automatic freekill protection?",
        _, true, 1.0, true, 43200.0);
    g_hCvAdminMaxMuteRounds = CreateConVar(
        "aio_admin_max_mute_rounds",
        "5",
        "How many rounds can an admin mute somebody?",
        _, true, 1.0, true, 10.0);
    g_hCvAdminMaxGagRounds = CreateConVar(
        "aio_admin_max_gag_rounds",
        "3",
        "How many rounds can an admin gag somebody?",
        _, true, 1.0, true, 10.0);
    g_hCvAdminMaxTLockRounds = CreateConVar(
        "aio_admin_max_tlock_rounds",
        "9",
        "How many rounds can an admin Temp-Lock somebody?",
        _, true, 1.0, true, 10.0);
    g_hCvAdminMaxTlistMinutes = CreateConVar(
        "aio_admin_max_tlist_minutes",
        "120",
        "How many minutes can an admin T-List somebody?",
        _, true, 1.0, true, 43200.0);
    g_hCvTeamJoinSpamLimit = CreateConVar(
        "aio_team_join_spam_limit",
        "6",
        "How many times can someone attempt to join guard team per round before being banned for a small time?",
        _, true, 3.0, true, 20.0);
    g_hCvTeamJoinSpamBanDur = CreateConVar(
        "aio_team_join_spam_ban_dur",
        "2",
        "How long (in minutes) will someone be banned if they try to spam join the guard team?",
        _, true, 3.0, true, 20.0);
    g_hCvRatioMinPlayers = CreateConVar(
        "aio_ratio_min_players",
        "10",
        "How many players are required before ratio is enforced?",
        _, true, 5.0, true, 20.0);
    g_hCvRatioPrisonersToGuards = CreateConVar(
        "aio_ratio_prisoners_guards",
        "1.99",
        "This is the ratio of Prisoners to Guards that will be enforced, assuming there are the minimum number of players.",
        _, true, 1.5, true, 3.0);
    g_hCvStartMuteLength = CreateConVar(
        "aio_start_mute_length",
        "30.0",
        "How long (in seconds) should Prisoners be muted at the begining of each round?",
        _, true, 10.0, true, 45.0);
    g_hCvMuteOnDeathDelay = CreateConVar(
        "aio_mute_on_death_delay",
        "1.5",
        "When a player dies, they will be muted but not necessarially instantly.  How many seconds of delay should be used?",
        _, true, 0.1, true, 5.0);
    g_hCvMaxClientsTalking = CreateConVar(
        "aio_max_talking_clients",
        "3",
        "The maximum number of clients (excluding lead) allowed to talk",
        _, true, 1.0, true, 10.0);
    g_hCvAdminTeamMuteSeconds = CreateConVar(
        "aio_admin_mute_length_team",
        "10.0",
        "How long (in seconds) should Prisoners be muted when an admin mutes the team?",
        _, true, 5.0, true, 45.0);



    g_hCvRebelSecondsPerTick = CreateConVar(
        "aio_rebel_tick_timespan",
        "5.0",
        "When a Prisoner rebels, he turns red for a certain number of timer ticks (depending on his prison rep level).  This is how long each timer tick is (in seconds).",
        _, true, 2.0, true, 10.0);
    g_hCvRebelGunAutoRebelTicks = CreateConVar(
        "aio_rebel_gun_auto_rebel_ticks",
        "1",
        "How many ticks to make a person a rebel who holds a gun out too long.",
        _, true, 1.0, true, 10.0);
    g_hCvRebelShoot = CreateConVar(
        "aio_rebel_shoot",
        "3.0",
        "How long to make a person a rebel for shooting a gun",
        _, true, 1.0, true, 10.0);
    g_hCvRebelTele = CreateConVar(
        "aio_rebel_tele",
        "20.0",
        "How long to make a person a rebel for taking first cell teleporter",
        _, true, 1.0, true, 600.0);
    g_hCvRebelGunAutoRebelSeconds = CreateConVar(
        "aio_rebel_gun_auto_rebel_timer",
        "3.5",
        "After <x> seconds of a T having a gun out to declare them a rebel",
        _, true, 1.0, true, 10.0);
    g_hCvGunplantTrackSeconds = CreateConVar(
        "aio_gunplant_timespan",
        "3.0",
        "When a Guard drops a weapon, it is tracked for this amount of time (in seconds).  If a Prisoner picks it up while its being tracked, it's considered a \"plant\".",
        _, true, 0.1, true, 60.0);



    g_hCvPrisonDiceRollsFrac = CreateConVar(
        "aio_prisondice_rolls_frac",
        "0.25",
        "How many dice rolls should be allowed at the beginning of each round -- per number of Prisoners?  0.0 would be no rolls; 0.5 would indicate half the Prisoners get a roll; 1.0 would indicate all Prisoners get a roll.",
        _, true, 0.0, true, 1.0);
    g_hCvTopRepPlayersToQuery = CreateConVar(
        "aio_toprep_players_to_get",
        "42",
        "How many players to get for the !toprep menu?",
        _, true, 1.0, true, 70.0);
    g_hCvRepWinDice = CreateConVar(
        "aio_rep_win_dice",
        "25",
        "Rolling prison dice can win a Prisoner one of several prizes.  One of these prizes is some prison rep.  How many points of prison rep should be awarded?",
        _, true, 0.0, true, 1000.0);
    g_hCvRepHurtGuard = CreateConVar(
        "aio_rep_hurt_guard",
        "0",
        "How many points of prison rep should be awarded when a Prisoner hurts a Guard?",
        _, true, 0.0, true, 1000.0);
    g_hCvRepKillGuard = CreateConVar(
        "aio_rep_kill_guard",
        "3",
        "How many points of prison rep should be awarded when a Prisoner kills a Guard?",
        _, true, 0.0, true, 1000.0);
    g_hCvRepKillLead = CreateConVar(
        "aio_rep_kill_lead",
        "2",
        "How many additional points you get for killing the lead",
        _, true, 0.0, true, 1000.0);
    /*g_hCvRepSurviveRound = CreateConVar(
        "aio_rep_survive_round",
        "0",
        "How many points of prison rep should be awarded when a player lives until the end of a round?",
        _, true, 0.0, true, 1000.0);
    g_hCvRepGetSmokes = CreateConVar(
        "aio_rep_survive_round",
        "10",
        "How many points of prison rep should be awarded when a Prisoner finds some cigarettes?",
        _, true, 0.0, true, 1000.0);
    g_hCvRepGetPot = CreateConVar(
        "aio_rep_get_pot",
        "25",
        "How many points of prison rep should be awarded when a Prisoner finds some marijuana?",
        _, true, 0.0, true, 1000.0);
    g_hCvRepGetCrack = CreateConVar(
        "aio_rep_get_pot",
        "35",
        "How many points of prison rep should be awarded when a Prisoner finds some crack cocaine?",
        _, true, 0.0, true, 1000.0);
    g_hCvRepGetHeroin = CreateConVar(
        "aio_rep_get_heroin",
        "45",
        "How many points of prison rep should be awarded when a Prisoner finds some heroine?",
        _, true, 0.0, true, 1000.0);*/
    g_hCvRepCostFire = CreateConVar(
        "aio_rep_cost_fire",
        "3",
        "Cost, in rep to vote to fire the Lead Guard?",
        _, true, 0.0, true, 1000.0);
    g_hCvRepCostWarday = CreateConVar(
        "aio_rep_cost_warday",
        "10",
        "Cost, in rep, to call a warday.",
        _, true, 0.0, true, 1000.0);
    g_hCvRepLevelColoredName = CreateConVar(
        "aio_rep_level_coloredname", "10000",
        "How much rep is required to use a colored name?",
        _, true, 0.0, true, 50000.0);
    g_hCvRepMakeItToLr = CreateConVar(
        "aio_rep_making_to_lr",
        "2",
        "How much rep a lead gets for making it to LR",
        _, true, 0.0, true, 1000.0);
    g_hCvRepKillRebel = CreateConVar(
        "aio_rep_guard_kill_rebel",
        "3",
        "How much rep a guard gets for killing a rebel",
        _, true, 0.0, true, 1000.0);
    g_hCvRepIdling = CreateConVar(
        "aio_rep_idling",
        "2",
        "How much rep per interval AFK spectators get for populating the server",
        _, true, 0.0, true, 1000.0);
    g_hCvRepIdlingInterval = CreateConVar(
        "aio_rep_idling_interval",
        "66.6",
        "Ever <x> seconds to give each spectator rep_idling rep",
        _, true, 1.0, true, 3600.0);



    g_hCvRepFireGiveBackPercent = CreateConVar(
        "aio_rep_fire_give_back_percent",
        "0.7666",
        "How much rep (decimal percent) to give back to a player for a successful fire",
        _, true, 0.0, true, 1.0);
    g_hCvLeadFiredRoundsToBlock = CreateConVar(
        "aio_lead_fired_rounds_to_block",
        "2",
        "When a Lead Guard is fired, how many rounds should he be blocked from taking Lead?",
        _, true, 0.0, true, 10.0);
    g_hCvLeadHpBonus = CreateConVar(
        "aio_lead_hp_bonus",
        "30",
        "How much extra health does the lead get?",
        _, true, 0.0, true, 500.0);
    g_hCvLeadRegenerateAmount = CreateConVar(
        "aio_lead_regenerate_amount",
        "1",
        "How much health to regenerate every <lead_regenerate_every> seconds",
        _, true, 0.0, true, 500.0);
    g_hCvLeadRegenerateEvery = CreateConVar(
        "aio_lead_regenerate_every",
        "2.0",
        "Every <x> seconds to regenerate lead's HP by <lead_regenerate_amount>",
        _, true, 0.5, true, 10.0);
    g_hCvLeadFireRatio = CreateConVar(
        "aio_lead_fire_ratio",
        "0.28",
        "What percent (as a fraction) of votes is needed to fire the Lead Guard?",
        _, true, 0.01, true, 75.0);
    g_hCvLeadPassPercent = CreateConVar(
        "aio_pass_fire_percent",
        "0.70",
        "What percent (as a fraction) of votes needed to teleport a lead to electric chair, when they !pass.",
        _, true, 0.0, true, 1.0);



    g_hCvNameChangeLimit = CreateConVar(
        "aio_namechange_limit",
        "10",
        "Namechangers are banned when a player changes names X times within Y seconds.  This is X.",
        _, true, 2.0, true, 20.0);
    g_hCvNameChangeSeconds = CreateConVar(
        "aio_namechange_timespan",
        "60.0",
        "Namechangers are banned when a player changes names X times within Y seconds.  This is Y.",
        _, true, 10.0, true, 120.0);
    g_hCvNameControlExact = CreateConVar(
        "aio_namecontrol_exact",
        "0",
        "If this is set to 1 (true) all members must use their exact forum name while playing.",
        _, true, 0.0, true, 1.0);
    g_hCvNameControlExclusive = CreateConVar(
        "aio_namecontrol_exclusive",
        "0",
        "If this is set to 1 (true) all non-clan members will be kicked.",
        _, true, 0.0, true, 1.0);



    g_hCvBombRadius = CreateConVar(
        "aio_bomb_radius",
        "500",
        "Radius of bomb explosion.",
        _, true, 1.0, true, 9000.0);
    g_hCvBombMagnitude = CreateConVar(
        "aio_bomb_magnitude",
        "300",
        "Magnitude of bomb explosion.",
        _, true, 1.0, true, 9000.0);
    g_hCvBombDamageMultiplier = CreateConVar(
        "aio_bomb_damage_multiplier",
        "40.0",
        "Damage multiplier for rep. At 7.0, and 10,000 rep, this will add 50 damage to the bomb.",
        _, true, 0.0, true, 100.0);
    g_hCvBombRadiusMultiplier = CreateConVar(
        "aio_bomb_radius_multiplier",
        "32.0",
        "Radius multiplier for rep. At 5.0 and 10, 000 rep, this will add 36 radius to the bomb.",
        _, true, 0.0, true, 100.0);
    g_hCvBombOnRoundStartChance = CreateConVar(
        "aio_bomb_on_round_start_chance",
        "0.666",
        "Decimal percent change a bomb will be given at the start of the round",
        _, true, 0.0, true, 1.0);



    g_hCvArmoryWarnTime = CreateConVar(
        "aio_armory_warn_time",
        "15",
        "After how many seconds of armory camping to warn the CT to leave.",
        _, true, 1.0, true, 60.0);
    g_hCvArmoryTeleportTime = CreateConVar(
        "aio_armory_teleport_time",
        "20",
        "After how many seconds of armory camping to teleport the CT.",
        _, true, 2.0, true, 61.0);
    g_hCvArmorySecondTeleportTime = CreateConVar(
        "aio_armory_second_teleport_time",
        "7",
        "Amount of time a player can be in armory (after the initial teleport) before they're teleported.",
        _, true, 1.0, true, 60.0);



    g_hCvBuyMenuCtBuyTime = CreateConVar(
        "aio_buymenu_ct_buy_time",
        "60",
        "Buy time in seconds for the CT !buy menu.",
        _, true, 0.1, true, 600.0);
    g_hCvAdminRoomTime = CreateConVar(
        "aio_adminroom_time",
        "20",
        "Time that admins are allowed to use !adminroom.",
        _, true, 0.1, true, 600.0);
    g_hCvAdminRoomDelay = CreateConVar(
        "aio_adminroom_delay",
        "5",
        "Time before admins can use !adminroom.",
        _, true, 0.1, true, 600.0);



    g_hCvWardaySndTimeAfter = CreateConVar(
        "aio_warday_snd_time_after",
        "180.0",
        "How much time after round start to call a Search and Destroy for a warday.",
        _, true, 60.0, true, 600.0);
    g_hCvWardayStartEarly = CreateConVar(
        "aio_warday_start_early",
        "3",
        "Start a warday early when there are <x> amount of players left alive on a team.",
        _, true, 0.0, true, 10.0);
    g_hCvWardayMaxConsecutive = CreateConVar(
        "aio_warday_max_consecutive",
        "2",
        "The max rounds in a row that you can have a warday (the count decreases by 1 each round).",
        _, true, 1.0, true, 100.0);



    g_hCvWeaponKnifeSyphonHealth = CreateConVar(
        "aio_weapons_knife_syphon_health",
        "50",
        "How much extra health a player gets when they kill someone with a knife.",
        _, true, 1.0, true, 100.0);
    g_hCvCtHealthBonusPerT = CreateConVar(
        "aio_ct_health_bonus_per_t",
        "0.666",
        "How much health each CT gets when they spawn for every T that is on the server.",
        _, true, 0.0, true, 10.0);
    g_hCvLrRebelHealth = CreateConVar(
        "aio_lr_rebel_health",
        "300",
        "How much health to give somene that rebels",
        _, true, 100.0, true, 1000.0);
    g_hCvLrWinRep = CreateConVar(
        "aio_lr_win_rep",
        "5",
        "How much rep someone gets for winning an LR",
        _, true, 1.0, true, 100.0);
    g_hCvLrFlashbangGiveDelay = CreateConVar(
        "aio_lr_flashbang_give_delay",
        "1.5",
        "How many seconds after a throw to give a player another flashbang",
        _, true, 1.0, true, 3.0);
    g_hCvLrDodgeballGravity = CreateConVar(
        "aio_lr_dodgeball_gravity",
        "0.75",
        "What to set a player's gravity to on dodgeball",
        _, true, 0.0, true, 1.0);
    g_hCvLrRpsLaserswordChange = CreateConVar(
        "aio_lr_rps_lasersword_chance",
        "0.05",
        "Decimal percent chance of someone being able to use laser sword in rock-paper-scissors LR",
        _, true, 0.0, true, 1.0);

    g_hCvSungodNumDrugsEach = CreateConVar(
        "aio_sungod_num_drugs_each",
        "2",
        "How many drugs should each sacrifice give?",
        _, true, 0.0, true, 10.0);
    /*
    g_hCvSungodSacrificeMeter = CreateConVar(
        "aio_sungod_sacrifice_meter",
        "5",
        "How many sacrifices need to occur (per round) until the sungod spews drugs?",
        _, true, 1.0, true, 32.0);*/

    g_hCvRadarHackStartAfterTime = CreateConVar(
        "aio_enable_radar_after_time_passed",
        "270",
        "After how many seconds to enable radar hax for CTs",
        _, true, 0.0, true, 540.0);

    g_hCvRadarHackStartAfterTs = CreateConVar(
        "aio_enable_radar_after_remaining_ts",
        "3",
        "After how many Ts remaining to enable the radar hax",
        _, true, 0.0, true, 40.0);

    g_hCvTradeDelay = CreateConVar(
        "aio_trade_delay",
        "60",
        "How long after a trade is completed/denied until a player can make a new one",
        _, true, 0.0, true, 600.0);
        
}

stock ConVars_OnConfigsExecuted()
{
    g_iRadarHackStartAfterTime = GetConVarInt(g_hCvRadarHackStartAfterTime);
    g_iRadarHackStartAfterTs = GetConVarInt(g_hCvRadarHackStartAfterTs);
}

public OnConVarChanged(Handle:cvar, const String:oldv[], const String:newv[])
{
    if (cvar == g_hCvRadarHackStartAfterTime)
        g_iRadarHackStartAfterTime = StringToInt(newv);

    else if (cvar == g_hCvRadarHackStartAfterTs)
        g_iRadarHackStartAfterTs = StringToInt(newv);
}
