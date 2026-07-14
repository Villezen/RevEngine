package backend.assets;

import animate.FlxAnimate;

import flixel.system.FlxAssets.FlxGraphicAsset;

import backend.utils.tools.TagTools.ITaggable;

enum RenderType
{
    ATLAS;
    SPARROW;
    TEXTURE;
}

typedef SpriteParams =
{
    var ?folder:String;
    var ?extension:String;
    var ?absolute:Bool;
    var ?permanent:Bool;
    var ?gpuLoaded:Bool;
    var ?frameWidth:Int;
    var ?frameHeight:Int;
}

typedef SpriteAddAnimParams =
{
    var ?prefix:String;
    var ?offsets:Array<Int>;
    var ?looped:Bool;
    var ?fps:Int;
    var ?flip:Array<Bool>;
    var ?indices:Array<Int>;
}

typedef SpritePlayAnimParams =
{
    var ?force:Bool;
    var ?reversed:Bool;
    var ?frame:Int;
    var ?onComplete:Void->Void;
}

class FunkinSprite extends FlxSprite implements ITaggable
{
    public var tag:String = "";

    public var spriteParams:SpriteParams;
    public var spritePath:String;
    public var offsetMap:Map<String, Array<Int>> = new Map<String, Array<Int>>();
    public var atlasSpr:FlxAnimate;
    public var renderType:RenderType = SPARROW;

    public function new(?x:Float = 0, ?y:Float = 0, ?path:String, ?params:SpriteParams)
    {
        super(x, y);

        if (path != null)
            loadSprite(path, params);
    }

    public function loadSprite(path:String, ?params:SpriteParams):FunkinSprite
    {
        if (params == null) params = {};

        if (params.folder == null) params.folder = "images";
        if (params.extension == null) params.extension = "png";
        if (params.absolute == null) params.absolute = false;
        if (params.permanent == null) params.permanent = false;
        if (params.gpuLoaded == null) params.gpuLoaded = true;
        if (params.frameWidth == null) params.frameWidth = 0;
        if (params.frameHeight == null) params.frameHeight = 0;

        this.spriteParams = params;
        this.spritePath = path;

        var base = '${params.folder}/$path';

        if (Paths.exists('$base.${params.extension}', params.absolute))
        {
            if (Paths.exists('$base.xml', params.absolute))
            {
                frames = Paths.getSparrowAtlas(path, params.folder, params.absolute);
                renderType = SPARROW;
            }
            else if (params.frameWidth > 0 || params.frameHeight > 0)
            {
                loadGraphic(Paths.image(path, params.folder, params.extension, params.absolute, params.permanent), true, params.frameWidth, params.frameHeight);
                renderType = TEXTURE;
            }
            else
            {
                loadGraphic(Paths.image(path, params.folder, params.extension, params.absolute, params.permanent));
                renderType = SPARROW;
            }
        }
        else if (Paths.isDirectory(base, params.absolute) && Paths.exists('$base/Animation.json', params.absolute))
        {
            frames = Paths.getAnimateAtlas(path, params.folder, null, params.absolute);

            atlasSpr = new FlxAnimate(x, y, Paths.atlas(path, params.folder, params.absolute));
            atlasSpr.applyStageMatrix = true;

            renderType = ATLAS;
        }
        else
            trace('Could not find sprite: $base', "WARNING");

        return this;
    }

    override public function loadGraphic(graphic:FlxGraphicAsset, animated = false, frameWidth = 0, frameHeight = 0, unique = false, ?key:String):FunkinSprite
    {
        super.loadGraphic(graphic, animated, frameWidth, frameHeight, unique, key);
        return this;
    }

    override public function makeGraphic(width:Int, height:Int, color = FlxColor.WHITE, unique = false, ?key:String):FunkinSprite
    {
        super.makeGraphic(width, height, color, unique, key);
        return this;
    }

