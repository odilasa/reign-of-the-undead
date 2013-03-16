/******************************************************************************
    Reign of the Undead, v2.x

    Copyright (c) 2010-2013 Reign of the Undead Team.
    See AUTHORS.txt for a listing.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to
    deal in the Software without restriction, including without limitation the
    rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
    sell copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

    The contents of the end-game credits must be kept, and no modification of its
    appearance may have the effect of failing to give credit to the Reign of the
    Undead creators.

    Some assets in this mod are owned by Activision/Infinity Ward, so any use of
    Reign of the Undead must also comply with Activision/Infinity Ward's modtools
    EULA.
******************************************************************************/

#include scripts\include\hud;
#include scripts\include\array;
#include scripts\include\utility;

initGame()
{
    debugPrint("in _survival::initGame()", "fn", level.nonVerbose);

    level.currentWave = 1;
    level.waveOrderCurrentWave = 0;
    level.playWave = true;
    level.wavesRepeat = level.dvar["surv_waves_repeat"];
    level.currentWaveRepitition = 0;
    level.hasReceivedDamage = 0;
    level.canBuyRaygun = false;
    thread loadConfig();
}

loadConfig()
{
    debugPrint("in _survival::loadConfig()", "fn", level.nonVerbose);

    wait .1;// Assume types not set, loading default
//     dvarDefault("surv_special1", "dog");
//     dvarDefault("surv_special2", "burning");
//     dvarDefault("surv_special3", "toxic");
//     dvarDefault("surv_special4", "tank");
//     dvarDefault("surv_special5", "boss");
    dvarDefault("surv_special_final", "boss");  // rotu 2.2
    dvarDefault("surv_total_waves", 12);        // rotu 2.2
    dvarDefault("surv_wave_count_system", "2.2"); // rotu 2.2

    level.waveCountSystem = getDvar("surv_wave_count_system");
    level.totalWaves = getDvarInt("surv_total_waves");
    level.finalWave = getDvar("surv_special_final");
    level.nthZombieIsSpecial = getDvarInt("surv_nth_zombie_is_special");
    level.secondHalfZombieDifficultyFactor = getDvarFloat("surv_second_half_zombie_difficulty_factor");
    level.specialWaveSizeFactor = getDvarFloat("surv_special_wave_size_factor");

    // Load an arbitrary number of surv_special[n] dvars
    if (level.survMode == "special")
    {
        level.specialWaves = [];
        for (i=0; i<level.dvar["surv_specialwaves"]; i++)
        {
            get = getdvar("surv_special"+(i+1));
            if(get == "") {break;}
            level.specialWaves[i]=get;
//             debugPrint("special wave " + (i+1) + " is: " + level.specialWaves[i], "val");
        }
    }

    if (level.dvar["surv_weaponmode"] == "wawzombies")
    {
        level.onGiveWeapons = 0;
        level.ammoStockType = "weapon";
        level.spawnPrimary = level.dvar["surv_waw_spawnprimary"];
        level.spawnSecondary = level.dvar["surv_waw_spawnsecondary"];
    }
    else if (level.dvar["surv_weaponmode"] == "upgrade")
    {
        level.onGiveWeapons = 1;
        level.ammoStockType = "upgrade";
    }

    level.slowBots = 1 - level.dvar["surv_slow_start"];
    if (level.waveCountSystem == "2.1") {
        calculateNumberOfWaves();
    }

    buildWaveOrder();
}


/**
 * @brief Creates a random wave order for the game
 *
 * @returns nothing
 */
buildWaveOrder()
{
    debugPrint("in _survival::buildWaveOrder()", "fn", level.nonVerbose);

    // Build a pool to choose waves from randomly
    wavePool = level.specialWaves;
    index = level.specialWaves.size;
    while (index < level.totalWaves - 1) {
        wavePool[index] = "regular";
        index++;
    }

    // Select wave ordering randomly
    for (i=0; i<level.totalWaves - 1; i++) {
        randomIndex = randomInt(wavePool.size);
        level.waveOrder[i] = wavePool[randomIndex];
        wavePool = removeElementByIndex(wavePool, randomIndex);
    }

    // Tack on the final wave
    level.waveOrder[level.totalWaves - 1] = level.finalWave;

    debugPrint("Total waves is: " + level.totalWaves, "val");
    for (i=0; i<level.waveOrder.size; i++) {
        debugPrint("Wave [" + i + "] is " + level.waveOrder[i], "val");
    }
}

