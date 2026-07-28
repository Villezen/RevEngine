package backend.display;

import haxe.ds.Vector;

import backend.utils.MathUtil;
import backend.utils.MemoryUtil;
import backend.utils.GitHubUtil;

import openfl.display.Sprite;
import openfl.display.Shape;

import openfl.text.TextFormat;
import openfl.text.TextField;
import openfl.Lib;

import flixel.FlxState;
import flixel.FlxSubState;
import flixel.math.FlxPoint;
import flixel.FlxBasic;
import flixel.math.FlxMath;
import flixel.util.FlxStringUtil;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

#if lime
import lime.graphics.opengl.GL;
#end

#if sys
import sys.thread.Thread;
#end

enum DisplayType
{
    HIDDEN;
    SIMPLE;
    MEMORY;
    ADVANCED;
}

typedef CachedSpriteData =
{
    var total:Int;
    var visible:Int;
    var drawn:Int;
}

/**
 * An OpenFL display object used for displaying debug information.
 */
class DEBUG extends Sprite
{
    public var currentDisplayType:DisplayType = SIMPLE;
    public var infoTextToggle:Bool = false;

    public var textBox:Shape;
    public var infoBox:Shape;

    public var engineTitle:TextField;
    public var engineBody:TextField;

    public var sysTitle:TextField;
    public var sysBody:TextField;

    public var condTitle:TextField;
    public var posText:TextField;
    public var stepText:TextField;
    public var beatText:TextField;
    public var measureText:TextField;

    public var stateTitle:TextField;
    public var stateBody:TextField;

    private var _infoFields:Array<TextField> = [];

    private var _titleFormat:TextFormat;
    private var _bodyFormat:TextFormat;

    public var framerateText:TextField;
    public var memoryText:TextField;
    public var framerateGraph:GRAPH;
    public var memoryGraph:GRAPH;
    public var currentFPS(default, null):Int = 0;
    public var peakFPS(default, null):Int = 0;
    public var peakMEM(default, null):Float = 0;
    private var cacheCount:Int = 0;
    private var currentTime:Float = 0;

    private static inline var FPS_BUFFER_SIZE:Int = 512;
    private var frameTimes:Vector<Float> = new Vector(FPS_BUFFER_SIZE);
    private var frameHead:Int = 0;
    private var frameCount:Int = 0;

    private var graphTimer:Float = 0;
    private var lastDrawnFPS:Int = -1;
    private var lastGcMEM:Float = -1;
    private var lastTaskMEM:Float = -1;

    public var osName:String = "Fetching...";
    public var cpuName:String = "Fetching...";
    public var gpuName:String = "Fetching...";
    public var githubCommit:String = "Fetching...";
    
    private var engineInfoString:String = "";
    private var systemInfoString:String = "";
    private var statsTimer:Float = 0;
    private var cachedSprites:CachedSpriteData = {total: 0, visible: 0, drawn: 0};

    private var cachedState:FlxState = null;
    private var cachedSubState:FlxSubState = null;
    private var cachedStateName:String = "";
    private var cachedSubStateName:String = "";

    private var targetInfoWidth:Float = 0;
    private var targetInfoHeight:Float = 0;
    private var targetFrameWidth:Float = 0;
    private var targetFrameHeight:Float = 15;
    private var targetMemWidth:Float = 0;
    private var targetMemHeight:Float = 15;

