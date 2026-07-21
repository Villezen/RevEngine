package menus.freeplay;

import flixel.group.FlxSpriteGroup;

import backend.shaders.HSVShader;

class DifficultyStars extends FlxSpriteGroup
{
    static inline final STAR_STRIDE:Int = 100;
    static inline final MAX_DIFFICULTY:Int = 15;
    static inline final NO_STARS_FRAME:Int = 1500;
    static inline final STARS_ANIM:String = "diff stars";

    var curDifficulty(default, set):Int = 0;
    public var difficulty(default, set):Int = 1;

    public var stars:FunkinSprite;
    public var flames:FreeplayFlames;

    var hsvShader:HSVShader;

    public function new(x:Float, y:Float)
    {
        super(x, y);

        hsvShader = new HSVShader();

        flames = new FreeplayFlames(0, 0);

        stars = new FunkinSprite(0, 0, 'menus/freeplay/stars');

        if (stars.atlasSpr != null)
            stars.atlasSpr.applyStageMatrix = false;

        stars.addAnim(STARS_ANIM, {prefix: STARS_ANIM, fps: 24, looped: false});
        stars.playAnim(STARS_ANIM);

        add(flames);
        add(stars);

        stars.shader = hsvShader;

        for (memb in flames.members)
        {
            if (memb != null)
                memb.shader = hsvShader;
        }
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        
        if (curDifficulty < MAX_DIFFICULTY && curStarFrame() >= (curDifficulty + 1) * STAR_STRIDE)
            stars.playAnim(STARS_ANIM, {force: true, frame: curDifficulty * STAR_STRIDE});
    }

    function set_difficulty(value:Int):Int
    {
        difficulty = value;

        if (difficulty <= 0)
        {
            difficulty = 0;
            curDifficulty = MAX_DIFFICULTY;
        }
        else if (difficulty <= MAX_DIFFICULTY)
        {
            difficulty = value;
            curDifficulty = difficulty - 1;
        }
        else
        {
            difficulty = MAX_DIFFICULTY;
            curDifficulty = difficulty - 1;
        }

        flameCheck();

        return difficulty;
    }

    public function flameCheck():Void
    {
        if (difficulty > 10)
            flames.flameCount = difficulty - 10;
        else
            flames.flameCount = 0;
    }

    function set_curDifficulty(value:Int):Int
    {
        curDifficulty = value;

        if (stars == null) return curDifficulty;

        if (curDifficulty == MAX_DIFFICULTY)
        {
            stars.playAnim(STARS_ANIM, {force: true, frame: NO_STARS_FRAME});

            if (stars.atlasSpr != null)
                stars.atlasSpr.anim.pause();
        }
        else
        {
            setStarFrame(curDifficulty * STAR_STRIDE);
            stars.playAnim(STARS_ANIM, {force: true, frame: curDifficulty * STAR_STRIDE});
        }

        return curDifficulty;
    }

    function curStarFrame():Int
    {
        if (stars == null || stars.atlasSpr == null || stars.atlasSpr.anim.curAnim == null)
            return 0;

        return stars.atlasSpr.anim.curAnim.curFrame;
    }

    function setStarFrame(frame:Int):Void
    {
        if (stars == null || stars.atlasSpr == null || stars.atlasSpr.anim.curAnim == null)
            return;

        stars.atlasSpr.anim.curAnim.curFrame = frame;
    }
}
