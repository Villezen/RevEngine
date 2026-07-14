package backend.modding;

import backend.modding.classes.ScriptedState;

import polymod.Polymod;
import flixel.FlxState;

/**
 * Helper class used to load any scripted states found in a mod.
 */
class ModState
{
    /**
     * A tracker used to track each scripted state that has been opened to avoid any issues while hot reloading.
     */
    public static var tracker:Map<FlxState, String> = new Map();

    /**
     * Loads and returns a custom scripted state.
     * @param name Name of the class
     * @return A state, ready to be transitioned to.
     */
    public static function load(name:String):FlxState
    {
        var scriptClass:Dynamic = ScriptedState;
        var state:ScriptedState = scriptClass.scriptInit(name);
        
        if (state != null)
        {
            tracker.set(state, name);
            return state;
        }

        trace('Could not find/load custom scripted state: ' + name, "ERROR");

        var fallback = new FallbackState();
        tracker.set(fallback, name); 
        
        return fallback;
    }
}