package game.world;

import sys.FileSystem;

import backend.modding.events.ScriptEvent;
import backend.modding.IScriptedClass;

import backend.modding.handlers.CharacterHandler;

import game.notes.Note;
import game.notes.SustainNote;
import game.notes.Strumline;

import backend.registries.world.CharacterRegistry;

import flixel.math.FlxPoint;
import flixel.util.FlxDestroyUtil;

/**
 * The type of positioning the character should have.
 * PLAYER = The character will be flipped to its X axis and have its left and right animation flipped.
 * GF = The character will be positioned between the player and opponent.
 * OPPONENT = The character will be positioned against the player.
 * OTHER = Basically like the `OPPONENT` entry. Used to differentiate the main opponent from other characters added alongisde them.
 */
enum PlacementType
{
    PLAYER;
    GF;
    OPPONENT;
    OTHER;
}

/**
 * The idle type of the character.
 * DEFAULT = Usual idle movement. Plays every couple of beats.
 * ALTERNATE = Idle movement based on a left and right bop, like GF and Skid & Pump.
 * EASED = The character will wait for its note animation to finish before going back to idle.
 * */
enum IdleType
{
    DEFAULT;
    ALTERNATE;
    LOOPED;
    EASED;
}

/**
 * Params used for the character.
 */
typedef CharacterParams =
{
    /**
     * Name of the character.
     */
    var name:String;

    /**
     * Strumline, attached to the character.
     */
    var ?parent:Strumline;
}

/**
 * A sprite object used as a player that shows up on the stage, that bops to the music and reacts to strumline behaviors.
 * Can be used for several other things such as debugging, visual display, etc. 
 */
class Character extends FunkinSprite implements IScriptedCharacterClass
{
    /**
     * The identifier of the character.
     * Only ever reassigned by `change`, which rekeys the character in `CharacterHandler` to match.
     */
    public var id(default, null):String;

    /**
     * The params of the character.
     */
    public var params:CharacterParams;

    /**
     * The character's parsed JSON data.
     */
    public var data:CharacterData;

    /**
     * The character's type.
     */
    public var placementType:PlacementType = OPPONENT;

    /**
     * The character's idle type.
     */
    public var idleType:IdleType = DEFAULT;

    /**
     * The character's identifier, also referred as their "name".
     */
    public var name:String = 'bf';

    /**
     * The character's display name, used in menus and other stuff.
     */
    public var displayName:String = 'Boyfriend';

    /**
     * The character's health bar color.
     */
    public var hpColor:FlxColor = FlxColor.WHITE;

    /**
     * The strumline the character inherits. Used to make it react to note hits, misses and more.
     */
    public var parent:Strumline;

    /**
     * The character's position offset.
     */
    public var posOffset:FlxPoint = FlxPoint.get(0.0, 0.0);

    /**
     * The character's camera offset.
     */
    public var camOffset:FlxPoint = FlxPoint.get(0.0, 0.0);

    /**
     * The dynamic camera values for this character.
     */
    public var dynCamPoint:FlxPoint = FlxPoint.get(0.0, 0.0);

    /**
     * How much the camera should move with this character's note animations. (Horizontal and vertical movement)
     */
    public var dynCamIntensity:FlxPoint = FlxPoint.get(0, 0);

    /**
     * Whether the character should bop to the beat of the music.
     */
    public var allowBopOnBeat:Bool = true;

    /**
     * The interval, in beats, at which the character dances at.
     */
    public var danceBeatInterval:Int = 2;

    /**
     * Whether this character has a looping idle animation.
     */
    public var loopingIdle:Bool = false;

    /**
     * Internal variable used to toggle between the `ALTERNATE` idle style's animations.
     */
    private var idleToggle:Bool = false;

    /**
     * Timer, used to reset the character back to its idle animation.
     */
    public var resetTimer:Float = 0.0;

    /**
     * Checks if the character is singing.
     */
    public var isSinging:Bool = false;

    /**
     * The suffix used in the idle animations.
     */
    public var idleSuffix:String = "";

    /**
     * The suffix used in the sing animations.
     */
    public var singSuffix:String = "";

    /**
     * If stunned, the character won't forcefully play the idle animation when the time comes.
     */
    public var stunned:Bool = false;

    /**
     * The amount of time, in steps, the character should sing for before they start dancing again.
     */
    public var singDuration:Float = 4.0;

    /**
     * This character's current conductor instance.
     */
    public var conductor:Conductor = null;

    public function new(id:String)
    {
        super(0, 0);
        
        this.id = id;
    }

