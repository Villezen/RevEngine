package menus.freeplay;

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

class FreeplayScore extends FlxTypedSpriteGroup<ScoreNum>
{
    public var scoreShit(default, set):Int = 0;

    function set_scoreShit(val:Int):Int
    {
        if (group == null || group.members == null) return val;

        var dumbNumb:Int = val;
        if (dumbNumb < 0) dumbNumb = 0;
        dumbNumb = Std.int(Math.min(dumbNumb, Math.pow(10, group.members.length) - 1));

        var loopNum:Int = group.members.length - 1;

        while (dumbNumb > 0)
        {
            group.members[loopNum].digit = dumbNumb % 10;

            dumbNumb = Math.floor(dumbNumb / 10);
            loopNum--;
        }

        while (loopNum >= 0)
        {
            group.members[loopNum].digit = 0;
            loopNum--;
        }

        return val;
    }

    public function new(x:Float, y:Float, digitCount:Int, scoreShit:Int = 100)
    {
        super(0, y);

        for (i in 0...digitCount)
            add(new ScoreNum(x + (45 * i), y, 0));

        this.scoreShit = scoreShit;
    }

    public function updateScore(scoreNew:Int)
    {
        scoreShit = scoreNew;
    }
}

class ScoreNum extends FunkinSprite
{
    public var digit(default, set):Int = 0;

    final numToString:Array<String> = ["ZERO", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE"];

    function set_digit(val:Int):Int
    {
        if (animation.curAnim != null && animation.curAnim.name != numToString[val])
        {
            animation.play(numToString[val], true, false, 0);
            updateHitbox();

            switch (val)
            {
                case 1:
                    offset.x -= 15;
                default:
                    centerOffsets(false);
            }
        }

        return val;
    }

    public function new(x:Float, y:Float, ?initDigit:Int = 0)
    {
        super(x, y, 'menus/freeplay/digitalNumbers');

        for (i in 0...10)
            addAnim(numToString[i], {prefix: '${numToString[i]} DIGITAL', fps: 24});

        this.digit = initDigit;

        animation.play(numToString[digit], true);

        setGraphicSize(Std.int(width * 0.4));
        updateHitbox();
    }
}
