#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new Float:fWallSpawns[27][3] =
{
	{
		1143079895, -1016142889, 0
	},
	{
		1150414275, -1018905887, 0
	},
	{
		1154412216, -998002033, 0
	},
	{
		1148343091, -996769792, 0
	},
	{
		1143455744, -1002995712, 0
	},
	{
		1138582159, -992403866, 0
	},
	{
		1133896335, -988884992, 0
	},
	{
		1134690304, -985853952, 0
	},
	{
		1143062528, -988303360, 1125515264
	},
	{
		-1002913792, -987246592, 0
	},
	{
		-1002635264, -984494080, 0
	},
	{
		-996425728, 1161068544, 1120403456
	},
	{
		-990966170, -986980352, 1120403456
	},
	{
		-993476608, -987602944, 0
	},
	{
		-990474158, -987590656, 0
	},
	{
		-991674368, -984600576, 0
	},
	{
		-1002209280, -996532224, 0
	},
	{
		-992133120, -996376576, 0
	},
	{
		-991977472, -1008926720, 0
	},
	{
		1141145600, 1124728832, 0
	},
	{
		1096642724, 1150640128, 0
	},
	{
		1147305984, 1133051904, 0
	},
	{
		1158255821, -996319232, 0
	},
	{
		1159290880, -1003716608, 0
	},
	{
		1158479462, -988934144, 0
	},
	{
		-996342825, -985403392, 1124859904
	},
	{
		-998440960, -987078656, 1124859904
	}
};
new Handle:hFilteredWords;
new bool:bInCageFromLadder[66];
new bool:bIsAprilFools;
new bool:bAlreadyCreated;
new Float:fLadder[3] =
{
	1151647990, -1002733896, 1124312678
};
new Float:fBigCageCenter[3] =
{
	1149657088, -1002700800, 1112014848
};
new g_iGame;
new m_clrRender = -1;

public OnPluginStart()
{
	HookEvent("round_start", OnRoundStart, EventHookMode:1);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode:1);
	CreateTimer(0.34, Timer_Teleport, any:0, 1);
	hFilteredWords = CreateArray(ByteCountToCells(32), 0);
	m_clrRender = FindSendPropOffs("CAI_BaseNPC", "m_clrRender");
	PushArrayString(hFilteredWords, "april");
	PushArrayString(hFilteredWords, "fools");
	PushArrayString(hFilteredWords, "aprl");
	PushArrayString(hFilteredWords, "apr");
	PushArrayString(hFilteredWords, "fool");
	PushArrayString(hFilteredWords, "april fols");
	RegConsoleCmd("fire", Command_Fire, "", 0);
	RegConsoleCmd("say", OnSay, "", 0);
	RegConsoleCmd("say_team", OnSay, "", 0);
	return 0;
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	decl String:game[256];
	GetGameFolderName(game, 256);
	if (StrEqual(game, "cstrike", true))
	{
		g_iGame = 0;
	}
	else
	{
		g_iGame = 1;
	}
	return APLRes:0;
}

public OnMapStart()
{
	if (IsAprilFools())
	{
		CreateBombZone();
	}
	if (g_iGame)
	{
		var1[0] = 2348;
	}
	else
	{
		var1[0] = 2312;
	}
	PrecacheModel(var1, false);
	return 0;
}

public OnPlayerSpawn(Handle:event, String:name[], bool:db)
{
	if (!bIsAprilFools)
	{
		return 0;
	}
	new userid = GetEventInt(event, "userid");
	CreateTimer(0.2, Timer_SetModels, userid, 0);
	return 0;
}

public OnRoundStart(Handle:event, String:name[], bool:db)
{
	if (!IsAprilFools())
	{
		return 0;
	}
	new index = -1;
	decl Float:angles[3];
	CreateBombZone();
	FlipProps("prop_physics_multiplayer");
	FlipProps("prop_dynamic");
	new max = GetRandomInt(7, 14);
	new Handle:arr = CreateArray(1, 0);
	new i;
	while (i < max)
	{
		index = 0;
		new j;
		while (j < 25)
		{
			new temp = GetRandomInt(0, 26);
			if (FindValueInArray(arr, temp) == -1)
			{
				index = temp;
				angles[0] = 0;
				angles[1] = GetRandomFloat(0, 360);
				angles[2] = 0;
				PushArrayCell(arr, index);
				new ent = CreateEntityByName("prop_physics_override", -1);
				if (g_iGame)
				{
					var1[0] = 2512;
				}
				else
				{
					var1[0] = 2476;
				}
				DispatchKeyValue(ent, "model", var1);
				DispatchKeyValue(ent, "spawnflags", "8");
				DispatchSpawn(ent);
				TeleportEntity(ent, fWallSpawns[index][0][0], angles, NULL_VECTOR);
				SetEntData(ent, m_clrRender + 3, any:0, 1, true);
				SetEntityRenderMode(ent, RenderMode:2);
				i++;
			}
			j++;
		}
		angles[0] = 0;
		angles[1] = GetRandomFloat(0, 360);
		angles[2] = 0;
		PushArrayCell(arr, index);
		new ent = CreateEntityByName("prop_physics_override", -1);
		if (g_iGame)
		{
			var1[0] = 2512;
		}
		else
		{
			var1[0] = 2476;
		}
		DispatchKeyValue(ent, "model", var1);
		DispatchKeyValue(ent, "spawnflags", "8");
		DispatchSpawn(ent);
		TeleportEntity(ent, fWallSpawns[index][0][0], angles, NULL_VECTOR);
		SetEntData(ent, m_clrRender + 3, any:0, 1, true);
		SetEntityRenderMode(ent, RenderMode:2);
		i++;
	}
	CloseHandle(arr);
	if (!g_iGame)
	{
		CreateTimer(5, Timer_Display, any:0, 0);
	}
	return 0;
}

