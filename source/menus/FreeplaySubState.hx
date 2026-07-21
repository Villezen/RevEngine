package menus;

import flixel.FlxCamera;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;

import backend.MusicBeatSubState;
import backend.Highscore;
import backend.shaders.AngleMask;
import backend.shaders.StrokeShader;
import backend.shaders.GaussianBlurShader;
import backend.ui.BGScrollingText;
import backend.utils.MathUtil;
import backend.transition.TransitionLoader;
import backend.modding.modules.BackingCard;
import backend.modding.handlers.BackingCardHandler;
import backend.registries.menus.FreeplayRegistry;
import backend.registries.song.MetaRegistry;
import backend.registries.song.ChartRegistry;
import backend.registries.song.DifficultyRegistry;
import backend.registries.misc.PlayerRegistry;

import game.PlayState;
import game.handlers.Preloader;

import menus.freeplay.SongMenuItem;
import menus.freeplay.SongMenuItem.FreeplaySongData;
import menus.freeplay.LetterSort;
import menus.freeplay.DifficultySelector;
import menus.freeplay.FreeplayScore;
import menus.freeplay.ClearPercentCounter;
import menus.freeplay.AlbumRoll;

class FreeplaySubState extends MusicBeatSubState
{
    public static var CURRENT_CHARACTER:String = "bf";

    public var angleMaskShader:AngleMask = new AngleMask();

    var camCapsules:FlxCamera;
    var camUI:FlxCamera;
    var camOverlay:FlxCamera;

    var menuSong:FunkinSound;

    public var card:FunkinSprite;
    var backingImage:FunkinSprite;
    var blackOverlay:FunkinSprite;
    var bopper:FunkinSprite;

    var topBar:FunkinSprite;
    var menuName:FlxText;
    var ostName:FlxText;
    var charSelectHint:FlxText;

    var capsules:Array<SongMenuItem> = [];
    var songs:Array<FreeplaySongData> = [];

    var curSelected:Int = 0;

    var busy:Bool = true;
    var entering:Bool = false;

    var shouldEnter:Bool = false;
    var canEnter:Bool = false;

    var pendingSong:String = null;
    var pendingVariation:String = "";

    var hintTimer:Float = 0;

    var allSongs:Array<FreeplaySongData> = [];
    var curFilter:String = "ALL";

    var availableCharacters:Array<String> = [];

    var letterSort:LetterSort;

    var curDifficulty:String = "normal";

    var difficultySelector:DifficultySelector;

    var cardLayer:FlxSpriteGroup;
    var currentCard:BackingCard = null;
    var introFinished:Bool = false;

    var bands:Array<BGScrollingText> = [];

    var cardGlow:FunkinSprite;
    var orangeBox:FunkinSprite;
    var orangeAccent:FunkinSprite;
    var confirmGlow:FunkinSprite;
    var confirmGlow2:FunkinSprite;

    var yeahText:FunkinSprite;
    var bigShoesText:FunkinSprite;
    var yesYesYesText:FunkinSprite;
    var getItText:FunkinSprite;

    var yeahTextBlurred:FunkinSprite;
    var bigShoesTextBlurred:FunkinSprite;
    var yesYesYesTextBlurred:FunkinSprite;
    var getItTextBlurred:FunkinSprite;

    var revealed:Bool = false;

    var highscoreSpr:FunkinSprite;
    var scoreDisplay:FreeplayScore;
    var clearBox:FunkinSprite;
    var clearPercentCounter:ClearPercentCounter;

    var albumRoll:AlbumRoll;

    var intendedScore:Int = 0;
    var lerpScore:Float = 0;
    var intendedCompletion:Float = 0;
    var lerpCompletion:Float = 0;

    var highscoreFlickerActive:Bool = true;

    var variations:Array<String> = [""];
    var diffCache:Map<String, Array<String>> = new Map();

