package backend.config;

import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSave;

import backend.Highscore.ScoreRecord;

/**
 * A class containing every customizable setting you can configure in-game.
 */
@:build(backend.macros.ConfigMacro.build())
class Configs
{
    /**
     * The save file holding every config.
     */
    @:noSave public static var configSave:FlxSave;

    /**
     * Extra settings defined at runtime, mainly by mods, keyed by name.
     */
    @:noSave public static var store:Map<String, Dynamic> = [];

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
     * Reads a defined value from the store.
     * @param key The name the value was stored under.
     * @param fallback The value returned when the key is missing.
     * @return The stored value, or `fallback` if it was never set.
     */
    public static function get(key:String, ?fallback:Dynamic = null):Dynamic
    {
        if (store.exists(key))
            return store.get(key);

        return fallback;
    }

    /**
     * Writes a defined value into the store.
     * @param key The name to store the value under.
     * @param value The value to persist on the next save.
     */
    public static function set(key:String, value:Dynamic):Void
    {
        store.set(key, value);
    }

    /**
     * Checks whether a defined value exists in the store.
     * @param key The name to look up.
     * @return Whether a value is present for that key.
     */
    public static function has(key:String):Bool
    {
        return store.exists(key);
    }

    /**
     * Loads each save file and alongside every config.
     */
    public static function load()
    {
        if (configSave == null)
            configSave = new FlxSave();

        configSave.bind('Configs', "RevEngine Configs [v" + Constants.CONFIG_VERSION + ']');

        if (configSave.data.store != null)
            store = configSave.data.store;

        _load();
    }

    /**
     * Saves each config to the save file.
     */
    public static function save()
    {
        _save();

        configSave.data.store = store;
        configSave.flush();
    }
}
