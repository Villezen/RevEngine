package game.notes;

import backend.registries.ui.NoteSkinRegistry.BaseAnimationData;
import backend.utils.KeyUtil;

/**
 * A sprite, representing an individual note in the game.
 */
class Note extends FunkinSprite
{
    /**
     * The skin applied to the note.
     */
    public var skin(default, set):NoteStyle;
    function set_skin(value:NoteStyle):NoteStyle
    {
        if (skin == value) return skin;

        if (value == null)
        {
            skin = null;
            return null;
        }

        skinOffsetX = 0;
        skinOffsetY = 0;

        if (parent == null || parent.data == null || parent.parent == null)
            return skin = value;

        value.applyToNote(this);

        animation.play('scroll');

        var keyCount = parent.parent.keyCount;
        var isExtraKeys = KeyUtil.isEK(keyCount);

        var anims:Array<BaseAnimationData> = isExtraKeys ? parent.data.animations.extraKeys : parent.data.animations.normal;
        var colorStr:String = (isExtraKeys ? Constants.COLOR_DIRECTIONS[keyCount][parent.direction] : Constants.DIRECTIONS[keyCount][parent.direction]).toUpperCase();
        var bindColorStr:String = Constants.DIRECTIONS_KEYBIND[keyCount][parent.direction].toUpperCase();

        var targetAnimName:String = 'arrow' + colorStr;
        var bindTargetName:String = 'arrow' + bindColorStr;

        for (animEntry in anims)
        {
            var isBind = animEntry.prefix.indexOf("keybind[") != -1;
            var checkName = isBind ? bindTargetName : targetAnimName;

            if (animEntry.name == checkName)
            {
                skinOffsetX = animEntry.offsets[0] * -1;
                skinOffsetY = animEntry.offsets[1] * -1;
                
                break;
            }
        }

        updateHitbox();
        sync();

        return skin = value;
    }

    /**
     * Offsets from the noteskin's JSON file.
     */
    public var skinOffsetX:Float = 0;
    public var skinOffsetY:Float = 0;

    /**
     * Re-applies the skin offsets on top of the recalculated hitbox offset.
     */
    override public function updateHitbox():Void
    {
        super.updateHitbox();

        offset.x += skinOffsetX;
        offset.y += skinOffsetY;
    }

    /**
     * The target time in milliseconds when this note should be hit.
     */
    public var time:Float = 0.0;

    /**
     * The direction this note belongs to.
     */
    public var direction:Int = 0;

    /**
     * Wheater or not the note must be hit by the player.
     */
    public var mustHit:Bool = false;

    /**
     * The sustain note linked to this note.
     */
    public var sustain:SustainNote;

    /**
     * Determines if the note is within the player's timing window.
     */
    public var canBeHit(get, never):Bool;

    private inline function get_canBeHit():Bool
    {
        if (!mustHit)
            return false;

        var timeDiff:Float = time - Conductor.instance.songPosition;
        if (timeDiff <= Constants.SAFE_ZONE_OFFSET * Constants.EARLY_HIT_MULT && timeDiff >= -Constants.SAFE_ZONE_OFFSET * Constants.LATE_HIT_MULT)
        {
            return true;
        }
        
        return false;
    }

    /**
     * Determines if the note can no longer be hit by the player.
     */
    public var tooLate(get, never):Bool;

    private inline function get_tooLate():Bool
    {
        return time < Conductor.instance.songPosition - (Constants.SAFE_ZONE_OFFSET * Constants.LATE_HIT_MULT) && !hit;
    }

    /**
     * Wheater or not the miss penalty for not pressing the note on time has been handled.
     */
    public var missHandled:Bool = false;

    /**
     * Wheater the enemy has successfully pressed the note.
     */
    public var enemyHit:Bool = false;

    /**
     * Wheater the player has successfully pressed the note.
     */
    public var playerHit:Bool = false;

    /**
     * Wheater the note has been accounted for by a hit.
     */
    public var hit:Bool = false;

    /**
     * Wheater or not the note has a sustain note attached to it .
     */
    public var hasSustain(get, never):Bool;

    private inline function get_hasSustain():Bool
    {
        return sustain != null;
    }

    /**
     * The visual distance from the strumline, used for positioning.
     */
    public var distance:Float = 2000;

    /**
     * Wheater the note has been generated/recycled.
     */
    public var generated:Bool = false;

    /**
     * The strumline lined to this note.
     */
    public var strumline:Strumline;

    /**
     * Reference to the strum object the note is travelling towards.
     */
    public var parent:Strum;

    /**
     * Creates a new note from a specific direction.
     * @param direction The direction of the note.
     */
    public function new(direction:Int)
    {
        super();
        this.direction = direction;
    }

    /**
     * Disables the note and resets its generation flag for object pooling.
     */
    override function kill()
    {
        super.kill();

        generated = false;
        sustain = null;
        skin = null; 
    }

    /**
     * Re-enables the note and resets hit-state flag for reuse.
     */
    override function revive()
    {
        super.revive();

        generated = true;
        alpha = 1;

        hit = false;
        enemyHit = false;
        playerHit = false;
        missHandled = false;
    }

    /**
     * Syncs the note to the parent strum object.
     */
    public function sync()
    {
        if (parent == null)
            return;

        var missModifier:Float = 1.0;

        if (missHandled)
            missModifier = 0.4;

        x = parent.x + (parent.width - width) / 2;
        alpha = parent.alpha * missModifier;

        if (strumline == null)
            return;

        flipY = strumline.downScroll;
    }

    /**
     * Frees memory references for the GC when the state ends.
     */
    override public function destroy()
    {
        skin = null;
        sustain = null;
        strumline = null;
        parent = null;

        super.destroy();
    }
}