    override function create():Void
    {
        BackingCardHandler.load();

        camCapsules = new FlxCamera();
        camCapsules.bgColor = 0x00000000;
        FlxG.cameras.add(camCapsules, false);

        camUI = new FlxCamera();
        camUI.bgColor = 0x00000000;
        FlxG.cameras.add(camUI, false);

        camOverlay = new FlxCamera();
        camOverlay.bgColor = 0x00000000;
        FlxG.cameras.add(camOverlay, false);

        if (FlxG.sound.music != null && FlxG.sound.music.playing)
            FlxG.sound.music.fadeOut(0.3, 0);

        menuSong = FunkinSound.load(Paths.music(FreeplayRegistry.data.theme.path), 1.0, true);

        conductor.reset();
        conductor.setBPM(FreeplayRegistry.data.theme.bpm);

        card = new FunkinSprite(0, 0, 'menus/freeplay/card');
        card.setGraphicSize(0, FlxG.height + 1);
        card.updateHitbox();
        card.color = 0xFFFFD4E9;
        card.x -= card.width;
        add(card);

        cardLayer = BackingCard.createLayer();
        add(cardLayer);

        FlxTween.tween(card, {x: 0}, 0.6, {ease: FlxEase.quartOut});

        backingImage = new FunkinSprite(370, 0, 'menus/freeplay/characters/' + CURRENT_CHARACTER + '/bg');
        backingImage.shader = angleMaskShader;
        backingImage.visible = false;

        blackOverlay = new FunkinSprite(FlxG.width, 0);
        blackOverlay.makeGraphic(Std.int(backingImage.width), Std.int(backingImage.height), 0xFF000000);

        backingImage.setGraphicSize(0, FlxG.height + 1);
        blackOverlay.setGraphicSize(0, FlxG.height + 1);

        backingImage.updateHitbox();
        blackOverlay.updateHitbox();

        blackOverlay.shader = angleMaskShader;

        add(blackOverlay);
        add(backingImage);

        topBar = new FunkinSprite().makeGraphic(camUI.width, 164, 0xFF000000);
        topBar.camera = camUI;
        topBar.y -= topBar.height;
        add(topBar);

        menuName = new FlxText(8, 8, 0, "FREEPLAY", 48);
        menuName.camera = camUI;
        menuName.font = 'VCR OSD Mono';
        menuName.alignment = FlxTextAlign.LEFT;
        menuName.visible = false;
        menuName.shader = new StrokeShader(0xFFFFFFFF, 2, 2);
        add(menuName);

        ostName = new FlxText(8, 8, FlxG.width - 8 - 8, "OFFICIAL OST", 48);
        ostName.camera = camUI;
        ostName.font = 'VCR OSD Mono';
        ostName.alignment = FlxTextAlign.RIGHT;
        ostName.visible = false;
        ostName.shader = new StrokeShader(0xFFFFFFFF, 4, 2);
        add(ostName);

        buildHighscorePanel();
        buildAlbumRoll();

        charSelectHint = new FlxText(-40, 18, FlxG.width - 8 - 8, 'Press [ TAB ] to change characters', 32);
        charSelectHint.camera = camUI;
        charSelectHint.alignment = FlxTextAlign.CENTER;
        charSelectHint.font = "5by7";
        charSelectHint.color = 0xFF5F5F5F;
        add(charSelectHint);

        charSelectHint.y -= 100;
        FlxTween.tween(charSelectHint, {y: charSelectHint.y + 100}, 0.8, {ease: FlxEase.quartOut});

        FlxTween.tween(topBar, {y: -100}, 0.3, {ease: FlxEase.quartOut});
        FlxTween.tween(blackOverlay, {x: backingImage.x}, 0.7, {ease: FlxEase.quintOut});

        bopper = new FunkinSprite(30, 0, 'menus/freeplay/characters/' + CURRENT_CHARACTER + '/dj');
        bopper.addAnim("intro", {prefix: "Intro"});
        bopper.addAnim("idle", {prefix: "Idle"});
        bopper.addAnim("confirm", {prefix: "Confirm"});
        bopper.playAnim("intro", {onComplete: () -> begin()});
        add(bopper);

        loadAllSongs();
        buildLetterSort();
        buildDifficultySelector();
        rebuildSongList();

        activateCard();

        super.create();
    }

    function activateCard():Void
    {
        currentCard = BackingCardHandler.get(CURRENT_CHARACTER);

        resetBackingCard();
        createBackingCard();

        if (currentCard != null)
        {
            currentCard.onCreate(this);
            currentCard.onCardCreate(this);
            currentCard.onCreatePost(this);
        }

        if (introFinished)
        {
            revealBackingCard();

            if (currentCard != null)
                currentCard.onIntroDone(this);
        }
    }

    function deactivateCard():Void
    {
        destroyBackingCard();

        if (currentCard != null)
        {
            currentCard.onDestroy(this);
            currentCard = null;
        }

        if (cardLayer != null)
        {
            var oldMembers = cardLayer.members.copy();
            cardLayer.clear();

            for (member in oldMembers)
            {
                if (member != null)
                {
                    FlxTween.cancelTweensOf(member);
                    member.destroy();
                }
            }
        }
    }

    function resetBackingCard():Void
    {
        bands = [];
        revealed = false;
    }

