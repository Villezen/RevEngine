package backend;

import flixel.util.typeLimit.NextState;

import game.PlayMetrics.NoteJudgement;
import game.PlayState.PlayStateParams;

import thx.semver.Version;
import thx.semver.VersionRule;

import backend.utils.WindowUtil;

/**
 * A class that stores constant values so they can be accessed wit
 */

class Constants
{
    /**
     * Which repository should the engine track its latest commit from.
     */
    public static final REPOSITORY_NAME:String = "RevEngine";

    /**
     * Who is the owner of the repository that the engine should track.
     */
    public static final REPOSITORY_OWNER:String = "Villezen";

    /**
     * Which branch should the engine track?
     */
    public static final REPOSITORY_BRANCH:String = "main";

    /**
     * The modding API of this engine. Used to not cause errors on mods with an older API version.
     */
    public static final API_VERSION:Version = '1.0.0';

    /**
     * The version rule of the engine's API. Mods that not in accordance to the rule will not get added.
     */
    public static final API_VERSION_RULE:VersionRule = ">=1.0.0";

    /**
     * The version of the mod's config saving system. Change this when the way certain configs work changes to prevent crashes so they get reset fully.
     */
    public static final CONFIG_VERSION:Version = '1.0.0';

    /**
     * The version of the highscore's saving system. Change this when the way saving highscores works to prevent crashes so they get reset fully.
     */
    public static final HIGHSCORE_VERSION:Version = '1.0.0';

    /**
     * The folder that stores each mod.
     */
    public static final MOD_FOLDER:String = "mods";

    /**
     * The folder that stores each script.
     */
    public static final SCRIPT_FOLDER:String = "scripts";

    /**
     * Descriptive string identifying the current build version.
     */
    public static final VERSION_STRING:String = '0.0.1';

    /**
     * Checks if this build is in debugging mode or not.
     */
    public static final DEBUG_MODE:Bool = true;

    /**
     * Descriptive string identifying the current build type.
     */
    public static final BUILD_TYPE:String = (DEBUG_MODE ? 'DEVELOPER BUILD' : 'RELEASE BUILD');

    /**
     * The width, used to space out the strums in-game.
     */
    public static final STRUM_WIDTH:Float = 150 * 0.7;

    /**
     * Multiplier applied to the hit window for notes hit before the perfect timing.
     */
    public static final EARLY_HIT_MULT:Float = 0.7; 

    /**
     * Multiplier applied to the hit window for notes hit after the perfect timing.
     */
    public static final LATE_HIT_MULT:Float = 0.7;

    /**
     * The total 'safe' window (in milliseconds) a player has to hit a note.
     */
    public static final SAFE_ZONE_OFFSET:Float = (12 / 60) * 1000;

    /**
     * The amount of time (in milliseconds) a note is visible on screen before it reaches the strumline.
     */
    public static final NOTE_SPAWN_TIME:Float = 1500;

    /**
     * The threshold (in milliseconds) at which the vocals will force to be resynced to the instrumental's position.
     */
    public static final RESYNC_THRESHOLD:Int = 40;

    /**
     * The distance between the Conductor and the instrumental which the Conductor snaps to the audio time.
     */
    public static final CONDUCTOR_HARD_RESYNC:Float = 100;

    /**
     * How much the conductor gets pulled towards the instrumental's time.
     */
    public static final CONDUCTOR_DRIFT_RATE:Float = 5;

    /**
     * How many measures between memory cleanups during gameplay.
     */
    public static final GAMEPLAY_GC_MEASURES:Int = 4;

    /**
     * How many seconds between periodic memory cleanups outside of gameplay. Set to 0 to disable.
     */
    public static final IDLE_GC_INTERVAL:Float = 5;

    /**
     * Maximum amount of health you can gain.
     */
    public static final MAX_HEALTH = 2;

    /**
     * Maximum amount of health you can lose. Getting this amount will cause a game over.
     */
    public static final MIN_HEALTH = 0;

    /**
     * Map containing each judgement and the data associated with it.
     * 
     * [0] is % of health gained/lost
     * [1] is % of score gained/lost
     * [2] is % of hitNotes registered
     */
    public static final JUDGEMENT_MAP:Map<NoteJudgement, Array<Float>> =
    [
        NoteJudgement.SICK => [1.5, 300.0, 1.0],
        NoteJudgement.GOOD => [0.75, 100.0, 0.65],
        NoteJudgement.BAD => [0.0, 10.0, 0.2],
        NoteJudgement.SHIT => [-1.0, 5, 0.03],
        NoteJudgement.NONE => [0.0, 0.0, 0.0]
    ];

    /**
     * Map containing each rating's millisecond hit window.
     */
    public static final RATING_MAP:Map<NoteJudgement, Int> =
    [
        NoteJudgement.SICK => 45,
        NoteJudgement.GOOD => 75,
        NoteJudgement.BAD => 105,
        NoteJudgement.SHIT => 135,
        NoteJudgement.NONE => -1
    ];

