package game.notes;

import flixel.graphics.tile.FlxDrawTrianglesItem.DrawData;

import flixel.animation.FlxAnimation;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;

import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxPoint.FlxCallbackPoint;

import backend.registries.ui.NoteSkinRegistry.BaseAnimationData;
import backend.utils.KeyUtil;

/**
 * A custom display object class for the sustain notes, using a custom mesh built by vertices and indices.
 * It uses UV mapping to avoid distortion while scaling.
 * * 90% of the code here is written by T5mpler & The Funkin Team (huge shoutouts). The other 10% is just stuff to ensure everything works properly on the engine.
 */
class SustainNote extends FunkinSprite
{
    public var vertices:DrawData<Float> = new DrawData<Float>();
    public var indices:DrawData<Int> = new DrawData<Int>();
    public var uvtData:DrawData<Float> = new DrawData<Float>();

    private var _tempVertices:Array<Float> = [];
    private var _tempUVTData:Array<Float> = [];
    private var _tempIndices:Array<Int> = [];

    public var generated:Bool = false;
    public var mustHit:Bool = false;
    public var glow:Bool = false;

    public var time:Float = 0;
    public var direction:Int = 0;
    public var fullLength:Float;

    public var length(default, set):Float;

    function set_length(value:Float):Float
    {
        if (value <= 0.0) value = 0.0;
        if (length == value) return length;
        if (value > fullLength) fullLength = value;

        length = value;
        redraw();

        return value;
    }

    public var skin(default, set):NoteStyle;

    function set_skin(value:NoteStyle):NoteStyle
    {
        if (skin == value) return skin;

        if (value == null)
        {
            skin = null;
            return null;
        }

        if (strum == null || strum.data == null || strum.parent == null)
            return skin = value;

        build(value);
        sync();

        return skin = value;
    }

    public var subdivisions(default, set):Int = 1;
    private var renderedSubdivisions:Int;

    function set_subdivisions(value:Int)
    {
        if (subdivisions == value) return value;
        value = Std.int(Math.max(value, 1));
        this.subdivisions = value;

        updateClipping();
        setupIndices(subdivisions);
        
        renderedSubdivisions = subdivisions;

        return value;
    }

    var holdAnimation(default, null):FlxAnimation;
    var holdEndAnimation(default, null):FlxAnimation;

    var holdFrame(get, never):FlxFrame;
    function get_holdFrame():FlxFrame
    {
        if (holdAnimation == null || holdAnimation.frames == null || frames == null || frames.frames == null) 
            return null;
        return frames?.frames[holdAnimation?.frames[holdAnimation?.curFrame]] ?? null;
    }

    var holdEndFrame(get, never):FlxFrame;
    function get_holdEndFrame():FlxFrame
    {
        if (holdEndAnimation == null || holdEndAnimation.frames == null || frames == null || frames.frames == null) 
            return null;
        return frames?.frames[holdEndAnimation?.frames[holdEndAnimation?.curFrame]] ?? null;
    }

    var tailTime(get, never):Float;
    function get_tailTime():Float
    {
        if (holdEndFrame == null || strumline == null || strumline.speed <= 0) return 0;
        return (holdEndFrame.frame.height * this.scale.x) / (0.45 * strumline.speed);
    }

    var visualLength(get, never):Float;
    function get_visualLength():Float
    {
        if (hit || length <= 0) return length;
        return Math.max(length, tailTime);
    }

    var fullVisualLength(get, never):Float;
    function get_fullVisualLength():Float
    {
        if (hit || fullLength <= 0) return fullLength;
        return Math.max(fullLength, tailTime);
    }

    public var note:Note;
    public var strum:Strum;
    public var strumline:Strumline;

    private var spriteWidth:Float;
    private var spriteHeight:Float;

    public var hit:Bool = false;
    public var missed:Bool = false;
    public var missHandled:Bool = false;

    public var alphaModifier:Float = 1.0;
    private var previousSpeed:Float;

    public inline static function sustainHeight(sustainLength:Float, scrollSpeed:Float):Float
    {
        return sustainLength * 0.45 * scrollSpeed;
    }

    public function new(strumline:Strumline)
    {
        super();

        this.strumline = strumline;

        if (this.scale != null) this.scale.destroy();

        this.scale = new FlxCallbackPoint((value:FlxPoint) -> {
            redraw();
        });
        this.scale.set(1, 1);

        updateClipping();
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        updateAlpha();

        if (holdAnimation == null || holdEndAnimation == null) return;

        var lastHoldFrame:FlxFrame = holdFrame;
        var lastHoldEndFrame:FlxFrame = holdEndFrame;

        holdAnimation.update(elapsed * (animation.timeScale * FlxG.animationTimeScale));
        holdEndAnimation.update(elapsed * (animation.timeScale * FlxG.animationTimeScale));

        if (previousSpeed != strumline.speed || (lastHoldFrame != holdFrame || lastHoldEndFrame != holdEndFrame))
        {
            redraw();
        }
        previousSpeed = strumline.speed;
    }