    function createBackingCard():Void
    {
        var w:Float = (card != null) ? card.width : 520;
        var h:Float = (card != null) ? card.height : 720;

        orangeBox = new FunkinSprite(0, 440).makeGraphic(Std.int(w), 80, 0xFFFEDA00);
        orangeBox.visible = false;
        cardLayer.add(orangeBox);

        orangeAccent = new FunkinSprite(0, orangeBox.y).makeGraphic(110, 80, 0xFFFFD400);
        orangeAccent.visible = false;
        cardLayer.add(orangeAccent);

        makeBand(160, "HOT BLOODED IN MORE WAYS THAN ONE ", FlxG.width, true, 43, 0xFFFFF383, 6.8);
        makeBand(220, "BOYFRIEND ", FlxG.width / 2, false, 60, 0xFFFF9963, -3.8);
        makeBand(285, "PROTECT YO NUTS ", FlxG.width / 2, true, 43, 0xFFFFFFFF, 3.5);
        makeBand(335, "BOYFRIEND ", FlxG.width / 2, false, 60, 0xFFFF9963, -3.8);
        makeBand(397, "HOT BLOODED IN MORE WAYS THAN ONE ", FlxG.width, true, 43, 0xFFFFF383, 6.8);
        makeBand(450, "BOYFRIEND ", FlxG.width / 2, false, 60, 0xFFFEA400, -3.8);

        confirmGlow2 = new FunkinSprite(-30, 200, 'menus/freeplay/characters/bf/confirmGlow2');
        confirmGlow2.visible = false;
        cardLayer.add(confirmGlow2);

        confirmGlow = new FunkinSprite(-30, 200, 'menus/freeplay/characters/bf/confirmGlow');
        confirmGlow.visible = false;
        confirmGlow.blend = ADD;
        cardLayer.add(confirmGlow);

        yeahTextBlurred = makeConfirmText(-3, 195, "yeah", "YEAH", true);
        bigShoesTextBlurred = makeConfirmText(-3, 140, "BIG SHOES", "BIG SHOES", true);
        yesYesYesTextBlurred = makeConfirmText(-3, 310, "YES YES YES", "YES YES YES", true);
        getItTextBlurred = makeConfirmText(-3, 380, "GET IT", "GET IT", true);

        yeahText = makeConfirmText(-3, 195, "yeah", "YEAH", false);
        bigShoesText = makeConfirmText(-3, 140, "BIG SHOES", "BIG SHOES", false);
        yesYesYesText = makeConfirmText(-3, 310, "YES YES YES", "YES YES YES", false);
        getItText = makeConfirmText(-3, 380, "GET IT", "GET IT", false);

        cardGlow = new FunkinSprite(-20, 0, 'menus/freeplay/cardGlow');
        cardGlow.alpha = 1;
        cardGlow.visible = false;
        cardGlow.blend = NORMAL;
        cardLayer.add(cardGlow);
    }

    function makeConfirmText(x:Float, y:Float, name:String, prefix:String, glow:Bool):FunkinSprite
    {
        var spr = new FunkinSprite(x, y, 'menus/freeplay/characters/bf/backingText');
        spr.addAnim(name, {prefix: prefix});
        spr.playAnim(name, {force: true});
        spr.visible = false;

        if (glow)
        {
            spr.blend = ADD;
            spr.shader = new GaussianBlurShader(2);

            if (spr.atlasSpr != null)
                spr.atlasSpr.useRenderTexture = true;
        }

        cardLayer.add(spr);
        return spr;
    }

    function setConfirmText(spr:FunkinSprite, x:Float, y:Float, sx:Float, sy:Float):Void
    {
        if (spr == null) return;

        spr.x = x;
        spr.y = y;
        spr.scale.set(sx, sy);
    }

    function playConfirmTextAnim():Void
    {
        var data =
        [
            {sharp: bigShoesText, blur: bigShoesTextBlurred, rx: -3.0, ry: 140.0, dx: -238.5, dy: 16.0, sx: 1.210, sy: 0.457, o8: 4.8},
            {sharp: yeahText, blur: yeahTextBlurred, rx: -3.0, ry: 195.0, dx: 240.0, dy: 44.8, sx: 1.268, sy: 0.280, o8: -8.0},
            {sharp: yesYesYesText, blur: yesYesYesTextBlurred, rx: -3.0, ry: 310.0, dx: -313.6, dy: 25.6, sx: 1.194, sy: 0.377, o8: 6.4},
            {sharp: getItText, blur: getItTextBlurred, rx: -3.0, ry: 380.0, dx: 14.8, dy: 49.6, sx: 1.361, sy: 0.180, o8: -6.4}
        ];

        for (t in data)
        {
            if (t.sharp != null)
            {
                t.sharp.visible = true;
                setConfirmText(t.sharp, t.rx + t.dx, t.ry + t.dy, t.sx, t.sy);
            }

            if (t.blur != null)
            {
                t.blur.visible = true;
                t.blur.alpha = 0.6;
                setConfirmText(t.blur, t.rx + t.dx, t.ry + t.dy, t.sx, t.sy);
            }
        }

        FlxTimer.wait(1 / 24, () ->
        {
            for (t in data)
            {
                setConfirmText(t.sharp, t.rx + t.o8, t.ry, 1, 1);
                setConfirmText(t.blur, t.rx - t.o8, t.ry, 1, 1);
            }
        });

        FlxTimer.wait(3 / 24, () ->
        {
            for (t in data)
            {
                setConfirmText(t.sharp, t.rx, t.ry, 1, 1);
                setConfirmText(t.blur, t.rx, t.ry, 1, 1);
            }
        });
    }

    function makeBand(y:Float, text:String, width:Float, bold:Bool, size:Int, color:Int, speed:Float):Void
    {
        var band = new BGScrollingText(0, y, text, width, bold, size);
        band.color = color;
        band.speed = speed;
        band.visible = false;

        cardLayer.add(band);
        bands.push(band);
    }

    function revealBackingCard():Void
    {
        revealed = true;

        if (orangeBox != null) orangeBox.visible = true;
        if (orangeAccent != null) orangeAccent.visible = true;

        for (i in 0...bands.length)
        {
            if (bands[i] != null)
            {
                bands[i].visible = true;
                bands[i].alpha = 0;
                FlxTween.tween(bands[i], {alpha: 1}, 0.5, {ease: FlxEase.quartOut});
            }
        }

        if (cardGlow != null)
        {
            cardGlow.visible = true;
            FlxTween.tween(cardGlow, {alpha: 0}, 0.5, {ease: FlxEase.quartOut});
        }
    }

