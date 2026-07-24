package menus.freeplay;

import flixel.group.FlxSpriteGroup;
import flixel.math.FlxRect;

class DifficultySelector extends FlxSpriteGroup
{
    public var difficulties:Array<String> = [];
    public var currentDifficulty(get, never):String;

    var curIndex:Int = 0;

    var leftArrow:FunkinSprite;
    var rightArrow:FunkinSprite;

    var diffSprites:Array<FunkinSprite> = [];
    var dots:Array<DifficultyDot> = [];

    var available:Array<String> = null;

    var windowLeft:Float = 0;
    var windowRight:Float = 0;
    var windowCenter:Float = 0;

    static final ARROW_HEIGHT:Float = 90;
    static final LEFT_ARROW_X:Float = 0;
    static final RIGHT_ARROW_X:Float = 305;
    static final ARROW_Y:Float = 0;
    static final DOTS_Y:Float = 100;
    static final DOT_SPACING:Float = 30;

    static final SLIDE_DISTANCE:Float = 410;

    public function new(x:Float, y:Float, difficulties:Array<String>, curCharacter:String, ?startDifficulty:String)
    {
        super(x, y);

        this.difficulties = difficulties;

        curIndex = difficulties.indexOf(startDifficulty ?? Constants.DEFAULT_DIFFICULTY);
        if (curIndex < 0) curIndex = 0;

        leftArrow = new FunkinSprite(LEFT_ARROW_X, ARROW_Y, 'menus/freeplay/characters/$curCharacter/selector');
        leftArrow.addAnim('shine', {prefix: 'arrow pointer loop', fps: 24, looped: true});
        leftArrow.playAnim('shine');
        add(leftArrow);

        rightArrow = new FunkinSprite(RIGHT_ARROW_X, ARROW_Y, 'menus/freeplay/characters/$curCharacter/selector');
        rightArrow.addAnim('shine', {prefix: 'arrow pointer loop', fps: 24, looped: true});
        rightArrow.flipX = true;
        rightArrow.playAnim('shine');
        add(rightArrow);

        windowLeft = LEFT_ARROW_X + leftArrow.frameWidth;
        windowRight = RIGHT_ARROW_X;
        windowCenter = (windowLeft + windowRight) / 2;

        for (difficulty in difficulties)
        {
            var sprite:FunkinSprite = new FunkinSprite(0, ARROW_Y, 'menus/freeplay/difficulties/$difficulty');

            if (Paths.exists('images/menus/freeplay/difficulties/$difficulty.xml'))
            {
                sprite.addAnim('idle', {prefix: 'idle', fps: 24, looped: true});
                sprite.playAnim('idle');
            }

            sprite.x = windowCenter - sprite.frameWidth / 2;
            sprite.y += (ARROW_HEIGHT - sprite.height) / 2;
            sprite.visible = difficulty == difficulties[curIndex];
            sprite.clipRect = FlxRect.get(0, 0, sprite.frameWidth, sprite.frameHeight);
            add(sprite);

            diffSprites.push(sprite);
        }

        for (difficulty in difficulties)
        {
            var dot:DifficultyDot = new DifficultyDot(0, DOTS_Y, difficulty);
            add(dot);

            dots.push(dot);
        }

        var dotWidth:Float = (dots.length > 0) ? dots[0].frameWidth : 0;
        var rowStart:Float = windowCenter - ((difficulties.length - 1) * DOT_SPACING + dotWidth) / 2;

        for (i in 0...dots.length)
            dots[i].x = this.x + rowStart + i * DOT_SPACING;

        updateDots(curIndex);
    }

    function get_currentDifficulty():String
    {
        return difficulties[curIndex];
    }

    inline function homeXOf(logo:FunkinSprite):Float
    {
        return this.x + windowCenter - logo.frameWidth / 2;
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);

