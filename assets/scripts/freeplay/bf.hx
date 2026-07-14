class BFBackingCard extends BackingCard
{
    var bands:Array<BGScrollingText> = [];

    var cardGlow:FunkinSprite;
    var orangeBox:FunkinSprite;
    var orangeAccent:FunkinSprite;
    var confirmGlow:FunkinSprite;
    var confirmGlow2:FunkinSprite;
    var backingText:FunkinSprite;

    var revealed:Bool = false;
    var beatPulse:Float = 0;

    function new()
    {
        super("bf");
    }

    override function onCreate(freeplay)
    {
        bands = [];
        revealed = false;
        beatPulse = 0;
    }

    override function onCardCreate(freeplay)
    {
        var w:Float = (freeplay.card != null) ? freeplay.card.width : 520;
        var h:Float = (freeplay.card != null) ? freeplay.card.height : 720;

        cardGlow = new FunkinSprite(-30, -30, 'menus/freeplay/cardGlow');
        cardGlow.alpha = 0;
        freeplay.cardLayer.add(cardGlow);

        orangeBox = new FunkinSprite(0, h * 0.6).makeGraphic(Std.int(w), 80, 0xFFFEDA00);
        orangeBox.visible = false;
        freeplay.cardLayer.add(orangeBox);

        orangeAccent = new FunkinSprite(0, orangeBox.y).makeGraphic(110, 80, 0xFFFFD400);
        orangeAccent.visible = false;
        freeplay.cardLayer.add(orangeAccent);

        makeBand(freeplay, 60,  "HOT BLOODED IN MORE WAYS THAN ONE ", 40, 0.9);
        makeBand(freeplay, 140, "BOYFRIEND ", 65, -1.1);
        makeBand(freeplay, 225, "PROTECT YO NUTS ", 50, 1.0);
        makeBand(freeplay, 315, "BOYFRIEND ", 65, -1.1);
        makeBand(freeplay, 400, "HOT BLOODED IN MORE WAYS THAN ONE ", 40, 0.9);
        makeBand(freeplay, 485, "BOYFRIEND ", 65, -1.1);
        makeBand(freeplay, 565, "PROTECT YO NUTS ", 50, 1.0);

        confirmGlow2 = new FunkinSprite(-30, 200, 'menus/freeplay/characters/bf/confirmGlow2');
        confirmGlow2.visible = false;
        freeplay.cardLayer.add(confirmGlow2);

        confirmGlow = new FunkinSprite(-30, 200, 'menus/freeplay/characters/bf/confirmGlow');
        confirmGlow.visible = false;
        freeplay.cardLayer.add(confirmGlow);

        backingText = new FunkinSprite(-20, 120, 'menus/freeplay/characters/bf/backingText');
        backingText.addAnim("yeah", {prefix: "YEAH"});
        backingText.visible = false;
        freeplay.cardLayer.add(backingText);
    }

    function makeBand(freeplay, y:Float, text:String, size:Int, speed:Float)
    {
        var band = new BGScrollingText(0, y, text, 700, true, size);
        band.color = 0xFFD1A02A;
        band.speed = speed;
        band.alpha = 0;

        freeplay.cardLayer.add(band);
        bands.push(band);
    }

    override function onPostCreate(freeplay) {}

    override function onIntroDone(freeplay)
    {
        revealed = true;

        if (orangeBox != null) orangeBox.visible = true;
        if (orangeAccent != null) orangeAccent.visible = true;

        for (i in 0...bands.length)
        {
            if (bands[i] != null)
                FlxTween.tween(bands[i], {alpha: 0.7}, 0.5, {ease: FlxEase.quartOut});
        }
    }

    override function onBeatHit(freeplay, beat:Int)
    {
        beatPulse = 1;
    }

    override function onUpdate(freeplay, elapsed:Float)
    {
        if (beatPulse > 0)
            beatPulse = Math.max(0, beatPulse - elapsed * 2.5);

        if (cardGlow != null)
            cardGlow.alpha = revealed ? (0.12 + beatPulse * 0.4) : 0;
    }

    override function onSelect(freeplay, ?song:Dynamic)
    {
        if (confirmGlow2 != null)
        {
            confirmGlow2.visible = true;
            confirmGlow2.alpha = 0;
            FlxTween.tween(confirmGlow2, {alpha: 0.6}, 0.33, {ease: FlxEase.quadOut});
        }

        if (confirmGlow != null)
        {
            confirmGlow.visible = true;
            confirmGlow.alpha = 0;
            FlxTween.tween(confirmGlow, {alpha: 1}, 0.33, {ease: FlxEase.quadOut});
        }

        if (backingText != null)
        {
            backingText.visible = true;
            backingText.playAnim("yeah", {force: true});
        }

        if (freeplay.backingImage != null)
        {
            FlxTween.color(freeplay.backingImage, 0.5, freeplay.backingImage.color, 0xFF646464,
            {
                onUpdate: (_) -> { freeplay.angleMaskShader.extraColor = freeplay.backingImage.color; }
            });
        }
    }

    override function onDestroy(freeplay)
    {
        for (i in 0...bands.length)
        {
            if (bands[i] != null)
                FlxTween.cancelTweensOf(bands[i]);
        }

        if (cardGlow != null) FlxTween.cancelTweensOf(cardGlow);
        if (confirmGlow != null) FlxTween.cancelTweensOf(confirmGlow);
        if (confirmGlow2 != null) FlxTween.cancelTweensOf(confirmGlow2);

        if (freeplay != null && freeplay.backingImage != null)
            FlxTween.cancelTweensOf(freeplay.backingImage);

        bands = [];
        cardGlow = null;
        orangeBox = null;
        orangeAccent = null;
        confirmGlow = null;
        confirmGlow2 = null;
        backingText = null;
    }
}
