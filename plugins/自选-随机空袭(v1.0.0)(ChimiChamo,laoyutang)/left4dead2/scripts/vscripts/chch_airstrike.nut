// Random Air Strikes on All Maps - original script and response rules by ChimiChamo.
// Fixes and repository packaging by laoyutang.
// Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=3163466945
// Repository maintenance version 1.0.0. Requires L4D2 VScript only.
if ("ChCh_RandomAirStrikes" in this)
    return;

ChCh_RandomAirStrikes <-
{
    Version = "1.0.0"
    SettingsFileName = "random_airstrikes/Settings.cfg"
    Defaults =
    {
        allowed_gamemodes = ["coop", "realism"]
        disallowed_maps = ["c1m1_hotel", "c1m3_mall", "c1m4_atrium", "c5m4_quarter", "c8m2_subway", "c8m4_interior", "c10m2_drainage", "c11m4_terminal", "c12m5_cornfield"]
        one_in_what_chance = 20
        flow_percent_dist_variance = 5
        air_strike_delay = 75
        drop_bomb = 1
        summon_horde = 0
        explode_radius = 500
        explode_dmg = 200
        initial_delay = 40
        check_interval = 1.0
        max_position_attempts = 16
        max_strike_distance = 1500
        plane_height = 2048
    }
    Limits =
    {
        one_in_what_chance = [1, 100000, true]
        flow_percent_dist_variance = [0, 100, false]
        air_strike_delay = [5, 3600, false]
        drop_bomb = [0, 1, true]
        summon_horde = [0, 1, true]
        explode_radius = [1, 4096, true]
        explode_dmg = [0, 10000, true]
        initial_delay = [0, 3600, false]
        check_interval = [0.1, 60, false]
        max_position_attempts = [1, 64, true]
        max_strike_distance = [128, 8192, false]
        plane_height = [256, 4096, false]
    }
    Settings = null
    LeavingTime = null
    NextCheckTime = 0.0
    NextStrikeTime = 0.0
    RoundActive = false
    Generation = 0
    NavAreas = []
    OwnedEntities = []

    function Log(message)
    {
        printl("[RandomAirStrikes] " + message);
    }

    // Read the original one-setting-per-line format as data, never as code.
    function ParseValue(value)
    {
        if (value == "true") return 1;
        if (value == "false") return 0;
        if (regexp(@"^-?[0-9]+(\.[0-9]+)?$").match(value))
        {
            local number = value.tofloat();
            if (number < -1000000 || number > 1000000)
                throw "number out of range";
            return value.find(".") == null ? number.tointeger() : number;
        }
        if (value.len() >= 2 && value.slice(0, 1) == "[" && value.slice(-1) == "]")
        {
            local result = [];
            local body = strip(value.slice(1, -1));
            if (body == "") return result;
            foreach (item in split(body, ","))
            {
                item = strip(item);
                if (!regexp("^\"[-a-zA-Z0-9_]+\"$").match(item))
                    throw "expected a quoted map or mode name";
                result.append(item.slice(1, -1));
            }
            return result;
        }
        throw "expected a number, boolean or array of names";
    }

    function ParseSettingsText(text)
    {
        local result = clone Defaults;
        local seen = {};
        local lineNumber = 0;
        foreach (line in split(text, "\n"))
        {
            lineNumber++;
            local comment = line.find("//");
            if (comment != null) line = line.slice(0, comment);
            line = strip(line);
            if (line == "" || line == "{" || line == "}" || line == "};") continue;
            if (line.slice(-1) == "," || line.slice(-1) == ";")
                line = strip(line.slice(0, -1));
            local separator = line.find("=");
            if (separator == null) throw "missing '=' on line " + lineNumber;
            local key = strip(line.slice(0, separator));
            if (!(key in Defaults)) throw "unknown setting: " + key;
            if (key in seen) throw "duplicate setting: " + key;
            local value = ParseValue(strip(line.slice(separator + 1)));
            if (type(Defaults[key]) == "array")
            {
                if (type(value) != "array") throw key + " must be an array";
            }
            else
            {
                local limit = Limits[key];
                if ((type(value) != "integer" && type(value) != "float") ||
                    (limit[2] && type(value) != "integer") ||
                    value < limit[0] || value > limit[1])
                    throw "invalid value for " + key;
            }
            seen[key] <- true;
            result[key] = value;
        }
        return result;
    }

    function SerializeSettings()
    {
        local data = "// Random Air Strikes " + Version + " - one setting per line.\n{\n";
        foreach (key, value in Settings)
        {
            data += "    " + key + " = ";
            if (type(value) == "array")
            {
                data += "[";
                foreach (index, item in value)
                    data += (index == 0 ? "" : ", ") + "\"" + item + "\"";
                data += "]";
            }
            else data += value.tostring();
            data += "\n";
        }
        return data + "}\n";
    }

    function ParseSettings()
    {
        Settings = clone Defaults;
        try
        {
            local file = FileToString(SettingsFileName);
            if (file == null)
            {
                if (!StringToFile(SettingsFileName, SerializeSettings()))
                    Log("Cannot create ems/" + SettingsFileName + "; using defaults.");
            }
            else Settings = ParseSettingsText(file);
        }
        catch (error)
        {
            // Leave the original file intact so administrators can correct it.
            Log("Invalid/unreadable settings; using defaults. " + error);
        }
    }

    function IsLivingSurvivor(player)
    {
        return player != null && player.IsValid() && player.IsSurvivor() &&
            NetProps.GetPropInt(player, "m_iTeamNum") == 2 && !player.IsDead() && !player.IsDying();
    }

    function GetLivingSurvivors()
    {
        local result = [];
        local player = null;
        while (player = Entities.FindByClassname(player, "player"))
            if (IsLivingSurvivor(player)) result.append(player);
        return result;
    }

    function IsAllowed()
    {
        return Settings.allowed_gamemodes.find(Director.GetGameModeBase()) != null &&
            Settings.disallowed_maps.find(Director.GetMapName()) == null;
    }

    function CanRunAction(generation)
    {
        return RoundActive && generation == Generation && IsAllowed() &&
            !Director.IsFinaleWon() && !Director.IsPlayingIntro() &&
            GetLivingSurvivors().len() > 0;
    }

    function Cleanup()
    {
        RoundActive = false;
        Generation++;
        foreach (entity in OwnedEntities)
            if (entity != null && entity.IsValid()) entity.Kill();
        OwnedEntities.clear();
        NavAreas.clear();
        LeavingTime = null;
        NextCheckTime = 0.0;
        NextStrikeTime = 0.0;
        g_MapScript.ScriptedMode_RemoveUpdate(IfBeginAirStrike);
    }

    function SpawnTemporary(classname, values, lifetime)
    {
        local entity = SpawnEntityFromTable(classname, values);
        if (entity == null || !entity.IsValid()) return null;
        OwnedEntities.append(entity);
        // Target the entity handle: a reused entity index must never be killed.
        DoEntFire("!self", "Kill", "", lifetime, null, entity);
        return entity;
    }

    // Ground the nav position from above, then require a clear column for the jet.
    // L4D2 TraceLine has no portable sky-surface output; worldspawn is NOT a sky test.
    function GetStrikePosition(spot, ignore)
    {
        local ground = {
            start = spot + Vector(0, 0, 32), end = spot - Vector(0, 0, 64),
            mask = 33570827, ignore = ignore // MASK_SOLID
        };
        if (!TraceLine(ground) || !ground.hit || ground.startsolid ||
            ground.fraction <= 0 ||
            ground.enthit == null || !ground.enthit.IsValid() ||
            ground.enthit.GetClassname() != "worldspawn") return null;

        local position = ground.pos + Vector(0, 0, 8);
        local overhead = {
            start = position, end = position + Vector(0, 0, Settings.plane_height + 128),
            mask = 33570827, ignore = ignore
        };
        if (!TraceLine(overhead) || overhead.startsolid || overhead.hit || overhead.fraction < 1.0)
            return null;
        return position;
    }

    function FindStrikePosition()
    {
        local leader = Director.GetHighestFlowSurvivor();
        if (!IsLivingSurvivor(leader)) return null;
        local origin = leader.GetOrigin();
        local flow = GetFlowPercentForPosition(origin, true);
        if (flow < 0 || flow > 100) return null;
        local candidates = [];
        local maxDistanceSquared = Settings.max_strike_distance * Settings.max_strike_distance;
        foreach (nav in NavAreas)
        {
            // CHECKPOINT is 2048; reject both starting and ending saferoom areas.
            if (nav.IsDegenerate() || nav.HasSpawnAttributes(2048) || nav.IsUnderwater() || nav.IsBlocked(2, false)) continue;
            if (nav.GetDistanceSquaredToPoint(origin) <= maxDistanceSquared)
                candidates.append(nav);
        }

        for (local attempt = 0; attempt < Settings.max_position_attempts && candidates.len() > 0; attempt++)
        {
            // Sample without replacement instead of returning the first nav in table order.
            local index = RandomInt(0, candidates.len() - 1);
            local nav = candidates[index];
            candidates[index] = candidates[candidates.len() - 1];
            candidates.pop();
            local spot = nav.FindRandomSpot();
            if ((spot - origin).LengthSqr() > maxDistanceSquared) continue;
            local candidateFlow = GetFlowPercentForPosition(spot, true);
            if (candidateFlow < 0 || candidateFlow > 100 ||
                fabs(candidateFlow - flow) > Settings.flow_percent_dist_variance) continue;
            local position = GetStrikePosition(spot, leader);
            if (position != null && (position - origin).LengthSqr() <= maxDistanceSquared)
                return position;
        }
        return null;
    }

    function NukeThePlace(where, angles, carrier, generation)
    {
        if (!CanRunAction(generation) || carrier == null || !carrier.IsValid()) return;
        local boom = SpawnTemporary("env_explosion", {
            origin = where, angles = angles, iMagnitude = Settings.explode_dmg,
            iRadiusOverride = Settings.explode_radius, spawnflags = 68
        }, 1.0);
        if (boom == null) return;
        foreach (effect in ["weapon_grenadelauncher", "gas_explosion_chunks_02"])
            SpawnTemporary("info_particle_system", {
                origin = where, angles = angles, effect_name = effect,
                start_active = 1, flag_as_weather = 0
            }, 8.0);
        EmitAmbientSoundOn("ambient/explosions/explode_" + RandomInt(1, 3) + ".wav",
            1.0, 120, RandomInt(95, 105), carrier);
        DoEntFire("!self", "Explode", "", 0.0, null, boom);

        local player = null;
        while (player = Entities.FindByClassnameWithin(player, "player", where, Settings.explode_radius))
        {
            if (!IsLivingSurvivor(player)) continue;
            local sight = { start = where, end = player.EyePosition(), mask = 33570827, ignore = player };
            if (!TraceLine(sight) || sight.startsolid || sight.hit) continue;
            player.Stagger(where);
            QueueSpeak(player, "ChCh_AirStrikeClose", 0.0, "");
        }
        DoEntFire("!self", "RunScriptCode", "ChCh_Respond()", 2.0, null, carrier);
        if (Settings.summon_horde == 1)
            DoEntFire("!self", "RunScriptCode", "ChCh_Horde()", RandomFloat(3.0, 4.0), null, carrier);
    }

    function DoAirStrike()
    {
        if (!CanRunAction(Generation) || Time() < NextStrikeTime) return false;
        local position = FindStrikePosition();
        if (position == null) return false;
        local angles = "0 " + RandomInt(0, 359) + " 0";
        local carrier = SpawnTemporary("info_target", { origin = position }, 15.0);
        if (carrier == null) return false;
        local plane = SpawnTemporary("prop_dynamic", {
            origin = position + Vector(0, 0, Settings.plane_height), angles = angles,
            model = "models/f18/f18.mdl", fademindist = -1, fademaxdist = 0, solid = 0
        }, 30.0);
        if (plane == null)
        {
            carrier.Kill();
            return false;
        }
        if (!carrier.ValidateScriptScope())
        {
            carrier.Kill();
            plane.Kill();
            return false;
        }
        local scope = carrier.GetScriptScope();
        local air = this;
        local generation = Generation;
        scope.ChCh_Jet <- function() {
            if (air.CanRunAction(generation))
                EmitAmbientSoundOn("animation/jets/jet_by_0" + RandomInt(1, 2) + "_mono.wav",
                    1.0, 0, RandomInt(95, 105), carrier);
        };
        scope.ChCh_Bomb <- function() { air.NukeThePlace(position, angles, carrier, generation); };
        scope.ChCh_Respond <- function() {
            if (!air.CanRunAction(generation)) return;
            local survivors = air.GetLivingSurvivors();
            if (survivors.len() > 0)
                QueueSpeak(survivors[RandomInt(0, survivors.len() - 1)], "ChCh_AirStrikeResp", 0.0, "");
        };
        scope.ChCh_Horde <- function() {
            if (air.CanRunAction(generation)) Director.ResetMobTimer();
        };

        local animation = RandomInt(1, 5);
        local boomTime = animation >= 3 ? 3.2 : 2.6;
        EntityOutputs.AddOutput(plane, "OnAnimationDone", "!self", "Kill", "", 0.0, 1);
        DoEntFire("!self", "SetAnimation", "flyby" + animation, 0.0, null, plane);
        DoEntFire("!self", "RunScriptCode", "ChCh_Jet()", boomTime - 1.0, null, carrier);
        if (Settings.drop_bomb == 1)
            DoEntFire("!self", "RunScriptCode", "ChCh_Bomb()", boomTime + RandomFloat(0.2, 0.5), null, carrier);
        NextStrikeTime = Time() + Settings.air_strike_delay;
        return true;
    }

    function Update()
    {
        local now = Time();
        if (!RoundActive || now < NextCheckTime) return;
        NextCheckTime = now + Settings.check_interval;
        for (local index = OwnedEntities.len() - 1; index >= 0; index--)
            if (!OwnedEntities[index].IsValid()) OwnedEntities.remove(index);
        if (!IsAllowed() || Director.IsFinaleWon() || Director.IsPlayingIntro()) return;
        if (!Director.HasAnySurvivorLeftSafeArea()) return;
        // Covers script loading after player_left_safe_area was already dispatched.
        if (LeavingTime == null) LeavingTime = now;
        if (now < LeavingTime + Settings.initial_delay || now < NextStrikeTime) return;
        if (RandomInt(1, Settings.one_in_what_chance) == 1) DoAirStrike();
    }

    function IfBeginAirStrike()
    {
        DirectorScript.ChCh_RandomAirStrikes.Update();
    }

    function OnGameEvent_round_start(params)
    {
        Cleanup();
        ParseSettings();
        if (!IsAllowed()) return;
        if (!IsModelPrecached("models/f18/f18.mdl")) PrecacheModel("models/f18/f18.mdl");
        foreach (sound in ["animation/jets/jet_by_01_mono.wav", "animation/jets/jet_by_02_mono.wav",
            "ambient/explosions/explode_1.wav", "ambient/explosions/explode_2.wav", "ambient/explosions/explode_3.wav"])
            if (!IsSoundPrecached(sound)) PrecacheSound(sound);
        local areas = {};
        NavMesh.GetAllAreas(areas);
        foreach (nav in areas) NavAreas.append(nav);
        RoundActive = true;
        g_MapScript.ScriptedMode_AddUpdate(IfBeginAirStrike);
    }

    function OnGameEvent_player_left_safe_area(params)
    {
        if (RoundActive && LeavingTime == null) LeavingTime = Time();
    }

    function OnGameEvent_round_end(params) { Cleanup(); }
    function OnGameEvent_map_transition(params) { Cleanup(); }
    function OnGameEvent_finale_win(params) { Cleanup(); }
};

