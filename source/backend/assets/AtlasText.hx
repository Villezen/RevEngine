package backend.assets;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.util.FlxStringUtil;

import backend.utils.tools.TagTools.ITaggable;

class AtlasText extends FlxTypedSpriteGroup<AtlasChar> implements ITaggable
{
    static var fonts:Map<AtlasFont, AtlasFontData> = new Map<AtlasFont, AtlasFontData>();

    public var tag:String = "";

    public var text(default, set):String = "";
    public var font(default, null):AtlasFontData;
    public var atlas(get, never):FlxAtlasFrames;

    inline function get_atlas():FlxAtlasFrames
    {
        return font.atlas;
    }

    public var caseAllowed(get, never):Case;

    inline function get_caseAllowed():Case
    {
        return font.caseAllowed;
    }

    public var maxHeight(get, never):Float;

    inline function get_maxHeight():Float
    {
        return font.maxHeight;
    }

    public function new(?x:Float = 0, ?y:Float = 0, text:String = "", fontName:AtlasFont = AtlasFont.DEFAULT)
    {
        super(x, y);

        if (!fonts.exists(fontName)) fonts.set(fontName, new AtlasFontData(fontName));
        font = fonts.get(fontName);

        this.text = text;
    }

    public static function flushFonts():Void
    {
        fonts.clear();
    }

    function set_text(value:String):String
    {
        if (value == null) value = "";

        final caseValue:String = restrictCase(value);
        final caseText:String = restrictCase(this.text);

        this.text = value;
        if (caseText == caseValue) return value; 

        if (caseValue.indexOf(caseText) == 0)
        {
            appendTextCased(caseValue.substr(caseText.length));
            return this.text;
        }

        value = caseValue;

        group.kill();

        if (value == "") return this.text;

        appendTextCased(caseValue);
        return this.text;
    }

    public function appendText(str:String):Void
    {
        if (str == null) throw "cannot append null";
        if (str == "") return;

        this.text += str;
    }

    function restrictCase(str:String):String
    {
        return switch (caseAllowed)
        {
            case Both: str;
            case Upper: str.toUpperCase();
            case Lower: str.toLowerCase();
        }
    }

    function appendTextCased(str:String):Void
    {
        if (atlas == null) return;

        var charCount:Int = group.countLiving();
        var xPos:Float = 0;
        var yPos:Float = 0;

        if (charCount == -1) charCount = 0;
        else if (charCount > 0)
        {
            var lastChar:AtlasChar = group.members[charCount - 1];
            xPos = lastChar.x + lastChar.width - x;
            yPos = lastChar.y + lastChar.height - maxHeight - y;
        }

        for (splitStr in str.split(""))
        {
            switch (splitStr)
            {
                case " ":
                    xPos += 40;
                case "\n":
                    xPos = 0;
                    yPos += maxHeight;
                case char:
                    var charSprite:AtlasChar;
                    if (group.members.length <= charCount) charSprite = new AtlasChar(0, 0, font, char);
                    else
                    {
                        charSprite = group.members[charCount];
                        charSprite.revive();
                        charSprite.char = char;
                        charSprite.alpha = 1;
                    }
                    charSprite.x = xPos;
                    charSprite.y = yPos + maxHeight - charSprite.height;
                    add(charSprite);

                    xPos += charSprite.width;
                    charCount++;
            }
        }
    }

    public function getWidth():Int
    {
        if (atlas == null) return 0;

        var width:Int = 0;
        for (char in restrictCase(this.text).split(""))
        {
            switch (char)
            {
                case " ":
                    width += 40;
                case char:
                    width += Std.int(font.getCharWidth(char));
            }
        }
        return width;
    }

    override function toString():String
    {
        return "AtlasText, " + FlxStringUtil.getDebugString([LabelValuePair.weak("x", x), LabelValuePair.weak("y", y), LabelValuePair.weak("text", text)]);
    }
}

class AtlasChar extends FlxSprite
{
    public var char(default, set):String;
    public var font(default, null):AtlasFontData;

