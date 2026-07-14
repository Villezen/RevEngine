package backend.registries.menus;

import json2object.JsonParser;

import lime.app.Application;
import lime.graphics.Image;
import lime.utils.Assets;

import backend.utils.WindowUtil;
import backend.utils.RegistryUtil;

typedef FreeplayData =
{
    @:optional var theme:FreeplayThemeData;
    @:optional var difficulties:Array<String>;
}

typedef FreeplayThemeData =
{
    @:optional var path:String;
    @:optional var bpm:Int;
}

class FreeplayRegistry
{
    public static var data:FreeplayData;
    private static var parser:JsonParser<FreeplayData> = new JsonParser<FreeplayData>();

    public static function load(?force:Bool = true):Void
    {
        if (data != null && !force)
            return;

        var rawData:String = "{}";

        #if sys
        if (Paths.exists('data/menus/freeplay.json'))
            rawData = Paths.data('freeplay.json', 'data/menus');
        #end

        parser.fromJson(rawData, 'freeplay.json');
        RegistryUtil.reportErrors('freeplay.json', parser.errors);

        data = validateData(parser.value);
    }

    private static function validateData(data:FreeplayData):FreeplayData
    {
        if (data == null) data = {};

        data.theme = validateThemeData(data.theme);
        if (data.difficulties == null) data.difficulties = ["easy", "normal", "hard", "erect", "nightmare"];

        return data;
    }

    private static function validateThemeData(theme:FreeplayThemeData):FreeplayThemeData
    {
        if (theme == null) theme = {};

        if (theme.path == null) theme.path = "menus/freeplay"; 
        if (theme.bpm == null) theme.bpm = 145;

        return theme;
    }
}