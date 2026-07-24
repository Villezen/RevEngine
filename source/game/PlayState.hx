package game;

import flixel.FlxCamera;
import flixel.FlxSubState;

import flixel.math.FlxMath;

import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.util.FlxStringUtil;

import flixel.text.FlxBitmapText;

import sys.FileSystem;

import lime.app.Application;

import backend.modding.PolymodManager;

import backend.modding.modules.Module;
import backend.modding.songs.SongModule;
import backend.modding.songs.SongEventModule;

import backend.modding.handlers.ModuleHandler;
import backend.modding.handlers.SongModuleHandler;
import backend.modding.handlers.SongEventModuleHandler;
import backend.modding.handlers.CharacterHandler;
import backend.modding.handlers.StageHandler;

import backend.registries.song.EventRegistry;
import backend.registries.song.EventObjectRegistry;

import backend.registries.world.StageRegistry;
import backend.registries.world.CharacterRegistry;

import backend.registries.ui.CountdownRegistry;
import backend.registries.ui.RatingsRegistry;
import backend.registries.ui.HealthIconRegistry;
import backend.registries.ui.NoteSkinRegistry;
import backend.registries.ui.DialogueRegistry;

import backend.modding.events.ScriptEvent;
import backend.modding.events.ScriptEventDispatcher;

import backend.transition.TransitionLoader;
import backend.transition.TransitionState;

import backend.Highscore;
import backend.Highscore.ScoreTallies;

import backend.utils.MathUtil;

import game.handlers.Chart;
import game.handlers.Meta;
import game.handlers.Song;
import game.handlers.Inputs;

import game.handlers.events.EventsHandler;
import game.handlers.events.Event;

import game.notes.Note;
import game.notes.SustainNote;
import game.notes.Strum;
import game.notes.Strumline;

import game.ui.Ratings;
import game.ui.HealthBar;
import game.ui.Countdown;

import game.world.Stage;
import game.world.Pointer;

import game.world.Character;
import game.world.Character.PlacementType;

import game.PlayMetrics.NoteJudgement;

import backend.MusicBeatState;

typedef PlayStateParams =
{
    /**
     * The name of the song to load.
     */
    var song:String;

    /**
     * The difficulty of the chart to load, defaults to `Constants.DEFAULT_DIFFICULTY`.
     */
    @:optional var difficulty:String;

    /**
     * The variation file suffix (e.g. "-pico") for the chosen character's mix, "" for default.
     */
    @:optional var variation:String;
}

/**
 * The primary state where everything happens.
 */
class PlayState extends MusicBeatState
{
    /**
     * Singleton instance of this current state. 
     */
    public static var instance:PlayState;

    /**
     * Updates to the current param every time it's set. Will be used as fallback if the set param is invalid.
     */
    public static var previousParams:PlayStateParams;

    /**
     * The parameters of the loaded song, utilized in the constructor.
     */
    public static var params:PlayStateParams;

    /**
     * Current song to fetch all data from.
     */
    public var name:String;

    /**
     * The difficulty of the chart being played.
     */
    public var difficulty:String;

    /**
     * The variation file suffix (e.g. "-pico") of the chart being played, "" for the default.
     */
    public var variation:String;

    /**
     * Wheater the song contains any dialogue.
     */
    public var hasDialogue:Bool = false;

    /**
     * Checks if the song is being played through the story mode.
     */
    public static var isStoryMode:Bool = false;

    /**
     * Whether the player is coming from the Freeplay menu to ensure the fade out transition occurs.
     */
    public static var comingFromFreeplay:Bool = false;

    /**
	 * Which week the player is playing.
	 */
	public static var currentStoryWeek:Int = -1;

    /**
	 * An array containing every song in the story mode week.
	 */
	public static var storySongs:Array<String> = [];

    /**
     * Active scripted modules.
     */
    public var modules:Array<Module> = [];
    
    /**
     * Camera for background and game world objects.
     */
    public var camGame:FlxCamera;

    /**
     * Camera for UI elements.
     */
    public var camHUD:FlxCamera;

    /**
     * Camera for event sprites.
     */
    public var camBetween:FlxCamera;

    /**
     * Camera for note strumlines.
     */
    public var camStrums:FlxCamera;

    /**
     * Cmaera for miscellaneous overlay elements.
     */
    public var camMisc:FlxCamera;

    /**
     * Camera for screen-space overlays.
     */
    public var camOverlay:FlxCamera;

    /**
     * Whether the cameras can bop every time the modulo beat/step has been hit.
     */
    public var camerasCanBop:Bool = true;

    /**
     * Modulo for the camera's to bop on beat/step.
     */
    public var cameraBopModulo:Int = 4;

    /**
     * Step/Beat offset of the camera bop rate.
     */
    public var cameraBopOffset:Int = 0;

    /**
     * Whether the camera modulo has been set to a beat hit, which means cameras should only bop every 4*n steps.
     */
    public var cameraBopModuloOnBeat:Bool = true;

    /**
     * Stage's camera zoom value (previously known as defaultCamZoom).
     */
    public var stageCameraZoom:Float = 1.0;

    /**
     * Current camera zoom value.
     */
    public var currentCameraZoom:Float = 1.0;

    /**
     * Camera zoom multiplier for camera bopping which gets modified by this state.
     */
    public var cameraBopMultiplier:Float = 1.0;

    /**
     * Camera bop intensity multiplier (utilize this one for events).
     */
    public var cameraBopIntensity:Array<Float> = [1.0, 1.0];

