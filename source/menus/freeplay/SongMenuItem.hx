package menus.freeplay;

import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;

import backend.utils.MathUtil;
import backend.registries.song.ChartRegistry;

typedef FreeplaySongData =
{
    var id:String;
    var name:String;
    var bpm:Int;
    var difficultyRating:Int;
    var icon:String;

    @:optional var difficulties:Array<String>;
    @:optional var newlyAdded:Bool;
    @:optional var variation:String;
    @:optional var albumId:String;
}

class SongMenuItem extends FlxSpriteGroup
{
    public var capsule:FunkinSprite;

    public var freeplayData(default, null):Null<FreeplaySongData> = null;

    public var selected(default, set):Bool;
    public var forceHighlight(default, set):Bool;

    var songText:CapsuleText;

    var pixelIcon:PixelatedIcon;

    public var favIcon:FunkinSprite;
    public var favIconBlurred:FunkinSprite;

    public var isFav:Bool = false;

    public var bpmText:FunkinSprite;
    public var difficultyText:FunkinSprite;
    public var newText:FunkinSprite;

    var difficultyNumbers:Array<CapsuleNumber> = [];
    var bpmNumbers:Array<CapsuleNumber> = [];

    public var targetPos:FlxPoint = new FlxPoint();
    public var doLerp:Bool = false;
    public var doJumpIn:Bool = false;
    public var doJumpOut:Bool = false;

    public var onConfirm:Void->Void;

    var grpHide:FlxGroup;

    var index:Int;

    public var curSelected:Int;

    public var realScaled:Float = 0.8;

    public function new(x:Float, y:Float, ?character:String = "bf")
    {
        super(x, y);

        capsule = new FunkinSprite(0, 0, 'menus/freeplay/characters/$character/capsule');
        capsule.addAnim('selected', {prefix: 'mp3 capsule w backing0', looped: true});
        capsule.addAnim('unselected', {prefix: 'mp3 capsule w backing NOT SELECTED', looped: true});
        add(capsule);

        bpmText = new FunkinSprite(144, 87, 'menus/freeplay/capsule/bpmtext');
        bpmText.setGraphicSize(Std.int(bpmText.width * 0.9));
        add(bpmText);

        difficultyText = new FunkinSprite(414, 87, 'menus/freeplay/capsule/difficultytext');
        difficultyText.setGraphicSize(Std.int(difficultyText.width * 0.9));
        add(difficultyText);

        newText = new FunkinSprite(454, 9, 'menus/freeplay/capsule/new');
        newText.addAnim('newAnim', {prefix: 'NEW notif', looped: true});
        newText.playAnim('newAnim');
        newText.setGraphicSize(Std.int(newText.width * 0.9));
        newText.visible = false;
        add(newText);

        for (i in 0...2)
        {
            var num:CapsuleNumber = new CapsuleNumber(466 + (i * 30), 32, true, 0);
            add(num);

            difficultyNumbers.push(num);
        }

        for (i in 0...3)
        {
            var num:CapsuleNumber = new CapsuleNumber(185 + (i * 11), 88.5, false, 0);
            add(num);

            bpmNumbers.push(num);
        }

        grpHide = new FlxGroup();

        songText = new CapsuleText(capsule.width * 0.26, 45, 'Random', Std.int(40 * realScaled));
        add(songText);
        grpHide.add(songText);

        pixelIcon = new PixelatedIcon(160, 35);
        add(pixelIcon);

        favIconBlurred = new FunkinSprite(405, 40, 'menus/freeplay/favHeart');
        favIconBlurred.addAnim('fav', {prefix: 'favorite heart'});
        favIconBlurred.setGraphicSize(50, 50);
        favIconBlurred.updateHitbox();
        favIconBlurred.blend = BlendMode.ADD;
        favIconBlurred.visible = false;
        add(favIconBlurred);

        favIcon = new FunkinSprite(405, 40, 'menus/freeplay/favHeart');
        favIcon.addAnim('fav', {prefix: 'favorite heart'});
        favIcon.setGraphicSize(50, 50);
        favIcon.updateHitbox();
        favIcon.blend = BlendMode.ADD;
        favIcon.visible = false;
        add(favIcon);

        updateDifficultyRating(0);

        setVisibleGrp(false);
    }

    public function setFavorite(fav:Bool, animate:Bool = false):Void
    {
        isFav = fav;

        favIcon.visible = fav;
        favIconBlurred.visible = fav;

        if (fav)
        {
            favIcon.playAnim('fav', {force: true});
            favIconBlurred.playAnim('fav', {force: true});

            if (!animate)
            {
                if (favIcon.animation.curAnim != null)
                    favIcon.animation.curAnim.curFrame = favIcon.animation.curAnim.numFrames - 1;

                if (favIconBlurred.animation.curAnim != null)
                    favIconBlurred.animation.curAnim.curFrame = favIconBlurred.animation.curAnim.numFrames - 1;
            }
        }

        if (freeplayData != null) songText.clipWidth = fav ? 245 : 290;

        updateSelected();
    }

    public function toggleFavorite():Bool
    {
        setFavorite(!isFav, true);
        return isFav;
    }

