package menus.charting;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.addons.display.FlxRuntimeShader;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;

import backend.registries.world.CharacterRegistry;

typedef CharterNoteGraphics =
{
    var heads:Array<FlxGraphic>;
    var bodies:Array<FlxGraphic>;
    var caps:Array<FlxGraphic>;
}

class CharterStrumline extends FlxBasic
{
    public static inline final KEY_AMOUNT:Int = 4;

    static inline final STATE_NORMAL:Int = 0;
    static inline final STATE_SELECTED:Int = 1;
    static inline final STATE_GHOST:Int = 2;

    var pulseTime:Float = 0.0;
    var selectionPulse:Float = 1.0;

    public var index(default, null):Int;
    public var notes:Array<CharterNote>;
    public var keys(default, null):Int;
    public var character:String;

    public var x(default, null):Float = 0;
    public var width(default, null):Float = 0;

    public var gridSize(default, null):Float;
    public var gridOutline(default, null):Float;
    public var totalHeight(default, null):Float;

    public var columnColors(default, null):Array<FlxColor> = [];
    public var columnGraphics(default, null):Array<Int> = [];
    public var maxSustain(default, null):Float = 0.0;

    public var grid(default, null):FunkinSprite;

    var graphics:CharterNoteGraphics;
    var gridCamera:FlxCamera;

    var headPools:Array<Array<FunkinSprite>> = [];
    var bodyPools:Array<Array<FunkinSprite>> = [];
    var capPools:Array<Array<FunkinSprite>> = [];

    var headCounts:Array<Int> = [];
    var bodyCounts:Array<Int> = [];
    var capCounts:Array<Int> = [];

    var playheadY:Float = 0;

    public function new(index:Int, notes:Array<CharterNote>, keys:Int, character:String, gridSize:Float, gridOutline:Float, graphics:CharterNoteGraphics, gridCamera:FlxCamera)
    {
        super();

        this.index = index;
        this.notes = notes;
        this.keys = (keys < 1) ? 1 : ((keys > 9) ? 9 : keys);
        this.character = character;
        this.gridSize = gridSize;
        this.gridOutline = gridOutline;
        this.graphics = graphics;
        this.gridCamera = gridCamera;

        this.width = (gridSize * this.keys) + (gridOutline * 2);

        for (i in 0...KEY_AMOUNT)
        {
            headPools.push([]);
            bodyPools.push([]);
            capPools.push([]);

            headCounts.push(0);
            bodyCounts.push(0);
            capCounts.push(0);
        }

        buildColumnTables();
        refreshSustainBounds();
    }

    public function buildGrid(totalHeight:Float):Void
    {
        this.totalHeight = totalHeight;

        if (grid == null)
        {
            grid = new FunkinSprite();
            grid.loadGraphic(Paths.image("menus/charter/pixel"));
            grid.camera = gridCamera;
        }

        var shader:FlxRuntimeShader = new FlxRuntimeShader(Paths.frag("engine/grid"));

        grid.setGraphicSize(Std.int(width), Std.int(totalHeight + gridOutline));
        grid.updateHitbox();
        grid.shader = shader;
        grid.x = x;
        grid.y = 0;

        shader.setFloatArray("u_spriteSize", [grid.width, grid.height]);
        shader.setFloat("u_gridSize", gridSize);
        shader.setFloat("u_outline", gridOutline);
        shader.setBool("u_outlineTop", true);
        shader.setBool("u_outlineBottom", true);
        shader.setBool("u_horizontal", false);

        var tint:FlxColor = FlxColor.interpolate(FlxColor.WHITE, CharacterRegistry.healthColor(character), 0.2);
        shader.setFloatArray("u_tint", [tint.redFloat, tint.greenFloat, tint.blueFloat]);
    }

    public function setX(value:Float):Void
    {
        x = value;

        if (grid != null)
            grid.x = value;
    }

    public function setKeys(value:Int):Void
    {
        keys = (value < 1) ? 1 : ((value > 9) ? 9 : value);
        width = (gridSize * keys) + (gridOutline * 2);

        for (note in notes)
        {
            if (note.direction >= keys) note.direction = keys - 1;
            if (note.direction < 0) note.direction = 0;
        }

        buildColumnTables();
    }

