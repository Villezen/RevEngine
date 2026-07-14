package menus;

import backend.MusicBeatState;
import backend.utils.MathUtil;

import backend.registries.menus.MainMenuRegistry;
import backend.registries.menus.FreeplayRegistry;

import backend.registries.menus.MainMenuRegistry.MainMenuObjectData;

import backend.transition.TransitionLoader;

import flixel.FlxCamera;
import flixel.FlxSubState;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.util.FlxAxes;
import flixel.effects.FlxFlicker;

import flixel.text.FlxText;

import backend.utils.GitHubUtil;

import polymod.hscript._internal.PolymodScriptClass;

class MainMenuState extends MusicBeatState
{
    var hasSelected:Bool = false;
    var transitioning:Bool = false;

    var canSkip:Bool = false;
    var hasSkipped:Bool = false;

    var selectedOption:String = "";

    var curSelected:Int = 0;
    var camIndex:Int = 0;

    var camBG:FlxCamera;
    var camItems:FlxCamera;
    var camUI:FlxCamera;

    var bg:FunkinSprite;
    var bgFlicker:FunkinSprite;

    var menuItems:FlxTypedSpriteGroup<FunkinSprite>;

    var versionText:FlxText;

    override public function create():Void
    {
        checkSong();
        
        FlxG.camera.bgColor = FlxColor.TRANSPARENT;

        camBG = createCamera();
        camItems = createCamera();
        camUI = createCamera();

        bg = createBackground(MainMenuRegistry.data.background.normal, camBG);
        bg.visible = MainMenuRegistry.data.background.normal.visible;
        add(bg);

        bgFlicker = createBackground(MainMenuRegistry.data.background.flicker, camBG);
        bgFlicker.visible = false;
        add(bgFlicker);

        menuItems = new FlxTypedSpriteGroup<FunkinSprite>();
        menuItems.camera = camItems;
        add(menuItems);

        var i:Int = 0;
        for (optionEntry in MainMenuRegistry.data.options)
        {
            var spriteData = optionEntry.sprite;

            var item = new FunkinSprite(0, i * 150, spriteData.path);
            item.tag = optionEntry.name;
            item.visible = spriteData.visible;
            item.alpha = spriteData.alpha;
            item.angle = spriteData.angle;
            item.scale.set(spriteData.scale[0], spriteData.scale[1]);
            item.updateHitbox();
            item.scrollFactor.set();

            for (anim in spriteData.animations)
                item.addAnim(anim.name, {prefix: anim.prefix, indices: anim.indices, fps: anim.fps, looped: anim.looped, offsets: [Std.int(anim.offsets[0]), Std.int(anim.offsets[1])]});

            item.playAnim('idle');
            item.screenCenter(FlxAxes.X);

            item.x += spriteData.position[0];
            item.y += spriteData.position[1];

            item.ID = i;
            menuItems.add(item);

            i++;
        }

        menuItems.screenCenter(FlxAxes.Y);

        scroll(0, false);

        versionText = new FlxText(0, FlxG.height - 18, FlxG.width, 'v' + Constants.VERSION_STRING + " (API: v" + Constants.API_VERSION + ")", 12);
        versionText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        versionText.camera = camUI;
        add(versionText);

        super.create();
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (!hasSelected)
        {
            if (controls.UI_UP.justPressed || controls.UI_DOWN.justPressed)
                scroll(controls.UI_UP.justPressed ? -1 : 1);
            else if (FlxG.mouse.wheel != 0)
                scroll(FlxG.mouse.wheel > 0 ? -1 : 1);

            if (controls.BACK.justPressed)
                exit();
        }

        if (controls.ACCEPT.justPressed)
        {
            if (!canSkip && !hasSelected)
                select(curSelected);
            else if (canSkip && !hasSkipped && hasSelected)
            {
                TransitionLoader.skipTransOut = true;
                
                hasSkipped = true;
                switchToOption(selectedOption);
            }
        }

        camBG.scroll.y = MathUtil.smoothLerpPrecision(camBG.scroll.y, -50 + (150 * camIndex), elapsed, 0.6);
        camItems.scroll.y = MathUtil.smoothLerpPrecision(camItems.scroll.y, -50 + (150 * camIndex), elapsed, 0.6);
    }

    override public function hotReload():Void
    {
        MainMenuRegistry.load(true);
        FreeplayRegistry.load(true);

        super.hotReload();
    }

