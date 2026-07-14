package backend.modding.handlers;

import backend.modding.classes.ScriptedStage;
import game.world.Stage;
import backend.modding.events.ScriptEvent;
import backend.modding.events.ScriptEventDispatcher;

/**
 * This class manages each external stage script in the state.
 */
class StageHandler
{
    public static var list:Map<String, Stage> = [];

    /**
     * Reads every working script that extends `ScriptedStage` and adds it to the list.
     */
    public static function load():Void
    {
        clear();

        var scriptClass:Dynamic = ScriptedStage;
        var stageClasses:Array<String> = scriptClass.listScriptClasses();

        for (stageEntry in stageClasses)
        {
            var stage:Stage = scriptClass.scriptInit(stageEntry);

            if (stage != null)
                list.set(stage.id, stage);
        }
    }

    /**
     * Tries to fetch a working stage script and returns a normal stage instance if nothing is found.
     */
    public static function spawn(id:String):Stage
    {
        var stage:Stage = list.get(id);

        if (stage == null)
            stage = new Stage(id);
        
        return stage;
    }

    /**
     * Calls an event to a given script ID.
     * @param id The stage script's identifier.
     * @param event The scripted event.
     */
    public static function call(id:String, event:ScriptEvent):Void
    {
        ScriptEventDispatcher.call(get(id), event);
    }

    /**
     * Gets another script's data. Primarily used by other scripts to access eachother.
     * @param id The stage script's identifier.
     * @return A chraracter class.
     */
    public static function get(id:String):Stage
    {
        return list.get(id) ?? null;
    }

    /**
     * Clears every loaded script and calls their respective functions.
     */
    public static function clear():Void
    {
        if (list != null)
        {
            var event = new ScriptEvent(DESTROY, false);

            for (char in list)
                ScriptEventDispatcher.call(char, event);

            list.clear();
        }
    }
}