    public function initPosition(x:Float, y:Float):Void
    {
        this.x = x;
        this.y = y;
    }

    public function initData(data:Null<FreeplaySongData>, index:Int):Void
    {
        this.freeplayData = data;
        this.index = index;

        refreshDisplay();
    }

    public function refreshDisplay():Void
    {
        if (freeplayData == null)
        {
            songText.text = 'Random';
            newText.visible = false;
            pixelIcon.setCharacter("");
            setStatsVisible(false);
        }
        else
        {
            songText.text = freeplayData.name;

            updateBPM(freeplayData.bpm);
            updateDifficultyRating(freeplayData.difficultyRating);

            var iconChar:String = resolveIconCharacter();
            pixelIcon.setCharacter(iconChar);
            if (pixelIcon.char != iconChar) pixelIcon.visible = false;

            newText.visible = freeplayData.newlyAdded == true;
            songText.clipWidth = isFav ? 245 : 290;
            setStatsVisible(true);
        }

        updateSelected();
    }

    public function refreshRating():Void
    {
        if (freeplayData == null) return;

        updateDifficultyRating(freeplayData.difficultyRating);
    }

    public function staggerNew(index:Int):Void
    {
        if (newText.animation.curAnim != null)
        {
            var frames:Int = newText.animation.curAnim.numFrames;
            newText.animation.curAnim.curFrame = (frames - ((index * 4) % frames)) % frames;
        }
    }

    function setStatsVisible(value:Bool):Void
    {
        bpmText.visible = value;
        difficultyText.visible = value;

        for (num in bpmNumbers)
            num.visible = value;

        for (num in difficultyNumbers)
            num.visible = value;
    }

    function resolveIconCharacter():String
    {
        if (freeplayData == null) return "";

        var iconChar:String = freeplayData.icon;

        if (!PixelatedIcon.iconExists(iconChar))
            iconChar = getOpponentCharacter(freeplayData.id);

        return (iconChar == null) ? "" : iconChar;
    }

    function getOpponentCharacter(songId:String):String
    {
        var variation:String = (freeplayData != null && freeplayData.variation != null) ? freeplayData.variation : "";

        var difficulty:String = Constants.DEFAULT_DIFFICULTY;
        var available:Array<String> = ChartRegistry.listDifficulties(songId, variation);

        if (available.length > 0 && !available.contains(difficulty))
            difficulty = available[0];

        var chart = ChartRegistry.get(songId, difficulty, variation);

        if (chart == null || chart.strumlines == null || chart.strumlines.length == 0)
            return "";

        for (strum in chart.strumlines)
        {
            if (strum != null && strum.id == 0 && strum.character != null)
                return strum.character;
        }

        var first = chart.strumlines[0];
        return (first != null && first.character != null) ? first.character : "";
    }

    function updateBPM(newBPM:Int):Void
    {
        var shiftX:Float = 191;
        var tempShift:Float = 0;

        if (Math.floor(newBPM / 100) == 1)
            shiftX = 186;

        for (i in 0...bpmNumbers.length)
        {
            bpmNumbers[i].x = this.x + (shiftX + (i * 11));
            switch (i)
            {
                case 0:
                {
                    if (newBPM < 100)
                        bpmNumbers[i].digit = 0;
                    else
                        bpmNumbers[i].digit = Math.floor(newBPM / 100) % 10;
                }
                case 1:
                {
                    if (newBPM < 10)
                        bpmNumbers[i].digit = 0;
                    else
                    {
                        bpmNumbers[i].digit = Math.floor(newBPM / 10) % 10;

                        if (Math.floor(newBPM / 10) % 10 == 1)
                            tempShift = -4;
                    }
                }
                case 2:
                {
                    bpmNumbers[i].digit = newBPM % 10;

                    if (Math.floor(newBPM) % 10 == 1)
                        tempShift -= 4;
                }
            }

            bpmNumbers[i].x += tempShift;
        }
    }

    function updateDifficultyRating(newRating:Int):Void
    {
        for (i in 0...difficultyNumbers.length)
        {
            switch (i)
            {
                case 0:
                {
                    if (newRating < 10)
                        difficultyNumbers[i].digit = 0;
                    else
                        difficultyNumbers[i].digit = Math.floor(newRating / 10);
                }
                case 1:
                    difficultyNumbers[i].digit = newRating % 10;
            }
        }
    }

    var frameInTicker:Float = 0;
    var frameInTypeBeat:Int = 0;

    var frameOutTicker:Float = 0;
    var frameOutTypeBeat:Int = 0;

    var xFrames:Array<Float> = [1.7, 1.8, 0.85, 0.85, 0.97, 0.97, 1];
    var xPosLerpLol:Array<Float> = [0, 0, 0.16, 0.16, 0.22, 0.22, 0.245]; 
    var xPosOutLerpLol:Array<Float> = [0.245, 0.75, 0.98, 0.98, 1.2];

