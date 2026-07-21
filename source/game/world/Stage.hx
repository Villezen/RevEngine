package game.world;

import backend.assets.FunkinSprite;

import flixel.FlxState;
import flixel.FlxCamera;
import flixel.FlxBasic;

import backend.modding.events.ScriptEvent;
import backend.modding.IScriptedClass;

import backend.modding.handlers.StageHandler;

import sys.FileSystem;

import backend.registries.world.StageRegistry;

import flixel.group.FlxSpriteGroup;

/**
 * Helper class used to set up the song's stage. Will also load its data.
 */
class Stage extends FlxBasic implements IScriptedClass
{
    /**
     * The identifier of the stage.
     */
    public final id:String;

    /**
     * The data, extracted by the stage JSON.
     */
    public var data:StageData;

    /**
     * Map, containing each stage asset.
     */
    public var sprites:Map<String, FunkinSprite> = [];

    public function new(id:String)
    {
        super();

        this.id = id;

        StageRegistry.reload(id);
    }

    public function build()
    {
        data = StageRegistry.get(id);

        for (entry in data.sprites)
        {
            var sprite:FunkinSprite = new FunkinSprite().loadGraphic(Paths.image(entry.path));
            sprite.tag = entry.name;

            sprite.setPosition(entry.position[0], entry.position[1]);

            sprite.scale.set(entry.scale[0], entry.scale[1]);
            sprite.updateHitbox();

            sprite.scrollFactor.set(entry.scroll[0], entry.scroll[1]);

            sprite.flipX = entry.flip[0];
            sprite.flipY = entry.flip[1];

            sprite.color = FlxColor.fromString(entry.color);
            sprite.alpha = entry.alpha;
            sprite.angle = entry.angle;
            sprite.antialiasing = entry.antialiasing;

            sprites.set(entry.name, sprite);
            FlxG.state.add(sprite);
        }

        dispatchEvent(new ScriptEvent(CREATE));
    }

    override public function update(elapsed:Float)
    {
        dispatchEvent(new UpdateScriptEvent(elapsed));
        
        super.update(elapsed);
    }

    override public function destroy()
    {
        dispatchEvent(new ScriptEvent(DESTROY));

        super.destroy();
    }

    /**
     * Dispatches an event to the stage's external script.
     * @param event The defined scripted event.
     */
    public function dispatchEvent(event:ScriptEvent)
    {
        StageHandler.call(id, event);
    }

    /**
     * Functions defined by the interface.
     */
    public function onScriptEvent(event:ScriptEvent) {}
    
    public function onStateCreate(event:ScriptEvent) {}
    public function onCreate(event:ScriptEvent) {}
    public function onCreatePost(event:ScriptEvent) {}

    public function onDestroy(event:ScriptEvent) {}

    public function onUpdate(event:UpdateScriptEvent) {}

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

    public function onCameraMove(event:CharacterScriptEvent):Void {}
}
