#define CHRISTMAS 0

// Christmas downloads
/*
materials/katharsmodels/present/type-1/present_five_all.vmt
materials/katharsmodels/present/type-1/present_five_all.vtf
materials/katharsmodels/present/type-1/present_one_all.vmt
materials/katharsmodels/present/type-1/present_one_all.vtf
materials/katharsmodels/present/type-1/present_three_all.vmt
materials/katharsmodels/present/type-1/present_three_all.vtf
materials/katharsmodels/present/type-2/present_four_all.vmt
materials/katharsmodels/present/type-2/present_four_all.vtf
materials/katharsmodels/present/type-2/present_six_all.vmt
materials/katharsmodels/present/type-2/present_six_all.vtf
materials/katharsmodels/present/type-2/present_two_all.vmt
materials/katharsmodels/present/type-2/present_two_all.vtf
materials/models/cloud/xmastree/bauble.vmt
materials/models/cloud/xmastree/bauble.vtf
materials/models/cloud/xmastree/leaf.vmt
materials/models/cloud/xmastree/leaf.vtf
materials/models/cloud/xmastree/leaf2.vmt
materials/models/cloud/xmastree/leaf2.vtf
materials/models/cloud/xmastree/lights.vmt
materials/models/cloud/xmastree/lights.vtf
materials/models/cloud/xmastree/star.vmt
materials/models/cloud/xmastree/star.vtf
materials/models/cloud/xmastree/tinsel.vmt
materials/models/cloud/xmastree/tinsel.vtf
materials/models/cloud/xmastree/tinsel2.vmt
materials/models/cloud/xmastree/tinsel2.vtf
materials/models/cloud/xmastree/tinsel3.vtf
materials/models/cloud/xmastree/tinsels.vmt
models/cloud/kn_xmastree.dx80.vtx
models/cloud/kn_xmastree.dx90.vtx
models/cloud/kn_xmastree.mdl
models/cloud/kn_xmastree.phy
models/cloud/kn_xmastree.sw.vtx
models/cloud/kn_xmastree.vvd
models/cloud/kn_xmastree.xbox.vtx
models/katharsmodels/present/type-1/normal/present.dx80.vtx
models/katharsmodels/present/type-1/normal/present.dx90.vtx
models/katharsmodels/present/type-1/normal/present.mdl
models/katharsmodels/present/type-1/normal/present.phy
models/katharsmodels/present/type-1/normal/present.sw.vtx
models/katharsmodels/present/type-1/normal/present.vvd
models/katharsmodels/present/type-1/normal/present2.dx80.vtx
models/katharsmodels/present/type-1/normal/present2.dx90.vtx
models/katharsmodels/present/type-1/normal/present2.mdl
models/katharsmodels/present/type-1/normal/present2.phy
models/katharsmodels/present/type-1/normal/present2.sw.vtx
models/katharsmodels/present/type-1/normal/present2.vvd
models/katharsmodels/present/type-1/normal/present2.xbox.vtx
models/katharsmodels/present/type-1/normal/present3.dx80.vtx
models/katharsmodels/present/type-1/normal/present3.dx90.vtx
models/katharsmodels/present/type-1/normal/present3.mdl
models/katharsmodels/present/type-1/normal/present3.phy
models/katharsmodels/present/type-1/normal/present3.sw.vtx
models/katharsmodels/present/type-1/normal/present3.vvd
models/katharsmodels/present/type-1/normal/present3.xbox.vtx
models/katharsmodels/present/type-2/normal/present.dx80.vtx
models/katharsmodels/present/type-2/normal/present.dx90.vtx
models/katharsmodels/present/type-2/normal/present.mdl
models/katharsmodels/present/type-2/normal/present.phy
models/katharsmodels/present/type-2/normal/present.sw.vtx
models/katharsmodels/present/type-2/normal/present.vvd
models/katharsmodels/present/type-2/normal/present2.dx80.vtx
models/katharsmodels/present/type-2/normal/present2.dx90.vtx
models/katharsmodels/present/type-2/normal/present2.mdl
models/katharsmodels/present/type-2/normal/present2.phy
models/katharsmodels/present/type-2/normal/present2.sw.vtx
models/katharsmodels/present/type-2/normal/present2.vvd
models/katharsmodels/present/type-2/normal/present2.xbox.vtx
models/katharsmodels/present/type-2/normal/present3.dx80.vtx
models/katharsmodels/present/type-2/normal/present3.dx90.vtx
models/katharsmodels/present/type-2/normal/present3.mdl
models/katharsmodels/present/type-2/normal/present3.phy
models/katharsmodels/present/type-2/normal/present3.sw.vtx
models/katharsmodels/present/type-2/normal/present3.vvd
models/katharsmodels/present/type-2/normal/present3.xbox.vtx
materials/models/cloud/xmastree/bluecracker.vmt
materials/models/cloud/xmastree/bluecracker.vtf
materials/models/cloud/xmastree/goldcracker.vmt
materials/models/cloud/xmastree/goldcracker.vtf
materials/models/cloud/xmastree/greencracker.vmt
materials/models/cloud/xmastree/greencracker.vtf
materials/models/cloud/xmastree/redcracker.vmt
materials/models/cloud/xmastree/redcracker.vtf
*/