    function buildColumnTables():Void
    {
        columnColors = [];
        columnGraphics = [];

        var colorNames:Array<String> = Constants.COLOR_DIRECTIONS.exists(keys) ? Constants.COLOR_DIRECTIONS.get(keys) : null;
        var dirNames:Array<String> = Constants.DIRECTIONS.exists(keys) ? Constants.DIRECTIONS.get(keys) : null;

        for (dir in 0...keys)
        {
            var colorName:String = (colorNames != null && dir < colorNames.length) ? colorNames[dir] : null;
            columnColors.push(CharterStrumline.colorFor(colorName));

            var dirName:String = (dirNames != null && dir < dirNames.length) ? dirNames[dir] : null;
            columnGraphics.push(CharterStrumline.graphicFor(dirName, dir));
        }
    }

    public static function colorFor(name:String):FlxColor
    {
        return switch (name)
        {
            case "purple" | "A": 0xFFFF22AA;
            case "blue" | "B": 0xFF00EEFF;
            case "green" | "C": 0xFF00CC00;
            case "red" | "D": 0xFFCC1111;
            case "E": 0xFFEEEEEE;
            case "F": 0xFFEEEEEE;
            case "G": 0xFFEEEEEE;
            case "H": 0xFFEEEEEE;
            case "I": 0xFFEEEEEE;
            default: 0xFFBBBBBB;
        }
    }

    public static function graphicFor(name:String, dir:Int):Int
    {
        return switch (name)
        {
            case "left": 0;
            case "down": 1;
            case "up": 2;
            case "right": 3;
            case "space": 2;
            default: dir % KEY_AMOUNT;
        }
    }

    public function refreshSustainBounds():Void
    {
        var longest:Float = 0.0;

        for (note in notes)
            if (note.sustain > longest) longest = note.sustain;

        maxSustain = longest;
    }

    public function sortNotes():Void
    {
        notes.sort(CharterNote.compare);
    }

    public function firstVisibleIndex(time:Float):Int
    {
        var target:Float = time - maxSustain;

        var low:Int = 0;
        var high:Int = notes.length - 1;

        while (low <= high)
        {
            var mid:Int = (low + high) >> 1;

            if (notes[mid].time < target)
                low = mid + 1;
            else
                high = mid - 1;
        }

        return low;
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        pulseTime += elapsed;
        selectionPulse = 1.0 + Math.sin(pulseTime * 5) * 0.04;
    }

    public function refresh(topTime:Float, bottomTime:Float, stepLengthMs:Float, playheadY:Float, selection:Map<CharterNote, Bool>, hiddenNotes:Map<CharterNote, Bool>):Void
    {
        this.playheadY = playheadY;

        for (i in 0...KEY_AMOUNT)
        {
            headCounts[i] = 0;
            bodyCounts[i] = 0;
            capCounts[i] = 0;
        }

        if (!visible || notes.length == 0 || stepLengthMs <= 0)
            return;

        var pixelsPerMs:Float = gridSize / stepLengthMs;
        var i:Int = firstVisibleIndex(topTime);

        while (i < notes.length)
        {
            var note:CharterNote = notes[i];
            i++;

            if (note.time > bottomTime) break;
            if (note.endTime < topTime) continue;

            if (hiddenNotes != null && hiddenNotes.exists(note)) continue;

            drawNote(note.direction, note.time, note.sustain, pixelsPerMs, selection != null && selection.exists(note), false);
        }
    }

    public function drawNote(dir:Int, time:Float, sustain:Float, pixelsPerMs:Float, selected:Bool, ghost:Bool):Void
    {
        if (dir < 0) dir = 0;
        if (dir >= keys) dir = keys - 1;

        var noteX:Float = x + gridOutline + (dir * gridSize);
        var noteY:Float = gridOutline + (time * pixelsPerMs);

        drawNoteAt(noteX, noteY, dir, sustain, pixelsPerMs, selected, ghost);
    }