    /**
     * Initializes the character.
     */
    public function init(x:Int, y:Int, params:CharacterParams)
    {
        if (this.params != null)
            unload();

        this.setPosition(x, y);

        CharacterRegistry.reload(params.name);

        build(params);

        Conductor.instance.onBeatHit.add(beatHit);

        dispatchEvent(new ScriptEvent(CREATE));
    }

    /**
     * Syncs the character to its params and loads everything.
     */
    function build(params:CharacterParams)
    {
        this.params = params;
        this.name = params.name;
        this.parent = params.parent;

        load_data();
        load_sprites();
        load_animations();

        this.origin.set(frameWidth / 2, frameHeight / 2);
        this.pixelPerfectRender = false;

        dance();

        if (parent != null)
        {
            parent.onNoteHit.add(hit);
            parent.onSustainHit.add(hold);
            parent.onNoteMiss.add(miss);
        }
    }

    /**
     * Completely swaps this character out for a different one.
     * @param name The character to change into.
     * @param params Params for the new character. Defaults to keeping this one's strumline.
     * @return The character to use from here on.
     */
    public function change(name:String, ?params:CharacterParams):Character
    {
        var ready:Character = PlayState.instance?.understudies?.get(name);

        if (ready != null && ready != this)
            return swap(ready);

        var owner:Character = CharacterHandler.get(name);

        if (owner != null && owner != this && owner.params != null)
        {
            trace('Could not change $name in: it is already loaded on another character.', "WARNING");
            return this;
        }

        if (params == null)
            params = {name: name, parent: this.parent};
        else
            params.name = name;

        var anchorX:Float = x - posOffset.x;
        var anchorY:Float = y - posOffset.y;

        var camExtraX:Float = camOffset.x - (data != null ? data.camera[0] : 0);
        var camExtraY:Float = camOffset.y - (data != null ? data.camera[1] : 0);

        var camIntensityX:Float = (dynCamIntensity != null) ? dynCamIntensity.x : 0.0;
        var camIntensityY:Float = (dynCamIntensity != null) ? dynCamIntensity.y : 0.0;
        var tint:FlxColor = color;

        var next:Character = this;

        if (name != this.name && (CharacterHandler.isScripted(this) || CharacterHandler.hasScript(name)))
            next = CharacterHandler.resolve(name);

        var pointer = PlayState.instance?.pointer;
        var followed:Bool = (pointer != null && pointer.curTarget == this);

        if (followed)
            pointer.curTarget = null;

        if (next != this)
        {
            var host = container;

            if (host != null)
                host.replace(this, next);

            destroy();
        }
        else
        {
            dispatchEvent(new ScriptEvent(DESTROY));
            unload();
        }

        var registered:Bool = (CharacterHandler.get(id) == this);

        if (registered)
            CharacterHandler.list.remove(id);

        if (next == this)
        {
            this.id = name;

            if (registered)
                CharacterHandler.list.set(name, this);
        }

        handOver(next);

        next.init(Std.int(anchorX), Std.int(anchorY), params);
        next.setPosition(anchorX + next.posOffset.x, anchorY + next.posOffset.y);

        next.camOffset.x += camExtraX;
        next.camOffset.y += camExtraY;

        next.dynCamIntensity.set(camIntensityX, camIntensityY);
        next.color = tint;

        refreshBar(next);

        if (followed)
            pointer.curTarget = next;

        return next;
    }

    /**
     * Gives the character to an "understudy", preloaded in PlayState.
     */
    function swap(next:Character):Character
    {
        var game = PlayState.instance;
        var line = parent;

        detach();
        next.attach(line);

        if (dynCamIntensity != null && next.dynCamIntensity != null)
            next.dynCamIntensity.set(dynCamIntensity.x, dynCamIntensity.y);

        next.color = color;
        var host = container;

        if (host != null && next.container == host)
        {
            var mine:Int = host.members.indexOf(this);
            var theirs:Int = host.members.indexOf(next);

            if (mine != -1 && theirs != -1)
            {
                host.members[mine] = next;
                host.members[theirs] = this;
            }
        }

        var pointer = game?.pointer;
        var followed:Bool = (pointer != null && pointer.curTarget == this);

        if (followed)
            pointer.curTarget = null;

        handOver(next);

        next.visible = true;
        next.active = true;

        visible = false;
        active = false;

        if (game != null)
        {
            game.understudies.remove(next.name);
            game.understudies.set(name, this);
        }

        next.dance();

        refreshBar(next);

        if (followed)
            pointer.curTarget = next;

        return next;
    }