    function selectBackingCard(?song:FreeplaySongData):Void
    {
        for (band in bands)
            band.visible = false;

        if (orangeBox != null) orangeBox.visible = false;
        if (orangeAccent != null) orangeAccent.visible = false;

        card.color = 0xFFFFD0D5;
        FlxTween.color(card, 0.33, 0xFFFFD0D5, 0xFF171831, {ease: FlxEase.quadOut});

        if (confirmGlow != null)
        {
            confirmGlow.visible = true;
            confirmGlow.alpha = 0;
        }

        if (confirmGlow2 != null)
        {
            confirmGlow2.visible = true;
            confirmGlow2.alpha = 0;
        }

        if (backingImage != null)
        {
            FlxTween.color(backingImage, 0.5, backingImage.color, 0xFF646464,
            {
                onUpdate: (_) -> { angleMaskShader.extraColor = backingImage.color; }
            });
        }

        if (confirmGlow2 != null)
        {
            FlxTween.tween(confirmGlow2, {alpha: 0.5}, 0.33,
            {
                ease: FlxEase.quadOut,
                onComplete: (_) ->
                {
                    confirmGlow2.alpha = 0.6;

                    if (confirmGlow != null)
                    {
                        confirmGlow.alpha = 1;
                        FlxTween.tween(confirmGlow, {alpha: 0}, 0.5);
                    }

                    playConfirmTextAnim();

                    if (backingImage != null)
                    {
                        FlxTween.color(backingImage, 2, backingImage.color, 0xFF555555,
                        {
                            ease: FlxEase.expoOut,
                            onUpdate: (_) -> { angleMaskShader.extraColor = backingImage.color; }
                        });
                    }
                }
            });
        }
    }

    function exitBackingCard():Void
    {
        for (band in bands)
            band.visible = false;

        if (orangeBox != null) orangeBox.visible = false;
        if (orangeAccent != null) orangeAccent.visible = false;

        if (cardGlow != null)
        {
            cardGlow.alpha = 1;
            FlxTween.tween(cardGlow, {alpha: 0}, 0.5, {ease: FlxEase.quartOut});
        }

        card.color = 0xFFFFD4E9;
    }

    function destroyBackingCard():Void
    {
        for (i in 0...bands.length)
        {
            if (bands[i] != null)
                FlxTween.cancelTweensOf(bands[i]);
        }

        if (cardGlow != null) FlxTween.cancelTweensOf(cardGlow);
        if (confirmGlow != null) FlxTween.cancelTweensOf(confirmGlow);
        if (confirmGlow2 != null) FlxTween.cancelTweensOf(confirmGlow2);

        for (txt in [yeahText, bigShoesText, yesYesYesText, getItText, yeahTextBlurred, bigShoesTextBlurred, yesYesYesTextBlurred, getItTextBlurred])
        {
            if (txt != null)
                FlxTween.cancelTweensOf(txt);
        }

        if (backingImage != null)
            FlxTween.cancelTweensOf(backingImage);

        bands = [];
        cardGlow = null;
        orangeBox = null;
        orangeAccent = null;
        confirmGlow = null;
        confirmGlow2 = null;

        yeahText = null;
        bigShoesText = null;
        yesYesYesText = null;
        getItText = null;
        yeahTextBlurred = null;
        bigShoesTextBlurred = null;
        yesYesYesTextBlurred = null;
        getItTextBlurred = null;
    }

    override function update(elapsed:Float):Void
    {
        if (!busy)
        {
            if (controls.UI_UP.justPressed) changeSelection(-1);
            if (controls.UI_DOWN.justPressed) changeSelection(1);

            if (controls.UI_LEFT.justPressed) changeDifficulty(-1);
            if (controls.UI_RIGHT.justPressed) changeDifficulty(1);

            if (FlxG.mouse.wheel != 0)
                changeSelection(FlxG.mouse.wheel > 0 ? -1 : 1);

            if (FlxG.keys.justPressed.Q) letterSort.changeSelection(-1);
            if (FlxG.keys.justPressed.E) letterSort.changeSelection(1);

            if (FlxG.keys.justPressed.F) favoriteSong();

            if (FlxG.keys.justPressed.TAB) changeCharacter(1);

            if (controls.ACCEPT.justPressed) confirmSelection();

            if (controls.BACK.justPressed)
                exitMenu();
        }

        if (canEnter && shouldEnter && !entering)
        {
            entering = true;

            PlayState.comingFromFreeplay = true;
            TransitionLoader.skipTransIn = true;
            TransitionLoader.skipTransOut = true;

            FunkinSound.stopAllAudio(true, false);

            var solid = new FunkinSprite().makeGraphic(camOverlay.width, camOverlay.height, 0xFF000000);
            solid.camera = camOverlay;
            solid.alpha = 0;
            add(solid);

            FlxTween.tween(solid, {alpha: 1}, 0.3, {ease: FlxEase.sineIn, onComplete: (_) ->
            {
                Manager.switchState(new PlayState({song: pendingSong, difficulty: curDifficulty, variation: pendingVariation}));
            }});
        }

        if (menuSong != null && menuSong.playing)
            conductor.update(menuSong.time);

        hintTimer += elapsed * 2;

        var targetAmt:Float = (Math.sin(hintTimer) + 1) / 2;
        charSelectHint.alpha = FlxMath.lerp(0.3, 0.9, targetAmt);

        lerpScoreDisplay(elapsed);

        if (currentCard != null && currentCard.active)
            currentCard.onUpdate(this, elapsed);

        super.update(elapsed);
    }