    /**
     * Value utilized for the zoom amount of the hud cameras.
     */
    public var currentHudZoom:Float = 1.0;

    /**
     * Whether the default cameras zoom can lerp back to their original zoom.
     */
    public var camerasCanLerp:Bool = true;

    /**
     * The higher the number the faster the camera lerps back to its original zoom.
     */
    public var camerasZoomLerpSpeed:Float = 1.0;

    /**
     * Data containing the song's note mappings.
     */
    public var chart:Chart;

    /**
     * Class handling the song's events.
     */
    public var eventsHandler:EventsHandler;

    /**
     * Metadata for the song.
     */
    public var meta:Meta;

    /**
     * Wrapper for handling audio playback.
     */
    public var song:Song;

    /**
     * The primary player strumline.
     */
    public var playerStrums:Strumline;

    /**
     * The strumline controlled by the opponent (id 0).
     */
    public var enemyStrums:Strumline;

    /**
     * Every strumline the player controls, in chart order. Notes on these are
     * driven by input; the rest are cpu.
     */
    public var playableStrums:Array<Strumline> = [];

    /**
     * A map containing each loaded strumline in the chart.
     */
    public var strumlines:Map<Int, Strumline> = [];

    /**
     * Tracker for performance telemetry.
     */
    public var metrics:PlayMetrics;

    /**
     * Handler for raw inputs.
     */
    public var inputs:Inputs;

    /**
     * The player's health bar. 
     */
    public var healthBar:HealthBar;

    /**
     * The score text.
     */
    public var scoreText:FlxBitmapText;

    /**
     * The ratings pop-up group.
     */
    public var ratings:Ratings;

    /**
     * The sprite group that'll be displayed during the countdown.
     */
    public var countdown:Countdown;

    /**
     * A sprite group, containing the world's stage.
     */
    public var stage:Stage;

    /**
     * Characters the 'Change Character' event will eventually swap to.
     */
    public var understudies:Map<String, Character> = [];

    /**
     * Pointer, controlling the world's camera.
     */
    public var pointer:Pointer;

    /**
     * The song's opponent.
     */
    public var dad:Character;

    /**
     * The song's player.
     */
    public var boyfriend:Character;

    /**
     * The song's girlfriend skin.
     */
    public var gf:Character;

    /**
     * A map containing each loaded character in the chart.
     */
    public var characters:Map<Int, Character> = [];

    /**
     * A group containing each variation of the miss sound effect.
     */
    public var missSounds:Array<FunkinSound> = [];

    /**
     * Wheater the HUD should generate.
     */
    public var generateHUD:Bool = true;

    /**
     * Wheater ratings should generate.
     */
    public var generateRatings:Bool = true;

    /**
     * Wheater the Conductor should update.
     */
    public var updateConductor:Bool = false;

    /**
     * Should the countdown be skipped?
     */
    public var skippedCountdown:Bool = false;

    /**
     * Wheater or not the song has started.
     */
    public var songStarted:Bool = false;

    /**
     * Maps each strumline id to its owning character.
     */
    private var _strumlineCharacters:Map<Int, String> = [];

    /**
     * Queue for key presses to be processed in the next update tick.
     */
    private var _pressEntryList:Array<InputEntry> = [];

    /**
     * Queue for key releases to be processed in the next update tick.
     */
    private var _releaseEntryList:Array<InputEntry> = [];

    /**
     * Lerp the health values to smoothen its movement.
     */
    private var _healthLerp:Float = 0;

    /**
     * Cached HUD camera list, so the per-frame zoom lerp doesn't allocate an array every update.
     */
    private var _hudZoomCameras:Array<FlxCamera> = [];

    /**
     * Last score value written to the score text, so the display string is only rebuilt when it changes.
     */
    private var _lastDisplayedScore:Int = -1;

    /**
     * Set when the window regains focus.
     */
    private var _reanchorConductor:Bool = false;

    /**
     * The Conductor position the strumline is last rendered with.
     */
    private var _lastConductorPos:Float = 0;

    /**
     * Internal variable to check if the player is currently able to skip through the song.
     */
    private var _canSkip:Bool = false;

    /**
     * Internal variable to check if the player is currently skipping through the song in any way.
     */
    private var _timeSkipping:Bool = false;

    /**
     * Transition-finish listener, kept so destroy() can invalidate it if this state dies before the transition completes.
     */
    private var _onTransitionFinish:Void->Void;

    public function new(?params:PlayStateParams)
    {
        super();

        if (params == null) params = previousParams;
        if (params.song == null) params.song = 'swirl';
        if (params.difficulty == null) params.difficulty = Constants.DEFAULT_DIFFICULTY;
        if (params.variation == null) params.variation = "";

        PlayState.params = params;
        PlayState.previousParams = params;

        name = params.song;
        difficulty = params.difficulty;
        variation = params.variation;
    }
    
    /**
     * Initializes most of the gameplay elements.
     */
    public override function create():Void
    {
        super.create();

        instance = this;

        if (FlxG.sound.music != null)
        {
            FlxG.sound.music.stop();
            FlxG.sound.music = null;
        }

        this.subStateOpened.add(onSubStateOpen);
        this.subStateClosed.add(onSubStateClose);

        FlxG.signals.focusGained.add(onWindowRefocus);

        ModuleHandler.load();
        ModuleHandler.callCreate();

        CharacterHandler.load();

        setupCameras();
        setupSong();
        setupStrumlines();
        setupInputs();
        setupWorld();
        setupHUD();

        dispatchEvent(new ScriptEvent(POST_CREATE, false));

        initDialogue();

        if (!hasDialogue)
            initCountdown();
    }

