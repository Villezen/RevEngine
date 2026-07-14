package menus;

import backend.MusicBeatSubState;

/**
 * Compiled stub for the freeplay menu.
 *
 * The real implementation is scripted: `assets/scripts/substates/FreeplaySubStateScript.hx`.
 * Opening `FreeplaySubState` is redirected there by the `overrides.states` entry in
 * `config.json`, so this stub only needs to exist for `Type.resolveClass("menus.FreeplaySubState")`
 * to succeed in `MainMenuState` before the redirect kicks in.
 *
 * The capsule classes it uses (`menus.freeplay.SongMenuItem` / `CapsuleText` / `CapsuleNumber`)
 * are compiled and kept in the build via `-dce no` + `--macro include('menus')`, so the script
 * can reference them directly.
 */
class FreeplaySubState extends MusicBeatSubState {}
