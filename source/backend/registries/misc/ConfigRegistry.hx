package backend.registries.misc;

import json2object.JsonParser;

import lime.app.Application;
import lime.graphics.Image;
import lime.utils.Assets;

import backend.utils.WindowUtil;
import backend.utils.RegistryUtil;

typedef ConfigData =
{
    @:optional var song:ConfigMenuSongData;
    @:optional var window:ConfigWindowData;
    @:optional var flags:ConfigPrefsData;
    @:optional var overrides:ConfigOverrideData;
}

typedef ConfigMenuSongData =
{
    @:optional var path:String;
    @:optional var bpm:Float;

    @:optional var skipTimestamp:Int;
}

typedef ConfigWindowData =
{
    @:optional var title:String;
    @:optional var targetRatio:Array<Int>;
    @:optional var icon:String;
    @:optional var resizable:Null<Bool>;
}

typedef ConfigPrefsData =
{
    @:optional var gitarooPause:Null<Bool>;
    @:optional var useLegacyFreeplay:Null<Bool>;
}

typedef ConfigOverrideData = 
{
    @:optional var states:Array<StateOverrideEntry>;
    @:optional var transitions:Array<TransitionOverrideEntry>;
}

typedef StateOverrideEntry =
{
    @:optional var state:String;
    @:optional var target:String;
}

typedef TransitionOverrideEntry =
{
    @:optional var state:String;
    @:optional var phase:TransitionPhaseEntry;
}

typedef TransitionPhaseEntry =
{
    @:alias("in") @:optional var transitionIn:String;
    @:alias("out") @:optional var transitionOut:String;
}

class ConfigRegistry
{
    public static var data:ConfigData;
    private static var parser:JsonParser<ConfigData> = new JsonParser<ConfigData>();

    public static function load(?force:Bool = true):Void
    {
        if (data != null && !force)
            return;

        var rawData:String = "{}";

        #if sys
        if (Paths.exists('config.json'))
            rawData = Paths.data('config.json', '');
        #end

        parser.fromJson(rawData, 'config.json');
        RegistryUtil.reportErrors('config.json', parser.errors);

        data = validateData(parser.value);
    }

    public static function execute():Void
    {
        if (data == null) load();

        Application.current.window.title = data.window.title;
        Application.current.window.resizable = data.window.resizable;

        var targetRatio:Float = data.window.targetRatio[0] / data.window.targetRatio[1];

        var gameHeight:Int = FlxG.initialHeight;
        var gameWidth:Int = Std.int(gameHeight * targetRatio);

        if (FlxG.width != gameWidth || FlxG.height != gameHeight)
            FlxG.resizeGame(gameWidth, gameHeight);

        var screenRes = WindowUtil.getScreenResolution();

        var maxWidth:Float = screenRes[0] / 1.5;
        var maxHeight:Float = screenRes[1] / 1.5;

        var scale:Float = Math.min(maxWidth / gameWidth, maxHeight / gameHeight);

        WindowUtil.resizeWindow(Std.int(gameWidth * scale), Std.int(gameHeight * scale));
        WindowUtil.centerWindow();

        var imagePath:String = Paths.image(data.window.icon);
        var icon:Image = null;

        if (imagePath != null && imagePath != "")
        {
            try
            {
                if (Assets.exists(imagePath))
                    icon = Assets.getImage(imagePath);
                else
                    icon = Image.fromFile(imagePath);
            }
            catch (e:Dynamic)
            {
                trace('Failed to load window icon "${data.window.icon}": $e', "WARNING");
            }
        }

        if (icon != null)
            Application.current.window.setIcon(icon);
    }

    private static function validateData(data:ConfigData):ConfigData
    {
        if (data == null) data = {};

        if (data.song == null) data.song = {};

        if (data.song.path == null) data.song.path = "music/freakyMenu";
        if (data.song.bpm == null) data.song.bpm = 102;
        if (data.song.skipTimestamp == null) data.song.skipTimestamp = 18882;

        if (data.window == null) data.window = {};
        if (data.window.title == null) data.window.title = "Friday Night Funkin'";
        if (data.window.targetRatio == null || data.window.targetRatio.length < 2 || data.window.targetRatio[0] <= 0 || data.window.targetRatio[1] <= 0) data.window.targetRatio = [16, 9];
        if (data.window.icon == null) data.window.icon = "engine/icons/default";
        if (data.window.resizable == null) data.window.resizable = true;

        if (data.flags == null) data.flags = {};

        if (data.flags.gitarooPause == null) data.flags.gitarooPause = true;
        if (data.flags.useLegacyFreeplay == null) data.flags.useLegacyFreeplay = true;

        if (data.overrides == null) data.overrides = {};
        if (data.overrides.states == null) data.overrides.states = [];
        if (data.overrides.transitions == null) data.overrides.transitions = [];

        for (i in 0...data.overrides.states.length)
        {
            var overrideEntry = data.overrides.states[i];

            if (overrideEntry == null)
            {
                data.overrides.states[i] = {state: "", target: ""};
                continue;
            }

            if (overrideEntry.state == null) overrideEntry.state = "";
            if (overrideEntry.target == null) overrideEntry.target = "";
        }

        for (i in 0...data.overrides.transitions.length)
        {
            var transEntry = data.overrides.transitions[i];

            if (transEntry == null)
            {
                data.overrides.transitions[i] = {state: "", phase: {transitionIn: "", transitionOut: ""}};
                continue;
            }
            
            if (transEntry.state == null) transEntry.state = "";
            
            if (transEntry.phase == null) transEntry.phase = {};
            if (transEntry.phase.transitionIn == null) transEntry.phase.transitionIn = "";
            if (transEntry.phase.transitionOut == null) transEntry.phase.transitionOut = "";
        }

        return data;
    }
}