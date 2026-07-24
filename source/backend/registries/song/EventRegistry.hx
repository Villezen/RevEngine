package backend.registries.song;

import haxe.Json;
import haxe.io.Path;
import json2object.JsonParser;

import backend.converters.Converter;

import backend.utils.RegistryUtil;

typedef EventData =
{
    @:optional var events:Array<EventEntry>;
}

typedef EventEntry =
{
    @:alias("n") @:optional var name:String;
    @:alias("t") @:optional var time:Null<Float>;
    @:alias("v") @:optional var variables:Array<String>;
}

class EventRegistry
{
    public static var list:Map<String, EventData> = new Map();
    private static var parser:JsonParser<EventData> = new JsonParser<EventData>();

    public static function init():Void
    {
        #if sys
        for (folder in Paths.readDirectory('data/songs'))
            reload(folder);
        #end
    }

    public static function get(name:String):EventData
    {
        if (!list.exists(name))
            reload(name);

        var cachedData = list.get(name);
        var clonedEvents:Array<EventEntry> = [];

        if (cachedData != null && cachedData.events != null)
        {
            for (event in cachedData.events)
                clonedEvents.push({name: event.name, time: event.time, variables: event.variables != null ? event.variables.copy() : []});
        }

        return {events: clonedEvents};
    }

    public static function reload(name:String):Void
    {
        list.set(name, validateData(loadEventData(name)));
    }

    public static function set(name:String, data:EventData):Void
    {
        list.set(name, validateData(data));
    }

    private static function validateData(data:EventData):EventData
    {
        if (data == null) data = {};
        if (data.events == null) data.events = [];

        var i:Int = data.events.length;

        while (--i >= 0)
        {
            var event = data.events[i];

            if (event == null)
            {
                data.events.splice(i, 1);
                continue;
            }

            if (event.name == null) event.name = "Invalid Event";
            if (event.time == null) event.time = 0.0;
            if (event.variables == null) event.variables = [];
        }

        return data;
    }

    public static function reloadAll():Void
    {
        list.clear();
        init();
    }

    private static function loadEventData(song:String):EventData
    {
        var eventsFile:String = '$song-events.json';
        var eventsPath:String = 'data/songs/$song/$eventsFile';

        var rawData:String = '{\n\t"events": []\n}';

        #if sys
        if (Paths.exists(eventsPath))
        {
            rawData = convert(song, Paths.data(eventsFile, 'data/songs/$song'));
        }
        else
        {
            var parsedChart:Dynamic = findForeignChart(song);

            if (parsedChart != null)
                rawData = convertParsed(song, parsedChart);
        }
        #end

        parser.fromJson(rawData, eventsPath);
        RegistryUtil.reportErrors(eventsPath, parser.errors);

        return parser.value;
    }

    public static function convert(song:String, data:String):String
    {
        if (data == null || data == "" || data == "{}")
            return "{}";

        var parsedData:Dynamic = null;

        try
        {
            parsedData = Json.parse(data);
        }
        catch (e:Dynamic)
        {
            trace('Parsing Events JSON for "$song" failed: $e', "WARNING");
            return "{}";
        }

        if (Converter.detect(parsedData) == null)
            return data;

        return convertParsed(song, parsedData);
    }

    public static function convertParsed(song:String, parsedData:Dynamic):String
    {
        var convertedData:EventData = Converter.runEvents(song, parsedData);
        var output:String = Converter.writeEvents(song, convertedData);

        #if sys
        var realPath:String = Converter.resolveRealFile('assets/data/songs/$song/$song-events.json');

        if (realPath == null)
        {
            var songDir:String = resolveSongDir(song);

            if (songDir != null)
                realPath = songDir + '/$song-events.json';
        }

        if (realPath != null)
        {
            if (Converter.saveConvertedFile(realPath, output))
                trace('Converted events for "$song" saved to $realPath', "INFO");
        }
        else
            trace('Converted events for "$song" are memory-only: no writable source location was found.', "WARNING");
        #end

        return output;
    }

    #if sys
    private static function findForeignChart(song:String):Dynamic
    {
        for (file in Paths.readDirectory('data/songs/$song'))
        {
            if (Path.extension(file) != "json") continue;

            var base:String = Path.withoutExtension(file);
            if (StringTools.startsWith(base, '$song-'))
            {
                var suffix:String = base.substr(song.length + 1);
                if (suffix == "events" || suffix == "meta" || StringTools.startsWith(suffix, "meta-")) continue;
            }

            var parsedChart:Dynamic = null;

            try
            {
                parsedChart = Json.parse(Paths.data(file, 'data/songs/$song'));
            }
            catch (e:Dynamic)
            {
                trace('Parsing Chart JSON for "$song" failed: $e', "WARNING");
            }

            if (parsedChart != null && Converter.detect(parsedChart) != null)
                return parsedChart;
        }

        return null;
    }

    private static function resolveSongDir(song:String):String
    {
        for (file in Paths.readDirectory('data/songs/$song'))
        {
            if (Path.extension(file) != "json") continue;

            var real:String = Converter.resolveRealFile('assets/data/songs/$song/$file');

            if (real != null)
                return Path.directory(real);
        }

        return null;
    }
    #end
}
