package backend.registries.misc;

import haxe.Json;
import json2object.JsonParser;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

import backend.utils.RegistryUtil;

typedef PlayerData =
{
    @:optional var name:String;
    @:optional var characters:Array<String>;

    @:optional var freeplay:PlayerFreeplayData;
    @:optional var characterSelect:PlayerCharacterSelectData;
}

typedef PlayerFreeplayData =
{
    @:optional var skin:String;
    @:optional var bands:PlayerFreeplayBandData;
}

typedef PlayerFreeplayBandData =
{
    @:optional var text:Array<String>;
    @:optional var color:Array<String>;
    @:optional var speed:Array<Float>;
}

typedef PlayerCharacterSelectData =
{
    @:optional var unlocked:Bool;
    @:optional var position:Int;
}

class PlayerRegistry
{
    public static var list:Map<String, PlayerData> = new Map();
    private static var parser:JsonParser<PlayerData> = new JsonParser<PlayerData>();

    public static function init():Void
    {
        #if sys
        if (Paths.exists('data/players'))
        {
            for (file in Paths.readDirectory('data/players'))
            {
                if (Path.extension(file) == "json")
                    reload(Path.withoutExtension(file));
            }
        }
        #end
    }

    public static inline function get(name:String):PlayerData
    {
        if (!list.exists(name))
            reload(name);

        return list.get(name);
    }

    public static function reload(name:String):Void
    {
        var rawData:String = "{}";

        #if sys
        if (Paths.exists('data/players/$name.json'))
            rawData = Paths.data('$name.json', 'data/players');
        #end

        parser.fromJson(rawData, '$name.json');
        RegistryUtil.reportErrors('$name.json', parser.errors);

        list.set(name, validateData(name, parser.value));
    }

    private static function validateData(name:String, data:PlayerData):PlayerData
    {
        if (data == null) data = {};

        if (data.name == null) data.name = name;
        if (data.characters == null || data.characters.length == 0) data.characters = [name];

        return data;
    }

    public static function playerForCharacter(character:String):Null<String>
    {
        if (character == null || character == "") return null;

        for (id in list.keys())
        {
            var data:PlayerData = list.get(id);

            if (data != null && data.characters != null && data.characters.indexOf(character) != -1)
                return id;
        }

        return null;
    }

    public static function owns(player:String, character:String):Bool
    {
        if (player == null || character == null) return false;

        var data:PlayerData = get(player);
        return data != null && data.characters != null && data.characters.indexOf(character) != -1;
    }

    public static function reloadAll():Void
    {
        list.clear();
        init();
    }
}
