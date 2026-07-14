package menus.freeplay;

class PixelatedIcon extends FunkinSprite
{
    public var char:String;

    public function new(x:Float, y:Float)
    {
        super(x, y);

        this.char = '';

        this.makeGraphic(32, 32, 0x00000000);
        this.antialiasing = false;
        this.active = false;
    }

    public static function iconExists(char:String):Bool
    {
        if (char == null || char == "") return false;
        return Paths.exists('images/characters/$char/icon-pixel.png');
    }

    public function setCharacter(char:String):Void
    {
        if (char == null) char = "";
        if (this.char == char && this.char != "") return;

        var charPath:String = 'characters/$char/icon-pixel';

        if (char == "" || !Paths.exists('images/$charPath.png'))
        {
            if (char != "")
                trace('Character "$char" has no freeplay pixel icon.', "WARNING");

            this.visible = false;
            this.char = "";
            return;
        }

        this.visible = true;
        this.char = char;

        loadSprite(charPath);

        this.scale.x = this.scale.y = 2;
        this.origin.x = 100;

        if (Paths.exists('images/$charPath.xml'))
        {
            this.active = true;

            addAnim('idle', {prefix: 'idle0', fps: 10, looped: true});
            addAnim('confirm', {prefix: 'confirm0', fps: 10});
            addAnim('confirm-hold', {prefix: 'confirm-hold0', fps: 10, looped: true});

            playAnim('idle');
        }
    }

    public function confirm():Void
    {
        if (!visible) return;

        playAnim('confirm', {onComplete: () -> playAnim('confirm-hold')});
    }
}
