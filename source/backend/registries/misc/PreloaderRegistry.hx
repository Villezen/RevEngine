package backend.registries.misc;

import haxe.Json;
import json2object.JsonParser;

import backend.utils.RegistryUtil;

/**
 * JSON params for the preloader data.
 */
typedef PreloaderData =
{
    @:optional var general:GeneralPreloadData;
    @:optional var extras:Array<ExtraPreloadData>;
}

/**
 * Which general aspects of the song should be preloaded.
 */
typedef GeneralPreloadData =
{
    @:optional var characters:Bool;
    @:optional var stage:Bool;
    @:optional var song:Bool;
    @:optional var noteskins:Bool;
    @:optional var countdown:Bool;
    @:optional var ratings:Bool;
}

/**
 * Entry for an extra asset to be preloaded.
 */
typedef ExtraPreloadData =
{
    var type:String;
    var path:String;
}

class PreloaderRegistry
{
    public static var list:Map<String, PreloaderData> = new Map();
    private static var parser:JsonParser<PreloaderData> = new JsonParser<PreloaderData>();

    public static function init():Void
    {
        #if sys
        for (folder in Paths.readDirectory('data/songs'))
            reload(folder);
        #end
    }

    public static inline function get(name:String):PreloaderData
    {
        if (!list.exists(name))
            reload(name);

        return list.get(name);
    }

    public static function reload(name:String):Void
    {
        var file:String = '$name-preload.json';
        var path:String = 'data/songs/$name/$file';

        var rawData:String = "{}";

        #if sys
        if (Paths.exists(path))
        {
            rawData = Paths.data(file, 'data/songs/$name');
        }
        #end

        parser.fromJson(rawData, path);
        RegistryUtil.reportErrors(path, parser.errors);

        list.set(name, validateData(parser.value));
    }

    private static function validateData(data:PreloaderData):PreloaderData
    {
        if (data == null) data = {};

        if (data.general == null) data.general = {};

        if (data.general.characters == null) data.general.characters = true;
        if (data.general.stage == null) data.general.stage = true;
        if (data.general.song == null) data.general.song = true;
        if (data.general.noteskins == null) data.general.noteskins = true;
        if (data.general.countdown == null) data.general.countdown = true;
        if (data.general.ratings == null) data.general.ratings = true;

        if (data.extras == null) data.extras = [];

        for (entry in data.extras)
        {
            if (entry.type == null) entry.type = "";
            if (entry.path == null) entry.path = "";
        }

        return data;
    }

    public static function reloadAll():Void
    {
        list.clear();
        init();
    }
}
