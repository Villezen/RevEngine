package menus;

import backend.MusicBeatState;
import backend.converters.Converter;
import backend.registries.song.ChartRegistry;
import backend.registries.song.ChartRegistry.ChartData;
import backend.registries.song.ChartRegistry.ChartNote;
import backend.registries.song.ChartRegistry.ChartStrumline;
import backend.registries.song.EventRegistry;
import backend.registries.song.EventObjectRegistry;
import backend.registries.song.EventObjectRegistry.EventObjectData;
import backend.registries.song.MetaRegistry;
import backend.ui.Bar;
import backend.ui.Button;
import backend.ui.Checkbox;
import backend.ui.Dropdown;
import backend.ui.InputBox;
import backend.ui.InteractiveWindow;
import backend.ui.Label;
import backend.ui.ScrollContainer;
import backend.ui.Separator;
import backend.ui.Stepper;
import backend.ui.UiManager;
import backend.utils.MathUtil;

import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.text.FlxBitmapText;

import game.PlayState;

import haxe.io.Path;

import lime.app.Application;

import menus.charting.CharterEvent;
import menus.charting.CharterEventGrid;
import menus.charting.CharterEventTooltip;
import menus.charting.CharterNote;
import menus.charting.CharterNotePreview;
import menus.charting.CharterStrumline;
import menus.charting.CharterStrumline.CharterNoteGraphics;
import menus.charting.CharterStrumlineBox;
import menus.charting.CharterStrumlineOutline;

import openfl.net.FileReference;

import sys.io.File;

class ChartingState extends MusicBeatState
{
    static inline final GRID_SIZE:Float = 40.0;
    static inline final GRID_OUTLINE:Float = 5.0;
    static inline final STRUMLINE_GAP:Float = 50.0;
    static inline final TOP_BAR_HEIGHT:Float = 30.0;

    static inline final EVENT_CELL:Float = 34.0;
    static inline final EVENT_OUTLINE:Float = 3.0;
    static inline final EVENT_STRIP_H:Float = EVENT_CELL + (EVENT_OUTLINE * 2);
    static inline final EVENT_STRIP_MARGIN:Float = 10.0;

    static inline final EVENT_STRIP_BOUND:Int = 50;

    static inline final NOTE_RENDER_Y_OFFSET:Float = 4.0;

    static inline final MIN_ZOOM:Float = 0.35;
    static inline final MAX_ZOOM:Float = 3.0;
    static inline final ZOOM_STEP:Float = 1.15;

    static inline final MAX_HISTORY:Int = 50;

    public var songName:String;
    public var difficulty:String;
    public var variation:String;

    var chart:ChartData;
    var meta:Dynamic;

    var totalWidth:Float = 0;
    var totalHeight:Float = 0;
    var finalMeasure:Int = 0;

    var inst:FunkinSound;
    var hitsound:FunkinSound;

    var vocals:Array<FunkinSound> = [];
    var tracks:Array<FunkinSound> = [];

    var playing:Bool = false;
    var hitsoundCursors:Array<Int> = [];

    var camBG:FlxCamera;
    var camGrid:FlxCamera;
    var camEvents:FlxCamera;
    var camUI:FlxCamera;

    var viewWidth:Float = FlxG.width;
    var viewHeight:Float = FlxG.height;

    var gridFollow:FlxObject;
    var bg:FunkinSprite;

    var camZoom:Float = 1.0;
    var camOffset:FlxPoint;
    var currentCamOffset:FlxPoint;
    var allowedXOffset:Int = 0;

    var strumlines:Array<CharterStrumline> = [];
    var noteGraphics:CharterNoteGraphics;

    var strumlineBoxes:Array<CharterStrumlineBox> = [];
    var strumlineOutline:CharterStrumlineOutline;

    var noteData:Array<Array<CharterNote>> = [];

    var eventData:Array<CharterEvent> = [];
    var eventLane:CharterEventGrid;
    var eventTooltip:CharterEventTooltip;
    var hoveredEvent:CharterEvent;

    var conductorLine:FunkinSprite;
    var gridBox:FunkinSprite;
    var selectionBox:FunkinSprite;

    var selectedNotes:Array<CharterNote> = [];
    var selectionLookup:Map<CharterNote, Bool> = new Map();

    var draggedNotes:Map<CharterNote, Bool> = new Map();
    var dragSources:Array<Int> = [];

    var dragDisplayX:Array<Float> = [];
    var dragDisplayY:Array<Float> = [];
    var dragDisplayReady:Bool = false;

    var selectionStart:FlxPoint;
    var isSelecting:Bool = false;

    var dragStartPos:FlxPoint;
    var isDragging:Bool = false;
    var dragStartStrumline:Int = -1;
    var dragStartColumn:Int = -1;

    var dragStepOffset:Float = 0;
    var dragColumnOffset:Int = 0;
    var dragStrumlineOffset:Int = 0;

    var clipboard:Array<ClipboardNote> = [];

    var snapList:Array<Float> = [8.0, 4.0, 2.0, 1.0, 0.5, 0.25, 0.125];
    var snapIndex:Int = 3;
    var curSnap:Float = 1.0;

    var history:Array<EditorSnapshot> = [];
    var historyIndex:Int = -1;

    var preview:CharterNotePreview;

    var canInteract:Bool = false;
    var mouseOverUI:Bool = false;

    var topBar:Bar;
    var exportWindow:InteractiveWindow;
    var welcomeWindow:InteractiveWindow;

    var editWindow:InteractiveWindow;
    var editIndex:Int = -1;

    var eventWindow:InteractiveWindow;
    var editingEvent:CharterEvent;
    var pendingEventTime:Float = 0.0;
    var pendingEventClose:Bool = false;

    var eventVarWidgets:Array<FlxSprite> = [];
    var eventContainer:ScrollContainer;
    var eventDescription:FlxBitmapText;
    var eventFieldWidth:Int = 200;
    var eventContentWidth:Int = 340;

    var metaWindow:InteractiveWindow;

    var conductorWindow:InteractiveWindow;
    var conductorValues:Array<FlxBitmapText> = [];

    var pendingRebuild:Bool = false;
    var pendingDelete:Int = -1;

    var pendingCloseMeta:Bool = false;
    var pendingMetaRelayout:Bool = false;

    var fileReference:FileReference;

    public function new(?songName:String, ?difficulty:String, ?variation:String)
    {
        super();

        var params = PlayState.previousParams;

        this.songName = songName ?? (params != null && params.song != null ? params.song : "test");
        this.difficulty = difficulty ?? (params != null && params.difficulty != null ? params.difficulty : Constants.DEFAULT_DIFFICULTY);
        this.variation = variation ?? (params != null && params.variation != null ? params.variation : "");
    }

    override function create():Void
    {
        FlxG.mouse.visible = true;

        super.create();

        initCameras();
        initBackground();

        selectionStart = FlxPoint.get();
        dragStartPos = FlxPoint.get();
        camOffset = FlxPoint.get();
        currentCamOffset = FlxPoint.get();

        loadChart();
        loadAudio();
        cacheNoteGraphics();

        buildStrumlines();
        buildUI();

        resizeCameras(Application.current.window.width, Application.current.window.height);
    }

    function initCameras():Void
    {
        camBG = new FlxCamera();
        camBG.bgColor = 0x00000000;
        FlxG.cameras.add(camBG, false);

        camGrid = new FlxCamera();
        camGrid.bgColor = 0x00000000;
        FlxG.cameras.add(camGrid, false);

        camEvents = new FlxCamera();
        camEvents.bgColor = 0x00000000;
        FlxG.cameras.add(camEvents, false);

        camUI = new FlxCamera();
        camUI.bgColor = 0x00000000;
        FlxG.cameras.add(camUI, false);

        gridFollow = new FlxObject(0, 0, 1, 1);
        gridFollow.camera = camGrid;
        add(gridFollow);

        camGrid.follow(gridFollow);
    }

    function initBackground():Void
    {
        bg = new FunkinSprite().loadGraphic(Paths.image("menus/backgrounds/menuDesat"));
        bg.setGraphicSize(FlxG.width, FlxG.height);
        bg.updateHitbox();
        bg.color = 0xFF3F3F4E;
        bg.camera = camBG;
        add(bg);
    }

    public override function onResize(width:Int, height:Int):Void
    {
        super.onResize(width, height);

        resizeCameras(width, height);
    }

    function resizeCameras(width:Int, height:Int):Void
    {
        if (width <= 0 || height <= 0) return;

        var ratio:Float = width / height;
        var baseRatio:Float = FlxG.width / FlxG.height;

        var camWidth:Int = FlxG.width;
        var camHeight:Int = FlxG.height;

        if (ratio > baseRatio)
            camWidth = Std.int(FlxG.height * ratio);
        else
            camHeight = Std.int(FlxG.width / ratio);

        var camX:Float = -(camWidth - FlxG.width) / 2;
        var camY:Float = -(camHeight - FlxG.height) / 2;

        for (camera in FlxG.cameras.list)
        {
            if (camera == null) continue;

            camera.width = camWidth;
            camera.height = camHeight;
            camera.x = camX;
            camera.y = camY;
        }

        if (camGrid != null && gridFollow != null)
            camGrid.follow(gridFollow);

        viewWidth = camWidth;
        viewHeight = camHeight;

        layoutUI();
    }

    function layoutUI():Void
    {
        if (bg != null)
        {
            bg.setGraphicSize(Std.int(viewWidth), Std.int(viewHeight));
            bg.updateHitbox();
            bg.setPosition(0, 0);
        }

        if (topBar != null)
            topBar.resize(viewWidth);

        layoutPreview();

        centerWindow(exportWindow);
        centerWindow(conductorWindow);
        centerWindow(welcomeWindow);
        centerWindow(editWindow);
        centerWindow(metaWindow);
        centerWindow(eventWindow);

        layoutEventLane();
    }

    function layoutPreview():Void
    {
        if (preview == null) return;

        var targetHeight:Int = Std.int(viewHeight - TOP_BAR_HEIGHT - EVENT_STRIP_H - EVENT_STRIP_MARGIN - 20);

        if (preview.previewHeight != targetHeight)
        {
            buildPreview();
            return;
        }

        preview.setPosition(viewWidth - preview.previewWidth - 4, TOP_BAR_HEIGHT + 10);
    }

    function centerWindow(window:InteractiveWindow):Void
    {
        if (window == null) return;

        window.x = (viewWidth - window.width) / 2;
        window.y = (viewHeight - window.height) / 2;

        var minY:Float = 30 + window.borderOffsetY;
        if (window.y < minY) window.y = minY;
    }

    function loadChart():Void
    {
        ChartRegistry.reload(songName, difficulty, variation);
        chart = ChartRegistry.get(songName, difficulty, variation);

        MetaRegistry.reload(songName, variation);
        meta = MetaRegistry.get(songName, variation);

        EventRegistry.reload(songName);
        loadEvents();

        history = [];
        historyIndex = -1;

        noteData = [];

        if (chart == null) return;

        for (entry in chart.strumlines)
        {
            var notes:Array<CharterNote> = [];

            for (note in entry.notes)
                notes.push(CharterNote.fromData(note));

            noteData.push(notes);
        }

        sortAllNotes();
        removeDuplicateNotes();
        pushHistory();
    }

    function syncChartData():Void
    {
        if (chart == null) return;

        for (i in 0...chart.strumlines.length)
        {
            if (i >= noteData.length) break;

            var data:Array<ChartNote> = [];

            for (note in noteData[i])
                data.push(note.toData());

            chart.strumlines[i].notes = data;
        }
    }

    function loadAudio():Void
    {
        destroyTracks();

        inst = loadTrack("Inst" + variation);

        if (inst != null)
            tracks.push(inst);

        loadVocalTracks();

        for (track in tracks)
        {
            track.play();
            track.pause();
            track.time = 0;
        }

        hitsound = FunkinSound.load(Paths.sound("menus/charter/hitsound"), 0.6);

        if (hitsound != null)
        {
            hitsound.play();
            hitsound.pause();
        }

        conductor.reset();
        conductor.setBPM((meta != null && meta.bpm > 0) ? meta.bpm : 100.0);

        refreshSongLength();
        resetHitsoundCursors();
    }

    function loadTrack(fileName:String):FunkinSound
    {
        if (!Paths.exists('songs/$songName/$fileName.ogg'))
            return null;

        var sound = Paths.audio(fileName, 'songs/$songName', "ogg", false, false, true);
        if (sound == null) return null;

        return FunkinSound.load(sound, 1.0, false, false, false, false, null, null, true);
    }

