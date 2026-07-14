package backend.registries.ui;

import json2object.JsonParser;
import haxe.io.Path;

import backend.utils.RegistryUtil;

typedef DialogueSkinData =
{
    @:optional var box:DialogueBoxData;
    @:optional var portraits:DialoguePortraitData;
    @:optional var text:DialogueTextData;
}

typedef DialogueBoxData =
{
    @:optional var path:String;
    @:optional var alpha:Null<Float>;
    @:optional var position:Array<Int>;
    @:optional var antialiasing:Null<Bool>;
    @:optional var scale:Array<Float>;

    @:optional var animations:Array<DialogueAnimationEntry>;
}

typedef DialoguePortraitData =
{
    @:optional var left:DialoguePortraitEntry;
    @:optional var center:DialoguePortraitEntry;
    @:optional var right:DialoguePortraitEntry;
}

typedef DialoguePortraitEntry =
{
    @:optional var position:Array<Int>;

    @:optional var xTween:DialoguePortraitTweenEntry;
    @:optional var yTween:DialoguePortraitTweenEntry;
    @:optional var scaleTween:DialoguePortraitTweenEntry;
    @:optional var alphaTween:DialoguePortraitTweenEntry;
    @:optional var angleTween:DialoguePortraitTweenEntry;
}

typedef DialoguePortraitTweenEntry = 
{
    @:optional var enabled:Null<Bool>;
    @:optional var ease:String;
    @:optional var duration:Null<Float>;
    @:optional var values:DialoguePortraitTweenValue;
}

typedef DialoguePortraitTweenValue =
{
    @:optional var from:Null<Float>;
    @:optional var to:Null<Float>;
}

typedef DialogueTextData = 
{
    @:optional var fonts:Array<DialogueTextFontData>;
}

typedef DialogueTextFontData = 
{
    @:optional var name:String;
    @:optional var file:String;
    @:optional var color:String;
    @:optional var fieldWidth:Null<Int>;
    @:optional var antialiasing:Null<Bool>;
    @:optional var offsets:Array<Int>;

    @:optional var borderColor:String;
    @:optional var borderSize:Null<Float>;

    @:optional var shadow:DialogueTextShadowData;

    @:optional var scale:Array<Float>;
    @:optional var size:Null<Int>;
}

typedef DialogueTextShadowData =
{
    @:optional var x:Null<Int>;
    @:optional var y:Null<Int>;
}

typedef DialogueTextDropShadowData =
{
    @:optional var enabled:Null<Bool>;
    @:optional var alpha:Null<Float>;
    @:optional var color:String;
    @:optional var offset:Array<Int>;
}

typedef DialogueCharacterData =
{
    @:optional var name:String;
    @:optional var color:String;

    @:optional var folder:String;

    @:optional var expressions:Array<DialogueCharacterExpressionEntry>;
}

typedef DialogueCharacterExpressionEntry =
{
    @:optional var name:String;

    @:optional var position:Array<Int>;
    @:optional var scale:Array<Float>;
    @:optional var alpha:Null<Float>;
    @:optional var angle:Null<Int>;
    @:optional var antialiasing:Null<Bool>;

    @:optional var animations:Array<DialogueAnimationEntry>;
}

typedef DialogueAnimationEntry =
{
    @:optional var name:String;
    @:optional var prefix:String;
    @:optional var offsets:Array<Int>;
    @:optional var indices:Array<Int>;
    @:optional var looped:Null<Bool>;
    @:optional var fps:Null<Int>;
    @:optional var flip:Array<Bool>;
}

typedef DialogueSongData =
{
    @:optional var skin:String;
    @:optional var startingBoxSuffix:String;
    @:optional var song:DialogueSongThemeData;

    @:optional var dialogue:Array<DialogueSongInteractionEntry>;
}

typedef DialogueSongThemeData =
{
    @:optional var path:String;
    @:optional var looped:Null<Bool>;
    @:optional var volume:Null<Float>;

    @:optional var fadeIn:Null<Bool>;
    @:optional var fadeOut:Null<Bool>;

    @:optional var fadeInTime:Null<Float>;
    @:optional var fadeOutTime:Null<Float>;
}

typedef DialogueSongInteractionEntry =
{
    @:optional var direction:String;

    @:optional var character:String;
    @:optional var expression:String;

    @:optional var boxSuffix:String;

    @:optional var anim:String;

    @:optional var audio:DialogueSongAudioData;

    @:optional var font:String;

    @:optional var event:String;

    @:optional var field:DialogueSongFieldData;
}

typedef DialogueSongFieldData =
{
    @:optional var speed:Null<Float>;

    @:optional var audio:DialogueSongAudioData;

    @:optional var text:String;
}

typedef DialogueSongAudioData =
{
    @:optional var path:String;
    @:optional var volume:Null<Float>;
}

class DialogueRegistry
{
    inline static final PATH_SKINS:String = 'data/dialogue/skins';
    inline static final PATH_CHARACTERS:String = 'data/dialogue/characters';
    inline static final PATH_SONGS:String = 'data/dialogue/songs';

