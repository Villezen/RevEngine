package game.notes;

import backend.registries.ui.NoteSkinRegistry;
import backend.registries.ui.NoteSkinRegistry.BaseAnimationData;

import flixel.util.FlxTimer;

import backend.utils.KeyUtil;

/**
 * A sprite representing a static note receptor.
 */
class Strum extends FunkinSprite
{
    /**
     * The parent strumline of the strum.
     */
    public var parent:Strumline;

    /**
     * The direction this strum occupies.
     */
    public var direction:Int = 0;

    /**
     * Stored visual configuration data from the style's JSON file. Will be used by the strum itself and its children. (pause)
     */
    public var data:NoteStyleData;

    /**
     * The skin applied to this strum.
     */
    public var skin(default, set):NoteStyle;

    function set_skin(value:NoteStyle):NoteStyle
    {
        if (skin == value) return skin;

        FlxTween.cancelTweensOf(this);
        data = NoteSkinRegistry.getStyle(value.name);

        value.applyToStrum(this);
        play('static', true);

        return skin = value;
    }

    /**
     * Timer, attached to the strum note. Used to handle confirm resets for playable strumlines.
     */
    public var timer:FlxTimer;

    /**
     * Creates a new strum receptor.
     * @param direction The direction for this strum.
     * @param skin The `NoteStyle` to apply.
     */
    public function new(direction:Int, skin:NoteStyle)
    {
        super(0, 0);

        this.direction = direction;
        this.skin = skin;
    }

    /**
     * Plays a specific animation and applies offsets.
     * @param anim The name of the animation.
     * @param force Wheater or not the animation should restart if its already playing.
     * @param reversed Wheater to play the animation backwards.
     * @param frame The specific frame index to start the animation on.
     */
    public function play(anim:String, ?force:Bool = false, reversed:Bool = false, frame:Int = 0)
    {
        if (animation == null || animation.getByName(anim) == null) return;

        animation.play(anim, force, reversed, frame);

        centerOffsets();
        centerOrigin();

        if (data != null && parent != null)
        {
            var anims:Array<BaseAnimationData> = KeyUtil.isEK(parent.keyCount) ? data.animations.extraKeys : data.animations.normal;
            var colorStr:String = (KeyUtil.isEK(parent.keyCount) ? Constants.COLOR_DIRECTIONS[parent.keyCount][direction] : Constants.DIRECTIONS[parent.keyCount][direction]).toUpperCase();

            for (animEntry in anims)
            {
                if (animEntry.name == anim + colorStr || animEntry.name == anim)
                {
                    offset.x -= animEntry.offsets[0];
                    offset.y -= animEntry.offsets[1];
                    break;
                }
            }
        }
    }

    /**
     * Overrides the standard Flixel centerOffests function to calculate centering based on the frameWidth and frameHeight
     * @param AdjustPosition Wheater or not the move the sprite's absolute position to compensate for the offset change.
     */
    public override function centerOffsets(AdjustPosition:Bool = false):Void
	{
        var previousOffsets:Array<Float> = [offset.x, offset.y];

        offset.x = (frameWidth - width) * 0.5;
        offset.y = (frameHeight - height) * 0.5;

        if (AdjustPosition)
        {
            x += offset.x;
            y += offset.y;
        }
	}

    /**
     * Syncs the strums to the current scroll direction.
     */
    public function sync()
    {
        flipY = parent.downScroll;
    }
}