package backend.converters.type;

import haxe.Json;

import backend.registries.song.ChartRegistry.ChartData;
import backend.registries.song.ChartRegistry.ChartStrumline;
import backend.registries.song.ChartRegistry.ChartNote;
import backend.registries.song.EventRegistry.EventData;
import backend.registries.song.EventRegistry.EventEntry;

import backend.converters.IConverterEntry;

typedef VSliceChartData =
{
    @:optional var version:String;
    @:optional var scrollSpeed:Dynamic;
    @:optional var events:Array<VSliceEventEntry>;

    @:optional var notes:Dynamic;
    @:optional var generatedBy:String;
}

typedef VSliceEventEntry =
{
    @:optional var t:Null<Float>;
    @:optional var e:String;
    @:optional var v:Dynamic;
}

typedef VSliceNoteEntry =
{
    @:optional var t:Null<Float>;
    @:optional var d:Null<Int>;
    @:optional var l:Null<Float>;
    @:optional var k:String;
}

class VSliceConverter implements IConverterEntry
{
    public static var instance(get, never):VSliceConverter;

    static function get_instance():VSliceConverter
    {
        if (_instance == null)
            _instance = new VSliceConverter();
        return _instance;
    }

    static var _instance:VSliceConverter;
    static final DIFFICULTY_KEYS:Array<String> = ["hard", "normal", "easy", "default"];

    public var song:String = "";
    public var difficulty:String = null;

    public function new() {}

    public function detect(data:Dynamic):Bool
    {
        if (data == null) return false;

        if (Reflect.hasField(data, "song")) return false;

        return Reflect.hasField(data, "notes") && Reflect.hasField(data, "scrollSpeed");
    }

    public function listDifficulties(data:Dynamic):Array<String>
    {
        var difficulties:Array<String> = [];

        var notes:Dynamic = (data != null) ? Reflect.field(data, "notes") : null;

        if (notes == null || notes is Array || notes is String)
            return difficulties;

        for (key in Reflect.fields(notes))
        {
            var entry:Dynamic = Reflect.field(notes, key);

            if (entry != null && entry is Array)
                difficulties.push(key);
        }

        difficulties.sort(Reflect.compare);

        return difficulties;
    }

    private function resolveNotes(notes:Dynamic):Array<VSliceNoteEntry>
    {
        if (notes == null) return [];

        if (notes is Array)
            return cast notes;

        if (difficulty != null)
        {
            var entry:Dynamic = Reflect.field(notes, difficulty);

            if (entry != null && entry is Array)
                return cast entry;
        }

        for (key in DIFFICULTY_KEYS)
        {
            var entry:Dynamic = Reflect.field(notes, key);

            if (entry != null && entry is Array)
                return cast entry;
        }

        for (key in Reflect.fields(notes))
        {
            var entry:Dynamic = Reflect.field(notes, key);

            if (entry != null && entry is Array)
                return cast entry;
        }

        return [];
    }

    private function resolveSpeed(scrollSpeed:Dynamic):Float
    {
        if (scrollSpeed != null && scrollSpeed is Float)
        {
            var value:Float = scrollSpeed;
            if (value > 0) return value;
        }
        else if (scrollSpeed != null && !(scrollSpeed is Array) && !(scrollSpeed is String))
        {
            var keys:Array<String> = (difficulty != null) ? [difficulty].concat(DIFFICULTY_KEYS) : DIFFICULTY_KEYS;

            for (key in keys)
            {
                var entry:Dynamic = Reflect.field(scrollSpeed, key);

                if (entry != null && entry is Float)
                {
                    var value:Float = entry;
                    if (value > 0) return value;
                }
            }
        }

        return 1.0;
    }

    private function extractCameraTarget(value:Dynamic):Null<Int>
    {
        if (value == null) return null;

        if (value is Float) return Std.int(value);
        if (value is String) return Std.parseInt(value);

        var char:Dynamic = Reflect.field(value, "char");

        if (char != null)
        {
            if (char is Float) return Std.int(char);
            if (char is String) return Std.parseInt(char);
        }

        return null;
    }

    public function convertChart(data:Dynamic):ChartData
    {
        var chart:VSliceChartData = cast data;

        var chartSpeed:Float = resolveSpeed(chart.scrollSpeed);

        var strum0:ChartStrumline = {id: 0, character: "dad", skin: "default", position: [-364, 53], scale: 1, visible: true, keys: 4, speed: chartSpeed, notes: []};
        var strum1:ChartStrumline = {id: 1, character: "bf", skin: "default", position: [265, 53], scale: 1, visible: true, keys: 4, speed: chartSpeed, notes: []};
        var strum2:ChartStrumline = {id: 2, character: "gf", skin: "default", position: [0, 0], scale: 1, visible: false, keys: 4, speed: chartSpeed, notes: []};

        for (note in resolveNotes(chart.notes))
        {
            if (note == null || note.t == null || note.d == null) continue;

            var rawDir:Int = note.d;
            if (rawDir < 0) continue;

            var length:Float = (note.l != null && note.l > 0) ? note.l : 0.0;

            var chartNote:ChartNote = {time: note.t, direction: rawDir % 4, length: length, kind: note.k ?? "default"};

            var isOpponentNote:Bool = rawDir > 3;

            if (isOpponentNote)
                strum0.notes.push(chartNote);
            else
                strum1.notes.push(chartNote);
        }

        sortNotes(strum0.notes);
        sortNotes(strum1.notes);

        return {strumlines: [strum0, strum1, strum2]};
    }