    function loadVocalTracks():Void
    {
        vocals = [];

        if (chart == null) return;

        var combinedName:String = "Voices" + variation;
        var combined:FunkinSound = null;
        var checkedCombined:Bool = false;

        var seen:Map<String, Bool> = new Map();
        var loaded:Array<String> = [];
        var missing:Array<String> = [];

        for (entry in chart.strumlines)
        {
            var character:String = entry.character;

            if (character == null || character == "" || seen.exists(character)) continue;
            seen.set(character, true);

            var trackName:String = 'Voices-$character$variation';
            var track:FunkinSound = loadTrack(trackName);

            if (track != null)
            {
                vocals.push(track);
                tracks.push(track);
                loaded.push(trackName);

                continue;
            }

            if (!checkedCombined)
            {
                checkedCombined = true;
                combined = loadTrack(combinedName);

                if (combined != null)
                {
                    vocals.push(combined);
                    tracks.push(combined);
                    loaded.push(combinedName);
                }
            }

            if (combined == null)
                missing.push(character);
        }
    }

    function refreshSongLength():Void
    {
        var lastTime:Float = 0.0;

        if (inst != null && inst.length > 0)
            lastTime = inst.length;
        else
        {
            for (notes in noteData)
            {
                for (note in notes)
                    if (note.endTime > lastTime) lastTime = note.endTime;
            }

            lastTime += conductor.measureLengthMs;
        }

        finalMeasure = Math.ceil(stepAtTime(lastTime) / 16.0);
        if (finalMeasure < 1)
            finalMeasure = 1;

        totalHeight = yFromTime(lastTime);

        var minimum:Float = GRID_SIZE * 16.0;
        if (totalHeight < minimum)
            totalHeight = minimum;
    }

    function cacheNoteGraphics():Void
    {
        noteGraphics = {heads: [], bodies: [], caps: [], multiHeads: new Map(), multiBodies: new Map(), multiCaps: new Map()};

        for (i in 0...CharterStrumline.KEY_AMOUNT)
        {
            noteGraphics.heads.push(resolveGraphic('menus/charter/notes/normal/$i'));
            noteGraphics.bodies.push(resolveGraphic('menus/charter/notes/normal/sustains/${i}_tail'));
            noteGraphics.caps.push(resolveGraphic('menus/charter/notes/normal/sustains/${i}_end'));
        }

        for (color in ['purple', 'blue', 'green', 'red', 'white', 'yellow', 'violet', 'darkred', 'darkblue'])
        {
            noteGraphics.multiHeads.set(color, resolveGraphic('menus/charter/notes/multikey/$color'));
            noteGraphics.multiBodies.set(color, resolveGraphic('menus/charter/notes/multikey/sustains/${color}_tail'));
            noteGraphics.multiCaps.set(color, resolveGraphic('menus/charter/notes/multikey/sustains/${color}_end'));
        }
    }

    function resolveGraphic(path:String):FlxGraphic
    {
        var key:String = Paths.image(path);
        if (key == null) return null;

        var graphic:FlxGraphic = FlxG.bitmap.get(key);
        if (graphic == null) graphic = FlxG.bitmap.add(key);

        return graphic;
    }

    function buildStrumlines():Void
    {
        for (strumline in strumlines)
        {
            if (strumline.grid != null) remove(strumline.grid);

            remove(strumline);
            strumline.destroy();
        }

        strumlines = [];

        for (box in strumlineBoxes)
        {
            remove(box);
            box.destroy();
        }

        strumlineBoxes = [];

        if (strumlineOutline != null) { remove(strumlineOutline); strumlineOutline.destroy(); strumlineOutline = null; }

        if (conductorLine != null) { remove(conductorLine); conductorLine.destroy(); }
        if (gridBox != null) { remove(gridBox); gridBox.destroy(); }
        if (selectionBox != null) { remove(selectionBox); selectionBox.destroy(); }

        if (eventLane != null)
        {
            remove(eventLane);
            eventLane.destroy();
            eventLane = null;
        }

        totalWidth = 0;
        allowedXOffset = 0;

        if (chart == null) return;

        refreshSongLength();

        var currentX:Float = 0;

        for (i in 0...chart.strumlines.length)
        {
            var entry:ChartStrumline = chart.strumlines[i];

            while (noteData.length <= i)
                noteData.push([]);

            var strumline = new CharterStrumline(i, noteData[i], entry.keys, entry.character, GRID_SIZE, GRID_OUTLINE, noteGraphics, camGrid);
            strumline.setX(currentX);
            strumline.buildGrid(totalHeight);

            entry.keys = strumline.keys;

            add(strumline.grid);
            strumlines.push(strumline);

            allowedXOffset += Std.int(GRID_SIZE * strumline.keys);

            currentX += strumline.width + STRUMLINE_GAP;
            totalWidth = currentX;
        }

        for (strumline in strumlines)
            add(strumline);

        var lineWidth:Float = Math.max(0, totalWidth - STRUMLINE_GAP);

        conductorLine = new FunkinSprite().makeGraphic(Std.int(lineWidth), 5, 0xFFDDDDDD);
        conductorLine.camera = camGrid;
        conductorLine.y = GRID_OUTLINE + yFromTime(conductor.songPosition);
        conductorLine.offset.y = conductorLine.height;
        add(conductorLine);

        gridBox = new FunkinSprite().makeGraphic(Std.int(GRID_SIZE), Std.int(GRID_SIZE), 0xFFDDDDDD);
        gridBox.camera = camGrid;
        gridBox.alpha = 0.5;
        add(gridBox);

        applySnap();

        selectionBox = new FunkinSprite().makeGraphic(1, 1, 0x550088FF);
        selectionBox.origin.set(0, 0);
        selectionBox.camera = camGrid;
        selectionBox.visible = false;
        add(selectionBox);

        gridFollow.x = lineWidth / 2;

        for (i in 0...strumlines.length)
        {
            var index:Int = i;
            var box = new CharterStrumlineBox(chart.strumlines[i], strumlines[i], camGrid, () -> openEditWindow(index));
            add(box);
            strumlineBoxes.push(box);
        }

        strumlineOutline = new CharterStrumlineOutline(camGrid);
        add(strumlineOutline);

        buildEventLane();
        buildPreview();
    }

    function buildEventLane():Void
    {
        eventLane = new CharterEventGrid(eventData, EVENT_CELL, EVENT_OUTLINE, camEvents);

        var timelineWidth:Float = (totalHeight / GRID_SIZE) * EVENT_CELL;
        eventLane.build(timelineWidth);

        add(eventLane);

        layoutEventLane();
    }

    function layoutEventLane():Void
    {
        if (eventLane == null) return;

        var stripTop:Float = viewHeight - eventLane.stripHeight - EVENT_STRIP_MARGIN;
        var markerX:Float = Math.max(150, viewWidth * 0.13);

        eventLane.layout(stripTop, markerX, viewWidth);
    }

    function updateStrumlineBoxes():Void
    {
        var naturalY:Float = -83;
        var zoom:Float = (camGrid.zoom > 0.01) ? camGrid.zoom : 1.0;
        var topMargin:Float = (TOP_BAR_HEIGHT + 6) / zoom;

        var overWindow:Bool = windowBlockingInput();

        for (box in strumlineBoxes)
        {
            box.interactable = canInteract && !overWindow;
            box.follow(naturalY, camGrid.viewTop, topMargin);
        }

        if (strumlineOutline != null)
        {
            var index:Int = focusedStrumlineIndex();

            if (index >= 0 && index < strumlines.length)
            {
                var originY:Float = Math.max(naturalY, camGrid.viewTop + topMargin);
                var strumline = strumlines[index];

                strumlineOutline.setTarget(strumline.x, originY, strumline.width, CharterStrumlineBox.HEIGHT);
            }
            else
                strumlineOutline.clearTarget();
        }
    }

    function focusedStrumlineIndex():Int
    {
        var target:Int = activeCameraTarget();
        if (target < 0) return -1;

        return strumlineIndexForId(target);
    }

    function strumlineIndexForId(id:Int):Int
    {
        if (chart == null) return -1;

        for (i in 0...chart.strumlines.length)
            if ((chart.strumlines[i].id ?? 0) == id) return i;

        return -1;
    }

    function updateKeyPreview():Void
    {
        if (chart == null || strumlines.length == 0) return;

        var time:Float = conductor.songPosition;

        var effective:Array<Int> = [];
        var bestTime:Array<Float> = [];

        for (i in 0...chart.strumlines.length)
        {
            effective.push(chart.strumlines[i].keys ?? 4);
            bestTime.push(Math.NEGATIVE_INFINITY);
        }

        for (event in eventData)
        {
            if (event.name != "Change Key Amount") continue;
            if (event.time > time) continue;
            if (event.variables == null || event.variables.length < 2) continue;

            var target:Null<Int> = Std.parseInt(event.variables[0]);
            var keys:Null<Int> = Std.parseInt(event.variables[1]);
            if (target == null || keys == null) continue;

            var index:Int = strumlineIndexForId(target);
            if (index < 0) continue;

            if (event.time >= bestTime[index])
            {
                bestTime[index] = event.time;
                effective[index] = keys;
            }
        }

        var refreshLayout:Bool = false;

        for (i in 0...strumlines.length)
        {
            if (i >= effective.length) break;

            var target:Int = Std.int(FlxMath.bound(effective[i], 1, 9));
            if (strumlines[i].keys == target) continue;

            strumlines[i].setKeys(target, false);
            strumlines[i].resizeGrid();

            if (i < strumlineBoxes.length) strumlineBoxes[i].refresh();

            refreshLayout = true;
        }

        if (refreshLayout) refreshStrumlineLayout();
    }

    function refreshStrumlineLayout():Void
    {
        var currentX:Float = 0;
        allowedXOffset = 0;

        for (strumline in strumlines)
        {
            strumline.setX(currentX);
            allowedXOffset += Std.int(GRID_SIZE * strumline.keys);
            currentX += strumline.width + STRUMLINE_GAP;
        }

        totalWidth = currentX;

        var lineWidth:Float = Math.max(0, totalWidth - STRUMLINE_GAP);

        if (conductorLine != null)
        {
            conductorLine.setGraphicSize(Std.int(lineWidth), 5);
            conductorLine.updateHitbox();
            conductorLine.offset.y = conductorLine.height;
        }
    }

    function activeCameraTarget():Int
    {
        var time:Float = conductor.songPosition;

        var target:Int = -1;
        var bestTime:Float = Math.NEGATIVE_INFINITY;

        var firstTarget:Int = -1;
        var firstTime:Float = Math.POSITIVE_INFINITY;

        for (event in eventData)
        {
            if (event.name != "Camera Movement") continue;

            var value:Int = parseCameraTarget(event);
            if (value < 0) continue;

            if (event.time < firstTime)
            {
                firstTime = event.time;
                firstTarget = value;
            }

            if (event.time <= time && event.time >= bestTime)
            {
                bestTime = event.time;
                target = value;
            }
        }

        return (target >= 0) ? target : firstTarget;
    }

    inline function parseCameraTarget(event:CharterEvent):Int
    {
        if (event.variables == null || event.variables.length == 0) return -1;

        var value:Null<Int> = Std.parseInt(event.variables[0]);
        return (value == null) ? -1 : value;
    }

    function windowBlockingInput():Bool
    {
        if (UiManager.activeUi != null) return true;
        if (topBar != null && topBar.activeMenuIndex != -1) return true;

        var pointer = FlxG.mouse.getWorldPosition(camUI);
        var over:Bool = pointer.y <= TOP_BAR_HEIGHT;

        if (!over && preview != null)
            over = preview.containsPoint(pointer.x, pointer.y);

        pointer.put();
        return over;
    }

    function anyBoxHovered():Bool
    {
        for (box in strumlineBoxes)
        {
            if (box.hovered)
                return true;
        }

        return false;
    }

    function updateEventLane():Void
    {
        if (eventLane == null) return;

        var stepLength:Float = conductor.stepLengthMs;

        if (conductorLine != null)
        {
            var laneOffset:Float = ((conductorLine.y - GRID_OUTLINE) / GRID_SIZE) * EVENT_CELL;
            var scrollX:Float = (EVENT_OUTLINE + laneOffset) - eventLane.markerX;
            
            var minScroll:Float = (EVENT_OUTLINE + 1) - eventLane.markerX;
            var maxScroll:Float = (eventLane.timelineWidth + EVENT_OUTLINE - 2) - eventLane.markerX;
            if (maxScroll < minScroll) maxScroll = minScroll;

            camEvents.scroll.x = FlxMath.bound(scrollX, minScroll, maxScroll);
        }

        camEvents.scroll.y = 0;

        hoveredEvent = null;

        var showHover:Bool = canInteract && !playing && !windowBlockingInput() && !isSelecting && !isDragging;

        if (showHover && stepLength > 0)
        {
            var pointer = FlxG.mouse.getWorldPosition(camEvents);

            if (eventLane.containsStrip(pointer.y))
            {
                eventLane.updateHover(pointer.x, curSnap, FlxG.keys.pressed.SHIFT);
                hoveredEvent = eventLane.eventAt(pointer.x, pointer.y, stepLength);
            }
            else
                eventLane.hideHover();

            pointer.put();
        }
        else
            eventLane.hideHover();

        if (eventTooltip != null)
        {
            if (hoveredEvent != null && stepLength > 0)
            {
                var scale:Float = EVENT_CELL / stepLength;
                var centerX:Float = (EVENT_OUTLINE + hoveredEvent.time * scale) - camEvents.scroll.x + (EVENT_CELL / 2);

                eventTooltip.showAt(hoveredEvent, EventObjectRegistry.findByName(hoveredEvent.name), centerX, eventLane.stripTop, viewWidth);
            }
            else
                eventTooltip.hide();
        }
    }

