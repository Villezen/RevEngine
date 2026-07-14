package backend.registries.menus;

import json2object.JsonParser;

import lime.app.Application;
import lime.graphics.Image;
import lime.utils.Assets;

import backend.utils.WindowUtil;
import backend.utils.RegistryUtil;

typedef TitleMenuData =
{
    @:optional var background:TitleMenuObjectData;
    @:optional var logo:TitleMenuObjectData;
    @:optional var button:TitleMenuObjectData;
    @:optional var bopper:TitleMenuObjectData;
    
    @:optional var intro:TitleMenuIntroTextData;
}

typedef TitleMenuIntroTextData = 
{
    @:optional var skip:Bool;

    @:optional var events:Array<TitleMenuEventData>;
    @:optional var introText:Array<Array<String>>;
}

typedef TitleMenuEventData =
{
    @:optional var beat:Int;
    @:optional var text:String;
    @:optional var action:Array<String>;
}

typedef TitleMenuObjectData =
{
    @:optional var path:String;
    @:optional var visible:Bool;
    @:optional var position:Array<Int>;
    @:optional var scale:Array<Float>;
    @:optional var alpha:Float;
    @:optional var angle:Int;

    @:optional var animations:Array<TitleMenuAnimationData>;
}

typedef TitleMenuAnimationData = 
{
    @:optional var name:String;
    @:optional var prefix:String;
    @:optional var indices:Array<Int>;
    @:optional var offsets:Array<Int>;
    @:optional var looped:Null<Bool>;
    @:optional var fps:Null<Int>;
}

class TitleMenuRegistry
{
    public static var data:TitleMenuData;
    private static var parser:JsonParser<TitleMenuData> = new JsonParser<TitleMenuData>();

    public static function load(?force:Bool = true):Void
    {
        if (data != null && !force)
            return;

        var rawData:String = "{}";

        #if sys
        if (Paths.exists('data/menus/title.json'))
            rawData = Paths.data('title.json', 'data/menus');
        #end

        parser.fromJson(rawData, 'title.json');
        RegistryUtil.reportErrors('title.json', parser.errors);

        data = validateData(parser.value);
    }

    private static function validateData(data:TitleMenuData):TitleMenuData
    {
        if (data == null) data = {};

        if (data.intro == null) data.intro = {};
        
        if (data.intro.skip == null) data.intro.skip = false;
        
        if (data.intro.introText == null) 
            data.intro.introText = [["swagshit", "moneymoney"]];

        if (data.intro.events == null) 
            data.intro.events = [];
        else 
            validateEvents(data.intro.events);

        data.background = validateObjectData(data.background, "");
        data.logo = validateObjectData(data.logo, "menus/title/logo");
        data.button = validateObjectData(data.button, "menus/title/text"); 
        data.bopper = validateObjectData(data.bopper, "menus/title/gfDance");

        return data;
    }

    private static function validateObjectData(obj:TitleMenuObjectData, defaultPath:String):TitleMenuObjectData
    {
        if (obj == null) obj = {};

        if (obj.path == null) obj.path = defaultPath;
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

    private static function validateEvents(events:Array<TitleMenuEventData>):Void
    {
        for (event in events)
        {
            if (event == null) continue;
            
            if (event.beat == null) event.beat = 0;
            if (event.text == null) event.text = "";
            if (event.action == null) event.action = []; 
        }
    }

    private static function validateAnimations(animations:Array<TitleMenuAnimationData>):Void
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