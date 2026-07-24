package backend.utils;

import flixel.FlxState;
import flixel.FlxSubState;

#if windows
import backend.platform.windows.WinAPI;
#end

/**
 * A utility class used for provide several functions related to debugging.
 */
class DebugUtil 
{
	/**
	 * Gets the raw name of an FlxState, defaulting to the current one..
	 * @return The name for the FlxState as a String.
	 */
	public static function getStateName(?state:FlxState):String 
	{
		if (state != null) 
			return Type.getClassName(Type.getClass(state));
		
		return Manager.currentScriptedState ?? Manager.currentState ?? '';
	}

	/**
	 * Gets the raw name of the current flixel substate.
	 * @return The raw name for the current flixel substate.
	 */
	public static function getSubStateName(?state:FlxState):String 
	{
		var curState:FlxState = (state ?? FlxG.state);

		if (curState != null && curState.subState != null) 
		{
			return Type.getClassName(Type.getClass(curState.subState));
		}

		return '';
	}

	/**
	 * Prints the current state into the debug console.
	 */
	public static function traceStateName():Void 
	{
		trace('[INFO] CURRENT STATE IS: ${getStateName()}');
	}

	/**
	 * Opens the windows debug console.
	 * @param clear Whether any previous traced lines should be cleared from the console.
	 */
	public static function openWindowsConsole(clear:Bool = false):Void
	{
		#if windows
		if (clear) 
		{
			WinAPI.clearScreen();
			trace('[INFO] CONSOLE CLEARED.\n');
		}

		WinAPI.allocConsole();
		#end
	}
}