        for (logo in diffSprites)
        {
            if (logo.clipRect == null) continue;

            var localX:Float = logo.x - this.x;

            var left:Float = windowLeft - localX;
            if (left < 0) left = 0;

            var right:Float = windowRight - localX;
            if (right > logo.frameWidth) right = logo.frameWidth;

            logo.clipRect.x = left;
            logo.clipRect.y = 0;
            logo.clipRect.width = (right > left) ? right - left : 0;
            logo.clipRect.height = logo.frameHeight;
        }
    }

    public function change(change:Int):Void
    {
        if (difficulties.length == 0 || change == 0) return;

        var prevIndex:Int = curIndex;

        curIndex += change;
        if (curIndex < 0) curIndex = difficulties.length - 1;
        if (curIndex >= difficulties.length) curIndex = 0;

        pressArrow(change < 0 ? leftArrow : rightArrow);

        FunkinSound.playOnce(Paths.sound('engine/scroll'), 0.4);

        if (curIndex != prevIndex)
            slideSprites(change, prevIndex);

        updateDots(prevIndex);
    }

    public function refreshDots(?availableDifficulties:Array<String>):Void
    {
        available = availableDifficulties;
        updateDots(curIndex);
    }

    function updateDots(prevIndex:Int):Void
    {
        for (i in 0...dots.length)
        {
            var dot:DifficultyDot = dots[i];

            if (available != null && available.indexOf(dot.difficultyId) == -1)
                dot.setState(DifficultyDot.INACTIVE);
            else if (i == curIndex)
                dot.setState(DifficultyDot.SELECTED);
            else if (i == prevIndex)
                dot.setState(DifficultyDot.DESELECTING);
            else
                dot.setState(DifficultyDot.DESELECTED);
        }
    }

    function slideSprites(change:Int, prevIndex:Int):Void
    {
        var outgoing:FunkinSprite = diffSprites[prevIndex];
        var incoming:FunkinSprite = diffSprites[curIndex];

        if (outgoing != null && outgoing != incoming)
        {
            var homeOut:Float = homeXOf(outgoing);

            FlxTween.cancelTweensOf(outgoing);
            outgoing.visible = true;

            FlxTween.tween(outgoing, {x: homeOut + (change > 0 ? -SLIDE_DISTANCE : SLIDE_DISTANCE)}, 0.2, {
                ease: FlxEase.circInOut,
                onComplete: (_) ->
                {
                    outgoing.x = homeOut;
                    outgoing.visible = false;
                }
            });
        }

        if (incoming != null)
        {
            var homeIn:Float = homeXOf(incoming);

            FlxTween.cancelTweensOf(incoming);

            incoming.x = homeIn + (change > 0 ? SLIDE_DISTANCE : -SLIDE_DISTANCE);
            incoming.alpha = 0.5;
            incoming.offset.y += 5;
            incoming.visible = false;

            FlxTween.tween(incoming, {x: homeIn}, 0.2, {ease: FlxEase.circInOut});

            new FlxTimer().start(1 / 24, (_) ->
            {
                incoming.alpha = 1;
                incoming.visible = true;
                incoming.updateHitbox();
            });
        }
    }

    function pressArrow(arrow:FunkinSprite):Void
    {
        arrow.offset.y -= 5;
        arrow.scale.set(0.8, 0.8);
        arrow.setColorTransform(1, 1, 1, 1, 160, 160, 160, 0);

        new FlxTimer().start(2 / 12, (_) ->
        {
            arrow.scale.set(1, 1);
            arrow.setColorTransform();
            arrow.updateHitbox();
        });
    }
}

class DifficultyDot extends FunkinSprite
{
    public static inline var SELECTED:Int = 0;
    public static inline var DESELECTING:Int = 1;
    public static inline var DESELECTED:Int = 2;
    public static inline var INACTIVE:Int = 3;

    public var difficultyId:String;

    var colorTween:FlxTween;

    static final SELECTED_COLOR:FlxColor = 0xFFFAFAFA;
    static final DESELECTED_COLOR:FlxColor = 0xFF484848;
    static final INACTIVE_COLOR:FlxColor = 0xFF121212;

    public function new(x:Float, y:Float, difficultyId:String)
    {
        super(x, y, 'menus/freeplay/seperator');

        this.difficultyId = difficultyId;

        setState(DESELECTED);
    }

    public function setState(state:Int):Void
    {
        if (colorTween != null)
        {
            colorTween.cancel();
            colorTween = null;
        }

        alpha = (state == INACTIVE) ? 0.33 : 1;

        switch (state)
        {
            case SELECTED:
                color = SELECTED_COLOR;

            case DESELECTING:
                colorTween = FlxTween.color(this, 0.5, SELECTED_COLOR, DESELECTED_COLOR, {ease: FlxEase.quartOut});

            case INACTIVE:
                color = INACTIVE_COLOR;

            default:
                color = DESELECTED_COLOR;
        }
    }
}