    override public function draw():Void
    {
        if (alpha == 0 || graphic == null || vertices == null) return;

        getScreenPosition(_point, strumline.camera).subtract(offset);
        strumline.camera.drawTriangles(graphic, vertices, indices, uvtData, null, _point, blend, false, antialiasing, colorTransform, shader);
    }

    override function updateHitbox()
    {
        this.width = spriteWidth;
        this.height = spriteHeight;

        origin.set(this.width * 0.5, this.height * 0.5);
    }

    override function kill()
    {
        super.kill();

        generated = false;
        fullLength = 0;
        length = 0;
        subdivisions = 1;

        strumline = null;
        strum = null;
        note = null;
        glow = false;
        
        skin = null;
    }

    override function revive()
    {
        super.revive();
        
        generated = true;
        time = 0;
        direction = 0;
        fullLength = 0;
        length = 0;
        subdivisions = 1;
        
        hit = false;
        missed = false;
        missHandled = false;
    }

    override function destroy()
    {
        vertices = null;
        uvtData = null;
        indices = null;

        _tempVertices = null;
        _tempUVTData = null;
        _tempIndices = null;
        
        super.destroy();
    }

    public function build(noteStyle:NoteStyle)
    {
        if (strumline == null || direction >= strumline.keyCount)
            return;

        noteStyle.applyToSustain(this);

        if (animation == null || animation.getByName('hold') == null || animation.getByName('tail') == null) return;

        this.scale.x = note.scale.x;

        holdAnimation = animation.getByName('hold');
        holdEndAnimation = animation.getByName('tail');

        spriteWidth = holdFrame.frame.width * this.scale.x;
        spriteHeight = sustainHeight(visualLength, strumline.speed) * this.scale.y;
        
        updateHitbox();
        updateClipping();

        offset.set(0, 0);

        if (strum != null && strum.parent != null)
        {
            this.antialiasing = strum.data.antialiasing;

            var keyCount = strum.parent.keyCount;
            var anims:Array<BaseAnimationData> = KeyUtil.isEK(keyCount) ? strum.data.animations.extraKeys : strum.data.animations.normal;
            var colorStr:String = (KeyUtil.isEK(keyCount) ? Constants.COLOR_DIRECTIONS[keyCount][direction] : Constants.DIRECTIONS[keyCount][direction]).toUpperCase();

            var targetName = 'hold$colorStr';

            for (animEntry in anims)
            {
                if (animEntry.name == targetName)
                {
                    offset.x -= animEntry.offsets[0];
                    offset.y -= animEntry.offsets[1];
                    break;
                }
            }
        }
    }

    function updateAlpha()
    {       
        var missModifier:Float = 1.0;

        if (missHandled) missModifier = 0.4;

        if (strum != null)
            alpha = strum.alpha * alphaModifier * missModifier * strum.data.sustainAlpha;
        else
            alpha = alphaModifier * missModifier;
    }

    public function sync()
    {
        if (strum == null) return;
        x = strum.x + (strum.width - this.spriteWidth) / 2;
    }

    function redraw()
    {
        spriteWidth = (holdFrame?.frame?.width ?? 0.0) * this.scale.x;
        spriteHeight = sustainHeight(visualLength, strumline.speed) * this.scale.y;
        
        updateClipping();
        updateHitbox();
    }

    public function setVertices(newVertices:Array<Float>)
    {
        this.vertices.length = newVertices.length;
        for (i in 0...newVertices.length) this.vertices[i] = newVertices[i];
    }

    public function setUVTData(newUVTData:Array<Float>)
    {
        this.uvtData.length = newUVTData.length;
        for (i in 0...newUVTData.length) this.uvtData[i] = newUVTData[i]; 
    }

    public function setIndices(newIndices:Array<Int>)
    {
        this.indices.length = newIndices.length;
        for (i in 0...newIndices.length) this.indices[i] = newIndices[i];
    }