    /**
     * Unparents the character from its strumline and KILLS IT.
     */
    function detach():Void
    {
        if (parent != null)
        {
            if (parent.onNoteHit != null) parent.onNoteHit.remove(hit);
            if (parent.onSustainHit != null) parent.onSustainHit.remove(hold);
            if (parent.onNoteMiss != null) parent.onNoteMiss.remove(miss);
        }

        parent = null;

        if (params != null)
            params.parent = null;

        isSinging = false;
        resetTimer = 0;
    }

    /**
     * Parents this character up to a strumline.
     */
    function attach(line:Strumline):Void
    {
        detach();

        parent = line;

        if (params != null)
            params.parent = line;

        if (line == null)
            return;

        line.onNoteHit.add(hit);
        line.onSustainHit.add(hold);
        line.onNoteMiss.add(miss);
    }

    /**
     * Points the song's own character references at the character replacing this one.
     */
    function handOver(next:Character)
    {
        var game = PlayState.instance;

        if (game == null || next == this)
            return;

        if (game.characters != null)
        {
            for (slot in game.characters.keys())
            {
                if (game.characters.get(slot) == this)
                    game.characters.set(slot, next);
            }
        }

        if (game.dad == this) game.dad = next;
        if (game.boyfriend == this) game.boyfriend = next;
        if (game.gf == this) game.gf = next;

        if (game.healthBar != null && game.healthBar.characters != null)
        {
            var bar = game.healthBar.characters;

            for (i in 0...bar.length)
            {
                if (bar[i] == this)
                    bar[i] = next;
            }
        }
    }

    /**
     * Syncs the health bar colors to the new character.
     */
    function refreshBar(next:Character)
    {
        var game = PlayState.instance;
        var bar = (game != null) ? game.healthBar : null;

        if (bar == null || bar.characters == null || bar.characters.indexOf(next) == -1)
            return;

        for (icon in [bar.leftIcon, bar.rightIcon])
        {
            if (icon == null || (icon.character != this && icon.character != next))
                continue;

            if (icon.character != next)
                icon.character = next;      
            else
                icon.changeIcon(next.name);  
        }

        bar.changeColor(bar.characters[0]?.hpColor ?? 0xFFA1A1A1, bar.characters[1]?.hpColor ?? 0xFFA1A1A1);
    }

    /**
     * Destroys every piece of the character currently loaded. They get skinned alive...
     */
    function unload()
    {
        if (parent != null)
        {
            if (parent.onNoteHit != null) parent.onNoteHit.remove(hit);
            if (parent.onSustainHit != null) parent.onSustainHit.remove(hold);
            if (parent.onNoteMiss != null) parent.onNoteMiss.remove(miss);
        }

        data = null;
        params = null;
        parent = null;

        idleType = DEFAULT;
        danceBeatInterval = 2;
        idleToggle = false;
        loopingIdle = false;

        idleSuffix = "";
        singSuffix = "";

        isSinging = false;
        allowBopOnBeat = true;
        resetTimer = 0.0;
        stunned = false;

        if (dynCamPoint != null)
            dynCamPoint.set(0.0, 0.0);

        if (dynCamIntensity != null)
            dynCamIntensity.set(0.0, 0.0);

        color = FlxColor.WHITE;
        shader = null;
        blend = null;
        visible = true;
        active = true;
        tag = "";
    }

    /**
     * Gets the character data from the registry and loads it.
     */
    public function load_data()
    {
        data = CharacterRegistry.get(name);

        displayName = data.name;
        hpColor = FlxColor.fromString(data.color);
        singDuration = data.singDuration;

        posOffset.set(data.position[0], data.position[1]);
        camOffset.set(data.camera[0], data.camera[1]);

        x += posOffset.x;
        y += posOffset.y;

        scale.set(data.scale[0], data.scale[1]);
        updateHitbox();

        flipX = data.flip[0];
        flipY = data.flip[1];

        antialiasing = data.antialiasing;
        alpha = data.alpha;
        angle = data.angle;

        renderType = switch(data.renderType)
        {
            case "SPARROW": SPARROW;
            case "ATLAS": ATLAS;
            default: SPARROW;
        };

        placementType = switch(data.placement)
        {
            case "PLAYER": PLAYER;
            case "GF": GF;
            case "OPPONENT": OPPONENT;
            case "OTHER": OTHER;
            default: OPPONENT;
        }
    }