    public function addAnim(name:String, ?data:SpriteAddAnimParams):Void
    {
        if (data == null) data = {};

        if (data.prefix == null) data.prefix = name;
        if (data.offsets == null) data.offsets = [0, 0];
        if (data.looped == null) data.looped = false;
        if (data.fps == null) data.fps = 24;
        if (data.flip == null) data.flip = [false, false];
        if (data.indices == null) data.indices = [];

        if (renderType == ATLAS)
        {
            if (atlasSpr == null) return;

            @:privateAccess
            var symbols:Array<String> = atlasSpr.library.dictionary.keys().array();
            var frameLabels:Array<String> = [];

            @:privateAccess
            for (layer in atlasSpr.library.timeline.layers)
            {
                for (frame in layer.frames)
                {
                    if (frame.name != null && frame.name != "")
                        frameLabels.push(frame.name);
                }
            }

            if (frameLabels.contains(data.prefix))
            {
                if (data.indices.length == 0)
                    atlasSpr.anim.addByFrameLabel(name, data.prefix, data.fps, data.looped, data.flip[0], data.flip[1]);
                else
                    atlasSpr.anim.addByFrameLabelIndices(name, data.prefix, data.indices, data.fps, data.looped, data.flip[0], data.flip[1]);
            }
            else if (symbols.contains(data.prefix))
            {
                if (data.indices.length == 0)
                    atlasSpr.anim.addBySymbol(name, data.prefix, data.fps, data.looped, data.flip[0], data.flip[1]);
                else
                    atlasSpr.anim.addBySymbolIndices(name, data.prefix, data.indices, data.fps, data.looped, data.flip[0], data.flip[1]);
            }
            else
                trace('Could not find Frame Label or Symbol named: ' + data.prefix, "WARNING");
        }
        else if (renderType == TEXTURE)
        {
            if (data.indices.length == 0)
                data.indices = [for (i in 0...animation.numFrames) i];

            animation.add(name, data.indices, data.fps, data.looped, data.flip[0], data.flip[1]);
        }
        else
        {
            if (data.indices.length == 0)
                animation.addByPrefix(name, data.prefix, data.fps, data.looped, data.flip[0], data.flip[1]);
            else
                animation.addByIndices(name, data.prefix, data.indices, "", data.fps, data.looped, data.flip[0], data.flip[1]);
        }

        offsetMap[name] = data.offsets;
    }

    public function playAnim(name:String, ?data:SpritePlayAnimParams):Void
    {
        if (data == null) data = {};

        if (data.force == null) data.force = false;
        if (data.reversed == null) data.reversed = false;
        if (data.frame == null) data.frame = 0;

        if (renderType == ATLAS)
        {
            if (atlasSpr == null || atlasSpr.anim.getByName(name) == null) return;
            atlasSpr.anim.play(name, data.force, data.reversed, data.frame);

            if (data.onComplete != null)
                atlasSpr.anim.onFinish.addOnce((_) -> data.onComplete());
        }
        else
        {
            if (animation == null || animation.getByName(name) == null) return;
            animation.play(name, data.force, data.reversed, data.frame);

            if (data.onComplete != null)
                animation.onFinish.addOnce((_) -> data.onComplete());
        }

        if (offsetMap.exists(name))
        {
            var animOffset = offsetMap.get(name);
            var ox = (animOffset[0] * -1) * scale.x;
            var oy = (animOffset[1] * -1) * scale.y;

            if (angle != 0)
            {
                var rads = angle * (Math.PI / 180);
                var cos = Math.cos(rads);
                var sin = Math.sin(rads);

                var rx = (ox * cos) - (oy * sin);
                var ry = (ox * sin) + (oy * cos);

                offset.set(rx, ry);
            }
            else
            {
                offset.set(ox, oy);
            }
        }
        else
            offset.set(0, 0);
    }

    public function hasAnim(name:String):Bool
    {
        if (renderType == ATLAS)
            return (atlasSpr != null && atlasSpr.anim.getByName(name) != null);
        else
            return (animation != null && animation.getByName(name) != null);
    }

    override public function update(elapsed:Float):Void
    {
        if (renderType == ATLAS && atlasSpr != null)
            atlasSpr.update(elapsed);

        super.update(elapsed);
    }

    override public function draw():Void
    {
        if (renderType == ATLAS && atlasSpr != null)
        {
            atlasSpr.x = x;
            atlasSpr.y = y;
            atlasSpr.alpha = alpha;
            atlasSpr.color = color;
            atlasSpr.antialiasing = antialiasing;
            atlasSpr.scale.copyFrom(scale);
            atlasSpr.offset.copyFrom(offset);
            atlasSpr.cameras = cameras;
            atlasSpr.shader = shader;
            atlasSpr.blend = blend;

            atlasSpr.draw();
        }
        else
        {
            super.draw();
        }
    }

    override public function destroy():Void
    {
        if (atlasSpr != null)
        {
            atlasSpr.destroy();
            atlasSpr = null;
        }

        super.destroy();
    }
}
