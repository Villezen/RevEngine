package backend.registries.song;

import haxe.Json;
import json2object.JsonParser;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

import backend.utils.RegistryUtil;

typedef EventObjectData =
{
    @:optional var name:String;
    @:optional var alias:Array<String>;
    @:optional var description:String;

    @:optional var variables:Array<EventObjectVariables>;
}

typedef EventObjectVariables =
{
    @:optional var name:String;
    @:optional var type:String;
    @:optional var defaultValue:String;
}

class EventObjectRegistry
{
    public static var list:Map<String, EventObjectData> = new Map();
    private static var parser:JsonParser<EventObjectData> = new JsonParser<EventObjectData>();

    public static function init():Void
    {
        #if sys
        for (file in Paths.readDirectory('data/events')) 
        {
            if (Path.extension(file) == "json") 
                reload(Path.withoutExtension(file));
        }
        #end
    }

    public static inline function get(name:String):EventObjectData
    {
        if (!list.exists(name))
            reload(name);

        return list.get(name);
    }

    /**
     * Finds a loaded event by its display name or one of its aliases.
     * @param name The event name used in the chart.
     * @return The event's data, or `null` if no loaded event matches.
     */
    public static function findByName(name:String):Null<EventObjectData>
    {
        if (name == null)
            return null;

        for (data in list)
        {
            if (data == null) continue;

            if (data.name == name || (data.alias != null && data.alias.contains(name)))
                return data;
        }

        return null;
    }

    public static function reload(name:String):Void
    {
        var rawData:String = "{}";

        #if sys
        if (Paths.exists('data/events/$name.json'))
            rawData = Paths.data('$name.json', 'data/events');
        #end

        parser.fromJson(rawData, 'data/events/$name.json');
        RegistryUtil.reportErrors('data/events/$name.json', parser.errors);

        list.set(name, validateData(name, parser.value));
    }

    private static function validateData(name:String, data:EventObjectData):EventObjectData
    {
        if (data == null) data = {};

        if (data.name == null) data.name = name;
        if (data.alias == null) data.alias = [];
        if (data.description == null) data.description = "";
        if (data.variables == null) data.variables = [];

        for (i in 0...data.variables.length)
        {
            var variable = data.variables[i];
            if (variable == null) continue;

            if (variable.name == null) variable.name = "Value";
            if (variable.type == null) variable.type = "Int";
            if (variable.defaultValue == null) variable.defaultValue = "";
        }

        return data;
    }

    public static function reloadAll():Void
    {
        list.clear();
        init();
    }
}