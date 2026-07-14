import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;

import backend.converters.Converter;

import sys.io.File;
import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;

class Charter extends MusicBeatState
{
    var GRID_SIZE:Float = 40.0;
    var GRID_OUTLINE:Float = 5.0;

    var TOTAL_WIDTH:Float = 0.0;
    var TOTAL_HEIGHT:Float = 0.0;

    var camBG:FlxCamera;
    var camGrid:FlxCamera;
    var camUI:FlxCamera;
    var gridFollow:FlxObject;

    public var name:String = "test";
    public var difficulty:String = "normal";
    var chart:Dynamic = null;
    var meta:Dynamic = null;
    var events:Dynamic = null;

    var inst:FunkinSound;
    var voices:FunkinSound;
    var hitsound:FunkinSound;

    var playing:Bool = false;

    var bg:FlxSprite;

    var strumlineGroups:Map<Int, FlxSpriteGroup> = [0 => null];
    var sustainGroups:Map<Int, FlxSpriteGroup> = [0 => null];
    var noteGroups:Map<Int, FlxSpriteGroup> = [0 => null];

    var renderedNotes = [{} => null];

    var conductorLine:FlxSprite;
    var gridBox:FlxSprite;

    var currentCamOffset:FlxPoint;
    var camOffset:FlxPoint;
    
    var allowedXOffset:Int = 0;
    var selectedNotes:Array<Dynamic> = [];
    var selectionBox:FlxSprite;
    var selectionStart:FlxPoint;
    var isSelecting:Bool = false;

    var dragStartPos:FlxPoint;
    var isDraggingNotes:Bool = false;
    var dragStartStrumIndex:Int = -1;
    var dragStartCol:Int = -1;

    var activeDragStepOffset:Float = 0;
    var activeDragColOffset:Int = 0;
    var activeDragStrumOffset:Int = 0;
    
    var clipboardNotes:Array<Dynamic> = [];
    var snapList:Array<Float> = [8.0, 4.0, 2.0, 1.0, 0.5, 0.25, 0.125];
    var snapIndex:Int = 3;
    var curSnap:Float = 1.0;
    var lastPosition:Float = 0;

    var currentNumerator:Int = 4;
    var currentDenominator:Int = 4;
    var cachedGraphics = ["_" => null]; 
    var finalMeasure:Int = 0;

    var canInteractChart:Bool = false;
    var canInteractUI:Bool = true;
    
    var history:Array<Array<Array<Dynamic>>> = [];
    var historyIndex:Int = -1;

    var fileReference:FileReference;
    
    var topBar:Dynamic;
    var exportWindow:Dynamic;
    var welcomeWindow:Dynamic;

    override function create()
    {
        name = PlayState.previousParams.song;
        difficulty = (PlayState.previousParams.difficulty != null) ? PlayState.previousParams.difficulty : "normal";
        
        FlxG.mouse.visible = true;
        
        super.create();

        initCameras();
        initBackground();

        selectionStart = FlxPoint.get();
        dragStartPos = FlxPoint.get();

        currentCamOffset = FlxPoint.get();
        camOffset = FlxPoint.get();

        refreshRegistries();
        refreshSong();
        refreshSounds();
        refreshStrumlines();

        uiCreate();
    }

    function initCameras()
    {
        camBG = new FlxCamera();
        camBG.bgColor = 0x00000000;
        FlxG.cameras.add(camBG, false);

        camGrid = new FlxCamera();
        camGrid.bgColor = 0x00000000;
        FlxG.cameras.add(camGrid, false);
        
        camUI = new FlxCamera();
        camUI.bgColor = 0x00000000;
        FlxG.cameras.add(camUI, false);

        gridFollow = new FlxObject(0, 0, 1, 1);
        gridFollow.camera = camGrid;
        add(gridFollow);
        camGrid.follow(gridFollow);
    }

    function initBackground()
    {
        bg = new FlxSprite().loadGraphic(Paths.image("menus/backgrounds/menuDesat"));
        bg.setGraphicSize(FlxG.width, FlxG.height);
        bg.updateHitbox();
        bg.color = 0xFF3F3F4E;
        bg.camera = camBG;
        add(bg);
    }

    function refreshRegistries()
    {
        chart = null;
        ChartRegistry.reload(name, difficulty);
        chart = ChartRegistry.get(name, difficulty);

        meta = null;
        MetaRegistry.reload(name);
        meta = MetaRegistry.get(name);

        events = null;
        EventRegistry.reload(name);
        events = EventRegistry.get(name);
        
        history = [];
        historyIndex = -1;

        if (chart != null)
        {
            saveAction();
            cleanDuplicateNotes();
        }
    }

    function refreshSong()
    {
        for (song in [inst, voices])
        {
            if (song != null)
            {
                song.stop();
                song.destroy();
            }
        }
        
        inst = FunkinSound.load(Paths.audio('Inst', 'songs/' + name, "ogg", false, false, true), 1.0, false, false, false, false, null, null, true);
        voices = FunkinSound.load(Paths.audio('Voices', 'songs/' + name, "ogg", false, false, true), 1.0, false, false, false, false, null, null, true);

        for (song in [inst, voices])
        {
            if (song != null)
            {
                song.play();
                song.pause();
            }
        }

        Conductor.instance.reset();
        Conductor.instance.setBPM(meta.bpm);

        updateFinalMeasure();
    }

    function refreshSounds()
    {
        hitsound = FunkinSound.load(Paths.sound("menus/charter/hitsound"), 0.6);

        hitsound.play();
        hitsound.pause();
    }

    function updateFinalMeasure()
    {
        if (inst == null) return;
        var lastBoundTime:Float = inst.length;
        var finalTotalSteps:Float = getStepAtTime(lastBoundTime);
        finalMeasure = Math.ceil(finalTotalSteps / 16.0);
        TOTAL_HEIGHT = (finalMeasure * 16.0) * GRID_SIZE;
    }

    function cleanDuplicateNotes()
    {        
        for (i in 0...chart.strumlines.length)
        {
            var entry = chart.strumlines[i];
            var notes:Array<Dynamic> = entry.notes;

            var uniqueNotes:Array<Dynamic> = [];

            var seenKeys = ["" => false];
            seenKeys.clear();
            
            var hasDuplicates = false;

            for (note in notes)
            {
                var key = note.time + "_" + note.direction;
                if (!seenKeys.exists(key))
                {
                    seenKeys.set(key, true);
                    uniqueNotes.push(note);
                }
                else
                    hasDuplicates = true;
            }

            if (hasDuplicates)
                entry.notes = uniqueNotes;
        }
    }