    function mouseOverEventStrip():Bool
    {
        if (eventLane == null) return false;

        var pointer = FlxG.mouse.getWorldPosition(camEvents);
        var over:Bool = eventLane.containsStrip(pointer.y);
        pointer.put();

        return over;
    }

    function loadEvents():Void
    {
        eventData = [];

        var data = EventRegistry.get(songName);

        if (data != null && data.events != null)
            for (entry in data.events) eventData.push(CharterEvent.fromEntry(entry));

        sortEvents();
    }

    function sortEvents():Void
    {
        eventData.sort(CharterEvent.compare);
    }

    function deleteEvent(event:CharterEvent):Void
    {
        if (event == null) return;

        eventData.remove(event);
        if (hoveredEvent == event) hoveredEvent = null;

        FunkinSound.playOnce(Paths.sound("menus/charter/notes/delete"), 0.1);
        pushHistory();
    }

    function handleEventLaneMouse(pointer:FlxPoint, stepLength:Float):Void
    {
        var event:CharterEvent = eventLane.eventAt(pointer.x, pointer.y, stepLength);

        if (FlxG.mouse.justPressedRight)
        {
            if (event != null) deleteEvent(event);
            return;
        }

        if (!FlxG.mouse.justPressed) return;

        if (event != null)
        {
            openEventWindow(event);
            return;
        }

        if (!eventLane.inGrid(pointer.x)) return;

        var time:Float = eventLane.timeAtX(pointer.x, stepLength);

        if (!FlxG.keys.pressed.SHIFT)
        {
            var snap:Float = stepLength * curSnap;
            time = Math.floor(time / snap) * snap;
        }

        if (time < 0) time = 0;

        var maxTime:Float = (eventLane.timelineWidth - EVENT_CELL) * stepLength / EVENT_CELL;
        if (maxTime > 0 && time > maxTime) time = maxTime;

        openEventWindow(null, time);
    }

    function buildPreview():Void
    {
        if (preview != null)
        {
            remove(preview);
            preview.destroy();
            preview = null;
        }

        if (chart == null || strumlines.length == 0) return;

        var columns:Int = 0;
        for (strumline in strumlines) columns += strumline.keys;

        if (columns <= 0) return;

        var columnWidth:Int = 5;
        if (columns > 12) columnWidth = 3;
        if (columns > 20) columnWidth = 2;

        var width:Int = columnWidth * columns;
        var height:Int = Std.int(viewHeight - TOP_BAR_HEIGHT - EVENT_STRIP_H - EVENT_STRIP_MARGIN - 20);

        preview = new CharterNotePreview(viewWidth - width - 4, TOP_BAR_HEIGHT + 10, width, height, columnWidth);
        preview.camera = camUI;
        add(preview);
    }

    function rebuildStrumlines():Void
    {
        if (playing) togglePlayback();

        clearSelection();

        isDragging = false;
        isSelecting = false;

        dragStepOffset = 0;
        dragColumnOffset = 0;
        dragStrumlineOffset = 0;
        draggedNotes.clear();

        if (selectionBox != null) selectionBox.visible = false;

        closeEditWindow();

        buildStrumlines();
        refreshVocals();

        pushHistory();
    }

    public function addStrumline(keys:Int = 4, character:String = "bf"):Int
    {
        if (chart == null) return -1;

        var index:Int = chart.strumlines.length;

        chart.strumlines.push
        ({
            id: nextFreeId(),
            character: character,
            skin: "default",
            position: [0, 0],
            scale: 1.0,
            visible: true,
            keys: Std.int(FlxMath.bound(keys, 1, 9)),
            speed: 1.0,
            playable: false,
            notes: []
        });

        noteData.push([]);

        rebuildStrumlines();

        return index;
    }

    function nextFreeId():Int
    {
        var next:Int = 0;

        for (entry in chart.strumlines)
        {
            var id:Int = entry.id ?? 0;
            if (id >= next) next = id + 1;
        }

        return next;
    }

    function idInUse(id:Int, exceptIndex:Int):Bool
    {
        for (i in 0...chart.strumlines.length)
        {
            if (i == exceptIndex) continue;
            if ((chart.strumlines[i].id ?? 0) == id) return true;
        }

        return false;
    }

    public function removeStrumline(index:Int):Bool
    {
        if (chart == null || index < 0 || index >= chart.strumlines.length) return false;

        if (chart.strumlines.length <= 1)
        {
            trace("Refusing to remove the last remaining strumline.", "WARNING");
            return false;
        }

        chart.strumlines.splice(index, 1);

        if (index < noteData.length)
            noteData.splice(index, 1);

        rebuildStrumlines();

        return true;
    }

    public function setStrumlineKeys(index:Int, keys:Int):Bool
    {
        if (chart == null || index < 0 || index >= chart.strumlines.length) return false;

        keys = Std.int(FlxMath.bound(keys, 1, 9));

        var entry = chart.strumlines[index];
        if (entry.keys == keys) return false;

        entry.keys = keys;

        if (index < noteData.length)
        {
            for (note in noteData[index])
            {
                if (note.direction >= keys) note.direction = keys - 1;
                if (note.direction < 0) note.direction = 0;
            }
        }

        removeDuplicateNotes();
        rebuildStrumlines();

        return true;
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (pendingDelete >= 0)
        {
            var index:Int = pendingDelete;
            pendingDelete = -1;
            removeStrumline(index);
        }
        else if (pendingRebuild)
        {
            pendingRebuild = false;
            removeDuplicateNotes();
            rebuildStrumlines();
        }

        if (pendingCloseMeta)
        {
            pendingCloseMeta = false;
            closeMetadataWindow();
        }

        if (pendingMetaRelayout)
        {
            pendingMetaRelayout = false;
            buildStrumlines();
        }

        if (pendingEventClose)
        {
            pendingEventClose = false;
            closeEventWindow();
        }

        mouseOverUI = computeMouseOverUI();

        handleInput(elapsed);

        if (playing)
            conductor.update(conductor.songPosition + elapsed * 1000);

        updatePlayback(elapsed);
        updateHitsounds();

        updateKeyPreview();

        updateCamera(elapsed);
        updateStrumlineBoxes();
        updateEventLane();
        renderNotes();

        updateGridBox();
        updatePreview();
        updateConductorWindow();
    }

    function computeMouseOverUI():Bool
    {
        return windowBlockingInput() || anyBoxHovered();
    }

    function renderNotes():Void
    {
        if (chart == null) return;

        var stepLength:Float = conductor.stepLengthMs;
        if (stepLength <= 0) return;

        var margin:Float = GRID_SIZE * NOTE_RENDER_Y_OFFSET;

        var top:Float = camGrid.viewTop - GRID_OUTLINE - margin;
        var bottom:Float = camGrid.viewTop + camGrid.viewHeight - GRID_OUTLINE + margin;

        var msPerPixel:Float = stepLength / GRID_SIZE;

        var topTime:Float = top * msPerPixel;
        var bottomTime:Float = bottom * msPerPixel;

        var playheadY:Float = conductorLine != null ? conductorLine.y : 0;

        for (strumline in strumlines)
            strumline.refresh(topTime, bottomTime, stepLength, playheadY, selectionLookup, isDragging ? draggedNotes : null);

        if (eventLane != null)
        {
            var scaleX:Float = EVENT_CELL / stepLength;
            var leftTime:Float = (camEvents.scroll.x - EVENT_OUTLINE) / scaleX;
            var rightTime:Float = (camEvents.scroll.x + viewWidth - EVENT_OUTLINE) / scaleX;
            var playheadX:Float = eventLane.markerX + camEvents.scroll.x;

            eventLane.refresh(leftTime, rightTime, stepLength, playheadX);
        }

        if (isDragging)
        {
            updateDragDisplay(stepLength);
            renderDragPreview(stepLength, topTime, bottomTime);
        }
    }

    function updateDragDisplay(stepLength:Float):Void
    {
        var pixelsPerMs:Float = GRID_SIZE / stepLength;
        var snapped:Bool = !FlxG.keys.pressed.SHIFT;
        var elapsed:Float = FlxG.elapsed;

        if (dragDisplayX.length != selectedNotes.length)
        {
            dragDisplayX.resize(selectedNotes.length);
            dragDisplayY.resize(selectedNotes.length);
            dragDisplayReady = false;
        }

        for (i in 0...selectedNotes.length)
        {
            var from:Int = (i < dragSources.length) ? dragSources[i] : -1;
            if (from < 0 || from >= strumlines.length) continue;

            var note:CharterNote = selectedNotes[i];

            var to:Int = Std.int(FlxMath.bound(from + dragStrumlineOffset, 0, strumlines.length - 1));
            var target = strumlines[to];

            var direction:Int = Std.int(FlxMath.bound(note.direction + dragColumnOffset, 0, target.keys - 1));

            var time:Float = note.time + (dragStepOffset * stepLength);
            if (time < 0) time = 0;

            var targetX:Float = target.x + GRID_OUTLINE + (direction * GRID_SIZE);
            var targetY:Float = GRID_OUTLINE + (time * pixelsPerMs);

            if (!dragDisplayReady)
            {
                dragDisplayX[i] = targetX;
                dragDisplayY[i] = targetY;
            }
            else
            {
                dragDisplayX[i] = MathUtil.smoothLerpPrecision(dragDisplayX[i], targetX, elapsed, 0.055);
                dragDisplayY[i] = snapped ? MathUtil.smoothLerpPrecision(dragDisplayY[i], targetY, elapsed, 0.055) : targetY;
            }
        }

        dragDisplayReady = true;
    }

    function renderDragPreview(stepLength:Float, topTime:Float, bottomTime:Float):Void
    {
        var pixelsPerMs:Float = GRID_SIZE / stepLength;

        for (i in 0...selectedNotes.length)
        {
            var from:Int = (i < dragSources.length) ? dragSources[i] : -1;
            if (from < 0 || from >= strumlines.length) continue;

            var note:CharterNote = selectedNotes[i];

            var to:Int = Std.int(FlxMath.bound(from + dragStrumlineOffset, 0, strumlines.length - 1));
            var target = strumlines[to];

            var direction:Int = Std.int(FlxMath.bound(note.direction + dragColumnOffset, 0, target.keys - 1));

            if (note.endTime >= topTime && note.time <= bottomTime)
                strumlines[from].drawNote(note.direction, note.time, note.sustain, pixelsPerMs, false, true);

            if (i >= dragDisplayX.length) continue;

            var displayX:Float = dragDisplayX[i];
            var displayY:Float = dragDisplayY[i];
            var displayTime:Float = (displayY - GRID_OUTLINE) / pixelsPerMs;

            if (displayTime + note.sustain >= topTime && displayTime <= bottomTime)
                target.drawNoteAt(displayX, displayY, direction, note.sustain, pixelsPerMs, true, false);
        }
    }

    function updatePlayback(elapsed:Float):Void
    {
        if (conductorLine == null) return;

        if (playing && inst != null && inst.length > 0 && conductor.songPosition >= inst.length - 5.0)
        {
            playing = false;
            pauseTracks();

            conductor.seek(inst.length);
        }

        var targetY:Float = GRID_OUTLINE + yFromTime(conductor.songPosition);

        if (playing || (preview != null && preview.scrubbing))
            conductorLine.y = targetY;
        else
            conductorLine.y = MathUtil.smoothLerpPrecision(conductorLine.y, targetY, elapsed, 0.25);
    }

    function updateCamera(elapsed:Float):Void
    {
        if (conductorLine == null) return;

        if (camGrid.zoom != camZoom)
        {
            var eased:Float = MathUtil.smoothLerpPrecision(camGrid.zoom, camZoom, elapsed, 0.12);

            camGrid.zoom = (Math.abs(eased - camZoom) < 0.001) ? camZoom : eased;
        }

        gridFollow.x = MathUtil.smoothLerpPrecision(gridFollow.x, conductorLine.x + (conductorLine.width / 2) + camOffset.x, elapsed, 0.4);

        currentCamOffset.y = MathUtil.smoothLerpPrecision(currentCamOffset.y, camOffset.y, elapsed, 0.4);
        gridFollow.y = conductorLine.y + currentCamOffset.y;
    }

    function updateHitsounds():Void
    {
        if (!playing || hitsound == null) return;

        if (hitsoundCursors.length != noteData.length)
            resetHitsoundCursors();

        var position:Float = conductor.songPosition;
        var play:Bool = false;

        for (i in 0...noteData.length)
        {
            var notes:Array<CharterNote> = noteData[i];
            var cursor:Int = hitsoundCursors[i];

            while (cursor < notes.length && notes[cursor].time <= position)
            {
                play = true;
                cursor++;
            }

            hitsoundCursors[i] = cursor;
        }

        if (play)
        {
            hitsound.time = 0;
            hitsound.play(true);
        }
    }