    /**
     * Creates and registers every defined camera.
     */
    function setupCameras()
    {
        camGame = new FlxCamera();
        camHUD = new FlxCamera();
        camBetween = new FlxCamera();
        camStrums = new FlxCamera();
        camMisc = new FlxCamera();
        camOverlay = new FlxCamera();
        
        FlxG.cameras.reset(camGame);

        for (camera in [camBetween, camHUD, camStrums, camMisc, camOverlay])
        {
            camera.bgColor.alpha = 0;
            FlxG.cameras.add(camera, false);
        }

        FlxG.cameras.setDefaultDrawTarget(camGame, true);

        _hudZoomCameras = [camHUD, camStrums];

        resizeCameras(Application.current.window.width, Application.current.window.height);
        camStrums.flipY = Configs.DOWNSCROLL;

        if (comingFromFreeplay)
        {
            var solid = new FunkinSprite().makeGraphic(camOverlay.width, camOverlay.height, FlxColor.BLACK);
            solid.camera = camOverlay;
            add(solid);

            FlxTween.tween(solid, {alpha: 0}, 0.3, {ease: FlxEase.sineOut, onComplete: (_) -> solid.destroy()});

            comingFromFreeplay = false;
        }
    }

    /**
     * Loads the internal song assets.
     */
    function setupSong()
    {
        meta = new Meta(name, variation);

        song = new Song(name, variation);
        add(song);

        chart = new Chart(name, difficulty, variation);

        eventsHandler = new EventsHandler(name);
        add(eventsHandler);

        eventsHandler.onExecution.add(eventExecution);

        conductor.setBPM(meta.bpm);
        conductor.update(-(conductor.beatLengthMs * 5));

        SongModuleHandler.forEachModule((module:SongModule) ->
        {
            module.initalize();
        });

        SongModuleHandler.callCreate(name);

        SongEventModuleHandler.forEachModule((module:SongEventModule) ->
        {
            module.initalize();
        });

        SongEventModuleHandler.callCreate();
    }

    /**
     * Initializes the player and enemy strumlines and connects hit/miss signals.
     */
    function setupStrumlines()
    {
        playableStrums = [];

        for (entry in chart.strumlines)
        {
            var isPlayable:Bool = entry.playable == true;

            var strumline:Strumline = new Strumline(entry.position[0], entry.position[1], {data: entry, cpu: !isPlayable, skin: entry.skin, scale: entry.scale});
            strumline.visible = entry.visible;
            strumline.camera = camStrums;
            add(strumline);

            strumline.onNoteHit.add(noteHit);
            strumline.onSustainHit.add(sustainHit);
            strumline.onNoteMiss.add(noteMiss);

            strumlines.set(entry.id, strumline);

            if (!_strumlineCharacters.exists(entry.id))
                _strumlineCharacters.set(entry.id, entry.character);

            if (isPlayable)
                playableStrums.push(strumline);
        }

        enemyStrums = strumlines.get(0);
        playerStrums = strumlines.get(1);

        metrics = new PlayMetrics(name);

        var noteTotal:Int = 0;
        for (entry in chart.strumlines)
        {
            if (entry.playable == true && entry.notes != null)
                noteTotal += entry.notes.length;
        }

        metrics.totalNotes = noteTotal;

        for (i in 0...3)
        {
            missSounds[i] = FunkinSound.load(Paths.sound('gameplay/miss/$i'), 0.4, false, false, false, false, null, null, true);
        }
    }

    /**
     * Initializes and configures the input system based on the current key count and connects required signals.
     */
    function setupInputs()
    {
        inputs = new Inputs();

        var setupKeys:Int = (playerStrums != null) ? playerStrums.keyCount : 4;
        for (strumline in playableStrums)
            if (strumline.keyCount > setupKeys) setupKeys = strumline.keyCount;

        inputs.setup(setupKeys);

        inputs.onInputPressed.add(function(entry:InputEntry)
        {
            if (!hasPlayableInput()) return;
            _pressEntryList.push(entry);
        });

        inputs.onInputReleased.add(function(entry:InputEntry)
        {
            if (!hasPlayableInput()) return;
            _releaseEntryList.push(entry);
        });
    }

