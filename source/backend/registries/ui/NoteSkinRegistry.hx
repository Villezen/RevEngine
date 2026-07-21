package backend.registries.ui;

import json2object.JsonParser;
import haxe.io.Path;

import backend.utils.RegistryUtil;

typedef NoteStyleData =
{
    @:optional var type:String;
    @:optional var textureBox:Array<Int>;

    @:optional var position:Array<Int>;
    @:optional var antialiasing:Null<Bool>;
    @:optional var noteSize:Null<Float>;
    @:optional var strumSize:Null<Float>;
    @:optional var strumWidth:Null<Int>;
    @:optional var sustainAlpha:Null<Float>;

    @:optional var hasCovers:Null<Bool>;
    @:optional var hasSplashes:Null<Bool>;

    @:optional var fallbackCovers:String;
    @:optional var fallbackSplashes:String;

    @:optional var animations:BaseAnimations;
}

typedef NoteSplashData =
{
    @:optional var type:String;
    @:optional var textureBox:Array<Int>;

    @:optional var position:Array<Int>;
    @:optional var size:Array<Float>;
    @:optional var alpha:Null<Float>;
    @:optional var antialiasing:Null<Bool>;
    @:optional var animations:BaseAnimations;
}

typedef HoldCoverData =
{
    @:optional var type:String;
    @:optional var textureBox:Array<Int>;

    @:optional var position:Array<Int>;
    @:optional var size:Array<Float>;
    @:optional var alpha:Null<Float>;
    @:optional var antialiasing:Null<Bool>;
    @:optional var animations:BaseAnimations;
}

typedef BaseAnimations =
{
    @:optional var normal:Array<BaseAnimationData>;
    @:optional var extraKeys:Array<BaseAnimationData>;
}

typedef BaseAnimationData =
{
    @:optional var name:String;
    @:optional var prefix:String;
    @:optional var fps:Null<Int>;
    @:optional var offsets:Array<Float>;
}

class NoteSkinRegistry
{
    inline static final PATH_STYLES:String = 'data/notes/styles';
    inline static final PATH_SPLASHES:String = 'data/notes/splashes';
    inline static final PATH_COVERS:String = 'data/notes/covers';

    public static var styleList:Map<String, NoteStyleData> = new Map();
    public static var splashList:Map<String, NoteSplashData> = new Map();
    public static var coverList:Map<String, HoldCoverData> = new Map();

    private static var styleParser:JsonParser<NoteStyleData> = new JsonParser<NoteStyleData>();
    private static var splashParser:JsonParser<NoteSplashData> = new JsonParser<NoteSplashData>();
    private static var coverParser:JsonParser<HoldCoverData> = new JsonParser<HoldCoverData>();

    public static function init():Void
    {
        #if sys
        for (file in Paths.readDirectory(PATH_STYLES))
            if (Path.extension(file) == "json") reloadStyle(Path.withoutExtension(file));

        for (file in Paths.readDirectory(PATH_SPLASHES))
            if (Path.extension(file) == "json") reloadSplash(Path.withoutExtension(file));

        for (file in Paths.readDirectory(PATH_COVERS))
            if (Path.extension(file) == "json") reloadCover(Path.withoutExtension(file));
        #end
    }

    public static inline function getStyle(name:String):NoteStyleData
    {
        if (!styleList.exists(name)) reloadStyle(name);
        return styleList.get(name);
    }

    public static inline function getSplash(name:String):NoteSplashData
    {
        if (!splashList.exists(name)) reloadSplash(name);
        return splashList.get(name);
    }

    public static inline function getCover(name:String):HoldCoverData
    {
        if (!coverList.exists(name)) reloadCover(name);
        return coverList.get(name);
    }

    public static function reload(name:String):Void
    {
        reloadStyle(name);
        reloadSplash(name);
        reloadCover(name);
    }

    public static function reloadStyle(name:String):Void
    {
        var rawData:String = "{}";
        #if sys
        if (Paths.exists('$PATH_STYLES/$name.json'))
            rawData = Paths.data('$name.json', PATH_STYLES);
        #end
        styleParser.fromJson(rawData, '$PATH_STYLES/$name.json');
        RegistryUtil.reportErrors('$PATH_STYLES/$name.json', styleParser.errors);
        styleList.set(name, validateStyleData(styleParser.value));
    }