public Action:Timer_Display(Handle:timer, data)
{
	PrintToChatAll("Terrorists are still on the terrorist team, and are still to be refered to as terrorists.");
	return Action:0;
}

public Action:Command_Fire(client, args)
{
	if (!client)
	{
		return Action:0;
	}
	PrintToChat(client, "Beats me why you wanna be set on fire, but OK.");
	IgniteEntity(client, 10, false, 0, false);
	return Action:0;
}

public Action:OnSay(client, args)
{
	if (!bIsAprilFools)
	{
		return Action:0;
	}
	decl String:text[256];
	GetCmdArgString(text, 255);
	StripQuotes(text);
	new i;
	while (GetArraySize(hFilteredWords) > i)
	{
		decl String:variation[32];
		GetArrayString(hFilteredWords, i, variation, 32);
		if (StrContains(text, variation, false) > -1)
		{
			return Action:4;
		}
		i++;
	}
	return Action:0;
}

public Action:Timer_SetModels(Handle:timer, client)
{
	if (!client)
	{
		return Action:0;
	}
	new team = GetClientTeam(client);
	if (team == 2)
	{
		if (g_iGame)
		{
		}
		else
		{
			PrecacheModel("models/player/hgmodels/hg_jbpd.mdl", false);
			SetEntityModel(client, "models/player/hgmodels/hg_jbpd.mdl");
		}
	}
	else
	{
		if (team == 3)
		{
			if (g_iGame)
			{
			}
			else
			{
				PrecacheModel("models/player/hgmodels/hg_jbprisoner.mdl", false);
				SetEntityModel(client, "models/player/hgmodels/hg_jbprisoner.mdl");
			}
		}
	}
	return Action:0;
}

public Action:Timer_Teleport(Handle:timer, data)
{
	if (!bIsAprilFools)
	{
		return Action:0;
	}
	new i = 1;
	while (i <= MaxClients)
	{
		if (!IsClientInGame(i))
		{
		}
		else
		{
			decl Float:origin[3];
			GetClientAbsOrigin(i, origin);
			if (GetEntityMoveType(i) == 9)
			{
				if (Distance(origin, fLadder) <= 1128792064)
				{
					TeleportEntity(i, fBigCageCenter, NULL_VECTOR, NULL_VECTOR);
					bInCageFromLadder[i] = 1;
				}
			}
			else
			{
				if (FloatAbs(origin[0] - fBigCageCenter[0][0]) <= 1127153664)
				{
					if (bInCageFromLadder[i][0][0])
					{
					}
					else
					{
						var3 = var3[0][150];
						TeleportEntity(i, fBigCageCenter, NULL_VECTOR, NULL_VECTOR);
						var4 = var4[0] - 150;
					}
				}
				bInCageFromLadder[i] = 0;
			}
		}
		i++;
	}
	return Action:0;
}

FlipProps(String:classname[])
{
	new index = -1;
	decl Float:angles[3];
	decl Float:origin[3];
	index = var1;
	while (var1 != -1)
	{
		GetEntPropVector(index, PropType:0, "m_angRotation", angles, 0);
		GetEntPropVector(index, PropType:0, "m_vecOrigin", origin, 0);
		var2 = var2[180];
		var3 = var3[50];
		SetEntityMoveType(index, MoveType:0);
		TeleportEntity(index, origin, angles, NULL_VECTOR);
	}
	return 0;
}

CreateBombZone()
{
	new i = FindEntityByClassname(-1, "func_bomb_target");
	if (!bIsAprilFools)
	{
		if (0 < i)
		{
			AcceptEntityInput(i, "Disable", -1, -1, 0);
		}
		return 0;
	}
	if (g_iGame)
	{
		i = CreateEntityByName("func_bomb_target", -1);
		bAlreadyCreated = 1;
		DispatchSpawn(i);
		ActivateEntity(i);
	}
	if (i == -1)
	{
		return 0;
	}
	decl Float:minbounds[3];
	decl Float:maxbounds[3];
	new Float:origin[3] = 0;
	TeleportEntity(i, origin, NULL_VECTOR, NULL_VECTOR);
	SetEntPropVector(i, PropType:0, "m_vecMins", minbounds, 0);
	SetEntPropVector(i, PropType:0, "m_vecMaxs", maxbounds, 0);
	SetEntProp(i, PropType:0, "m_nSolidType", any:2, 4, 0);
	AcceptEntityInput(i, "Enable", -1, -1, 0);
	return 0;
}

bool:IsAprilFools()
{
	decl String:date[32];
	FormatTime(date, 32, "%B %d", -1);
	bIsAprilFools = StrEqual(date, "April 01", true);
	return bIsAprilFools;
}

Float:Distance(Float:a[3], Float:b[3])
{
	return SquareRoot(Pow(a[0] - b[0], 2) + Pow(a[1] - b[1], 2) + Pow(a[2] - b[2], 2));
}