    /**
     * Sets up world elements (stage, pointer, characters)
     */
    function setupWorld()
    {
        stage = StageHandler.spawn(meta.stage);
        stage.build();
        add(stage);

        stageCameraZoom = currentCameraZoom = camGame.zoom = stage.data.camera.zoom;

        var owners:Map<String, Int> = [];

        for (entry in chart.strumlines)
        {
            var id:Int = entry.id;
            var owner:Int = owners.exists(entry.character) ? owners.get(entry.character) : id;

            if (id <= owner)
                owners.set(entry.character, id);
        }

        for (entry in chart.strumlines)
        {
            var id:Int = entry.id;
            var owner:Int = owners.get(entry.character);

            if (owner != id)
            {
                trace('Strumline $id wants "${entry.character}", which strumline $owner already has. Leaving strumline $id without a character.', "WARNING");
                continue;
            }

            var character:Character = CharacterHandler.spawn(0, 0, {name: entry.character, parent: strumlines.get(id)});

            if (character == null)
                continue;

            placeCharacter(character);

            characters.set(id, character);
            song.initVocalTrack(entry.character);
        }

        if (characters[2] != null)
            gf = characters[2];

        if (characters[0] != null)
            dad = characters[0];

        if (characters[1] != null)
            boyfriend = characters[1];

        if (gf != null) 
            add(gf);
            
        if (dad != null) 
            add(dad);   
            
        if (boyfriend != null) 
            add(boyfriend);

        for (id => char in characters)
        {
            if (![0, 1, 2].contains(id))
                add(char);
        }

        buildUnderstudies();

        stage.dispatchEvent(new ScriptEvent(POST_CREATE));

        pointer = new Pointer(stage.data.camera.baseline[0], stage.data.camera.baseline[1]);
        add(pointer);

        pointer.onCameraMove.add(cameraMove);

        camGame.follow(pointer);
        camGame.focusOn(pointer.getPosition());

        pointer.curTarget = dad ?? pointer.curTarget;
        pointer.speed = stage.data.camera.speed;
    }

    /**
     * Initializes the HUD.
     */
    function setupHUD()
    {
        if (generateHUD)
        {
            healthBar = new HealthBar(0, 0, {parent: this, parentVar: '_healthLerp', characters: [PlayState.instance.dad, PlayState.instance.boyfriend]});
            healthBar.screenCenter(X);
            healthBar.y = camera.height * 0.1;
            healthBar.camera = camHUD;
            add(healthBar);

            scoreText = new FlxBitmapText(0, 0, 'Score: 0', Paths.getAngelFont("vcr/low"));
            scoreText.x = healthBar.x + healthBar.width - 190;
            scoreText.y = healthBar.y + 30;
            scoreText.alignment = RIGHT;
            scoreText.borderStyle = OUTLINE;
            scoreText.borderColor = FlxColor.BLACK;
            scoreText.letterSpacing = -1;
            scoreText.camera = camHUD;
            scoreText.antialiasing = true;
            add(scoreText);

            syncHUD();
        }

        ratings = new Ratings(meta.ratings.skin);
        ratings.camera = Reflect.field(this, ratings.data.camera);
        add(ratings);

        _healthLerp = metrics.health ?? 1.0;

        countdown = new Countdown({skin: meta.countdown.skin, audio: meta.countdown.audio});
        countdown.camera = camMisc;
        add(countdown);

        if (countdown != null)
            countdown.sync();
    }

    /**
     * Initializes the dialogue. (If any is found)
     */
    function initDialogue()
    {
        if (!isStoryMode)
            return;

        if (Paths.exists('data/dialogue/songs/$name.json'))
            hasDialogue = true;
        else
            return;

        hasDialogue = true;

        runAfterTransition(() -> FlxTimer.wait(conductor.beatLengthMs / 1000, () -> Manager.openSubState(new menus.DialogueSubState())));
    }

    /**
     * Runs an action once the current transition finishes (or immediately when
     * no transition is active), keeping the listener removable on destroy.
     */
    function runAfterTransition(action:Void->Void):Void
    {
        if (!TransitionState.switchingState)
        {
            action();
            return;
        }

        _onTransitionFinish = function()
        {
            _onTransitionFinish = null;
            action();
        };

        TransitionLoader.onTransitionFinish.addOnce(_onTransitionFinish);
    }

    /**
     * Initializes the countdown.
     */
    function initCountdown()
    {
        if (countdown == null) return;

        runAfterTransition(() -> FlxTimer.wait(countdown.countdownDelay, () -> startCountdown()));
    }

    /**
     * Starts the countdown.
     */
    function startCountdown()
    {
        updateConductor = true;

        if (!skippedCountdown)
        {
            countdown?.onFinish.add(startSong);
            countdown?.start();
        }
        else
        {
            startSong();
        }
    }

    /**
     * Called when the song has started.
     */
    function startSong()
    {
        songStarted = true;
        _canSkip = true;

        if (song != null)
			song.inst.onComplete = endSong;

        conductor.update(0);
        updateConductor = true;

        song.play();
    }

    /**
     * Called when the song has ended.
     */
    function endSong()
    {
        songStarted = false;
        updateConductor = false;
        _canSkip = false;

        if (song != null)
            song.stop();

        saveHighscore();

        FunkinSound.stopAllAudio(true);
        Manager.switchState(new menus.MainMenuState(), "stickers");
    }

    /**
     * Records the score and tallies for the song that just finished and saves it.
     */
    function saveHighscore()
    {
        if (metrics == null)
        {
            return;
        }

        var tallies:ScoreTallies =
        {
            sick: metrics.sick,
            good: metrics.good,
            bad: metrics.bad,
            shit: metrics.shit,
            missed: metrics.misses,
            combo: metrics.combo,
            maxCombo: metrics.maxCombo,
            totalNotesHit: metrics.sick + metrics.good + metrics.bad + metrics.shit,
            totalNotes: metrics.totalNotes
        };

        Highscore.saveScore(name, difficulty, variation, {score: metrics.score, tallies: tallies});
    }

