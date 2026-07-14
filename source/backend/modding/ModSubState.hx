package backend.modding;

import backend.modding.classes.ScriptedSubState; 
import flixel.FlxSubState;

/**
 * Helper class used to load any scripted substates found in a mod.
 */
class ModSubState
{
    /**
     * A tracker used to track each scripted substate that has been opened to avoid any issues while hot reloading.
     */
    public static var tracker:Map<FlxSubState, String> = new Map();

    /**
     * Loads and returns a custom scripted substate.
     * @param name Name of the class
     * @return A substate, ready to be opened.
     */
    public static function load(name:String):FlxSubState
    {
        var scriptClass:Dynamic = ScriptedSubState;
        var subState:ScriptedSubState = scriptClass.scriptInit(name);
        
        if (subState != null)
        {
            tracker.set(subState, name);
            return subState;
        }

        trace('Could not find/load custom scripted substate: ' + name, "ERROR");

        var fallback = new FallbackSubState();
        tracker.set(fallback, name); 
        
        return fallback;
    }
}