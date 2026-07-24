package backend.transition;

import flixel.group.FlxSpriteGroup;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.math.FlxMath;
import flixel.util.FlxSort;
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.ShaderFilter;

typedef StickerPack =
{
    var name:String;
    var folder:String;
    var items:Array<String>;
}

class Transition extends FlxSpriteGroup
{
    public var shouldFinish:Bool = false;
    public var alias:String = "";

    public var transIn:Bool;
    public var transOut:Bool;

    public static var storedStickers:FlxTypedSpriteGroup<StickerSprite> = new FlxTypedSpriteGroup<StickerSprite>();
    public var grpStickers:FlxTypedSpriteGroup<StickerSprite>;
    
    public var isStickers:Bool = false;
    
    public var stickerPacks:Array<StickerPack> = [{name: "base", folder: "set-1", items: ["bf"]}];
    public var stickerCounts:Map<String, Int> = new Map<String, Int>();

    public var activeStickerPack:String = "base";

    public function new(alias:String)
    {
        super();
        this.alias = alias;

        grpStickers = new FlxTypedSpriteGroup<StickerSprite>();
        add(grpStickers);
    }

    public function initStickerGroup():Void
    {
        if (grpStickers == null)
        {
            grpStickers = new FlxTypedSpriteGroup<StickerSprite>();
            grpStickers.camera = this.camera;
            add(grpStickers);
        }
    }

    public function start():Void {}

    public function finish():Void
    {
        if (shouldFinish) return;
        shouldFinish = true;
    }

    public function destroyStoredStickers():Void
    {
        for (sticker in storedStickers.members)
        {
            if (sticker != null)
                sticker.destroy();
        }

        storedStickers.clear();
    }

    public function getStickerPath():String 
    {
        if (stickerPacks == null || stickerPacks.length == 0) 
            return 'bfSticker1';

        var pack:StickerPack = null;
        for (p in stickerPacks)
        {
            if (p.name == activeStickerPack)
            {
                pack = p;
                break;
            }
        }

        if (pack == null)
            pack = stickerPacks[0];

        if (pack.items == null || pack.items.length == 0) 
            return 'bfSticker1';

        var char:String = pack.items[FlxG.random.int(0, pack.items.length - 1)];
        var maxStickers:Int = getStickerCount(pack.folder, char);

        var folderPrefix:String = (pack.folder == null || pack.folder == "") ? "" : pack.folder + "/";
        return '${folderPrefix}${char}Sticker${FlxG.random.int(1, maxStickers)}';
    }

    public function getStickerCount(folder:String, char:String):Int
    {
        var cacheKey:String = folder + ":" + char;

        if (stickerCounts.exists(cacheKey))
            return stickerCounts.get(cacheKey);

        var count:Int = 0;
        var folderPrefix:String = (folder == null || folder == "") ? "" : folder + '/';

        var searching:Bool = true;
        
        while (searching)
        {
            var attempt:Int = count + 1;
            var stickerName:String = '${folderPrefix}${char}Sticker${attempt}';

            if (Paths.exists('images/engine/transition/stickers/$stickerName.png'))
                count++;
            else
                searching = false; 
        }

        if (count == 0)
            count = 1;

        stickerCounts.set(cacheKey, count);
        
        return count;
    }

    public function makeStickers(camWidth:Float, camHeight:Float):Void
    {   
        if (grpStickers != null)
            grpStickers.camera = this.camera;

        var xPos:Float = -100;
        var yPos:Float = -100;

        while (xPos <= camWidth)
        {
            var sticky:StickerSprite = new StickerSprite(0, 0, getStickerPath());
            sticky.camera = this.camera;
            sticky.x = xPos;
            sticky.y = yPos;
            xPos += sticky.frameWidth * 0.5;
            sticky.visible = false;

            if (xPos >= camWidth)
            {
                if (yPos <= camHeight)
                {
                    xPos = -100;
                    yPos += FlxG.random.float(70, 120);
                }
            }

            sticky.angle = FlxG.random.int(-60, 70);
            if (grpStickers != null) grpStickers.add(sticky);
        }

        for (daStickers in [grpStickers, storedStickers])
        {
            if (daStickers == null || daStickers.length == 0) continue;

            FlxG.random.shuffle(daStickers.members);

            var totalValid:Int = 0;
            for (s in daStickers.members) if (s != null) totalValid++;
            var processed:Int = 0;

            for (ind => sticker in daStickers.members)
            {
                if (sticker == null) continue;

                sticker.timing = FlxMath.remapToRange(ind, 0, daStickers.length, 0, 0.9);

                new FlxTimer().start(sticker.timing, _ ->
                {
                    if (sticker != null)
                    {
                        sticker.visible = true;

                        var snd = FunkinSound.playOnce(Paths.sound('engine/stickers/click${FlxG.random.int(1, 8)}'), 1.0, null, null, true);
                        if (snd != null) snd.pitch = FlxG.random.float(0.9, 1.1);

                        var frameTimer:Int = (processed == totalValid - 1 ? 2 : FlxG.random.int(0, 2));

                        new FlxTimer().start((1 / 24) * frameTimer, _ ->
                        {
                            if (sticker != null)
                                sticker.scale.x = sticker.scale.y = FlxG.random.float(0.97, 1.02);

                            processed++;

                            if (processed >= totalValid)
                            {
                                if (daStickers == grpStickers) 
                                {
                                    storedStickers.camera = this.camera; 

                                    for (s in grpStickers.members)
                                    {
                                        if (s != null)
                                            storedStickers.add(s);
                                    }
                                }

                                finish();
                            }
                        });
                    }
                });
            }

            daStickers.sort((ord, a, b) -> {
                return FlxSort.byValues(ord, a.timing, b.timing);
            });

            var lastOne:StickerSprite = null;

            for (i in 0...daStickers.members.length)
            {
                var s = daStickers.members[daStickers.members.length - 1 - i];

                if (s != null)
                {
                    lastOne = s;
                    break;
                }
            }

            if (lastOne != null)
            {
                lastOne.updateHitbox();
                lastOne.angle = 0;
                lastOne.setPosition(Std.int(camWidth - lastOne.width) / 2, Std.int(camHeight - lastOne.height) / 2);
            }
        }
    }

    public function killStickers():Void
    {
        if (grpStickers == null || grpStickers.length == 0)
        {
            finish();
            return;
        }

        var totalValid:Int = 0;

        for (s in grpStickers.members)
        {
            if (s != null)
                totalValid++;
        }

        var processed:Int = 0;

        for (ind => sticker in grpStickers.members)
        {
            if (sticker == null) continue;
            
            new FlxTimer().start(sticker.timing, _ ->
            {
                sticker.visible = false;
                sticker.destroy();

                var snd = FunkinSound.playOnce(Paths.sound('engine/stickers/click${FlxG.random.int(1, 5)}'), 1.0, null, null, true);
                if (snd != null) snd.pitch = FlxG.random.float(0.9, 1.1);

                processed++;

                if (processed >= totalValid)
                {
                    destroyStoredStickers();
                    finish();
                }
            });
        }
    }
}

class StickerSprite extends FunkinSprite
{
    public var timing:Float = 0;

    public function new(x:Float, y:Float, path:String):Void
    {
        super(x, y);

        loadGraphic(Paths.image('engine/transition/stickers/${path}', false, true));
        updateHitbox();
        antialiasing = true;
        scrollFactor.set();
    }
}