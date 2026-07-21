package menus.charting;

import backend.registries.song.ChartRegistry.ChartNote;

class CharterNote
{
    public var direction:Int;
    public var time:Float;
    public var sustain:Float;
    public var kind:String;
    public var endTime(get, never):Float;

    inline function get_endTime():Float
    {
        return time + sustain;
    }

    public var isHold(get, never):Bool;

    inline function get_isHold():Bool
    {
        return sustain > 0;
    }

    public function new(direction:Int, time:Float, sustain:Float = 0.0, ?kind:String)
    {
        this.direction = direction;
        this.time = time;
        this.sustain = (sustain > 0) ? sustain : 0.0;
        this.kind = kind ?? "default";
    }

    public function clone():CharterNote
    {
        return new CharterNote(direction, time, sustain, kind);
    }

    public function toData():ChartNote
    {
        return {time: time, direction: direction, length: sustain, kind: kind};
    }

    public static function fromData(data:ChartNote):CharterNote
    {
        return new CharterNote(data.direction, data.time, data.length, data.kind);
    }

    public static function compare(a:CharterNote, b:CharterNote):Int
    {
        if (a.time < b.time) return -1;
        if (a.time > b.time) return 1;

        if (a.direction < b.direction) return -1;
        if (a.direction > b.direction) return 1;

        return 0;
    }

    public function toString():String
    {
        return 'CharterNote(direction: $direction, time: $time, sustain: $sustain)';
    }
}