    override function beatHit(beat:Int):Void
    {
        if (bopper != null && beat % 2 == 0 && !busy)
            bopper.playAnim("idle", {force: true});

        if (currentCard != null && currentCard.active)
            currentCard.onBeatHit(this, beat);

        super.beatHit(beat);
    }

    function begin():Void
    {
        busy = false;

        if (parent != null)
            parent.persistentDraw = false;

        backingImage.visible = true;

        FlxTween.color(backingImage, 0.6, 0xFF000000, 0xFFFFFFFF,
        {
            ease: FlxEase.expoOut,
            onUpdate: (_) -> angleMaskShader.extraColor = backingImage.color,
            onComplete: (_) -> blackOverlay.visible = false
        });

        menuName.visible = true;
        FlxTimer.wait(1.5 / 24, () -> menuName.shader = null);

        ostName.visible = true;
        FlxTimer.wait(1.5 / 24, () -> ostName.shader = null);

        card.color = 0xFFFFD863;

        bopper.playAnim("idle", {force: true});

        introFinished = true;

        revealBackingCard();

        revealHighscorePanel();
        revealAlbumRoll();

        if (currentCard != null)
            currentCard.onIntroDone(this);

        if (menuSong != null)
            menuSong.play();
    }

    function revealHighscorePanel():Void
    {
        if (highscoreSpr != null) highscoreSpr.visible = true;

        if (scoreDisplay != null)
        {
            scoreDisplay.visible = true;
            scoreDisplay.updateScore(0);
        }

        if (clearBox != null) clearBox.visible = true;
        if (clearPercentCounter != null) clearPercentCounter.visible = true;

        lerpScore = 0;
        lerpCompletion = 0;

        updateScoreDisplay();
    }

    function revealAlbumRoll():Void
    {
        if (albumRoll == null) return;

        var item = capsules[curSelected];
        albumRoll.albumId = (item != null && item.freeplayData != null) ? item.freeplayData.albumId : null;

        albumRoll.setDifficultyStars(ratingFor(item));
        albumRoll.playIntro();
    }

    function exitMenu():Void
    {
        if (busy) return;
        busy = true;

        if (parent != null)
            parent.persistentDraw = true;

        FunkinSound.playOnce(Paths.sound('engine/cancel'));

        FlxTween.tween(card, {x: -card.width}, 0.4, {ease: FlxEase.expoIn});
        FlxTween.tween(backingImage, {x: FlxG.width * 1.5}, 0.4, {ease: FlxEase.expoIn});
        FlxTween.tween(blackOverlay, {x: FlxG.width * 1.5}, 0.4, {ease: FlxEase.expoIn});
        FlxTween.tween(bopper, {x: -FlxG.width * 1.6}, 0.5, {ease: FlxEase.expoIn});

        FlxTween.tween(topBar, {y: -topBar.height}, 0.3, {ease: FlxEase.quartIn});
        FlxTween.tween(ostName, {y: -topBar.height}, 0.3, {ease: FlxEase.quartIn});
        FlxTween.tween(menuName, {y: -topBar.height}, 0.3, {ease: FlxEase.quartIn});
        FlxTween.tween(charSelectHint, {y: -topBar.height}, 0.3, {ease: FlxEase.quartIn});

        FlxTween.tween(letterSort, {y: -topBar.height}, 0.3, {ease: FlxEase.quartIn});
        FlxTween.tween(difficultySelector, {x: difficultySelector.x - 400}, 0.4, {ease: FlxEase.expoIn});

        if (highscoreSpr != null) FlxTween.tween(highscoreSpr, {x: FlxG.width}, 0.4, {ease: FlxEase.expoIn});
        if (scoreDisplay != null) FlxTween.tween(scoreDisplay, {x: FlxG.width}, 0.4, {ease: FlxEase.expoIn});
        if (clearBox != null) FlxTween.tween(clearBox, {x: FlxG.width}, 0.4, {ease: FlxEase.expoIn});
        if (clearPercentCounter != null) FlxTween.tween(clearPercentCounter, {x: FlxG.width * 1.05}, 0.42, {ease: FlxEase.expoIn});

        if (albumRoll != null) FlxTween.tween(albumRoll, {x: FlxG.width}, 0.4, {ease: FlxEase.expoIn});

        for (i in 0...capsules.length)
        {
            var capsule = capsules[i];
            capsule.doJumpIn = false;
            capsule.doLerp = false;
            capsule.doJumpOut = true;
        }

        exitBackingCard();

        if (currentCard != null)
            currentCard.onExit(this);

        FlxTimer.wait(0.5, () ->
        {
            FunkinSound.stopAllAudio(true);
            close();
        });
    }