    public static var skinList:Map<String, DialogueSkinData> = new Map();
    public static var characterList:Map<String, DialogueCharacterData> = new Map();
    public static var songList:Map<String, DialogueSongData> = new Map();

    private static var skinParser:JsonParser<DialogueSkinData> = new JsonParser<DialogueSkinData>();
    private static var characterParser:JsonParser<DialogueCharacterData> = new JsonParser<DialogueCharacterData>();
    private static var songParser:JsonParser<DialogueSongData> = new JsonParser<DialogueSongData>();

    public static function init():Void
    {
        #if sys
        for (file in Paths.readDirectory(PATH_SKINS))
            if (Path.extension(file) == "json") reloadSkin(Path.withoutExtension(file));

        for (file in Paths.readDirectory(PATH_CHARACTERS))
            if (Path.extension(file) == "json") reloadCharacter(Path.withoutExtension(file));

        for (file in Paths.readDirectory(PATH_SONGS))
            if (Path.extension(file) == "json") reloadSong(Path.withoutExtension(file));
        #end
    }

    public static inline function getSkin(name:String):DialogueSkinData
    {
        if (!skinList.exists(name)) reloadSkin(name);
        return skinList.get(name); 
    }

    public static inline function getCharacter(name:String):DialogueCharacterData
    {
        if (!characterList.exists(name)) reloadCharacter(name);
        return characterList.get(name);
    }

    public static inline function getSong(name:String):DialogueSongData
    {
        if (!songList.exists(name)) reloadSong(name);
        return songList.get(name);
    }

    public static function reload(name:String):Void
    {
        reloadSkin(name);
        reloadCharacter(name);
        reloadSong(name);
    }

    public static function reloadSkin(name:String):Void
    {
        var rawData:String = "{}";
        #if sys
        if (Paths.exists('$PATH_SKINS/$name.json'))
            rawData = Paths.data('$name.json', PATH_SKINS);
        #end
        skinParser.fromJson(rawData, '$PATH_SKINS/$name.json');
        RegistryUtil.reportErrors('$PATH_SKINS/$name.json', skinParser.errors);
        skinList.set(name, validateSkinData(skinParser.value));
    }

    public static function reloadCharacter(name:String):Void
    {
        var rawData:String = "{}";
        #if sys
        if (Paths.exists('$PATH_CHARACTERS/$name.json'))
            rawData = Paths.data('$name.json', PATH_CHARACTERS);
        #end
        characterParser.fromJson(rawData, '$PATH_CHARACTERS/$name.json');
        RegistryUtil.reportErrors('$PATH_CHARACTERS/$name.json', characterParser.errors);
        characterList.set(name, validateCharacterData(characterParser.value));
    }

    public static function reloadSong(name:String):Void
    {
        var rawData:String = "{}";
        #if sys
        if (Paths.exists('$PATH_SONGS/$name.json'))
            rawData = Paths.data('$name.json', PATH_SONGS);
        #end
        songParser.fromJson(rawData, '$PATH_SONGS/$name.json');
        RegistryUtil.reportErrors('$PATH_SONGS/$name.json', songParser.errors);
        songList.set(name, validateSongData(songParser.value));
    }

    private static function validateAnimationEntry(entry:DialogueAnimationEntry):DialogueAnimationEntry
    {
        if (entry == null) entry = {};

        if (entry.name == null) entry.name = "";
        if (entry.prefix == null) entry.prefix = "";

        if (entry.offsets == null || entry.offsets.length < 2) entry.offsets = [0, 0];
        if (entry.looped == null) entry.looped = false;
        if (entry.fps == null) entry.fps = 24;
        if (entry.flip == null || entry.flip.length < 2) entry.flip = [false, false];

        return entry;
    }

    private static function validateTweenEntry(entry:DialoguePortraitTweenEntry):DialoguePortraitTweenEntry
    {
        if (entry == null) entry = {};

        if (entry.enabled == null) entry.enabled = false;

        if (entry.ease == null) entry.ease = "linear";
        if (entry.duration == null) entry.duration = 1.0;

        if (entry.values == null) entry.values = {};

        if (entry.values.from == null) entry.values.from = 0.0;
        if (entry.values.to == null) entry.values.to = 1.0;

        return entry;
    }

    private static function validatePortraitEntry(entry:DialoguePortraitEntry):DialoguePortraitEntry
    {
        if (entry == null) entry = {};
        
        if (entry.position == null || entry.position.length < 2) entry.position = [0, 0];
        
        entry.xTween = validateTweenEntry(entry.xTween);
        entry.yTween = validateTweenEntry(entry.yTween);
        entry.scaleTween = validateTweenEntry(entry.scaleTween);
        entry.alphaTween = validateTweenEntry(entry.alphaTween);
        entry.angleTween = validateTweenEntry(entry.angleTween);

        return entry;
    }

