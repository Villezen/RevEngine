package menus.freeplay;

import flixel.group.FlxSpriteGroup;
import flixel.math.FlxRect;
import flixel.text.FlxText;

import openfl.filters.BitmapFilterQuality;
import openfl.filters.GlowFilter;

import backend.shaders.GaussianBlurShader;

class CapsuleText extends FlxSpriteGroup
{
    public var blurredText:FlxText;
    var whiteText:FlxText;

    public var text(default, set):Null<String>;

    public var clipWidth(default, set):Int = 255;
    public var tooLong:Bool = false;

    var glowColor:FlxColor = 0xFF00ccff;

    public function new(x:Float, y:Float, songTitle:String, size:Float)
    {
        super(x, y);

        blurredText = CapsuleText.initText(songTitle, size);
        blurredText.shader = new GaussianBlurShader(1);
        whiteText = CapsuleText.initText(songTitle, size);
        text = songTitle;

        blurredText.color = glowColor;
        whiteText.color = 0xFFFFFFFF;
        add(blurredText);
        add(whiteText);
    }

    static function initText(songTitle:String, size:Float):FlxText
    {
        var text:FlxText = new FlxText(0, 0, 0, songTitle, Std.int(size));
        text.font = Paths.font('5by7.ttf');
        return text;
    }

    function set_clipWidth(value:Int):Int
    {
        resetText();
        checkClipWidth(value);
        return clipWidth = value;
    }

    function checkClipWidth(?wid:Int):Void
    {
        if (wid == null) wid = clipWidth;
        if (whiteText == null || blurredText == null) return;

        if (whiteText.width > wid)
        {
            tooLong = true;

            blurredText.clipRect = new FlxRect(0, 0, wid, blurredText.height);
            whiteText.clipRect = new FlxRect(0, 0, wid, whiteText.height);
        }
        else
        {
            tooLong = false;

            blurredText.clipRect = null;
            whiteText.clipRect = null;
        }
    }

    function set_text(value:String):String
    {
        if (value == null) return value;

        if (blurredText == null || whiteText == null)
        {
            trace('Capsule not initialized properly', "WARNING");
            return text = value;
        }

        blurredText.text = value;
        whiteText.text = value;
        checkClipWidth();
        whiteText.textField.filters = [new GlowFilter(glowColor, 1, 5, 5, 210, BitmapFilterQuality.MEDIUM)];

        return text = value;
    }

    var moveTimer:FlxTimer = new FlxTimer();
    var moveTween:Null<FlxTween>;

    public function initMove():Void
    {
        moveTimer.start(0.6, (timer) -> moveTextRight());
    }

    function moveTextRight():Void
    {
        var distToMove:Float = whiteText.width - clipWidth;

        moveTween = FlxTween.tween(whiteText.offset, {x: distToMove}, 2,
        {
            onUpdate: function(_)
            {
                whiteText.clipRect = new FlxRect(whiteText.offset.x, 0, clipWidth, whiteText.height);
                blurredText.offset = whiteText.offset;
                blurredText.clipRect = new FlxRect(whiteText.offset.x, 0, clipWidth, blurredText.height);
            },
            onComplete: function(_)
            {
                moveTimer.start(0.3, (timer) -> moveTextLeft());
            },
            ease: FlxEase.sineInOut
        });
    }

    function moveTextLeft():Void
    {
        moveTween = FlxTween.tween(whiteText.offset, {x: 0}, 2,
        {
            onUpdate: function(_)
            {
                whiteText.clipRect = new FlxRect(whiteText.offset.x, 0, clipWidth, whiteText.height);
                blurredText.offset = whiteText.offset;
                blurredText.clipRect = new FlxRect(whiteText.offset.x, 0, clipWidth, blurredText.height);
            },
            onComplete: function(_)
            {
                moveTimer.start(0.3, (timer) -> moveTextRight());
            },
            ease: FlxEase.sineInOut
        });
    }

    public function resetText():Void
    {
        scale.x = 1;
        scale.y = 1;

        if (moveTween != null) moveTween.cancel();
        if (moveTimer != null) moveTimer.cancel();

        whiteText.offset.x = 0;
        whiteText.clipRect = new FlxRect(whiteText.offset.x, 0, clipWidth, whiteText.height);
        blurredText.clipRect = new FlxRect(whiteText.offset.x, 0, clipWidth, blurredText.height);
    }

    var flickerState:Bool = false;
    var flickerTimer:Null<FlxTimer>;

    public function flickerText():Void
    {
        resetText();
        flickerTimer = new FlxTimer().start(1 / 24, flickerProgress, 19);
    }

    function flickerProgress(timer:FlxTimer):Void
    {
        if (flickerState == true)
        {
            whiteText.blend = BlendMode.ADD;
            blurredText.blend = BlendMode.ADD;
            blurredText.color = 0xFFFFFFFF;
            whiteText.color = 0xFFFFFFFF;
            whiteText.textField.filters = [new GlowFilter(0xFFFFFF, 1, 5, 5, 210, BitmapFilterQuality.MEDIUM)];
        }
        else
        {
            blurredText.color = glowColor;
            whiteText.color = 0xFFDDDDDD;
            whiteText.textField.filters = [new GlowFilter(0xDDDDDD, 1, 5, 5, 210, BitmapFilterQuality.MEDIUM)];
        }
        flickerState = !flickerState;
    }
}