    public function convertEvents(data:Dynamic):EventData
    {
        var chart:VSliceChartData = cast data;
        var events:Array<EventEntry> = [];

        if (chart.events != null)
        {
            for (ev in chart.events)
            {
                if (ev == null || ev.e == null) continue;

                var eventName:String = ev.e;
                var time:Float = ev.t ?? 0.0;
                var vars:Array<String> = [];

                if (eventName == "FocusCamera")
                {
                    eventName = "Camera Movement";

                    var target:Null<Int> = extractCameraTarget(ev.v);
                    var mapped:Int = (target == null) ? 1 : switch (target)
                    {
                        case 0: 1;
                        case 1: 0;
                        default: target;
                    };

                    vars.push(Std.string(mapped));
                }
                else if (ev.v != null)
                {
                    vars.push((ev.v is String) ? (ev.v : String) : Json.stringify(ev.v));
                }

                events.push({name: eventName, time: time, variables: vars});
            }
        }

        events.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));

        return {events: events};
    }

    public function revertChart(data:ChartData, ?eventData:EventData):Dynamic
    {
        var chartSpeed:Float = 1.0;

        if (data != null && data.strumlines != null && data.strumlines.length > 0 && data.strumlines[0] != null && data.strumlines[0].speed != null)
            chartSpeed = data.strumlines[0].speed;

        var vNotes:Array<VSliceNoteEntry> = [];

        if (data != null && data.strumlines != null)
        {
            for (strumline in data.strumlines)
            {
                if (strumline == null || strumline.notes == null) continue;

                var isPlayer:Bool = (strumline.id == 1);

                for (note in strumline.notes)
                {
                    if (note == null) continue;

                    var dir:Int = (note.direction ?? 0) % 4;
                    if (!isPlayer) dir += 4;

                    var vNote:VSliceNoteEntry = {t: note.time ?? 0.0, d: dir};

                    if (note.length != null && note.length > 0)
                        vNote.l = note.length;

                    if (note.kind != null && note.kind != "default")
                        vNote.k = note.kind;

                    vNotes.push(vNote);
                }
            }
        }

        vNotes.sort(function(a, b) return a.t < b.t ? -1 : (a.t > b.t ? 1 : 0));

        var vEvents:Array<VSliceEventEntry> = [];

        if (eventData != null && eventData.events != null)
        {
            for (ev in eventData.events)
            {
                if (ev == null || ev.name == null) continue;

                var vName:String = ev.name;
                var vVal:Dynamic = (ev.variables != null && ev.variables.length > 0) ? ev.variables[0] : null;

                if (ev.name == "Camera Movement")
                {
                    vName = "FocusCamera";

                    var parsed:Null<Int> = (vVal != null) ? Std.parseInt(Std.string(vVal)) : null;
                    var char:Int = (parsed == null) ? 0 : switch (parsed)
                    {
                        case 0: 1;
                        case 1: 0;
                        default: parsed;
                    };

                    vVal = {char: char};
                }

                vEvents.push({t: ev.time ?? 0.0, e: vName, v: vVal});
            }
        }

        vEvents.sort(function(a, b) return a.t < b.t ? -1 : (a.t > b.t ? 1 : 0));

        return
        {
            version: "2.0.0",
            scrollSpeed: {easy: chartSpeed, normal: chartSpeed, hard: chartSpeed},
            events: vEvents,
            notes: {easy: [], normal: [], hard: vNotes},
            generatedBy: "RevEngine V-Slice Converter - v" + Constants.VERSION_STRING
        };
    }

    public function revertEvents(data:EventData):Dynamic
    {
        return
        {
            version: "2.0.0",
            scrollSpeed: {easy: 1.0, normal: 1.0, hard: 1.0},
            events: [],
            notes: {easy: [], normal: [], hard: []},
            generatedBy: "RevEngine V-Slice Converter - v" + Constants.VERSION_STRING
        };
    }

    public function write(data:Dynamic):String
    {
        return Json.stringify(data, null, "\t");
    }

    private static function sortNotes(notes:Array<ChartNote>):Void
    {
        notes.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
    }
}
