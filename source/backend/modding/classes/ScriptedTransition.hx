package backend.modding.classes;

import backend.transition.Transition;

/**
 * An independent scripted state, competently separated from any module handling code.
 */
@:hscriptClass
class ScriptedTransition extends Transition implements polymod.hscript.HScriptedClass {}