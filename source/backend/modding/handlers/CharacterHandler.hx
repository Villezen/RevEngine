package backend.modding.handlers;

import backend.modding.classes.ScriptedCharacter;
import game.world.Character;
import game.world.Character.CharacterParams;
import backend.modding.events.ScriptEvent;
import backend.modding.events.ScriptEventDispatcher;

/**
 * This class manages each external character script in the state.
 */
class CharacterHandler
{
    public static var list:Map<String, Character> = [];

    /**
     * Reads every working script that extends `ScriptedCharacter` and adds it to the list.
     */
    public static function load():Void
    {
        clear();

        var scriptClass:Dynamic = ScriptedCharacter;
        var characterClasses:Array<String> = scriptClass.listScriptClasses();

        for (charEntry in characterClasses)
        {
            var char:Character = scriptClass.scriptInit(charEntry);

            if (char != null)
                list.set(char.id, char);
        }
    }

    /**
     * Tries to fetch a working character script and returns a normal character instance if nothing is found.
     */
    public static function spawn(x:Int, y:Int, params:CharacterParams):Character
    {
        var char:Character = list.get(params.name);

        if (char == null)
        {
            char = new Character(params.name);
            list.set(params.name, char); 
        }

        char.init(x, y, params);
        
        return char;
    }

    /**
     * Calls an event to a given script ID.
     * @param id The character script's identifier.
     * @param event The scripted event.
     */
    public static function call(id:String, event:ScriptEvent):Void
    {
        ScriptEventDispatcher.call(get(id), event);
    }

    /**
     * Gets another script's data. Primarily used by other scripts to access eachother.
     * @param id The character script's identifier.
     * @return A chraracter class.
     */
    public static function get(id:String):Character
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