package backend.registries.song;

import haxe.Json;
import json2object.JsonParser;
import sys.FileSystem;
import sys.io.File;

import backend.utils.RegistryUtil;

typedef MetaData =
{
    @:optional var name:String;
    @:optional var icon:String;
    @:optional var stage:String;
    @:optional var bpm:Null<Float>;

    @:optional var player:String;

    @:optional var album:MetaAlbumData;
    @:optional var freeplay:MetaFreeplayData;

    @:optional var composers:Array<String>;
    @:optional var artists:Array<String>;
    @:optional var charters:Array<String>;

    @:optional var countdown:CountdownSkinData;
    @:optional var ratings:RatingSkinData;
}

typedef MetaAlbumData = 
{
    @:optional var name:String;
    @:optional var ratings:Int;
    @:optional var previewTimestamp:Float;
}

typedef MetaFreeplayData = 
{
    @:optional var hide:Bool;
    @:optional var newlyAdded:Bool;
}

typedef CountdownSkinData =
{
    @:optional var skin:String;
    @:optional var audio:String;
}

typedef RatingSkinData =
{
    @:optional var skin:String;
}

class MetaRegistry
{
    public static var list:Map<String, MetaData> = new Map();
    private static var parser:JsonParser<MetaData> = new JsonParser<MetaData>();

    public static function init():Void
    {
        #if sys
        if (Paths.exists('data/songs'))
        {
            for (folder in Paths.readDirectory('data/songs'))
                reload(folder);
        }
        #end
    }

    public static inline function get(name:String, ?variation:String):MetaData
    {
        var key:String = name + (variation ?? "");

        if (!list.exists(key))
            reload(name, variation);

        return list.get(key);
    }

    public static function reload(name:String, ?variation:String):Void
    {
        var suffix:String = variation ?? "";
        var key:String = name + suffix;

        var file:String = '$name-meta$suffix.json';
        var baseFile:String = '$name-meta.json';

        var rawData:String = "{}";

        #if sys
        if (Paths.exists('data/songs/$name/$file'))
            rawData = Paths.data(file, 'data/songs/$name');
        else if (Paths.exists('data/songs/$name/$baseFile'))
            rawData = Paths.data(baseFile, 'data/songs/$name');
        #end

        parser.fromJson(rawData, 'data/songs/$name/$file');
        RegistryUtil.reportErrors('data/songs/$name/$file', parser.errors);

        list.set(key, validateData(name, parser.value));
    }

    private static function validateData(name:String, data:MetaData):MetaData
    {
        if (data == null) data = {};

        if (data.name == null) data.name = name;
        if (data.icon == null) data.icon = "bf-test";
        if (data.stage == null) data.stage = "stage";
        if (data.bpm == null || data.bpm <= 0) data.bpm = 100.0;
        if (data.player == null) data.player = Constants.DEFAULT_CHARACTER;
        
        if (data.album == null) data.album = {};
        if (data.album.name == null) data.album.name = "unknown";
        if (data.album.ratings == null) data.album.ratings = 1;
        if (data.album.previewTimestamp == null) data.album.previewTimestamp = 0;

        if (data.freeplay == null) data.freeplay = {};
        if (data.freeplay.hide == null) data.freeplay.hide = false;
        if (data.freeplay.newlyAdded == null) data.freeplay.newlyAdded = false;

        if (data.composers == null) data.composers = ["NULL"];
        if (data.artists == null) data.artists = ["NULL"];
        if (data.charters == null) data.charters = ["NULL"];

        if (data.countdown == null) data.countdown = {};
        if (data.countdown.skin == null) data.countdown.skin = "default";
        if (data.countdown.audio == null) data.countdown.audio = "default";

        if (data.ratings == null) data.ratings = {};
        if (data.ratings.skin == null) data.ratings.skin = "default";

        return data;
    }

    public static function reloadAll():Void
    {
        list.clear();
        init();
    }
}