    function loadAllSongs():Void
    {
        allSongs = [];
        availableCharacters = [];

        variations = [""];
        for (v in DifficultyRegistry.characterVariations())
            variations.push("-" + v);

        for (folder in Paths.readDirectory('data/songs'))
        {
            if (!Paths.isDirectory('data/songs/' + folder))
                continue;

            var meta = MetaRegistry.get(folder);

            if (meta.freeplay.hide)
                continue;

            allSongs.push(
            {
                id: folder,
                name: meta.name,
                bpm: Std.int(meta.bpm),
                difficultyRating: MetaRegistry.getRating(folder, curDifficulty),
                icon: meta.icon,
                difficulties: [],
                variation: "",
                newlyAdded: meta.freeplay.newlyAdded,
                albumId: meta.album.name
            });

            registerSongPlayers(folder);
        }

        if (availableCharacters.indexOf(CURRENT_CHARACTER) == -1 && availableCharacters.length > 0)
            CURRENT_CHARACTER = availableCharacters[0];
    }

    function songDifficulties(songId:String, variation:String):Array<String>
    {
        var key = songId + "|" + variation;
        var cached = diffCache.get(key);

        if (cached != null) return cached;

        cached = ChartRegistry.listDifficulties(songId, variation);
        diffCache.set(key, cached);

        return cached;
    }

    function registerSongPlayers(songId:String):Void
    {
        for (variation in variations)
        {
            for (difficulty in songDifficulties(songId, variation))
                registerCharacter(PlayerRegistry.playerForCharacter(songPlayerCharacter(songId, difficulty, variation)));
        }
    }

    function registerCharacter(c:Null<String>):Void
    {
        if (c != null && c != "" && availableCharacters.indexOf(c) == -1)
            availableCharacters.push(c);
    }

    function songPlayerCharacter(songId:String, difficulty:String, variation:String):Null<String>
    {
        var chart = ChartRegistry.get(songId, difficulty, variation);

        if (chart == null || chart.strumlines == null)
            return null;

        for (strum in chart.strumlines)
        {
            if (strum != null && strum.id == 1)
                return strum.character;
        }

        return null;
    }

    function resolveVariation(songId:String, player:String, difficulty:String):Null<String>
    {
        for (variation in variations)
        {
            if (songDifficulties(songId, variation).indexOf(difficulty) == -1)
                continue;

            if (PlayerRegistry.owns(player, songPlayerCharacter(songId, difficulty, variation)))
                return variation;
        }

        return null;
    }

    function changeCharacter(change:Int):Void
    {
        if (availableCharacters.length <= 1) return;

        var idx = availableCharacters.indexOf(CURRENT_CHARACTER);
        if (idx == -1) idx = 0;

        idx = (idx + change) % availableCharacters.length;
        if (idx < 0) idx += availableCharacters.length;

        deactivateCard();

        CURRENT_CHARACTER = availableCharacters[idx];

        FunkinSound.playOnce(Paths.sound('engine/scroll'), 0.4);

        rebuildSongList();
        updateDots();

        activateCard();
    }

    function filterSongs():Array<FreeplaySongData>
    {
        var filter = curFilter;
        var out:Array<FreeplaySongData> = [];

        for (i in 0...allSongs.length)
        {
            var s = allSongs[i];

            var variation = resolveVariation(s.id, CURRENT_CHARACTER, curDifficulty);
            if (variation == null)
                continue;

            var diffs = songDifficulties(s.id, variation);
            if (diffs.indexOf(curDifficulty) == -1)
                continue;

            s.variation = variation;
            s.difficulties = diffs;
            s.difficultyRating = MetaRegistry.getRating(s.id, curDifficulty, variation);

            if (filter == "ALL")
            {
                out.push(s);
                continue;
            }

            if (filter == "fav")
            {
                if (isFavorite(s.id))
                    out.push(s);

                continue;
            }

            var first = s.name.charAt(0).toUpperCase();

            if (filter == "#")
            {
                if (first >= "0" && first <= "9") out.push(s);
                continue;
            }

            var lo = filter.charAt(0);
            var hi = (filter.length >= 3) ? filter.charAt(2) : lo;

            if (first >= lo && first <= hi) out.push(s);
        }

        return out;
    }

    function rebuildSongList():Void
    {
        for (i in 0...capsules.length)
        {
            if (capsules[i] != null)
            {
                FlxTween.cancelTweensOf(capsules[i]);
                remove(capsules[i], true);
                capsules[i].destroy();
            }
        }

        capsules = [];
        songs = filterSongs();

        var randomCapsule = new SongMenuItem(0, 0, CURRENT_CHARACTER);
        randomCapsule.camera = camCapsules;
        randomCapsule.initPosition(FlxG.width, 0);
        randomCapsule.initData(null, 1);
        randomCapsule.y = randomCapsule.intendedY(0) + 10;
        randomCapsule.targetPos.x = randomCapsule.x;
        randomCapsule.ID = -1;
        randomCapsule.initJumpIn(0, true);
        add(randomCapsule);
        capsules.push(randomCapsule);

        for (i in 0...songs.length)
        {
            var song = songs[i];
            var pos = i + 1;

            var item = new SongMenuItem(0, 0, CURRENT_CHARACTER);
            item.camera = camCapsules;

            item.initPosition(FlxG.width, 0);
            item.initData(song, pos + 1);
            item.setFavorite(isFavorite(song.id));
            item.staggerNew(i);

            item.y = item.intendedY(pos) + 10;
            item.targetPos.x = item.x;
            item.ID = i;

            item.initJumpIn(0, true);

            add(item);
            capsules.push(item);
        }

        curSelected = (songs.length > 0) ? 1 : 0;

        changeSelection(0);
    }

