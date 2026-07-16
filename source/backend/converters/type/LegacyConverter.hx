package backend.converters.type;

import haxe.Json;

import backend.registries.song.ChartRegistry.ChartData;
import backend.registries.song.ChartRegistry.ChartStrumline;
import backend.registries.song.ChartRegistry.ChartNote;
import backend.registries.song.EventRegistry.EventData;
import backend.registries.song.EventRegistry.EventEntry;

import haxe.ds.ArraySort;

import backend.converters.IConverterEntry;

typedef LegacyChartData =
{
    @:optional var song:LegacySongData;
}

typedef LegacySongData =
{
    @:optional var song:String;
    @:optional var bpm:Null<Float>;
    @:optional var player1:String;
    @:optional var player2:String;

    @:optional var speed:Dynamic;
    @:optional var notes:Dynamic;
    
    @:optional var events:Array<Dynamic>;
}

typedef LegacySectionData =
{
    @:optional var sectionNotes:Array<Dynamic>;
    @:optional var mustHitSection:Null<Bool>;
    @:optional var bpm:Null<Float>;
    @:optional var changeBPM:Null<Bool>;
    @:optional var altAnim:Null<Bool>;
    @:optional var lengthInSteps:Null<Int>;
}

private typedef ResolvedSections =
{
    var sections:Array<Dynamic>;
    var difficultyKeyed:Bool;
}

class LegacyConverter implements IConverterEntry
{
    public static var instance(get, never):LegacyConverter;

    static function get_instance():LegacyConverter
    {
        if (_instance == null)
            _instance = new LegacyConverter();
        return _instance;
    }

    static var _instance:LegacyConverter;
    static final DIFFICULTY_KEYS:Array<String> = ["normal", "hard", "easy"];

    public var song:String = "";
    public var difficulty:String = null;

    public function new() {}

    private function getSongData(data:Dynamic):LegacySongData
    {
        if (data == null) return {};

        if (Reflect.hasField(data, "song") && (Reflect.field(data, "song") is String))
            return cast data;

        if (Reflect.hasField(data, "song") && Reflect.isObject(Reflect.field(data, "song")))
            return cast Reflect.field(data, "song");

        return cast data;
    }

    public function detect(data:Dynamic):Bool
    {
        if (data == null) return false;

        var songObj:Dynamic = getSongData(data);
        return songObj != null && (Reflect.hasField(songObj, "player1") || Reflect.hasField(songObj, "player2"));
    }