new keys;       /* Dynamically stores number of spawn locations */

new iCig;
new iBooze;
new iWeed;
new iCoke;
new iHeroin;

// Christmas!!!
#if CHRISTMAS
new String:sCig[] = "models/katharsmodels/present/type-1/normal/present.mdl";
new String:sBooze[] = "models/katharsmodels/present/type-1/normal/present2.mdl";
new String:sWeed[] = "models/katharsmodels/present/type-1/normal/present3.mdl";
new String:sCoke[] = "models/katharsmodels/present/type-2/normal/present.mdl";
new String:sHeroin[] = "models/katharsmodels/present/type-2/normal/present2.mdl";
#else
new String:sCig[] = "models/player/hggangs/cancer.mdl";
new String:sBooze[] = "models/player/hggangs/can.mdl";
new String:sWeed[] = "models/player/hggangs/appleseed.mdl";
new String:sCoke[] = "models/player/hggangs/cocacola.mdl";
new String:sHeroin[] = "models/player/hggangs/shooter.mdl";
#endif

new String:sLocationPath[PLATFORM_MAX_PATH];

new spawnLocations[MAX_DRUGS_INITIAL];     /* Records used Locations */
new entityIndexes[MAX_DRUGS];              /* Holds all parent entities */
new dynamicIndexes[MAX_DRUGS];             /* Holds all drug entities */

new Handle:hMapLocations = INVALID_HANDLE;
new Handle:g_hValidProps = INVALID_HANDLE;

/* ----- Events ----- */


stock Drugs_OnPluginStart()
{
    BuildPath(Path_SM,
              sLocationPath, PLATFORM_MAX_PATH, "data/locations.txt");

    if (!FileExists(sLocationPath))
        SetFailState("No location data file \"./data/locations.txt\"");

    keys = getNumberOfKeys();
    g_hValidProps = CreateArray();

    HookEntityOutput("prop_physics_multiplayer", "OnBreak", OnBreak);

    // Christmas!
    #if CHRISTMAS
    CreateTimer(GetRandomFloat(2.5, 27.5), Timer_CreatePresents);
    #endif
}

// Christmas!
#if CHRISTMAS
public Action:Timer_CreatePresents(Handle:timer)
{
    new Float:vel[3];
    vel[0] = GetRandomFloat(-250.0, 250.0);
    vel[1] = GetRandomFloat(-250.0, 250.0);
    vel[2] = GetRandomFloat(50.0, 250.0);

    SpawnDrugs(908.0, -296.0, 80.0, vel);
    CreateTimer(GetRandomFloat(0.0, 30.0), Timer_CreatePresents);
}
#endif

stock Drugs_OnMapStart()
{
    MakeFilesDownloadable();

    iCig = PrecacheModel(sCig);
    iBooze = PrecacheModel(sBooze);
    iWeed = PrecacheModel(sWeed);
    iCoke = PrecacheModel(sCoke);
    iHeroin = PrecacheModel(sHeroin);

    PrecacheModel("models/props/cs_office/phone.mdl");

    // Christmas
    #if CHRISTMAS
    PrecacheModel("models/cloud/kn_xmastree.mdl");
    #endif
}

public OnBreak(const String:output[], entity, entity2, Float:delay)
{
    decl String:classname[MAX_NAME_LENGTH];
    GetEntityClassname(entity, classname, sizeof(classname));

    if (!StrEqual(classname, "prop_physics") && !StrEqual(classname, "prop_physics_multiplayer"))
        return;

    new index = FindValueInArray(g_hValidProps, entity);
    if (index > -1)
    {
        RemoveFromArray(g_hValidProps, index);
    }

    else
        return;

    decl Float:fEntityLocation[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fEntityLocation);

    if (GetRandomFloat() <= GetConVarFloat(hOnBreakPercent))
    {
        SpawnDrugs(fEntityLocation[0], fEntityLocation[1], fEntityLocation[2]);
    }
}

