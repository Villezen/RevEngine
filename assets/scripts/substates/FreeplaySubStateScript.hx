import backend.registries.menus.FreeplayRegistry;
import menus.freeplay.SongMenuItem;
import menus.freeplay.LetterSort;
import menus.freeplay.DifficultySelector;
import backend.transition.TransitionLoader;
import flixel.text.FlxTextAlign;

class FreeplaySubStateScript extends MusicBeatSubState
{
    public static var CURRENT_CHARACTER:String = "bf";

    public var angleMaskShader:AngleMask = new AngleMask();

    var camCapsules:FlxCamera;
    var camUI:FlxCamera;
    var camOverlay:FlxCamera;

    var menuSong:FunkinSound;

    var card:FunkinSprite;
    var backingImage:FunkinSprite;
    var blackOverlay:FunkinSprite;
    var bopper:FunkinSprite;

    var capsules = [];
    var songs = [];

    var curSelected:Int = 0;

    var busy:Bool = true;
    var entering:Bool = false;

    var shouldEnter:Bool = false;
    var canEnter:Bool = false;

    var pendingSong:String = null;
    var pendingVariation:String = "";

    var hintTimer:Float = 0;

    var allSongs = [];
    var curFilter:String = "ALL";

    var availableCharacters = [];

    var letterSort:LetterSort;

    var curDifficulty:String = "normal";

    var difficultySelector:DifficultySelector;

    var cardLayer = null;
    var currentCard:BackingCard = null;
    var introFinished:Bool = false;

    override function create()
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

    function activateCard()
    {
        currentCard = BackingCardHandler.get(CURRENT_CHARACTER);

        if (currentCard == null) return;

        currentCard.onCreate(this);
        currentCard.onCardCreate(this);
        currentCard.onPostCreate(this);

        if (introFinished)
            currentCard.onIntroDone(this);
    }

    function deactivateCard()
    {
        if (currentCard != null)
        {
            currentCard.onDestroy(this);
            currentCard = null;
        }

        if (cardLayer != null)
            cardLayer.clear();
    }

    override function update(elapsed)
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

        if (currentCard != null && currentCard.active)
            currentCard.onUpdate(this, elapsed);

