package game.handlers;

import backend.Controls.DigitalActionDR;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;
import flixel.FlxG;

/**
 * Data structure representing a single input event.
 */
typedef InputEntry =
{
    /**
     * The direction of the input.
     */
    direction:Int
}

/**
 * A class used for handling game inputs. This is mainly used for controlling note inputs.
 * Code based off of Base FNF's "PrecisInputManager" code.
 */
class Inputs
{
    /**
     * Singleton instance of this class.
     */
    public static var instance(get, never):Inputs;

    static function get_instance():Inputs 
    {
        if (_instance == null)
            return _instance = new Inputs();

        return _instance;
    }
    
    private static var _instance:Inputs;

    /**
     * Internal mapping of the raw key codes to their DigitalAction objects.
     */
    private var keyControlList:Map<Int, DigitalActionDR> = new Map<Int, DigitalActionDR>();

    /**
     * Internal mapping of the raw key codes to the strum direction.
     */
    private var keyDirList:Map<Int, Int> = new Map<Int, Int>();

    /**
     * Tracks which keys are held to prevent duplicate inputs.
     */
    private var keysHeld:Map<Int, Bool> = new Map<Int, Bool>();

    /**
     * Signal dispatched when a valid key is pressed.
     */
    public var onInputPressed:FlxTypedSignal<InputEntry->Void> = new FlxTypedSignal<InputEntry->Void>();

    /**
     * Signal dispatched when a valid key is released.
     */
    public var onInputReleased:FlxTypedSignal<InputEntry->Void> = new FlxTypedSignal<InputEntry->Void>();

    /**
     * Attaches OpenFL keyboard listeners.
     */
    public function new()
    {
        FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
        FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
    }
    
    /**
     * Configures the control system for a specific key count.
     * @param count The number of keys.
     */
    public function setup(count:Int)
    {
        var binds:Dynamic = Reflect.field(Configs, "NOTE_BINDS_" + count + "K");

        if (binds == null)
        {
            trace('No note binds found for ${count}K. Input setup skipped.', "WARNING");
            return;
        }

        Controls.instance.setupNoteBinds(binds);
        initialize();
    }

    /**
     * Rebuilds the internal maps based on the current configuration.
     */
    private function initialize()
    {
        keyControlList.clear();
        keyDirList.clear();
        keysHeld.clear();

        for (i in 0...Controls.instance.noteControlList.length)
        {
            var dir:DigitalActionDR = Controls.instance.noteControlList[i];
            var dirKeys:Array<Int> = getKeysForDirection(i);

            for (key in dirKeys)
            {
                keyDirList.set(key, i);
                keyControlList.set(key, dir);
                keysHeld.set(key, false);
            }
        }
    }

    /**
     * Called when a key is pressed down.
     * @param e The `KeyboardEvent` defined by the event listener.
     */
    private function onKeyDown(e:KeyboardEvent)
    {
        var key:Int = e.keyCode;

        if (!keyDirList.exists(key) || keysHeld.get(key) == true) return;
        keysHeld.set(key, true);

        var direction:Int = getDirectionByKey(key);
        onInputPressed.dispatch({ direction: direction });
    }

    /**
     * Called when a key is released.
     * @param e The `KeyboardEvent` defined by the event listener.
     */
    private function onKeyUp(e:KeyboardEvent)
    {
        var key:Int = e.keyCode;

        if (keyDirList.exists(key))
        {
            keysHeld.set(key, false);

            var direction:Int = getDirectionByKey(key);
            onInputReleased.dispatch({ direction: direction });
        }
    }
    
    /**
     * Retrieves the raw key IDs associated with a specific direction.
     */
    private function getKeysForDirection(direction:Int):Array<Int>
    {
        return Controls.instance.noteControlList[direction].getInputs();
    }

    /**
     * Looks up the action object mapped to a specific key.
     */
    private function getActionByKey(key:Int):DigitalActionDR
    {
        return keyControlList.get(key);
    }

    /**
     * Looks up a key direction index mapped to a specific key.
     */
    private function getDirectionByKey(key:Int):Int
    {
        return keyDirList.get(key);
    }

    /**
     * Cleans up event and signal listeners
     */
    public function destroy()
    {
        FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyUp);
        FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
        onInputPressed.removeAll();
        onInputReleased.removeAll();

        keyControlList.clear();
        keyDirList.clear();
        keysHeld.clear();

        if (_instance == this)
            _instance = null;
    }
}