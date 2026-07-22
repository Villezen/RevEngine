package menus.charting;

import backend.registries.song.EventRegistry.EventEntry;

class CharterEvent
{
    public var name:String;
    public var time:Float;
    public var variables:Array<String>;

    public function new(name:String, time:Float, ?variables:Array<String>)
    {
        this.name = (name != null) ? name : "";
        this.time = time;
        this.variables = (variables != null) ? variables : [];
    }

    public function clone():CharterEvent
    {
        return new CharterEvent(name, time, variables.copy());
    }

    public function toEntry():EventEntry
    {
        return {name: name, time: time, variables: variables.copy()};
    }

    public static function fromEntry(entry:EventEntry):CharterEvent
    {
        if (entry == null) return new CharterEvent("Invalid Event", 0.0);

        var variables:Array<String> = [];

        if (entry.variables != null)
            for (variable in entry.variables) variables.push(variable);

        return new CharterEvent(entry.name ?? "", entry.time ?? 0.0, variables);
    }

    public static function compare(a:CharterEvent, b:CharterEvent):Int
    {
        if (a.time < b.time) return -1;
        if (a.time > b.time) return 1;

        return 0;
    }

    public function toString():String
    {
        return 'CharterEvent(name: $name, time: $time, variables: $variables)';
    }
}