public OnPlayerUse(const String:output[], entity, activator, Float:delay)
{
    new closest, iDynamic;

    decl Float:fEntityLocation[3];
    decl Float:fPlayerLocation[3];

    new Float:fClosest;
    new Float:fDistance;

    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fEntityLocation);

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !JB_IsPlayerAlive(i) || GetClientTeam(i) < 2)
            continue;

        GetEntPropVector(i, Prop_Send, "m_vecOrigin", fPlayerLocation);

        fDistance = Pow(Pow(fPlayerLocation[0] - fEntityLocation[0], 2.0) +
                        Pow(fPlayerLocation[1] - fEntityLocation[1], 2.0) +
                        Pow(fPlayerLocation[2] - fEntityLocation[2], 2.0),
                        0.5);

        if (!fClosest || fDistance < fClosest)
        {
            fClosest = fDistance;
            closest = i;
        }
    }

    if (GetClientTeam(closest) == TEAM_T)
    {
        /*
         * Remove the index from the list of remaining entities
         * And gets the cooresponding drug index
         */

        for (new i = 0; i < MAX_DRUGS; i++)
        {
            if (entityIndexes[i] == entity)
            {
                entityIndexes[i] = 0;
                iDynamic = dynamicIndexes[i];
            }
        }

        new points;
        new model = GetEntProp(iDynamic, Prop_Send, "m_nModelIndex");

        if (model == iCig)
            points = GetConVarInt(hCig);

        else if (model == iBooze)
            points = GetConVarInt(hBooze);

        else if (model == iWeed)
            points = GetConVarInt(hWeed);

        else if (model == iCoke)
            points = GetConVarInt(hCoke);

        else if (model == iHeroin)
            points = GetConVarInt(hHeroin);

        UnhookSingleEntityOutput(entity, "OnPlayerUse", OnPlayerUse);
        AcceptEntityInput(entity, "kill");

        AddPoints(closest, points, true);
        TellPoints(closest);
    }
}

stock Drugs_OnRoundStart()
{
    // Christmas time!
    #if CHRISTMAS
    new tree = CreateEntityByName("prop_physics_override");
    DispatchKeyValue(tree, "model", "models/cloud/kn_xmastree.mdl");

    DispatchSpawn(tree);

    TeleportEntity(tree, Float:{908.0, -296.0, 1.0}, NULL_VECTOR, NULL_VECTOR);
    SetEntityMoveType(tree, MOVETYPE_NONE);
    #endif

    if (bIsThursday)
        return;

    ClearArray(g_hValidProps);
    CreateTimer(1.69, Timer_SpawnDrugs);
}

public Action:Timer_SpawnDrugs(Handle:timer, any:data)
{
    new index = -1;
    while ((index = FindEntityByClassname(index, "prop_physics_multiplayer")) != -1)
    {
        PushArrayCell(g_hValidProps, index);
    }

    new toSpawn = GetRandomInt(GetConVarInt(hMinSpawn),
                               GetConVarInt(hMaxSpawn));

    /* Only spawn as much drugs as there is map locations */
    for (new i = 0; i < (toSpawn > keys ? keys : toSpawn); i++)
    {
        new iLocationIndex = getRandomLocation();

        if (iLocationIndex == -1)
            continue;

        decl String:sLocationIndex[4];
        decl String:sLocation[64];
        decl String:sLocations[3][32];

        /* Stores the actual location in array of floats */
        decl Float:fLocation[3];

        IntToString(iLocationIndex, sLocationIndex, 4);
        KvGetString(hMapLocations, sLocationIndex, sLocation, 64);

        ExplodeString(sLocation, " ", sLocations, 3, 32);

        fLocation[0] = StringToFloat(sLocations[0]);
        fLocation[1] = StringToFloat(sLocations[1]);
        fLocation[2] = StringToFloat(sLocations[2]);

        SpawnDrugs(fLocation[0], fLocation[1], fLocation[2]);
    }
}

stock Drugs_OnRoundEnd()
{
    /*
     * Gets rid of the old indexes, no need to remove the actual entities 
     * The source engine does this for us
     */

    for (new i = 0; i < MAX_DRUGS; i++)
    {
        if (entityIndexes[i] && IsValidEntity(entityIndexes[i]))
            UnhookSingleEntityOutput(entityIndexes[i],
                                     "OnPlayerUse", OnPlayerUse);

        entityIndexes[i] = 0;
 
        if (i < MAX_DRUGS_INITIAL)
            spawnLocations[i] = 0;
    }
}

/* ----- Functions ----- */

stock MakeFilesDownloadable()
{
    decl String:sFilePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sFilePath, PLATFORM_MAX_PATH, "data/gangdownloads.txt");

    new Handle:oFile = OpenFile(sFilePath, "r");
    decl String:currentDownload[PLATFORM_MAX_PATH];

    while (!IsEndOfFile(oFile) &&
            ReadFileLine(oFile, currentDownload, sizeof(currentDownload)))
    {
        /* Remove the leading new line character */
        currentDownload[strlen(currentDownload) - 1] = '\0';

        AddFileToDownloadsTable(currentDownload);
    }

    CloseHandle(oFile);
}