    function refreshStrumlines()
    {
        if (conductorLine != null)
        {
            remove(conductorLine);
            conductorLine.destroy();
        }

        if (gridBox != null)
        {
            remove(gridBox);
            gridBox.destroy();
        }

        if (selectionBox != null)
        {
            remove(selectionBox);
            selectionBox.destroy();
        }

        for (i in strumlineGroups.keys())
        {
            var group = strumlineGroups.get(i);
            if (group != null) { remove(group); group.destroy(); }
            
            var sGroup = sustainGroups.get(i);
            if (sGroup != null) { remove(sGroup); sGroup.destroy(); }
            
            var nGroup = noteGroups.get(i);
            if (nGroup != null) { remove(nGroup); nGroup.destroy(); }
        }

        strumlineGroups.clear();
        sustainGroups.clear();
        noteGroups.clear();

        allowedXOffset = 0;

        var currentX:Float = 0;
        TOTAL_WIDTH = 0;
        
        if (chart == null)
            return;
            
        for (i in 0...chart.strumlines.length)
        {
            var entry = chart.strumlines[i];
            allowedXOffset += Std.int(GRID_SIZE * entry.keys);

            if (entry.keys > 9)
                entry.keys = 9;
            else if (entry.keys < 1)
                entry.keys = 1;
                
            var group:FlxSpriteGroup = new FlxSpriteGroup();
            group.camera = camGrid;
            add(group);

            var sGroup:FlxSpriteGroup = new FlxSpriteGroup();
            sGroup.camera = camGrid;
            add(sGroup);
            
            var nGroup:FlxSpriteGroup = new FlxSpriteGroup();
            nGroup.camera = camGrid;
            add(nGroup);

            var grid = new FlxSprite().loadGraphic(Paths.image('menus/charter/pixel'));
            var gridShader = new FlxRuntimeShader(Paths.frag('engine/grid'));

            grid.setGraphicSize(Std.int((GRID_SIZE * entry.keys) + (GRID_OUTLINE * 2)), Std.int(TOTAL_HEIGHT + (GRID_OUTLINE * 2))); 
            grid.updateHitbox();
            grid.shader = gridShader;
            grid.x = currentX;
            grid.y = 0;
            group.add(grid);

            gridShader.setFloatArray("u_spriteSize", [grid.width, grid.height]);
            gridShader.setFloat("u_gridSize", GRID_SIZE);
            gridShader.setFloat("u_outline", GRID_OUTLINE); 
            gridShader.setBool("u_outlineTop", true);
            gridShader.setBool("u_outlineBottom", true);

            strumlineGroups.set(i, group);
            sustainGroups.set(i, sGroup);
            sGroup.x = currentX;
            
            noteGroups.set(i, nGroup);
            nGroup.x = currentX;
            
            currentX += (GRID_SIZE * entry.keys) + (GRID_OUTLINE * 2) + 50; 
            TOTAL_WIDTH = currentX;
        }

        var lineWidth = Math.max(0, TOTAL_WIDTH - 50);
        
        conductorLine = new FlxSprite().makeGraphic(Std.int(lineWidth), 5, 0xFFDDDDDD);
        conductorLine.camera = camGrid;
        conductorLine.y = GRID_OUTLINE + yFromTime(Conductor.instance.position);
        conductorLine.offset.y = conductorLine.height;
        add(conductorLine);
        
        gridBox = new FlxSprite().makeGraphic(Std.int(GRID_SIZE), Std.int(GRID_SIZE), 0xFFDDDDDD);
        gridBox.setGraphicSize(Std.int(GRID_SIZE), Std.int(GRID_SIZE * curSnap));
        gridBox.updateHitbox();
        gridBox.camera = camGrid;
        add(gridBox);
        
        selectionBox = new FlxSprite().makeGraphic(1, 1, 0x550088FF);
        selectionBox.origin.set(0, 0);
        selectionBox.camera = camGrid;
        selectionBox.visible = false;
        add(selectionBox);

        gridFollow.x = conductorLine.width / 2;
        
        refreshNotes();
    }

    function refreshNotes():Void
    {
        for (i in 0...chart.strumlines.length)
        {
            var nGroup = noteGroups.get(i);
            if (nGroup != null) nGroup.forEachAlive(function(spr:FlxSprite) spr.kill());
            
            var sGroup = sustainGroups.get(i);
            if (sGroup != null) sGroup.forEachAlive(function(spr:FlxSprite) spr.kill());
        }

        if (renderedNotes != null)
            renderedNotes.clear();

        updateFinalMeasure();
        renderVisibleNotes();
    }

    function drawNoteSprite(strumIndex:Int, noteData:Dynamic, time:Float, direction:Int, isSelected:Bool, isGhost:Bool):Array<FlxSprite>
    {
        var sprites:Array<FlxSprite> = [];

        var entry = chart.strumlines[strumIndex];
        var noteTrueEnd = time + (noteData.length > 0 ? noteData.length : 0);

        var noteStartStep = getStepAtTime(time);
        var noteEndStep = getStepAtTime(noteTrueEnd);

        var col = direction;
        var group = noteGroups.get(strumIndex);
        var sGroup = sustainGroups.get(strumIndex);

        var relativeNoteX:Float = GRID_OUTLINE + (col * GRID_SIZE);
        var targetState = isGhost ? 2 : (isSelected ? 1 : 0);
        var targetAlpha = isGhost ? 0.4 : 1.0;
        
        var noteSprite = getRecycled(group);

        noteSprite.loadGraphic(Paths.image('menus/charter/notes/normal/' + col));
        noteSprite.setGraphicSize(Std.int(GRID_SIZE), Std.int(GRID_SIZE));
        noteSprite.updateHitbox();

        noteSprite.x = group.x + relativeNoteX;
        noteSprite.y = group.y + GRID_OUTLINE + yFromTime(time);

        noteSprite.ID = targetState;
        
        if (isSelected)
            noteSprite.setColorTransform(1, 1, 1, targetAlpha, 80, 80, 80, 0);
        else
            noteSprite.setColorTransform(1, 1, 1, targetAlpha, 0, 0, 0, 0);
            
        noteSprite.alpha = targetAlpha;
        noteSprite.color = 0xFFFFFFFF;
        sprites.push(noteSprite);

        if (noteData.length > 0)
        {
            var totalHeight:Float = (noteEndStep - noteStartStep) * GRID_SIZE;
            var endHeight:Float = Math.min(totalHeight, 20.0);
            var bodyHeight:Float = totalHeight - endHeight;
            var sustainWidth:Int = Std.int(GRID_SIZE * 0.35);
            var relativeSustainX:Float = relativeNoteX + (GRID_SIZE - sustainWidth) / 2;
            
            if (bodyHeight > 0)
            {
                var targetW = sustainWidth;
                var targetH = Std.int(bodyHeight + 1.0);

                var bodyClone = getRecycled(sGroup);
                bodyClone.loadGraphic(Paths.image('menus/charter/notes/normal/sustains/' + col + '_tail'));

                bodyClone.setGraphicSize(targetW, targetH);
                bodyClone.updateHitbox();
                
                bodyClone.x = sGroup.x + relativeSustainX;
                bodyClone.y = sGroup.y + noteSprite.y + (GRID_SIZE / 2); 
                bodyClone.ID = 1;
                
                clearClipRect(bodyClone);
                
                if (isSelected)
                    bodyClone.setColorTransform(0.6, 0.6, 0.6, targetAlpha, 80, 80, 80, 80);
                else
                    bodyClone.setColorTransform(0.6, 0.6, 0.6, targetAlpha, 0, 0, 0, 0);
                    
                bodyClone.alpha = targetAlpha;
                bodyClone.color = 0xFF999999;
                sprites.push(bodyClone);

                var body = getRecycled(sGroup);
                body.loadGraphic(Paths.image('menus/charter/notes/normal/sustains/' + col + '_tail'));

                body.setGraphicSize(targetW, targetH);
                body.updateHitbox();
                
                body.x = sGroup.x + relativeSustainX;
                body.y = sGroup.y + noteSprite.y + (GRID_SIZE / 2);
                
                clearClipRect(body);

                body.ID = targetState;
                
                if (isSelected)
                    body.setColorTransform(1, 1, 1, targetAlpha, 80, 80, 80, 0);
                else
                    body.setColorTransform(1, 1, 1, targetAlpha, 0, 0, 0, 0);
                    
                body.alpha = targetAlpha;
                body.color = 0xFFFFFFFF;
                sprites.push(body);
            }

            var tailTargetH = Std.int(endHeight);
            
            var tailClone = getRecycled(sGroup);
            tailClone.loadGraphic(Paths.image('menus/charter/notes/normal/sustains/' + col + '_end'));

            tailClone.setGraphicSize(sustainWidth, tailTargetH);
            tailClone.updateHitbox();

            tailClone.x = sGroup.x + relativeSustainX;
            tailClone.y = sGroup.y + noteSprite.y + (GRID_SIZE / 2) + bodyHeight;
            tailClone.ID = 1;

            clearClipRect(tailClone);
            
            if (isSelected)
                tailClone.setColorTransform(0.6, 0.6, 0.6, targetAlpha, 60, 60, 60, 0);
            else
                tailClone.setColorTransform(0.6, 0.6, 0.6, targetAlpha, 0, 0, 0, 0);
                
            tailClone.alpha = targetAlpha;
            tailClone.color = 0xFF999999;
            sprites.push(tailClone);
            
            var tail = getRecycled(sGroup);
            tail.loadGraphic(Paths.image('menus/charter/notes/normal/sustains/' + col + '_end'));

            tail.setGraphicSize(sustainWidth, tailTargetH);
            tail.updateHitbox();
            
            tail.x = sGroup.x + relativeSustainX;
            tail.y = sGroup.y + noteSprite.y + (GRID_SIZE / 2) + bodyHeight;
            clearClipRect(tail);

            tail.ID = targetState;
            
            if (isSelected)
                tail.setColorTransform(1, 1, 1, targetAlpha, 80, 80, 80, 0);
            else
                tail.setColorTransform(1, 1, 1, targetAlpha, 0, 0, 0, 0);
                
            tail.alpha = targetAlpha;
            tail.color = 0xFFFFFFFF;
            sprites.push(tail);
        }

        return sprites;
    }

