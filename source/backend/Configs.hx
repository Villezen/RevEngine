package backend;

import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSave;

import backend.Highscore.ScoreRecord;

/**
 * A class containing every customizable setting you can configure in-game.
 */
class Configs
{
    public static var configSave:FlxSave;
    public static var highscoreSave:FlxSave;

    /**
     * [MODDING]
     */

    /**
     * The currently active mod.
     */
    public static var ACTIVE_MOD:String = "";

    /**
     * [KEYBINDS]
     */

    /**
     * Keybinds used to go back or cancel in menus.
     */
    public static var BACK_BIND:Array<Dynamic> = [FlxKey.ESCAPE, FlxKey.BACKSPACE];

    /**
     * Keybinds used to confirm or accept selections in menus.
     */
	public static var ACCEPT_BIND:Array<Dynamic> = [FlxKey.ENTER, FlxKey.SPACE];

    /**
     * Standard directional inputs for navigating the UI.
     */
    public static var UI_BINDS:Array<Dynamic> =
    [
        [FlxKey.A, FlxKey.LEFT],
        [FlxKey.S, FlxKey.DOWN],
        [FlxKey.W, FlxKey.UP],
        [FlxKey.D, FlxKey.RIGHT]
    ];

    public static var NOTE_BINDS_1K:Array<Dynamic> =
    [ 
        [FlxKey.SPACE, FlxKey.NONE]
    ];

    public static var NOTE_BINDS_2K:Array<Dynamic> =
    [ 
        [FlxKey.D, FlxKey.NONE],
        [FlxKey.K, FlxKey.NONE]
    ];

    public static var NOTE_BINDS_3K:Array<Dynamic> =
    [ 
        [FlxKey.D, FlxKey.NONE],
        [FlxKey.SPACE, FlxKey.NONE],
        [FlxKey.K, FlxKey.NONE]
    ];

    public static var NOTE_BINDS_4K:Array<Dynamic> =
    [ 
        [FlxKey.D, FlxKey.LEFT],
        [FlxKey.F, FlxKey.DOWN],
        [FlxKey.J, FlxKey.UP],
        [FlxKey.K, FlxKey.RIGHT]
    ];

    public static var NOTE_BINDS_5K:Array<Dynamic> =
    [
        [FlxKey.D, FlxKey.NONE],
        [FlxKey.F, FlxKey.NONE],
        [FlxKey.SPACE, FlxKey.NONE],
        [FlxKey.J, FlxKey.NONE],
        [FlxKey.K, FlxKey.NONE]
    ];

    public static var NOTE_BINDS_6K:Array<Dynamic> =
    [
        [FlxKey.S, FlxKey.NONE],
        [FlxKey.D, FlxKey.NONE],
        [FlxKey.F, FlxKey.NONE],
        [FlxKey.J, FlxKey.NONE],
        [FlxKey.K, FlxKey.NONE],
        [FlxKey.L, FlxKey.NONE]
    ];

    public static var NOTE_BINDS_7K:Array<Dynamic> =
    [
        [FlxKey.S, FlxKey.NONE],
        [FlxKey.D, FlxKey.NONE],
        [FlxKey.F, FlxKey.NONE],
        [FlxKey.SPACE, FlxKey.NONE],
        [FlxKey.J, FlxKey.NONE],
        [FlxKey.K, FlxKey.NONE],
        [FlxKey.L, FlxKey.NONE]
    ];

    public static var NOTE_BINDS_8K:Array<Dynamic> =
    [
        [FlxKey.A, FlxKey.NONE],
        [FlxKey.S, FlxKey.NONE],
        [FlxKey.D, FlxKey.NONE],
        [FlxKey.F, FlxKey.NONE],
        [FlxKey.H, FlxKey.NONE],
        [FlxKey.J, FlxKey.NONE],
        [FlxKey.K, FlxKey.NONE],
        [FlxKey.L, FlxKey.NONE]
    ];

    public static var NOTE_BINDS_9K:Array<Dynamic> =
    [
        [FlxKey.A, FlxKey.NONE],
        [FlxKey.S, FlxKey.NONE],
        [FlxKey.D, FlxKey.NONE],
        [FlxKey.F, FlxKey.NONE],
        [FlxKey.SPACE, FlxKey.NONE],
        [FlxKey.H, FlxKey.NONE],
        [FlxKey.J, FlxKey.NONE],
        [FlxKey.K, FlxKey.NONE],
        [FlxKey.L, FlxKey.NONE]
    ];

    /**
     * [GAMEPLAY]
     */