    function resetHitsoundCursors():Void
    {
        hitsoundCursors = [];

        var position:Float = conductor.songPosition;

        for (notes in noteData)
        {
            var low:Int = 0;
            var high:Int = notes.length - 1;

            while (low <= high)
            {
                var mid:Int = (low + high) >> 1;

                if (notes[mid].time <= position)
                    low = mid + 1;
                else
                    high = mid - 1;
            }

            hitsoundCursors.push(low);
        }
    }

    function togglePlayback():Void
    {
        if (inst == null) return;

        playing = !playing;

        if (playing && conductor.songPosition >= inst.length)
            seekTo(0);

        if (playing)
        {
            setTrackTime(conductor.songPosition);
            playTracks();
            resetHitsoundCursors();
        }
        else
            pauseTracks();
    }

    function seekTo(time:Float, applyAudio:Bool = true):Void
    {
        if (time < 0) time = 0;
        if (inst != null && time > inst.length) time = inst.length;

        if (applyAudio)
            setTrackTime(time);

        conductor.seek(time);

        if (playing)
            resetHitsoundCursors();
    }

    function skimSong(direction:Int):Void
    {
        if (FlxG.keys.pressed.TAB || FlxG.keys.pressed.CONTROL || FlxG.keys.pressed.ALT) return;

        if (playing) togglePlayback();

        var amount:Float = conductor.stepLengthMs * (FlxG.keys.pressed.SHIFT ? 2 : 1);
        seekTo(conductor.songPosition + amount * direction);
    }

    function skimCamera(direction:Int):Void
    {
        if (FlxG.keys.pressed.ALT)
            camOffset.x = FlxMath.bound(camOffset.x + (40 * direction), -allowedXOffset, allowedXOffset);
        else if (FlxG.keys.pressed.TAB)
            camOffset.y = FlxMath.bound(camOffset.y + (40 * direction), -280, 280);
    }

    function zoomCamera(direction:Int):Void
    {
        camZoom = FlxMath.bound(direction > 0 ? camZoom * ZOOM_STEP : camZoom / ZOOM_STEP, MIN_ZOOM, MAX_ZOOM);
    }

    override function stepHit(step:Float):Void
    {
        super.stepHit(step);

        if (!playing || inst == null) return;

        if (Math.abs(inst.time - conductor.songPosition) > Constants.RESYNC_THRESHOLD)
        {
            conductor.songPosition = inst.time;
            resetHitsoundCursors();
        }

        if (step % 4 != 0) return;

        for (voice in vocals)
        {
            if (Math.abs(voice.time - inst.time) > Constants.RESYNC_THRESHOLD)
                voice.time = inst.time;
        }
    }

    function playTracks():Void
    {
        for (track in tracks)
            track.play();
    }

    function pauseTracks():Void
    {
        for (track in tracks)
            track.pause();
    }

    function setTrackTime(time:Float):Void
    {
        for (track in tracks)
            track.time = time;
    }

    function destroyTracks():Void
    {
        for (track in tracks)
        {
            if (track == null)
                continue;

            track.stop();
            track.destroy();
        }

        tracks = [];
        vocals = [];
        inst = null;
    }

    function refreshVocals():Void
    {
        for (voice in vocals)
        {
            if (voice == null) continue;

            tracks.remove(voice);

            voice.stop();
            voice.destroy();
        }

        vocals = [];
        loadVocalTracks();

        var position:Float = conductor.songPosition;

        for (voice in vocals)
        {
            voice.play();
            voice.pause();
            voice.time = position;

            if (playing) voice.play();
        }
    }

    function handleInput(elapsed:Float):Void
    {
        var ctrl:Bool = FlxG.keys.pressed.CONTROL;

        if (ctrl && FlxG.keys.justPressed.S)
        {
            if (FlxG.keys.pressed.SHIFT)
                saveChartAs();
            else
                saveChart();
        }

        if (!canInteract) return;

        handlePreviewScrub();

        if (ctrl && !isDragging)
        {
            if (FlxG.keys.justPressed.Z)
                undo();
            else if (FlxG.keys.justPressed.X || FlxG.keys.justPressed.Y)
                redo();
        }

        var scrolling:Bool = FlxG.mouse.wheel != 0;
        var stepping:Bool = controls.UI_UP.justPressed || controls.UI_DOWN.justPressed;

        if (ctrl && FlxG.keys.justPressed.SPACE)
            addStrumline();
        else if (FlxG.keys.justPressed.SPACE && !stepping && !scrolling)
            togglePlayback();

        if (scrolling) skimSong(FlxG.mouse.wheel > 0 ? -1 : 1);
        if (stepping) skimSong(controls.UI_UP.justPressed ? -1 : 1);

        if (scrolling && (FlxG.keys.pressed.TAB || FlxG.keys.pressed.ALT))
            skimCamera(FlxG.mouse.wheel > 0 ? -1 : 1);

        if (scrolling && ctrl)
            zoomCamera(FlxG.mouse.wheel > 0 ? 1 : -1);

        if (ctrl && FlxG.keys.justPressed.R)
            camZoom = 1.0;

        if (FlxG.keys.justPressed.ESCAPE)
            exitEditor();

        if (!ctrl && (FlxG.keys.justPressed.Z || FlxG.keys.justPressed.X))
            setSnap(snapIndex + (FlxG.keys.justPressed.Z ? 1 : -1));

        if (preview == null || !preview.scrubbing)
            handleMouse();

        if (FlxG.keys.justPressed.Q)
            resizeSelectedSustains(-1);
        else if (FlxG.keys.justPressed.E)
            resizeSelectedSustains(1);

        if (FlxG.keys.justPressed.DELETE)
            deleteSelected();

        if (ctrl && FlxG.keys.justPressed.A)
            selectHoveredStrumline();

        if (ctrl && FlxG.keys.justPressed.C)
            copySelected();

        if (ctrl && FlxG.keys.justPressed.V)
            pasteClipboard();
    }

    function setSnap(index:Int):Void
    {
        snapIndex = Std.int(FlxMath.bound(index, 0, snapList.length - 1));
        curSnap = snapList[snapIndex];

        applySnap();
    }

    function applySnap():Void
    {
        if (gridBox == null) return;

        gridBox.setGraphicSize(GRID_SIZE, GRID_SIZE * curSnap);
        gridBox.updateHitbox();
    }

    function handlePreviewScrub():Void
    {
        if (preview == null || inst == null) return;

        var pointer = FlxG.mouse.getWorldPosition(camUI);

        if (FlxG.mouse.justPressed && preview.containsPoint(pointer.x, pointer.y, 0) && UiManager.activeUi == null)
        {
            preview.scrubbing = true;

            if (playing) togglePlayback();
        }

        if (preview.scrubbing)
        {
            if (FlxG.mouse.pressed)
            {
                var target:Float = preview.fractionAt(pointer.y) * inst.length;

                if (Math.abs(target - conductor.songPosition) > 0.5)
                    seekTo(target, false);
            }
            else
            {
                preview.scrubbing = false;
                setTrackTime(conductor.songPosition);
            }
        }

        pointer.put();
    }

    function handleMouse():Void
    {
        if (chart == null || playing) return;

        if (mouseOverUI && !isSelecting && !isDragging) return;

        var pointer = FlxG.mouse.getWorldPosition(camGrid);
        var stepLength:Float = conductor.stepLengthMs;

        if (eventLane != null && !isSelecting && !isDragging)
        {
            var eventPointer = FlxG.mouse.getWorldPosition(camEvents);

            if (eventLane.containsStrip(eventPointer.y))
            {
                handleEventLaneMouse(eventPointer, stepLength);
                eventPointer.put();
                pointer.put();
                return;
            }

            eventPointer.put();
        }

        if (FlxG.mouse.justPressedRight)
            deleteNoteAt(pointer, stepLength);

        if (FlxG.mouse.justPressed)
            beginMouseAction(pointer, stepLength);

        if (isDragging && FlxG.mouse.pressed)
            updateDrag(pointer);

        if (isDragging && FlxG.mouse.justReleased)
            finishDrag();

        if (isSelecting && FlxG.mouse.pressed)
        {
            selectionBox.x = Math.min(selectionStart.x, pointer.x);
            selectionBox.y = Math.min(selectionStart.y, pointer.y);
            selectionBox.scale.set(Math.max(1, Math.abs(pointer.x - selectionStart.x)), Math.max(1, Math.abs(pointer.y - selectionStart.y)));
        }

        if (isSelecting && FlxG.mouse.justReleased)
        {
            isSelecting = false;
            selectionBox.visible = false;

            var travelled:Float = Math.abs(pointer.x - selectionStart.x) + Math.abs(pointer.y - selectionStart.y);

            if (travelled < 10)
                handleGridClick(pointer, stepLength);
            else
                applySelectionBox(stepLength);
        }

        pointer.put();
    }

    function deleteNoteAt(pointer:FlxPoint, stepLength:Float):Void
    {
        for (strumline in strumlines)
        {
            var note:CharterNote = strumline.noteAt(pointer.x, pointer.y, stepLength);
            if (note == null) continue;

            strumline.notes.remove(note);
            deselect(note);

            strumline.refreshSustainBounds();

            pushHistory();
            markPreviewDirty();

            FunkinSound.playOnce(Paths.sound("menus/charter/notes/delete"), 0.1);

            return;
        }
    }

    function beginMouseAction(pointer:FlxPoint, stepLength:Float):Void
    {
        for (i in 0...strumlines.length)
        {
            var strumline = strumlines[i];

            var note:CharterNote = strumline.noteAt(pointer.x, pointer.y, stepLength);
            if (note == null) continue;

            dragStartStrumline = i;
            dragStartColumn = strumline.columnAt(pointer.x);

            if (!selectionLookup.exists(note))
            {
                if (!FlxG.keys.pressed.SHIFT)
                    clearSelection();

                select(note);
            }

            isDragging = true;
            dragStartPos.set(pointer.x, pointer.y);

            refreshDraggedNotes();

            FunkinSound.playOnce(Paths.sound("menus/charter/notes/grab"), 0.15);

            return;
        }

        selectionStart.set(pointer.x, pointer.y);
        isSelecting = true;

        selectionBox.visible = true;
        selectionBox.x = pointer.x;
        selectionBox.y = pointer.y;
        selectionBox.scale.set(1, 1);
    }

    function updateDrag(pointer:FlxPoint):Void
    {
        var hoveredStrumline:Int = dragStartStrumline;
        var hoveredColumn:Int = dragStartColumn;
        var closest:Float = 999999.0;

        for (i in 0...strumlines.length)
        {
            var strumline = strumlines[i];

            if (strumline.containsX(pointer.x))
            {
                hoveredStrumline = i;
                hoveredColumn = strumline.columnAt(pointer.x);

                break;
            }

            var distance:Float = (pointer.x < strumline.x) ? strumline.x - pointer.x : pointer.x - (strumline.x + strumline.width);

            if (distance < closest)
            {
                closest = distance;
                hoveredStrumline = i;
                hoveredColumn = (pointer.x < strumline.x) ? 0 : strumline.keys - 1;
            }
        }

        var strumlineOffset:Int = hoveredStrumline - dragStartStrumline;
        var columnOffset:Int = hoveredColumn - dragStartColumn;
        var stepOffset:Float = (pointer.y - dragStartPos.y) / GRID_SIZE;

        if (!FlxG.keys.pressed.SHIFT)
            stepOffset = Math.round(stepOffset / curSnap) * curSnap;

        var stepLength:Float = conductor.stepLengthMs;
        var minOffset:Float = -999999.0;

        for (note in selectedNotes)
        {
            var toZero:Float = -(note.time / stepLength);
            if (toZero > minOffset) minOffset = toZero;
        }

        if (stepOffset < minOffset)
        {
            stepOffset = minOffset;

            if (!FlxG.keys.pressed.SHIFT)
                stepOffset = Math.ceil(stepOffset / curSnap) * curSnap;
        }

        dragStepOffset = stepOffset;
        dragColumnOffset = columnOffset;
        dragStrumlineOffset = strumlineOffset;
    }

    function finishDrag():Void
    {
        FunkinSound.playOnce(Paths.sound("menus/charter/notes/release"), 0.15);

        if (dragStepOffset != 0 || dragColumnOffset != 0 || dragStrumlineOffset != 0)
        {
            var stepLength:Float = conductor.stepLengthMs;

            for (i in 0...selectedNotes.length)
            {
                var from:Int = (i < dragSources.length) ? dragSources[i] : -1;
                if (from < 0 || from >= strumlines.length) continue;

                var note:CharterNote = selectedNotes[i];

                var to:Int = Std.int(FlxMath.bound(from + dragStrumlineOffset, 0, strumlines.length - 1));
                var target = strumlines[to];

                var direction:Int = Std.int(FlxMath.bound(note.direction + dragColumnOffset, 0, target.keys - 1));

                strumlines[from].notes.remove(note);

                note.time += dragStepOffset * stepLength;
                if (note.time < 0) note.time = 0;

                note.direction = direction;

                target.notes.push(note);
            }

            sortAllNotes();
            removeDuplicateNotes();

            for (strumline in strumlines)
                strumline.refreshSustainBounds();

            pushHistory();
            markPreviewDirty();
        }

        isDragging = false;

        dragStepOffset = 0;
        dragColumnOffset = 0;
        dragStrumlineOffset = 0;

        draggedNotes.clear();

        dragDisplayX = [];
        dragDisplayY = [];
        dragDisplayReady = false;
    }

