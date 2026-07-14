package backend.registries.song;

import haxe.Json;
import json2object.JsonParser;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

import backend.utils.RegistryUtil;

typedef AlbumData =
{
    @:optional var name:String;
    @:optional var artists:Array<String>;
    @:optional var sprites:AlbumSpritesData;
}

typedef AlbumSpritesData = 
{
    @:optional var art:AlbumObjectData;
    @:optional var text:AlbumObjectData;
}

typedef AlbumObjectData =
{
    @:optional var path:String;
    @:optional var visible:Bool;
    @:optional var position:Array<Float>;
    @:optional var scale:Array<Float>;
    @:optional var alpha:Float;
    @:optional var angle:Int;

    @:optional var animations:Array<AlbumAnimationData>;
}

typedef AlbumAnimationData = 
{
    @:optional var name:String;
    @:optional var prefix:String;
    @:optional var indices:Array<Int>;
    @:optional var offsets:Array<Int>;
    @:optional var looped:Null<Bool>;
    @:optional var fps:Null<Int>;
}

class AlbumRegistry
{
    public static var list:Map<String, AlbumData> = new Map();
    private static var parser:JsonParser<AlbumData> = new JsonParser<AlbumData>();

    public static function init():Void
    {
        #if sys
        if (Paths.exists('data/albums'))
        {
            for (file in Paths.readDirectory('data/albums'))
            {
                if (Path.extension(file) == "json")
                    reload(Path.withoutExtension(file));
            }
        }
        #end
    }

    public static inline function get(name:String):AlbumData
    {
        if (!list.exists(name))
            reload(name);

        return list.get(name);
    }

    public static function reload(name:String):Void
    {
        var rawData:String = "{}";

        #if sys
        if (Paths.exists('data/albums/$name.json'))
            rawData = Paths.data('$name.json', 'data/albums');
        #end

        parser.fromJson(rawData, '$name.json');
        RegistryUtil.reportErrors('$name.json', parser.errors);

        list.set(name, validateData(name, parser.value));
    }

    private static function validateData(name:String, data:AlbumData):AlbumData
    {
        if (data == null) data = {};

        if (data.name == null) data.name = name;
        if (data.artists == null) data.artists = ["Unknown"];

        if (data.sprites == null) 
            data.sprites = {art: null, text: null};

        data.sprites.art = validateObjectData(data.sprites.art);
        data.sprites.text = validateObjectData(data.sprites.text);

        return data;
    }

    private static function validateObjectData(obj:AlbumObjectData):AlbumObjectData
    {
        if (obj == null) obj = {};

        if (obj.path == null) obj.path = "";
        if (obj.visible == null) obj.visible = true;
        if (obj.position == null) obj.position = [0, 0];
        if (obj.scale == null) obj.scale = [1, 1];
        if (obj.alpha == null) obj.alpha = 1;
        if (obj.angle == null) obj.angle = 0;

        if (obj.animations == null) 
            obj.animations = [];
        else 
            validateAnimations(obj.animations);

        return obj;
    }

    private static function validateAnimations(animations:Array<AlbumAnimationData>):Void
    {
        for (anim in animations)
        {
            if (anim == null) continue;
            
            if (anim.name == null) anim.name = "idle";
            if (anim.prefix == null) anim.prefix = ""; 
            if (anim.indices == null) anim.indices = []; 
            if (anim.offsets == null) anim.offsets = [0, 0];
            
            if (anim.looped == null) anim.looped = false;
            if (anim.fps == null) anim.fps = 24;
        }
    }

    public static function reloadAll():Void
    {
        list.clear();
        init();
    }
}