dvarDefault(dvar, def)
{
    debugPrint("in _survival::dvarDefault()", "fn", level.nonVerbose);

    if (getdvar(dvar) == "") {setdvar(dvar,def);}
}

addSpawn(targetname, priority)
{
    debugPrint("in _survival::addSpawn()", "fn", level.nonVerbose);

    if (!isdefined(level.survSpawns)) {return -1;}

    if (!isdefined(priority)) {priority = 1;}

    spawns = getentarray(targetname, "targetname");

    if (spawns.size > 0) {
        index = level.survSpawns.size;
        level.survSpawnsPriority[index] = priority;
        level.survSpawnsTotalPriority = level.survSpawnsTotalPriority + priority;
        level.survSpawns[index] = targetname;
    }
}

getRandomSpawn()
{
    debugPrint("in _survival::getRandomSpawn()", "fn", level.absurdVerbosity);

    spawn = undefined;
    random = randomint(level.survSpawnsTotalPriority);
    for (i=0; i<level.survSpawns.size; i++) {
        random = random - level.survSpawnsPriority[i];
        if (random < 0) {
            spawn = level.survSpawns[i];
            break;
        }
    }
    if (isDefined(spawn)) {
        array = getentarray(spawn, "targetname");
        return array[randomint(array.size)];
    }
}


/**
 * @brief Calculates the total number of waves
 *
 * @returns nothing
 */
calculateNumberOfWaves()
{
    debugPrint("in _survival::calculateNumberOfWaves()", "fn", level.lowVerbosity);

    specialWaves = level.dvar["surv_specialwaves"];
    regularWaves = specialWaves * (level.dvar["surv_specialinterval"] - 1);
    level.totalWaves = level.dvar["surv_waves_repeat"] * (regularWaves + specialWaves);
}


/**
 * @brief Calculates the number of zombies in a wave based on the wave system
 *
 * @param wave integer The one-based wave number to calculate the number of zombies for
 *
 * @returns the number of zombies in the wave
 */
getWaveSize(wave)
{
    debugPrint("in _survival::getWaveSize()", "fn", level.nonVerbose);

    waveid = wave - 1;
    players = level.players.size;
    switch (level.dvar["surv_wavesystem"])
    {
        case 0:
            return level.dvar["surv_zombies_initial"] + players * level.dvar["surv_zombies_perplayer"];
        case 1:
            return level.dvar["surv_zombies_initial"] + waveid * level.dvar["surv_zombies_perwave"];
        case 2:
            return level.dvar["surv_zombies_initial"] + players * (waveid * level.dvar["surv_zombies_perwave"] + level.dvar["surv_zombies_perplayer"]);
        case 3:
            return level.dvar["surv_zombies_initial"] + players * level.dvar["surv_zombies_perplayer"] + waveid * level.dvar["surv_zombies_perwave"];
    }
}

beginGame()
{
    debugPrint("in _survival::beginGame()", "fn", level.nonVerbose);

    if (level.survMode == "special") {
        scripts\gamemodes\_gamemodes::buildZomTypes("basic");
    } else {
        scripts\gamemodes\_gamemodes::buildZomTypes("all");
    }
    level.zomIdleBehavior = "magic";

    /// @bug maps trying to precache after this wait call--it fails
    // try to eliminate this wait, see if that works ok.
    wait 5;

    thread mainGametype();
    //thread watchEnd();
}

watchEnd()
{
    debugPrint("in _survival::watchEnd()", "fn", level.nonVerbose);

    level endon( "game_ended" );
    level endon("wave_finished");
    //wait 5;
    while (1) {
        if (level.alivePlayers == 0) {
            thread scripts\gamemodes\_gamemodes::endMap("All survivors have died!");
            return;
        }
        wait .5;
    }
}