    public function drawNoteAt(noteX:Float, noteY:Float, dir:Int, sustain:Float, pixelsPerMs:Float, selected:Bool, ghost:Bool):Void
    {
        if (dir < 0) dir = 0;
        if (dir >= keys) dir = keys - 1;

        var graphic:Int = columnGraphics[dir];

        var alpha:Float = ghost ? 0.35 : 1.0;
        var state:Int = ghost ? STATE_GHOST : (selected ? STATE_SELECTED : STATE_NORMAL);

        if (sustain > 0)
        {
            var totalLength:Float = sustain * pixelsPerMs;
            var capHeight:Float = Math.min(totalLength, 20);
            var bodyHeight:Float = totalLength - capHeight;

            var sustainWidth:Float = Std.int(gridSize * 0.35);
            var sustainX:Float = noteX + ((gridSize - sustainWidth) / 2);
            var sustainY:Float = noteY + (gridSize / 2);

            if (bodyHeight > 0)
            {
                var body:FunkinSprite = acquire(bodyPools[graphic], bodyCounts[graphic]++, graphics.bodies[graphic]);
                place(body, sustainX, sustainY, sustainWidth, bodyHeight + 1.0, alpha, state);
            }

            var cap:FunkinSprite = acquire(capPools[graphic], capCounts[graphic]++, graphics.caps[graphic]);
            place(cap, sustainX, sustainY + bodyHeight, sustainWidth, capHeight, alpha, state);
        }

        var head:FunkinSprite = acquire(headPools[graphic], headCounts[graphic]++, graphics.heads[graphic]);
        place(head, noteX, noteY, gridSize, gridSize, alpha, state);
    }

    inline function acquire(pool:Array<FunkinSprite>, slot:Int, graphic:FlxGraphic):FunkinSprite
    {
        var sprite:FunkinSprite = (slot < pool.length) ? pool[slot] : null;

        if (sprite == null)
        {
            sprite = new FunkinSprite();

            if (graphic != null)
                sprite.loadGraphic(graphic);
            else
                sprite.makeGraphic(1, 1, FlxColor.TRANSPARENT);

            sprite.camera = gridCamera;
            pool.push(sprite);
        }

        return sprite;
    }

    inline function place(sprite:FunkinSprite, x:Float, y:Float, width:Float, height:Float, alpha:Float, state:Int):Void
    {
        if (Math.abs(sprite.width - width) > 0.05 || Math.abs(sprite.height - height) > 0.05)
        {
            sprite.setGraphicSize(width, height);
            sprite.updateHitbox();
        }

        sprite.x = x;
        sprite.y = y;
        sprite.alpha = alpha;
        sprite.ID = state;

        if (sprite.clipRect != null)
            sprite.clipRect = null;
    }

    override public function draw():Void
    {
        if (!visible) return;

        for (graphic in 0...KEY_AMOUNT)
            drawSustainPool(bodyPools[graphic], bodyCounts[graphic]);

        for (graphic in 0...KEY_AMOUNT)
            drawSustainPool(capPools[graphic], capCounts[graphic]);

        for (graphic in 0...KEY_AMOUNT)
        {
            var pool:Array<FunkinSprite> = headPools[graphic];
            var count:Int = headCounts[graphic];

            for (i in 0...count)
            {
                var sprite:FunkinSprite = pool[i];

                if (sprite.ID == STATE_SELECTED)
                {
                    lighten(sprite, 1.0);
                    drawPulsed(sprite);
                }
                else if (sprite.ID == STATE_GHOST)
                {
                    shade(sprite, 1.0, 0.35);
                    sprite.draw();
                }
                else
                {
                    shade(sprite, (sprite.y + (gridSize / 2) < playheadY) ? 0.6 : 1.0, 1.0);
                    sprite.draw();
                }
            }
        }
    }

    inline function shade(sprite:FunkinSprite, mult:Float, alpha:Float):Void
    {
        sprite.setColorTransform(mult, mult, mult, alpha, 0, 0, 0, 0);
    }

    inline function lighten(sprite:FunkinSprite, alpha:Float):Void
    {
        sprite.setColorTransform(1, 1, 1, alpha, 80, 80, 80, 0);
    }

    inline function drawPulsed(sprite:FunkinSprite):Void
    {
        if (selectionPulse == 1.0)
        {
            sprite.draw();
            return;
        }

        var baseX:Float = sprite.scale.x;
        var baseY:Float = sprite.scale.y;

        sprite.scale.set(baseX * selectionPulse, baseY * selectionPulse);
        sprite.draw();
        sprite.scale.set(baseX, baseY);
    }

