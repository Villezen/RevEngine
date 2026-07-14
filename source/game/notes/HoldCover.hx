package game.notes;

import haxe.Json;

import backend.registries.ui.NoteSkinRegistry;
import backend.registries.ui.NoteSkinRegistry.HoldCoverData;
import backend.registries.ui.NoteSkinRegistry.BaseAnimationData;
import backend.utils.KeyUtil;

class HoldCover extends FunkinSprite
{
    /**
     * Whether the hold cover is allowed to be shown or not.
     */
    public var show:Bool = true;

    /**
     * The note direction of this hold cover.
     */
    public var direction(default, null):Int;

    /**
     * The JSON data for the hold cover skin.
     */
    public var data:HoldCoverData;

    /**
     * Used to emulate hiding the cover when it finishes playing so it doesn't stop being drawn on the screen.
     */
    private var alphaMult:Float = 1.0;

    /**
     * The note style of this hold cover.
     */
    public var skin(default, set):NoteStyle;

    function set_skin(value:NoteStyle):NoteStyle 
    {
        if (value == skin) return value;

        data = NoteSkinRegistry.getCover(value.name);
        value.applyToCover(this);

        return skin = value;
    }

    /**
     * The strumline associated with this hold cover.
     */
    public var strumline:Strumline;

    /**
     * The strum associated with this note splash.
     */
    public var parent:Strum;

    public function new(direction:Int, skin:NoteStyle)
    {
        super();

        this.direction = direction;
        this.skin = skin;

        alphaMult = 0.0000000000000000000000000001;
        playAnimation('start', true);

        if (animation != null && animation.onFinish != null)
            animation.onFinish.add(onAnimFinish);
    }

    private function onAnimFinish(name:String):Void
    {
        if (name == 'start')
            playAnimation('loop', true);
        else if (name == 'end')
            hide(false);
    }

    /**
     * Positions the hold cover sprite to be aligned with the parent strum.
     */
    public override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (parent != null)
            sync();
    }

    public function start()
    {
        if (!show) return;

        playAnimation('start', true);
        alphaMult = 1.0;
    }

    public function finish()
    {
        if (!show) return;

        playAnimation('end', true);
    }

    public function hide(?stop:Bool = true) 
    {
        if (stop)
            animation.stop();

        alphaMult = 0.0000000000000000000000000001;
    }

    /**
     * Plays a hold cover animation and applies its respective JSON offsets.
     */
    public function playAnimation(animName:String, ?force:Bool = true, ?reversed:Bool = false, ?frame:Int = 0) 
    {
        if (animation == null || animation.getByName(animName) == null) return;

        animation.play(animName, force, reversed, frame);
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

            var isDownscroll:Bool = (strumline != null && strumline.downScroll);
            var downscrollMult:Float = isDownscroll ? -1 : 1;

            offset.x += animArray[0] * -1;
            offset.y += animArray[1] * -1 * downscrollMult;
        }
    }

    /**
     * Syncs the hold cover to the parent strum.
     */
    public function sync()
    {
        var isDownscroll:Bool = (strumline != null && strumline.downScroll);
        var downscrollMult:Float = isDownscroll ? -1 : 1;

        if (parent != null)
        {
            x = (parent.x + (parent.width - width) / 2) + data.position[0];
            y = (parent.y + (parent.height - height) / 2) + (data.position[1] * downscrollMult);

            alpha = parent.alpha * alphaMult;
            angle = parent.angle;
        }

        flipY = isDownscroll;
    }
}