package menus;

import flixel.group.FlxSpriteGroup;
import flixel.util.FlxAxes;

import backend.MusicBeatState;
import backend.registries.menus.TitleMenuRegistry;
import backend.utils.MathUtil;
import backend.transition.TransitionLoader;

class TitleState extends MusicBeatState
{
    static var skippedIntro:Bool = false;
    var confirmed:Bool = false;

    var canSkip:Bool = false;
    var hasSkipped:Bool = false;

    var introGroup:FlxSpriteGroup;
    var mainGroup:FlxSpriteGroup;

    var randomIntro:Array<String> = [];
    var eventsByBeat:Map<Int, TitleMenuEventData> = new Map<Int, TitleMenuEventData>();

    var gfTitle:FunkinSprite;
    var logo:FunkinSprite;
    var button:FunkinSprite;
    var flashSprite:FunkinSprite;

    var gfDances:Bool = false;
    var buttonIdleLooped:Bool = false;

    override public function create()
    {
        if (FlxG.sound.music == null || !FlxG.sound.music.playing)
        {
            if (FunkinSound.playMusic(ConfigRegistry.data.song.path, {startingVolume: 0, persist: true}))
            {
                FlxG.sound.music.fadeIn(1, 0, 1);
            }
        }

        conductor.reset();
        conductor.setBPM(ConfigRegistry.data.song.bpm);

        var allIntroTexts = TitleMenuRegistry.data.intro.introText;

        if (allIntroTexts != null && allIntroTexts.length > 0)
            randomIntro = allIntroTexts[FlxG.random.int(0, allIntroTexts.length - 1)];

        for (event in TitleMenuRegistry.data.intro.events)
        {
            if (!eventsByBeat.exists(event.beat))
                eventsByBeat.set(event.beat, event);
        }

        introGroup = new FlxSpriteGroup();
        add(introGroup);

        mainGroup = new FlxSpriteGroup();
        mainGroup.visible = false;
        add(mainGroup);

        gfTitle = createMenuSprite(TitleMenuRegistry.data.bopper);
        mainGroup.add(gfTitle);

        logo = createMenuSprite(TitleMenuRegistry.data.logo);
        logo.playAnim("bump", {force: true});
        mainGroup.add(logo);

        button = createMenuSprite(TitleMenuRegistry.data.button);
        mainGroup.add(button);

        gfDances = gfTitle.hasAnim("danceLeft") && gfTitle.hasAnim("danceRight");

        for (anim in TitleMenuRegistry.data.button.animations)
        {
            if (anim.name == "idle" && anim.looped)
            {
                buttonIdleLooped = true;
                break;
            }
        }

        button.playAnim("idle", {force: true});
        gfTitle.playAnim("danceRight", {force: true});

        flashSprite = new FunkinSprite().makeGraphic(1, 1, 0xFFFFFFFF);
        flashSprite.setGraphicSize(flashSprite.camera.width, flashSprite.camera.height);
        flashSprite.updateHitbox();
        flashSprite.alpha = 0;
        add(flashSprite);
        
        if (TitleMenuRegistry.data.intro.skip || skippedIntro)
            skipIntro(false);
        else
            FlxG.sound.music.time = 0;

        super.create();
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        conductor.update(FlxG.sound.music.time);

        if (controls.ACCEPT.justPressed)
        {
            if (skippedIntro)
            {
                if (!canSkip)
                    confirm();
                else if (canSkip && !hasSkipped)
                {
                    TransitionLoader.skipTransOut = true;
                    
                    hasSkipped = true;
                    Manager.switchState(new MainMenuState());
                }
            }
            else
                skipIntro();
        }
    }

    override public function hotReload()
    {
        TitleMenuRegistry.load(true);
        super.hotReload();
    }

