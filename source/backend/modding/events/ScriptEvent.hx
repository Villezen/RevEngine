package backend.modding.events;

import game.notes.Note;
import game.notes.SustainNote;
import game.world.Character;

/**
 * This is a base class for all events that are issued to scripted classes.
 */
@:nullSafety
class ScriptEvent
{
    /**
     * Can the event get cancelled?
     */
    public var cancelable(default, null):Bool;

    /**
     * Is the event cancelled?
     */
    public var cancelled(default, null):Bool;

    /**
     * The type of the event. The value specified decides which function's gonna get called.
     */
    public var type(default, null):ScriptEventType;

    /**
     * Whether the event should continue to be triggered on additional targets.
     */
    public var shouldPropagate(default, null):Bool;

    /**
     * Sets up the script event with the specified values.
     */
    public function new(type:ScriptEventType, cancelable:Bool = false)
    {
        this.type = type;
        this.cancelable = cancelable;

        cancelled = false;
        shouldPropagate = true;
    }

    /**
     * Cancels the called script.
     */
    public function cancel()
    {
        if (cancelable)
            cancelled = true;
    }

    /**
     * Stops an event from propagating.
     */
    public function stopPropagation()
    {
        shouldPropagate = false;
    }

    /**
     * Returns info about the script event in a string form.
     */
    public function toString()
    {
        return 'Script Event (type: $type, cancelable: $cancelable)';
    }
}

/**
 * A class that's being extended by the base script event. Used to give arguments to the `UPDATE` functins.
 */
class UpdateScriptEvent extends ScriptEvent
{
    public var elapsed(default, null):Float;

    public function new(elapsed:Float):Void
    {
        super(UPDATE, false);
        this.elapsed = elapsed;
    }

    public override function toString()
    {
        return 'Update Script Event (elapsed: $elapsed)';
    }
}

/**
 * A class that's being extended by the base script event. Used to give arguments to note hit functins.
 */
class NoteHitScriptEvent extends ScriptEvent
{
    public var note(default, null):Note;
    public var strumGlow(default, null):Bool;
    public var strumResetTimer(default, null):Int;
    public var showRating(default, null):Bool;
    public var showSplashes(default, null):Bool;

    public function new(type:ScriptEventType, note:Note, strumResetTimer:Int, strumGlow:Bool, showRating:Bool, showSplashes:Bool):Void
    {
        super(type, true);

        this.note = note;
        this.strumGlow = strumGlow;
        this.showRating = showRating;
        this.strumResetTimer = strumResetTimer;
        this.showSplashes = showSplashes;
    }

    public override function toString()
    {
        return 'Note Hit Script Event (note: $note, strumGlow: $strumGlow, showRating: $showRating, strumResetTimer: $strumResetTimer, showSplashes: $showSplashes)';
    }
}

/**
 * A class that's being extended by the base script event. Used to give arguments to sustain hit functins.
 */
class SustainHitScriptEvent extends ScriptEvent
{
    public var sustain(default, null):SustainNote;
    public var strumGlow(default, null):Bool;
    public var showCover(default, null):Bool;

    public function new(type:ScriptEventType, sustain:SustainNote, strumGlow:Bool, showCover:Bool):Void
    {
        super(type, true);

        this.sustain = sustain;
        this.strumGlow = strumGlow;
        this.showCover = showCover;
    }

    public override function toString()
    {
        return 'Sustain Hit Script Event (sustain: $sustain, strumGlow: $strumGlow, showCover: $showCover)';
    }
}

/**
 * A class that's being extended by the base script event. Used to give arguments to Conductor functions.
 */
class ConductorScriptEvent extends ScriptEvent
{
    public var step(default, null):Float;
    public var beat(default, null):Float;
    public var measure(default, null):Float;
    
    public function new(type:ScriptEventType, step:Float, beat:Float, measure:Float)
    {
        super(type, true);

        this.step = step;
        this.beat = beat;
        this.measure = measure;
    }
    
    override function toString():String
    {
        return 'Conductor Script Event (type: $type, step: $step, beat: $beat, measure: $measure)';
    }
}

/**
 * A class that's being extended by the base script event. Used to give arguments to character functions.
 */
class CharacterScriptEvent extends ScriptEvent
{
    public var character(default, null):Character;

    public function new(type:ScriptEventType, character:Character):Void
    {
        super(type, true);
        this.character = character;
    }

    public override function toString()
    {
        return 'Character Script Event (character: $character)';
    }
}

/**
 * A class that's being extended by the base script event. Used to give arguments to song event functions.
 */
class SongEventScriptEvent extends ScriptEvent
{
    public var name(default, null):String;
    public var time(default, null):Float;
    public var variables(default, null):Array<Dynamic>;

    public function new(name:String, time:Float, variables:Array<Dynamic>):Void
    {
        super(SONG_EVENT, true);

        this.name = name;
        this.time = time;
        this.variables = variables;
    }

    public override function toString()
    {
        return 'Song Event Script Event (name: $name, time: $time, variables: $variables)';
    }
}