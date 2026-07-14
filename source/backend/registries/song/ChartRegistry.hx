package backend.registries.song;

import haxe.Json;
import haxe.io.Path;
import json2object.JsonParser;

import backend.converters.Converter;
import backend.converters.IConverterEntry;
import backend.assets.Paths;

import backend.utils.RegistryUtil;

typedef ChartData =
{
    @:optional var strumlines:Array<ChartStrumline>;
}

typedef ChartStrumline =
{
    @:optional var id:Null<Int>;
    @:optional var character:String;
    @:optional var skin:String;
    @:optional var position:Array<Int>;
    @:optional var scale:Null<Float>;
    @:optional var visible:Null<Bool>;
    @:optional var keys:Null<Int>;
    @:optional var speed:Null<Float>;
    @:optional var notes:Array<ChartNote>;
}

typedef ChartNote =
{
    @:alias("t") @:optional var time:Null<Float>;
    @:alias("d") @:optional var direction:Null<Int>;
    @:alias("l") @:optional var length:Null<Float>;
    @:alias("k") @:optional var kind:String;
}

class ChartRegistry
{
    public static var list:Map<String, ChartData> = new Map();
    private static var parser:JsonParser<ChartData> = new JsonParser<ChartData>();

    private static var scanned:Map<String, Bool> = new Map();

    private static inline function chartKey(name:String, difficulty:String):String
    {
        return '$name/$difficulty';
    }

    public static function init():Void
    {
        #if sys
        for (folder in Paths.readDirectory('data/songs'))
            reloadSong(folder);
        #end
    }

    public static function reloadSong(name:String):Void
    {
        convertSong(name, true);

        for (difficulty in listDifficulties(name))
            reload(name, difficulty);
    }

    public static function listDifficulties(name:String, ?variation:String):Array<String>
    {
        if (variation == null) variation = "";

        convertSong(name);

        var difficulties:Array<String> = [];

        #if sys
        for (file in Paths.readDirectory('data/songs/$name'))
        {
            var difficulty:String = chartDifficulty(name, file, variation);

            if (difficulty != null && !difficulties.contains(difficulty))
                difficulties.push(difficulty);
        }
        #end

        difficulties.sort(Reflect.compare);

        return difficulties;
    }

    private static inline function chartFileName(name:String, difficulty:String, variation:String):String
    {
        return '$name-chart-$difficulty$variation.json';
    }

    #if sys
    private static function chartDifficulty(name:String, file:String, variation:String):Null<String>
    {
        if (Path.extension(file) != "json") return null;

        var base:String = Path.withoutExtension(file);
        var prefix:String = '$name-chart-';
        if (!StringTools.startsWith(base, prefix)) return null;

        var rest:String = base.substr(prefix.length);
        if (rest == "") return null;

        var fileVariation:String = "";

        for (cv in DifficultyRegistry.characterVariations())
        {
            if (StringTools.endsWith(rest, '-$cv'))
            {
                fileVariation = '-$cv';
                rest = rest.substr(0, rest.length - fileVariation.length);
                break;
            }
        }

        if (fileVariation != variation || rest == "") return null;

        return rest;
    }
    #end

    public static function get(name:String, ?difficulty:String, ?variation:String):ChartData
    {
        if (difficulty == null) difficulty = Constants.DEFAULT_DIFFICULTY;
        if (variation == null) variation = "";

        if (!list.exists(chartKey(name, difficulty + variation)))
            reload(name, difficulty, variation);

        return list.get(chartKey(name, difficulty + variation));
    }

    public static function reload(name:String, ?difficulty:String, ?variation:String):Void
    {
        if (difficulty == null) difficulty = Constants.DEFAULT_DIFFICULTY;
        if (variation == null) variation = "";

        var chartFile:String = chartFileName(name, difficulty, variation);
        var chartPath:String = 'data/songs/$name/$chartFile';

        var rawData:String = "{}";

        #if sys
        convertSong(name);

        if (Paths.exists(chartPath))
        {
            rawData = Paths.data(chartFile, 'data/songs/$name');
            rawData = convert(name, difficulty, rawData);
        }
        #end

        parser.fromJson(rawData, chartPath);
        RegistryUtil.reportErrors(chartPath, parser.errors);

        list.set(chartKey(name, difficulty + variation), validateData(parser.value));
    }

