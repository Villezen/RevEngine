package menus.freeplay;

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

class ClearPercentCounter extends FlxTypedSpriteGroup<FunkinSprite>
{
    var _curNumber:Int = 0;
    public var curNumber(get, set):Int;

    inline function get_curNumber():Int
    {
        return _curNumber;
    }

    function set_curNumber(val:Int):Int
    {
        _curNumber = val;
        drawNumbers();
        return _curNumber;
    }

    public function new(x:Float, y:Float, curNumber:Int = 0)
    {
        super(x, y);

        for (i in 0...3)
        {
            var d:FunkinSprite = new FunkinSprite(0, 0, 'menus/freeplay/clearNumbers');

            for (n in 0...10)
                d.addAnim('$n', {prefix: '$n'});

            d.visible = false;
            add(d);
        }

        this.curNumber = curNumber;
    }

    function drawNumbers():Void
    {
        if (members == null || members.length < 3) return;

        var clamped:Int = Std.int(Math.min(Math.max(_curNumber, 0), 100));
        var str:String = Std.string(clamped);

        var shift:Float = switch (str.length)
        {
            case 3: -10;
            case 1: 24;
            default: 0;
        }

        var xPos:Float = shift;

        for (i in 0...members.length)
        {
            var d:FunkinSprite = members[i];

            if (i < str.length)
            {
                d.visible = true;
                d.playAnim(str.charAt(i), {force: true});
                d.updateHitbox();
                d.x = x + xPos;
                d.y = y;

                xPos += d.width;
            }
            else
                d.visible = false;
        }
    }
}
