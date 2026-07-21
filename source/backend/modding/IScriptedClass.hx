package backend.modding;

import backend.modding.events.ScriptEvent;

/**
 * An interface containing general functions for each module script.
 */
interface IScriptedClass
{
    public function onScriptEvent(event:ScriptEvent):Void;

    public function onCreate(event:ScriptEvent):Void;
    public function onStateCreate(event:ScriptEvent):Void;
    public function onCreatePost(event:ScriptEvent):Void;

    public function onUpdate(event:UpdateScriptEvent):Void;

    public function onDestroy(event:ScriptEvent):Void;

    public function onMeasureHit(event:ConductorScriptEvent):Void;
    public function onBeatHit(event:ConductorScriptEvent):Void;
    public function onStepHit(event:ConductorScriptEvent):Void;

    public function onSongEvent(event:SongEventScriptEvent):Void;

    public function onNoteHit(event:NoteHitScriptEvent):Void;
    public function onPlayerHit(event:NoteHitScriptEvent):Void;
    public function onOpponentHit(event:NoteHitScriptEvent):Void;

    public function onPlayerMiss(event:NoteHitScriptEvent):Void;

    public function onNoteHold(event:SustainHitScriptEvent):Void;
    public function onPlayerHold(event:SustainHitScriptEvent):Void;
    public function onOpponentHold(event:SustainHitScriptEvent):Void;

    public function onCameraMove(event:CharacterScriptEvent):Void;
}

/**
 * An interface containing event functions.
 */
interface IEventHandler
{
    public function onDispatchEvent(event:ScriptEvent):Void;
}

/**
 * An interface containing character functions.
 */
interface IScriptedCharacterClass extends IScriptedClass
{
    public function onDance(event:ScriptEvent):Void;
    public function onHit(event:NoteHitScriptEvent):Void;
    public function onMiss(event:NoteHitScriptEvent):Void;
    public function onHold(event:SustainHitScriptEvent):Void;
}