    function clearClipRect(spr:FlxSprite)
    {
        if (spr.clipRect != null)
        {
            spr.clipRect.put();
            spr.clipRect = null;
        }
    }

    function getRecycled(group:FlxSpriteGroup):FlxSprite
    {
        var spr:FlxSprite = group.getFirstDead();
        
        if (spr == null)
        {
            spr = new FlxSprite();
            group.add(spr);
        }
        else
        {
            spr.revive();
        }
            
        return spr;
    }

    function renderVisibleNotes()
    {
        if (chart == null) return;

        var viewMinY = camGrid.scroll.y;
        var viewMaxY = camGrid.scroll.y + FlxG.height;
        
        var minTime = timeFromY(viewMinY - GRID_OUTLINE - (GRID_SIZE * 4));
        var maxTime = timeFromY(viewMaxY - GRID_OUTLINE + (GRID_SIZE * 4));

        var currentlyVisibleNotes = [[] => false];
        currentlyVisibleNotes.clear();

        var searchMin = minTime;
        var searchMax = maxTime;

        if (isDraggingNotes)
        {
            var dragTimeOffset = activeDragStepOffset * Conductor.instance.stepLengthMs;
            if (dragTimeOffset > 0)
                searchMin -= dragTimeOffset;
            else
                searchMax -= dragTimeOffset;
        }

        for (i in 0...chart.strumlines.length)
        {
            var entry = chart.strumlines[i];

            var l = 0;
            var r = entry.notes.length - 1;

            while (l <= r)
            {
                var m = Math.floor((l + r) / 2);
                var note = entry.notes[m];
                var noteEnd = note.time + (note.length > 0 ? note.length : 0);

                if (noteEnd < searchMin)
                    l = m + 1;
                else
                    r = m - 1;
            }

            var startIndex = (l < 0) ? 0 : l;

            for (j in startIndex...entry.notes.length)
            {
                var noteData = entry.notes[j];
                var noteStart = noteData.time;
                var noteEnd = noteData.time + (noteData.length > 0 ? noteData.length : 0);

                if (noteStart > searchMax)
                    break;

                var isPotentiallyVisible = (noteEnd >= minTime && noteStart <= maxTime);
                var isSelected = false;

                if (!isPotentiallyVisible)
                {
                    if (!isDraggingNotes)
                    {
                        continue;
                    }
                    else
                    {
                        isSelected = (selectedNotes.indexOf(noteData) != -1);
                        if (!isSelected)
                            continue;
                    }
                }
                else
                {
                    isSelected = (selectedNotes.indexOf(noteData) != -1);
                }

                var drawOrig = false;
                var drawDrag = false;
                
                var newTime = noteStart;
                var newEnd = noteEnd;
                var newStrumIndex = i;
                var newLocalDir = noteData.direction;

                if (isDraggingNotes && isSelected)
                {
                    newStrumIndex = i + activeDragStrumOffset;

                    if (newStrumIndex < 0) newStrumIndex = 0;
                    if (newStrumIndex >= chart.strumlines.length) newStrumIndex = chart.strumlines.length - 1;
                    
                    var newStrum = chart.strumlines[newStrumIndex];

                    newLocalDir = noteData.direction + activeDragColOffset;
                    
                    if (newLocalDir < 0) newLocalDir = 0;
                    if (newLocalDir >= newStrum.keys) newLocalDir = newStrum.keys - 1;
                    
                    newTime = noteData.time + (activeDragStepOffset * Conductor.instance.stepLengthMs);
                    newEnd = newTime + (noteData.length > 0 ? noteData.length : 0);

                    if (noteEnd >= minTime && noteStart <= maxTime) drawOrig = true;
                    if (newEnd >= minTime && newTime <= maxTime) drawDrag = true;
                }
                else
                {
                    if (noteEnd >= minTime && noteStart <= maxTime) drawOrig = true;
                }

                if (drawOrig || drawDrag)
                {
                    currentlyVisibleNotes.set(noteData, true);

                    if (!renderedNotes.exists(noteData))
                    {
                        var sprites:Array<FlxSprite> = [];

                        if (!isDraggingNotes || !isSelected) 
                        {
                            sprites = sprites.concat(drawNoteSprite(i, noteData, noteData.time, noteData.direction, isSelected, false));
                        }
                        else 
                        {
                            if (drawOrig) sprites = sprites.concat(drawNoteSprite(i, noteData, noteData.time, noteData.direction, false, true));
                            if (drawDrag) sprites = sprites.concat(drawNoteSprite(newStrumIndex, noteData, newTime, newLocalDir, true, false));
                        }
                        
                        renderedNotes.set(noteData, sprites);
                    }
                }
            }
        }

        var keysToRemove = [];

        for (noteData in renderedNotes.keys())
        {
            if (!currentlyVisibleNotes.exists(noteData))
            {
                var sprites = renderedNotes.get(noteData);

                if (sprites != null)
                {
                    for (spr in sprites)
                        spr.kill();
                }

                keysToRemove.push(noteData);
            }
        }
        
        for (key in keysToRemove) renderedNotes.remove(key);
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        updateInputs(elapsed);
        
        if (playing)
            Conductor.instance.update(Conductor.instance.position + elapsed * 1000);

        checkHitsounds();

        renderVisibleNotes();

        updateSong(elapsed);
        updateSprites(elapsed);

        updateGridBox();
        updateNoteVisuals();

        lastPosition = Conductor.instance.position;
    }

