package backend.registries.ui;

import haxe.io.Path;
import json2object.JsonParser;

import backend.utils.RegistryUtil;

typedef CountdownData =
{
    @:optional var increments:CountdownIncrements;
}

typedef CountdownIncrements = 
{
    @:optional var THREE:CountdownIncrementData;
    @:optional var TWO:CountdownIncrementData;
    @:optional var ONE:CountdownIncrementData;
    @:optional var GO:CountdownIncrementData;
}

typedef CountdownIncrementData =
{
    @:optional var antialiasing:Null<Bool>;
    @:optional var alpha:Null<Float>;
    @:optional var angle:Null<Int>;
    @:optional var scale:Array<Float>;
    @:optional var offsets:Array<Int>;

    @:optional var animation:CountdownIncrementAnimationData;
}

typedef CountdownIncrementAnimationData =
{
    var prefix:String;
    @:optional var fps:Null<Int>;
    @:optional var looped:Null<Bool>;
}

class CountdownRegistry
{
    public static var list:Map<String, CountdownData> = new Map();
    private static var parser:JsonParser<CountdownData> = new JsonParser<CountdownData>();

    public static function init():Void
    {
        #if sys
        for (file in Paths.readDirectory('data/countdown'))
        {
            if (Path.extension(file) == "json")
                reload(Path.withoutExtension(file));
        }
        #end
    }

    public static inline function get(name:String):CountdownData
    {
        if (!list.exists(name))
            reload(name);

        return list.get(name);
    }

    public static function reload(name:String):Void
    {
        var rawData:String = "{}";

        #if sys
        if (Paths.exists('data/countdown/$name.json'))
            rawData = Paths.data('$name.json', 'data/countdown');
        #end

        parser.fromJson(rawData, 'data/countdown/$name.json');
        RegistryUtil.reportErrors('data/countdown/$name.json', parser.errors);

        list.set(name, validateData(parser.value));
    }

    private static function validateData(data:CountdownData):CountdownData
    {
        if (data == null) 
            data = {increments: {}};
            
        if (data.increments == null) 
            data.increments = {};

        function validateIncrement(inc:CountdownIncrementData):CountdownIncrementData
        {
            if (inc == null) inc = {};
            
            if (inc.antialiasing == null) inc.antialiasing = true;
            if (inc.alpha == null) inc.alpha = 1.0;
            if (inc.angle == null) inc.angle = 0;
            
            if (inc.scale == null || inc.scale.length < 2) 
                inc.scale = [1.0, 1.0];
                
            if (inc.offsets == null || inc.offsets.length < 2) 
                inc.offsets = [0, 0];

            if (inc.animation != null)
            {
                if (inc.animation.fps == null) inc.animation.fps = 24;
                if (inc.animation.looped == null) inc.animation.looped = false;
            }

            return inc;
        }

        data.increments.THREE = validateIncrement(data.increments.THREE);
        data.increments.TWO = validateIncrement(data.increments.TWO);
        data.increments.ONE = validateIncrement(data.increments.ONE);
        data.increments.GO = validateIncrement(data.increments.GO);

        return data;
    }

    public static function reloadAll():Void
    {
        list.clear();
        init();
    }
}