    public function listDifficulties(data:Dynamic):Array<String>
    {
        var difficulties:Array<String> = [];

        var songData:LegacySongData = getSongData(data);
        var notes:Dynamic = (songData != null) ? songData.notes : null;

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

    private function resolveSections(notes:Dynamic):ResolvedSections
    {
        if (notes == null)
            return {sections: [], difficultyKeyed: false};

        if (notes is Array)
            return {sections: cast notes, difficultyKeyed: false};

        if (difficulty != null && Reflect.hasField(notes, difficulty))
        {
            var entry:Dynamic = Reflect.field(notes, difficulty);
            if (entry != null && entry is Array)
                return {sections: cast entry, difficultyKeyed: true};
        }

        for (key in DIFFICULTY_KEYS)
        {
            if (Reflect.hasField(notes, key))
            {
                var entry:Dynamic = Reflect.field(notes, key);
                if (entry != null && entry is Array)
                    return {sections: cast entry, difficultyKeyed: true};
            }
        }

        for (key in Reflect.fields(notes))
        {
            var entry:Dynamic = Reflect.field(notes, key);
            if (entry != null && entry is Array)
                return {sections: cast entry, difficultyKeyed: true};
        }

        return {sections: [], difficultyKeyed: true};
    }

    private function resolveSpeed(speed:Dynamic):Float
    {
        if (speed != null && speed is Float)
        {
            var value:Float = speed;
            if (value > 0) return value;
        }
        else if (speed != null && !(speed is Array) && !(speed is String))
        {
            var keys:Array<String> = (difficulty != null) ? [difficulty].concat(DIFFICULTY_KEYS) : DIFFICULTY_KEYS;

            for (key in keys)
            {
                var entry:Dynamic = Reflect.field(speed, key);

                if (entry != null && entry is Float)
                {
                    var value:Float = entry;
                    if (value > 0) return value;
                }
            }
        }

        return 1.0;
    }

    public function convertChart(data:Dynamic):ChartData
    {
        var songData:LegacySongData = getSongData(data);
        var chartSpeed:Float = resolveSpeed(songData.speed);

        var p1:String = (songData.player1 != null && songData.player1 != "") ? songData.player1 : "bf";
        var p2:String = (songData.player2 != null && songData.player2 != "") ? songData.player2 : "dad";

        var strum0:ChartStrumline = {id: 0, character: p2, skin: "default", position: [-364, 53], scale: 1, visible: true, keys: 4, speed: chartSpeed, notes: []};
        var strum1:ChartStrumline = {id: 1, character: p1, skin: "default", position: [265, 53], scale: 1, visible: true, keys: 4, speed: chartSpeed, notes: []};
        var strum2:ChartStrumline = {id: 2, character: "gf", skin: "default", position: [0, 0], scale: 1, visible: false, keys: 4, speed: chartSpeed, notes: []};

        for (section in resolveSections(songData.notes).sections)
        {
            if (section == null) continue;

            var sectionNotes:Array<Dynamic> = Reflect.field(section, "sectionNotes");
            if (sectionNotes == null) continue;

            for (note in sectionNotes)
            {
                if (note == null || !(note is Array)) continue;

                var noteData:Array<Dynamic> = cast note;

                if (noteData.length < 2 || !(noteData[0] is Float) || !(noteData[1] is Float || noteData[1] is Int)) continue;

                var time:Float = cast noteData[0];
                var rawDir:Int = Std.int(noteData[1]);

                if (rawDir < 0) continue;

                var length:Float = 0.0;
                if (noteData.length > 2 && noteData[2] != null)
                {
                    if (noteData[2] is Float || noteData[2] is Int)
                        length = cast noteData[2];
                }

                var kind:String = "default";
                if (noteData.length > 3 && noteData[3] is String && noteData[3] != "")
                    kind = cast noteData[3];

                var isPlayerNote:Bool = (rawDir < 4);

                var chartNote:ChartNote = {time: time, direction: rawDir % 4, length: length, kind: kind};

                if (isPlayerNote)
                    strum1.notes.push(chartNote);
                else
                    strum0.notes.push(chartNote);
            }
        }

        sortNotes(strum0.notes);
        sortNotes(strum1.notes);

        return {strumlines: [strum0, strum1, strum2]};
    }

    public function convertEvents(data:Dynamic):EventData
    {
        var songData:LegacySongData = getSongData(data);
        var resolved:ResolvedSections = resolveSections(songData.notes);
        var events:Array<EventEntry> = [];

        var currentTime:Float = 0.0;
        var currentBpm:Float = (songData.bpm != null && songData.bpm > 0) ? songData.bpm : 100.0;
        var lastFocus:String = null;

        for (section in resolved.sections)
        {
            if (section == null) continue;

            var changeBPM:Bool = false;
            
            if (Reflect.hasField(section, "changeBPM"))
                changeBPM = Reflect.field(section, "changeBPM") == true;

            if (changeBPM && Reflect.hasField(section, "bpm"))
            {
                var sectBpm:Float = Reflect.field(section, "bpm");
                if (sectBpm > 0 && sectBpm != currentBpm)
                {
                    currentBpm = sectBpm;
                    events.push({name: "BPM Change", time: currentTime, variables: [Std.string(currentBpm)]});
                }
            }

            var mustHit:Bool = false;
            if (Reflect.hasField(section, "mustHitSection"))
            {
                var val:Dynamic = Reflect.field(section, "mustHitSection");
                mustHit = (val == true || val == "true");
            }

            var cameraFocus:String = mustHit ? "1" : "0";

            if (cameraFocus != lastFocus)
            {
                events.push({name: "Camera Movement", time: currentTime, variables: [cameraFocus]});
                lastFocus = cameraFocus;
            }

            var steps:Int = 16;
            if (Reflect.hasField(section, "lengthInSteps"))
            {
                var l:Null<Int> = Reflect.field(section, "lengthInSteps");
                if (l != null && l > 0) steps = l;
            }

            currentTime += steps * Conductor.instance.getStepLengthMsOf(currentBpm);
        }

        convertLegacyEvents(songData, resolved, events);
        sortEvents(events);

        return {events: events};
    }

    private function convertLegacyEvents(songData:LegacySongData, resolved:ResolvedSections, events:Array<EventEntry>):Void
    {
        var raw:Array<Dynamic> = songData.events;

        if (raw == null)
        {
            raw = [];

            for (section in resolved.sections)
            {
                if (section == null) continue;

                var sectionNotes:Array<Dynamic> = Reflect.field(section, "sectionNotes");
                if (sectionNotes == null) continue;

                for (note in sectionNotes)
                {
                    if (note == null || !(note is Array)) continue;

                    var noteData:Array<Dynamic> = cast note;

                    if (noteData.length < 5 || !(noteData[0] is Float)) continue;
                    if (!(noteData[1] is Float || noteData[1] is Int) || Std.int(noteData[1]) >= 0) continue;

                    raw.push([noteData[0], [[noteData[2], noteData[3], noteData[4]]]]);
                }
            }
        }

        for (entry in raw)
        {
            if (entry == null || !(entry is Array)) continue;

            var pair:Array<Dynamic> = cast entry;

            if (pair.length < 2 || !(pair[0] is Float) || !(pair[1] is Array)) continue;

            var time:Float = cast pair[0];
            var group:Array<Dynamic> = cast pair[1];

            for (sub in group)
            {
                if (sub == null || !(sub is Array)) continue;

                var values:Array<Dynamic> = cast sub;

                if (values.length < 1 || !(values[0] is String)) continue;

                var converted:EventEntry = convertLegacyEvent(cast values[0], time, values);

                if (converted != null)
                    events.push(converted);
            }
        }
    }

    private function convertLegacyEvent(name:String, time:Float, values:Array<Dynamic>):EventEntry
    {
        var value1:String = (values.length > 1 && values[1] != null) ? Std.string(values[1]) : "";
        var value2:String = (values.length > 2 && values[2] != null) ? Std.string(values[2]) : "";

        switch (name)
        {
            case "Change Character":
                if (value2 == "") return null;

                return {name: Constants.CHANGE_CHARACTER_EVENT, time: time, variables: [Std.string(resolveCharacterTarget(value1)), value2]};

            case "Play Animation":
                if (value1 == "") return null;

                return {name: Constants.PLAY_ANIMATION_EVENT, time: time, variables: [Std.string(resolveAnimationTarget(value2)), value1]};

            default:
                return null;
        }
    }

    private function resolveCharacterTarget(value:String):Int
    {
        var slot:Int = switch (StringTools.trim(value.toLowerCase()))
        {
            case "gf" | "girlfriend": 2;
            case "dad" | "opponent": 1;

            default:
                var parsed:Null<Int> = Std.parseInt(value);
                (parsed != null) ? parsed : 0;
        }

        return switch (slot)
        {
            case 1: 0;
            case 2: 2;
            default: 1;
        }
    }

    private function resolveAnimationTarget(value:String):Int
    {
        return switch (StringTools.trim(value.toLowerCase()))
        {
            case "bf" | "boyfriend": 1;
            case "gf" | "girlfriend": 2;

            default:
                var parsed:Null<Int> = Std.parseInt(value);
                (parsed == 1 || parsed == 2) ? parsed : 0;
        }
    }

    public function revertChart(data:ChartData, ?eventData:EventData):Dynamic
    {
        var chartSpeed:Float = 1.0;

        if (data != null && data.strumlines != null && data.strumlines.length > 0 && data.strumlines[0] != null && data.strumlines[0].speed != null)
            chartSpeed = data.strumlines[0].speed;

        var allNotes:Array<Dynamic> = [];

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
                    if (isPlayer) dir += 4;

                    var legacyNote:Array<Dynamic> = [note.time ?? 0.0, dir, (note.length == null || note.length < 0) ? 0.0 : note.length];
                    if (note.kind != null && note.kind != "default")
                        legacyNote.push(note.kind);

                    allNotes.push(legacyNote);
                }
            }
        }

        allNotes.sort(function(a, b)
        {
            var timeA:Float = a[0];
            var timeB:Float = b[0];
            return timeA < timeB ? -1 : (timeA > timeB ? 1 : 0);
        });

        var singleSection:LegacySectionData = {sectionNotes: allNotes, mustHitSection: false, bpm: 100.0, changeBPM: false, altAnim: false, lengthInSteps: 16};

        var legacyData:LegacySongData =
        {
            song: song != "" ? song : "Unknown",
            bpm: 100.0,
            player1: "bf",
            player2: "dad",
            speed: chartSpeed,
            notes: [singleSection]
        };

        return {song: legacyData};
    }

    public function revertEvents(data:EventData):Dynamic
    {
        return
        {
            song:
            {
                song: song,
                bpm: 100.0,
                player1: "bf",
                player2: "dad",
                speed: 1.0,
                notes: []
            }
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

    private static function sortEvents(events:Array<EventEntry>):Void
    {
        ArraySort.sort(events, function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
    }
}