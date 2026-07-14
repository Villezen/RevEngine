package backend.modding.handlers;

import backend.modding.classes.ScriptedTransition;
import backend.transition.Transition;

/**
 * This class manages each external transition script in the mod.
 */
class TransitionHandler
{
    public static var list:Map<String, String> = [];

    /**
     * Reads every working script that extends `ScriptedTransition` and adds its class name to the list.
     */
    public static function load():Void
    {
        list.clear();
        var scriptClass:Dynamic = ScriptedTransition;
        var transitionClasses:Array<String> = scriptClass.listScriptClasses();

        for (transEntry in transitionClasses)
        {
            var trans:Transition = scriptClass.scriptInit(transEntry);

            if (trans != null)
                list.set(trans.alias, transEntry);
        }
    }

    /**
     * Tries to fetch a working transition script and creates a FRESH instance of it.
     */
    public static function spawn(alias:String):Transition
    {
        var transEntry = list.get(alias);
        
        if (transEntry != null)
        {
            var scriptClass:Dynamic = ScriptedTransition;
            return scriptClass.scriptInit(transEntry);
        }

        return null;
    }
}