    private static function validateSkinData(data:DialogueSkinData):DialogueSkinData
    {
        if (data == null) data = {};

        if (data.box == null) data.box = {};

        if (data.box.path == null) data.box.path = "";

        if (data.box.alpha == null) data.box.alpha = 1.0;
        if (data.box.position == null || data.box.position.length < 2) data.box.position = [0, 0];
        if (data.box.antialiasing == null) data.box.antialiasing = true;
        if (data.box.scale == null || data.box.scale.length < 2) data.box.scale = [1.0, 1.0];
        
        if (data.box.animations == null) data.box.animations = [];

        for (i in 0...data.box.animations.length)
            data.box.animations[i] = validateAnimationEntry(data.box.animations[i]);

        if (data.portraits == null) data.portraits = {};

        data.portraits.left = validatePortraitEntry(data.portraits.left);
        data.portraits.center = validatePortraitEntry(data.portraits.center);
        data.portraits.right = validatePortraitEntry(data.portraits.right);

        if (data.text == null) data.text = {};
        
        if (data.text.fonts == null) data.text.fonts = [];

        for (i in 0...data.text.fonts.length)
        {
            var font = data.text.fonts[i];

            if (font == null)
            {
                data.text.fonts[i] = {};
                font = data.text.fonts[i];
            }

            if (font.name == null) font.name = "vcr";
            if (font.file == null) font.file = "vcr.ttf";
            if (font.color == null) font.color = "#FFFFFF";
            if (font.fieldWidth == null) font.fieldWidth = 0;
            if (font.borderSize == null) font.borderSize = 0;
            if (font.antialiasing == null) font.antialiasing = true;
            if (font.offsets == null || font.offsets.length < 2) font.offsets = [0, 0];
            if (font.scale == null || font.scale.length < 2) font.scale = [1, 1];
            if (font.size == null) font.size = 32;

            if (font.shadow == null) font.shadow = {};

            if (font.shadow.x == null) font.shadow.x = 0;
            if (font.shadow.y == null) font.shadow.y = 0;
        }

        return data;
    }

    private static function validateCharacterData(data:DialogueCharacterData):DialogueCharacterData
    {
        if (data == null) data = {};
        
        if (data.name == null) data.name = "Unknown";
        if (data.color == null) data.color = "#FFFFFF";
        if (data.folder == null) data.folder = "";

        if (data.expressions == null) data.expressions = [];

        for (i in 0...data.expressions.length)
        {
            var exp = data.expressions[i];

            if (exp == null)
            {
                data.expressions[i] = {};
                exp = data.expressions[i];
            }
            
            if (exp.name == null) exp.name = "default";
            if (exp.position == null || exp.position.length < 2) exp.position = [0, 0];
            if (exp.scale == null || exp.scale.length < 2) exp.scale = [1.0, 1.0];
            if (exp.alpha == null) exp.alpha = 1.0;
            if (exp.angle == null) exp.angle = 0;
            if (exp.antialiasing == null) exp.antialiasing = true;
            
            if (exp.animations == null) exp.animations = [];

            for (j in 0...exp.animations.length)
                exp.animations[j] = validateAnimationEntry(exp.animations[j]);
        }

        return data;
    }

    private static function validateSongData(data:DialogueSongData):DialogueSongData
    {
        if (data == null) data = {};
        
        if (data.skin == null) data.skin = "default";
        if (data.startingBoxSuffix == null) data.startingBoxSuffix = "";

        if (data.song == null) data.song = {};

        if (data.song.path == null) data.song.path = "";
        if (data.song.looped == null) data.song.looped = true;
        if (data.song.volume == null) data.song.volume = 1.0;
        if (data.song.fadeIn == null) data.song.fadeIn = false;
        if (data.song.fadeOut == null) data.song.fadeOut = false;
        if (data.song.fadeInTime == null) data.song.fadeInTime = 1.0;
        if (data.song.fadeOutTime == null) data.song.fadeOutTime = 1.0;

        if (data.dialogue == null) data.dialogue = [];

        for (i in 0...data.dialogue.length)
        {
            var line = data.dialogue[i];

            if (line == null)
            {
                data.dialogue[i] = {};
                line = data.dialogue[i];
            }
            
            if (line.character == null) line.character = "";
            if (line.direction == null) line.direction = "left";
            if (line.boxSuffix == null) line.boxSuffix = "";
            if (line.font == null) line.font = "vcr";
            if (line.expression == null) line.expression = "";
            if (line.anim == null) line.anim = "";
            if (line.event == null) line.event = "";

            if (line.audio == null) line.audio = {};
            if (line.audio.path == null) line.audio.path = "";
            if (line.audio.volume == null) line.audio.volume = 1.0;

            if (line.field == null) line.field = {};
            if (line.field.speed == null) line.field.speed = 0.05;
            if (line.field.text == null) line.field.text = "";

            if (line.field.audio == null) line.field.audio = {};
            if (line.field.audio.path == null) line.field.audio.path = "";
            if (line.field.audio.volume == null) line.field.audio.volume = 1.0;
        }

        return data;
    }

    public static function reloadAll():Void
    {
        skinList.clear();
        characterList.clear();
        songList.clear();
        
        init();
    }
}