    function handleGridClick(pointer:FlxPoint, stepLength:Float):Void
    {
        var snappedY:Float = pointer.y;

        if (!FlxG.keys.pressed.SHIFT)
            snappedY = GRID_OUTLINE + (Math.floor((pointer.y - GRID_OUTLINE) / (GRID_SIZE * curSnap)) * (GRID_SIZE * curSnap));

        var target:CharterStrumline = null;

        for (strumline in strumlines)
        {
            if (strumline.containsX(pointer.x))
            {
                target = strumline;
                break;
            }
        }

        var inBounds:Bool = target != null && snappedY >= GRID_OUTLINE && snappedY <= GRID_OUTLINE + totalHeight - GRID_SIZE;

        if (!inBounds)
        {
            if (selectedNotes.length > 0) clearSelection();
            return;
        }

        var column:Int = target.columnAt(pointer.x);
        var time:Float = ((snappedY - GRID_OUTLINE) / GRID_SIZE) * stepLength;
        var step:Float = time / stepLength;

        var existing:CharterNote = null;
        var closest:Float = 0.5;

        for (note in target.notes)
        {
            if (note.direction != column) continue;

            var distance:Float = Math.abs((note.time / stepLength) - step);

            if (distance <= closest)
            {
                closest = distance;
                existing = note;
            }
        }

        if (!FlxG.keys.pressed.SHIFT) clearSelection();

        if (existing != null)
        {
            select(existing);
            return;
        }

        var note:CharterNote = new CharterNote(column, time);
        target.notes.push(note);

        target.sortNotes();
        target.refreshSustainBounds();

        select(note);

        FunkinSound.playOnce(Paths.sound("menus/charter/notes/place"), 0.1);

        pushHistory();
        markPreviewDirty();
    }

    function applySelectionBox(stepLength:Float):Void
    {
        if (!FlxG.keys.pressed.SHIFT) clearSelection();

        var rect:FlxRect = FlxRect.get(selectionBox.x, selectionBox.y, selectionBox.scale.x, selectionBox.scale.y);

        for (strumline in strumlines)
            strumline.selectWithin(rect, stepLength, selectedNotes, selectionLookup);

        rect.put();
        markPreviewDirty();
    }

    function selectHoveredStrumline():Void
    {
        if (chart == null) return;

        var pointer = FlxG.mouse.getWorldPosition(camGrid);

        for (strumline in strumlines)
        {
            if (!strumline.containsX(pointer.x)) continue;

            for (note in strumline.notes)
                select(note);

            break;
        }

        pointer.put();
    }

    function resizeSelectedSustains(direction:Int):Void
    {
        if (selectedNotes.length == 0) return;

        var amount:Float = conductor.stepLengthMs;
        if (FlxG.keys.pressed.SHIFT) amount /= 2.0;

        for (note in selectedNotes)
        {
            note.sustain += amount * direction;
            if (note.sustain < 0) note.sustain = 0;
        }

        for (strumline in strumlines)
            strumline.refreshSustainBounds();

        FunkinSound.playOnce(Paths.sound(direction == 1 ? "menus/charter/notes/inflate" : "menus/charter/notes/deflate"), 0.15);

        pushHistory();
        markPreviewDirty();
    }

    function deleteSelected():Void
    {
        if (selectedNotes.length == 0)
            return;

        for (strumline in strumlines)
        {
            var kept:Array<CharterNote> = [];

            for (note in strumline.notes)
                if (!selectionLookup.exists(note)) kept.push(note);

            if (kept.length == strumline.notes.length) continue;

            strumline.notes.resize(0);

            for (note in kept)
                strumline.notes.push(note);
        }

        clearSelection();

        for (strumline in strumlines)
            strumline.refreshSustainBounds();

        FunkinSound.playOnce(Paths.sound("menus/charter/notes/trash"), 0.15);

        pushHistory();
        markPreviewDirty();
    }

    function copySelected():Void
    {
        clipboard = [];

        for (note in selectedNotes)
        {
            var index:Int = strumlineIndexOf(note);
            if (index == -1) continue;

            clipboard.push({note: note.clone(), strumline: index});
        }
    }

    function pasteClipboard():Void
    {
        if (clipboard.length == 0 || chart == null) return;

        var stepLength:Float = conductor.stepLengthMs;
        var snapMs:Float = stepLength * curSnap;

        var earliest:Float = clipboard[0].note.time;
        for (entry in clipboard)
            if (entry.note.time < earliest) earliest = entry.note.time;

        var delta:Float = (Math.round(conductor.songPosition / snapMs) * snapMs) - earliest;

        clearSelection();

        for (entry in clipboard)
        {
            if (entry.strumline >= strumlines.length) continue;

            var note:CharterNote = entry.note.clone();

            note.time += delta;
            if (note.time < 0) note.time = 0;

            strumlines[entry.strumline].notes.push(note);
            select(note);
        }

        sortAllNotes();
        removeDuplicateNotes();

        for (strumline in strumlines)
            strumline.refreshSustainBounds();

        pushHistory();
        markPreviewDirty();
    }

    function select(note:CharterNote):Void
    {
        if (selectionLookup.exists(note)) return;

        selectedNotes.push(note);
        selectionLookup.set(note, true);

        markPreviewDirty();
    }

    function deselect(note:CharterNote):Void
    {
        if (!selectionLookup.exists(note)) return;

        selectedNotes.remove(note);
        selectionLookup.remove(note);

        markPreviewDirty();
    }

    function clearSelection():Void
    {
        if (selectedNotes.length == 0) return;

        selectedNotes = [];
        selectionLookup.clear();

        markPreviewDirty();
    }

    function refreshDraggedNotes():Void
    {
        draggedNotes.clear();
        dragSources = [];

        dragDisplayX = [];
        dragDisplayY = [];
        dragDisplayReady = false;

        var owners:Map<CharterNote, Int> = new Map();

        for (i in 0...strumlines.length)
        {
            for (note in strumlines[i].notes)
                owners.set(note, i);
        }

        for (note in selectedNotes)
        {
            draggedNotes.set(note, true);
            dragSources.push(owners.exists(note) ? owners.get(note) : -1);
        }
    }

    function strumlineIndexOf(note:CharterNote):Int
    {
        for (i in 0...strumlines.length)
            if (strumlines[i].notes.indexOf(note) != -1) return i;

        return -1;
    }

    function sortAllNotes():Void
    {
        for (notes in noteData)
            notes.sort(CharterNote.compare);
    }

    function removeDuplicateNotes():Void
    {
        var removed:Bool = false;

        for (notes in noteData)
        {
            var seen:Map<String, Bool> = new Map();
            var unique:Array<CharterNote> = [];

            for (note in notes)
            {
                var key:String = '${note.time}_${note.direction}';

                if (seen.exists(key))
                {
                    removed = true;
                    continue;
                }

                seen.set(key, true);
                unique.push(note);
            }

            if (unique.length != notes.length)
            {
                notes.resize(0);

                for (note in unique)
                    notes.push(note);
            }
        }

        if (!removed) return;

        var surviving:Array<CharterNote> = [];

        for (note in selectedNotes)
            if (strumlineIndexOf(note) != -1) surviving.push(note);

        if (surviving.length != selectedNotes.length)
        {
            selectedNotes = surviving;
            selectionLookup.clear();

            for (note in selectedNotes)
                selectionLookup.set(note, true);
        }

        markPreviewDirty();
    }

    function markPreviewDirty():Void
    {
        if (preview != null) preview.needsRebuild = true;
    }

    function updatePreview():Void
    {
        if (preview == null || conductorLine == null) return;

        if (preview.needsRebuild)
            preview.rebuild(strumlines, conductor.stepLengthMs, GRID_SIZE, totalHeight, selectionLookup);

        preview.updateIndicators(camGrid.viewTop, camGrid.viewHeight, conductorLine.y, GRID_OUTLINE, totalHeight);
    }

    function updateGridBox():Void
    {
        if (gridBox == null || chart == null) return;

        if (!canInteract || playing || isSelecting || isDragging || mouseOverUI || mouseOverEventStrip() || (preview != null && preview.scrubbing))
        {
            gridBox.visible = false;
            return;
        }

        var pointer = FlxG.mouse.getWorldPosition(camGrid);
        var snappedY:Float = pointer.y;

        if (!FlxG.keys.pressed.SHIFT)
            snappedY = GRID_OUTLINE + (Math.floor((pointer.y - GRID_OUTLINE) / (GRID_SIZE * curSnap)) * (GRID_SIZE * curSnap));

        var hovering:Bool = false;

        if (snappedY >= GRID_OUTLINE && snappedY <= GRID_OUTLINE + totalHeight - GRID_SIZE)
        {
            for (strumline in strumlines)
            {
                if (!strumline.containsX(pointer.x)) continue;

                gridBox.x = strumline.x + GRID_OUTLINE + (strumline.columnAt(pointer.x) * GRID_SIZE);
                gridBox.y = snappedY;
                hovering = true;

                break;
            }
        }

        gridBox.visible = hovering;
        pointer.put();
    }

    function snapshot():EditorSnapshot
    {
        var strumlineState:Array<StrumlineSnapshot> = [];

        for (i in 0...chart.strumlines.length)
        {
            var entry:ChartStrumline = chart.strumlines[i];

            var notes:Array<CharterNote> = [];
            if (i < noteData.length)
                for (note in noteData[i]) notes.push(note.clone());

            var position:Array<Int> = (entry.position != null && entry.position.length >= 2) ? [entry.position[0], entry.position[1]] : [0, 0];

            strumlineState.push
            ({
                id: entry.id ?? 0,
                character: entry.character,
                skin: entry.skin,
                keys: entry.keys ?? 4,
                speed: entry.speed ?? 1.0,
                scale: entry.scale ?? 1.0,
                visible: entry.visible != false,
                playable: entry.playable == true,
                position: position,
                notes: notes
            });
        }

        var events:Array<CharterEvent> = [];
        for (event in eventData) events.push(event.clone());

        return {strumlines: strumlineState, events: events};
    }

    function restore(state:EditorSnapshot):Void
    {
        clearSelection();

        if (playing) togglePlayback();

        isDragging = false;
        isSelecting = false;
        draggedNotes.clear();

        closeEditWindow();
        closeEventWindow();

        eventData.resize(0);
        for (event in state.events) eventData.push(event.clone());
        sortEvents();

        var strumlineState:Array<StrumlineSnapshot> = state.strumlines;

        if (structureMatches(strumlineState))
        {
            for (i in 0...strumlineState.length)
            {
                var notes:Array<CharterNote> = noteData[i];
                notes.resize(0);

                for (note in strumlineState[i].notes)
                    notes.push(note.clone());

                strumlines[i].refreshSustainBounds();
            }

            markPreviewDirty();
            return;
        }

        chart.strumlines = [];
        noteData = [];

        for (s in strumlineState)
        {
            chart.strumlines.push
            ({
                id: s.id,
                character: s.character,
                skin: s.skin,
                position: [s.position[0], s.position[1]],
                scale: s.scale,
                visible: s.visible,
                keys: s.keys,
                speed: s.speed,
                playable: s.playable,
                notes: []
            });

            var notes:Array<CharterNote> = [];
            for (note in s.notes) notes.push(note.clone());
            noteData.push(notes);
        }

        buildStrumlines();
        refreshVocals();

        markPreviewDirty();
    }

    function structureMatches(state:Array<StrumlineSnapshot>):Bool
    {
        if (chart == null || state.length != chart.strumlines.length) return false;
        if (state.length != noteData.length || state.length != strumlines.length) return false;

        for (i in 0...state.length)
        {
            var entry:ChartStrumline = chart.strumlines[i];
            var s:StrumlineSnapshot = state[i];

            if ((entry.id ?? 0) != s.id) return false;
            if (entry.character != s.character) return false;
            if ((entry.keys ?? 4) != s.keys) return false;
            if ((entry.speed ?? 1.0) != s.speed) return false;
            if ((entry.scale ?? 1.0) != s.scale) return false;
            if ((entry.visible != false) != s.visible) return false;
            if ((entry.playable == true) != s.playable) return false;

            var position:Array<Int> = entry.position;
            if (position == null || position.length < 2 || position[0] != s.position[0] || position[1] != s.position[1]) return false;
        }

        return true;
    }

    function pushHistory():Void
    {
        if (historyIndex < history.length - 1)
            history.splice(historyIndex + 1, history.length - historyIndex - 1);

        history.push(snapshot());

        if (history.length > MAX_HISTORY)
            history.shift();
        else
            historyIndex++;

        markPreviewDirty();
    }