    public function initJumpIn(maxTimer:Float, ?force:Bool = false):Void
    {
        frameInTypeBeat = 0;

        new FlxTimer().start((1 / 24) * maxTimer, function(doShit)
        {
            doJumpIn = true;
            doLerp = true;
        });

        if (force)
        {
            visible = true;
            capsule.alpha = 1;
            setVisibleGrp(true);
        }
        else
        {
            new FlxTimer().start((xFrames.length / 24) * 2.5, function(_)
            {
                visible = true;
                capsule.alpha = 1;
                setVisibleGrp(true);
            });
        }
    }

    public function forcePosition():Void
    {
        visible = true;
        capsule.alpha = 1;

        updateSelected();

        doLerp = true;
        doJumpIn = false;
        doJumpOut = false;

        frameInTypeBeat = xFrames.length;
        frameOutTypeBeat = 0;

        capsule.scale.x = xFrames[frameInTypeBeat - 1];
        capsule.scale.y = 1 / xFrames[frameInTypeBeat - 1];

        x = targetPos.x;
        y = targetPos.y;

        capsule.scale.x *= realScaled;
        capsule.scale.y *= realScaled;

        setVisibleGrp(true);
    }

    override function update(elapsed:Float):Void
    {
        if (doJumpIn)
        {
            frameInTicker += elapsed;

            if (frameInTicker >= 1 / 24 && frameInTypeBeat < xFrames.length)
            {
                frameInTicker = 0;

                capsule.scale.x = xFrames[frameInTypeBeat];
                capsule.scale.y = 1 / xFrames[frameInTypeBeat];
                targetPos.x = FlxG.width * xPosLerpLol[Std.int(Math.min(frameInTypeBeat, xPosLerpLol.length - 1))];
                capsule.scale.x *= realScaled;
                capsule.scale.y *= realScaled;

                frameInTypeBeat += 1;

                final shiftx:Float = 320;

                if (targetPos.x <= shiftx)
                    targetPos.x = intendedX(index - curSelected);
            }
            else if (frameInTypeBeat == xFrames.length)
            {
                doJumpIn = false;
            }
        }

        if (doJumpOut)
        {
            frameOutTicker += elapsed;

            if (frameOutTicker >= 1 / 24 && frameOutTypeBeat < xFrames.length)
            {
                frameOutTicker = 0;

                capsule.scale.x = xFrames[frameOutTypeBeat];
                capsule.scale.y = 1 / xFrames[frameOutTypeBeat];
                this.x = FlxG.width * xPosOutLerpLol[Std.int(Math.min(frameOutTypeBeat, xPosOutLerpLol.length - 1))];

                capsule.scale.x *= realScaled;
                capsule.scale.y *= realScaled;

                frameOutTypeBeat += 1;
            }
            else if (frameOutTypeBeat == xFrames.length)
            {
                doJumpOut = false;
            }
        }

        if (doLerp)
        {
            x = MathUtil.smoothLerpPrecision(x, targetPos.x, elapsed, 0.256);
            y = MathUtil.smoothLerpPrecision(y, targetPos.y, elapsed, 0.192);
        }

        super.update(elapsed);
    }

    public function confirm():Void
    {
        if (songText != null)
        {
            textAppear();
            songText.flickerText();
        }

        if (pixelIcon != null && pixelIcon.visible)
            pixelIcon.confirm();
    }

    function textAppear():Void
    {
        songText.scale.x = 1.7;
        songText.scale.y = 0.2;

        new FlxTimer().start(1 / 24, function(_)
        {
            songText.scale.x = 0.4;
            songText.scale.y = 1.4;
        });

        new FlxTimer().start(2 / 24, function(_)
        {
            songText.scale.x = songText.scale.y = 1;
        });
    }

    public function intendedX(index:Float):Float
    {
        return 270 + (60 * (FlxMath.fastSin(index)));
    }

    public function intendedY(index:Float):Float
    {
        return (index * ((capsule.height * realScaled) + 10)) + 120;
    }

    function set_selected(value:Bool):Bool
    {
        final wasSelected:Bool = selected;

        selected = value;
        if (wasSelected != selected)
        {
            updateSelected();
        }
        return selected;
    }

    function set_forceHighlight(value:Bool):Bool
    {
        forceHighlight = value;
        updateSelected();
        return forceHighlight;
    }

    public function updateSelected():Void
    {
        final isSelected:Bool = (this.selected || this.forceHighlight);

        songText.alpha = isSelected ? 1 : 0.6;
        songText.blurredText.visible = isSelected ? true : false;
        capsule.playAnim(isSelected ? "selected" : "unselected");
        capsule.offset.x = isSelected ? 0 : -5;

        favIcon.alpha = isSelected ? 1 : 0.6;
        favIconBlurred.alpha = isSelected ? 1 : 0;

        if (songText.tooLong) songText.resetText();

        if (selected && songText.tooLong) songText.initMove();
    }

    function setVisibleGrp(value:Bool):Void
    {
        for (spr in grpHide.members)
        {
            spr.visible = value;
        }

        updateSelected();
    }

    public override function kill():Void
    {
        super.kill();

        visible = true;
        capsule.alpha = 1;
        doLerp = false;
        doJumpIn = false;
        doJumpOut = false;
    }
}
