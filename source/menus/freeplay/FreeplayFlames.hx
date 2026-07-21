package menus.freeplay;

import flixel.group.FlxSpriteGroup;

class FreeplayFlames extends FlxTypedSpriteGroup<FunkinSprite>
{
    static inline final FLAME_COUNT:Int = 5;

    var flameX(default, set):Float = -37;
    var flameY(default, set):Float = -118;
    var flameSpreadX(default, set):Float = 29;
    var flameSpreadY(default, set):Float = 6;

    public var flameCount(default, set):Int = 0;

    var flameTimer:Float = 0.25;

    var timers:Array<FlxTimer> = [];

    var properPositions:Bool = false;

    public function new(x:Float, y:Float)
    {
        super(x, y);

        for (i in 0...FLAME_COUNT)
        {
            var flame:FunkinSprite = new FunkinSprite(flameX + (flameSpreadX * i), flameY + (flameSpreadY * i));
            flame.frames = Paths.getSparrowAtlas('menus/freeplay/flame');
            flame.animation.addByPrefix("flame", "fire loop full instance 1", FlxG.random.int(23, 25), false);
            flame.animation.play("flame");
            flame.visible = false;
            flameCount = 0;

            flame.animation.onFinish.add(function(_)
            {
                flame.animation.play("flame", true, false, 2);
            });

            add(flame);
        }
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (!properPositions)
        {
            setFlamePositions();
            properPositions = true;
        }
    }

    function set_flameCount(value:Int):Int
    {
        while (timers.length > 0)
        {
            var timer:FlxTimer = timers.pop();

            if (timer != null) timer.cancel();
        }

        this.properPositions = false;
        this.flameCount = value;

        var visibleCount:Int = 0;

        for (i in 0...FLAME_COUNT)
        {
            if (members[i] == null) continue;

            var flame:FunkinSprite = members[i];

            if (i < flameCount)
            {
                if (!flame.visible)
                {
                    var nextTimer:FlxTimer = new FlxTimer().start(flameTimer * visibleCount, function(currentTimer:FlxTimer)
                    {
                        if (i >= this.flameCount)
                            return;

                        timers.remove(currentTimer);

                        flame.animation.play("flame", true);
                        flame.visible = true;
                    });

                    timers.push(nextTimer);

                    visibleCount++;
                }
            }
            else
                flame.visible = false;
        }

        return this.flameCount;
    }

    function setFlamePositions():Void
    {
        for (i in 0...FLAME_COUNT)
        {
            if (members[i] == null) continue;

            var flame:FunkinSprite = members[i];
            flame.x = x + flameX + (flameSpreadX * i);
            flame.y = y + flameY + (flameSpreadY * i);
        }
    }

    function set_flameX(value:Float):Float
    {
        this.flameX = value;
        setFlamePositions();

        return this.flameX;
    }

    function set_flameY(value:Float):Float
    {
        this.flameY = value;
        setFlamePositions();

        return this.flameY;
    }

    function set_flameSpreadX(value:Float):Float
    {
        this.flameSpreadX = value;
        setFlamePositions();

        return this.flameSpreadX;
    }

    function set_flameSpreadY(value:Float):Float
    {
        this.flameSpreadY = value;
        setFlamePositions();

        return this.flameSpreadY;
    }

    override public function destroy():Void
    {
        while (timers.length > 0)
        {
            var timer:FlxTimer = timers.pop();

            if (timer != null) timer.cancel();
        }

        super.destroy();
    }
}
