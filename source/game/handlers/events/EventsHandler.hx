package game.handlers.events;

import backend.registries.song.EventRegistry;

import flixel.util.FlxSignal.FlxTypedSignal;

import flixel.FlxBasic;

import flixel.util.FlxSort;

/**
 * An instance handler used for initalizing events, handling them, etc.
 */
class EventsHandler extends FlxBasic
{
    /**
     * Signal dispatched when an event has been fired.
     */
    public var onExecution(default, null):FlxTypedSignal<Event->Void> = new FlxTypedSignal<Event->Void>();

    /**
     * The name of the song.
     */
    public var name:String = "";

    /**
     * List of the events that are still waiting to be triggered.
     */
    public var events:Array<Event> = [];

    /**
     * Initializes the handler and retrieves the list of events to trigger.
     * @param name The name of the song.
     */
    public function new(name:String)
    {
        super();

        this.name = name;

        var data = EventRegistry.get(name);

        if (data != null && data.events != null)
        {
            for (entry in data.events)
            {
                if (entry == null) continue;

                events.push(new Event(entry));
            }
        }

        events.sort(function(a, b) return FlxSort.byValues(FlxSort.ASCENDING, a.time, b.time));
    }

    /**
     * Update function that fires every event whose time has been reached.
     */
    public override function update(elapsed:Float)
    {
        if (Conductor.instance == null) 
            return;

        while (events.length > 0 && events[0] != null && events[0].time <= Conductor.instance.songPosition)
            onExecution.dispatch(events.shift());
    }

    /**
     * Cleans up the signal and any pending events.
     */
    public override function destroy():Void
    {
        onExecution.removeAll();
        events.resize(0);

        super.destroy();
    }
}
