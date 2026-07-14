package backend.registries.world;

import json2object.JsonParser;
import haxe.io.Path;

import backend.utils.RegistryUtil;

typedef StageData =
{
    @:optional var camera:CameraData;
    @:optional var characters:CharactersData;
    @:optional var sprites:Array<SpriteData>;
}

typedef CameraData =
{
    @:optional var zoom:Null<Float>;
    @:optional var speed:Null<Float>;
    @:optional var baseline:Array<Int>;
    @:optional var boyfriend:Array<Int>;
    @:optional var dad:Array<Int>;
    @:optional var girlfriend:Array<Int>;
}

typedef CharactersData =
{
    @:optional var boyfriend:Array<Int>;
    @:optional var dad:Array<Int>;
    @:optional var girlfriend:Array<Int>;
    @:optional var visibility:Array<Bool>;
}

typedef SpriteData =
{
    @:optional var name:String;
    @:optional var path:String;
    @:optional var position:Array<Int>;
    @:optional var scale:Array<Float>;
    @:optional var scroll:Array<Float>;
    @:optional var flip:Array<Bool>;
    @:optional var alpha:Null<Float>;
    @:optional var angle:Null<Int>;
    @:optional var antialiasing:Null<Bool>;
    @:optional var animations:AnimationData;
}

typedef AnimationData =
{
    @:optional var current:String;
    @:optional var data:Array<AnimationEntry>;
}

typedef AnimationEntry =
{
    @:optional var name:String;
    @:optional var prefix:String;
    @:optional var indices:Array<Int>;
    @:optional var fps:Null<Int>;
    @:optional var looping:Null<Bool>;
    @:optional var flip:Array<Bool>;
}

class StageRegistry
{
    public static var list:Map<String, StageData> = new Map();
    private static var parser:JsonParser<StageData> = new JsonParser<StageData>();

    public static function init():Void
    {
        #if sys
        for (file in Paths.readDirectory('data/stages'))
        {
            if (Path.extension(file) == "json")
                reload(Path.withoutExtension(file));
        }
        #end
    }

    public static inline function get(name:String):StageData
    {
        if (!list.exists(name))
            reload(name);

        return list.get(name);
    }

    public static function reload(name:String):Void
    {
        var rawData:String = "{}";

        #if sys
        if (Paths.exists('data/stages/$name.json'))
            rawData = Paths.data('$name.json', 'data/stages');
        #end

        parser.fromJson(rawData, 'data/stages/$name.json');
        RegistryUtil.reportErrors('data/stages/$name.json', parser.errors);

        list.set(name, validateData(parser.value));
    }

    private static function validateData(data:StageData):StageData
    {
        if (data == null) data = {};

        if (data.camera == null) data.camera = {};
        if (data.camera.zoom == null) data.camera.zoom = 1.0;
        if (data.camera.speed == null) data.camera.speed = 1.0;
        if (data.camera.baseline == null || data.camera.baseline.length < 2) data.camera.baseline = [0, 0];
        if (data.camera.boyfriend == null || data.camera.boyfriend.length < 2) data.camera.boyfriend = [0, 0];
        if (data.camera.dad == null || data.camera.dad.length < 2) data.camera.dad = [0, 0];
        if (data.camera.girlfriend == null || data.camera.girlfriend.length < 2) data.camera.girlfriend = [0, 0];

        if (data.characters == null) data.characters = {};
        if (data.characters.boyfriend == null || data.characters.boyfriend.length < 2) data.characters.boyfriend = [0, 0];
        if (data.characters.dad == null || data.characters.dad.length < 2) data.characters.dad = [0, 0];
        if (data.characters.girlfriend == null || data.characters.girlfriend.length < 2) data.characters.girlfriend = [0, 0];
        if (data.characters.visibility == null || data.characters.visibility.length < 3) data.characters.visibility = [true, true, true];

        if (data.sprites == null) data.sprites = [];

        var i:Int = data.sprites.length;
        while (--i >= 0)
            if (data.sprites[i] == null) data.sprites.splice(i, 1);

        for (sprite in data.sprites)
        {
            if (sprite.name == null) sprite.name = "Sprite";
            if (sprite.path == null) sprite.path = "";
            if (sprite.position == null || sprite.position.length < 2) sprite.position = [0, 0];
            if (sprite.scale == null || sprite.scale.length < 2) sprite.scale = [1.0, 1.0];
            if (sprite.scroll == null || sprite.scroll.length < 2) sprite.scroll = [1.0, 1.0];
            if (sprite.flip == null || sprite.flip.length < 2) sprite.flip = [false, false];
            if (sprite.alpha == null) sprite.alpha = 1.0;
            if (sprite.angle == null) sprite.angle = 0;
            if (sprite.antialiasing == null) sprite.antialiasing = true;

            if (sprite.animations == null) sprite.animations = {};
            if (sprite.animations.current == null) sprite.animations.current = "";
            if (sprite.animations.data == null) sprite.animations.data = [];

            var j:Int = sprite.animations.data.length;
            while (--j >= 0)
                if (sprite.animations.data[j] == null) sprite.animations.data.splice(j, 1);

            for (anim in sprite.animations.data)
            {
                if (anim.name == null) anim.name = "";
                if (anim.prefix == null) anim.prefix = "";
                if (anim.fps == null) anim.fps = 30;
                if (anim.looping == null) anim.looping = true;
                if (anim.flip == null || anim.flip.length < 2) anim.flip = [false, false];
            }
        }

        return data;
    }

    public static function reloadAll():Void
    {
        list.clear();
        init();
    }
}