    public function new()
    {
        super();

        textBox = new Shape();
        textBox.graphics.beginFill(0x000000);
        textBox.graphics.drawRect(0, 0, 1, 30); 
        textBox.graphics.endFill();
        textBox.alpha = 0.4;
        addChild(textBox);

        infoBox = new Shape();
        infoBox.graphics.beginFill(0x000000);
        infoBox.graphics.drawRect(0, 0, 1, 30); 
        infoBox.graphics.endFill();
        infoBox.alpha = 0.4;
        addChild(infoBox);

        _titleFormat = new TextFormat('Monsterrat', 13, 0xFF7FDBFF, true);
        _bodyFormat = new TextFormat('Monsterrat', 10, 0xFFFFFF);

        engineTitle = makeInfoField(_titleFormat, "Engine Info");
        engineBody = makeInfoField(_bodyFormat, "Loading info...");

        sysTitle = makeInfoField(_titleFormat, "System Info");
        sysBody = makeInfoField(_bodyFormat, "Loading info...");

        condTitle = makeInfoField(_titleFormat, "Conductor Info");
        posText = makeInfoField(_bodyFormat, "Position: 0ms");
        stepText = makeInfoField(_bodyFormat, "Step: 0");
        beatText = makeInfoField(_bodyFormat, "Beat: 0");
        measureText = makeInfoField(_bodyFormat, "Measure: 0");
        
        stateTitle = makeInfoField(_titleFormat, "State Info");
        stateBody = makeInfoField(_bodyFormat, "State:");

        _infoFields = [engineTitle, engineBody, sysTitle, sysBody, condTitle, posText, stepText, beatText, measureText, stateTitle, stateBody];

        framerateText = new TextField();
        framerateText.x = 10;
        framerateText.y = 6;
        framerateText.selectable = false;
        framerateText.mouseEnabled = false;
        framerateText.autoSize = openfl.text.TextFieldAutoSize.LEFT;
        framerateText.defaultTextFormat = new TextFormat('Monsterrat', 15, 0xFFFFFF);
        framerateText.text = "FPS: 0";
        addChild(framerateText);

        memoryText = new TextField();
        memoryText.alpha = 0.7;
        memoryText.x = 10;
        memoryText.y = 20;
        memoryText.selectable = false;
        memoryText.mouseEnabled = false;
        memoryText.autoSize = openfl.text.TextFieldAutoSize.LEFT;
        memoryText.defaultTextFormat = new TextFormat('Monsterrat', 11, 0xFFFFFF);
        memoryText.text = "MEM: 0.00mb / 0.00mb";
        addChild(memoryText);

        targetFrameWidth = framerateText.textWidth + 10;
        targetFrameHeight = framerateText.textHeight;
        targetMemWidth = memoryText.textWidth + 10;
        targetMemHeight = memoryText.textHeight;

        framerateGraph = new GRAPH(0, 0, 200, 25, 0xFFFFFF);
        framerateGraph.textDisplay.y = -49;
        framerateGraph.minValue = 0;
        addChild(framerateGraph);

        memoryGraph = new GRAPH(0, 0, 200, 25, 0xFFFFFF);
        memoryGraph.textDisplay.y = -49;
        memoryGraph.minValue = 0;
        addChild(memoryGraph);

        #if flash
        addEventListener(Event.ENTER_FRAME, function(e)
        {
            var time = Lib.getTimer();
            __enterFrame(time - currentTime);
        });
        #end

        #if lime
        try 
        {
            var renderer = GL.getParameter(GL.RENDERER);
            if (renderer != null)
                gpuName = Std.string(renderer);
        } 
        catch (e:Dynamic) {}
        #end

        #if sys
        Thread.create(() ->
        {
            var fetchedCPU = "Unknown CPU";
            var fetchedOS = Sys.systemName();

            #if windows
            try 
            {
                var cpuProcess = new sys.io.Process("reg", ["query", "HKLM\\HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0", "/v", "ProcessorNameString"]);
                var cpuOutput = cpuProcess.stdout.readAll().toString();
                cpuProcess.close();

                for (line in cpuOutput.split("\n"))
                {
                    if (line.indexOf("REG_SZ") != -1)
                    {
                        fetchedCPU = StringTools.trim(line.split("REG_SZ")[1]);
                        break;
                    }
                }

                var osProcess = new sys.io.Process("wmic", ["os", "get", "Caption"]);
                var osOutput = osProcess.stdout.readAll().toString();
                osProcess.close();

                for (line in osOutput.split("\n"))
                {
                    var trimmed = StringTools.trim(line);
                    if (trimmed.length > 0 && trimmed.indexOf("Caption") == -1)
                    {
                        fetchedOS = trimmed;
                        break;
                    }
                }
            }
            catch (e:Dynamic) {}
            #elseif mac
            try
            {
                var cpuProcess = new sys.io.Process("sysctl", ["-n", "machdep.cpu.brand_string"]);
                fetchedCPU = StringTools.trim(cpuProcess.stdout.readAll().toString());
                cpuProcess.close();

                var osNameProcess = new sys.io.Process("sw_vers", ["-productName"]);
                var osNameStr = StringTools.trim(osNameProcess.stdout.readAll().toString());
                osNameProcess.close();

                var osVerProcess = new sys.io.Process("sw_vers", ["-productVersion"]);
                var osVerStr = StringTools.trim(osVerProcess.stdout.readAll().toString());
                osVerProcess.close();

                if (osNameStr.length > 0)
                    fetchedOS = osNameStr + " " + osVerStr;
            }
            catch (e:Dynamic) {}
            #elseif linux
            try
            {
                var cpuInput = sys.io.File.read('/proc/cpuinfo', false);
                var cpuRegex = ~/^model name\s+:\s+(.+)$/m;
                var line:String;

                while (!cpuInput.eof())
                {
                    line = cpuInput.readLine();
                    if (cpuRegex.match(line))
                    {
                        fetchedCPU = StringTools.trim(cpuRegex.matched(1));
                        break;
                    }
                }
                cpuInput.close();

                var osInput = sys.io.File.read("/etc/os-release", false);
                var osRegex = ~/^PRETTY_NAME="([^"]+)"/m;

                while (!osInput.eof())
                {
                    line = osInput.readLine();
                    if (osRegex.match(line))
                    {
                        fetchedOS = StringTools.trim(osRegex.matched(1));
                        break;
                    }
                }
                osInput.close();
            }
            catch (e:Dynamic) {}
            #end

            cpuName = fetchedCPU;
            osName = fetchedOS;

            updateStaticInfo();
        });
        #end

        GitHubUtil.fetchCommit(Constants.REPOSITORY_OWNER, Constants.REPOSITORY_NAME, Constants.REPOSITORY_BRANCH, '', function(result:String)
        {
            githubCommit = result;
            updateStaticInfo();
        });

        updateStaticInfo(); 
    }

    private function updateStaticInfo():Void
    {
        engineInfoString = 'RevEngine v${Constants.VERSION_STRING} (API: v${Constants.API_VERSION})\n'
                         + 'Commit: $githubCommit (${Constants.REPOSITORY_OWNER}/${Constants.REPOSITORY_NAME}:${Constants.REPOSITORY_BRANCH})';

        systemInfoString = 'OS: ${osName}\n'
                         + 'CPU: ${cpuName}\n'
                         + 'GPU: ${gpuName}';
    }

    @:noCompletion
    #if !flash override #end function __enterFrame(deltaTime:Float):Void
    {
        currentTime += deltaTime;

        if (frameCount == FPS_BUFFER_SIZE)
        {
            frameHead = (frameHead + 1) % FPS_BUFFER_SIZE;
            frameCount--;
        }

        frameTimes[(frameHead + frameCount) % FPS_BUFFER_SIZE] = currentTime;
        frameCount++;

        while (frameCount > 0 && frameTimes[frameHead] < currentTime - 1000)
        {
            frameHead = (frameHead + 1) % FPS_BUFFER_SIZE;
            frameCount--;
        }

        updateFramerate();
        updateDisplay(deltaTime);
        updateInfo(deltaTime);

        updateFramerateText();

        graphTimer += deltaTime;
        if (graphTimer >= 100)
        {
            graphTimer = 0;

            if (currentDisplayType == ADVANCED)
            {
                framerateGraph.maxValue = peakFPS;
                framerateGraph.update(currentFPS);
            }
        }

        statsTimer += deltaTime;
        if (statsTimer >= 500)
        {
            if (currentDisplayType != HIDDEN)
                updateMemory();

            if (infoTextToggle)
            {
                cachedSprites.total = 0;
                cachedSprites.visible = 0;
                cachedSprites.drawn = 0;
                getSpriteCounts(FlxG.state, cachedSprites);
            }

            statsTimer = 0;
        }

        framerateGraph.x = framerateText.x;
        framerateGraph.y = framerateText.y + targetFrameHeight + 5;

        memoryGraph.x = memoryText.x;
        memoryGraph.y = memoryText.y + targetMemHeight + 5;
    }

    public function getSpriteCounts(basic:FlxBasic, ?counts:CachedSpriteData):CachedSpriteData
    {
        if (counts == null)
            counts = {total: 0, visible: 0, drawn: 0};

        if (basic == null || !basic.exists)
            return counts;

        if (Std.isOfType(basic, FlxTypedGroup))
        {
            var group:FlxTypedGroup<Dynamic> = cast basic;
            for (member in group.members)
                getSpriteCounts(member, counts);
        }
        else if (Std.isOfType(basic, FlxTypedSpriteGroup))
        {
            var spriteGroup:FlxTypedSpriteGroup<Dynamic> = cast basic;
            getSpriteCounts(spriteGroup.group, counts);
        }
        else if (Std.isOfType(basic, FunkinSprite))
        {
            var sprite:FunkinSprite = cast basic;
            counts.total++;

            if (sprite.visible)
            {
                counts.visible++;
                if (sprite.isOnScreen(FlxG.camera))
                    counts.drawn++;
            }
        }

        return counts;
    }

    public function updateFramerate()
    {
        var currentCount = frameCount;
        currentFPS = Math.round((currentCount + cacheCount) / 2);
        currentFPS = Std.int(Math.min(currentFPS, Std.int(Lib.current.stage.frameRate)));

        if (currentFPS > peakFPS) peakFPS = currentFPS;

        cacheCount = currentCount;
    }

    private function updateFramerateText():Void
    {
        if (currentFPS == lastDrawnFPS)
            return;

        lastDrawnFPS = currentFPS;

        framerateText.text = 'FPS: ${currentFPS}';
        targetFrameWidth = framerateText.textWidth + 10;
        targetFrameHeight = framerateText.textHeight;
        framerateText.width = targetFrameWidth;
    }

    public function updateMemory()
    {
        var rawGCMem:Float = MemoryUtil.getGCMemory();
        var rawTaskMem:Float = MemoryUtil.getTaskMemory();

        var gcMEM:Float = MemoryUtil.roundMemory(rawGCMem, true, true);
        var taskMEM:Float = MemoryUtil.roundMemory(rawTaskMem, true, true);
        
        if (taskMEM > peakMEM) peakMEM = taskMEM;

        if (currentDisplayType == ADVANCED)
        {
            memoryGraph.maxValue = peakMEM;
            memoryGraph.update(taskMEM);
        }

        if (gcMEM == lastGcMEM && taskMEM == lastTaskMEM)
            return;

        lastGcMEM = gcMEM;
        lastTaskMEM = taskMEM;

        var gcUnit:String = MemoryUtil.setMemoryUnitString(rawGCMem).toLowerCase();
        var taskUnit:String = MemoryUtil.setMemoryUnitString(rawTaskMem).toLowerCase();

        memoryText.text = 'MEM: ${gcMEM}${gcUnit} / ${taskMEM}${taskUnit}';

        targetMemWidth = memoryText.textWidth + 10;
        targetMemHeight = memoryText.textHeight;
        memoryText.width = targetMemWidth;
    }

    private function makeInfoField(format:TextFormat, initial:String):TextField
    {
        var field:TextField = new TextField();

        field.selectable = false;
        field.mouseEnabled = false;

        field.autoSize = openfl.text.TextFieldAutoSize.LEFT;
        field.defaultTextFormat = format;
        field.text = initial;
        field.alpha = 0;

        addChild(field);

        return field;
    }

    public function updateInfo(dt:Float)
    {
        if (FlxG.keys.justPressed.F2)
            infoTextToggle = !infoTextToggle;

        var elapsed:Float = dt / 1000;

        if (infoTextToggle && FlxG.state != null)
        {
            updateInfoContent();
            layoutInfoSections();
        }

        infoBox.alpha = MathUtil.smoothLerpPrecision(infoBox.alpha, infoTextToggle ? 0.4 : 0, elapsed, 0.1);

        var textAlpha:Float = infoTextToggle ? 0.85 : 0;
        for (field in _infoFields)
            field.alpha = MathUtil.smoothLerpPrecision(field.alpha, textAlpha, elapsed, 0.1);

        if (!infoTextToggle && infoBox.alpha <= 0.01)
            return;

        infoBox.x = 10;
        infoBox.y = textBox.y + textBox.height + 2;

        infoBox.width = MathUtil.smoothLerpPrecision(infoBox.width, targetInfoWidth + 12, elapsed, 0.1);
        infoBox.height = MathUtil.smoothLerpPrecision(infoBox.height, targetInfoHeight, elapsed, 0.1);
    }

    private function updateInfoContent():Void
    {
        applyText(engineBody, engineInfoString);
        applyText(sysBody, systemInfoString);

        var conductor:Conductor = Conductor.instance;
        if (conductor != null)
        {
            applyText(posText, 'Position: ${Std.int(conductor.songPosition)}ms (${FlxStringUtil.formatTime(Std.int(conductor.songPosition / 1000))})');
            applyText(stepText, 'Step: ${conductor.currentStep} [${FlxMath.roundDecimal(conductor.currentStepTime, 2)}]');
            applyText(beatText, 'Beat: ${conductor.currentBeat} [${FlxMath.roundDecimal(conductor.currentBeatTime, 2)}]');
            applyText(measureText, 'Measure: ${conductor.currentMeasure} [${FlxMath.roundDecimal(conductor.currentMeasureTime, 2)}]');
        }
        else
        {
            applyText(posText, 'Position: --');
            applyText(stepText, 'Step: --');
            applyText(beatText, 'Beat: --');
            applyText(measureText, 'Measure: --');
        }

        if (FlxG.state != cachedState)
        {
            cachedState = FlxG.state;
            cachedStateName = Type.getClassName(Type.getClass(cachedState));
        }

        if (FlxG.state.subState != cachedSubState)
        {
            cachedSubState = FlxG.state.subState;
            cachedSubStateName = cachedSubState != null ? Type.getClassName(Type.getClass(cachedSubState)) : "";
        }

        var stateStr:String = cachedStateName;
        if (cachedSubState != null)
            stateStr += ' ($cachedSubStateName)';

        applyText(stateBody, 'State: ${stateStr}\n'
                           + 'Total Sprites: ${cachedSprites.total}\n'
                           + 'Visible Sprites: ${cachedSprites.visible}\n'
                           + 'Drawn Sprites: ${cachedSprites.drawn}');
    }

    private function layoutInfoSections():Void
    {
        var x:Float = 10;

        var padTop:Float = 3;
        var padBottom:Float = 3;

        var boxTop:Float = textBox.y + textBox.height + 2;

        var y:Float = boxTop + padTop - 2;

        var maxWidth:Float = 0;

        var first:Bool = true;

        for (field in _infoFields)
        {
            if (!first && (field == engineTitle || field == sysTitle || field == condTitle || field == stateTitle))
                y += 5;

            field.x = x;
            field.y = y;

            y += field.textHeight;

            first = false;

            if (field.textWidth > maxWidth)
                maxWidth = field.textWidth;
        }

        targetInfoWidth = maxWidth;
        targetInfoHeight = (y + padBottom) - boxTop;
    }

    private inline function applyText(field:TextField, value:String):Void
    {
        if (field.text != value)
            field.text = value;
    }

    public function updateDisplay(dt:Float):Void
    {
        if (FlxG.keys.justPressed.F3)
        {
            switch (currentDisplayType)
            {
                case HIDDEN: currentDisplayType = SIMPLE;
                case SIMPLE: currentDisplayType = MEMORY;
                case MEMORY: currentDisplayType = ADVANCED;
                case ADVANCED: currentDisplayType = HIDDEN;
            }
        }

        var elapsed:Float = dt / 1000;
        textBox.x = framerateText.x;
        textBox.y = framerateText.y;

        switch(currentDisplayType)
        {
            case HIDDEN:
            {
                textBox.width = MathUtil.smoothLerpPrecision(textBox.width, 0, elapsed, 0.1);
                textBox.height = MathUtil.smoothLerpPrecision(textBox.height, 0, elapsed, 0.1);

                framerateText.x = MathUtil.smoothLerpPrecision(framerateText.x, -(targetFrameWidth), elapsed, 0.1);
                memoryText.x = MathUtil.smoothLerpPrecision(memoryText.x, -(targetMemWidth), elapsed, 0.1);
                memoryText.y = MathUtil.smoothLerpPrecision(memoryText.y, 20, elapsed, 0.1);

                framerateGraph.alpha = MathUtil.smoothLerpPrecision(framerateGraph.alpha, 0, elapsed, 0.1);
                memoryGraph.alpha = MathUtil.smoothLerpPrecision(memoryGraph.alpha, 0, elapsed, 0.1);
            }
            
            case SIMPLE:
            {
                textBox.width = MathUtil.smoothLerpPrecision(textBox.width, targetFrameWidth - 2, elapsed, 0.1);
                textBox.height = MathUtil.smoothLerpPrecision(textBox.height, targetFrameHeight + 5, elapsed, 0.1);

                framerateText.x = MathUtil.smoothLerpPrecision(framerateText.x, 10, elapsed, 0.1);
                memoryText.x = MathUtil.smoothLerpPrecision(memoryText.x, -(targetMemWidth), elapsed, 0.1);
                memoryText.y = MathUtil.smoothLerpPrecision(memoryText.y, 20, elapsed, 0.1);

                framerateGraph.alpha = MathUtil.smoothLerpPrecision(framerateGraph.alpha, 0, elapsed, 0.1);
                memoryGraph.alpha = MathUtil.smoothLerpPrecision(memoryGraph.alpha, 0, elapsed, 0.1);
            }
            
            case MEMORY:
            {
                textBox.width = MathUtil.smoothLerpPrecision(textBox.width, targetMemWidth - 2, elapsed, 0.1);
                textBox.height = MathUtil.smoothLerpPrecision(textBox.height, targetFrameHeight + targetMemHeight, elapsed, 0.1);

                framerateText.x = MathUtil.smoothLerpPrecision(framerateText.x, 10, elapsed, 0.1);

                memoryText.x = MathUtil.smoothLerpPrecision(memoryText.x, 10, elapsed, 0.1);
                memoryText.y = MathUtil.smoothLerpPrecision(memoryText.y, 20, elapsed, 0.1);

                framerateGraph.alpha = MathUtil.smoothLerpPrecision(framerateGraph.alpha, 0, elapsed, 0.1);
                memoryGraph.alpha = MathUtil.smoothLerpPrecision(memoryGraph.alpha, 0, elapsed, 0.1);
            }
            
            case ADVANCED:
            {
                textBox.width = MathUtil.smoothLerpPrecision(textBox.width, 208, elapsed, 0.1);
                textBox.height = MathUtil.smoothLerpPrecision(textBox.height, memoryText.y + targetMemHeight + 33, elapsed, 0.1);

                framerateText.x = MathUtil.smoothLerpPrecision(framerateText.x, 10, elapsed, 0.1);
                memoryText.x = MathUtil.smoothLerpPrecision(memoryText.x, 10, elapsed, 0.1);
                memoryText.y = MathUtil.smoothLerpPrecision(memoryText.y, 60, elapsed, 0.1);

                framerateGraph.alpha = MathUtil.smoothLerpPrecision(framerateGraph.alpha, 1, elapsed, 0.1);
                memoryGraph.alpha = MathUtil.smoothLerpPrecision(memoryGraph.alpha, 1, elapsed, 0.1);
            }
        }
    }
}