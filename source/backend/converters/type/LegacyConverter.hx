package backend.converters.type;

import haxe.Json;

import backend.registries.song.ChartRegistry.ChartData;
import backend.registries.song.ChartRegistry.ChartStrumline;
import backend.registries.song.ChartRegistry.ChartNote;
import backend.registries.song.EventRegistry.EventData;
import backend.registries.song.EventRegistry.EventEntry;

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
    var sections:Array<LegacySectionData>;
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

    public function detect(data:Dynamic):Bool
    {
        if (data == null || !Reflect.hasField(data, "song"))
            return false;

        var songData:Dynamic = Reflect.field(data, "song");

        return songData != null && (Reflect.hasField(songData, "player1") || Reflect.hasField(songData, "player2"));
    }

    public function listDifficulties(data:Dynamic):Array<String>
    {
        var difficulties:Array<String> = [];

        var songData:Dynamic = (data != null) ? Reflect.field(data, "song") : null;
        var notes:Dynamic = (songData != null) ? Reflect.field(songData, "notes") : null;

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

        if (difficulty != null)
        {
            var entry:Dynamic = Reflect.field(notes, difficulty);

            if (entry != null && entry is Array)
                return {sections: cast entry, difficultyKeyed: true};
        }

        for (key in DIFFICULTY_KEYS)
        {
            var entry:Dynamic = Reflect.field(notes, key);

            if (entry != null && entry is Array)
                return {sections: cast entry, difficultyKeyed: true};
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
        var chart:LegacyChartData = cast data;
        var songData:LegacySongData = chart.song ?? {};

        var chartSpeed:Float = resolveSpeed(songData.speed);

        var strum0:ChartStrumline = {id: 0, character: songData.player2 ?? "dad", skin: "default", position: [-364, 53], scale: 1, visible: true, keys: 4, speed: chartSpeed, notes: []};
        var strum1:ChartStrumline = {id: 1, character: songData.player1 ?? "bf", skin: "default", position: [265, 53], scale: 1, visible: true, keys: 4, speed: chartSpeed, notes: []};
        var strum2:ChartStrumline = {id: 2, character: "gf", skin: "default", position: [0, 0], scale: 1, visible: false, keys: 4, speed: chartSpeed, notes: []};

        for (section in resolveSections(songData.notes).sections)
        {
            if (section == null || section.sectionNotes == null) continue;

            var mustHit:Bool = section.mustHitSection ?? false;

            for (note in section.sectionNotes)
            {
                if (note == null || !(note is Array)) continue;

                var noteData:Array<Dynamic> = cast note;

                if (noteData.length < 2 || !(noteData[0] is Float) || !(noteData[1] is Float)) continue;

                var time:Float = noteData[0];
                var rawDir:Int = Std.int(noteData[1]);

                if (rawDir < 0) continue;

                var length:Float = (noteData.length > 2 && noteData[2] != null && noteData[2] is Float) ? noteData[2] : 0.0;

                var kind:String = "default";
                if (noteData.length > 3 && noteData[3] is String)
                    kind = noteData[3];

                var isPlayerNote:Bool = mustHit ? (rawDir < 4) : (rawDir >= 4);

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
        var chart:LegacyChartData = cast data;
        var songData:LegacySongData = chart.song ?? {};

        var resolved:ResolvedSections = resolveSections(songData.notes);
        var events:Array<EventEntry> = [];

        var currentTime:Float = 0.0;
        var currentBpm:Float = (songData.bpm != null && songData.bpm > 0) ? songData.bpm : 100.0;
        var lastFocus:String = null;

        for (section in resolved.sections)
        {
            if (section == null) continue;

            if ((section.changeBPM ?? false) && section.bpm != null && section.bpm > 0 && section.bpm != currentBpm)
            {
                currentBpm = section.bpm;
                events.push({name: "BPM Change", time: currentTime, variables: [Std.string(currentBpm)]});
            }

            var mustHit:Bool = section.mustHitSection ?? false;
            var cameraFocus:String = resolved.difficultyKeyed ? (mustHit ? "0" : "1") : (mustHit ? "1" : "0");

            if (cameraFocus != lastFocus)
            {
                events.push({name: "Camera Movement", time: currentTime, variables: [cameraFocus]});
                lastFocus = cameraFocus;
            }

            var steps:Int = (section.lengthInSteps != null && section.lengthInSteps > 0) ? section.lengthInSteps : 16;

            currentTime += steps * Conductor.instance.getBeatLengthMsOf(currentBpm);
        }

        return {events: events};
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
}
