package game.handlers.events;

import backend.registries.song.EventRegistry.EventEntry;

/**
 * Holds the parsed data of a single chart event (name, time and variables).
 */
class Event
{
    /**
     * The name of the event.
     */
    public var name:String = "";

    /**
     * The song position (in milliseconds) the event fires at.
     */
    public var time:Float = 0;

    /**
     * The raw parameters of the event.
     */
    public var variables:Array<Dynamic> = [];

    public function new(entry:EventEntry)
    {
        if (entry == null) return;

        this.name = entry.name ?? "";
        this.time = entry.time ?? 0.0;
        this.variables = entry.variables ?? [];
    }
}
