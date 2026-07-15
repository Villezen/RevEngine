package game;

import flixel.FlxCamera;
import flixel.FlxSubState;

import backend.assets.FunkinSound;
import flixel.math.FlxMath;

import flixel.util.FlxTimer;
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

import backend.registries.song.ChartRegistry;
import backend.registries.song.MetaRegistry;
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
import backend.utils.MemoryUtil;

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
     * The strumline controlled by the player.
     */
    public var playerStrums:Strumline;

    /**
     * The strumline controlled by the opponent.
     */
    public var enemyStrums:Strumline;

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
     * Queue for key presses to be processed in the next update tick.
     */
    private var pressEntryList:Array<InputEntry> = [];

    /**
     * Queue for key releases to be processed in the next update tick.
     */
    private var releaseEntryList:Array<InputEntry> = [];

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
     * Internal variables used for lerping.
     */
    private var scoreLerp:Float = 0;
    private var healthLerp:Float = 0;

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
    private var reanchorConductor:Bool = false;

    /**
     * The Conductor position the strumline is last rendered with.
     */
    private var lastConductorPos:Float = 0;

    /**
     * Internal variable to check if the player is currently able to skip through the song.
     */
    private var canSkip:Bool = false;

    /**
     * Internal variable to check if the player is currently skipping through the song in any way.
     */
    private var timeSkipping:Bool = false;

    /**
     * Transition-finish listener, kept so destroy() can invalidate it if this state dies before the transition completes.
     */
    private var onTransitionFinish:Void->Void;

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
        for (entry in chart.strumlines)
        {
            var strumline:Strumline = new Strumline(entry.position[0], entry.position[1], {data: entry, cpu: entry.id == 1 ? false : true, skin: entry.skin, scale: entry.scale});
            strumline.visible = entry.visible;
            strumline.camera = camStrums;
            add(strumline);

            strumline.onNoteHit.add(noteHit);
            strumline.onSustainHit.add(sustainHit);
            strumline.onNoteMiss.add(noteMiss);

            strumlines.set(entry.id, strumline);
        }

        enemyStrums = strumlines.get(0);
        playerStrums = strumlines.get(1);

        metrics = new PlayMetrics(name);
        
        var noteTotal:Int = 0;
        for (entry in chart.strumlines)
        {
            if (entry.id == 1 && entry.notes != null)
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
        inputs.setup(playerStrums.keyCount);

        inputs.onInputPressed.add(function(entry:InputEntry)
        {
            if (playerStrums.cpu) return;
            pressEntryList.push(entry); 
        });

        inputs.onInputReleased.add(function(entry:InputEntry)
        {
            if (playerStrums.cpu) return;
            releaseEntryList.push(entry);
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

        var opponentName:String = null;
        for (entry in chart.strumlines)
        {
            if (entry.id == 0)
            {
                opponentName = entry.character;
                break;
            }
        }

        for (entry in chart.strumlines)
        {
            if (entry.id == 2 && opponentName != null && entry.character == opponentName)
                continue;

            var character:Character = CharacterHandler.spawn(0, 0, {name: entry.character, parent: strumlines.get(entry.id)});

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

            characters.set(entry.id, character);
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
            healthBar = new HealthBar(0, 0, {parent: this, parentVar: 'healthLerp', characters: [PlayState.instance.dad, PlayState.instance.boyfriend]});
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

        healthLerp = metrics.health ?? 1.0;

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

        runAfterTransition(() -> FlxTimer.wait(conductor.beatLengthMs / 1000, () -> Manager.openSubState(new DialogueSubState())));
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

        onTransitionFinish = function()
        {
            onTransitionFinish = null;
            action();
        };

        TransitionLoader.onTransitionFinish.addOnce(onTransitionFinish);
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
        canSkip = true;

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
        canSkip = false;

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
            return;

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

        Highscore.saveScore(name, difficulty, variation, {score: Std.int(metrics.score), tallies: tallies});
    }

    /**
     * Updates the game state, alongside other variables.
     */
    public override function update(elapsed:Float):Void
    {
        super.update(elapsed);

        lastConductorPos = conductor.position;

        if (updateConductor)
        {
            var newPosition:Float = conductor.position + elapsed * 1000;

            if (song != null && song.inst != null && song.inst.playing)
            {
                var drift:Float = song.inst.time - newPosition;
                
                if (reanchorConductor || Math.abs(drift) > Constants.CONDUCTOR_HARD_RESYNC)
                    newPosition = song.inst.time;
                else
                    newPosition += drift * Math.min(1.0, elapsed * Constants.CONDUCTOR_DRIFT_RATE);
            }

            reanchorConductor = false;

            conductor.update(newPosition);
        }

        if (FlxG.keys.justPressed.ESCAPE && songStarted)
        {
            updateConductor = false;
            
            if (song != null)
                song.stop();

            FunkinSound.stopAllAudio(true);
            Manager.switchState(new menus.MainMenuState(), "stickers");
        }

        if (FlxG.keys.justPressed.SEVEN)
        {
            Manager.switchState("Charter");
        }

        processInputs(elapsed);

        if (canSkip)
            updateTimeSkipping(FlxG.keys.pressed.TWO || FlxG.keys.pressed.ONE, (FlxG.keys.pressed.TWO ? 3.0 : 0.5));
        else if (!canSkip && FlxG.timeScale != 1.0)
            setTimeScale(1.0);

        if (camerasCanLerp)
        {
            var decay:Float = 0.85;
            var speed:Float = (elapsed * 60) * camerasZoomLerpSpeed;
            var lerpFactor:Float = Math.pow(decay, speed);

            cameraBopMultiplier = FlxMath.lerp(1.0, cameraBopMultiplier, lerpFactor);
            FlxG.camera.zoom = (currentCameraZoom * cameraBopMultiplier);

            for (hudCameras in _hudZoomCameras)
                hudCameras.zoom = FlxMath.lerp(currentHudZoom, hudCameras.zoom, lerpFactor);
        }

        scoreLerp = MathUtil.framerateLerp(scoreLerp, metrics.score ?? 0, FlxMath.bound(elapsed * (30 * 1.0), 0, 1));
        healthLerp = MathUtil.framerateLerp(healthLerp, metrics.health ?? 1.0, FlxMath.bound(elapsed * (30 * 1.5), 0, 1));

        if (scoreText != null)
        {
            var roundedScore:Int = Math.round(scoreLerp);

            if (roundedScore != _lastDisplayedScore)
            {
                _lastDisplayedScore = roundedScore;
                scoreText.text = "Score: " + Std.string(FlxStringUtil.formatMoney(roundedScore, false, true));
            }
        }

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
    }

    /**
     * Procces inputs to determine if a note should be hit or not.
     */
    function processInputs(elapsed:Float)
    {
        if (playerStrums == null) return;

        for (sustain in playerStrums.sustains.members)
        {
            if (sustain == null || !sustain.exists || !sustain.alive) continue;

            if (conductor.position >= sustain.time && sustain.hit && !sustain.missed && sustain.mustHit)
                metrics.hold(elapsed);
        }

        if (pressEntryList.length + releaseEntryList.length <= 0 || playerStrums.cpu) return;

        for (pressEntry in pressEntryList)
        {
            var noteDir:Int = pressEntry.direction;
            
            playerStrums.pressKey(noteDir);

            var spr:Strum = playerStrums.strums.members[noteDir];
            spr?.play("pressed", true);

            var sortedNotesList:Array<Note> = playerStrums.filterHittableNotes(noteDir);
            sortedNotesList.sort(playerStrums?.sortHitNotes);

            if (sortedNotesList.length > 0) 
            {
                var targetNote = sortedNotesList[0];
                    
                if (targetNote != null && targetNote.alive)
                {
                    if (targetNote.sustain != null)
                    {
                        var sustain:SustainNote = targetNote.sustain;

                        sustain.hit = true;
                        sustain.missed = false;
                        sustain.missHandled = false;

                        var catchPadding:Float = 0;
                        if (sustain.strum != null && playerStrums.speed > 0)
                            catchPadding = (sustain.strum.height / 4) / (0.45 * playerStrums.speed);

                        sustain.fullLength = (sustain.time + sustain.fullLength) - lastConductorPos + catchPadding;
                        sustain.time = lastConductorPos;
                        sustain.length = sustain.fullLength;

                        if (sustain.strum != null)
                        {
                            sustain.y = sustain.strum.y + sustain.strum.height / 2;
                            sustain.sync();
                        }
                    }

                    playerStrums.onNoteHit.dispatch(targetNote);
                    targetNote.kill();
                }           
            }
        }
        pressEntryList.resize(0);

        for (releaseEntry in releaseEntryList)
        {
            var noteDir:Int = releaseEntry.direction;   

            playerStrums.releaseKey(noteDir);
            
            var spr:Strum = playerStrums.strums.members[noteDir];
            spr?.play("static", true);      
        }
        releaseEntryList.resize(0);
    }

    /**
     * Destroys and nullifies most of the variables.
     */
    public override function destroy():Void
    {
        FlxG.signals.focusGained.remove(onWindowRefocus);

        if (onTransitionFinish != null)
        {
            TransitionLoader.onTransitionFinish.remove(onTransitionFinish);
            onTransitionFinish = null;
        }

        if (conductor.onStepHit.has(stepHit))
            conductor.onStepHit.remove(stepHit);

        if (conductor.onBeatHit.has(beatHit))
            conductor.onBeatHit.remove(beatHit);

        if (conductor.onMeasureHit.has(measureHit))
            conductor.onMeasureHit.remove(measureHit);

        if (missSounds != null)
        {
            for (snd in missSounds)
            {
                if (snd != null)
                {
                    FlxG.sound.list.remove(snd, true);
                    snd.destroy();
                }
            }
            missSounds = [];
        }

        var allCameras = [camGame, camBetween, camHUD, camStrums, camMisc, camOverlay];
        for (cam in allCameras)
        {
            if (cam != null && FlxG.cameras.list.contains(cam))
            {
                FlxG.cameras.remove(cam, true);
            }
        }

        if (song != null)
        {
            song.stop();
        }

        if (inputs != null)
        {
            inputs.destroy();
            inputs = null;
        }

        instance = null;

        song = null;
        chart = null;
        meta = null;
        
        metrics = null;
        eventsHandler = null;

        playerStrums = null;
        enemyStrums = null;

        strumlines.clear();
        characters.clear();

        stage = null;
        pointer = null;

        dad = null;
        boyfriend = null;
        gf = null;

        inputs?.destroy();

        CharacterHandler.clear();

        super.destroy();
    }

    /**
     * Reloads every registry in this state.
     */
    override function hotReload():Void
    {
        super.hotReload();

        ChartRegistry.reloadSong(name);
        MetaRegistry.reload(name);
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
            var noteskinsToReset:Array<String> = [];
            var charactersToReset:Array<String> = [];

            for (entry in chart.strumlines)
            {
                if (!noteskinsToReset.contains(entry.skin))
                    noteskinsToReset.push(entry.skin);

                if (!charactersToReset.contains(entry.character))
                    charactersToReset.push(entry.character);
            }

            for (skin in noteskinsToReset)
                NoteSkinRegistry.reload(skin);

            for (character in charactersToReset)
                CharacterRegistry.reload(character);
        }
    }

    /**
     * Makes the next Conductor update to re-anchor to the audio instead of advancing through the refocus elapsed spike.
     */
    function onWindowRefocus():Void
    {
        reanchorConductor = true;
    }

    public function onSubStateOpen(substate:FlxSubState)
    {
        if (Std.isOfType(substate, game.DialogueSubState))
		{
			persistentDraw = true;
			persistentUpdate = false;
		}
    }

    public function onSubStateClose(substate:FlxSubState)
    {
        if (Std.isOfType(substate, game.DialogueSubState))
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
    private function updateTimeSkipping(pressed:Bool, speed:Float)
    {
        if (pressed && FlxG.timeScale != speed)
            setTimeScale(speed);
        else if (!pressed && FlxG.timeScale != 1.0)
            setTimeScale(1.0);

        if (pressed == timeSkipping || playerStrums == null)
            return;

        timeSkipping = pressed;
        playerStrums.cpu = pressed;

        if (pressed)
        {
            for (i in 0...playerStrums.keyCount)
            {
                playerStrums.releaseKey(i);

                var strum:Strum = playerStrums.strums.members[i];

                if (strum != null && strum.animation != null && strum.animation.name == "pressed")
                    strum.play("static", true);
            }

            pressEntryList.resize(0);
            releaseEntryList.resize(0);
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

    /**
     * Function that gets called every time a new step is iterated.
     * @param measure The current measure index.
     */
    public override function measureHit(measure:Float):Void
    {
        super.measureHit(measure);

        #if cpp
        if (Constants.GAMEPLAY_GC_MEASURES > 0 && measure > 0 && measure % Constants.GAMEPLAY_GC_MEASURES == 0)
            MemoryUtil.softClean();
        #end
    }

    public function eventExecution(event:Event)
    {
        var scriptEvent = new SongEventScriptEvent(event.name, event.time, event.variables);
        dispatchEvent(scriptEvent);

        if (scriptEvent.cancelled)
            return;

        SongEventModuleHandler.execute(scriptEvent);
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
            var rating:NoteJudgement = metrics.calculateRating(note.time - conductor.position);
            
            if (event.showRating)
                metrics.judgeRating(rating);

            metrics.calculateAccuracy();

            ratings.popRating(rating);
            ratings.popCombo(metrics.combo);

            if (event.strumGlow)
            {
                var strum = strumline.strums.members[note.direction];

                if (note.direction < strumline.keyCount && strum != null)
                {
                    if (strum.timer != null)
                        strum.timer.cancel();

                    strum.play("confirm", true);

                    if (note.sustain == null)
                    {
                        strum.timer = new FlxTimer().start(conductor.beatLengthMs / 2000, (_) ->
                        {
                            if (strum.animation.curAnim.name == "confirm")
                                strum.play("pressed", true);

                            strum.timer == null;
                        });
                    }
                }
            }

            if (rating == NoteJudgement.SICK && strumline.hasSplashes && strumline.splashes.members[note.direction] != null && event.showSplashes)
                strumline.splashes.members[note.direction].splash();
        }
        else
        {
            if (note.direction < strumline.keyCount)
            {
                strumline.strumGlowTimers[note.direction] = event.strumResetTimer;

                if (strumline.strums.members[note.direction] != null && event.strumGlow)
                    strumline.strums.members[note.direction].play("confirm", true);
            }
        }

        for (entry in chart.strumlines)
        {
            if (entry.id == note.strumline.id)
            {
                if (song != null)
                    song.changePlayerVolume(1.0, entry.character);

                break;
            }
        }
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

            for (entry in chart.strumlines)
            {
                if (entry.id == note.strumline.id)
                {
                    if (song != null)
                        song.changePlayerVolume(0.0, entry.character);

                    break;
                }
            }

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
