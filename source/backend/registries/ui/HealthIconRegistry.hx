package backend.registries.ui;

import haxe.io.Path;
import json2object.JsonParser;

import backend.utils.RegistryUtil;

typedef IconData =
{
    @:optional var scale:Array<Float>;
    @:optional var position:Array<Int>;
    @:optional var antialiasing:Null<Bool>;
    @:optional var states:Array<IconState>;
}

typedef IconState =
{
    @:optional var value:Null<Float>;
    @:optional var name:String;
    @:optional var prefix:Array<Int>;
    @:optional var offsets:Array<Int>;
    @:optional var looped:Null<Bool>;
    @:optional var fps:Null<Int>;
}

class HealthIconRegistry
{
    public static var list:Map<String, IconData> = new Map();
    private static var parser:JsonParser<IconData> = new JsonParser<IconData>();

    public static function init():Void
    {
        #if sys
        for (file in Paths.readDirectory('data/icons'))
        {
            if (Path.extension(file) == "json")
                reload(Path.withoutExtension(file));
        }
        #end
    }

    public static inline function get(name:String):IconData
    {
        if (!list.exists(name))
            reload(name);

        return list.get(name);
    }

    public static function reload(name:String):Void
    {
        var rawData:String = "{}";

        #if sys
        if (Paths.exists('data/icons/$name.json'))
            rawData = Paths.data('$name.json', 'data/icons');
        #end

        parser.fromJson(rawData, 'data/icons/$name.json');
        RegistryUtil.reportErrors('data/icons/$name.json', parser.errors);

        list.set(name, validateData(parser.value));
    }

    private static function validateData(data:IconData):IconData
    {
        if (data == null) data = {};

        if (data.scale == null || data.scale.length < 2) data.scale = [1.0, 1.0];
        if (data.position == null || data.position.length < 2) data.position = [0, 0];
        if (data.antialiasing == null) data.antialiasing = true;
        
        if (data.states == null || data.states.length == 0)
        {
            data.states =
            [
                {value: 25.0, name: "losing", prefix: [1], offsets: [0, 0], looped: false, fps: 24},
                {name: "neutral", prefix: [0], offsets: [0, 0], looped: false, fps: 24}
            ];
        }

        var i:Int = data.states.length;
        while (--i >= 0)
            if (data.states[i] == null) data.states.splice(i, 1);

        for (state in data.states)
        {
            if (state.value == null) state.value = 0.0;
            if (state.name == null) state.name = "neutral";
            if (state.prefix == null) state.prefix = [0];
            if (state.offsets == null || state.offsets.length < 2) state.offsets = [0, 0];
            if (state.looped == null) state.looped = false;
            if (state.fps == null) state.fps = 24;
        }

        return data;
    }

    public static function reloadAll():Void
    {
        list.clear();
        init();
    }
}