mainGametype()
{
    debugPrint("in _survival::mainGametype()", "fn", level.nonVerbose);

    level endon( "game_ended" );

    thread survivorsHUD();

    // Some legacy maps (e.g. mp_surv_overrun) seem to not use waypoints, so level.wp.size is zero.
    // In these cases, we just get a random spawn points; make a note of this in the logs
    if (level.wp.size == 0) {
        noticePrint("Legacy map " + getdvar("mapname") + " doesn't use waypoints. Using random spawn points instead of waypoints for spawning and emberFX");
    }

    if (level.waveCountSystem == "2.1") {
        for (iii=0; iii<level.wavesRepeat; iii++) {
            for (i=0; i<level.dvar["surv_specialwaves"]; i++)
            {
                if (isdefined(level.specialWaves[i])) {
                    special = level.specialWaves[i];
                } else {
                    special = level.specialWaves[randomint(level.specialWaves.size)];
                }

                if (special != "boss") {
                    scripts\gamemodes\_gamemodes::addSpawnType(special);
                }

                for (j=1; j<level.dvar["surv_specialinterval"]; j++) {
                    startRegularWave();
                }

                startSpecialWave(special);
            }
            level.zom_types["zombie"].maxHealth*= 1 + (0.5 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["zombie"].damage*= 1 + (0.4 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["fat"].maxHealth*= 1 + (1.0 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["fat"].damage*= 1 + (0.4 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["fast"].runSpeed*= 1 + (0.2 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["fast"].maxHealth*= 1 + (0.3 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["fast"].damage*= 1 + (0.4 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["runners"].runSpeed*= 1 + (0.2 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["runners"].maxHealth*= 1 + (0.3 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["runners"].damage*= 1 + (0.4 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["tank"].maxHealth*= 1 + (0.1 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["tank"].damage*= 1 + (0.2 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["burning_tank"].maxHealth*= 1 + (0.1 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["burning_tank"].damage*= 1 + (0.2 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["burning"].damage*= 1 + (0.6 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["burning_dog"].damage*= 1 + (0.6 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["toxic"].damage*= 1 + (0.5 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["toxic"].maxhealth*= 1 + (0.5 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["dog"].damage *=  1 + (0.4 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["dog"].maxHealth *= 1 + (0.5 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["cyclops"].damage *= 1 + (0.4 * level.secondHalfZombieDifficultyFactor);
            level.zom_types["cyclops"].maxHealth *= 1 + (0.5 * level.secondHalfZombieDifficultyFactor);
            level.currentWaveRepitition++;
            allowRaygun();
            level.rewardScale *= 2;
        }
    } else if (level.waveCountSystem == "2.2") {
        for (level.waveOrderCurrentWave=0; level.waveOrderCurrentWave<level.waveOrder.size; level.waveOrderCurrentWave++) {
            // After half the waves, make zombies harder
            if (level.waveOrderCurrentWave==Int(level.waveOrder.size / 2)) {
                level.zom_types["zombie"].maxHealth*= 1 + (0.5 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["zombie"].damage*= 1 + (0.4 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["fat"].maxHealth*= 1 + (1.0 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["fat"].damage*= 1 + (0.4 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["fast"].runSpeed*= 1 + (0.2 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["fast"].maxHealth*= 1 + (0.3 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["fast"].damage*= 1 + (0.4 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["runners"].runSpeed*= 1 + (0.2 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["runners"].maxHealth*= 1 + (0.3 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["runners"].damage*= 1 + (0.4 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["tank"].maxHealth*= 1 + (0.1 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["tank"].damage*= 1 + (0.2 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["burning_tank"].maxHealth*= 1 + (0.1 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["burning_tank"].damage*= 1 + (0.2 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["burning"].damage*= 1 + (0.6 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["burning_dog"].damage*= 1 + (0.6 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["toxic"].damage*= 1 + (0.5 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["toxic"].maxhealth*= 1 + (0.5 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["dog"].damage *=  1 + (0.4 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["dog"].maxHealth *= 1 + (0.5 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["cyclops"].damage *= 1 + (0.4 * level.secondHalfZombieDifficultyFactor);
                level.zom_types["cyclops"].maxHealth *= 1 + (0.5 * level.secondHalfZombieDifficultyFactor);
                allowRaygun();
                level.rewardScale *= 2;
            }
            if (level.waveOrder[level.waveOrderCurrentWave]=="regular") {startRegularWave();}
            else {startSpecialWave(level.waveOrder[level.waveOrderCurrentWave]);}
        }
    }

    thread scripts\gamemodes\_gamemodes::endMap("All waves have been held off!", 1);
}

allowRaygun()
{
    debugPrint("in _survival::allowRaygun()", "fn", level.nonVerbose);

    level.canBuyRaygun = true;
    for (i=0; i<level.players.size; i++) {
        if (level.players[i].canGetSpecialWeapons) {
            level.players[i] setclientdvar("ui_raygun", 1); // enable raygun in shop
        } else {
            level.players[i] setclientdvar("ui_raygun", 0); // disable raygun in shop
        }
    }
}

survivorsHUD()
{
    debugPrint("in _survival::survivorsHUD()", "fn", level.nonVerbose);

    if (level.dvar["hud_survivors_left"]) {
        overlay = overlayMessage(&"ZOMBIE_SURV_LEFT", level.alivePlayers, (0,1,0), 1.4);
        overlay.alignX = "right";
        overlay.horzAlign = "right";
        overlay.x = -16;
        overlay.y = 16;
        overlay.font = "default";
        overlay thread survivorLeft();
        overlay thread destroySurvivorsLeft();
    }
    if (level.dvar["hud_survivors_down"]) {
        overlay2 = overlayMessage(&"ZOMBIE_SURV_DOWN", level.activePlayers-level.alivePlayers, (1,0,0), 1.4);
        overlay2.alignX = "right";
        overlay2.horzAlign = "right";
        overlay2.x = -16;
        overlay2.y = 34;
        overlay2.font = "default";
        overlay2 thread survivorDown();
        overlay2 thread destroySurvivorsDown();
    }
    if (level.dvar["hud_wave_number"]) {
        overlay3 = overlayMessage(&"ZOMBIE_WAVE_NUMBER", level.currentWave + "/" + level.totalWaves, (0,0,1), 1.4);
        overlay3.alignX = "right";
        overlay3.horzAlign = "right";
        overlay3.x = -16;
        overlay3.y = 52;
        overlay3.font = "default";
        overlay3 thread waveNumber();
        overlay3 thread destroyWaveNumber();
    }
}

destroySurvivorsLeft()
{
    debugPrint("in _survival::destroySurvivorsLeft()", "fn", level.nonVerbose);

    level endon("post_mapvote");
    while (1) {
        level waittill("starting_credits");
        wait 2;
        self FadeOverTime(1);
        self.alpha = 0;
        wait 1;
        self destroy();
        wait 3;
    }
}

destroySurvivorsDown()
{
    debugPrint("in _survival::destroySurvivorsDown()", "fn", level.nonVerbose);

    level endon("post_mapvote");
    while (1) {
        level waittill("starting_credits");
        wait 2;
        self FadeOverTime(1);
        self.alpha = 0;
        wait 1;
        self destroy();
        wait 3;
    }
}

destroyWaveNumber()
{
    debugPrint("in _survival::destroyWaveNumber()", "fn", level.nonVerbose);

    level endon("post_mapvote");
    while (1) {
        level waittill("starting_credits");
        wait 2;
        self FadeOverTime(1);
        self.alpha = 0;
        wait 1;
        self destroy();
        wait 3;
    }
}

waveNumber()
{
    debugPrint("in _survival::waveNumber()", "fn", level.nonVerbose);

    level endon("game_ended");
    while (1) {
        level waittill("wave_finished");
        wait .1;
        if (level.currentWaveRepitition==1) {self.color = (1,0,0);}

        // Fix bug where current wave exceeds total waves when game is finished
        if (level.currentWave > level.totalWaves) {
            level.currentWave = level.totalWaves;
        }
        self setText(level.currentWave + "/" + level.totalWaves);
    }
}

survivorLeft()
{
    debugPrint("in _survival::survivorLeft()", "fn", level.nonVerbose);

    level endon("game_ended");
    while (1) {
        self setText(level.alivePlayers);
        wait 1;
    }
}

survivorDown()
{
    debugPrint("in _survival::survivorDown()", "fn", level.nonVerbose);

    level endon("game_ended");

    while (1) {
        val = level.activePlayers-level.alivePlayers;
        self setText(val);
        wait 1;
    }
}

/**
 * @brief Starts a regular wave of zombies
 *
 * @returns nothing
 */
startRegularWave()
{
    debugPrint("in _survival::startRegularWave()", "fn", level.nonVerbose);

    level endon( "game_ended" );
    level.intermission = 1;

    timer(level.dvar["surv_timeout"], &"ZOMBIE_NEWWAVEIN", (.2,.7,0));
    wait level.dvar["surv_timeout"] + 2;

    level.waveSize = getWaveSize(level.currentWave);
    level.waveProgress = 0;

    if (level.dvar["surv_endround_revive"]) {
        for (i=0; i<level.players.size; i++) {
            player = level.players[i];
            if (player.isDown) {
                player thread scripts\players\_players::revive();
            }
        }
    }

    announceMessage(&"ZOMBIE_NEWWAVE", level.waveSize, (.2,.7,0), 4, 95);

    wait 5;

    scripts\server\_environment::setAmbient("zom_ambient");

    scripts\players\_players::resetSpawning();
    level.intermission = 0;

    // Start bringing in the ZOMBIES!!!
    level notify("start_monitoring");
    thread watchEnd();
    thread watchWaveProgress();
    for (i=0; i<level.waveSize; ) {
        if (!level.playWave) {
            // we want to stop playing this wave, so don't create any more zombies
            break;
        }
        if (level.botsAlive<level.dif_zomMax) {
            // Make every nth zombie a special zombie
            modulo = i % level.nthZombieIsSpecial;
            if (modulo == 0) {
                specialType = scripts\gamemodes\_gamemodes::getRandomSpecialType();
                spawnType = 0;
                if ((specialType == "tank") || (specialType == "burning_tank")) {spawnType = 1;}
                else if (specialType == "toxic") {spawnType = 2;}
                if (isDefined(spawnZombie(specialType, spawnType))) {
                    i++;
                }
            } else if (isdefined(spawnZombie())) {
                i++;
            }
        }
        wait level.dif_zomSpawnRate;
    }

    // this assumes there is less than 20 bugged zombies
    level thread killBuggedZombies();
    level waittill("wave_finished");

    scripts\server\_environment::stopAmbient();

    level.currentWave++;
}

/**
 * @brief Starts a special wave of zombies
 *
 * @param type string The type of special wave
 *
 * @returns nothing
 */
startSpecialWave(type)
{
    debugPrint("in _survival::startSpecialWave()", "fn", level.nonVerbose);

    level endon( "game_ended" );

    level.intermission = 1;
    waveType = type;

    level.zom_spawntype = 0;
    if ((type == "tank") || (type == "burning_tank")) {
        level.zom_spawntype = 1; // souls spawn
    }
    if (type == "toxic") {
        level.zom_spawntype = 2; // ground spawn
    }

    timer(level.dvar["surv_timeout"], &"ZOMBIE_NEWWAVEIN" , (.7,.2,0));
    wait level.dvar["surv_timeout"] + 2;

    if (type == "boss") {level.waveSize = 1;}
    else if (type == "cyclops") {
        level.waveSize = int(0.85 * level.activePlayers);
        if (level.waveSize == 0) {level.waveSize = 1;}
    }
    else {
        level.waveSize = getWaveSize(level.currentWave);
        level.waveSize = int(level.waveSize * level.specialWaveSizeFactor) + 1;
    }

    level.waveProgress = 0;

    if (waveType == "inferno") { // burning or burning dog
        announceMessage(&"ZOMBIE_NEWSPECIALWAVE", "burning zombies", (.7,.2,0), 4, 95);
    } else if (waveType == "random") { // random special zombies
        announceMessage(&"ZOMBIE_NEWSPECIALWAVE", "mixed zombies", (.7,.2,0), 4, 95);
    } else {
        announceMessage(&"ZOMBIE_NEWSPECIALWAVE", level.zom_typenames[type], (.7,.2,0), 4, 95);
    }

    wait 5;

    // Set the environment for the special wave
    scripts\server\_environment::setAmbient(scripts\bots\_types::getAmbientForType(type));
    scripts\server\_environment::setGlobalFX(scripts\bots\_types::getFxForType(type));
    thread scripts\server\_environment::setBlur(scripts\bots\_types::getBlurForType(type), 20);
    vision = scripts\bots\_types::getVisionForType(type);
    if (vision != "") {
        scripts\server\_environment::setVision(vision, 20);
    }
    fog = scripts\bots\_types::getFogForType(type);
    if (fog != "") {
        scripts\server\_environment::setFog(fog, 20);
    }

    scripts\players\_players::resetSpawning();
    level.intermission = 0;

    // Start bringing in the ZOMBIES!!!
    level notify("start_monitoring");
    thread watchWaveProgress();
    thread watchEnd();
    for (i=0; i<level.waveSize; ) {
        if (!level.playWave) {
            // we want to stop playing this wave, so don't create any more zombies
            if (type == "boss") {level.bossOverlay fadeout(1);}
            break;
        }
        if (level.botsAlive<level.dif_zomMax) {
            if (waveType == "inferno") {
                // type is a random burning, burning_dog, or burning_tank
                spawnType = level.zom_spawntype;
                random = randomFloat(1);
                if (random < 0.33) {type = "burning";}
                else if (random > 0.66) {
                    type = "burning_tank";
                    spawnType = 1;  // soul spawn
                } else {type = "burning_dog";}
                if (isdefined(spawnZombie(type, spawnType))) {
                    i++;
                }
            } else if (waveType == "random") {
                // random special zombies
                type = scripts\gamemodes\_gamemodes::getRandomSpecialType();
                spawnType = 0;
                if ((type == "tank") || (type == "burning_tank")) {spawnType = 1;}
                else if (type == "toxic") {spawnType = 2;}
                if (isdefined(spawnZombie(type, spawnType))) {
                    i++;
                }
            } else {
                if (isdefined(spawnZombie(type, level.zom_spawntype))) {
                    i++;
                }
            }
        }
        wait level.dif_zomSpawnRate;
    }
    if (type!="boss") {level thread killBuggedZombies();}

    level waittill("wave_finished");

    // Restore environment settings for the next wave
    level.slowBots += 1/(level.dvar["surv_slow_waves"]);
    scripts\server\_environment::stopAmbient();
    if (vision != "") {
        scripts\server\_environment::resetVision(10);
    }
    thread scripts\server\_environment::setBlur(level.dvar["env_blur"], 7);
    if (fog != "") {
        scripts\server\_environment::setFog("default", 10);
    }

    level notify("global_fx_end");

    level.currentWave++;
}

/**
 * @brief Uses the meatgrinder to kill stuck zombies
 *
 * @returns nothing
 */
killBuggedZombies()
{
    debugPrint("in _survival::killBuggedZombies()", "fn", level.nonVerbose);

    level endon("wave_finished");

    if (!level.dvar["surv_find_stuck"]) {return;}

    tolerance = 0;
    while(1) {
        if (level.waveProgress >= level.waveSize) {
            wait 1;
            level notify("force_wave_finished");
            wait 1;
            level notify("wave_finished");
        }

        lastProg = level.waveProgress;
        level.hasReceivedDamage = 0;
        wait 10;
        if (level.activePlayers==level.alivePlayers) {
            if (lastProg == level.waveProgress && !level.hasReceivedDamage) {
                tolerance += 5;
            } else {tolerance = 0;}
        } else {tolerance = 0;}

        if (tolerance >= level.dvar["surv_stuck_tollerance"])
        {
            iprintlnbold("^1Stuck zombies detected, bringing out meatgrinder!");
            wait 1;
            for (i=0; i<level.bots.size; i++) {
                level.bots[i] suicide();
                wait 0.05;
            }
        }
    }
}

/**
 * @brief Keeps track of the number of zombies killed this wave, and when the wave ends
 *
 * @returns nothing
 */
watchWaveProgress()
{
    debugPrint("in _survival::watchWaveProgress()", "fn", level.nonVerbose);

    level endon( "game_ended" );
    level endon("force_wave_finished");

    level thread doWaveHud();
    while (1) {
        level waittill("bot_killed");
        level.waveProgress++;
        if (level.waveProgress >= level.waveSize)
        break;
    }
    level notify("wave_finished");
}

/**
 * @brief Updates the wave progress HUD
 *
 * @returns nothing
 */
doWaveHud()
{
    debugPrint("in _survival::doWaveHud()", "fn", level.nonVerbose);

    level endon( "game_ended" );

    while(1) {
        updateWaveHud(level.waveProgress,level.waveSize);
        wait 1;
    }
}

/**
 * @brief Spawns a zombie with a specified spawn type
 *
 * @param override string The specific type of zombie to spawn
 * @param spawntype integer The type of spawning to do. 1 is ground spawn, 2 is soul spawn
 *
 * @returns The spawned bot
 */
spawnZombie(override, spawntype)
{
    debugPrint("in _survival::spawnZombie()", "fn", level.fullVerbosity);

    if (!isdefined(spawntype)) {spawntype = 0;}

    if (spawntype==1) {
        bot = scripts\bots\_bots::getAvailableBot();
        if (!isdefined(bot)) {return undefined;}

        bot.hasSpawned = true;

        type = override;
        // Some legacy maps (e.g. mp_surv_overrun) seem to not use waypoints, so level.wp.size is zero.
        // In these cases, we just get a random spawn point
        if (level.wp.size == 0) {
            spawn = getRandomSpawn();
        } else {
            spawn = level.wp[randomint(level.wp.size)];
        }
        thread soulSpawn(type, spawn, bot);
        return bot;
    } else if (spawntype==2) {
        bot = scripts\bots\_bots::getAvailableBot();
        if (!isdefined(bot)) {return undefined;}

        bot.hasSpawned = true;

        type = override;
        // Some legacy maps (e.g. mp_surv_overrun) seem to not use waypoints, so level.wp.size is zero.
        // In these cases, we just get a random spawn point
        if (level.wp.size == 0) {
            spawn = getRandomSpawn();
        } else {
            spawn = level.wp[randomint(level.wp.size)];
        }
        thread groundSpawn(type, spawn, bot);
        return bot;
    } else {
        if (isdefined(override)) {
            type = override;
            spawn = getRandomSpawn();
            return scripts\bots\_bots::spawnZombie(type, spawn);
        } else {
            type = scripts\gamemodes\_gamemodes::getRandomType();
            spawn = getRandomSpawn();
            return scripts\bots\_bots::spawnZombie(type, spawn);
        }
    }
}

/**
 * @brief Spawns a zombie coming up through the ground
 *
 * @param type string The type of zombie to spawn
 * @param spawn The spawn object
 * @param bot The bot to spawn
 *
 * @returns nothing
 */
groundSpawn(type, spawn, bot)
{
    debugPrint("in _survival::groundSpawn()", "fn", level.veryLowVerbosity);

    playfx(level.goundSpawnFX, PhysicsTrace(spawn.origin, spawn.origin-200));
    wait .2;

    scripts\bots\_bots::spawnZombie(type, spawn, bot);
}

/**
 * @brief Spawns a zombie falling from the sky
 *
 * @param type string The type of zombie to spawn
 * @param spawn The spawn object
 * @param bot The bot to spawn
 *
 * @returns nothing
 */
soulSpawn(type, spawn, bot)
{
    debugPrint("in _survival::soulSpawn()", "fn", level.veryLowVerbosity);

    org = spawn("script_model", spawn.origin + (0,0,2000));
    org setmodel("tag_origin");
    wait .1;
    playFXOnTag(level.soulFX , org, "tag_origin");
    wait .1;
    org moveto(spawn.origin+(0,0,48), 20);
    wait 20;
    playfx(level.soulspawnFX, org.origin);
    org delete();

    scripts\bots\_bots::spawnZombie(type, spawn, bot);
}


