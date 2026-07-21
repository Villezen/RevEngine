package game.notes;

import backend.registries.ui.NoteSkinRegistry;
import backend.registries.ui.NoteSkinRegistry.NoteSplashData;
import backend.registries.ui.NoteSkinRegistry.BaseAnimationData;

import backend.utils.KeyUtil;

class NoteSplash extends FunkinSprite
{
    public var direction(default, null):Int;
    public var data:NoteSplashData;

    private var _maxVariants:Int = 0;

    public var skin(default, set):NoteStyle;

    function set_skin(value:NoteStyle):NoteStyle
    {
        if (value == skin) return value;

        data = NoteSkinRegistry.getSplash(value.name);
        value.applyToSplash(this);

        _maxVariants = scanMaxVariants();

        return skin = value;
    }

    function scanMaxVariants():Int
    {
        if (animation == null) return 0;

        var max:Int = 0;

        for (animName in animation.getNameList())
        {
            var parsed = Std.parseInt(animName);

            if (parsed != null && parsed > max)
                max = parsed;
        }

        return max;
    }

    public var strumline:Strumline;
    public var parent:Strum;

    public function new(direction:Int, skin:NoteStyle)
    {
        super();
        this.direction = direction;
        this.skin = skin;

        splash(false);
    }

    public override function update(elapsed:Float)
    {
        super.update(elapsed);

        var isDownscroll:Bool = (strumline != null && strumline.downScroll);
        var downscrollMult:Float = isDownscroll ? -1 : 1;

        if (parent != null)
        {
            this.x = (parent.x + (parent.width * 0.5) - (this.width * 0.5)) + data.position[0];
            this.y = (parent.y + (parent.height * 0.5) - (this.height * 0.5)) + (data.position[1] * downscrollMult);

            this.alpha = parent.alpha * data.alpha;
            this.angle = parent.angle;
        }

        this.flipY = isDownscroll;
    }

    public function splash(isVisible:Bool = true)
    {
        if (animation == null || _maxVariants <= 0) return;

        var animName = Std.string(FlxG.random.int(1, _maxVariants));

        if (animation.getByName(animName) == null)
            return;

        animation.play(animName, true);
        updateHitbox();

        if (data != null && data.animations != null)
        {
            var animArray:Array<Float> = [0, 0];
            var anims:Array<BaseAnimationData> = KeyUtil.isEK(skin.keys) ? data.animations.extraKeys : data.animations.normal;
            var colorStr:String = (KeyUtil.isEK(skin.keys) ? Constants.COLOR_DIRECTIONS[skin.keys][direction] : Constants.DIRECTIONS[skin.keys][direction]).toUpperCase();

            for (animEntry in anims)
            {
                if (animEntry.name == animName || animEntry.name == animName + colorStr)
                {
                    animArray = animEntry.offsets;
                    break;
                }
            }

            if (this.offset != null)
            {
                var isDownscroll:Bool = (strumline != null && strumline.downScroll);
                var downscrollMult:Float = isDownscroll ? -1 : 1;

                this.offset.x -= animArray[0];
                this.offset.y -= (animArray[1] * downscrollMult);
            }
        }
        
        this.visible = isVisible;

        animation.onFinish.addOnce((anim:String) -> {
            this.visible = false;
        });
    }
}