    function buildLetterSort():Void
    {
        letterSort = new LetterSort(410, 80);
        letterSort.camera = camUI;

        letterSort.changeSelectionCallback = (str) ->
        {
            curFilter = str;
            rebuildSongList();
        };

        add(letterSort);
    }

    function buildDifficultySelector():Void
    {
        difficultySelector = new DifficultySelector(20, 70, FreeplayRegistry.data.difficulties, CURRENT_CHARACTER, curDifficulty);
        difficultySelector.camera = camUI;
        add(difficultySelector);
    }

    function buildHighscorePanel():Void
    {
        highscoreSpr = new FunkinSprite(FlxG.width - 420, 70, 'menus/freeplay/highscore');
        highscoreSpr.addAnim('highscore', {prefix: 'highscore small instance 1', fps: 24});
        highscoreSpr.camera = camUI;
        highscoreSpr.visible = false;
        add(highscoreSpr);

        scheduleHighscoreFlicker(FlxG.random.float(12, 50));

        scoreDisplay = new FreeplayScore(FlxG.width - 353, 60, 7, 100);
        scoreDisplay.camera = camUI;
        scoreDisplay.visible = false;
        add(scoreDisplay);

        clearBox = new FunkinSprite(FlxG.width - 115, 65, 'menus/freeplay/clearBox');
        clearBox.camera = camUI;
        clearBox.visible = false;
        add(clearBox);

        clearPercentCounter = new ClearPercentCounter(FlxG.width - 95, 87, 0);
        clearPercentCounter.camera = camUI;
        clearPercentCounter.visible = false;
        add(clearPercentCounter);
    }

    function buildAlbumRoll():Void
    {
        albumRoll = new AlbumRoll();
        albumRoll.camera = camUI;
        add(albumRoll);
    }

    function ratingFor(item:SongMenuItem):Int
    {
        return (item != null && item.freeplayData != null) ? item.freeplayData.difficultyRating : 0;
    }

    function updateAlbumRoll():Void
    {
        if (albumRoll == null) return;

        var item = capsules[curSelected];

        if (introFinished)
        {
            var newAlbumId = (item != null && item.freeplayData != null) ? item.freeplayData.albumId : null;

            if (albumRoll.albumId != newAlbumId)
            {
                albumRoll.albumId = newAlbumId;
                albumRoll.skipIntro();
            }
        }

        albumRoll.setDifficultyStars(ratingFor(item));
    }

    function scheduleHighscoreFlicker(delay:Float):Void
    {
        FlxTimer.wait(delay, function()
        {
            if (highscoreFlickerActive)
            {
                if (highscoreSpr != null)
                    highscoreSpr.playAnim('highscore', {force: true});

                scheduleHighscoreFlicker(FlxG.random.float(20, 60));
            }
        });
    }

    function updateScoreDisplay():Void
    {
        var item = capsules[curSelected];

        if (item != null && item.freeplayData != null)
        {
            var song = item.freeplayData;
            var variation = (song.variation != null) ? song.variation : "";

            intendedScore = Highscore.getScoreValue(song.id, curDifficulty, variation);
            intendedCompletion = Highscore.getClearPercent(song.id, curDifficulty, variation);
        }
        else
        {
            intendedScore = 0;
            intendedCompletion = 0;
        }
    }

    function lerpScoreDisplay(elapsed:Float):Void
    {
        if (scoreDisplay == null) return;

        lerpScore = MathUtil.smoothLerpPrecision(lerpScore, intendedScore, elapsed, 0.2, 1 / 100);
        if (Math.isNaN(lerpScore) || Math.abs(lerpScore - intendedScore) < 1) lerpScore = intendedScore;

        lerpCompletion = MathUtil.smoothLerpPrecision(lerpCompletion, intendedCompletion, elapsed, 0.5, 1 / 100);
        if (Math.isNaN(lerpCompletion) || Math.abs(lerpCompletion - intendedCompletion) < 0.01) lerpCompletion = intendedCompletion;

        scoreDisplay.updateScore(Std.int(lerpScore));

        if (clearPercentCounter != null)
        {
            var pct = Math.floor(lerpCompletion * 100);

            if (pct < 0) pct = 0;
            if (pct > 100) pct = 100;

            clearPercentCounter.curNumber = pct;
        }
    }

    function changeDifficulty(change:Int):Void
    {
        difficultySelector.change(change);
        curDifficulty = difficultySelector.currentDifficulty;

        var item = capsules[curSelected];
        var keepId = (item != null && item.freeplayData != null) ? item.freeplayData.id : null;
        var prevSelected = curSelected;

        if (songListIds(filterSongs()) == songListIds(songs))
        {
            refreshCapsuleRatings();

            updateDots();
            updateScoreDisplay();
            updateAlbumRoll();

            if (currentCard != null)
                currentCard.onDifficultyChange(this, curDifficulty);

            return;
        }

        rebuildSongList();

        var found = false;

        if (keepId != null)
        {
            for (i in 0...songs.length)
            {
                if (songs[i].id == keepId)
                {
                    curSelected = i + 1;
                    found = true;
                    break;
                }
            }
        }

        if (!found)
            curSelected = Std.int(Math.min(prevSelected, capsules.length - 1));

        if (currentCard != null)
            currentCard.onDifficultyChange(this, curDifficulty);

        changeSelection(0);
    }