    public static function reloadSplash(name:String):Void
    {
        var rawData:String = "{}";
        #if sys
        if (Paths.exists('$PATH_SPLASHES/$name.json'))
            rawData = Paths.data('$name.json', PATH_SPLASHES);
        #end
        splashParser.fromJson(rawData, '$PATH_SPLASHES/$name.json');
        RegistryUtil.reportErrors('$PATH_SPLASHES/$name.json', splashParser.errors);
        splashList.set(name, validateSplashData(splashParser.value));
    }

    public static function reloadCover(name:String):Void
    {
        var rawData:String = "{}";
        #if sys
        if (Paths.exists('$PATH_COVERS/$name.json'))
            rawData = Paths.data('$name.json', PATH_COVERS);
        #end
        coverParser.fromJson(rawData, '$PATH_COVERS/$name.json');
        RegistryUtil.reportErrors('$PATH_COVERS/$name.json', coverParser.errors);
        coverList.set(name, validateCoverData(coverParser.value));
    }

    private static function validateBaseAnimations(anim:BaseAnimations):BaseAnimations
    {
        if (anim == null) anim = {};
        if (anim.normal == null) anim.normal = [];
        if (anim.extraKeys == null) anim.extraKeys = [];

        var validateDataList = function(list:Array<BaseAnimationData>)
        {
            var i:Int = list.length;
            
            while (--i >= 0)
                if (list[i] == null) list.splice(i, 1);

            for (item in list)
            {
                if (item.name == null) item.name = "";
                if (item.prefix == null) item.prefix = "";
                if (item.fps == null) item.fps = 24;
                if (item.offsets == null || item.offsets.length < 2) item.offsets = [0.0, 0.0];
            }
        };

        validateDataList(anim.normal);
        validateDataList(anim.extraKeys);
        
        return anim;
    }

    private static function validateStyleData(data:NoteStyleData):NoteStyleData
    {
        if (data == null) data = {};

        if (data.type == null) data.type = "COMBINED";
        if (data.textureBox == null || data.textureBox.length < 2) data.textureBox = [17, 17];

        if (data.position == null || data.position.length < 2) data.position = [0, 0];
        if (data.antialiasing == null) data.antialiasing = true;

        if (data.noteSize == null) data.noteSize = 0.63;
        if (data.strumSize == null) data.strumSize = 0.63;

        if (data.strumWidth == null) data.strumWidth = 150;

        if (data.sustainAlpha == null) data.sustainAlpha = 1.0;

        if (data.hasCovers == null) data.hasCovers = true;
        if (data.hasSplashes == null) data.hasSplashes = true;

        if (data.fallbackCovers == null) data.fallbackCovers = "default";
        if (data.fallbackSplashes == null) data.fallbackSplashes = "default";

        data.animations = validateBaseAnimations(data.animations);

        return data;
    }

    private static function validateSplashData(data:NoteSplashData):NoteSplashData
    {
        if (data == null) data = {};
        
        if (data.type == null) data.type = "COMBINED";
        if (data.textureBox == null || data.textureBox.length < 2) data.textureBox = [17, 17];

        if (data.position == null || data.position.length < 2) data.position = [0, 0];
        if (data.size == null || data.size.length < 2) data.size = [0.8, 0.8];
        if (data.alpha == null) data.alpha = 1.0;
        if (data.antialiasing == null) data.antialiasing = true;

        data.animations = validateBaseAnimations(data.animations);

        return data;
    }

    private static function validateCoverData(data:HoldCoverData):HoldCoverData
    {
        if (data == null) data = {};
        
        if (data.type == null) data.type = "COMBINED";
        if (data.textureBox == null || data.textureBox.length < 2) data.textureBox = [17, 17];

        if (data.position == null || data.position.length < 2) data.position = [0, 0];
        if (data.size == null || data.size.length < 2) data.size = [0.7, 0.7];
        if (data.alpha == null) data.alpha = 1.0;
        if (data.antialiasing == null) data.antialiasing = true;

        data.animations = validateBaseAnimations(data.animations);
        
        return data;
    }

    public static function reloadAll():Void
    {
        styleList.clear();
        splashList.clear();
        coverList.clear();
        init();
    }
}