package backend.modding.songs;

import backend.modding.events.ScriptEvent;
import backend.modding.handlers.SongEventModuleHandler;
import backend.modding.IScriptedClass;

import flixel.FlxBasic;

import game.PlayState;
import game.notes.Note;

/**
 * A module that gets attached to a song event defined in `data/events` and runs its `execute` function whenever the defined event gets executed.
 */
class SongEventModule implements IScriptedClass
{
    /**
     * A unique identifier of the module. Used so a module can be accessed by another module.
     */
    public var moduleId(default, null):String;

    /**
     * The name of the song event this module belongs to. Has to match the `name` field of the event's JSON file in `data/events`.
     */
    public var eventId(default, null):String;

    /**
     * The priority of the module. Scripts with a higher priority get called before scripts with a lower priority.
     */
    public var priority(default, set):Int = 1000;

    function set_priority(value:Int):Int
    {
        this.priority = value;
        SongEventModuleHandler.reorder();

        return value;
    }

    /**
     * Whether or not the script is currently active. Disabling this variable will prevent them from being called.
     */
    public var active(default, null):Bool = true;

    /**
     * The current PlayState instance so it's easily accessible for scripts.
     */
    var game:PlayState;

    public function new(moduleId:String, eventId:String, priority:Int = 1000)
    {
        this.moduleId = moduleId;
        this.eventId = eventId;
        this.priority = priority;
    }

    /**
     * Further initalizes the SongEventModule before it runs.
     */
    public function initalize():Void
    {
        if (FlxG.state is PlayState)
        {
            game = PlayState.instance;
        }
    }

    /**
     * Applies the event's effect. Gets called whenever the module's defined event is executed.
     * @param event The script event holding the executed event's name, time and variables.
     * @return Whether the event executed successfully.
     */
    public function execute(event:SongEventScriptEvent):Bool
    {
        return true;
    }

    /**
     * GENERAL FUNCTIONS
     */

    public function onScriptEvent(event:ScriptEvent):Void {}

    public function onCreate(event:ScriptEvent):Void {}
    public function onStateCreate(event:ScriptEvent):Void {}
    public function onCreatePost(event:ScriptEvent):Void {}

    public function onUpdate(event:UpdateScriptEvent):Void {}

    public function onDestroy(event:ScriptEvent):Void {}

    public function onMeasureHit(event:ConductorScriptEvent):Void {}
    public function onBeatHit(event:ConductorScriptEvent):Void {}
    public function onStepHit(event:ConductorScriptEvent):Void {}

    public function onSongEvent(event:SongEventScriptEvent):Void {}

    public function onNoteHit(event:NoteHitScriptEvent):Void {}
    public function onPlayerHit(event:NoteHitScriptEvent):Void {}
    public function onOpponentHit(event:NoteHitScriptEvent):Void {}

    public function onPlayerMiss(event:NoteHitScriptEvent):Void {}

    public function onNoteHold(event:SustainHitScriptEvent):Void {}
    public function onPlayerHold(event:SustainHitScriptEvent):Void {}
    public function onOpponentHold(event:SustainHitScriptEvent):Void {}

    public function onCameraMove(event:CharacterScriptEvent):Void {}

    /**
     * Adds an FlxBasic to the state.
     * @param object The object to add
     * @return Newly added object.
     */
    public function add(object:FlxBasic):FlxBasic
        return FlxG.state.add(object);

    /**
     * Required function by Polymod. Returns the module's data.
     * @return A string, containing the module's data.
     */
    public function toString():String
        return 'SongEventModule (moduleId: $moduleId, eventId: $eventId, priority: $priority)';
}