ChCh_RandomAirStrikes.ParseSettings();
__CollectEventCallbacks(ChCh_RandomAirStrikes, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);
ChCh_RandomAirStrikes.Log("Loaded maintenance version " + ChCh_RandomAirStrikes.Version);

// Original survivor response rules follow.
IncludeScript("response_testbed", this)

local newrules =
[
	{
		name = "ChCh_AirStrikeCloseGambler",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeClose" ],
			[ "who", "Gambler" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/Gambler/WorldC5M4B06.vcd",   }  //SHIT!
            {   scenename = "scenes/Gambler/WorldC5M4B07.vcd",   }  //SHIT!
            {   scenename = "scenes/Gambler/World219.vcd",   }  //WHAT THE -  (reaction to bombing)
            {   scenename = "scenes/Gambler/WorldC2M127.vcd",   }  //Woah shit.
            {   scenename = "scenes/Gambler/World220.vcd",   }  //WHAT THE HELL ARE THEY DOING?  (reaction to bombing)
            {   scenename = "scenes/Gambler/WorldC5M4B03.vcd",   }  //STOP BOMBING US!
		],
		group_params = g_rr.RGroupParams({})
	}

	{
		name = "ChCh_AirStrikeRespGambler",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeResp" ],
			[ "who", "Gambler" ],
            [ "Coughing", 0 ],
            [ "NumberOfTeamAlive", 2,null ],
            [ "speaking", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/Gambler/World221.vcd",   }  //Everybody okay?
            {   scenename = "scenes/Gambler/World222.vcd",   }  //Was that aimed at us?!
            {   scenename = "scenes/Gambler/WorldC5M4B02.vcd",   }  //Well, it's official: They're trying to kill US now.
            {   scenename = "scenes/Gambler/WorldC5M4B09.vcd",   }  //Well, it's official: They're trying to kill US now.
            {   scenename = "scenes/Gambler/WorldC5M4B05.vcd",   }  //Christ, those guys are such assholes.
		],
		group_params = g_rr.RGroupParams({})
	}

	{
		name = "ChCh_AirStrikeCloseProducer",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeClose" ],
			[ "who", "Producer" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/Producer/ReactionNegative13.vcd",   }  //Holy shit!
            {   scenename = "scenes/Producer/WorldC5M3B11.vcd",   }  //What are they doing!?
            {   scenename = "scenes/Producer/LedgeHangSlip03.vcd",   }  //Woah woah woah
		],
		group_params = g_rr.RGroupParams({})
	}

	{
		name = "ChCh_AirStrikeRespProducer",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeResp" ],
			[ "who", "Producer" ],
            [ "Coughing", 0 ],
            [ "NumberOfTeamAlive", 2,null ],
            [ "speaking", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/Producer/WorldC5M4B02.vcd",   }  //We aren't safe here.
            {   scenename = "scenes/Producer/WorldC5M4B04.vcd",   }  //Something tells me they're not checking for survivors anymore.
            {   scenename = "scenes/Producer/WorldC5M4B01.vcd",   }  //We need to keep moving.
		],
		group_params = g_rr.RGroupParams({})
	}

	{
		name = "ChCh_AirStrikeCloseCoach",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeClose" ],
			[ "who", "Coach" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/Coach/WorldC5M4B03.vcd",   }  //SHIT!
            {   scenename = "scenes/Coach/Exclamation01.vcd",   }  //Oh Shit!
		],
		group_params = g_rr.RGroupParams({})
	}

	{
		name = "ChCh_AirStrikeRespCoach",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeResp" ],
			[ "who", "Coach" ],
            [ "Coughing", 0 ],
            [ "NumberOfTeamAlive", 2,null ],
            [ "speaking", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/Coach/WorldC5M4B02.vcd",   }  //STOP BOMBING US.
            {   scenename = "scenes/Coach/TeamKillAccident05.vcd",   }  //What the f'...  don't be doin that.
            {   scenename = "scenes/Coach/TeamKillAccident06.vcd",   }  //Hey! Don't be doin that.
		],
		group_params = g_rr.RGroupParams({})
	}

	{
		name = "ChCh_AirStrikeCloseMechanic",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeClose" ],
			[ "who", "Mechanic" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/Mechanic/WorldC5M4B01.vcd",   }  //Woah!
            {   scenename = "scenes/Mechanic/WorldC5M103.vcd",   }  //HEY, STOP WITH THE BOMBING!
            {   scenename = "scenes/Mechanic/WorldC5M104.vcd",   }  //PLEASE DO NOT BOMB US!
            {   scenename = "scenes/Mechanic/TeamKillAccident05.vcd",   }  //Jesus Christ, man!
		],
		group_params = g_rr.RGroupParams({})
	}

	{
		name = "ChCh_AirStrikeRespMechanic",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeResp" ],
			[ "who", "Mechanic" ],
            [ "Coughing", 0 ],
            [ "NumberOfTeamAlive", 2,null ],
            [ "speaking", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/Mechanic/WorldC5M4B04.vcd",   }  //We need to get the hell out of here.
            {   scenename = "scenes/Mechanic/WorldC5M4B05.vcd",   }  //They must not see us.
            {   scenename = "scenes/Mechanic/WorldC5M4B02.vcd",   }  //They nailed that.
            {   scenename = "scenes/Mechanic/WorldC5M4B03.vcd",   }  //What are they even aiming at?
            {   scenename = "scenes/Mechanic/World216.vcd",   }  //Hit the deck!
            {   scenename = "scenes/Mechanic/World217.vcd",   }  //We all in one piece?
		],
		group_params = g_rr.RGroupParams({})
	}

	{
		name = "ChCh_AirStrikeCloseNamVet",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeClose" ],
			[ "who", "NamVet" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/NamVet/Swears04.vcd",   }  //Bull-frickin-horseshit.
            {   scenename = "scenes/NamVet/FallShort01.vcd",   }  //[Yelp]
            {   scenename = "scenes/NamVet/FallShort03.vcd",   }  //[Yelp]
		],
		group_params = g_rr.RGroupParams({})
	}

	{
		name = "ChCh_AirStrikeRespNamVet",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeResp" ],
			[ "who", "NamVet" ],
            [ "Coughing", 0 ],
            [ "NumberOfTeamAlive", 2,null ],
            [ "speaking", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/NamVet/WorldFarmHouse0502.vcd",   }  //The honest to God military!
            {   scenename = "scenes/NamVet/TeamKillAccident02.vcd",   }  //Have you lost your mind?
            {   scenename = "scenes/NamVet/TeamKillAccident04.vcd",   }  //Watch it, Watch it!
            {   scenename = "scenes/NamVet/FriendlyFire03.vcd",   }  //Do I look like a target?
            {   scenename = "scenes/NamVet/FriendlyFire16.vcd",   }  //Hold your fire!
		],
		group_params = g_rr.RGroupParams({})
	}

	{
		name = "ChCh_AirStrikeCloseTeenGirl",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeClose" ],
			[ "who", "TeenGirl" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/TeenGirl/Swear06.vcd",   }  //Mother.
            {   scenename = "scenes/TeenGirl/FallShort01.vcd",   }  //[improv quick yelp]
            {   scenename = "scenes/TeenGirl/FallShort03.vcd",   }  //[improv quick yelp]
		],
		group_params = g_rr.RGroupParams({})
	}

	{
		name = "ChCh_AirStrikeRespTeenGirl",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeResp" ],
			[ "who", "TeenGirl" ],
            [ "Coughing", 0 ],
            [ "NumberOfTeamAlive", 2,null ],
            [ "speaking", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/TeenGirl/TeamKillAccident03.vcd",   }  //You REALLY have to be more careful!
            {   scenename = "scenes/TeenGirl/TeamKillAccident06.vcd",   }  //Stop Stop!
            {   scenename = "scenes/TeenGirl/FriendlyFire03.vcd",   }  //Watch it!
            {   scenename = "scenes/TeenGirl/FriendlyFire14.vcd",   }  //Hey, come on! Stop!
            {   scenename = "scenes/TeenGirl/FriendlyFire17.vcd",   }  //What the hell?
		],
		group_params = g_rr.RGroupParams({})
	}

	{
		name = "ChCh_AirStrikeCloseManager",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeClose" ],
			[ "who", "Manager" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/Manager/FallShort01.vcd",   }  //[Yelp]
            {   scenename = "scenes/Manager/FallShort03.vcd",   }  //[Yelp]
            {   scenename = "scenes/Manager/FallShort04.vcd",   }  //[Yelp]
		],
		group_params = g_rr.RGroupParams({})
	}

	{
		name = "ChCh_AirStrikeRespManager",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeResp" ],
			[ "who", "Manager" ],
            [ "Coughing", 0 ],
            [ "NumberOfTeamAlive", 2,null ],
            [ "speaking", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/Manager/TeamKillAccident03.vcd",   }  //What the hell man?
            {   scenename = "scenes/Manager/TeamKillAccident04.vcd",   }  //Be careful, what are you doing?
            {   scenename = "scenes/Manager/FriendlyFire02.vcd",   }  //AH! Will you knock it off?
            {   scenename = "scenes/Manager/FriendlyFire03.vcd",   }  //Do I look like one of them?
            {   scenename = "scenes/Manager/FriendlyFire12.vcd",   }  //I'm gonna shoot you back next time
		],
		group_params = g_rr.RGroupParams({})
	}

	{
		name = "ChCh_AirStrikeCloseBiker",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeClose" ],
			[ "who", "Biker" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/Biker/FallShort02.vcd",   }  //[Yelp]
            {   scenename = "scenes/Biker/FallShort03.vcd",   }  //[Yelp]
		],
		group_params = g_rr.RGroupParams({})
	}

	{
		name = "ChCh_AirStrikeRespBiker",
		criteria =
		[
			[ "concept", "ChCh_AirStrikeResp" ],
			[ "who", "Biker" ],
            [ "Coughing", 0 ],
            [ "NumberOfTeamAlive", 2,null ],
            [ "speaking", 0 ],
            [ "Incapacitated", 0 ],
		],
		responses =
		[
            {   scenename = "scenes/Biker/WorldFarmHouse0528.vcd", speakonce = true  }  //I LOVE the goddamn army!
            {   scenename = "scenes/Biker/DLC2ArmyTruck01.vcd",   }  //Huh. The army. Fat lotta help they've been to US.
            {   scenename = "scenes/Biker/DLC2ArmyTruck02.vcd",   }  //Huh. The army. They're about as much help as the cops.
            {   scenename = "scenes/Biker/TeamKillAccident04.vcd",   }  //Pull yer head outta yer ass.
            {   scenename = "scenes/Biker/FriendlyFire02.vcd",   }  //Dammit! Will you knock it off!
            {   scenename = "scenes/Biker/FriendlyFire03.vcd",   }  //Will you knock it off!
            {   scenename = "scenes/Biker/FriendlyFire04.vcd",   }  //Do I look like a target?
		],
		group_params = g_rr.RGroupParams({})
	}
]
g_rr.rr_ProcessRules( newrules );
