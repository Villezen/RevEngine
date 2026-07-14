package backend.utils;

import flixel.util.FlxSignal.FlxTypedSignal;

import lime.app.Application;
import lime.ui.MessageBoxType;

/**
 * A class focused around utulizing the game's window.
 */
final class WindowUtil
{
    private static var initialized:Bool = false;
    
    public static var onDropFile:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

    public static var onFocusOut:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();
    public static var onFocusIn:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();

    /**
     * Sets up each signal defined above.
     */
    public static function initSignals():Void
    {
        clearSignals();

        if (initialized) return;

        Application.current.window.onDropFile.add(function(file:String, type:String, x:Float, y:Float)
        {
            onDropFile.dispatch(file);
        });

        Application.current.window.onFocusOut.add(function()
        {
            onFocusOut.dispatch();
        });

        Application.current.window.onFocusIn.add(function()
        {
            onFocusIn.dispatch();
        });

        initialized = true;
    }

    /**
     * Clears each signal to prevent duplicates.
     */
    public static function clearSignals()
    {
        onDropFile.removeAll();
        onFocusOut.removeAll();
        onFocusIn.removeAll();
    }

    /**
     * Gets the screen resolution of the monitor the game is currently running in.
     * @return An array, containing the dimensions.
     */
    public static function getScreenResolution():Array<Float>
    {
        return [Application.current.window.display.bounds.width, Application.current.window.display.bounds.height];
    }

    /**
     * Gets the resolution of the current game window.
     * @return An array, containing the dimensions.
     */
    public static function getWindowResolution():Array<Float>
    {
        return [Application.current.window.width, Application.current.window.height];
    }

    /**
     * Positions the window to the given position values.
     * @param _x The target X axis.
     * @param _y The target Y axis.
     */
    public static function positionWindow(_x:Int, _y:Int):Void
    {
        Application.current.window.x = _x;
		Application.current.window.y = _y;
    }

    /**
     * Resizes the game window to given dimensions.
     * @param _width The target width.
     * @param _height The target height.
     */
    public static function resizeWindow(_width:Float, _height:Float):Void
    {
        Application.current.window.width = Std.int(_width);
		Application.current.window.height = Std.int(_height);
    }

    /**
     * Centers the game window to the screen resolution.
     */
    public static function centerWindow():Void
    {
        Application.current.window.x = Std.int((getScreenResolution()[0] - getWindowResolution()[0]) / 2);
		Application.current.window.y = Std.int((getScreenResolution()[1] - getWindowResolution()[1]) / 2);
    }

    /**
     * Displays an error window.
     * @param title The title of the window.
     * @param info The message contents in the window.
     */
    public static function showError(title:String, info:String):Void
    {
        Application.current.window.alert(MessageBoxType.ERROR, info, title);
    }
}