    function checkHitsounds()
    {
        if (chart == null || Math.abs(Conductor.instance.position - lastPosition) > 100 || !playing) return;
        
        for (i in 0...chart.strumlines.length)
        {
            var strum = chart.strumlines[i];
            var notes:Array<Dynamic> = strum.notes;

            var l = 0;
            var r = notes.length - 1;
            var targetTime = lastPosition - 100.0;
            
            while (l <= r)
            {
                var m = Math.floor((l + r) / 2);
                
                if (notes[m].time < targetTime)
                    l = m + 1;
                else r = m - 1;
            }

            if (l < 0)
                l = 0;
                
            for (j in l...notes.length)
            {
                var note = notes[j];
                
                if (note.time > Conductor.instance.position) break;
                
                if (note.time <= Conductor.instance.position && note.time > lastPosition)
                {
                    hitsound.time = 0;
                    hitsound.play(true);
                }
            }
        }
    }

    function updateNoteVisuals()
    {
        var lineY = conductorLine.y;
        var centerOffset = GRID_SIZE / 2;

        for (i in 0...chart.strumlines.length)
        {
            var nGroup = noteGroups.get(i);
            
            if (nGroup != null)
            {
                nGroup.forEachAlive(function(note:FlxSprite)
                {
                    if (note.y + centerOffset < lineY)
                        note.color = 0xFF999999;
                    else
                        note.color = 0xFFFFFFFF;
                });
            }

            var sGroup = sustainGroups.get(i);
            
            if (sGroup != null)
            {
                sGroup.forEachAlive(function(sus:FlxSprite)
                {
                    if (sus.ID == 1) return;
                    if (sus.height <= 0) return;
     
                    if (sus.y + sus.height < lineY)
                        sus.visible = false;
                    else if (sus.y < lineY)
                    {
                        sus.visible = true;
                        var percentPassed = (lineY - sus.y) / sus.height;
                        
                        var frameW = sus.frameWidth;
                        var frameH = sus.frameHeight;
                        var clipY = percentPassed * frameH;
                        
                        if (sus.clipRect == null) sus.clipRect = FlxRect.get();
                        sus.clipRect.set(0, clipY, frameW, frameH - clipY);
                        sus.clipRect = sus.clipRect; 
                    }
                    else
                    {
                        sus.visible = true;
                        clearClipRect(sus);
                    }
                });
            }
        }
    }

    function updateSong(elapsed:Float)
    {
        if (inst != null && inst.length > 0)
        {
            if (Conductor.instance.position >= (inst.length - 5.0))
            {
                if (playing)
                {
                    playing = false;
                    inst.pause();
                    
                    Conductor.instance.position = inst.length; 
                    Conductor.instance.update(Conductor.instance.position);
                }
            }
        }

        var targetY:Float = GRID_OUTLINE + yFromTime(Conductor.instance.position);
        
        if (playing)
            conductorLine.y = targetY;
        else
            conductorLine.y = MathUtil.smoothLerpPrecision(conductorLine.y, targetY, elapsed, 0.25);
    }

    function updateSprites(elapsed:Float)
    {
        gridFollow.x = currentCamOffset.x + MathUtil.smoothLerpPrecision(gridFollow.x, conductorLine.x + (conductorLine.width / 2) + camOffset.x, elapsed, 0.4);
        gridFollow.y = conductorLine.y + currentCamOffset.y;

        currentCamOffset.y = MathUtil.smoothLerpPrecision(currentCamOffset.y, camOffset.y, elapsed, 0.4);
    }

    function updateGridBox()
    {
        if (gridBox == null || chart == null || !canInteractChart) return;
        
        var mousePos = FlxG.mouse.getWorldPosition(camGrid);
        var snappedY = mousePos.y;

        if (!FlxG.keys.pressed.SHIFT)
            snappedY = GRID_OUTLINE + (Math.floor((mousePos.y - GRID_OUTLINE) / (GRID_SIZE * curSnap)) * (GRID_SIZE * curSnap));
            
        var currentX:Float = 0;
        var isHoveringValidGrid = false;

        var minPlayableY:Float = GRID_OUTLINE;
        var maxPlayableY:Float = GRID_OUTLINE + TOTAL_HEIGHT - GRID_SIZE;
        
        if (snappedY >= minPlayableY && snappedY <= maxPlayableY)
        {
            for (i in 0...chart.strumlines.length)
            {
                var entry = chart.strumlines[i];
                var strumWidth = (GRID_SIZE * entry.keys) + (GRID_OUTLINE * 2);
                
                if (mousePos.x >= currentX && mousePos.x <= currentX + strumWidth)
                {
                    var localX = mousePos.x - currentX - GRID_OUTLINE;
                    
                    if (localX < 0)
                        localX = 0;
                        
                    var col = Math.floor(localX / GRID_SIZE);

                    if (col >= entry.keys)
                        col = entry.keys - 1;
                        
                    gridBox.x = currentX + GRID_OUTLINE + (col * GRID_SIZE);
                    gridBox.y = snappedY;
                    isHoveringValidGrid = true;
                    
                    break;
                }
                currentX += strumWidth + 50;
            }
        }

        gridBox.visible = isHoveringValidGrid && !isSelecting && !isDraggingNotes && !playing;
        gridBox.alpha = 0.5;

        mousePos.put();
    }

    function updateInputs(elapsed:Float)
    {
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S)
            saveChart();
            
        if (!canInteractChart)
            return;
            
        if (FlxG.keys.pressed.CONTROL && !isDraggingNotes)
        {
            if (FlxG.keys.justPressed.Z)
                undoAction();
            else if (FlxG.keys.justPressed.X)
                redoAction();
        }

        var scrolling = FlxG.mouse.wheel != 0;
        var pressed = controls.UI_UP.justPressed || controls.UI_DOWN.justPressed;
        
        if (FlxG.keys.justPressed.SPACE && !pressed && !scrolling)
            toggleSong();
            
        if (scrolling)
            skimSong(FlxG.mouse.wheel > 0 ? -1 : 1);
            
        if (pressed)
            skimSong(controls.UI_UP.justPressed ? -1 : 1);
            
        if (scrolling && (FlxG.keys.pressed.TAB || FlxG.keys.pressed.ALT))
            skimCamera(FlxG.mouse.wheel > 0 ? -1 : 1);

        if (FlxG.keys.justPressed.ESCAPE)
            exitMenu();
            
        if (FlxG.keys.justPressed.Z || FlxG.keys.justPressed.X)
        {
            if (FlxG.keys.pressed.CONTROL)
                return;
                
            if (FlxG.keys.justPressed.Z)
                snapIndex++;
            else
                snapIndex--;
                
            if (snapIndex < 0)
                snapIndex = 0;
                
            if (snapIndex >= snapList.length)
                snapIndex = snapList.length - 1;
                
            curSnap = snapList[snapIndex];
        }

        handleMouseLogic();
        
        if (FlxG.keys.justPressed.Q)
            handleSustainModify(-1);
        else if (FlxG.keys.justPressed.E)
            handleSustainModify(1);
            