    /**
     * Updates the game state, alongside other variables.
     */
    public override function update(elapsed:Float):Void
    {
        super.update(elapsed);

        _lastConductorPos = conductor.songPosition;

        // Handle instrumental resync
        if (updateConductor)
        {
            var newPosition:Float = conductor.songPosition + elapsed * 1000;

            if (song != null && song.inst != null && song.inst.playing)
            {
                var drift:Float = song.inst.time - newPosition;
                
                if (_reanchorConductor || Math.abs(drift) > Constants.CONDUCTOR_HARD_RESYNC)
                    newPosition = song.inst.time;
                else
                    newPosition += drift * Math.min(1.0, elapsed * Constants.CONDUCTOR_DRIFT_RATE);
            }

            _reanchorConductor = false;

            conductor.update(newPosition);
        }

        // Process the player's inputs.
        processInputs(elapsed);

        // Lerps the cameras zoom back to their original values.
        lerpCamerasZoom(elapsed);

        // Smoothen the health bar.
        _healthLerp = FlxMath.lerp(_healthLerp, metrics.health, 0.15);

        updateScoreText();

        manageDebugKeybinds(true);
    }

    /**
     * Updates the default score text. 
     */
    dynamic function updateScoreText():Void
    {
        if (scoreText == null || metrics == null || metrics.score == _lastDisplayedScore) 
        {
            return;
        }

        _lastDisplayedScore = metrics.score;
        scoreText.text = "Score: " + Std.string(FlxStringUtil.formatMoney(metrics.score, false, true));
    }

    /**
     * Lerps the zoom of the cameras back to their original values.
     */
    dynamic function lerpCamerasZoom(elapsed:Float):Void
    {
        if (!camerasCanLerp)
        {
            return;
        }

        var decay:Float = 0.85;
        var speed:Float = (elapsed * 60) * camerasZoomLerpSpeed;
        var lerpFactor:Float = Math.pow(decay, speed);

        cameraBopMultiplier = FlxMath.lerp(1.0, cameraBopMultiplier, lerpFactor);
        FlxG.camera.zoom = (currentCameraZoom * cameraBopMultiplier);

        for (hudCameras in _hudZoomCameras)
            hudCameras.zoom = FlxMath.lerp(currentHudZoom, hudCameras.zoom, lerpFactor);
    }

    /**
     * Handles certain debugging functions.
     * @param devMode Allows for more sensitive debug keybinds like timeskip, downscroll switch and quick exit.
     */
    function manageDebugKeybinds(devMode:Bool):Void
    {
        // Access the chart editor.
        if (FlxG.keys.justPressed.SEVEN)
        {
            Manager.switchState(new menus.ChartingState(name, difficulty, variation));
        }

        // Only add the more sensitive keybinds after this.
        if (!devMode) return;

        // Quickly go back to the main menu.
        if (FlxG.keys.justPressed.ESCAPE && songStarted)
        {
            updateConductor = false;
            
            song?.stop();

            FunkinSound.stopAllAudio(true);
            Manager.switchState(new menus.MainMenuState(), "stickers");
        }

        // Quickly switches the scroll direction of the notes.
        if (FlxG.keys.justPressed.TAB)
        {
            Configs.DOWNSCROLL = !Configs.DOWNSCROLL;
            camStrums.flipY = Configs.DOWNSCROLL;

            syncHUD();

            for (strumline in [playerStrums, enemyStrums])
            {
                if (strumline != null)
                    strumline.downScroll = camStrums.flipY;
            }
        }

        // Makes the game fast forward.
        if (_canSkip)
        {
            update_timeSkipping(FlxG.keys.pressed.TWO || FlxG.keys.pressed.ONE, (FlxG.keys.pressed.TWO ? 3.0 : 0.5));
        }
        else if (!_canSkip && FlxG.timeScale != 1.0)
        {
            setTimeScale(1.0);
        }
    }

    /**
     * Whether any strumline is currently accepting player input.
     */
    function hasPlayableInput():Bool
    {
        for (strumline in playableStrums)
            if (strumline != null && !strumline.cpu) return true;

        return false;
    }

    /**
     * Procces inputs to determine if a note should be hit or not.
     */
    function processInputs(elapsed:Float):Void
    {
        for (strumline in playableStrums)
        {
            if (strumline == null) continue;

            for (sustain in strumline.sustains.members)
            {
                if (sustain == null || !sustain.exists || !sustain.alive) continue;

                if (conductor.songPosition >= sustain.time && sustain.hit && !sustain.missed && sustain.mustHit)
                    metrics.hold(elapsed);
            }
        }

        if (_pressEntryList.length + _releaseEntryList.length <= 0 || !hasPlayableInput()) return;

        for (pressEntry in _pressEntryList)
        {
            for (strumline in playableStrums)
                pressInputOnStrumline(strumline, pressEntry.direction);
        }
        _pressEntryList.resize(0);

        for (releaseEntry in _releaseEntryList)
        {
            for (strumline in playableStrums)
            {
                if (strumline == null || strumline.cpu || releaseEntry.direction >= strumline.keyCount) continue;

                strumline.releaseKey(releaseEntry.direction);

                var spr:Strum = strumline.strums.members[releaseEntry.direction];
                spr?.play("static", true);
            }
        }
        _releaseEntryList.resize(0);
    }

