package backend.registries.menus;

import json2object.JsonParser;

import lime.app.Application;
import lime.graphics.Image;
import lime.utils.Assets;

import backend.utils.WindowUtil;
import backend.utils.RegistryUtil;

typedef MainMenuData =
{
    @:optional var background:MainMenuBackgroundData;
    @:optional var options:Array<MainMenuOptionData>;
}

typedef MainMenuOptionData =
{
    @:optional var name:String;
    @:optional var targetState:String;
    @:optional var sprite:MainMenuObjectData;
}

typedef MainMenuBackgroundData =
{
    @:optional var normal:MainMenuObjectData;
    @:optional var flicker:MainMenuObjectData;
}

typedef MainMenuObjectData =
{
    @:optional var path:String;
    @:optional var visible:Bool;
    @:optional var position:Array<Int>;
    @:optional var scale:Array<Float>;
    @:optional var alpha:Float;
    @:optional var angle:Int;

    @:optional var animations:Array<MainMenuAnimationData>;
}

typedef MainMenuAnimationData = 
{
    @:optional var name:String;
    @:optional var prefix:String;
    @:optional var indices:Array<Int>;
    @:optional var offsets:Array<Float>;
    @:optional var looped:Bool;
    @:optional var fps:Int;
}

class MainMenuRegistry
{
    public static var data:MainMenuData;
    private static var parser:JsonParser<MainMenuData> = new JsonParser<MainMenuData>();

    public static function load(?force:Bool = true):Void
    {
        if (data != null && !force)
            return;

        var rawData:String = "{}";

        #if sys
        if (Paths.exists('data/menus/mainMenu.json'))
            rawData = Paths.data('mainMenu.json', 'data/menus');
        #end

        parser.fromJson(rawData, 'mainMenu.json');
        RegistryUtil.reportErrors('mainMenu.json', parser.errors);

        data = validateData(parser.value);
    }

    private static function validateData(data:MainMenuData):MainMenuData
    {
        if (data == null) data = {};

        if (data.background == null)
            data.background = {normal: null, flicker: null};

        data.background.normal = validateObjectData(data.background.normal);
        data.background.flicker = validateObjectData(data.background.flicker);

        if (data.options == null) 
            data.options = [];
        else 
        {
            for (i in 0...data.options.length)
                data.options[i] = validateOptionData(data.options[i]);
        }

        return data;
    }

    private static function validateOptionData(option:MainMenuOptionData):MainMenuOptionData
    {
        if (option == null) option = {};

        if (option.name == null) option.name = "unknown";
        if (option.targetState == null) option.targetState = "";

        option.sprite = validateObjectData(option.sprite);

        return option;
    }

    private static function validateObjectData(obj:MainMenuObjectData):MainMenuObjectData
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

    private static function validateAnimations(animations:Array<MainMenuAnimationData>):Void
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
}