SpawnDrugs(Float:x, Float:y, Float:z, Float:vel[3]=NULL_VECTOR)
{
    if (isRatioFucked() || bIsThursday)
        return -1;

    for (new j = 0; j < MAX_DRUGS + 1; j++)
    {
        /* Too many drugs! */
        if (j == MAX_DRUGS)
            return -1;

        /* There's a free index, continue spawning the entity */
        if (!entityIndexes[j])
            break;
    }

    decl Float:fLocation[3];

    fLocation[0] = x;
    fLocation[1] = y;
    fLocation[2] = z + 20;

    /*
     * prop_physics_override will create a prop_physics_multiplayer
     * And then copy all the model data
     * This creates the parent entity, a phone...
     */

    new iParentDrug = CreateEntityByName("prop_physics_override");

    decl String:sParentName[32];
    Format(sParentName, sizeof(sParentName), "gang_parent_%i", iParentDrug);

    DispatchKeyValue(iParentDrug, "model",
                     "models/props/cs_office/phone.mdl");

    DispatchKeyValue(iParentDrug, "spawnflags", "256");
    DispatchKeyValue(iParentDrug, "targetname", sParentName);

    decl String:sModel[128];

    switch (GetRandomInt(0, 4))
    {
        case 0:
            sModel = sCig;

        case 1:
            sModel = sBooze;

        case 2:
            sModel = sWeed;

        case 3:
            sModel = sCoke;

        case 4:
            sModel = sHeroin;
    }

    DispatchSpawn(iParentDrug);

    // Don't block players
    SetEntProp(iParentDrug, Prop_Send, "m_usSolidFlags",  152);
    SetEntProp(iParentDrug, Prop_Send, "m_CollisionGroup", 11);

    /* Makes the parent entity invisible */
    SetEntData(iParentDrug, m_clrRender + 3, 0, 1, true);
    SetEntityRenderMode(iParentDrug, RENDER_TRANSTEXTURE);

    new iDrug = CreateEntityByName("prop_dynamic_override");

    decl String:sTargetName[32];
    Format(sTargetName, sizeof(sTargetName), "gang_dynamic_%i", iParentDrug);

    DispatchKeyValue(iDrug, "parentname", sParentName);
    DispatchKeyValue(iDrug, "targetname", sTargetName);
    DispatchKeyValue(iDrug, "model", sModel);

    /* Booze and cigarrettes spawn wierdly, so just... rotate it... */
    if (StrEqual(sModel, sBooze))
        DispatchKeyValue(iDrug, "angles", "90 0 0");

    else if (StrEqual(sModel, sCig))
        DispatchKeyValue(iDrug, "angles", "270 0 90");

    DispatchSpawn(iDrug);

    /* Sets the parent entity to the invisible phone */
    SetVariantString(sParentName);
    AcceptEntityInput(iDrug, "SetParent");

    TeleportEntity(iParentDrug, fLocation, NULL_VECTOR, vel);
    HookSingleEntityOutput(iParentDrug, "OnPlayerUse", OnPlayerUse);

    /* Store the parent index for future use */
    for (new j = 0; j < MAX_DRUGS; j++)
    {
        if (!entityIndexes[j])
        {
            entityIndexes[j] = iParentDrug;
            dynamicIndexes[j] = iDrug;
            break;
        }
    }

    return iParentDrug;
}


/* ----- Return Values ----- */


getRandomLocation()
{
    new i, iterations;
    new bool:bFound = false;

    while (++iterations < 1000)
    {
        i = GetRandomInt(1, keys);
        bFound = false;

        for (new j = 0; j < MAX_DRUGS_INITIAL; j++)
        {
            if (spawnLocations[j] == i)
            {
                /* Index has already been used, find a new one */
                bFound = true;
                break;
            }
        }

        /* 
         * Index hasn't been used yet, return it 
         * Then put it into the first unused slot of spawnLocations
         */

        if (!bFound)
        {
            /* Set the value of j to the first unused index */
            for (new j = 0; j < MAX_DRUGS_INITIAL; j++)
            {
                if (!spawnLocations[j])
                {
                    spawnLocations[j] = i;
                    break;
                }
            }

            return i;
        }
    }
    return -1;
}

getNumberOfKeys()
{
    new i = 0;
    decl String:key[5];
    decl String:keyvalue[64];

    hMapLocations = CreateKeyValues("locations");
    FileToKeyValues(hMapLocations, sLocationPath);

    /* Increment the number of keys until there is no next key */
    do
    {
        IntToString(++i, key, sizeof(key));
        KvGetString(hMapLocations,
                    key, keyvalue, sizeof(keyvalue), "no location found");
    } while (!StrEqual("no location found", keyvalue));

    return i - 1;
}

FreeDrugs()
{
    new left = MAX_DRUGS;

    for (new i = 0; i < MAX_DRUGS; i++)
    {
        if (entityIndexes[i])
            left--;
    }

    return left;
}
