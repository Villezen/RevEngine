package menus.freeplay;

class CapsuleNumber extends FunkinSprite
{
    public var digit(default, set):Int = 0;

    var numToString:Array<String> = ["ZERO", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE"];

    public function new(x:Float, y:Float, big:Bool = false, ?initDigit:Int = 0)
    {
        super(x, y, big ? 'menus/freeplay/capsule/bignumbers' : 'menus/freeplay/capsule/smallnumbers');

        for (i in 0...10)
            addAnim(numToString[i], {prefix: numToString[i]});

        this.digit = initDigit;

        setGraphicSize(Std.int(width * 0.9));
        updateHitbox();
    }

    function set_digit(val:Int):Int
    {
        playAnim(numToString[val], {force: true});
        centerOffsets(false);

        switch (val)
        {
            case 1:
                offset.x -= 4;
            case 3:
                offset.x -= 1;
            default:
                centerOffsets(false);
        }
        
        return val;
    }
}
