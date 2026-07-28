package backend.assets;

import animate.FlxAnimate;

import flixel.FlxSprite;
import flixel.system.FlxAssets.FlxGraphicAsset;

import openfl.display.BitmapData;

import backend.utils.tools.TagTools.ITaggable;

/**
 * How the sprite draws itself.
 * ATLAS = An animate atlas, export from Adobe Animate.
 * SPARROW = A spritesheet with an xml bundled with it.
 * TEXTURE = An image cut into frames of the same size.
 * MODEL = A 3D model drawn into the sprite's bitmap.
 */
enum RenderType
{
    ATLAS;
    SPARROW;
    TEXTURE;
    MODEL;
}

/**
 * Params used when loading a sprite.
 */
typedef SpriteParams =
{
    /**
     * The folder the file sits in. Defaults to images.
     */
    var ?folder:String;

    /**
     * The file extension. Defaults to png.
     */
    var ?extension:String;

    /**
     * Whether the path points somewhere outside the game's assets.
     */
    var ?absolute:Bool;

    /**
     * Whether the graphic stays in the cache instead of being cleared on a state switch.
     */
    var ?permanent:Bool;

    /**
     * Whether the graphic is cached into the GPU.
     */
    var ?gpuLoaded:Bool;

    /**
     * The size of one frame, for images cut into frames of the same size.
     */
    var ?frameWidth:Int;
    var ?frameHeight:Int;
}

/**
 * Params used when adding an animation.
 */
typedef SpriteAddAnimParams =
{
    /**
     * The name of the frames in the spritesheet. Defaults to the animation's own name.
     */
    var ?prefix:String;

    /**
     * How far the sprite shifts while this animation plays.
     */
    var ?offsets:Array<Int>;

    /**
     * Whether the animation starts over when it ends.
     */
    var ?looped:Bool;

    /**
     * How many frames the animation plays per second.
     */
    var ?fps:Int;

    /**
     * Whether the animation is flipped on the x and y axis.
     */
    var ?flip:Array<Bool>;

    /**
     * The frames to use and the order to play them in. Leave it empty to use all of them.
     */
    var ?indices:Array<Int>;
}

/**
 * Params used when playing an animation.
 */
typedef SpritePlayAnimParams =
{
    /**
     * Whether to start the animation over if it is already the one playing.
     */
    var ?force:Bool;

    /**
     * Whether the animation plays backwards.
     */
    var ?reversed:Bool;

    /**
     * The frame the animation starts on.
     */
    var ?frame:Int;

    /**
     * Called once the animation finishes.
     */
    var ?onComplete:Void->Void;
}

/**
 * An extension of FlxSprite, that supports auto-detected rendering modes and 
 */
class FunkinSprite extends FlxSprite implements ITaggable
{
    /**
     * A name to look this sprite up by.
     */
    public var tag:String = "";

    /**
     * The params this sprite was loaded with.
     */
    public var spriteParams:SpriteParams;

    /**
     * The path this sprite was loaded from.
     */
    public var spritePath:String;

    /**
     * The offset of every animation, by name.
     */
    public var offsetMap:Map<String, Array<Int>> = new Map<String, Array<Int>>();

    /**
     * The animate atlas this sprite draws, or null on any other render type.
     */
    public var atlasSpr:FlxAnimate;

    /**
     * How this sprite draws itself.
     */
    public var renderType:RenderType = SPARROW;

    /**
     * The 3D model drawn into this sprite, or null if a 2D sprite is being rendered.
     */
    public var model:FunkinModel = null;

    /**
     * The viewport that renders the model into this sprite's bitmap.
     */
    public var viewport:FunkinViewport = null;

    /**
     * Whether the model gets re-rendered each frame. Turn off to freeze it on the current pose.
     */
    public var dirty3D:Bool = true;

    /**
     * The size of the bitmap a model renders into. Higher number means higher quality which decreases performance.
     */
    public static var modelRenderSize:Int = 768;

    /**
     * The margin left around a model so it doesn't cut off.
     */
    public static var modelFrameMargin:Float = 2.0;

    /**
     * How many times a second a model redraws itself.
     */
    public static var modelRenderFps:Int = 30;

    /**
     * The bitmap the model renders into, used as this sprite's graphic.
     */
    private var _modelBitmap:BitmapData = null;