    /**
     * Presses one note direction on one strumline and calculates if an incoming note should be hit.
     */
    function pressInputOnStrumline(strumline:Strumline, noteDir:Int):Void
    {
        if (strumline == null || strumline.cpu || noteDir >= strumline.keyCount) return;

        strumline.pressKey(noteDir);

        var spr:Strum = strumline.strums.members[noteDir];
        spr?.play("pressed", true);

        var sortedNotesList:Array<Note> = strumline.filterHittableNotes(noteDir);
        sortedNotesList.sort(strumline.sortHitNotes);

        if (sortedNotesList.length <= 0) return;

        var targetNote = sortedNotesList[0];
        if (targetNote == null || !targetNote.alive) return;

        if (targetNote.sustain != null)
        {
            var sustain:SustainNote = targetNote.sustain;

            sustain.hit = true;
            sustain.missed = false;
            sustain.missHandled = false;

            var catchPadding:Float = 0;
            if (sustain.strum != null && strumline.speed > 0)
                catchPadding = (sustain.strum.height / 4) / (0.45 * strumline.speed);

            sustain.fullLength = (sustain.time + sustain.fullLength) - _lastConductorPos + catchPadding;
            sustain.time = _lastConductorPos;
            sustain.length = sustain.fullLength;

            if (sustain.strum != null)
            {
                sustain.y = sustain.strum.y + sustain.strum.height / 2;
                sustain.sync();
            }
        }

        strumline.onNoteHit.dispatch(targetNote);
        targetNote.kill();
    }

    /**
     * Destroys and nullifies most of the variables.
     */
    public override function destroy():Void
    {
        FlxG.signals.focusGained.remove(onWindowRefocus);

        if (_onTransitionFinish != null)
        {
            TransitionLoader.onTransitionFinish.remove(_onTransitionFinish);
            _onTransitionFinish = null;
        }

        for (snd in missSounds)
        {
            if (snd == null) continue;
            
            FlxG.sound.list.remove(snd, true);
            snd.destroy();  
        }

        missSounds = [];
        playableStrums = [];

        for (cam in [camGame, camBetween, camHUD, camStrums, camMisc, camOverlay])
        {
            if (cam == null || !FlxG.cameras.list.contains(cam)) continue;
            FlxG.cameras.remove(cam, true);
        }

        inputs?.destroy();
        inputs = null;

        strumlines?.clear();
        characters?.clear();
        song?.stop();

        var objects:Array<Dynamic> = [song, chart, meta, metrics, eventsHandler, playerStrums, enemyStrums, stage, pointer];
        for (obj in objects)
        {
            obj = null;
        }

        CharacterHandler.clear();

        instance = null;

        super.destroy();
    }

    /**
     * Puts a character in the correct position.
     */
    public function placeCharacter(character:Character):Void
    {
        if (character == null || stage == null)
            return;

        switch(character.placementType)
        {
            case PLAYER:
            {
                character.setPosition(770 + character.posOffset.x + stage.data.characters.boyfriend[0], 450 + character.posOffset.y + stage.data.characters.boyfriend[1]);
                character.camOffset.x += stage.data.camera.boyfriend[0];
                character.camOffset.y += stage.data.camera.boyfriend[1];
            }

            case GF:
            {
                character.setPosition(400 + character.posOffset.x + stage.data.characters.girlfriend[0], 130 + character.posOffset.y + stage.data.characters.girlfriend[1]);
                character.camOffset.x += stage.data.camera.girlfriend[0];
                character.camOffset.y += stage.data.camera.girlfriend[1];
            }

            case OPPONENT:
            {
                character.setPosition(100 + character.posOffset.x + stage.data.characters.dad[0], 100 + character.posOffset.y + stage.data.characters.dad[1]);
                character.camOffset.x += stage.data.camera.dad[0];
                character.camOffset.y += stage.data.camera.dad[1];
            }

            case OTHER:
                character.setPosition(character.posOffset.x, character.posOffset.y);

            default:
                character.setPosition(character.posOffset.x, character.posOffset.y);
        }
    }

    /**
     * Builds every character found in the 'Change Character' event.
     */
    function buildUnderstudies():Void
    {
        var data = EventRegistry.get(name);

        if (data == null || data.events == null)
            return;

        for (event in data.events)
        {
            if (event == null || event.variables == null || event.variables.length < 2)
                continue;

            var object = EventObjectRegistry.findByName(event.name);

            if (object == null || object.name != "Change Character")
                continue;

            var target:String = Std.string(event.variables[1]);

            if (target == null || target == "" || understudies.exists(target))
                continue;

            var taken:Bool = false;

            for (char in characters)
                if (char != null && char.name == target) taken = true;

            if (taken)
                continue;

            var understudy:Character = CharacterHandler.spawn(0, 0, {name: target});

            if (understudy == null)
                continue;

            placeCharacter(understudy);

            understudy.visible = false;
            understudy.active = false;

            understudies.set(target, understudy);
            add(understudy);

            trace('Built "$target" ahead of its event.', "PRELOAD");
        }
    }

    /**
     * Reloads every registry in this state.
     */
    override function hotReload():Void
    {
        super.hotReload();

        EventRegistry.reload(name);

        DialogueRegistry.reloadAll();
        EventObjectRegistry.reloadAll();

        if (ratings != null)
            RatingsRegistry.reload(ratings.skin);

        if (meta != null)
        {
            StageRegistry.reload(meta.stage);
            CountdownRegistry.reload(meta.countdown.skin);
        }

        if (healthBar != null)
        {
            HealthIconRegistry.reload(healthBar.leftIcon.character.name);
            HealthIconRegistry.reload(healthBar.rightIcon.character.name);
        }

        if (chart != null && chart.strumlines != null)
        {
            var charactersToReset:Array<String> = [];

            for (entry in chart.strumlines)
            {
                if (!charactersToReset.contains(entry.character))
                    charactersToReset.push(entry.character);
            }

            for (character in charactersToReset)
                CharacterRegistry.reload(character);
        }
    }