    function refreshCapsuleRatings():Void
    {
        for (i in 0...capsules.length)
        {
            if (capsules[i] != null)
                capsules[i].refreshRating();
        }
    }

    function songListIds(list:Array<FreeplaySongData>):String
    {
        var ids = "";

        for (i in 0...list.length)
            ids += list[i].id + "|";

        return ids;
    }

    function updateDots():Void
    {
        if (difficultySelector == null || capsules.length <= 0) return;

        var item = capsules[curSelected];
        difficultySelector.refreshDots((item != null && item.freeplayData != null) ? item.freeplayData.difficulties : null);
    }

    function favoriteSong():Void
    {
        if (capsules.length <= 0) return;

        var item = capsules[curSelected];
        if (item == null || item.freeplayData == null) return;

        var song = item.freeplayData;
        var nowFav = item.toggleFavorite();

        setFavorite(song.id, nowFav);

        FunkinSound.playOnce(Paths.sound(nowFav ? 'menus/freeplay/fav' : 'menus/freeplay/unfav'), 0.8);

        item.doLerp = false;

        FlxTween.tween(item, {y: item.y - 5}, 0.1, {ease: FlxEase.expoOut});
        FlxTween.tween(item, {y: item.y + 5}, 0.1, {ease: FlxEase.expoIn, startDelay: 0.1, onComplete: (_) -> item.doLerp = true});

        if (currentCard != null)
            currentCard.onSongFavorite(this, song);
    }

    function changeSelection(change:Int):Void
    {
        if (capsules.length <= 0) return;

        var prevSelected = curSelected;

        curSelected += change;

        if (curSelected < 0)
            curSelected = capsules.length - 1;
        else if (curSelected >= capsules.length)
            curSelected = 0;

        if (curSelected != prevSelected)
            FunkinSound.playOnce(Paths.sound('engine/scroll'), 0.4);

        for (i in 0...capsules.length)
        {
            var capsule = capsules[i];
            var index = i + 1;

            capsule.forceHighlight = false;
            capsule.selected = index == curSelected + 1;

            capsule.curSelected = curSelected;

            var capsuleIndex = index - curSelected;
            var yOffset = 0.0;

            if (capsuleIndex < 0)
                yOffset += 50;
            else if (capsuleIndex > 4)
                yOffset -= 10;

            capsule.targetPos.y = capsule.intendedY(capsuleIndex) - yOffset;
            capsule.targetPos.x = capsule.intendedX(capsuleIndex);

            if (index < curSelected)
                capsule.targetPos.y -= 100;
        }

        if (currentCard != null)
            currentCard.onSelectionChange(this, curSelected);

        updateDots();
        updateScoreDisplay();
        updateAlbumRoll();
    }

    function confirmSelection():Void
    {
        if (busy || capsules.length <= 0) return;

        var item = capsules[curSelected];
        if (item == null) return;

        if (item.freeplayData == null)
        {
            var pool:Array<Int> = [];

            for (i in 0...capsules.length)
                if (capsules[i].freeplayData != null) pool.push(i);

            if (pool.length == 0)
            {
                FunkinSound.playOnce(Paths.sound('engine/cancel'));
                return;
            }

            curSelected = pool[FlxG.random.int(0, pool.length - 1)];
            changeSelection(0);

            item = capsules[curSelected];
        }

        busy = true;

        var song = item.freeplayData;

        if (menuSong != null)
            menuSong.stop();

        bopper.playAnim("confirm", {force: true});

        FunkinSound.playOnce(Paths.sound('engine/confirm'));
        item.confirm();

        selectBackingCard(song);

        if (currentCard != null)
            currentCard.onSelect(this, song);

        FlxTimer.wait(1, () -> shouldEnter = true);

        pendingSong = song.id;
        pendingVariation = (song.variation != null) ? song.variation : "";
        Preloader.start(song.id, curDifficulty, pendingVariation, () -> canEnter = true);
    }

    function isFavorite(id:String):Bool
    {
        return Configs.FAVORITE_SONGS.indexOf(id) != -1;
    }

    function setFavorite(id:String, fav:Bool):Void
    {
        if (fav)
        {
            if (Configs.FAVORITE_SONGS.indexOf(id) == -1)
                Configs.FAVORITE_SONGS.push(id);
        }
        else
            Configs.FAVORITE_SONGS.remove(id);

        Configs.save();
    }

    override function destroy():Void
    {
        highscoreFlickerActive = false;

        deactivateCard();
        BackingCardHandler.clear();

        if (camCapsules != null)
        {
            FlxG.cameras.remove(camCapsules);
            camCapsules = null;
        }

        if (camUI != null)
        {
            FlxG.cameras.remove(camUI);
            camUI = null;
        }

        if (camOverlay != null)
        {
            FlxG.cameras.remove(camOverlay);
            camOverlay = null;
        }

        super.destroy();
    }
}