    function drawSustainPool(pool:Array<FunkinSprite>, count:Int):Void
    {
        for (i in 0...count)
        {
            var sprite:FunkinSprite = pool[i];

            if (sprite.ID == STATE_SELECTED)
            {
                lighten(sprite, 1.0);
                sprite.draw();
                continue;
            }

            if (sprite.ID == STATE_GHOST)
            {
                shade(sprite, 1.0, 0.35);
                sprite.draw();
                continue;
            }

            var bottom:Float = sprite.y + sprite.height;

            if (bottom <= playheadY)
            {
                shade(sprite, 0.6, 1.0);
                sprite.draw();

                continue;
            }

            if (sprite.y >= playheadY || sprite.height <= 0)
            {
                shade(sprite, 1.0, 1.0);
                sprite.draw();

                continue;
            }

            var passed:Float = (playheadY - sprite.y) / sprite.height;

            shade(sprite, 0.6, 1.0);
            sprite.draw();

            var clip:FlxRect = FlxRect.get(0, passed * sprite.frameHeight, sprite.frameWidth, sprite.frameHeight * (1 - passed));

            sprite.clipRect = clip;
            shade(sprite, 1.0, 1.0);
            sprite.draw();

            sprite.clipRect = null;
            clip.put();
        }
    }

    public inline function containsX(worldX:Float):Bool
    {
        return worldX >= x && worldX <= x + width;
    }

    public function columnAt(worldX:Float):Int
    {
        var localX:Float = worldX - x - gridOutline;
        if (localX < 0) localX = 0;

        var column:Int = Math.floor(localX / gridSize);
        if (column >= keys) column = keys - 1;

        return column;
    }

    public function noteAt(worldX:Float, worldY:Float, stepLengthMs:Float):CharterNote
    {
        if (!containsX(worldX) || stepLengthMs <= 0) return null;

        var pixelsPerMs:Float = gridSize / stepLengthMs;
        var i:Int = firstVisibleIndex(((worldY - gridOutline) / gridSize) * stepLengthMs);

        while (i < notes.length)
        {
            var note:CharterNote = notes[i];
            i++;

            var noteY:Float = gridOutline + (note.time * pixelsPerMs);
            if (noteY > worldY) break;

            var noteX:Float = x + gridOutline + (note.direction * gridSize);
            if (worldX < noteX || worldX > noteX + gridSize) continue;

            var height:Float = note.isHold ? (note.sustain * pixelsPerMs) : gridSize;

            if (worldY >= noteY && worldY <= noteY + height)
                return note;
        }

        return null;
    }

    public function selectWithin(rect:FlxRect, stepLengthMs:Float, into:Array<CharterNote>, seen:Map<CharterNote, Bool>):Void
    {
        if (stepLengthMs <= 0) return;
        if (x > rect.right || x + width < rect.left) return;

        var pixelsPerMs:Float = gridSize / stepLengthMs;
        var hitSize:Float = gridSize / 4;
        var inset:Float = (gridSize - hitSize) / 2;

        var startTime:Float = ((rect.top - gridOutline - gridSize) / gridSize) * stepLengthMs;
        var endTime:Float = ((rect.bottom - gridOutline) / gridSize) * stepLengthMs;

        var i:Int = firstVisibleIndex(startTime);

        while (i < notes.length)
        {
            var note:CharterNote = notes[i];
            i++;

            if (note.time > endTime) break;

            var noteX:Float = x + gridOutline + (note.direction * gridSize) + inset;
            var noteY:Float = gridOutline + (note.time * pixelsPerMs) + inset;

            if (noteX < rect.right && noteX + hitSize > rect.left && noteY < rect.bottom && noteY + hitSize > rect.top)
            {
                if (!seen.exists(note))
                {
                    seen.set(note, true);
                    into.push(note);
                }
            }
        }
    }

    override public function destroy():Void
    {
        for (pools in [headPools, bodyPools, capPools])
        {
            for (pool in pools)
            {
                for (sprite in pool)
                {
                    if (sprite.clipRect != null)
                        sprite.clipRect = FlxDestroyUtil.put(sprite.clipRect);

                    sprite.destroy();
                }
            }
        }

        headPools = null;
        bodyPools = null;
        capPools = null;

        grid = FlxDestroyUtil.destroy(grid);

        notes = null;
        graphics = null;
        gridCamera = null;

        super.destroy();
    }
}
