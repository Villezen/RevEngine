package menus.freeplay;

import flixel.group.FlxSpriteGroup;

class LetterSort extends FlxSpriteGroup
{
    public var letters:Array<FreeplayLetter> = [];
    var curSelection:Int = 2;

    public var changeSelectionCallback:String->Void;

    var leftArrow:FunkinSprite;
    var rightArrow:FunkinSprite;
    var grpSeperators:FlxSpriteGroup;

    public function new(x:Float, y:Float)
    {
        super(x, y);

        grpSeperators = new FlxSpriteGroup();
        add(grpSeperators);

        leftArrow = new FunkinSprite(-20, 15, 'menus/freeplay/miniArrow');
        leftArrow.flipX = true;
        add(leftArrow);

        rightArrow = new FunkinSprite(380, 15, 'menus/freeplay/miniArrow');
        add(rightArrow);

        for (i in 0...5)
        {
            var letter:FreeplayLetter = new FreeplayLetter(i * 80, 0, i, curSelection);
            letter.x += 57;
            letter.y += 60;
            add(letter);

            letters.push(letter);

            if (i != 2)
            {
                letter.scale.x = letter.scale.y = 0.8;
                letter.x -= 10;
                letter.y -= 12;
            }

            var darkness:Float = Math.max(Math.abs(i - 2) / 6, 0.01);
            letter.color = letter.color.getDarkened(darkness);

            if (i == 4) continue;

            var sep:FunkinSprite = new FunkinSprite((i * 80) + 60, 20, 'menus/freeplay/seperator');
            sep.color = letter.color.getDarkened(darkness);
            grpSeperators.add(sep);
        }

        changeSelection(0);
    }

    public function changeSelection(diff:Int = 0, playSound:Bool = true):Void
    {
        doLetterChangeAnims(diff);

        var multiPosOrNeg:Float = diff > 0 ? 1 : -1;

        var arrowToMove:FunkinSprite = diff < 0 ? leftArrow : rightArrow;
        arrowToMove.offset.x = 3 * multiPosOrNeg;

        new FlxTimer().start(2 / 24, function(_)
        {
            arrowToMove.offset.x = 0;
        });

        if (playSound && diff != 0) FunkinSound.playOnce(Paths.sound('engine/scroll'), 0.4);
    }

    function doLetterChangeAnims(diff:Int):Void
    {
        var ezTimer = function(frameNum:Int, spr:FlxSprite, offsetNum:Float)
        {
            new FlxTimer().start(frameNum / 24, function(_)
            {
                spr.offset.x = offsetNum;
            });
        };

        var positions:Array<Float> = [-10, -22, 2, 0];
        var multiPosOrNeg:Float = diff > 0 ? 1 : -1;

        for (sep in grpSeperators.members)
        {
            ezTimer(0, sep, positions[0] * multiPosOrNeg);
            ezTimer(1, sep, positions[1] * multiPosOrNeg);
            ezTimer(2, sep, positions[2] * multiPosOrNeg);
            ezTimer(3, sep, positions[3] * multiPosOrNeg);
        }

        for (index => letter in letters)
        {
            letter.offset.x = positions[0] * multiPosOrNeg;

            new FlxTimer().start(1 / 24, function(_)
            {
                letter.offset.x = positions[1] * multiPosOrNeg;
                if (index == 0) letter.visible = false;
            });

            new FlxTimer().start(2 / 24, function(_)
            {
                letter.offset.x = positions[2] * multiPosOrNeg;
                if (index == 0) letter.visible = true;
            });

            if (index == 2)
            {
                ezTimer(3, letter, 0);
                continue;
            }

            ezTimer(3, letter, positions[3] * multiPosOrNeg);
        }

        curSelection += diff;
        if (curSelection < 0) curSelection = letters[0].regexLetters.length - 1;
        if (curSelection >= letters[0].regexLetters.length) curSelection = 0;

        for (letter in letters)
            letter.changeLetter(diff, curSelection);

        if (changeSelectionCallback != null) changeSelectionCallback(letters[2].regexLetters[letters[2].curLetter]);
    }
}

class FreeplayLetter extends FunkinSprite
{
    public var regexLetters:Array<String> = [];
    public var animLetters:Array<String> = [];
    public var curLetter:Int = 0;

    public function new(x:Float, y:Float, ?letterInd:Int, curSelected:Int = 0)
    {
        super(x, y, 'menus/freeplay/sortedLetters');

        var alphabet:String = 'A-B_C-D_E-H_I-L_M-N_O-R_S_T_U-Z';
        regexLetters = alphabet.split('_');
        regexLetters.insert(0, 'ALL');
        regexLetters.insert(0, 'fav');
        regexLetters.insert(0, '#');

        animLetters = regexLetters.map(animLetter -> animLetter.replace('-', ''));

        for (letter in animLetters)
            addAnim(letter + ' move', {prefix: letter + ' move', looped: true});

        if (letterInd != null)
        {
            playAnim(animLetters[letterInd] + ' move', {force: true});
            curLetter = letterInd;

            if (curSelected != curLetter) pauseAnim();
        }
    }

    public function changeLetter(diff:Int = 0, ?curSelection:Int):Void
    {
        curLetter += diff;

        if (curLetter < 0) curLetter = regexLetters.length - 1;
        if (curLetter >= regexLetters.length) curLetter = 0;

        playAnim(animLetters[curLetter] + ' move', {force: true});

        if (curSelection != curLetter) pauseAnim();
    }

    function pauseAnim():Void
    {
        if (atlasSpr != null) atlasSpr.anim.pause();
    }
}