    /**
     * Makes the next Conductor update to re-anchor to the audio instead of advancing through the refocus elapsed spike.
     */
    function onWindowRefocus():Void
    {
        _reanchorConductor = true;
    }

    public function onSubStateOpen(substate:FlxSubState)
    {
        if (Std.isOfType(substate, menus.DialogueSubState))
		{
			persistentDraw = true;
			persistentUpdate = false;
		}
    }

    public function onSubStateClose(substate:FlxSubState)
    {
        if (Std.isOfType(substate, menus.DialogueSubState))
		{
            if (!songStarted)
                initCountdown();
		}
    }

    override function dispatchEvent(event:ScriptEvent):Void
    {
        super.dispatchEvent(event);

        var module:SongModule = SongModuleHandler.get(name);
        SongModuleHandler.call(module, event);

        SongEventModuleHandler.callAll(event);

        for (character in characters)
        {
            if (character == null)
                continue;

            CharacterHandler.call(character.id, event);
        }
    }

    /**
     * Makes the player strumline cpu controlled and disables rating calculation and health gain/loss.
     * @param pressed Whether the fast-forward key is being held.
     */
    private function update_timeSkipping(pressed:Bool, speed:Float)
    {
        if (pressed && FlxG.timeScale != speed)
            setTimeScale(speed);
        else if (!pressed && FlxG.timeScale != 1.0)
            setTimeScale(1.0);

        if (pressed == _timeSkipping)
            return;

        _timeSkipping = pressed;

        for (strumline in playableStrums)
        {
            if (strumline == null) continue;

            strumline.cpu = pressed;

            if (!pressed) continue;

            for (i in 0...strumline.keyCount)
            {
                strumline.releaseKey(i);

                var strum:Strum = strumline.strums.members[i];

                if (strum != null && strum.animation != null && strum.animation.name == "pressed")
                    strum.play("static", true);
            }
        }

        if (pressed)
        {
            _pressEntryList.resize(0);
            _releaseEntryList.resize(0);
        }
    }

    public function setTimeScale(value:Float)
    {
        if (song == null) 
            return;

        FlxG.timeScale = value;

        song.inst.pitch = value;
        for (track in song.voices) track.pitch = value;
    }

    /**
     * Adds onto the cameras zoom value, so it can be lerped back.
     */
    public function cameraBop(gameCameraValue:Float = 0.015, hudCamerasValue:Float = 0.05):Void
    {
        if (!camerasCanLerp)
        {
            return;
        }

        cameraBopMultiplier += gameCameraValue;

        for (hudCameras in _hudZoomCameras)
            hudCameras.zoom += hudCamerasValue;
    }

    /**
     * Gets called when the camera moves onto another character.
     * @param char The target character.
     */
    public function cameraMove(char:Character):Void
    {
        dispatchEvent(new CharacterScriptEvent(CAMERA_MOVE, char));
    }

    /**
     * Function that gets called every time a new step is iterated.
     * @param step The current step index.
     */
    public override function stepHit(step:Float):Void
    {
        super.stepHit(step);

        if (camerasCanBop && ((step + (cameraBopOffset * 16)) % (cameraBopModulo * (cameraBopModuloOnBeat ? 4 : 1)) == 0))
        {
            cameraBop(Constants.CAMGAME_BOP_VALUE * cameraBopIntensity[0], Constants.CAMHUD_BOP_VALUE * cameraBopIntensity[1]);
        }
    }

    /**
     * Function that gets called every time a new step is iterated.
     * @param beat The current beat index.
     */
    public override function beatHit(beat:Float):Void
    {
        super.beatHit(beat);

        if (healthBar != null)
            healthBar.bounce(beat);
    }

    public function eventExecution(event:Event)
    {
        var scriptEvent = new SongEventScriptEvent(event.name, event.time, event.variables);
        dispatchEvent(scriptEvent);

        if (scriptEvent.cancelled)
            return;

        SongEventModuleHandler.execute(scriptEvent);
    }

    /**
     * Changes the volume of the track owned by a given note's strumline.
     */
    function changeNoteVocals(note:Note, volume:Float):Void
    {
        if (song == null || note.strumline == null || !_strumlineCharacters.exists(note.strumline.id))
            return;

        song.changePlayerVolume(volume, _strumlineCharacters.get(note.strumline.id));
    }