    override public function closeSubState():Void
    {
        super.closeSubState();

        checkSong();

        if (hasSelected && !transitioning)
            regenerate();
    }

    function createCamera():FlxCamera
    {
        var cam = new FlxCamera();
        cam.bgColor = 0x00000000;
        FlxG.cameras.insert(cam, FlxG.cameras.list.indexOf(FlxG.camera), false);

        return cam;
    }

    function createBackground(data:MainMenuObjectData, cam:FlxCamera):FunkinSprite
    {
        var sprite = new FunkinSprite(data.position[0], data.position[1], data.path);
        sprite.alpha = data.alpha;
        sprite.angle = data.angle;
        sprite.scale.set(data.scale[0], data.scale[1]);
        sprite.updateHitbox();
        sprite.screenCenter();
        sprite.x += data.position[0];
        sprite.y += data.position[1];
        sprite.scrollFactor.set(0, 0.1);
        sprite.camera = cam;
        return sprite;
    }

    function scroll(dir:Int, ?playSound:Bool = true):Void
    {
        curSelected += dir;

        var maxItems = menuItems.members.length;

        if (curSelected > maxItems - 1)
        {
            curSelected = 0;
            camIndex = 0;
        }
        else if (curSelected < 0)
        {
            curSelected = maxItems - 1;
            camIndex = Std.int(Math.max(0, maxItems - 4));
        }
        else if (curSelected > camIndex + 3)
            camIndex = curSelected - 3;
        else if (curSelected < camIndex)
            camIndex = curSelected;

        for (item in menuItems.members)
            item.playAnim(item.ID == curSelected ? 'selected' : 'idle', {force: true});

        if (playSound)
            FunkinSound.playOnce(Paths.sound('engine/scroll'));
    }

    function select(option:Int):Void
    {
        hasSelected = true;
        canSkip = true;

        if (MainMenuRegistry.data.background.flicker.visible)
            FlxFlicker.flicker(bgFlicker, 1, 0.15, false, true);

        for (item in menuItems.members)
        {
            if (item.ID == curSelected)
            {
                FlxFlicker.flicker(item, 1, 0.1, false, true);
                selectedOption = item.tag;
            }
            else
            {
                FlxTween.cancelTweensOf(item);
                FlxTween.tween(item, {alpha: 0}, 0.1);
            }
        }

        FlxTimer.wait(1, () ->
        {
            if (!hasSkipped)
                switchToOption(selectedOption);
        });

        FunkinSound.playOnce(Paths.sound('engine/confirm'));
    }

    function switchToOption(optionName:String):Void
    {
        for (optionEntry in MainMenuRegistry.data.options)
        {
            if (optionEntry.name != optionName)
                continue;

            var target:String = optionEntry.targetState;
            var targetClass = Type.resolveClass("menus." + target);

            if (targetClass != null)
            {
                var instance = Type.createInstance(targetClass, []);

                if (instance is FlxSubState)
                    Manager.openSubState(instance);
                else
                {
                    transitioning = true;
                    Manager.switchState(instance);
                }
            }
            else if (isScriptedSubState(target))
                Manager.openSubState(target);
            else
            {
                transitioning = true;
                Manager.switchState(target);
            }

            break;
        }
    }

    function isScriptedSubState(name:String):Bool
        return PolymodScriptClass.listScriptClassesExtending(Type.getClassName(FlxSubState)).indexOf(name) != -1;

    function exit():Void
    {
        hasSelected = true;
        transitioning = true;

        FunkinSound.playOnce(Paths.sound('engine/cancel'));
        Manager.switchState(new TitleState());
    }

    function regenerate():Void
    {
        hasSelected = false;

        canSkip = false;
        hasSkipped = false;

        FlxFlicker.stopFlickering(bgFlicker);
        bgFlicker.visible = false;

        for (item in menuItems.members)
        {
            FlxFlicker.stopFlickering(item);

            item.visible = true;
            item.alpha = 0;

            FlxTween.cancelTweensOf(item);
            FlxTween.tween(item, {alpha: 1}, 0.1);
        }
    }

    function checkSong()
    {
        if (FlxG.sound.music == null || !FlxG.sound.music.playing)
        {
            if (FunkinSound.playMusic(ConfigRegistry.data.song.path, {startingVolume: 0, persist: true}))
                FlxG.sound.music.fadeIn(1, 0, 1);
        }
    }
}
