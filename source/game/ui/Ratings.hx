package game.ui;

import flixel.group.FlxSpriteGroup;

import game.PlayMetrics.NoteJudgement;

import backend.registries.ui.RatingsRegistry;
import backend.registries.ui.RatingsRegistry.RatingsData;
import backend.registries.ui.RatingsRegistry.RatingSpriteEntry;

import backend.utils.EaseUtil;

class Ratings extends FlxSpriteGroup
{
    public var data:RatingsData;

    public var skin(default, set):String = "";

    function set_skin(value:String):String
    {
        skin = value;
        data = RatingsRegistry.get(value);

        _comboEntries = [];

        if (data != null && data.combo != null)
        {
            _comboEntries =
            [
                data.combo.num0, data.combo.num1, data.combo.num2, data.combo.num3, data.combo.num4,
                data.combo.num5, data.combo.num6, data.combo.num7, data.combo.num8, data.combo.num9
            ];
        }

        return skin;
    }

    /**
     * Reused digit buffer for popCombo, so combo splitting doesn't run per hit.
     */
    private var _digits:Array<Int> = [];

    /**
     * Cached combo digit sprites to avoid using Reflect functions.
     */
    private var _comboEntries:Array<RatingSpriteEntry> = [];

    public function new(skin:String)
    {
        super();

        this.skin = skin;
    }

    private function recyclePopup():RatingPopup
    {
        var spr:RatingPopup = cast group.getFirstDead();

        if (spr == null)
        {
            spr = new RatingPopup();
            add(spr);
        }
        else
        {
            spr.revive();

            group.members.remove(spr);
            group.members.push(spr);
        }

        spr.alpha = 1;
        spr.velocity.set(0, 0);
        spr.acceleration.set(0, 0);

        return spr;
    }

    public function popRating(rating:NoteJudgement):Void
    {
        var ratingStr:String = switch (rating)
        {
            case NoteJudgement.SICK: 'sick';
            case NoteJudgement.GOOD: 'good';
            case NoteJudgement.BAD: 'bad';
            case NoteJudgement.SHIT: 'shit';
            case NoteJudgement.NONE: null;
        }

        if (ratingStr == null) return;

        var ratingData:RatingSpriteEntry = switch (rating)
        {
            case NoteJudgement.SICK: data.ratings.sick;
            case NoteJudgement.GOOD: data.ratings.good;
            case NoteJudgement.BAD: data.ratings.bad;
            case NoteJudgement.SHIT: data.ratings.shit;
            case NoteJudgement.NONE: null;
        }

        if (ratingData == null) return;

        this.setPosition(0, 0);

        var rating:RatingPopup = recyclePopup();

        rating.loadGraphic(Paths.image('game/ui/ratings/$skin/$ratingStr'));
        rating.scale.set(ratingData.scale[0], ratingData.scale[1]);
        rating.updateHitbox();
        rating.setPosition(data.position[0] + data.ratings.position[0] + ratingData.offset[0], data.position[1] + data.ratings.position[1] + ratingData.offset[1]);

        rating.velocity.x = FlxG.random.int(ratingData.velocity.x[0], ratingData.velocity.x[1]);
        rating.velocity.y = FlxG.random.int(ratingData.velocity.y[0], ratingData.velocity.y[1]);

        rating.acceleration.x = FlxG.random.int(ratingData.acceleration.x[0], ratingData.acceleration.x[1]);
        rating.acceleration.y = FlxG.random.int(ratingData.acceleration.y[0], ratingData.acceleration.y[1]);

        var ratingEase = ratingData.ease != "stepped" ? EaseUtil.get(ratingData.ease) : steppedEase;
        rating.beginFade((Conductor.instance.stepLengthMs * 4) * 0.001, 0.2 * ratingData.timeMult, ratingEase);
    }

    public function popCombo(combo:Int):Void
    {
        _digits.resize(0);
        var tempCombo:Int = combo;

        while (tempCombo != 0)
        {
            _digits.push(tempCombo % 10);
            tempCombo = Std.int(tempCombo / 10);
        }
        while (_digits.length < 3)
            _digits.push(0);

        var digitIterator:Int = 1;
        for (digit in _digits)
        {
            if (digit >= _comboEntries.length) return;

            var comboData:RatingSpriteEntry = _comboEntries[digit];
            if (comboData == null) return;

            var numScore:RatingPopup = recyclePopup();

            numScore.loadGraphic(Paths.image('game/ui/ratings/$skin/combo/$digit'));
            numScore.scale.set(comboData.scale[0], comboData.scale[1]);
            numScore.updateHitbox();
            numScore.setPosition(data.position[0] + data.combo.position[0] + comboData.offset[0] - (data.combo.spacing * digitIterator), data.position[1] + data.combo.position[1] + comboData.offset[1]);

            numScore.acceleration.y = FlxG.random.int(250, 300);
            numScore.velocity.y = -FlxG.random.int(130, 150);
            numScore.velocity.x = FlxG.random.float(-5, 5);

            var comboEase = comboData.ease != "stepped" ? EaseUtil.get(comboData.ease) : steppedEase;

            numScore.beginFade((Conductor.instance.stepLengthMs * 4) * 0.002, 0.2, comboEase);

            digitIterator++;
        }
    }

    static function steppedEase(t:Float):Float
    {
        return Math.floor(t * 2) / 2;
    }

    override function destroy()
    {
        _digits = null;
        _comboEntries = null;

        super.destroy();
    }
}

/**
 * A recycleable rating/combo popup sprite.
 */
class RatingPopup extends FunkinSprite
{
    var _fadeDelay:Float = 0;
    var _fadeDuration:Float = 0;
    var _fadeElapsed:Float = 0;

    var _startAlpha:Float = 1;
    var _ease:Float->Float = null;
    var _fading:Bool = false;

    public function new()
    {
        super();
    }

    public function beginFade(delay:Float, duration:Float, ease:Float->Float):Void
    {
        _fadeDelay = delay;
        _fadeDuration = duration;
        _fadeElapsed = 0;

        _startAlpha = alpha;
        _ease = ease;
        _fading = true;
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (!_fading) return;

        if (_fadeDelay > 0)
        {
            _fadeDelay -= elapsed;
            return;
        }

        _fadeElapsed += elapsed;

        var t:Float = _fadeDuration <= 0 ? 1 : Math.min(_fadeElapsed / _fadeDuration, 1);
        var eased:Float = _ease != null ? _ease(t) : t;

        alpha = _startAlpha * (1 - eased);

        if (t >= 1)
        {
            _fading = false;
            kill();
        }
    }

    override public function kill():Void
    {
        _fading = false;
        super.kill();
    }
}