    public function noteHit(note:Note)
    {
        var event = new NoteHitScriptEvent(NOTE_HIT, note, 150, true, true, true);
        dispatchEvent(event);

        if (event.cancelled)
            return;

        if (note.mustHit)
        {
            var playerEvent = new NoteHitScriptEvent(PLAYER_HIT, note, 150, true, true, true);
            dispatchEvent(playerEvent);

            if (playerEvent.cancelled)
                return;

            event = playerEvent;
        }
        else
        {
            var opponentEvent = new NoteHitScriptEvent(OPPONENT_HIT, note, 150, true, true, true);
            dispatchEvent(opponentEvent);

            if (opponentEvent.cancelled)
                return;

            event = opponentEvent;
        }

        var strumline = note.strumline;

        if (note.mustHit)
        {
            var rating:NoteJudgement = metrics.calculateRating(note.time - conductor.songPosition);
            
            if (event.showRating)
                metrics.judgeRating(rating);

            metrics.calculateAccuracy();

            ratings.popRating(rating);
            ratings.popCombo(metrics.combo);

            if (event.strumGlow)
            {
                var strum = strumline.strums.members[note.direction];

                if (note.direction < strumline.keyCount && strum != null && !strumline.hasActiveSustain(note.direction))
                {
                    if (strum.timer != null)
                        strum.timer.cancel();

                    strum.play("confirm", true);

                    if (note.sustain == null)
                    {
                        strum.timer = new FlxTimer().start(conductor.beatLengthMs / 1000, (_) ->
                        {
                            if (strum.animation.curAnim.name == "confirm")
                                strum.play("pressed", true);

                            strum.timer = null;
                        });
                    }
                }
            }

            if (rating == NoteJudgement.SICK && strumline.hasSplashes && strumline.splashes.members[note.direction] != null && event.showSplashes)
                strumline.splashes.members[note.direction].splash();
        }
        else
        {
            if (note.direction < strumline.keyCount && !strumline.hasActiveSustain(note.direction))
            {
                strumline.strumGlowTimers[note.direction] = event.strumResetTimer;

                if (strumline.strums.members[note.direction] != null && event.strumGlow)
                    strumline.strums.members[note.direction].play("confirm", true);
            }
        }

        changeNoteVocals(note, 1.0);
    }

    public function sustainHit(sustain:SustainNote)
    {
        var event = new SustainHitScriptEvent(NOTE_HOLD, sustain, true, true);
        dispatchEvent(event);

        if (event.cancelled)
            return;

        if (sustain.mustHit)
        {
            var playerEvent = new SustainHitScriptEvent(PLAYER_HOLD, sustain, true, true);
            dispatchEvent(playerEvent);

            if (playerEvent.cancelled)
                return;

            event = playerEvent;
        }
        else
        {
            var opponentEvent = new SustainHitScriptEvent(OPPONENT_HOLD, sustain, true, true);
            dispatchEvent(opponentEvent);

            if (opponentEvent.cancelled)
                return;

            event = opponentEvent;
        }

        var strumline = sustain.strumline;

        if (!sustain.glow)
        {
            sustain.glow = true;

            if (strumline.hasCovers && strumline.covers.members[sustain.direction] != null && event.showCover)
                strumline.covers.members[sustain.direction].start();

            if (event.strumGlow)
            {
                strumline.strumGlowTimers[sustain.direction] = 0;
                strumline.strums.members[sustain.direction].play("confirm", true);
            }
        }

        if (sustain.length <= 0)
        {
            if (sustain.mustHit)
            {
                if (event.strumGlow)
                    strumline.strums.members[sustain.direction].play("pressed", true);

                if (strumline.hasCovers && strumline.covers.members[sustain.direction] != null && event.showCover)
                    strumline.covers.members[sustain.direction].finish();
            }
            else
            {
                if (event.strumGlow)
                    strumline.strums.members[sustain.direction].play("static", true);

                if (strumline.hasCovers && strumline.covers.members[sustain.direction] != null && event.showCover)
                    strumline.covers.members[sustain.direction].hide();
            }
        }
    }

    public function noteMiss(note:Note)
    {
        var event = new NoteHitScriptEvent(PLAYER_MISS, note, 150, true, true, true);
        dispatchEvent(event);

        if (event.cancelled)
            return;

        if (note.mustHit)
        {
            metrics.miss();
            metrics.calculateAccuracy();

            changeNoteVocals(note, 0.0);

            var index = FlxG.random.int(0, 2);

            if (missSounds[index] != null)
            {
                missSounds[index].stop();
                missSounds[index].volume = 0.4;
                missSounds[index].play();
            }
        }
    }

    /**
     * Updates the game camera whenever the window is resized.
     */
    public override function onResize(width:Int, height:Int):Void
    {
        super.onResize(width, height);

        resizeCameras(width, height);
    }

    /**
     * Resizes every camera to fit the application windows' width and height. [EXPERIMENTAL]
     */
    public function resizeCameras(width:Int, height:Int)
    {
        var ratio:Float = width / height;
        var baseRatio:Float = FlxG.width / FlxG.height;

        var camWidth:Int = FlxG.width;
        var camHeight:Int = FlxG.height;

        if (ratio > baseRatio) 
            camWidth = Std.int(FlxG.height * ratio);
        else 
            camHeight = Std.int(FlxG.width / ratio);

        var camX:Float = -(camWidth - FlxG.width) / 2;
        var camY:Float = -(camHeight - FlxG.height) / 2;

        var allCameras = [camGame, camBetween, camHUD, camStrums, camMisc, camOverlay];

        for (camera in allCameras)
        {
            if (camera != null)
            {
                if ([camGame, camOverlay].contains(camera))
                {
                    camera.width = camWidth;
                    camera.x = camX;
                }

                camera.height = camHeight;
                camera.y = camY;
            }
        }

        if (camGame != null && pointer != null)
        {
            camGame.follow(pointer);
            camGame.focusOn(pointer.getPosition());
        }
        
        syncHUD();

        if (countdown != null)
            countdown.sync();
    }

    /**
     * Syncs the HUD Objects to the current scroll and camera dimensions.
     */
    public function syncHUD():Void
    {
        if (healthBar != null)
            healthBar.y = Configs.DOWNSCROLL ? healthBar.camera.height * 0.1 : healthBar.camera.height * 0.9;

        if (scoreText != null && healthBar != null)
            scoreText.y = healthBar.y + 30;
    }
}
