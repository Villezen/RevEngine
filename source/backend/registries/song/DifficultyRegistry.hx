package backend.registries.song;

import haxe.Json;
import json2object.JsonParser;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

import backend.utils.RegistryUtil;

typedef DifficultyData =
{
    @:optional var name:String;
    @:optional var difficulty:Bool;
    @:optional var variation:Bool;
}

class DifficultyRegistry
{
    public static var list:Map<String, DifficultyData> = new Map();
    private static var parser:JsonParser<DifficultyData> = new JsonParser<DifficultyData>();

    public static function init():Void
    {
        #if sys
        if (Paths.exists('data/difficulties'))
        {
            for (file in Paths.readDirectory('data/difficulties'))
            {
                if (Path.extension(file) == "json")
                    reload(Path.withoutExtension(file));
            }
        }
        #end
    }

    public static inline function get(name:String):DifficultyData
    {
        if (!list.exists(name))
            reload(name);

        return list.get(name);
    }

    public static inline function isVariation(name:String):Bool
    {
        var data = get(name);
        return data != null && data.variation == true;
    }

    public static inline function suffix(name:String):String
    {
        return isVariation(name) ? '-$name' : '';
    }

    public static function characterVariations():Array<String>
    {
        var result:Array<String> = [];

        for (id in list.keys())
        {
            var data = list.get(id);
            if (data != null && data.variation == true && data.difficulty == false)
                result.push(id);
        }

        return result;
    }

    public static function reload(name:String):Void
    {
        var rawData:String = "{}";

        #if sys
        if (Paths.exists('data/difficulties/$name.json'))
            rawData = Paths.data('$name.json', 'data/difficulties');
        #end

        parser.fromJson(rawData, '$name.json');
        RegistryUtil.reportErrors('$name.json', parser.errors);

        list.set(name, validateData(name, parser.value));
    }

    private static function validateData(name:String, data:DifficultyData):DifficultyData
    {
        if (data == null) data = {};

        if (data.name == null) data.name = name;
        if (data.difficulty == null) data.difficulty = true; 
        if (data.variation == null) data.variation = false;

        return data;
    }

    public static function reloadAll():Void
    {
        list.clear();
        init();
    }
}