    /**
     * The amount of health lost when the player misses a note.
     */
    public static final MISS_HEALTH_LOSS:Float = 0.1;

    /**
     * The amount of score that's lost whenever a player misses a note.
     */
    public static final MISS_SCORE_LOSS:Int = 40;

    /**
     * The amount of health gained per second while holding down a sustain note.
     * 7.5 %
     */
    public static final SUSTAIN_HEALTH_GAIN_PER_SEC:Float = (7.5 / 100.0 * 2);

    /**
     * The amount of score per second while holding down a sustain note.
     */
    public static final SUSTAIN_SCORE_GAIN_PER_SEC:Float = 100;

    /**
     * The sing animations each character should play, depending on the note direction and key count. 
     */
    public static final SING_DIRECTIONS:Map<Int, Array<String>> =
    [
        1 => ['UP'],
        2 => ['LEFT', 'RIGHT'],
        3 => ['LEFT', 'UP', 'RIGHT'],
        4 => ['LEFT', 'DOWN', 'UP', 'RIGHT'],
        5 => ['LEFT', 'DOWN', 'UP', 'UP', 'RIGHT'],
        6 => ['LEFT', 'UP', 'RIGHT', 'LEFT', 'DOWN', 'RIGHT'],
        7 => ['LEFT', 'UP', 'RIGHT', 'UP', 'LEFT', 'DOWN', 'RIGHT'],
        8 => ['LEFT', 'DOWN', 'UP', 'RIGHT', 'LEFT', 'DOWN', 'UP', 'RIGHT'],
        9 => ['LEFT', 'DOWN', 'UP', 'RIGHT', 'UP', 'LEFT', 'DOWN', 'UP', 'RIGHT']
    ];

    /**
     * Maps the strum direction to a specific color based on the key count.
     */
    public static var COLOR_DIRECTIONS:Map<Int, Array<String>> =
    [
        1 => ['E'],
        2 => ['purple', 'red'],
        3 => ['A', 'E', 'D'],
        4 => ['purple', 'blue', 'green', 'red'],
        5 => ['A', 'B', 'E', 'C', 'D'],
        6 => ['A', 'C', 'D', 'F', 'G', 'I'],
        7 => ['A', 'C', 'D', 'E', 'F', 'G', 'I'],
        8 => ['A', 'B', 'C', 'D', 'F', 'G', 'H', 'I'],
        9 => ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I']
    ];

    /**
     * Maps the strum direction to a specific color based on keybind noteskins.
     */
    public static var DIRECTIONS_KEYBIND:Map<Int, Array<String>> =
    [
        1 => ['A'],
        2 => ['left', 'right'],
        3 => ['A', 'B', 'C'],
        4 => ['left', 'down', 'up', 'right'],
        5 => ['A', 'B', 'C', 'D', 'E'],
        6 => ['A', 'B', 'C', 'D', 'E', 'F'],
        7 => ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
        8 => ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'],
        9 => ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I']
    ];

    /**
     * Maps the strum direction to a specific readable direction string.
     */
    public static var DIRECTIONS:Map<Int, Array<String>> =
    [
        1 => ['space'],
        2 => ['left', 'right'],
        3 => ['left', 'space', 'right'],
        4 => ['left', 'down', 'up', 'right'],
        5 => ['left', 'down', 'space', 'up', 'right'],
        6 => ['left', 'up', 'right', 'left', 'down', 'right'],
        7 => ['left', 'up', 'right', 'space', 'left', 'down', 'right'],
        8 => ['left', 'down', 'up', 'right', 'left', 'down', 'up', 'right'],
        9 => ['left', 'down', 'up', 'right', 'space', 'left', 'down', 'up', 'right']
    ];

    /**
     * Absolute paths of the assets that should be added to the async preloader when loading into PlayState.
     */
    public static final PRELOAD_ASSETS:Array<String> =
    [
        'images/game/ui/missVignette'
    ];
    
    /**
     * Absolute paths of the sounds that should be added to the async preloader when loading into PlayState.
     */
    public static final PRELOAD_SOUNDS:Array<String> =
    [
        'audio/sounds/gameplay/miss/0',
        'audio/sounds/gameplay/miss/1',
        'audio/sounds/gameplay/miss/2'
    ];

    /**
     * The delay of the countdown.
     */
    public static final DEFAULT_COUNTDOWN_DELAY:Float = 0.35;

    /**
     * The difficulty charts fall back to when none is specified.
     */
    public static final DEFAULT_DIFFICULTY:String = "normal";

    /**
     * The default player character freeplay starts on.
     */
    public static final DEFAULT_CHARACTER:String = "bf";

    /**
     * PlayState's default parameters, utilized as a fallback.
     */
    public static final DEFAULT_PLAYSTATE_PARAMS:PlayStateParams = {song: 'test', difficulty: 'normal'}

    /**
     * By how much the game camera shall bop by default.
     */
    public static final CAMGAME_BOP_VALUE:Float = 0.015;

    /**
     * By how much the hud cameras shall bop by default.
     */
    public static final CAMHUD_BOP_VALUE:Float = 0.015*2;
}