    function updateClipping()
    {
        if (graphic == null || holdFrame == null || holdEndFrame == null || length <= 0) return;

        _tempVertices.resize(0);
        _tempUVTData.resize(0);

        var fullClipHeight = sustainHeight(fullVisualLength, strumline.speed);
        var clipHeight:Float = FlxMath.bound(sustainHeight(visualLength, strumline.speed), 0, spriteHeight);

        if (clipHeight <= 0)
        {
            visible = false;
            return;
        }

        var bottomHeight:Float = holdEndFrame.frame.height * this.scale.x;
        var partHeight:Float = clipHeight - bottomHeight;
        var fullPartHeight:Float = fullClipHeight - bottomHeight;

        var clipProgression:Float = fullPartHeight - partHeight;
        var splitFullHeight:Float = (fullPartHeight / this.subdivisions);
        var validSubdivisions:Int = 0;
        var firstValidHeight:Float = 0;

        for (i in 0...this.subdivisions)
        {
            var h = splitFullHeight + (i * splitFullHeight);

            if (h > clipProgression)
            {
                if (validSubdivisions == 0) firstValidHeight = h - clipProgression;
                validSubdivisions++;
            }
        }

        if (validSubdivisions == 0) validSubdivisions = 1;

        // HOLD VERTICES //
        _tempVertices[0 * 2] = 0.0;
        _tempVertices[0 * 2 + 1] = flipY ? clipHeight : (spriteHeight - clipHeight);
        _tempVertices[1 * 2] = spriteWidth;
        _tempVertices[1 * 2 + 1] = _tempVertices[0 * 2 + 1];

        var startIndexPoint:Int = 2;
        var vertexIndex:Int = startIndexPoint;
        var lastVertexIndex:Int = startIndexPoint;

        for (i in 0...validSubdivisions)
        {
            var height = (i == 0) ? firstValidHeight : splitFullHeight;

            if (i == 0)
            {
                _tempVertices[vertexIndex * 2] = _tempVertices[0 * 2];
                _tempVertices[vertexIndex * 2 + 1] = (height > 0) ? (_tempVertices[0 * 2 + 1] + height) : _tempVertices[0 * 2 + 1];
                _tempVertices[(vertexIndex + 1) * 2] = _tempVertices[1 * 2]; 
                _tempVertices[(vertexIndex + 1) * 2 + 1] = _tempVertices[vertexIndex * 2 + 1]; 
                lastVertexIndex = vertexIndex;
                vertexIndex += 2;
            }
            else
            {
                _tempVertices[vertexIndex * 2] = _tempVertices[lastVertexIndex * 2];
                _tempVertices[vertexIndex * 2 + 1] = _tempVertices[lastVertexIndex * 2 + 1];
                _tempVertices[(vertexIndex + 1) * 2] = _tempVertices[(lastVertexIndex + 1) * 2];
                _tempVertices[(vertexIndex + 1) * 2 + 1] = _tempVertices[(lastVertexIndex + 1) * 2 + 1];
                _tempVertices[(vertexIndex + 2) * 2] = _tempVertices[vertexIndex * 2]; 
                _tempVertices[(vertexIndex + 2) * 2 + 1] = flipY ? _tempVertices[vertexIndex * 2 + 1] - height : _tempVertices[vertexIndex * 2 + 1] + height;
                _tempVertices[(vertexIndex + 3) * 2] = _tempVertices[(vertexIndex + 1) * 2]; 
                _tempVertices[(vertexIndex + 3) * 2 + 1] = _tempVertices[(vertexIndex + 2) * 2 + 1]; 
                lastVertexIndex = vertexIndex + 2;
                vertexIndex += 4;
            }       
        }

        // HOLD END VERTICES //
        var endVertexIndexLeft:Int = vertexIndex - 2;
        var endVertexIndexRight:Int = vertexIndex - 1;

        var overlapPixels:Float = 2.5;
        var seamYLeft:Float = _tempVertices[endVertexIndexLeft * 2 + 1];
        var seamYRight:Float = _tempVertices[endVertexIndexRight * 2 + 1];

        _tempVertices[endVertexIndexLeft * 2 + 1] += flipY ? -overlapPixels : overlapPixels;
        _tempVertices[endVertexIndexRight * 2 + 1] += flipY ? -overlapPixels : overlapPixels;

        _tempVertices[vertexIndex * 2] = _tempVertices[endVertexIndexLeft * 2]; 
        _tempVertices[vertexIndex * 2 + 1] = seamYLeft; 

        _tempVertices[(vertexIndex + 1) * 2] = _tempVertices[endVertexIndexRight * 2]; 
        _tempVertices[(vertexIndex + 1) * 2 + 1] = seamYRight; 

        _tempVertices[(vertexIndex + 2) * 2] = _tempVertices[vertexIndex * 2]; 
        _tempVertices[(vertexIndex + 2) * 2 + 1] = if (partHeight > 0)
        {
            (seamYLeft + bottomHeight);
        }
        else
        {
            (seamYLeft + bottomHeight * (clipHeight / bottomHeight));
        }

        _tempVertices[(vertexIndex + 3) * 2] = _tempVertices[(vertexIndex + 1) * 2]; 
        _tempVertices[(vertexIndex + 3) * 2 + 1] = _tempVertices[(vertexIndex + 2) * 2 + 1]; 

        // HOLD UVs //
        var uvInset:Float = 1.5 / graphic.height;
        var safeHoldTop:Float = holdFrame.uv.top + uvInset;
        var safeHoldBottom:Float = holdFrame.uv.bottom - uvInset;
        var safeTailTop:Float = holdEndFrame.uv.top + uvInset;

        _tempUVTData[0 * 2] = holdFrame.uv.left;
        _tempUVTData[0 * 2 + 1] = safeHoldTop + (1 - Math.max(0, firstValidHeight / (fullPartHeight / renderedSubdivisions))) * (safeHoldBottom - safeHoldTop);

        _tempUVTData[1 * 2] = holdFrame.uv.right;
        _tempUVTData[1 * 2 + 1] = _tempUVTData[0 * 2 + 1];

        var curVertexPoint:Int = startIndexPoint;

        while (curVertexPoint != vertexIndex)
        {
            if (curVertexPoint == startIndexPoint)
            {
                _tempUVTData[curVertexPoint * 2] = _tempUVTData[0 * 2]; 
                _tempUVTData[curVertexPoint * 2 + 1] = safeHoldBottom;
                _tempUVTData[(curVertexPoint + 1) * 2] = _tempUVTData[1 * 2]; 
                _tempUVTData[(curVertexPoint + 1) * 2 + 1] = _tempUVTData[curVertexPoint * 2 + 1]; 
                curVertexPoint += 2;
            }
            else
            {
                _tempUVTData[curVertexPoint * 2] = _tempUVTData[0 * 2]; 
                _tempUVTData[curVertexPoint * 2 + 1] = safeHoldTop;
                _tempUVTData[(curVertexPoint + 1) * 2] = _tempUVTData[1 * 2]; 
                _tempUVTData[(curVertexPoint + 1) * 2 + 1] = _tempUVTData[curVertexPoint * 2 + 1]; 
                _tempUVTData[(curVertexPoint + 2) * 2] = _tempUVTData[curVertexPoint * 2]; 
                _tempUVTData[(curVertexPoint + 2) * 2 + 1] = safeHoldBottom;
                _tempUVTData[(curVertexPoint + 3) * 2] = _tempUVTData[(curVertexPoint + 1) * 2];  
                _tempUVTData[(curVertexPoint + 3) * 2 + 1] = _tempUVTData[(curVertexPoint + 2) * 2 + 1]; 
                curVertexPoint += 4;
            }
        }

        // HOLD END UVs //
        _tempUVTData[vertexIndex * 2] = holdEndFrame.uv.left;
        _tempUVTData[vertexIndex * 2 + 1] = if (partHeight > 0)
        {
            safeTailTop;
        }
        else
        {
            var clippedTop = (holdEndFrame.frame.y + ((bottomHeight - clipHeight) / this.scale.x)) / graphic.height;
            Math.max(safeTailTop, clippedTop); 
        }

        _tempUVTData[(vertexIndex + 1) * 2] = holdEndFrame.uv.right;
        _tempUVTData[(vertexIndex + 1) * 2 + 1] = _tempUVTData[vertexIndex * 2 + 1]; 
        _tempUVTData[(vertexIndex + 2) * 2] = _tempUVTData[vertexIndex * 2]; 
        _tempUVTData[(vertexIndex + 2) * 2 + 1] = holdEndFrame.uv.bottom;
        _tempUVTData[(vertexIndex + 3) * 2] = _tempUVTData[(vertexIndex + 1) * 2]; 
        _tempUVTData[(vertexIndex + 3) * 2 + 1] = _tempUVTData[(vertexIndex + 2) * 2 + 1]; 

        if (validSubdivisions != renderedSubdivisions)
        {
            this.renderedSubdivisions = validSubdivisions;
            setupIndices(validSubdivisions);
        }

        setVertices(_tempVertices);
        setUVTData(_tempUVTData);
    }

    function setupIndices(subdivisions:Int)
    {
        _tempIndices.resize(0);
        var endVertexIndex:Int = 4;

        _tempIndices.push(0);
        _tempIndices.push(1);
        _tempIndices.push(2);

        _tempIndices.push(1);
        _tempIndices.push(2);
        _tempIndices.push(3);

        for (i in 0...subdivisions - 1)
        {
            _tempIndices.push(4 + i * 4);
            _tempIndices.push(5 + i * 4);
            _tempIndices.push(6 + i * 4);

            _tempIndices.push(5 + i * 4);
            _tempIndices.push(6 + i * 4);
            _tempIndices.push(7 + i * 4);

            endVertexIndex += 4;
        }

        _tempIndices.push(endVertexIndex);
        _tempIndices.push(endVertexIndex + 1);
        _tempIndices.push(endVertexIndex + 2);

        _tempIndices.push(endVertexIndex + 1);
        _tempIndices.push(endVertexIndex + 2);
        _tempIndices.push(endVertexIndex + 3);

        setIndices(_tempIndices);
    }
}