        super.update(elapsed);
    }

    override function beatHit(beat)
    {
        if (bopper != null && beat % 2 == 0 && !busy)
            bopper.playAnim("idle", {force: true});

        if (currentCard != null && currentCard.active)
            currentCard.onBeatHit(this, Std.int(beat));

        super.beatHit(beat);
    }

    function begin()
    {
        busy = false;

        if (parent != null)
            parent.persistentDraw = false;

        backingImage.color = 0xFF000000;
        angleMaskShader.extraColor = 0xFF000000;
        backingImage.visible = true;

        FlxTween.color(backingImage, 0.6, 0xFF000000, 0xFFFFFFFF, {
            ease: FlxEase.expoOut,
            onUpdate: (_) -> { angleMaskShader.extraColor = backingImage.color; },
            onComplete: (_) -> { blackOverlay.visible = false; }
        });

        menuName.visible = true;
        FlxTimer.wait(1.5 / 24, () -> menuName.shader = null);

        ostName.visible = true;
        FlxTimer.wait(1.5 / 24, () -> ostName.shader = null);

        card.color = 0xFFFFD863;

        bopper.playAnim("idle", {force: true});

        introFinished = true;

        if (currentCard != null)
            currentCard.onIntroDone(this);

        if (menuSong != null)
            menuSong.play();
    }

    function exitMenu()
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

        for (i in 0...capsules.length)
        {
            var capsule = capsules[i];
            capsule.doJumpIn = false;
            capsule.doLerp = false;
            capsule.doJumpOut = true;
        }

        FlxTimer.wait(0.5, () ->
        {
            FunkinSound.stopAllAudio(true);
            close();
        });
    }

    function loadAllSongs()
    {
        allSongs = [];
        availableCharacters = [];

        for (folder in Paths.readDirectory('data/songs'))
        {
            if (!Paths.isDirectory('data/songs/' + folder))
                continue;

            var meta = MetaRegistry.get(folder);

            if (meta.freeplay.hide)
                continue;

            allSongs.push({id: folder, name: meta.name, bpm: Std.int(meta.bpm), difficultyRating: meta.album.ratings, icon: meta.icon, difficulties: [], variation: "", newlyAdded: meta.freeplay.newlyAdded});
            registerCharacter(meta.player);

            for (v in DifficultyRegistry.characterVariations())
            {
                if (Paths.exists('data/songs/' + folder + '/' + folder + '-meta-' + v + '.json'))
                    registerCharacter(MetaRegistry.get(folder, '-' + v).player);
            }
        }

        if (availableCharacters.indexOf(CURRENT_CHARACTER) == -1 && availableCharacters.length > 0)
            CURRENT_CHARACTER = availableCharacters[0];
    }

    function registerCharacter(c)
    {
        if (c != null && c != "" && availableCharacters.indexOf(c) == -1)
            availableCharacters.push(c);
    }

    function resolveVariation(songId, character)
    {
        if (MetaRegistry.get(songId).player == character)
            return "";

        for (v in DifficultyRegistry.characterVariations())
        {
            var suffix = "-" + v;

            if (Paths.exists('data/songs/' + songId + '/' + songId + '-meta' + suffix + '.json')
                && MetaRegistry.get(songId, suffix).player == character)
                return suffix;
        }

        return null;
    }

    function changeCharacter(change)
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

    function filterSongs()
    {
        var filter = curFilter;
        var out = [];

        for (i in 0...allSongs.length)
        {
            var s = allSongs[i];

            var variation = resolveVariation(s.id, CURRENT_CHARACTER);
            if (variation == null)
                continue;

            var diffs = ChartRegistry.listDifficulties(s.id, variation);
            if (diffs.indexOf(curDifficulty) == -1)
                continue;

            s.variation = variation;
            s.difficulties = diffs;

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

    function rebuildSongList()
    {
        for (i in 0...capsules.length)
            remove(capsules[i]);

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

    function buildLetterSort()
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

    function buildDifficultySelector()
    {
        difficultySelector = new DifficultySelector(20, 70, FreeplayRegistry.data.difficulties, CURRENT_CHARACTER, curDifficulty);
        difficultySelector.camera = camUI;
        add(difficultySelector);
    }

    function changeDifficulty(change:Int)
    {
        difficultySelector.change(change);
        curDifficulty = difficultySelector.currentDifficulty;

        var item = capsules[curSelected];
        var keepId = (item != null && item.freeplayData != null) ? item.freeplayData.id : null;
        var prevSelected = curSelected;

        if (songListIds(filterSongs()) == songListIds(songs))
        {
            updateDots();
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

        changeSelection(0);
    }

    function songListIds(list:Array<Dynamic>):String
    {
        var ids = "";

        for (i in 0...list.length)
            ids += list[i].id + "|";

        return ids;
    }

    function updateDots()
    {
        if (difficultySelector == null || capsules.length <= 0) return;

        var item = capsules[curSelected];
        difficultySelector.refreshDots((item != null && item.freeplayData != null) ? item.freeplayData.difficulties : null);
    }

    function favoriteSong()
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
        FlxTween.tween(item, {y: item.y + 5}, 0.1,
        {
            ease: FlxEase.expoIn,
            startDelay: 0.1,
            onComplete: (_) -> item.doLerp = true
        });
    }

    function changeSelection(change:Int)
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

        updateDots();
    }

    function confirmSelection()
    {
        if (busy || capsules.length <= 0) return;

        var item = capsules[curSelected];
        if (item == null) return;

        if (item.freeplayData == null)
        {
            var pool = [];
            
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

        menuSong.stop();

        bopper.playAnim("confirm", {force: true});

        FunkinSound.playOnce(Paths.sound('engine/confirm'));
        item.confirm();

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

    override function destroy()
    {
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
