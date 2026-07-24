package menus.charting;

import flixel.group.FlxSpriteGroup;

import openfl.geom.Rectangle;

class CharterNotePreview extends FlxSpriteGroup
{
    public var notes(default, null):FunkinSprite;
    public var viewport(default, null):FunkinSprite;
    public var playhead(default, null):FunkinSprite;

    public var previewWidth(default, null):Int = 0;
    public var previewHeight(default, null):Int = 0;
    public var columnWidth(default, null):Int = 5;

    public var needsRebuild:Bool = true;
    public var scrubbing:Bool = false;

    var rect:Rectangle = new Rectangle();

    public function new(x:Float, y:Float, width:Int, height:Int, columnWidth:Int)
    {
        super(x, y);

        this.previewWidth = width;
        this.previewHeight = height;
        this.columnWidth = columnWidth;

        notes = new FunkinSprite();
        notes.makeGraphic(width, height, 0xFF606060, true);
        add(notes);

        viewport = new FunkinSprite().makeGraphic(1, 1, FlxColor.WHITE);
        viewport.origin.set(0, 0);
        viewport.alpha = 0.25;
        add(viewport);

        playhead = new FunkinSprite().makeGraphic(1, 1, 0xFFDDDDDD);
        playhead.origin.set(0, 0);
        playhead.scale.set(width, 2);
        playhead.alpha = 0.8;
        add(playhead);
    }

    public function rebuild(strumlines:Array<CharterStrumline>, stepLengthMs:Float, gridSize:Float, totalHeight:Float, selection:Map<CharterNote, Bool>):Void
    {
        needsRebuild = false;

        if (stepLengthMs <= 0 || totalHeight <= 0) return;

        var pixels = notes.pixels;
        if (pixels == null) return;

        var scale:Float = previewHeight / totalHeight;
        var pixelsPerMs:Float = gridSize / stepLengthMs;

        pixels.lock();

        rect.setTo(0, 0, previewWidth, previewHeight);
        pixels.fillRect(rect, 0xFF606060);

        var column:Int = 0;

        for (strumline in strumlines)
        {
            for (note in strumline.notes)
            {
                var dir:Int = note.direction;
                if (dir < 0 || dir >= strumline.keys) continue;

                var noteX:Int = (column + dir) * columnWidth;

                var noteY:Int = Std.int(note.time * pixelsPerMs * scale);
                if (noteY < 0) noteY = 0;
                if (noteY > previewHeight - 1) noteY = previewHeight - 1;

                var selected:Bool = selection != null && selection.exists(note);
                var color:FlxColor = selected ? 0xFFFFFF00 : strumline.columnColors[dir];

                if (note.isHold)
                {
                    var endY:Int = Std.int(note.endTime * pixelsPerMs * scale);
                    if (endY > previewHeight) endY = previewHeight;

                    var tailHeight:Int = endY - noteY;
                    if (tailHeight < 1) tailHeight = 1;

                    var tailWidth:Int = columnWidth - 2;
                    if (tailWidth < 1) tailWidth = 1;

                    rect.setTo(noteX + 1, noteY, tailWidth, tailHeight);
                    pixels.fillRect(rect, selected ? 0xFF808000 : dim(strumline.columnColors[dir]));
                }

                rect.setTo(noteX, noteY, columnWidth, selected ? 2 : 1);
                pixels.fillRect(rect, color);
            }

            column += strumline.keys;
        }

        pixels.unlock();
        notes.dirty = true;
    }

    public function updateIndicators(viewTop:Float, viewHeight:Float, playheadWorldY:Float, gridOutline:Float, totalHeight:Float):Void
    {
        if (totalHeight <= 0) return;

        var scale:Float = previewHeight / totalHeight;

        var boxHeight:Float = viewHeight * scale;
        if (boxHeight > previewHeight) boxHeight = previewHeight;
        if (boxHeight < 2) boxHeight = 2;

        var boxY:Float = (viewTop - gridOutline) * scale;
        if (boxY < 0) boxY = 0;
        if (boxY > previewHeight - boxHeight) boxY = previewHeight - boxHeight;

        viewport.y = y + boxY;
        viewport.scale.set(previewWidth, boxHeight);

        var lineY:Float = (playheadWorldY - gridOutline) * scale;
        if (lineY < 0) lineY = 0;
        if (lineY > previewHeight - 2) lineY = previewHeight - 2;

        playhead.y = y + lineY;
    }

    public function containsPoint(screenX:Float, screenY:Float, slack:Float = 4.0):Bool
    {
        return screenX >= x - slack && screenX <= x + previewWidth + slack && screenY >= y - slack && screenY <= y + previewHeight + slack;
    }

    public function fractionAt(screenY:Float):Float
    {
        var fraction:Float = (screenY - y) / previewHeight;

        if (fraction < 0) fraction = 0;
        if (fraction > 1) fraction = 1;

        return fraction;
    }

    static inline function dim(color:FlxColor):FlxColor
    {
        return 0xFF000000 | ((color >> 1) & 0x7F7F7F);
    }
}