    public function new(?x:Float = 0, ?y:Float = 0, font:AtlasFontData, char:String)
    {
        super(x, y);

        this.font = font;

        if (font.atlas != null)
            frames = font.atlas;

        this.char = char;
    }

    function set_char(value:String):String
    {
        if (this.char == value) return this.char;

        var indices:Null<Array<Int>> = font.getCharFrames(value);
        if (indices != null)
        {
            animation.add('anim', indices, 24);
            animation.play('anim');
        }

        updateHitbox();

        return this.char = value;
    }
}

class AtlasFontData
{
    static var isLetter:EReg = ~/^[a-zA-Z]$/;
    static var trailingDigits:EReg = ~/\d+$/;

    public var name(default, null):AtlasFont;

    public var atlas(default, null):FlxAtlasFrames;

    public var maxHeight(default, null):Float = 0.0;

    public var caseAllowed(default, null):Case = Both;

    var frameIndices:Map<String, Array<Int>> = new Map<String, Array<Int>>();

    public function new(name:AtlasFont)
    {
        this.name = name;

        atlas = Paths.getSparrowAtlas('alphabet', "images", false, true);

        if (atlas == null)
        {
            trace('Could not find the alphabet atlas for font "$name".', "WARNING");
            return;
        }

        atlas.parent.destroyOnNoUse = false;
        atlas.parent.persist = true;

        var upperChar:EReg = name == BOLD ? ~/^[A-Z] bold\d+$/ : ~/^[A-Z] capital\d+$/;
        var lowerChar:EReg = name == BOLD ? ~/^[a-z] bold\d+$/ : ~/^[a-z] lowercase\d+$/;

        var containsUpper:Bool = false;
        var containsLower:Bool = false;

        for (i in 0...atlas.frames.length)
        {
            var frame = atlas.frames[i];

            var prefix:String = trailingDigits.replace(frame.name, "");
            var group:Array<Int> = frameIndices.get(prefix);
            if (group == null)
            {
                group = new Array<Int>();
                frameIndices.set(prefix, group);
            }
            group.push(i);

            var isUpper:Bool = upperChar.match(frame.name);
            var isLower:Bool = lowerChar.match(frame.name);

            if (isUpper || isLower)
                maxHeight = Math.max(maxHeight, frame.frame.height);

            containsUpper = containsUpper || isUpper;
            containsLower = containsLower || isLower;
        }

        for (group in frameIndices)
            group.sort((a, b) -> atlas.frames[a].name < atlas.frames[b].name ? -1 : 1);

        if (containsUpper != containsLower) caseAllowed = containsUpper ? Upper : Lower;
    }

    public function getCharFrames(char:String):Null<Array<Int>>
    {
        return frameIndices.get(getAnimPrefix(char));
    }

    public function getCharWidth(char:String):Float
    {
        var indices:Null<Array<Int>> = frameIndices.get(getAnimPrefix(char));
        if (indices == null) return 0;

        return atlas.frames[indices[0]].sourceSize.x;
    }

    public function getAnimPrefix(char:String):String
    {
        if (isLetter.match(char))
        {
            if (name == BOLD) return '${char.toUpperCase()} bold';

            return char.toLowerCase() == char ? '$char lowercase' : '$char capital';
        }

        return switch (char)
        {
            case '&': 'amp';
            case '😠': 'angry faic';
            case "'": 'apostraphie';
            case ',': 'comma';
            case "$": 'dollarsign ';
            case '↓': 'down arrow';
            case '(': name == BOLD ? '(' : 'start parentheses';
            case ')': name == BOLD ? ')' : 'end parentheses';
            case '!': 'exclamation point';
            case '/': 'forward slash';
            case '#': 'hashtag ';
            case '♥': 'heart';
            case '♡': 'heart';
            case '←': 'left arrow';
            case '×': 'multiply x';
            case '.': 'period';
            case '?': 'question mark';
            case '→': 'right arrow';
            case '↑': 'up arrow';

            default: char;
        }
    }
}

enum Case
{
    Both;
    Upper;
    Lower;
}

enum abstract AtlasFont(String) from String to String
{
    var DEFAULT = "default";
    var BOLD = "bold";
}