    public static var HIGHSCORES:Map<String, ScoreRecord> = [];
    public static var DOWNSCROLL:Bool = false;

    /**
     * [FREEPLAY]
     */

    /**
     * The IDs of songs the player has favorited.
     */
    public static var FAVORITE_SONGS:Array<String> = [];

    /**
     * Private function that loads each config.
     */
    private static function _load()
    {
        if (configSave.data.ACTIVE_MOD != null) ACTIVE_MOD = configSave.data.ACTIVE_MOD;

        if (configSave.data.BACK_BIND != null) BACK_BIND = configSave.data.BACK_BIND;
        if (configSave.data.ACCEPT_BIND != null) ACCEPT_BIND = configSave.data.ACCEPT_BIND;
        if (configSave.data.UI_BINDS != null) UI_BINDS = configSave.data.UI_BINDS;

        if (configSave.data.NOTE_BINDS_1K != null) NOTE_BINDS_1K = configSave.data.NOTE_BINDS_1K;
        if (configSave.data.NOTE_BINDS_2K != null) NOTE_BINDS_2K = configSave.data.NOTE_BINDS_2K;
        if (configSave.data.NOTE_BINDS_3K != null) NOTE_BINDS_3K = configSave.data.NOTE_BINDS_3K;
        if (configSave.data.NOTE_BINDS_4K != null) NOTE_BINDS_4K = configSave.data.NOTE_BINDS_4K;
        if (configSave.data.NOTE_BINDS_5K != null) NOTE_BINDS_5K = configSave.data.NOTE_BINDS_5K;
        if (configSave.data.NOTE_BINDS_6K != null) NOTE_BINDS_6K = configSave.data.NOTE_BINDS_6K;
        if (configSave.data.NOTE_BINDS_7K != null) NOTE_BINDS_7K = configSave.data.NOTE_BINDS_7K;
        if (configSave.data.NOTE_BINDS_8K != null) NOTE_BINDS_8K = configSave.data.NOTE_BINDS_8K;
        if (configSave.data.NOTE_BINDS_9K != null) NOTE_BINDS_9K = configSave.data.NOTE_BINDS_9K;

        if (highscoreSave.data.HIGHSCORES != null) HIGHSCORES = highscoreSave.data.HIGHSCORES;
        
        if (configSave.data.DOWNSCROLL != null) DOWNSCROLL = configSave.data.DOWNSCROLL;

        if (configSave.data.FAVORITE_SONGS != null) FAVORITE_SONGS = configSave.data.FAVORITE_SONGS;
    }

    /**
     * Private function that saves each config.
     */
    private static function _save()
    {
        configSave.data.ACTIVE_MOD = ACTIVE_MOD;

        configSave.data.BACK_BIND = BACK_BIND;
        configSave.data.ACCEPT_BIND = ACCEPT_BIND;
        configSave.data.UI_BINDS = UI_BINDS;

        configSave.data.NOTE_BINDS_1K = NOTE_BINDS_1K;
        configSave.data.NOTE_BINDS_2K = NOTE_BINDS_2K;
        configSave.data.NOTE_BINDS_3K = NOTE_BINDS_3K;
        configSave.data.NOTE_BINDS_4K = NOTE_BINDS_4K;
        configSave.data.NOTE_BINDS_5K = NOTE_BINDS_5K;
        configSave.data.NOTE_BINDS_6K = NOTE_BINDS_6K;
        configSave.data.NOTE_BINDS_7K = NOTE_BINDS_7K;
        configSave.data.NOTE_BINDS_8K = NOTE_BINDS_8K;
        configSave.data.NOTE_BINDS_9K = NOTE_BINDS_9K;

        highscoreSave.data.HIGHSCORES = HIGHSCORES;

        configSave.data.DOWNSCROLL = DOWNSCROLL;

        configSave.data.FAVORITE_SONGS = FAVORITE_SONGS;
    }

    /**
     * Loads each save file and alongside every config.
     */
    public static function load()
    {
        if (configSave == null)
            configSave = new FlxSave();

        configSave.bind('Configs', "RevEngine Configs [v" + Constants.CONFIG_VERSION + ']');

        if (highscoreSave == null)
            highscoreSave = new FlxSave();

        highscoreSave.bind('Highscores', "RevEngine Highscores [v" + Constants.HIGHSCORE_VERSION + ']');

        _load();
    }

    /**
     * Saves each config to the save file.
     */
    public static function save()
    {
        _save();

        configSave.flush();
        highscoreSave.flush();
    }
}