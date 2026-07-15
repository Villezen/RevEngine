package backend.display;

import backend.utils.MathUtil;
import backend.utils.MemoryUtil;
import backend.utils.GitHubUtil;

import openfl.display.Sprite;
import openfl.display.Shape;

import openfl.text.TextFormat;
import openfl.text.TextField;
import openfl.Lib;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.math.FlxPoint;
import flixel.FlxBasic;
import flixel.FlxSprite;
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
    public var infoText:TextField;
    public var framerateText:TextField;
    public var memoryText:TextField;
    public var framerateGraph:GRAPH;
    public var memoryGraph:GRAPH;
    public var currentFPS(default, null):Int = 0;
    public var peakFPS(default, null):Int = 0;
    public var peakMEM(default, null):Float = 0;
    private var cacheCount:Int = 0;
    private var currentTime:Float = 0;
    private var times:Array<Float> = [];

    public var osName:String = "Fetching...";
    public var cpuName:String = "Fetching...";
    public var gpuName:String = "Fetching...";
    public var githubCommit:String = "Fetching...";
    
    private var staticInfoString:String = "";
    private var statsTimer:Float = 0;
    private var cachedSprites:CachedSpriteData = {total: 0, visible: 0, drawn: 0};

    private var cachedState:FlxState = null;
    private var cachedSubState:FlxSubState = null;
    private var cachedStateName:String = "";
    private var cachedSubStateName:String = "";

    private var lastStep:Int = -1;
    private var lastBeat:Int = -1;
    private var lastMeasure:Int = -1;

    private var targetInfoWidth:Float = 0;
    private var targetInfoHeight:Float = 0;
    private var targetFrameWidth:Float = 0;
    private var targetFrameHeight:Float = 15; 
    private var targetMemWidth:Float = 0;
    private var targetMemHeight:Float = 15;
    private var forceInfoUpdate:Bool = true;

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

        infoText = new TextField();
        infoText.x = 10;
        infoText.y = 6;
        infoText.selectable = false;
        infoText.mouseEnabled = false;
        infoText.autoSize = openfl.text.TextFieldAutoSize.LEFT; 
        infoText.defaultTextFormat = new TextFormat('Monsterrat', 10, 0xFFFFFF);
        infoText.text = "Loading info...";
        addChild(infoText);
        
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
        staticInfoString = 'RevEngine v${Constants.VERSION_STRING} (API: v${Constants.API_VERSION})\n' 
                         + 'Commit: $githubCommit (${Constants.REPOSITORY_OWNER}/${Constants.REPOSITORY_NAME}:${Constants.REPOSITORY_BRANCH})\n\n'
                         + 'OS: ${osName}\n' 
                         + 'CPU: ${cpuName}\n' 
                         + 'GPU: ${gpuName}\n\n';
    }

    @:noCompletion
    #if !flash override #end function __enterFrame(deltaTime:Float):Void
    {
        currentTime += deltaTime;
        times.push(currentTime);

        while (times[0] < currentTime - 1000)
            times.shift();

        updateFramerate();
        updateDisplay(deltaTime);
        updateInfo(deltaTime);

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
                
                forceInfoUpdate = true;
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
        else if (Std.isOfType(basic, FlxSprite))
        {
            var sprite:FlxSprite = cast basic;
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
        var currentCount = times.length;
        currentFPS = Math.round((currentCount + cacheCount) / 2);
        currentFPS = Std.int(Math.min(currentFPS, Std.int(Lib.current.stage.frameRate)));

        if (currentFPS > peakFPS) peakFPS = currentFPS;
        
        if (currentCount != cacheCount)
        {
            framerateText.text = 'FPS: ${currentFPS}';
            targetFrameWidth = framerateText.textWidth + 10;
            targetFrameHeight = framerateText.textHeight; 
            framerateText.width = targetFrameWidth;
        }

        cacheCount = currentCount;

        if (currentDisplayType == ADVANCED)
        {
            framerateGraph.maxValue = peakFPS;
            framerateGraph.update(currentCount);
        }
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

        var gcUnit:String = MemoryUtil.setMemoryUnitString(rawGCMem).toLowerCase();
        var taskUnit:String = MemoryUtil.setMemoryUnitString(rawTaskMem).toLowerCase();
        
        memoryText.text = 'MEM: ${gcMEM}${gcUnit} / ${taskMEM}${taskUnit}';
        
        targetMemWidth = memoryText.textWidth + 10;
        targetMemHeight = memoryText.textHeight;
        memoryText.width = targetMemWidth;
    }

    public function updateInfo(dt:Float)
    {
        if (FlxG.keys.justPressed.F2)
            infoTextToggle = !infoTextToggle;

        var elapsed:Float = dt / 1000;

        if (infoTextToggle)
        {
            var currentStep:Int = 0;
            var currentBeat:Int = 0;
            var currentMeasure:Int = 0;

            var conductor:Dynamic = Reflect.field(FlxG.state, "conductor");
            if (conductor != null)
            {
                currentStep = conductor.currentStepTime != null ? conductor.currentStepTime : 0;
                currentBeat = conductor.currentBeatTime != null ? conductor.currentBeatTime : 0;
                currentMeasure = conductor.currentMeasureTime != null ? conductor.currentMeasureTime : 0;
            }

            if (FlxG.state != cachedState)
            {
                cachedState = FlxG.state;
                cachedStateName = Type.getClassName(Type.getClass(cachedState));
                forceInfoUpdate = true;
            }

            if (FlxG.state.subState != cachedSubState)
            {
                cachedSubState = FlxG.state.subState;
                cachedSubStateName = cachedSubState != null ? Type.getClassName(Type.getClass(cachedSubState)) : "";
                forceInfoUpdate = true;
            }

            if (currentStep != lastStep || currentBeat != lastBeat || currentMeasure != lastMeasure || forceInfoUpdate)
            {
                lastStep = currentStep;
                lastBeat = currentBeat;
                lastMeasure = currentMeasure;
                forceInfoUpdate = false;

                var stateStr:String = cachedStateName;
                if (cachedSubState != null)
                {
                    stateStr += ' ($cachedSubStateName)';
                }

                infoText.text = staticInfoString
                              + 'State: ${stateStr}\n'
                              + 'Step: ${currentStep}\n'
                              + 'Beat: ${currentBeat}\n'
                              + 'Measure: ${currentMeasure}\n\n'
                              + 'Total Sprites: ${cachedSprites.total}\n'
                              + 'Total Visible Sprites: ${cachedSprites.visible}\n'
                              + 'Total Drawn Sprites: ${cachedSprites.drawn}';
                
                targetInfoWidth = infoText.textWidth;
                targetInfoHeight = infoText.textHeight;
                infoText.width = targetInfoWidth + 10;
            }
        }

        infoBox.alpha = MathUtil.smoothLerpPrecision(infoBox.alpha, infoTextToggle ? 0.4 : 0, elapsed, 0.1);
        infoText.alpha = MathUtil.smoothLerpPrecision(infoText.alpha, infoTextToggle ? 0.8 : 0, elapsed, 0.1);

        if (!infoTextToggle && infoBox.alpha <= 0.01)
			return;

        infoText.y = textBox.y + textBox.height + 5;
        infoBox.x = infoText.x;
        infoBox.y = infoText.y;
        
        infoBox.width = MathUtil.smoothLerpPrecision(infoBox.width, targetInfoWidth + 7, elapsed, 0.1);
        infoBox.height = MathUtil.smoothLerpPrecision(infoBox.height, targetInfoHeight + 5, elapsed, 0.1);
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