    /**
     * Loads the character spritesheet with the given rendering mode.
     */
    public function load_sprites()
    {
        loadSprite('characters/${name}/char');

        if (renderType == ATLAS && atlasSpr != null)
            atlasSpr.applyStageMatrix = data.applyStageMatrix;
    }

    /**
     * Loads every animation located in the character's data file.
     */
    public function load_animations()
    {
        for (entry in data.animations)
        {
            var animName = entry.name;

            if (data.flip[0])
            {
                if (animName.contains("singLEFT"))
                    animName = StringTools.replace(animName, "singLEFT", "singRIGHT");
                else if (animName.contains("singRIGHT"))
                    animName = StringTools.replace(animName, "singRIGHT", "singLEFT");
            }

            addAnim(animName, {
                prefix: entry.prefix,
                offsets: entry.offsets,
                looped: entry.looped,
                fps: entry.fps,
                flip: entry.flip,
                indices: entry.indices
            });
        }

        if (offsetMap.exists("danceLeft") && offsetMap.exists("danceRight"))
        {
            idleType = ALTERNATE;
            danceBeatInterval = 1;
        }
        else if ((renderType == SPARROW && animation.getByName("idle") != null && animation.getByName("idle").looped) || (renderType == ATLAS && atlasSpr.anim.getByName("idle") != null && atlasSpr.anim.getByName("idle").looped))
            idleType = LOOPED;
        else if (offsetMap.exists("singLEFT-ease") && offsetMap.exists("singDOWN-ease") && offsetMap.exists("singUP-ease") && offsetMap.exists("singRIGHT-ease"))
            idleType = EASED;
    }

    /**
     * Plays a given animation and sets the character's respective offsets.
     */
    public function play(name:String, ?force:Bool = false, ?reversed:Bool = false, ?frame:Int = 0):Void
    {
        playAnim(name, {force: force, reversed: reversed, frame: frame});
    }

    /**
     * Dance.
     */
    public function dance()
    {
        if (stunned)
            return;

        dispatchEvent(new ScriptEvent(DANCE));

        isSinging = false;

        dynCamPoint.set(0.0, 0.0);

        var suffix = (idleSuffix != "" ? idleSuffix : "");

        switch (idleType)
        {
            case DEFAULT | EASED | LOOPED:
                play('idle' + suffix, true);
                
            case ALTERNATE:
                idleToggle = !idleToggle;
                play((idleToggle ? 'danceLeft' : 'danceRight') + suffix, true);
        }

        if (idleType == LOOPED)
            loopingIdle = true;
    }

    public function hit(note:Note)
    {
        var event = new NoteHitScriptEvent(HIT, note, 150, true, true, true);
        dispatchEvent(event);

        if (event.cancelled)
            return;

        var dir = Constants.SING_DIRECTIONS[parent.keyCount][note.direction];

        isSinging = true;
        allowBopOnBeat = false;
        loopingIdle = false;
        stunned = false;

        play('sing${dir}' + (singSuffix != "" ? '-$singSuffix' : ""), true);
        moveCamera(dir, dynCamIntensity.x, dynCamIntensity.y);

        resetTimer = 0;
    }

    public function hold(sustain:SustainNote) 
    {
        var event = new SustainHitScriptEvent(HOLD, sustain, true, true);
        dispatchEvent(event);

        if (event.cancelled)
            return;

        if (Conductor.instance.songPosition < sustain.time + Conductor.instance.stepLengthMs) return;

        var dir = Constants.SING_DIRECTIONS[parent.keyCount][sustain.direction];
        var animName = 'sing${dir}';

        if (renderType == ATLAS)
        {
            if (atlasSpr.anim.curAnim != null && atlasSpr.anim.curAnim.name == animName)
                return;
        }
        else if (renderType == SPARROW)
        {
            if (animation.curAnim != null && animation.curAnim.name == animName)
                return;
        }

        isSinging = true;
        allowBopOnBeat = false;
        loopingIdle = false;
        stunned = false;

        play(animName, true);
        moveCamera(dir, dynCamIntensity.x, dynCamIntensity.y);
    }

    public function miss(note:Note)
    {
        dispatchEvent(new NoteHitScriptEvent(MISS, note, 150, true, true, true));

        var dir = Constants.SING_DIRECTIONS[parent.keyCount][note.direction];

        isSinging = true;
        allowBopOnBeat = false;
        loopingIdle = false;
        stunned = false;

        play('sing${dir}-miss', true);
        moveCamera(dir, dynCamIntensity.x / 2, dynCamIntensity.y / 2);

        resetTimer = 0;
    }