    override public function beatHit(beat:Float)
    {
        super.beatHit(beat);

        if (gfTitle.visible)
        {
            if (gfDances)
                gfTitle.playAnim(beat % 2 == 0 ? "danceLeft" : "danceRight", {force: true});
            else
                gfTitle.playAnim("idle", {force: true});
        }

        if (logo.visible)
            logo.playAnim("bump", {force: true});

        if (button.visible && !buttonIdleLooped)
            button.playAnim("idle", {force: true});

        if (!skippedIntro)
        {
            var event = eventsByBeat.get(Std.int(beat));

            if (event != null)
                executeEvent(event.action, event.text);
        }
    }

    function executeEvent(action:Array<String>, text:String):Void
    {
        if (action.contains("skipIntro"))
        {
            skipIntro();
            return;
        }

        if (action.contains("deleteText"))
            clearGroup();

        if (text != "")
            addText(text);

        if (action.contains("showNGLogo"))
            addNGLogo();

        introGroup.screenCenter(FlxAxes.Y);
    }

    function addText(text:String):Void
    {
        if (text.startsWith("introText[") && text.endsWith("]"))
        {
            var index:Null<Int> = Std.parseInt(text.substring(10, text.length - 1));
            text = (index != null && index >= 0 && index < randomIntro.length) ? randomIntro[index] : "";
        }

        if (text == "")
            return;

        for (line in text.split("\n"))
        {
            var aText:AtlasText = new AtlasText(0, 0, line, BOLD);
            aText.y = introGroup.length * aText.maxHeight;
            aText.screenCenter(FlxAxes.X);
            introGroup.add(aText);
        }
    }

    function addNGLogo():Void
    {
        var ngLogo:FunkinSprite = new FunkinSprite(0, 0, 'menus/title/ngAnimated', {frameWidth: 600, frameHeight: 591});
        ngLogo.addAnim("loop", {indices: [0, 1], fps: 4, looped: true});
        ngLogo.playAnim("loop", {force: true});
        ngLogo.scale.set(0.5, 0.5);
        ngLogo.updateHitbox();
        ngLogo.screenCenter(FlxAxes.X);
        ngLogo.y += introGroup.length * 75;
        introGroup.add(ngLogo);
    }

    function clearGroup():Void
    {
        for (member in introGroup.members)
        {
            if (member != null)
                member.destroy();
        }

        introGroup.clear();
    }

    function skipIntro(?shouldFlash:Bool = true):Void
    {
        skippedIntro = true;

        mainGroup.visible = true;
        introGroup.visible = false;

        if (shouldFlash)
            flash(1.75);

        clearGroup();

        if (FlxG.sound.music.time < ConfigRegistry.data.song.skipTimestamp)
            FlxG.sound.music.time = ConfigRegistry.data.song.skipTimestamp;
    }

    function confirm():Void
    {
        if (confirmed)
            return;

        confirmed = true;
        canSkip = true;

        flash(0.7);

        FunkinSound.playOnce(Paths.sound('engine/confirm'));
        button.playAnim("confirm", {force: true});

        FlxTimer.wait(0.75, () ->
        {
            if (!hasSkipped)
                Manager.switchState(new MainMenuState());
        });
    }

    function flash(time:Float = 1.0):Void
    {
        FlxTween.cancelTweensOf(flashSprite);

        flashSprite.alpha = 1;
        FlxTween.tween(flashSprite, {alpha: 0.0}, time, {ease: FlxEase.sineOut});
    }

    function createMenuSprite(data:TitleMenuObjectData):FunkinSprite
    {
        var sprite:FunkinSprite = new FunkinSprite(0, 0, data.path);

        sprite.screenCenter();
        sprite.x += data.position[0];
        sprite.y += data.position[1];

        sprite.scale.set(data.scale[0], data.scale[1]);
        sprite.updateHitbox();

        sprite.alpha = data.alpha;
        sprite.angle = data.angle;
        sprite.visible = data.visible;

        for (anim in data.animations)
            sprite.addAnim(anim.name, {prefix: anim.prefix, indices: anim.indices, offsets: anim.offsets, looped: anim.looped, fps: anim.fps});

        return sprite;
    }
}
