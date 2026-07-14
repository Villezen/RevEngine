package backend.registries.ui;

import haxe.io.Path;
import json2object.JsonParser;

import backend.utils.RegistryUtil;

typedef RatingsData =
{
    @:optional var position:Array<Int>;
    @:optional var antialiasing:Null<Bool>;
    @:optional var alpha:Null<Float>;

    @:optional var camera:String;

    @:optional var ratings:JudgementsData;
    @:optional var combo:ComboData;
}

typedef JudgementsData =
{
    @:optional var position:Array<Int>;

    @:optional var sick:RatingSpriteEntry;
    @:optional var good:RatingSpriteEntry;
    @:optional var bad:RatingSpriteEntry;
    @:optional var shit:RatingSpriteEntry;
}

typedef ComboData =
{
    @:optional var position:Array<Int>;
    @:optional var spacing:Null<Int>;

    @:optional var num0:RatingSpriteEntry;
    @:optional var num1:RatingSpriteEntry;
    @:optional var num2:RatingSpriteEntry;
    @:optional var num3:RatingSpriteEntry;
    @:optional var num4:RatingSpriteEntry;
    @:optional var num5:RatingSpriteEntry;
    @:optional var num6:RatingSpriteEntry;
    @:optional var num7:RatingSpriteEntry;
    @:optional var num8:RatingSpriteEntry;
    @:optional var num9:RatingSpriteEntry;
}

typedef RatingSpriteEntry = 
{
    @:optional var offset:Array<Int>;
    @:optional var scale:Array<Float>;

    @:optional var velocity:RatingPointEntry;
    @:optional var acceleration:RatingPointEntry;

    @:optional var ease:String;
    @:optional var timeMult:Null<Float>;
}

typedef RatingPointEntry = 
{
    @:optional var x:Array<Int>;
    @:optional var y:Array<Int>;
}

class RatingsRegistry
{
    public static var list:Map<String, RatingsData> = new Map();
    private static var parser:JsonParser<RatingsData> = new JsonParser<RatingsData>();

    public static function init():Void
    {
        #if sys
        for (file in Paths.readDirectory('data/ratings'))
        {
            if (Path.extension(file) == "json")
                reload(Path.withoutExtension(file));
        }
        #end
    }

    public static inline function get(name:String):RatingsData
    {
        if (!list.exists(name))
            reload(name);

        return list.get(name);
    }

    public static function reload(name:String):Void
    {
        var rawData:String = "{}";

        #if sys
        if (Paths.exists('data/ratings/$name.json'))
            rawData = Paths.data('$name.json', 'data/ratings');
        #end

        parser.fromJson(rawData, 'data/ratings/$name.json');
        RegistryUtil.reportErrors('data/ratings/$name.json', parser.errors);

        list.set(name, validateData(parser.value));
    }

    private static function validateData(data:RatingsData):RatingsData
    {
        if (data == null) data = {};

        if (data.position == null || data.position.length < 2) data.position = [0, 0];
        if (data.antialiasing == null) data.antialiasing = true;
        if (data.alpha == null) data.alpha = 1.0;
        if (data.camera == null) data.camera = "camHUD";

        if (data.ratings == null) data.ratings = {};

        if (data.ratings.position == null || data.ratings.position.length < 2) data.ratings.position = [0, 0];

        data.ratings.sick = validateEntry(data.ratings.sick);
        data.ratings.good = validateEntry(data.ratings.good);
        data.ratings.bad = validateEntry(data.ratings.bad);
        data.ratings.shit = validateEntry(data.ratings.shit);

        if (data.combo == null) data.combo = {};

        if (data.combo.position == null || data.combo.position.length < 2) data.combo.position = [110, 100];
        if (data.combo.spacing == null) data.combo.spacing = 36;

        data.combo.num0 = validateComboEntry(data.combo.num0);
        data.combo.num1 = validateComboEntry(data.combo.num1);
        data.combo.num2 = validateComboEntry(data.combo.num2);
        data.combo.num3 = validateComboEntry(data.combo.num3);
        data.combo.num4 = validateComboEntry(data.combo.num4);
        data.combo.num5 = validateComboEntry(data.combo.num5);
        data.combo.num6 = validateComboEntry(data.combo.num6);
        data.combo.num7 = validateComboEntry(data.combo.num7);
        data.combo.num8 = validateComboEntry(data.combo.num8);
        data.combo.num9 = validateComboEntry(data.combo.num9);

        return data;
    }

    private static function validateEntry(entry:RatingSpriteEntry):RatingSpriteEntry
    {
        if (entry == null) entry = {};

        if (entry.offset == null || entry.offset.length < 2) entry.offset = [0, 0];
        if (entry.scale == null || entry.scale.length < 2) entry.scale = [0.65, 0.65];

        if (entry.velocity == null)
            entry.velocity = {x: [-10, 0], y: [-140, -175]}; 
        else
        {
            if (entry.velocity.x == null || entry.velocity.x.length < 2) entry.velocity.x = [-10, 0];
            if (entry.velocity.y == null || entry.velocity.y.length < 2) entry.velocity.y = [-140, -175];
        }

        if (entry.acceleration == null)
            entry.acceleration = {x: [0, 0], y: [550, 550]};
        else
        {
            if (entry.acceleration.x == null || entry.acceleration.x.length < 2) entry.acceleration.x = [0, 0];
            if (entry.acceleration.y == null || entry.acceleration.y.length < 2) entry.acceleration.y = [550, 550];
        }

        if (entry.ease == null) entry.ease = "linear"; 
        if (entry.timeMult == null) entry.timeMult = 1.0;

        return entry;
    }

    private static function validateComboEntry(entry:RatingSpriteEntry):RatingSpriteEntry
    {
        if (entry == null) entry = {};

        if (entry.offset == null || entry.offset.length < 2) entry.offset = [0, 0];
        if (entry.scale == null || entry.scale.length < 2) entry.scale = [0.45, 0.45];

        if (entry.velocity == null)
            entry.velocity = {x: [-5, 5], y: [-130, -150]}; 
        else
        {
            if (entry.velocity.x == null || entry.velocity.x.length < 2) entry.velocity.x = [-5, 5];
            if (entry.velocity.y == null || entry.velocity.y.length < 2) entry.velocity.y = [-130, -150];
        }

        if (entry.acceleration == null)
            entry.acceleration = {x: [0, 0], y: [250, 300]};
        else
        {
            if (entry.acceleration.x == null || entry.acceleration.x.length < 2) entry.acceleration.x = [0, 0];
            if (entry.acceleration.y == null || entry.acceleration.y.length < 2) entry.acceleration.y = [250, 300];
        }

        if (entry.ease == null) entry.ease = "linear"; 
        if (entry.timeMult == null) entry.timeMult = 1.0;

        return entry;
    }

    public static function reloadAll():Void
    {
        list.clear();
        init();
    }
}