    public function moveCamera(dir:String, xPos:Float, yPos:Float):Void
    {
        switch(dir)
        {
            case 'LEFT':
                dynCamPoint.set(-xPos, 0);
            case 'RIGHT':
                dynCamPoint.set(xPos, 0);
            case 'UP':
                dynCamPoint.set(0, -yPos);
            case 'DOWN':
                dynCamPoint.set(0, yPos);
        }
    }
    
    /**
     * Handles the character's animation reset logic.
     */
    override public function update(elapsed:Float)
    {
        handle_timer(elapsed);
        handle_sustains(elapsed);

        super.update(elapsed);

        dispatchEvent(new UpdateScriptEvent(elapsed));
    }

    /**
     * Handles the character's reset timer.
     */
    function handle_timer(elapsed:Float)
    {
        if (isSinging)
            resetTimer += elapsed;

        if (resetTimer < ((Conductor.instance.stepLengthMs / 1000) * singDuration) || !isSinging)
        {
            return;
        }
        
        // Normal Idle type.
        if (idleType != EASED)
        {
            isSinging = false;
            allowBopOnBeat = true;

            resetTimer = 0;

            return;
        }

        // Eased idle type.
        var anim = (renderType == ATLAS ? atlasSpr.anim : animation);

        if (anim.curAnim.name.contains('-miss'))
        {
            return;
        }

        if (anim.finished)
        {
            resetTimer = 0;

            play(anim.curAnim.name + '-ease', true);
            anim.onFinish.addOnce((leAnim:String) -> 
            {
                isSinging = false;
                allowBopOnBeat = true;
                resetTimer = 0;
            });
        }
    }

    /**
     * Handles the sustains being able to pause the reset timer.
     */
    function handle_sustains(elapsed:Float)
    {
        if (parent == null)
        {
            return;
        }

        for (sustain in parent.sustains.members)
        {
            if (sustain == null || !sustain.exists || !sustain.alive) continue;

            if (Conductor.instance.songPosition >= sustain.time && sustain.hit && !sustain.missed)
            {
                resetTimer -= elapsed;
                
                if (resetTimer < 0)
                    resetTimer = 0;
            }
        }
    }

    /**
     * Function called when a beat is hit.
     */
    function beatHit(beat:Float) 
    {
        if (beat % danceBeatInterval == 0 && !isSinging && allowBopOnBeat && !loopingIdle)
            dance();
    }

    override public function destroy()
    {
        dispatchEvent(new ScriptEvent(DESTROY));

        if (Conductor.instance != null)
            Conductor.instance.onBeatHit.remove(beatHit);

        unload();

        posOffset = FlxDestroyUtil.put(posOffset);
        camOffset = FlxDestroyUtil.put(camOffset);
        dynCamPoint = FlxDestroyUtil.put(dynCamPoint);
        dynCamIntensity = FlxDestroyUtil.put(dynCamIntensity);

        super.destroy();
    }

    /**
     * Dispatches an event to the character's external script.
     * @param event The defined scripted event.
     */
    public function dispatchEvent(event:ScriptEvent)
    {
        CharacterHandler.call(id, event);
    }

    /**
     * Functions defined by the interface.
     */
    public function onScriptEvent(event:ScriptEvent) {}
    
    public function onStateCreate(event:ScriptEvent) {}
    public function onCreate(event:ScriptEvent) {}
    public function onPostCreate(event:ScriptEvent) {}

    public function onDestroy(event:ScriptEvent) {}

    public function onUpdate(event:UpdateScriptEvent) {}

    public function onCameraMove(event:CharacterScriptEvent) {}

    public function onMeasureHit(event:ConductorScriptEvent) {}
    public function onBeatHit(event:ConductorScriptEvent) {}
    public function onStepHit(event:ConductorScriptEvent) {}

    public function onSongEvent(event:SongEventScriptEvent):Void {}

    public function onNoteHit(event:NoteHitScriptEvent):Void {}
    public function onPlayerHit(event:NoteHitScriptEvent):Void {}
    public function onOpponentHit(event:NoteHitScriptEvent):Void {}

    public function onPlayerMiss(event:NoteHitScriptEvent):Void {}

    public function onNoteHold(event:SustainHitScriptEvent):Void {}
    public function onPlayerHold(event:SustainHitScriptEvent):Void {}
    public function onOpponentHold(event:SustainHitScriptEvent):Void {}

    public function onDance(event:ScriptEvent) {}
    public function onHit(event:NoteHitScriptEvent) {}
    public function onMiss(event:NoteHitScriptEvent) {}
    public function onHold(event:SustainHitScriptEvent) {}
}