    function undo():Void
    {
        if (historyIndex <= 0) return;

        FunkinSound.playOnce(Paths.sound("menus/charter/notes/action"), 0.2);

        historyIndex--;
        restore(history[historyIndex]);
    }

    function redo():Void
    {
        if (historyIndex >= history.length - 1) return;

        FunkinSound.playOnce(Paths.sound("menus/charter/notes/action"), 0.2);

        historyIndex++;
        restore(history[historyIndex]);
    }

    inline function stepAtTime(time:Float):Float
    {
        return conductor.stepLengthMs > 0 ? (time / conductor.stepLengthMs) : 0.0;
    }

    inline function yFromTime(time:Float):Float
    {
        return stepAtTime(time) * GRID_SIZE;
    }

    public function saveChart():Void
    {
        if (chart == null) return;

        syncChartData();

        var data:String = Converter.writeChart(songName, chart);
        var directory:String = songDirectory();

        Paths.createDirectory(directory);
        File.saveContent('$directory/$songName-chart-$difficulty.json', data);

        writeEventsData();

        FunkinSound.playOnce(Paths.sound("menus/charter/save"), 0.3);
    }

    function writeEventsData():Void
    {
        var out:String = Converter.writeEvents(songName, {events: [for (event in eventData) event.toEntry()]});
        var directory:String = songDirectory();

        Paths.createDirectory(directory);
        File.saveContent('$directory/$songName-events.json', out);
    }

    public function saveEvents():Void
    {
        writeEventsData();
        FunkinSound.playOnce(Paths.sound("menus/charter/save"), 0.3);
    }

    public function saveEventsAs():Void
    {
        var out:String = Converter.writeEvents(songName, {events: [for (event in eventData) event.toEntry()]});

        fileReference = new FileReference();
        fileReference.save(out, '$songName-events.json');
    }

    public function saveChartAs():Void
    {
        if (chart == null) return;

        syncChartData();

        fileReference = new FileReference();
        fileReference.save(Converter.writeChart(songName, chart), '$songName-chart-$difficulty.json');
    }

    function songDirectory():String
    {
        var keys:Array<String> =
        [
            'assets/data/songs/$songName/$songName-chart-$difficulty.json',
            'assets/data/songs/$songName/$songName-meta.json',
            'assets/data/songs/$songName/$songName-events.json'
        ];

        for (key in keys)
        {
            var real:String = Converter.resolveRealFile(key);
            if (real != null) return Path.directory(real);
        }

        return 'assets/data/songs/$songName';
    }

    public function exitEditor():Void
    {
        syncChartData();
        EventRegistry.set(songName, {events: [for (event in eventData) event.toEntry()]});

        FlxG.mouse.visible = false;
        Manager.switchState(new PlayState({song: songName, difficulty: difficulty, variation: variation}));
    }

    function buildUI():Void
    {
        topBar = new Bar({position: [0, 0], size: [FlxG.width, Std.int(TOP_BAR_HEIGHT)], items:
        [
            {name: "File", items:
            [
                {text: "Save Chart", altText: "CTRL + S", separate: false, callback: saveChart},
                {text: "Save Chart As...", altText: "CTRL + SHIFT + S", separate: true, callback: saveChartAs},
                {text: "Save Metadata", altText: "CTRL + M", separate: false, callback: saveMetadata},
                {text: "Save Metadata As...", altText: "CTRL + SHIFT + M", separate: true, callback: () -> trace("WIP", "WARNING")},
                {text: "Save Events", altText: "", separate: false, callback: saveEvents},
                {text: "Save Events As...", altText: "", separate: true, callback: saveEventsAs},
                {text: "Import Chart", altText: "", separate: false, callback: () -> trace("WIP", "WARNING")},
                {text: "Export Chart", altText: "", separate: true, callback: () -> exportWindow.windowVisible = !exportWindow.windowVisible},
                {text: "Import Metadata", altText: "", separate: false, callback: () -> trace("WIP", "WARNING")},
                {text: "Export Metadata", altText: "", separate: true, callback: () -> trace("WIP", "WARNING")},
                {text: "Exit", altText: "ESC", separate: false, callback: exitEditor}
            ]},

            {name: "Edit", items:
            [
                {text: "Undo", altText: "CTRL + Z", separate: false, callback: undo},
                {text: "Redo", altText: "CTRL + Y", separate: false, callback: redo}
            ]},

            {name: "Song", items:
            [
                {text: "Edit Metadata", altText: "", separate: false, callback: openMetadataWindow},
                {text: "Conductor Info", altText: "", separate: false, callback: toggleConductorWindow}
            ]},

            {name: "Misc", items:
            [
                {text: "Toggle Welcome Dialog", altText: "", separate: false, callback: () ->
                {
                    welcomeWindow.windowVisible = !welcomeWindow.windowVisible;
                    canInteract = !welcomeWindow.windowVisible;
                }},
                {text: "Reset Zoom", altText: "CTRL + R", separate: false, callback: () -> camZoom = 1.0}
            ]}
        ]});

        topBar.camera = camUI;
        add(topBar);

        buildExportWindow();
        buildConductorWindow();
        buildWelcomeWindow();

        eventTooltip = new CharterEventTooltip();
        eventTooltip.camera = camUI;
        add(eventTooltip);
    }

    function buildConductorWindow():Void
    {
        var w:Int = 300;
        var h:Int = 292;

        var labelX:Int = 24;
        var valueX:Int = 136;

        function rowY(n:Int):Int return 18 + (n * 28);

        var names:Array<String> = ["Position", "Time", "Step", "Beat", "Measure", "BPM", "Step Length", "Beat Length", "State"];

        conductorValues = [];

        var items:Array<FlxSprite> = [];

        for (i in 0...names.length)
        {
            items.push(new Label({position: [labelX, rowY(i) + 4], size: [0.26, 0.26], type: "SOLID", alpha: 0.5, color: 0xFFFFFFFF, text: names[i]}));

            var value = new FlxBitmapText(valueX, rowY(i) + 2, "-", Paths.getAngelFont("jetbrains"));
            value.scale.set(0.3, 0.3);
            value.color = 0xFF7FDBFF;
            value.updateHitbox();

            conductorValues.push(value);
            items.push(value);
        }

        conductorWindow = new InteractiveWindow({position: [0, 0], size: [w, h], title: "Conductor", minimiziable: true, items: items, callback: null});
        conductorWindow.windowVisible = false;
        conductorWindow.camera = camUI;
        centerWindow(conductorWindow);
        conductorWindow.borderOffsetBottom = EVENT_STRIP_BOUND;
        conductorWindow.borderOffsetY = Std.int(TOP_BAR_HEIGHT);
        add(conductorWindow);
    }

    function toggleConductorWindow():Void
    {
        if (conductorWindow == null) return;

        conductorWindow.windowVisible = !conductorWindow.windowVisible;
    }

    function updateConductorWindow():Void
    {
        if (conductorWindow == null || !conductorWindow.windowVisible) return;

        setConductorValue(0, round1(conductor.songPosition) + " ms");
        setConductorValue(1, formatClock(conductor.songPosition));
        setConductorValue(2, conductor.currentStep + "  (" + round2(conductor.currentStepTime) + ")");
        setConductorValue(3, conductor.currentBeat + "  (" + round2(conductor.currentBeatTime) + ")");
        setConductorValue(4, conductor.currentMeasure + "  (" + round2(conductor.currentMeasureTime) + ")");
        setConductorValue(5, "" + round2(conductor.bpm));
        setConductorValue(6, round2(conductor.stepLengthMs) + " ms");
        setConductorValue(7, round2(conductor.beatLengthMs) + " ms");
        setConductorValue(8, playing ? "Playing" : "Paused");
    }

    function setConductorValue(index:Int, text:String):Void
    {
        if (index < conductorValues.length)
            conductorValues[index].text = text;
    }

    inline function round1(value:Float):Float
    {
        return Math.round(value * 10) / 10;
    }

    inline function round2(value:Float):Float
    {
        return Math.round(value * 100) / 100;
    }

    function formatClock(ms:Float):String
    {
        var total:Int = Std.int(ms / 1000);
        if (total < 0) total = 0;

        return Std.int(total / 60) + ":" + StringTools.lpad(Std.string(total % 60), "0", 2);
    }

    function buildExportWindow():Void
    {
        var warning:Label = new Label({position: [33, 83], size: [0.2, 0.2], type: "SOLID", alpha: 0.5, color: 0xFFFFFFFF,
            text: "* NOTE: Only Strumlines\nwith the ID of 0 and 1 will\nbe exported for this format."});
        warning.alpha = 0;

        var formats:Array<String> = ["RevEngine", "Legacy", "V-Slice", "Codename", "Psych", "FPS Plus", "osu!", "StepMania", "Clone Hero", "Quaver"];
        var items = [];

        for (format in formats)
            items.push({name: format, callback: null});

        exportWindow = new InteractiveWindow({position: [0, 0], size: [200, 320], title: "Export", minimiziable: false, items:
        [
            new Label({position: [33, 32], size: [0.25, 0.25], type: "SOLID", alpha: 0.5, color: 0xFFFFFFFF, text: "Format:"}),
            warning,
            new Dropdown({position: [35, 50], size: [130, 30], items: items, callback: (selected:String) ->
            {
                warning.alpha = ["RevEngine", "Codename"].contains(selected) ? 0 : 0.5;
            }}),

            new Label({position: [50, 209], size: [0.2, 0.2], type: "SOLID", alpha: 0.6, color: 0xFFFFFFFF, text: "Compress as .ZIP"}),
            new Label({position: [50, 240], size: [0.2, 0.2], type: "SOLID", alpha: 0.6, color: 0xFFFFFFFF, text: "Export with Audio Files"}),

            new Checkbox({position: [22, 203], size: [25, 25], callback: null}),
            new Checkbox({position: [22, 233], size: [25, 25], callback: null}),

            new Button({position: [60, 267], size: [80, 35], text: "Export", callback: () -> trace("WIP", "WARNING")})
        ], callback: (value:Bool) -> canInteract = !value});

        exportWindow.windowVisible = false;
        centerWindow(exportWindow);
        exportWindow.camera = camUI;
        exportWindow.borderOffsetBottom = EVENT_STRIP_BOUND;
        exportWindow.borderOffsetY = Std.int(TOP_BAR_HEIGHT);
        add(exportWindow);
    }

    function buildWelcomeWindow():Void
    {
        var title:String = "Welcome! (Currently charting " + ((meta != null && meta.name != null) ? meta.name : songName) + ")";

        var binds:Array<Array<String>> =
        [
            ["LEFT CLICK: Place / Select a Note", "RIGHT CLICK: Delete a Note"],
            ["CLICK + DRAG: Move / Box-Select", "SHIFT: Disable Grid Snapping"],
            ["CTRL + C: Copy Selected Notes", "CTRL + V: Paste Notes at Playhead"],
            ["CTRL + A: Select Strumline Notes", "DELETE: Delete Selected Notes"],
            ["Q / E: Change Sustain Length", "Z / X: Change Grid Snap"],
            ["CTRL + Z: Undo", "CTRL + X / Y: Redo"],
            ["SPACE: Play / Pause", "W / S / SCROLL: Move Playhead"],
            ["SCROLL BAR (right): Seek Song", "TAB / ALT + SCROLL: Pan Camera"],
            ["CTRL + SCROLL: Zoom In / Out", "CTRL + R: Reset Zoom"],
            ["CTRL + SPACE: Add a Strumline", "EDIT BUTTON: Edit a Strumline"],
            ["CTRL + S: Save Chart", "CTRL + SHIFT + S: Save Chart As"],
            ["ESC: Exit the Editor", ""]
        ];

        var keybinds:String = "";
        for (i in 0...binds.length)
        {
            keybinds += StringTools.rpad(binds[i][0], " ", 38) + binds[i][1];

            if (i < binds.length - 1)
                keybinds += "\n";
        }

        var w:Int = 700;
        var h:Int = 430;

        welcomeWindow = new InteractiveWindow({position: [0, 0], size: [w, h], title: "RevEngine Chart Editor (PROTOTYPE)", minimiziable: false, items:
        [
            new Label({position: [20, 16], size: [0.4, 0.4], type: "SOLID", alpha: 1.0, color: 0xFFFFFFFF, text: title}),
            new Separator({position: [24, 50], size: [w - 48, 3], alpha: 0.4, color: 0xFFFFFFFF, blending: true}),

            new Label({position: [20, 62], size: [0.3, 0.3], type: "SOLID", alpha: 1.0, color: 0xFFFFFFFF, text: "Keybinds:"}),
            new Label({position: [20, 92], size: [0.22, 0.22], type: "SOLID", alpha: 1.0, color: 0xFFFFFFFF, text: keybinds}),

            new Separator({position: [24, 336], size: [w - 48, 3], alpha: 0.4, color: 0xFFFFFFFF, blending: true}),
            new Label({position: [20, 348], size: [0.24, 0.24], type: "SOLID", alpha: 1.0, color: 0xFFFFFFFF,
                text: "Once you're ready to start charting, click Begin or just close this window!"}),

            new Button({position: [Std.int((w - 96) / 2), 380], size: [96, 36], text: "Begin", callback: () ->
            {
                welcomeWindow.windowVisible = false;
                canInteract = true;
            }})
        ], callback: (value:Bool) -> canInteract = !value});

        welcomeWindow.camera = camUI;
        centerWindow(welcomeWindow);
        welcomeWindow.borderOffsetBottom = EVENT_STRIP_BOUND;
        welcomeWindow.borderOffsetY = Std.int(TOP_BAR_HEIGHT);
        add(welcomeWindow);
    }

