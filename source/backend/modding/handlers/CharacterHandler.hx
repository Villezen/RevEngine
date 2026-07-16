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
    public static var scripts:Map<String, String> = [];

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
            {
                list.set(char.id, char);
                scripts.set(char.id, charEntry);
            }
        }
    }

    /**
     * Returns a character's instance that owns the given name, building it if it doesn't exist yet.
     * @param name The character's identifier.
     */
    public static function resolve(name:String):Character
    {
        var char:Character = list.get(name);

        if (char != null)
            return char;

        var entry:String = scripts.get(name);

        if (entry != null)
        {
            var scriptClass:Dynamic = ScriptedCharacter;
            char = scriptClass.scriptInit(entry);
        }

        if (char == null)
            char = new Character(name);

        list.set(name, char);

        return char;
    }

    /**
     * Spawns the character owning the given name on the given position.
     * @return The character, or `null` if its name is already loaded somewhere else.
     */
    public static function spawn(x:Int, y:Int, params:CharacterParams):Null<Character>
    {
        var char:Character = resolve(params.name);

        if (char.params != null)
        {
            trace('Could not spawn ${params.name}: it is already loaded on another character.', "WARNING");
            return null;
        }

        char.init(x, y, params);

        return char;
    }

    /**
     * Whether the given character has an external script.
     * @param char The character to check.
     */
    public static function isScripted(char:Character):Bool
    {
        return char != null && Std.isOfType(char, ScriptedCharacter);
    }

    /**
     * Whether the character under the given name has an external script.
     * @param name The character's identifier.
     */
    public static function hasScript(name:String):Bool
    {
        return scripts.exists(name);
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

        scripts.clear();
    }
}