    /**
     * Whether the model has already rendered this frame, so it only renders onces.
     */
    private var _rendered3D:Bool = false;

    /**
     * How long it has been since the model last redrew, kept so it can hold to the set framerate.
     */
    private var _modelTimer:Float = 0;

    public function new(?x:Float = 0, ?y:Float = 0, ?path:String, ?params:SpriteParams)
    {
        super(x, y);

        if (path != null)
            loadSprite(path, params);
    }

    /**
     * Loads a spritesheet or an atlas and sets the render type that fits what it found.
     */
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
        
        offsetMap.clear();

        if (atlasSpr != null)
        {
            atlasSpr.destroy();
            atlasSpr = null;
        }

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

    /**
     * Loads a model and renders it into this sprite's bitmap.
     */
    public function loadModel(path:String, ?params:ModelParams):FunkinSprite
    {
        disposeModel();

        viewport = new FunkinViewport({width: modelRenderSize, height: modelRenderSize});
        model = new FunkinModel(path, params);
        viewport.add(model);
        viewport.frame(model, modelFrameMargin);

        _modelBitmap = new BitmapData(modelRenderSize, modelRenderSize, true, 0x00000000);
        loadGraphic(_modelBitmap);

        renderType = MODEL;
        refreshModel();

        return this;
    }

    /**
     * Renders the model into the bitmap.
     */
    private function refreshModel():Void
    {
        if (viewport == null || _modelBitmap == null)
            return;

        viewport.render(_modelBitmap);

        if (_modelBitmap.image != null)
            _modelBitmap.image.version++;
    }

    /**
     * Frees the model, its viewport and its bitmap.
     */
    public function disposeModel():Void
    {
        if (viewport != null)
        {
            viewport.destroy();
            viewport = null;
        }

        model = null;

        if (_modelBitmap != null)
        {
            if (graphic != null)
                FlxG.bitmap.remove(graphic);
            else
                _modelBitmap.dispose();

            _modelBitmap = null;
        }
    }

    /**
     * The same as FlxSprite's, only it returns a FunkinSprite instead of an FlxSprite.
     */
    override public function loadGraphic(graphic:FlxGraphicAsset, animated = false, frameWidth = 0, frameHeight = 0, unique = false, ?key:String):FunkinSprite
    {
        super.loadGraphic(graphic, animated, frameWidth, frameHeight, unique, key);
        return this;
    }

    /**
     * The same as FlxSprite's, only it returns a FunkinSprite instead of an FlxSprite.
     */
    override public function makeGraphic(width:Int, height:Int, color = FlxColor.WHITE, unique = false, ?key:String):FunkinSprite
    {
        super.makeGraphic(width, height, color, unique, key);
        return this;
    }

    /**
     * Adds an animation.
     */
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

    /**
     * Plays an animation and applies any offsets given.
     */
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

    /**
     * Whether the sprite has an animation with that name.
     */
    public function hasAnim(name:String):Bool
    {
        if (renderType == ATLAS)
            return (atlasSpr != null && atlasSpr.anim.getByName(name) != null);
        else
            return (animation != null && animation.getByName(name) != null);
    }

    /**
     * Renders the model or an atlas sprite.
     */
    override public function update(elapsed:Float):Void
    {
        if (renderType == MODEL)
        {
            _modelTimer += elapsed;

            if (modelRenderFps <= 0 || _modelTimer >= 1 / modelRenderFps)
            {
                _modelTimer = 0;
                _rendered3D = false;
            }

            if (model != null)
                model.update(elapsed);
        }
        else if (renderType == ATLAS && atlasSpr != null)
            atlasSpr.update(elapsed);

        super.update(elapsed);
    }

    /**
     * Draws the sprite.
     */
    override public function draw():Void
    {
        if (renderType == MODEL)
        {
            if (dirty3D && !_rendered3D)
            {
                refreshModel();
                _rendered3D = true;
            }

            super.draw();
        }
        else if (renderType == ATLAS && atlasSpr != null)
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

    /**
     * Destroy the atlas sprite or the model.
     */
    override public function destroy():Void
    {
        if (atlasSpr != null)
        {
            atlasSpr.destroy();
            atlasSpr = null;
        }

        disposeModel();

        super.destroy();
    }
}