    function listCharacters():Array<String>
    {
        var names:Array<String> = [];

        for (file in Paths.readDirectory("data/characters"))
        {
            if (Path.extension(file) != "json") continue;
            names.push(Path.withoutExtension(file));
        }

        names.sort(function(a, b) return (a < b) ? -1 : (a > b) ? 1 : 0);

        if (names.length == 0) names.push("bf");

        return names;
    }

    function listNoteskins():Array<String>
    {
        var names:Array<String> = [];

        for (file in Paths.readDirectory("data/notes/styles"))
        {
            if (Path.extension(file) != "json") continue;
            names.push(Path.withoutExtension(file));
        }

        names.sort(function(a, b) return (a < b) ? -1 : (a > b) ? 1 : 0);

        if (names.length == 0) names.push("default");

        return names;
    }

    function openEditWindow(index:Int):Void
    {
        if (chart == null || index < 0 || index >= chart.strumlines.length) return;

        closeEditWindow();
        editIndex = index;

        var entry:ChartStrumline = chart.strumlines[index];

        var w:Int = 340;
        var h:Int = 498;

        var labelX:Int = 20;
        var ctrlX:Int = 150;
        var ctrlW:Int = 168;
        var ctrlH:Int = 34;

        function rowY(n:Int):Int return 22 + (n * 46);
        function labelY(n:Int):Int return rowY(n) + 9;

        var characterDropdown = new Dropdown({position: [ctrlX, rowY(0) + 2], size: [ctrlW, 30],
            items: [for (name in listCharacters()) {name: name, callback: null}], callback: null});

        var playableBox = new Checkbox({position: [ctrlX, rowY(1)], size: [30, 30], callback: null});
        playableBox.value = (entry.playable == true);

        var keysStepper = new Stepper({position: [ctrlX, rowY(2)], size: [ctrlW, ctrlH], type: "Int", args: [1, 9, 1], callback: null});
        keysStepper.setValue(entry.keys ?? 4);

        var speedStepper = new Stepper({position: [ctrlX, rowY(3)], size: [ctrlW, ctrlH], type: "Float", args: [0.1, 20.0, 0.1], callback: null});
        speedStepper.setValue(entry.speed ?? 1.0);

        var scaleStepper = new Stepper({position: [ctrlX, rowY(4)], size: [ctrlW, ctrlH], type: "Float", args: [0.1, 5.0, 0.05], callback: null});
        scaleStepper.setValue(entry.scale ?? 1.0);

        var visibleBox = new Checkbox({position: [ctrlX, rowY(5)], size: [30, 30], callback: null});
        visibleBox.value = (entry.visible != false);

        var skinDropdown = new Dropdown({position: [ctrlX, rowY(6) + 2], size: [ctrlW, 30],
            items: [for (name in listNoteskins()) {name: name, callback: null}], callback: null});

        var posValues:Array<Int> = (entry.position != null && entry.position.length >= 2) ? entry.position : [0, 0];

        var posXInput = new InputBox({position: [ctrlX, rowY(7)], size: [80, ctrlH], type: "NUMBER", callback: null});
        posXInput.setText(Std.string(posValues[0]));

        var posYInput = new InputBox({position: [ctrlX + 88, rowY(7)], size: [80, ctrlH], type: "NUMBER", callback: null});
        posYInput.setText(Std.string(posValues[1]));

        var idInput = new InputBox({position: [ctrlX, rowY(8)], size: [100, ctrlH], type: "INTEGER", callback: null});
        idInput.setText(Std.string(entry.id ?? 0));

        characterDropdown.selectItem(entry.character ?? "bf");
        skinDropdown.selectItem(entry.skin ?? "default");

        var saveButton = new Button({position: [w - 186, h - 50], size: [86, 36], text: "Save", callback: function()
        {
            var newId:Null<Int> = Std.parseInt(idInput.value);

            if (newId == null)
            {
                trace("Strumline ID must be a whole number.", "WARNING");
                return;
            }

            if (idInUse(newId, editIndex))
            {
                trace('Strumline ID $newId is already used by another strumline; not saving.', "WARNING");
                return;
            }

            var newKeys:Int = Std.int(keysStepper.currentValue);

            entry.id = newId;
            entry.playable = playableBox.value;
            entry.character = characterDropdown.selectedItem;
            entry.skin = skinDropdown.selectedItem;
            entry.keys = newKeys;
            entry.speed = speedStepper.currentValue;
            entry.scale = scaleStepper.currentValue;
            entry.visible = visibleBox.value;
            entry.position = [parseIntSafe(posXInput.value), parseIntSafe(posYInput.value)];

            if (editIndex < noteData.length)
            {
                for (note in noteData[editIndex])
                {
                    if (note.direction >= newKeys)
                        note.direction = newKeys - 1;
                    
                    if (note.direction < 0)
                        note.direction = 0;
                }
            }

            FunkinSound.playOnce(Paths.sound("menus/charter/save"), 0.3);
            pendingRebuild = true;
        }});

        var deleteButton = new Button({position: [w - 92, h - 50], size: [86, 36], text: "Delete", callback: function()
        {
            pendingDelete = editIndex;
        }});

        var items:Array<FlxSprite> =
        [
            editLabel("Character", labelX, labelY(0)),
            editLabel("Playable", labelX, labelY(1)),
            editLabel("Keys", labelX, labelY(2)),
            editLabel("Speed", labelX, labelY(3)),
            editLabel("Scale", labelX, labelY(4)),
            editLabel("Visible", labelX, labelY(5)),
            editLabel("Skin", labelX, labelY(6)),
            editLabel("Position", labelX, labelY(7)),
            editLabel("ID", labelX, labelY(8)),

            playableBox,
            keysStepper,
            speedStepper,
            scaleStepper,
            visibleBox,
            posXInput,
            posYInput,
            idInput,
            saveButton,
            deleteButton,
            skinDropdown,
            characterDropdown
        ];

        editWindow = new InteractiveWindow({position: [0, 0], size: [w, h], title: "Edit Strumline " + (entry.id ?? 0), minimiziable: false,
            items: items, callback: function(open:Bool)
            {
                if (!open) editIndex = -1;
            }});

        editWindow.camera = camUI;
        centerWindow(editWindow);
        editWindow.borderOffsetBottom = EVENT_STRIP_BOUND;
        editWindow.borderOffsetY = Std.int(TOP_BAR_HEIGHT);
        add(editWindow);
    }

    function editLabel(text:String, x:Int, y:Int, scale:Float = 0.3):Label
    {
        return new Label({position: [x, y], size: [scale, scale], type: "SOLID", alpha: 0.9, color: 0xFFFFFFFF, text: text});
    }

    function listEventTypes():Array<String>
    {
        if (!EventObjectRegistry.list.keys().hasNext())
            EventObjectRegistry.init();

        var names:Array<String> = [];

        for (data in EventObjectRegistry.list)
        {
            if (data == null || data.name == null) continue;
            if (names.indexOf(data.name) == -1) names.push(data.name);
        }

        names.sort(function(a, b) return (a < b) ? -1 : (a > b) ? 1 : 0);
        return names;
    }

    function resolveEventTypeName(name:String):String
    {
        var data:EventObjectData = EventObjectRegistry.findByName(name);
        return (data != null && data.name != null) ? data.name : name;
    }

    function openEventWindow(?event:CharterEvent, ?time:Float):Void
    {
        closeEventWindow();

        var types:Array<String> = listEventTypes();

        if (types.length == 0)
        {
            trace("No event definitions found in data/events.", "WARNING");
            return;
        }

        editingEvent = event;
        pendingEventTime = (time != null) ? time : ((event != null) ? event.time : conductor.songPosition);

        var w:Int = 380;
        var h:Int = 470;

        var labelX:Int = 20;
        var ctrlX:Int = 120;

        eventContentWidth = w - 40;

        var startName:String = (event != null) ? resolveEventTypeName(event.name) : types[0];
        if (types.indexOf(startName) == -1) startName = types[0];

        eventVarWidgets = [];

        eventDescription = new FlxBitmapText(0, 0, "", Paths.getAngelFont("jetbrains"));
        eventDescription.scale.set(0.24, 0.24);
        eventDescription.color = 0xFFFFFFFF;
        eventDescription.alpha = 0.65;
        eventDescription.autoSize = false;
        eventDescription.wordWrap = true;
        eventDescription.fieldWidth = Std.int((w - 40) / 0.24);
        eventDescription.setPosition(labelX, 62);
        eventDescription.updateHitbox();

        eventContainer = new ScrollContainer({position: [labelX, 150], size: [w - 40, h - 150 - 62]});

        var typeItems = [for (name in types) {name: name, callback: null}];

        var typeDropdown = new Dropdown({position: [ctrlX, 14], size: [w - ctrlX - 20, 30], items: typeItems,
            callback: (selected:String) -> rebuildEventFields(selected)});

        var saveButton = new Button({position: [w - 96, h - 46], size: [80, 34], text: "Save", callback: function()
        {
            var selectedName:String = typeDropdown.selectedItem;

            var vars:Array<String> = [];
            for (widget in eventVarWidgets) vars.push(readWidgetValue(widget));

            if (editingEvent != null)
            {
                editingEvent.name = selectedName;
                editingEvent.variables = vars;
            }
            else
                eventData.push(new CharterEvent(selectedName, pendingEventTime, vars));

            sortEvents();
            pushHistory();

            FunkinSound.playOnce(Paths.sound("menus/charter/save"), 0.3);
            pendingEventClose = true;
        }});

        var items:Array<FlxSprite> =
        [
            editLabel("Event", labelX, 22),
            new Separator({position: [labelX, 52], size: [w - 40, 3], alpha: 0.4, color: 0xFFFFFFFF, blending: true}),
            eventDescription,
            eventContainer,
            saveButton
        ];

        if (event != null)
        {
            items.push(new Button({position: [w - 186, h - 46], size: [80, 34], text: "Delete", callback: function()
            {
                if (editingEvent != null) deleteEvent(editingEvent);
                pendingEventClose = true;
            }}));
        }

        items.push(typeDropdown);

        eventWindow = new InteractiveWindow({position: [0, 0], size: [w, h], title: (event != null) ? "Edit Event" : "Create Event",
            minimiziable: false, items: items, callback: (open:Bool) -> canInteract = !open});

        eventWindow.camera = camUI;
        centerWindow(eventWindow);
        eventWindow.borderOffsetBottom = EVENT_STRIP_BOUND;
        eventWindow.borderOffsetY = Std.int(TOP_BAR_HEIGHT);
        add(eventWindow);

        typeDropdown.selectItem(startName);
        rebuildEventFields(startName);
    }

    function rebuildEventFields(typeName:String):Void
    {
        if (eventContainer == null) return;

        var data:EventObjectData = EventObjectRegistry.findByName(typeName);

        if (eventDescription != null)
        {
            eventDescription.text = (data != null && data.description != null) ? data.description : "";
            eventDescription.updateHitbox();
        }

        eventContainer.clearContent();
        eventVarWidgets = [];

        if (data == null || data.variables == null) return;

        var rowHeight:Float = 44;
        var labelX:Float = 4;

        var reuse:Bool = (editingEvent != null && data.name == editingEvent.name);

        var labels:Array<Label> = [];
        var maxLabelWidth:Float = 0;

        for (def in data.variables)
        {
            if (def == null) continue;

            var label = new Label({position: [0, 0], size: [0.26, 0.26], type: "SOLID", alpha: 0.9, color: 0xFFFFFFFF, text: def.name});
            labels.push(label);

            if (label.width > maxLabelWidth) maxLabelWidth = label.width;
        }

        var fieldX:Float = labelX + maxLabelWidth + 12;

        var boxWidth:Int = eventContentWidth - Std.int(fieldX) - 14;
        if (boxWidth < 60) boxWidth = 60;
        eventFieldWidth = boxWidth;

        var row:Int = 0;

        for (i in 0...data.variables.length)
        {
            var def = data.variables[i];
            if (def == null) continue;

            var value:String = (reuse && i < editingEvent.variables.length)
                ? editingEvent.variables[i]
                : ((def.defaultValue != null) ? def.defaultValue : "");

            var rowY:Float = row * rowHeight;

            eventContainer.addContent(labels[row], labelX, rowY + 13, rowHeight);

            var widget:FlxSprite = makeVariableWidget(def.type, value);
            eventContainer.addContent(widget, fieldX, rowY + 4, rowHeight);

            eventVarWidgets.push(widget);

            row++;
        }
    }

