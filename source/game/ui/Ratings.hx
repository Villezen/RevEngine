package game.ui;

import backend.assets.FunkinSprite;

import flixel.group.FlxSpriteGroup;

import game.PlayMetrics.NoteJudgement;

import backend.registries.ui.RatingsRegistry;
import backend.registries.ui.RatingsRegistry.RatingsData;
import backend.registries.ui.RatingsRegistry.RatingSpriteEntry;

class Ratings extends FlxSpriteGroup
{
    public var data:RatingsData;

    public var skin(default, set):String = "";

    function set_skin(value:String):String
    {
        skin = value;
        data = RatingsRegistry.get(value);

        return skin;
    }

    /**
     * Reused digit buffer for popCombo, so combo splitting doesn't run per hit.
     */
    private var _digits:Array<Int> = [];

    public function new(skin:String)
    {
        super();

        this.skin = skin;
    }


    /**
     * Recycles a rating sprite from the pool or makes a new one.
     */
    private function recyclePopup():FunkinSprite
    {
        var spr:FunkinSprite = cast group.getFirstDead();

        if (spr == null)
        {
            spr = new FunkinSprite();
            add(spr);
        }
        else
        {
            spr.revive();

            group.members.remove(spr);
            group.members.push(spr);
        }

        FlxTween.cancelTweensOf(spr);

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

        var rating:FunkinSprite = recyclePopup();
        rating.loadGraphic(Paths.image('game/ui/ratings/$skin/$ratingStr'));
        rating.scale.set(ratingData.scale[0], ratingData.scale[1]);
        rating.updateHitbox();
        rating.setPosition(data.position[0] + data.ratings.position[0] + ratingData.offset[0], data.position[1] + data.ratings.position[1] + ratingData.offset[1]);

        rating.velocity.x = FlxG.random.int(ratingData.velocity.x[0], ratingData.velocity.x[1]);
        rating.velocity.y = FlxG.random.int(ratingData.velocity.y[0], ratingData.velocity.y[1]);

        rating.acceleration.x = FlxG.random.int(ratingData.acceleration.x[0], ratingData.acceleration.x[1]);
        rating.acceleration.y = FlxG.random.int(ratingData.acceleration.y[0], ratingData.acceleration.y[1]);

        var ratingEase = ratingData.ease != "stepped" ? Reflect.field(FlxEase, ratingData.ease) : function(t:Float):Float return {Math.floor(t * 2) / 2;}

        FlxTween.tween(rating, {alpha: 0}, 0.2 * ratingData.timeMult, {onComplete: function(tween:FlxTween)
        {
            rating.kill();
        }, startDelay: (Conductor.instance.stepLengthMs * 4) * 0.001, ease: ratingEase});
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
            var comboData:RatingSpriteEntry = Reflect.field(data.combo, 'num$digit');
            if (comboData == null) return;

            var numScore:FunkinSprite = recyclePopup();
            numScore.loadGraphic(Paths.image('game/ui/ratings/$skin/combo/$digit'));
            numScore.scale.set(comboData.scale[0], comboData.scale[1]);
            numScore.updateHitbox();
            numScore.setPosition(data.position[0] + data.combo.position[0] + comboData.offset[0] - (data.combo.spacing * digitIterator), data.position[1] + data.combo.position[1] + comboData.offset[1]);

            numScore.acceleration.y = FlxG.random.int(250, 300);
            numScore.velocity.y = -FlxG.random.int(130, 150);
            numScore.velocity.x = FlxG.random.float(-5, 5);

            var comboEase = comboData.ease != "stepped" ? Reflect.field(FlxEase, comboData.ease) : function(t:Float):Float return {Math.floor(t * 2) / 2;}

            FlxTween.tween(numScore, {alpha: 0}, 0.2, {onComplete: function(tween:FlxTween)
            {
                numScore.kill();
            }, startDelay: (Conductor.instance.stepLengthMs * 4) * 0.002, ease: comboEase});

            digitIterator++;
        }
    }

    override function destroy()
    {
        _digits = null;

        super.destroy();
    }
}