        if (FlxG.keys.justPressed.DELETE)
        {
            if (selectedNotes.length > 0)
            {
                for (note in selectedNotes)
                {
                    for (strum in chart.strumlines)
                        strum.notes.remove(note);
                }
                saveAction();

                FunkinSound.playOnce(Paths.sound('menus/charter/notes/trash'), 0.15);
                selectedNotes = [];
                refreshNotes();
            }
        }

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.A)
        {
            if (chart != null)
            {
                var mousePos = FlxG.mouse.getWorldPosition(camGrid);
                var currentX:Float = 0;
                var hoveredStrum:Dynamic = null;

                for (i in 0...chart.strumlines.length)
                {
                    var entry = chart.strumlines[i];
                    var strumWidth = (GRID_SIZE * entry.keys) + (GRID_OUTLINE * 2);
                    
                    if (mousePos.x >= currentX && mousePos.x <= currentX + strumWidth)
                    {
                        hoveredStrum = entry;
                        break;
                    }

                    currentX += strumWidth + 50;
                }

                if (hoveredStrum != null)
                {
                    var added = false;
                    
                    for (note in hoveredStrum.notes)
                    {
                        if (selectedNotes.indexOf(note) == -1)
                        {
                            selectedNotes.push(note);
                            added = true;
                        }
                    }

                    if (added)
                        refreshNotes();
                }
                mousePos.put();
            }
        }

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.C)
        {
            clipboardNotes = [];
            
            for (note in selectedNotes) {
                var strumIdx = 0;
                
                for (i in 0...chart.strumlines.length) {
                    if (chart.strumlines[i].notes.indexOf(note) != -1) { strumIdx = i; break; }
                }
                clipboardNotes.push({time: note.time, direction: note.direction, length: note.length, strumline: strumIdx});
            }
        }

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.V)
        {
            if (clipboardNotes.length > 0)
            {
                selectedNotes = [];
                var newClipboard = [];

                for (clipNote in clipboardNotes)
                {
                    var newTime = clipNote.time + Conductor.instance.stepLengthMs;
                    var newNote = {time: newTime, direction: clipNote.direction, length: clipNote.length};

                    var strumIndex = clipNote.strumline;
                    
                    if (strumIndex < chart.strumlines.length)
                    {
                        chart.strumlines[strumIndex].notes.push(newNote);
                        selectedNotes.push(newNote);

                        newClipboard.push({time: newTime, direction: clipNote.direction, length: clipNote.length, strumline: strumIndex});
                    }
                }

                clipboardNotes = newClipboard;
                
                for (strum in chart.strumlines)
                {
                    strum.notes.sort(function(a:Dynamic, b:Dynamic):Int
                    {
                        if (a.time < b.time) return -1;
                        if (a.time > b.time) return 1;
                        return 0;
                    });
                }

                saveAction();
                refreshNotes();
            }
        }
    }

    function handleMouseLogic()
    {
        if (chart == null || playing) return;
        
        var mousePos = FlxG.mouse.getWorldPosition(camGrid);

        if (FlxG.mouse.justPressedRight)
        {
            var clickedNote:Dynamic = null;
            var clickedStrumline:Dynamic = null;
            var clickedIndex:Int = -1;
            var currentX:Float = 0;
            
            for (i in 0...chart.strumlines.length)
            {
                var entry = chart.strumlines[i];
                var strumWidth = (GRID_SIZE * entry.keys) + (GRID_OUTLINE * 2);
                
                for (j in 0...entry.notes.length)
                {
                    var note = entry.notes[j];
                    var noteDir = note.direction;

                    if (mousePos.x >= currentX && mousePos.x <= currentX + strumWidth)
                    {
                        var noteX = currentX + GRID_OUTLINE + (noteDir * GRID_SIZE);
                        var noteY = GRID_OUTLINE + yFromTime(note.time);
                        var noteH = (note.length > 0) ? (note.length / Conductor.instance.stepLengthMs) * GRID_SIZE : GRID_SIZE;
                        var noteRect = FlxRect.get(noteX, noteY, GRID_SIZE, noteH);
                        
                        if (noteRect.containsPoint(mousePos))
                        {
                            clickedNote = note;
                            clickedStrumline = entry;
                            clickedIndex = j;

                            noteRect.put();
                            break;
                        }
                        noteRect.put();
                    }
                }

                if (clickedNote != null)
                    break;
                    
                currentX += strumWidth + 50;
            }

            if (clickedNote != null && clickedStrumline != null)
            {
                clickedStrumline.notes.splice(clickedIndex, 1);
                selectedNotes.remove(clickedNote);

                saveAction();

                FunkinSound.playOnce(Paths.sound('menus/charter/notes/delete'), 0.1);
                refreshNotes();
            }
        }

        if (FlxG.mouse.justPressed)
        {
            var clickedNote = null;
            var currentX:Float = 0;

            for (i in 0...chart.strumlines.length)
            {
                var entry = chart.strumlines[i];
                var strumWidth = (GRID_SIZE * entry.keys) + (GRID_OUTLINE * 2);
                
                for (note in entry.notes)
                {
                    var noteDir = note.direction;
                    
                    if (mousePos.x >= currentX && mousePos.x <= currentX + strumWidth)
                    {
                        var noteX = currentX + GRID_OUTLINE + (noteDir * GRID_SIZE);
                        var noteY = GRID_OUTLINE + yFromTime(note.time);
                        var noteH = (note.length > 0) ? (note.length / Conductor.instance.stepLengthMs) * GRID_SIZE : GRID_SIZE;
                        var noteRect = FlxRect.get(noteX, noteY, GRID_SIZE, noteH);
                        
                        if (noteRect.containsPoint(mousePos))
                        {
                            clickedNote = note;
                            noteRect.put();
                            break;
                        }

                        noteRect.put();
                    }
                }

                if (clickedNote != null)
                {
                    dragStartStrumIndex = i;
                    var localX = mousePos.x - currentX - GRID_OUTLINE;

                    if (localX < 0)
                        localX = 0;
                        
                    dragStartCol = Math.floor(localX / GRID_SIZE);

                    if (dragStartCol >= entry.keys)
                        dragStartCol = entry.keys - 1;
                        
                    break;
                }
                currentX += strumWidth + 50;
            }

            if (clickedNote != null)
            {
                if (selectedNotes.indexOf(clickedNote) == -1)
                {
                    if (!FlxG.keys.pressed.SHIFT)
                        selectedNotes = [];

                    selectedNotes.push(clickedNote);
                    refreshNotes();
                }

                isDraggingNotes = true;
                dragStartPos.set(mousePos.x, mousePos.y);
            }
            else 
            {
                selectionStart.set(mousePos.x, mousePos.y);
                isSelecting = true;
                selectionBox.visible = true;

                selectionBox.x = mousePos.x;
                selectionBox.y = mousePos.y;

                selectionBox.scale.set(1, 1);
            }
        }

        if (isDraggingNotes && FlxG.mouse.justPressed)
            FunkinSound.playOnce(Paths.sound('menus/charter/notes/grab'), 0.15);
            
        if (isDraggingNotes && FlxG.mouse.pressed)
        {
            var hoveredStrumIndex = dragStartStrumIndex;
            var hoveredCol = dragStartCol;
            
            var currentX:Float = 0;
            var closestDist:Float = 999999.0;
            
            for (i in 0...chart.strumlines.length) 
            {
                var strumWidth = (GRID_SIZE * chart.strumlines[i].keys) + (GRID_OUTLINE * 2);
                
                if (mousePos.x >= currentX && mousePos.x <= currentX + strumWidth) 
                {
                    hoveredStrumIndex = i;
                    var localX = mousePos.x - currentX - GRID_OUTLINE;

                    if (localX < 0)
                        localX = 0;
                        
                    hoveredCol = Math.floor(localX / GRID_SIZE);

                    if (hoveredCol >= chart.strumlines[i].keys)
                        hoveredCol = chart.strumlines[i].keys - 1;
                        
                    closestDist = 0;
                    break;
                }
                else if (mousePos.x < currentX)
                {
                    var dist = currentX - mousePos.x;
                    
                    if (dist < closestDist)
                    {
                        closestDist = dist;
                        hoveredStrumIndex = i;
                        hoveredCol = 0;
                    }
                }
                else if (mousePos.x > currentX + strumWidth)
                {
                    var dist = mousePos.x - (currentX + strumWidth);
                    
                    if (dist < closestDist)
                    {
                        closestDist = dist;
                        hoveredStrumIndex = i;
                        hoveredCol = chart.strumlines[i].keys - 1;
                    }
                }

                currentX += strumWidth + 50;
            }
            
            var strumOffset = hoveredStrumIndex - dragStartStrumIndex;
            var colOffset = hoveredCol - dragStartCol;
            var stepOffset:Float = (mousePos.y - dragStartPos.y) / GRID_SIZE;
            
            if (!FlxG.keys.pressed.SHIFT)
                stepOffset = Math.round(stepOffset / curSnap) * curSnap;
                
            var minAllowedStepOffset:Float = -999999.0;
            for (note in selectedNotes)
            {
                var neededToZero = -(note.time / Conductor.instance.stepLengthMs);
                if (neededToZero > minAllowedStepOffset)
                    minAllowedStepOffset = neededToZero;
            }

            if (stepOffset < minAllowedStepOffset)
            {
                stepOffset = minAllowedStepOffset;
                if (!FlxG.keys.pressed.SHIFT)
                    stepOffset = Math.ceil(stepOffset / curSnap) * curSnap;
            }
                
            if (activeDragStepOffset != stepOffset || activeDragColOffset != colOffset || activeDragStrumOffset != strumOffset) 
            {
                activeDragStepOffset = stepOffset;
                activeDragColOffset = colOffset;
                activeDragStrumOffset = strumOffset;

                refreshNotes(); 
            }
        }

        if (isDraggingNotes && FlxG.mouse.justReleased)
        {
            FunkinSound.playOnce(Paths.sound('menus/charter/notes/release'), 0.15);
            
            if (activeDragStepOffset != 0 || activeDragColOffset != 0 || activeDragStrumOffset != 0)
            {
                for (note in selectedNotes)
                {
                    var currentStrumIndex = -1;
                    
                    for (i in 0...chart.strumlines.length)
                    {
                        if (chart.strumlines[i].notes.indexOf(note) != -1)
                        {
                            currentStrumIndex = i;
                            break;
                        }
                    }

                    var currentStrum = chart.strumlines[currentStrumIndex];
                    var localDir = note.direction;
                    
                    var newStrumIndex = currentStrumIndex + activeDragStrumOffset;
                    if (newStrumIndex < 0)
                        newStrumIndex = 0;
                    if (newStrumIndex >= chart.strumlines.length)
                        newStrumIndex = chart.strumlines.length - 1;
                        
                    var newStrum = chart.strumlines[newStrumIndex];
                    var newLocalDir = localDir + activeDragColOffset;
                    
                    if (newLocalDir < 0)
                        newLocalDir = 0;
                    if (newLocalDir >= newStrum.keys)
                        newLocalDir = newStrum.keys - 1;
                        
                    currentStrum.notes.remove(note);
                    note.time += (activeDragStepOffset * Conductor.instance.stepLengthMs);
                    note.direction = newLocalDir;

                    newStrum.notes.push(note);
                }
                
                for (strum in chart.strumlines)
                {
                    strum.notes.sort(function(a:Dynamic, b:Dynamic):Int
                    {
                        if (a.time < b.time) return -1;
                        if (a.time > b.time) return 1;
                        return 0;
                    });
                }

                saveAction();
            }

            isDraggingNotes = false;
            activeDragStepOffset = 0;
            activeDragColOffset = 0;
            activeDragStrumOffset = 0;

            refreshNotes();
            cleanDuplicateNotes();
        }

        if (isSelecting && FlxG.mouse.pressed)
        {
            var rectX = Math.min(selectionStart.x, mousePos.x);
            var rectY = Math.min(selectionStart.y, mousePos.y);
            var rectW = Math.max(1, Math.abs(mousePos.x - selectionStart.x));
            var rectH = Math.max(1, Math.abs(mousePos.y - selectionStart.y));
            
            selectionBox.x = rectX;
            selectionBox.y = rectY;
            selectionBox.scale.set(rectW, rectH);
        }

        if (isSelecting && FlxG.mouse.justReleased)
        {
            isSelecting = false;
            selectionBox.visible = false;

            var dist = Math.abs(mousePos.x - selectionStart.x) + Math.abs(mousePos.y - selectionStart.y);
            
            if (dist < 10)
                handleGridClick(mousePos);
            else
                handleSelectionBox();
        }
        
        mousePos.put();
    }

    function handleSelectionBox()
    {
        if (!FlxG.keys.pressed.SHIFT)
            selectedNotes = [];
            
        var selRect = FlxRect.get(selectionBox.x, selectionBox.y, selectionBox.scale.x, selectionBox.scale.y);
        var currentX:Float = 0;
        
        for (i in 0...chart.strumlines.length)
        {
            var entry = chart.strumlines[i];
            var strumWidth = (GRID_SIZE * entry.keys) + (GRID_OUTLINE * 2);
            
            for (noteData in entry.notes)
            {
                var col:Int = noteData.direction;
                var noteX:Float = currentX + GRID_OUTLINE + (col * GRID_SIZE);
                var noteY:Float = GRID_OUTLINE + yFromTime(noteData.time);

                var noteH = GRID_SIZE;
                if (noteData.length > 0)
                    noteH += (noteData.length / Conductor.instance.stepLengthMs) * GRID_SIZE;
                    
                var rectSize = GRID_SIZE / 4;
                var offset = (GRID_SIZE - rectSize) / 2;
                var noteRect = FlxRect.get(noteX + offset, noteY + offset, rectSize, rectSize);
                
                if (selRect.overlaps(noteRect))
                {
                    if (selectedNotes.indexOf(noteData) == -1)
                        selectedNotes.push(noteData);
                }
                noteRect.put();
            }
            currentX += strumWidth + 50;
        }

        selRect.put();
        refreshNotes();
    }

    function handleSustainModify(dir:Int)
    {
        if (selectedNotes.length > 0)
        {
            var change = Conductor.instance.stepLengthMs;
            
            if (FlxG.keys.pressed.SHIFT)
                change /= 2.0;
                
            for (note in selectedNotes)
            {
                note.length += change * dir;
                
                if (note.length < 0)
                    note.length = 0;
            }

            saveAction();
            
            if (dir == 1)
                FunkinSound.playOnce(Paths.sound('menus/charter/notes/inflate'), 0.15);
            else
                FunkinSound.playOnce(Paths.sound('menus/charter/notes/deflate'), 0.15);

            refreshNotes();
        }
    }

    function handleGridClick(mousePos:FlxPoint)
    {
        if (chart == null) return;
        
        var snappedY = mousePos.y;

        if (!FlxG.keys.pressed.SHIFT)
            snappedY = GRID_OUTLINE + (Math.floor((mousePos.y - GRID_OUTLINE) / (GRID_SIZE * curSnap)) * (GRID_SIZE * curSnap));
            
        var minPlayableY:Float = GRID_OUTLINE;
        var maxPlayableY:Float = GRID_OUTLINE + TOTAL_HEIGHT - GRID_SIZE;

        var outOfBounds = false;
        if (snappedY < minPlayableY || snappedY > maxPlayableY)
            outOfBounds = true;
            
        var currentX:Float = 0;

        var clickedCol = -1;
        var clickedStrumline:Dynamic = null;
        var clickedStrumlineIndex:Int = -1;
        
        for (i in 0...chart.strumlines.length)
        {
            var entry = chart.strumlines[i];
            var strumWidth = (GRID_SIZE * entry.keys) + (GRID_OUTLINE * 2);
            
            if (mousePos.x >= currentX && mousePos.x <= currentX + strumWidth)
            {
                var localX = mousePos.x - currentX - GRID_OUTLINE;
                if (localX < 0) localX = 0;

                clickedCol = Math.floor(localX / GRID_SIZE);
                if (clickedCol >= entry.keys) clickedCol = entry.keys - 1;

                clickedStrumline = entry;
                clickedStrumlineIndex = i;
                break;
            }

            currentX += strumWidth + 50;
        }

        if (clickedStrumline == null || clickedCol == -1)
            outOfBounds = true;
            
        if (outOfBounds)
        {
            if (selectedNotes.length > 0)
            {
                selectedNotes = [];
                refreshNotes();
            }

            return;
        }

        var targetTime = timeFromY(snappedY - GRID_OUTLINE);
        var clickedStep = getStepAtTime(targetTime);
        var closestNote:Dynamic = null;
        var closestIndex:Int = -1;
        var closestDist:Float = 999999.0;
        
        for (i in 0...clickedStrumline.notes.length)
        {
            var noteData = clickedStrumline.notes[i];
            var noteDir = noteData.direction;
            
            if (noteDir == clickedCol)
            {
                var noteStep = getStepAtTime(noteData.time);
                var dist = Math.abs(noteStep - clickedStep);

                if (dist < closestDist && dist <= 0.5)
                {
                    closestDist = dist;
                    closestNote = noteData;
                    closestIndex = i;
                }
            }
        }

        var newNote = {time: targetTime, direction: clickedCol, length: 0.0};
        clickedStrumline.notes.push(newNote);

        FunkinSound.playOnce(Paths.sound('menus/charter/notes/place'), 0.1);
        
        if (!FlxG.keys.pressed.SHIFT)
            selectedNotes = [];

        selectedNotes.push(newNote);
        
        clickedStrumline.notes.sort(function(a:Dynamic, b:Dynamic):Int
        {
            if (a.time < b.time) return -1;
            if (a.time > b.time) return 1;
            return 0;
        });
        
        saveAction();
        refreshNotes();
        cleanDuplicateNotes();
    }

    function cloneChartNotes():Array<Array<Dynamic>>
    {
        var state:Array<Array<Dynamic>> = [];
        for (strum in chart.strumlines)
        {
            var strumNotes:Array<Dynamic> = [];
            for (note in strum.notes)
            {
                strumNotes.push({time: note.time, direction: note.direction, length: note.length});
            }
            state.push(strumNotes);
        }
        return state;
    }

    function restoreChartNotes(state:Array<Array<Dynamic>>)
    {
        selectedNotes = [];
        for (i in 0...chart.strumlines.length)
        {
            var strumNotes:Array<Dynamic> = [];
            for (note in state[i])
            {
                strumNotes.push({time: note.time, direction: note.direction, length: note.length});
            }
            chart.strumlines[i].notes = strumNotes;
        }
        refreshNotes();
    }

    function saveAction()
    {
        if (historyIndex < history.length - 1)
            history.splice(historyIndex + 1, history.length - historyIndex - 1);
            
        history.push(cloneChartNotes());

        if (history.length > 50)
            history.shift();
        else
            historyIndex++;
    }

    function undoAction()
    {
        if (historyIndex > 0)
        {
            FunkinSound.playOnce(Paths.sound('menus/charter/notes/action'), 0.2);
            historyIndex--;
            restoreChartNotes(history[historyIndex]);
        }
    }

    function redoAction()
    {
        if (historyIndex < history.length - 1)
        {
            FunkinSound.playOnce(Paths.sound('menus/charter/notes/action'), 0.2);
            historyIndex++;
            restoreChartNotes(history[historyIndex]);
        }
    }

    function toggleSong()
    {
        playing = !playing;
        
        if (Conductor.instance.position >= inst.length)
        {
            for (song in [inst, voices])
                song.time = 0;
                
            Conductor.instance.position = 0; 
            Conductor.instance.update(Conductor.instance.position);
        }

        if (playing)
        {
            for (song in [inst, voices])
                song.play();
        }
        else
        {
            for (song in [inst, voices])
                song.pause();
        }
    }

    function skimSong(dir:Int)
    {
        if (FlxG.keys.pressed.TAB || FlxG.keys.pressed.CONTROL || FlxG.keys.pressed.ALT)
            return;
            
        if (playing)
            toggleSong();
            
        var value = Conductor.instance.stepLengthMs * (FlxG.keys.pressed.SHIFT ? 2 : 1);

        Conductor.instance.position += value * dir;
        
        if (Conductor.instance.position < 0)
            Conductor.instance.position = 0;
            
        if (Conductor.instance.position > inst.length)
            Conductor.instance.position = inst.length;
            
        if (Conductor.instance.position >= 0 && Conductor.instance.position <= inst.length)
        {
            for (song in [inst, voices])
                song.time = Conductor.instance.position;
        }

        Conductor.instance.update(Conductor.instance.position);
    }

    function skimCamera(dir:Int)
    {
        if (FlxG.keys.pressed.ALT)
        {
            var val = camOffset.x + (40 * dir);
            camOffset.x = FlxMath.bound(val, -allowedXOffset, allowedXOffset);
        }
        else if (FlxG.keys.pressed.TAB)
        {
            var val = camOffset.y + (40 * dir);
            camOffset.y = FlxMath.bound(val, -280, 280);
        }
    }

    function yFromTime(time:Float):Float
    {
        return getStepAtTime(time) * GRID_SIZE;
    }

    function getStepAtTime(time:Float):Float
    {
        return Conductor.instance.lastChangeStep + ((time - Conductor.instance.lastChangeTime) / Conductor.instance.stepLengthMs);
    }

    function timeFromY(localY:Float):Float
    {
        var step = localY / GRID_SIZE;
        return Conductor.instance.lastChangeTime + ((step - Conductor.instance.lastChangeStep) * Conductor.instance.stepLengthMs);
    }

    function getTimeFromStep(step:Float):Float
    {
        return step * ((60.0 / Conductor.instance.bpm) * 250.0);
    }

    override function stepHit(step:Float)
    {
        super.stepHit(step);
        
        if (!playing)
            return;
            
        if (inst != null)
        {
            if (Math.abs(inst.time - Conductor.instance.position) > Constants.RESYNC_THRESHOLD)
                Conductor.instance.position = inst.time;
        }

        if (voices != null)
        {
            if (Math.abs(voices.time - Conductor.instance.position) > Constants.RESYNC_THRESHOLD)
                voices.time = Conductor.instance.position;
        }
    }

    /**
     * Chart Helper Functions
     */
    public function saveChart()
    {
        if (chart == null)
            return;
            
        var data = Converter.writeChart(name, chart);

        Paths.createDirectory('assets/data/songs/$name');
        File.saveContent('assets/data/songs/$name/$name-chart-$difficulty.json', data);

        FunkinSound.playOnce(Paths.sound('menus/charter/save'), 0.3);
    }

    public function saveAsChart()
    {
        if (chart == null)
            return;
            
        fileReference = new FileReference();

        var data = Converter.writeChart(name, chart);
        fileReference.save(data, '$name-chart-$difficulty.json');
    }

    public function exitMenu()
    {
        Manager.switchState(new game.PlayState({song: PlayState.previousParams.song, difficulty: difficulty}));
    }

    /**
     * UI Handling Section
     */
    public function uiCreate()
    {
        topBar = new Bar({position: [0, 0], size: [camera.width, 30], items:
        [
            {name: "File", items: [
                {text: "Save", altText: "CTRL + S", callback: ()-> saveChart()},
                {text: "Save As...", altText: "CTRL + SHIFT + S", separate: true, callback: ()-> saveAsChart()},
                {text: "Import", altText: "CTRL + I", callback: ()-> trace("Imported File")},
                {text: "Export", altText: "CTRL + O", separate: true, callback: ()-> exportWindow.windowVisible = !exportWindow.windowVisible},
                {text: "Exit", altText: "ESC", callback: ()-> exitMenu()}
            ]},

            {name: "Edit", items: [
                {text: "Undo", altText: "CTRL + Z", callback: ()-> undoAction()},
                {text: "Redo", altText: "CTRL + Y", callback: ()-> redoAction()}
            ]},

            {name: "Song", items: [
                {text: "Open Conductor Window", callback: ()-> trace("Open Conductor Window")},
                {text: "Open Metadata Window", callback: ()-> trace("Open Metadata Window")},
                {text: "Open Audio Window", callback: ()-> trace("Open Audio Window")}
            ]},

            {name: "Chart", items: [
                {text: "Playtest", altText: "ENTER", callback: ()-> trace("Playtested song")},
                {text: "Playtest Here", separate: true, callback: ()-> trace("Playtested here song")},
                {text: "Toggle Waveforms", callback: ()-> trace("Toggled Waveforms")}
            ]},

            {name: "Misc", items: [
                {text: "Toggle Welcome Dialog", altText: "", callback: ()-> {
                    welcomeWindow.windowVisible = !welcomeWindow.windowVisible;
                    canInteractChart = !welcomeWindow.windowVisible;
                }},
                {text: "burp", altText: "", callback: ()-> FunkinSound.playOnce(Paths.sound('menus/charter/burp'))},
            ]}
        ]});
        
        topBar.camera = camUI;
        add(topBar);

        var exportWarningLabel:Label = new Label({position: [33, 83], size: [0.2, 0.2], type: "SOLID", alpha: 0.5, color: 0xFFFFFFFF, text: "* NOTE: Only Strumlines\nwith the ID of 0 and 1 will\nbe exported for this format."});
        exportWarningLabel.alpha = 0;
        
        exportWindow = new InteractiveWindow({position: [0, 0], size: [200, 320], title: "Export", items:
        [
            new Label({position: [33, 32], size: [0.25, 0.25], type: "SOLID", alpha: 0.5, color: 0xFFFFFFFF, text: "Format:"}),

            exportWarningLabel,
            new Dropdown({position: [(200 - 130) / 2, 50], size: [130, 30], items: [{name: "RevEngine"}, {name: "Legacy"}, {name: "V-Slice"}, {name: "Codename"}, {name: "Psych"}, {name: "FPS Plus"}, {name: "osu!"}, {name: "StepMania"}, {name: "Clone Hero"}, {name: "Quaver"}], callback: function(s) {
                exportWarningLabel.alpha = !["RevEngine", "Codename"].contains(s) ? 0.5 : 0;
            }}),

            new Label({position: [50, 209], size: [0.2, 0.2], type: "SOLID", alpha: 0.6, color: 0xFFFFFFFF, text: "Compress as .ZIP"}),
            new Label({position: [50, 240], size: [0.2, 0.2], type: "SOLID", alpha: 0.6, color: 0xFFFFFFFF, text: "Export with Audio Files"}),

            new Checkbox({position: [22, 203], size: [25, 25]}),
            new Checkbox({position: [22, 233], size: [25, 25]}),

            new Button({position: [(200 - 80) / 2, ((300 - 35) / 2) + 135], size: [80, 35], text: "Export", callback: () -> {
                trace("pipi");
            }})
        ], minimizable: false, callback: function(v) canInteractChart = !v});
        
        exportWindow.windowVisible = false;
        exportWindow.screenCenter();
        exportWindow.camera = camUI;
        exportWindow.borderOffsetY = 30;
        add(exportWindow);

        welcomeWindow = new InteractiveWindow({position: [0, 0], size: [600, 300], title: "RevEngine Chart Editor (PROTOTYPE)", items:
        [
            new Label({position: [20, 20], size: [0.4, 0.4], type: "SOLID", alpha: 1.0, color: 0xFFFFFFFF, text: "Welcome! (Currently charting " + meta.name + ")"}),

            new Separator({position: [24, 50], size: [400, 3], alpha: 0.4, color: 0xFFFFFFFF, blending: true}),

            new Label({position: [20, 60], size: [0.3, 0.3], type: "SOLID", alpha: 1.0, color: 0xFFFFFFFF, text: "Keybinds:"}),

            new Label({position: [20, 80], size: [0.25, 0.25], type: "SOLID", alpha: 1.0, color: 0xFFFFFFFF, text: "CTRL + C: Copy Selected Notes       CTRL + V: Paste Selected Notes\nDELETE: Delete Selected Notes       CTRL + A: Select every note on the Strumline.\nLEFT CLICK: Place/Select a note     RIGHT CLICK: Delete a note\nCTRL + Z: Undo Action               CTRL + X: Redo Action\nZ/X: Change the grid's snap value   Q/E: Change the Selected Note's length\nTAB + SCROLL WHEEL: Adjust camera   W/S/SCROLL WHEEL: Scroll through the playhead\nSHIFT: Disable Grid Snapping        SPACE: Play/Pause the playhead"}),

            new Separator({position: [24, 205], size: [500, 3], alpha: 0.4, color: 0xFFFFFFFF, blending: true}),

            new Label({position: [20, 215], size: [0.24, 0.24], type: "SOLID", alpha: 1, color: 0xFFFFFFFF, text: "Once you're ready to start charting, click Begin or just close this window!"}),

            new Button({position: [(600 - 80) / 2, ((280 - 35) / 2) + 125], size: [80, 35], text: "Begin", callback: () -> {
                welcomeWindow.windowVisible = false;
                canInteractChart = true;
            }})
        ], minimiziable: false, callback: function(v) canInteractChart = !v});
        
        welcomeWindow.camera = camUI;
        welcomeWindow.screenCenter();
        welcomeWindow.borderOffsetY = 30;
        add(welcomeWindow);
    }

    public function uiUpdate(elapsed:Float)
    {

    }

    override function destroy()
    {
        super.destroy();
        
        for (song in [inst, voices])
        {
            song.stop();
            song.destroy();
        }
    }
}