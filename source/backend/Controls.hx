package backend;

import flixel.input.actions.FlxActionInput;
import flixel.input.actions.FlxAction;
import flixel.input.FlxInput.FlxInputState;
import flixel.input.keyboard.FlxKey;
import flixel.input.actions.FlxAction.FlxActionDigital;
import flixel.input.actions.FlxActionSet;

/**
 * An abstract enum representing all the input actions available.
 */
enum abstract Action(String) from String to String
{
    var back = 'back';
    var accept = 'accept';

    var ui_left = 'ui_left';
    var ui_down = 'ui_down';
    var ui_up = 'ui_up';
    var ui_right = 'ui_right';
}

/**
 * Main input manager.
 */
class Controls extends FlxActionSet
{
    /**
     * Singleton instance of this current class,
     */
    public static var instance(get, null):Controls;

    static function get_instance():Controls {
        if (_instance == null) {
            _instance = new Controls();
        }
        return _instance;
    }

    static var _instance:Controls = null;

    /**
     * A list of active digital actions for the notes in-game. Will vary depending on the key count.
     */
    public var noteControlList:Array<DigitalActionDR> = [];

    /**
     * Input actions, taken from the Action enum.
     */
    public var BACK(default, null):DigitalActionDR = new DigitalActionDR(back);
    public var ACCEPT(default, null):DigitalActionDR = new DigitalActionDR(accept);

    public var UI_LEFT(default, null):DigitalActionDR = new DigitalActionDR(ui_left);
    public var UI_DOWN(default, null):DigitalActionDR = new DigitalActionDR(ui_down);
    public var UI_UP(default, null):DigitalActionDR = new DigitalActionDR(ui_up);
    public var UI_RIGHT(default, null):DigitalActionDR = new DigitalActionDR(ui_right);

    /**
     * Internal map used to lookup actions by using a string.
     */
    var byName:Map<Action, DigitalActionDR> = [];

    public function new()
    {
        super('controls');
        reloadKeybinds();
    }

    /**
     * Configures keybindings for the note lanes.
     * @param binds An array of keys, taken from the Config class.
     */
    public function setupNoteBinds(binds:Array<Dynamic>):Void
    {
        for (action in noteControlList)
        {
            remove(action);
            byName.remove(action.name);
        }
        noteControlList = [];

        for (i in 0...binds.length)
        {
            var noteName:Action = cast 'note_$i';
            var noteAction = new DigitalActionDR(noteName);
            
            add(noteAction);
            noteControlList.push(noteAction);

            var primaryKey:FlxKey = cast(binds[i][0], FlxKey);
            var secondaryKey:FlxKey = cast(binds[i][1], FlxKey);

            forEachAction(noteName, function(digital:FlxActionDigital, state:FlxInputState)
            {
                if (primaryKey != FlxKey.NONE) digital.addKey(primaryKey, state);
                if (secondaryKey != FlxKey.NONE) digital.addKey(secondaryKey, state);
            });
        }
    }

    /**
     * Loads any other keybindings from the Configs class that isn't note related.
     */
    public function loadKeybinds()
    {
        var controlsMap:Map<Action, Array<Dynamic>> =
        [
            back => Configs.BACK_BIND,
            accept => Configs.ACCEPT_BIND,
            
            ui_left => Configs.UI_BINDS[0],
            ui_down => Configs.UI_BINDS[1],
            ui_up => Configs.UI_BINDS[2],
            ui_right => Configs.UI_BINDS[3]
        ];

        for (name in byName.keys()) 
        {
            if (StringTools.startsWith(name, "note_")) continue;

            forEachAction(name, function(digital:FlxActionDigital, state:FlxInputState)
            {
                var keys:Array<Dynamic> = controlsMap[name];
                
                if (keys != null)
                {
                    for (i in 0...keys.length)
                    {
                        var key:FlxKey = cast(keys[i], FlxKey);
                        if (key != FlxKey.NONE)
                        {
                            digital.addKey(key, state);
                        }
                    }
                }
            });
        }
    }

    /**
     * Resets the action map and re-initializes all keybindings. 
     */
    public function reloadKeybinds()
    {
        byName.clear();

        for (control in [BACK, ACCEPT, UI_LEFT, UI_DOWN, UI_UP, UI_RIGHT]) 
            add(control);

        loadKeybinds();
    }

    /**
     * Helper function to apply a logic function across all possible input states 
     */
    public function forEachAction(actionName:Action, func:FlxActionDigital->FlxInputState->Void)
    {
        var action:FlxActionDigital = byName[actionName];
        func(action, RELEASED);
        func(action, PRESSED);
        func(action, JUST_PRESSED);
        func(action, JUST_RELEASED);
    }

    /**
     * Registers an action to the set and tracks it in the internal map.
     */
    public override function add(action:FlxAction):Bool
    {
        var drAction:DigitalActionDR = cast action;
        byName[cast action.name] = drAction;
        return super.add(action);
    }
}

/**
 * A DigitalAction used for DR. 
 * This contains filter checking, and properties for checking the state of a control.
 */
class DigitalActionDR extends FlxActionDigital
{
    /**
     * Whether this digital action is currently being held down by a player.
     */
    public var pressed(get, null):Bool;
    
    function get_pressed():Bool
        return filterCheck(PRESSED);

    /**
     * Whether this digital action is released by a player.
     */
    public var released(get, null):Bool;
    
    function get_released():Bool
        return filterCheck(RELEASED);
    
    /**
     * Whether this digital action was just pressed by a player.
     */
    public var justPressed(get, null):Bool;
    
    function get_justPressed():Bool
        return filterCheck(JUST_PRESSED);
    
    /**
     * Whether this digital action was just released by a player.
     */
    public var justReleased(get, null):Bool;

    function get_justReleased():Bool
        return filterCheck(JUST_RELEASED);

    /**
     * Stores the cache for all of the inputs, including whether this action was triggered, and the timestamp at which it happened.
     */
    var inputCache:Map<String, {timestamp:Int, triggered:Bool}> = [];

    public function filterCheck(?filteredState:FlxInputState)
    {
        var filterKey = '$filteredState';
        var entry = inputCache.get(filterKey);

        if (entry != null && entry.timestamp == FlxG.game.ticks) {
            return entry.triggered;
        }

        if (inputs == null || inputs.length == 0) return false;

        var filteredInputs = inputs.filter(function(action:FlxActionInput) {
            return (filteredState == null || action.trigger == filteredState);
        });

        var result = false;
		for (i in 0...filteredInputs.length)
		{
			var j = filteredInputs.length - i - 1;
			var input = filteredInputs[j];

			if (input.destroyed)
			{
				inputs.splice(j, 1);
				continue;
			}

			input.update();

			if (input.check(this))
			{
				result = true;
			}
		}

        inputCache.set(filterKey, {timestamp: Std.int(FlxG.game.ticks), triggered: result});
        
		return result;
    }
    
    /**
     * Returns a list of keys for this action.
     * @return an Array<Int> that's a list of the keys for this action. Normally, a list of 'FlxKey'. 
     */
    public function getInputs():Array<Int>
    {
        var list:Array<Int> = new Array<Int>();
		for (input in inputs) 
        {
            list.push(input.inputID);
        }
        return list;
    }
}