    function makeVariableWidget(type:String, value:String):FlxSprite
    {
        switch (type)
        {
            case "Bool":
                var box = new Checkbox({position: [0, 0], size: [30, 30], callback: null});
                box.value = (value == "true" || value == "1");
                return box;

            case "Int":
                var input = new InputBox({position: [0, 0], size: [eventFieldWidth, 32], type: "INTEGER", callback: null});
                input.setText(value);
                return input;

            case "Float":
                var input = new InputBox({position: [0, 0], size: [eventFieldWidth, 32], type: "NUMBER", callback: null});
                input.setText(value);
                return input;

            case "Noteskin":
                var names:Array<String> = listNoteskins();

                var dropdown = new Dropdown({position: [0, 0], size: [eventFieldWidth, 30],
                    items: [for (name in names) {name: name, callback: null}], callback: null});

                dropdown.selectItem((value != null && names.indexOf(value) != -1) ? value : names[0]);
                return dropdown;

            default:
                var input = new InputBox({position: [0, 0], size: [eventFieldWidth, 32], type: "ANY", callback: null});
                input.setText(value);
                return input;
        }
    }

    function readWidgetValue(widget:FlxSprite):String
    {
        if (Std.isOfType(widget, InputBox)) return (cast widget:InputBox).value;
        if (Std.isOfType(widget, Checkbox)) return (cast widget:Checkbox).value ? "true" : "false";
        if (Std.isOfType(widget, Dropdown)) return (cast widget:Dropdown).selectedItem;

        return "";
    }

    function closeEventWindow():Void
    {
        if (eventWindow != null)
        {
            eventWindow.windowVisible = false;
            UiManager.unregister(eventWindow);

            remove(eventWindow);
            eventWindow.destroy();

            eventWindow = null;
        }

        editingEvent = null;
        eventContainer = null;
        eventDescription = null;
        eventVarWidgets = [];
    }

    function openMetadataWindow():Void
    {
        if (meta == null) return;

        closeMetadataWindow();

        var w:Int = 650;
        var h:Int = 476;

        var lLabel:Int = 20;
        var lCtrl:Int = 128;
        var rLabel:Int = 336;
        var rCtrl:Int = 452;
        var ctrlW:Int = 168;

        function rowY(n:Int):Int return 20 + (n * 44);
        function labelY(n:Int):Int return rowY(n) + 8;

        var characters:Array<String> = listCharacters();
        var stages:Array<String> = listStages();

        // left
        var nameInput = metaInput(lCtrl, rowY(0), ctrlW, "ANY", metaString("name"), null);
        var iconInput = metaInput(lCtrl, rowY(1), ctrlW, "ANY", metaString("icon"), characters);
        var stageInput = metaInput(lCtrl, rowY(2), ctrlW, "ANY", metaString("stage"), stages);
        var bpmInput = metaInput(lCtrl, rowY(3), ctrlW, "NUMBER", Std.string(meta.bpm), null);
        var albumInput = metaInput(lCtrl, rowY(4), ctrlW, "ANY", metaAlbumString("name", "unknown"), null);
        var previewInput = metaInput(lCtrl, rowY(5), ctrlW, "NUMBER", Std.string(meta.album.previewTimestamp), null);
        var countdownSkinInput = metaInput(lCtrl, rowY(6), ctrlW, "ANY", metaSubString("countdown", "skin", "default"), null);
        var countdownAudioInput = metaInput(lCtrl, rowY(7), ctrlW, "ANY", metaSubString("countdown", "audio", "default"), null);

        // right
        var composersInput = metaInput(rCtrl, rowY(0), ctrlW, "ANY", csvJoin(meta.composers), null);
        var artistsInput = metaInput(rCtrl, rowY(1), ctrlW, "ANY", csvJoin(meta.artists), null);
        var chartersInput = metaInput(rCtrl, rowY(2), ctrlW, "ANY", csvJoin(meta.charters), null);
        var ratingsSkinInput = metaInput(rCtrl, rowY(3), ctrlW, "ANY", metaSubString("ratings", "skin", "default"), null);
        var ratingsInput = metaInput(rCtrl, rowY(4), ctrlW, "ANY", formatRatings(meta.album.ratings), null);

        var hideBox = new Checkbox({position: [rCtrl + 40, rowY(5)], size: [28, 28], callback: null});
        hideBox.value = (meta.freeplay.hide == true);

        var newlyBox = new Checkbox({position: [rCtrl + 40, rowY(6)], size: [28, 28], callback: null});
        newlyBox.value = (meta.freeplay.newlyAdded == true);

        var closeButton = new Button({position: [w - 104, h - 46], size: [88, 36], text: "Close", callback: function()
        {
            var newBpm:Float = parseFloatSafe(bpmInput.value, meta.bpm);

            meta.name = nameInput.value;
            meta.icon = iconInput.value;
            meta.stage = stageInput.value;

            meta.album.name = albumInput.value;
            meta.album.previewTimestamp = parseFloatSafe(previewInput.value, 0.0);
            meta.album.ratings = parseRatings(ratingsInput.value);

            meta.freeplay.hide = hideBox.value;
            meta.freeplay.newlyAdded = newlyBox.value;

            meta.composers = csvSplit(composersInput.value);
            meta.artists = csvSplit(artistsInput.value);
            meta.charters = csvSplit(chartersInput.value);

            meta.countdown.skin = countdownSkinInput.value;
            meta.countdown.audio = countdownAudioInput.value;
            meta.ratings.skin = ratingsSkinInput.value;

            if (newBpm > 0 && newBpm != meta.bpm)
            {
                meta.bpm = newBpm;
                conductor.setBPM(newBpm);
                pendingMetaRelayout = true;
            }

            pendingCloseMeta = true;
        }});

        var ls:Float = 0.26;

        var items:Array<FlxSprite> =
        [
            editLabel("Name", lLabel, labelY(0), ls),
            editLabel("Icon", lLabel, labelY(1), ls),
            editLabel("Stage", lLabel, labelY(2), ls),
            editLabel("BPM", lLabel, labelY(3), ls),
            editLabel("Album", lLabel, labelY(4), ls),
            editLabel("Preview", lLabel, labelY(5), ls),
            editLabel("Count Skin", lLabel, labelY(6), ls),
            editLabel("Count SFX", lLabel, labelY(7), ls),

            editLabel("Composers", rLabel, labelY(0), ls),
            editLabel("Artists", rLabel, labelY(1), ls),
            editLabel("Charters", rLabel, labelY(2), ls),
            editLabel("Rank Skin", rLabel, labelY(3), ls),
            editLabel("Ratings", rLabel, labelY(4), ls),
            editLabel("Hide From Freeplay", rLabel, labelY(5), ls),
            editLabel("Mark as Newly Added", rLabel, labelY(6), ls),

            new Label({position: [lLabel, h - 68], size: [0.24, 0.24], type: "SOLID", alpha: 0.55, color: 0xFFFFFFFF,
                text: "Lists are comma-separated values.\nRatings are difficulty:stars   (use * for all)."}),

            nameInput, iconInput, stageInput, bpmInput, albumInput, previewInput, countdownSkinInput, countdownAudioInput,
            composersInput, artistsInput, chartersInput, ratingsSkinInput, ratingsInput,
            hideBox, newlyBox, closeButton
        ];

        metaWindow = new InteractiveWindow({position: [0, 0], size: [w, h], title: "Song Metadata", minimiziable: false,
            items: items, callback: function(open:Bool) canInteract = !open});

        metaWindow.camera = camUI;
        centerWindow(metaWindow);
        metaWindow.borderOffsetBottom = EVENT_STRIP_BOUND;
        metaWindow.borderOffsetY = Std.int(TOP_BAR_HEIGHT);
        add(metaWindow);
    }

    function metaInput(x:Int, y:Int, width:Int, type:String, value:String, ?autocomplete:Array<String>):InputBox
    {
        var box = new InputBox({position: [x, y], size: [width, 32], type: type, autocompleteList: autocomplete, callback: null});
        box.setText(value);

        return box;
    }

    function closeMetadataWindow():Void
    {
        if (metaWindow != null)
        {
            metaWindow.windowVisible = false;
            UiManager.unregister(metaWindow);

            remove(metaWindow);
            metaWindow.destroy();

            metaWindow = null;
        }
    }

    public function saveMetadata():Void
    {
        if (meta == null) return;

        writeMetadata();
        FunkinSound.playOnce(Paths.sound("menus/charter/save"), 0.3);
    }

    function writeMetadata():Void
    {
        if (meta == null) return;

        var directory:String = songDirectory();
        Paths.createDirectory(directory);

        File.saveContent('$directory/$songName-meta$variation.json', haxe.Json.stringify(meta, null, "\t"));
    }

    function metaString(field:String):String
    {
        var value:Dynamic = Reflect.field(meta, field);
        return (value != null) ? Std.string(value) : "";
    }

    function metaAlbumString(field:String, fallback:String):String
    {
        if (meta.album == null) return fallback;
        var value:Dynamic = Reflect.field(meta.album, field);
        return (value != null) ? Std.string(value) : fallback;
    }

    function metaSubString(group:String, field:String, fallback:String):String
    {
        var sub:Dynamic = Reflect.field(meta, group);
        if (sub == null) return fallback;

        var value:Dynamic = Reflect.field(sub, field);
        return (value != null) ? Std.string(value) : fallback;
    }

    function csvJoin(arr:Array<String>):String
    {
        return (arr != null) ? arr.join(", ") : "";
    }

    function csvSplit(text:String):Array<String>
    {
        var out:Array<String> = [];
        if (text == null) return out;

        for (part in text.split(","))
        {
            var trimmed:String = StringTools.trim(part);
            if (trimmed != "") out.push(trimmed);
        }

        return out;
    }

    function formatRatings(ratings:Array<Dynamic>):String
    {
        if (ratings == null) return "";

        var parts:Array<String> = [];

        for (entry in ratings)
        {
            if (entry == null) continue;

            var difficulty:String = (entry.difficulty != null && entry.difficulty != "") ? entry.difficulty : "*";
            var rating:Int = (entry.rating != null) ? entry.rating : 1;

            parts.push('$difficulty:$rating');
        }

        return parts.join(", ");
    }

    function parseRatings(text:String):Array<Dynamic>
    {
        var out:Array<Dynamic> = [];
        if (text == null) return out;

        for (part in text.split(","))
        {
            var trimmed:String = StringTools.trim(part);
            if (trimmed == "") continue;

            var pair:Array<String> = trimmed.split(":");
            var difficulty:String = StringTools.trim(pair[0]);
            if (difficulty == "") difficulty = "*";

            var rating:Int = (pair.length > 1) ? parseIntSafe(StringTools.trim(pair[1])) : 1;

            out.push({difficulty: difficulty, rating: rating});
        }

        return out;
    }

    function listStages():Array<String>
    {
        var names:Array<String> = [];

        for (file in Paths.readDirectory("data/stages"))
        {
            if (Path.extension(file) != "json") continue;
            names.push(Path.withoutExtension(file));
        }

        names.sort(function(a, b) return (a < b) ? -1 : (a > b) ? 1 : 0);

        return names;
    }

    function parseFloatSafe(s:String, fallback:Float):Float
    {
        var v:Null<Float> = Std.parseFloat(s);
        return (v == null || Math.isNaN(v)) ? fallback : v;
    }

    function closeEditWindow():Void
    {
        if (editWindow != null)
        {
            editWindow.windowVisible = false;
            UiManager.unregister(editWindow);

            remove(editWindow);
            editWindow.destroy();

            editWindow = null;
        }

        editIndex = -1;
    }

    function parseIntSafe(s:String):Int
    {
        var v:Null<Int> = Std.parseInt(s);
        return (v == null) ? 0 : v;
    }

    override function destroy():Void
    {
        super.destroy();

        destroyTracks();

        if (hitsound != null)
        {
            hitsound.stop();
            hitsound.destroy();
            hitsound = null;
        }

        for (point in [selectionStart, dragStartPos, camOffset, currentCamOffset])
        {
            if (point != null)
                point.put();
        }

        selectionStart = null;
        dragStartPos = null;
        camOffset = null;
        currentCamOffset = null;

        selectionLookup.clear();
        draggedNotes.clear();

        strumlineBoxes = [];
        editWindow = null;
        metaWindow = null;
        conductorWindow = null;
        conductorValues = [];

        eventLane = null;
        eventTooltip = null;
        eventWindow = null;
        eventContainer = null;
        eventDescription = null;
        eventVarWidgets = [];
        editingEvent = null;
        eventData = [];
    }
}

typedef ClipboardNote =
{
    var note:CharterNote;
    var strumline:Int;
}

typedef StrumlineSnapshot =
{
    var id:Int;
    var character:String;
    var skin:String;
    var keys:Int;
    var speed:Float;
    var scale:Float;
    var visible:Bool;
    var playable:Bool;
    var position:Array<Int>;
    var notes:Array<CharterNote>;
}

typedef EditorSnapshot =
{
    var strumlines:Array<StrumlineSnapshot>;
    var events:Array<CharterEvent>;
}