    private static function validateData(data:ChartData):ChartData
    {
        if (data == null) data = {};

        if (data.strumlines == null || data.strumlines.length == 0)
        {
            data.strumlines =
            [
                {id: 0, character: "bf", skin: "default", position: [0, 0], scale: 1.0, visible: true, keys: 4, speed: 1.0, notes: []},
                {id: 1, character: "bf", skin: "default", position: [0, 0], scale: 1.0, visible: true, keys: 4, speed: 1.0, notes: []}
            ];
        }

        for (i in 0...data.strumlines.length)
        {
            var strum = data.strumlines[i];

            if (strum == null)
            {
                strum = {};
                data.strumlines[i] = strum;
            }

            if (strum.id == null) strum.id = 0;
            if (strum.character == null) strum.character = "bf";
            if (strum.skin == null) strum.skin = "default";
            if (strum.position == null || strum.position.length < 2) strum.position = [0, 0];
            if (strum.scale == null) strum.scale = 1.0;
            if (strum.visible == null) strum.visible = true;
            if (strum.keys == null || strum.keys <= 0) strum.keys = 4;
            if (strum.speed == null || strum.speed <= 0) strum.speed = 1.0;
            if (strum.notes == null) strum.notes = [];

            for (note in strum.notes)
            {
                if (note == null) continue;

                if (note.time == null) note.time = 0.0;
                if (note.direction == null) note.direction = 0;
                if (note.length == null || note.length < 0) note.length = 0.0;
                if (note.kind == null) note.kind = "default";
            }
        }

        return data;
    }

    public static function reloadAll():Void
    {
        list.clear();
        scanned.clear();
        init();
    }

    public static function convertSong(name:String, ?force:Bool = false):Void
    {
        #if sys
        if (!force && scanned.exists(name)) return;
        scanned.set(name, true);

        var chartPrefix:String = '$name-chart-';

        for (file in Paths.readDirectory('data/songs/$name'))
        {
            if (Path.extension(file) != "json") continue;

            var base:String = Path.withoutExtension(file);

            if (StringTools.startsWith(base, '$name-'))
            {
                var suffix:String = base.substr(name.length + 1);
                if (suffix == "events" || suffix == "meta" || StringTools.startsWith(suffix, "meta-")) continue;
            }

            var realPath:String = Converter.resolveRealFile('assets/data/songs/$name/$file');
            if (realPath == null) continue;

            var parsedData:Dynamic = parseChartJson(name, Paths.data(file, 'data/songs/$name'));
            if (parsedData == null) continue;

            var converter:IConverterEntry = Converter.detect(parsedData);

            if (converter != null)
            {
                var single:String = base;
                if (StringTools.startsWith(base, chartPrefix)) single = base.substr(chartPrefix.length);
                else if (StringTools.startsWith(base, '$name-')) single = base.substr(name.length + 1);

                convertForeign(name, converter, parsedData, Path.normalize(realPath), single);
            }
        }
        #end
    }

    #if sys
    /**
     * Splits a foreign chart container into native `$name-chart-<difficulty>.json` files next
     * to the source, then consumes the source file once everything is saved.
     */
    private static function convertForeign(name:String, converter:IConverterEntry, parsedData:Dynamic, sourcePath:String, ?singleName:String):Void
    {
        EventRegistry.convertParsed(name, parsedData);

        converter.song = name;

        var difficulties:Array<String> = converter.listDifficulties(parsedData);
        var singleDifficulty:Bool = difficulties.length == 0;

        if (singleDifficulty)
            difficulties = [singleName ?? Constants.DEFAULT_DIFFICULTY];

        var targetDir:String = Path.directory(sourcePath);
        var written:Array<String> = [];
        var allSaved:Bool = true;

        for (difficulty in difficulties)
        {
            converter.difficulty = singleDifficulty ? null : difficulty;

            var output:String = Converter.writeChart(name, converter.convertChart(parsedData));
            var targetPath:String = Path.normalize('$targetDir/' + chartFileName(name, difficulty, ""));

            if (Converter.saveConvertedFile(targetPath, output))
            {
                trace('Converted chart for "$name" [$difficulty] saved to $targetPath', "INFO");
                written.push(targetPath.toLowerCase());
            }
            else
            {
                trace('Converted chart for "$name" [$difficulty] is memory-only: saving to $targetPath failed.', "WARNING");
                allSaved = false;
            }
        }

        converter.difficulty = null;

        if (allSaved && !written.contains(sourcePath.toLowerCase()) && Converter.removeSourceFile(sourcePath))
            trace('Removed converted chart source at $sourcePath', "INFO");
    }
    #end

    /**
     * In-memory safety net: converts a foreign chart string into the native format
     * without touching the disk (convertSong handles the on-disk conversion).
     */
    public static function convert(song:String, difficulty:String, data:String):String
    {
        var parsedData:Dynamic = parseChartJson(song, data);

        if (parsedData == null)
            return (data == null || data == "") ? "{}" : data;

        var converter:IConverterEntry = Converter.detect(parsedData);

        if (converter == null)
            return data;

        EventRegistry.convertParsed(song, parsedData);

        var target:String = converter.listDifficulties(parsedData).contains(difficulty) ? difficulty : null;

        return Converter.writeChart(song, Converter.runChart(song, parsedData, target));
    }

    private static function parseChartJson(song:String, data:String):Dynamic
    {
        if (data == null || data == "" || data == "{}")
            return null;

        try
        {
            return Json.parse(data);
        }
        catch (e:Dynamic)
        {
            trace('Parsing Chart JSON for "$song" failed: $e', "WARNING");
        }

        return null;
    }
}
