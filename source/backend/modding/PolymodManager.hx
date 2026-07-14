package backend.modding;

import openfl.utils.Assets;

import sys.FileSystem;
import sys.io.File;

import polymod.Polymod;
import polymod.fs.SysFileSystem;
import polymod.hscript._internal.Expr.CType;

import backend.modding.handlers.*;
import backend.assets.Paths;

import thx.semver.Version;
import thx.semver.VersionRule;

typedef StaticModuleHandler = { public function load():Void; }

/**
 * A class, managing and implementing the Polymod modding system into the mod.
 */
@:keep
class PolymodManager
{
    /**
     * Internal variable containing every handler to call function from.
     */
    private static var handlers:Array<StaticModuleHandler> = [CharacterHandler, ModuleHandler, SongModuleHandler, SongEventModuleHandler, StageHandler];

    /**
     * All the currently loaded mods.
     */
    public static var loadedMods:Array<ModMetadata> = [];

    /**
     * A list of ALL mods found in the mod folder, regardless of whether they are active.
     */
    public static var availableMods:Array<ModMetadata> = [];

    /**
     * The folder ID of the currently active mod.
     */
    public static var activeMod:String = "";

    /**
     * The file system for all the mods.
     */
    public static var modFileSystem:SysFileSystem = null;

    public static function setup():Void
    {
        modFileSystem = new SysFileSystem({modRoot: Constants.MOD_FOLDER});

        initImports();

        Configs.load();

        if (Configs.ACTIVE_MOD != "")
            enableMod(Configs.ACTIVE_MOD);

        readAvaliableMods();
    }

    /**
     * Initializes every import that's gonna be automatically imported in each scripted class and blacklists classes that could harm your PC.
     */
    public static function initImports():Void
    {
        Polymod.addDefaultImport(Date);
        Polymod.addDefaultImport(DateTools);
        Polymod.addDefaultImport(EReg);
        Polymod.addDefaultImport(StringTools);
        Polymod.addDefaultImport(IntIterator);
        Polymod.addDefaultImport(Reflect);

        Polymod.addDefaultImport(backend.Manager);
        Polymod.addDefaultImport(backend.MusicBeatState);
        Polymod.addDefaultImport(backend.MusicBeatSubState);
        
        Polymod.addDefaultImport(backend.Configs);
        Polymod.addDefaultImport(backend.Constants);

        Polymod.addDefaultImport(backend.assets.Paths);
        Polymod.addDefaultImport(backend.assets.Cacher);
        Polymod.addDefaultImport(backend.assets.FunkinSprite);

        Polymod.addDefaultImport(backend.modding.PolymodManager);
        Polymod.addDefaultImport(backend.modding.ModState);
        Polymod.addDefaultImport(backend.modding.events.ScriptEvent);
        Polymod.addDefaultImport(backend.modding.modules.Module);
        Polymod.addDefaultImport(backend.modding.modules.BackingCard);
        Polymod.addDefaultImport(backend.modding.handlers.BackingCardHandler);
        Polymod.addDefaultImport(backend.modding.songs.SongModule);
        Polymod.addDefaultImport(backend.modding.songs.SongEventModule);

        Polymod.addDefaultImport(backend.shaders.AngleMask);
        Polymod.addDefaultImport(backend.shaders.GaussianBlurShader);
        Polymod.addDefaultImport(backend.shaders.StrokeShader);

        Polymod.addDefaultImport(backend.utils.FileUtil);
        Polymod.addDefaultImport(backend.utils.MathUtil);
        Polymod.addDefaultImport(backend.utils.WindowUtil);
        Polymod.addDefaultImport(backend.utils.StringUtil);

        Polymod.addDefaultImport(backend.transition.Transition);
        Polymod.addDefaultImport(backend.transition.TransitionState);
        Polymod.addDefaultImport(backend.transition.Transition.StickerSprite);

        Polymod.addDefaultImport(backend.registries.world.CharacterRegistry);
        
        Polymod.addDefaultImport(backend.registries.song.ChartRegistry);
        Polymod.addDefaultImport(backend.registries.song.MetaRegistry);
        Polymod.addDefaultImport(backend.registries.song.DifficultyRegistry);
        Polymod.addDefaultImport(backend.registries.song.EventRegistry);

        Polymod.addDefaultImport(backend.registries.misc.ConfigRegistry);

        Polymod.addDefaultImport(backend.registries.ui.DialogueRegistry);

        Polymod.addDefaultImport(backend.registries.menus.TitleMenuRegistry);

        Polymod.addDefaultImport(backend.ui.Button);
        Polymod.addDefaultImport(backend.ui.Slider);
        Polymod.addDefaultImport(backend.ui.ContextMenu);
        Polymod.addDefaultImport(backend.ui.InteractiveWindow);
        Polymod.addDefaultImport(backend.ui.Stepper);
        Polymod.addDefaultImport(backend.ui.Separator);
        Polymod.addDefaultImport(backend.ui.Label);
        Polymod.addDefaultImport(backend.ui.Dropdown);
        Polymod.addDefaultImport(backend.ui.Bar);
        Polymod.addDefaultImport(backend.ui.Checkbox);
        Polymod.addDefaultImport(backend.ui.InputBox);
        Polymod.addDefaultImport(backend.ui.BGScrollingText);

        Polymod.addDefaultImport(flixel.FlxBasic);
        Polymod.addDefaultImport(flixel.FlxCamera);
        Polymod.addDefaultImport(flixel.FlxG);
        Polymod.addDefaultImport(flixel.FlxGame);
        Polymod.addDefaultImport(flixel.FlxObject);
        Polymod.addDefaultImport(flixel.FlxSprite);
        Polymod.addDefaultImport(flixel.FlxState);
        Polymod.addDefaultImport(flixel.FlxStrip);
        Polymod.addDefaultImport(flixel.FlxSubState);
        Polymod.addDefaultImport(flixel.group.FlxSpriteGroup);

        Polymod.addDefaultImport(flixel.graphics.FlxGraphic);

        Polymod.addDefaultImport(flixel.util.FlxTimer);
        Polymod.addDefaultImport(flixel.util.FlxSpriteUtil);
        Polymod.addDefaultImport(flixel.util.FlxDestroyUtil);

        Polymod.addDefaultImport(flixel.addons.display.FlxBackdrop);
        Polymod.addDefaultImport(flixel.addons.text.FlxTypeText);

        Polymod.addDefaultImport(flixel.sound.FlxSound);
        Polymod.addDefaultImport(backend.assets.FunkinSound);

        Polymod.addDefaultImport(flixel.math.FlxMath);
        Polymod.addDefaultImport(flixel.math.FlxRect);

        Polymod.addDefaultImport(flixel.tweens.FlxTween);
        Polymod.addDefaultImport(flixel.tweens.FlxEase);

        Polymod.addDefaultImport(flixel.text.FlxText);

        Polymod.addDefaultImport(flixel.text.FlxBitmapText);
        Polymod.addDefaultImport(backend.assets.FunkinBitmapText);
        Polymod.addDefaultImport(backend.assets.AtlasText);
        Polymod.addDefaultImport(flixel.graphics.frames.FlxBitmapFont);

        Polymod.addDefaultImport(flixel.ui.FlxBar);
        Polymod.addDefaultImport(flixel.addons.display.FlxPieDial);

        Polymod.addDefaultImport(flixel.addons.display.FlxRuntimeShader);
        
        Polymod.addDefaultImport(openfl.filters.ShaderFilter);
        Polymod.addDefaultImport(openfl.utils.Assets);

        Polymod.addDefaultImport(openfl.display.BitmapData);
        Polymod.addDefaultImport(openfl.display.ShaderInput);
        Polymod.addDefaultImport(openfl.display.ShaderParameter);

        Polymod.addDefaultImport(openfl.geom.Vector3D);

        Polymod.addDefaultImport(flixel.addons.display.shapes.FlxShapeLine);

        Polymod.addDefaultImport(flash.geom.ColorTransform);

        Polymod.addDefaultImport(game.PlayState);

        Polymod.addDefaultImport(game.notes.Strum);
        Polymod.addDefaultImport(game.notes.Note);

        Polymod.addDefaultImport(game.world.Character);
        Polymod.addDefaultImport(game.world.Stage);

        Polymod.addDefaultImport(game.handlers.Conductor);
        Polymod.addDefaultImport(game.handlers.Preloader);
        Polymod.addDefaultImport(game.handlers.Song);

        Polymod.blacklistImport('Sys');
    }

    /**
     * Reads every avaliable mod and updates the array/
     */
    public static function readAvaliableMods():Void
    {
        availableMods = getAllMods();
    }

    /**
     * Loads only the single mod currently set as `activeMod`.
     */
    public static function loadActiveMods():Void
    {
        var availableIds:Array<String> = [for (mod in availableMods) mod.id];
        
        if (activeMod != "" && availableIds.contains(activeMod))
            loadModsById([activeMod]); 
        else
            loadModsById([]);
    }

    /**
     * Sets a mod as the active mod.
     * @param id The folder name of the mod to enable.
     * @param autoReload Whether to immediately reload the mod file system.
     */
    public static function enableMod(id:String, autoReload:Bool = true):Void
    {
        if (activeMod != id)
        {
            activeMod = id;

            Configs.ACTIVE_MOD = activeMod;
            Configs.save();

            if (autoReload) invalidateAndReload();
        }
    }

    /**
     * Disables the currently active mod.
     * @param autoReload Whether to immediately reload the mod file system.
     */
    public static function disableMod(autoReload:Bool = true):Void
    {
        activeMod = "";

        Configs.ACTIVE_MOD = activeMod;
        Configs.save();

        if (autoReload) invalidateAndReload();
    }

    /**
     * Fully invalidates every cached asset before reloading the mod file system.
     * Required when the active mod changes, since any asset may now be overridden.
     */
    private static function invalidateAndReload():Void
    {
        backend.assets.Cacher.instance.clearAll();
        backend.assets.AtlasText.flushFonts();
        Polymod.clearCache();

        reloadMods();
    }

    /**
     * Retrieves a list of all mods, and their metadata from the game's mod folder.
     * @return An `Array<ModMetadata>`
     */
    public static function getAllMods():Array<ModMetadata>
    {
        Paths.createDirectory(Constants.MOD_FOLDER);
        
        var mods = Polymod.scan(
        {
            modRoot: Constants.MOD_FOLDER,
            fileSystem: modFileSystem,
            apiVersionRule: Constants.API_VERSION_RULE,
            errorCallback: PolymodErrorHandler.printError,
        });

        if (mods.length == 0)
            trace('Polymod did not find any mods', "POLYMOD", true);
        else
            trace('Polymod found ${mods.length} mod(s) while scanning.', "POLYMOD", true);

        return mods;
    }

    /**
     * Loads a list of mods by their directory id name.
     * @param ids The list of mod directorys to load.
     */
    public static function loadModsById(ids:Array<String>)
    {
        Paths.createDirectory(Constants.MOD_FOLDER);

		loadedMods = Polymod.init(
        {
			modRoot: './${Constants.MOD_FOLDER}/',
            dirs: ids,
			framework: OPENFL,
            customFilesystem: modFileSystem,
            errorCallback: PolymodErrorHandler.printError,
            apiVersionRule: Constants.API_VERSION_RULE,
            useScriptedClasses: true,
		});

        if (loadedMods.length == 0)
            trace('Polymod was not able to load any mods.', "POLYMOD");
        else
            trace('Successfully loaded ${loadedMods.length} mod(s)!', "POLYMOD");
    }

    /**
     * Performs a full, heavy reload of the entire mod file system.
     * Use this ONLY when changing which mod folders are active in a menu.
     */
    public static function reloadMods()
    {
        Polymod.clearScripts();

        loadActiveMods();

        registerLooseScripts();

        for (handler in handlers)
            handler.load();

        Paths.ensureRevAssets();
    }

    /**
     * Registers any scripts found in the root assets folder but were never recognized by Polymod.
     */
    @:access(polymod.hscript._internal.PolymodScriptClass)
    public static function registerLooseScripts():Void
    {
        #if sys
        var folder:String = 'assets/${Constants.SCRIPT_FOLDER}';

        if (!FileSystem.exists(folder) || !FileSystem.isDirectory(folder))
            return;

        var known:Map<String, Bool> = new Map();
        
        for (name in polymod.hscript._internal.PolymodScriptClass.listScriptClasses())
            known.set(name, true);

        var scriptAmount:Int = scanLooseScripts(folder, polymod.PolymodConfig.scriptClassExt);

        if (scriptAmount > 0)
        {
            normalizeNewSuperclasses(known);
            trace('Loaded $scriptAmount new script(s) without recompiling.', "POLYMOD");
        }
        #end
    }

    #if sys
    /**
     * Resolves the superclass of every newly registered scripted class from its class name name to its full path.
     * @param known The set of class names that already existed before the loose scan.
     */
    @:access(polymod.hscript._internal.PolymodInterpEx)
    static function normalizeNewSuperclasses(known:Map<String, Bool>):Void
    {
        for (name => cls in polymod.hscript._internal.PolymodInterpEx._scriptClassDescriptors)
        {
            if (known.exists(name)) continue;

            switch (cls.extend)
            {
                case CTPath(path, params):
                {
                    if (path == null || path.length == 0) continue;

                    var shortName:String = path[path.length - 1];

                    if (cls.imports.exists(shortName))
                    {
                        var fullPath:String = cls.imports.get(shortName).fullPath;

                        if (fullPath != null && fullPath != "")
                            cls.extend = CTPath(fullPath.split('.'), params);
                    }
                }

                case _:
            }
        }
    }
    #end

    #if sys
    /**
     * Recursively scans the given directory, registering any script files that are not recognized by Polymod.
     * @param dir The directory to scan.
     * @param extensions The script file extensions to look for.
     * @return How many new scripts were registered.
     */
    @:access(polymod.hscript._internal.PolymodScriptClass)
    static function scanLooseScripts(dir:String, extensions:Array<String>):Int
    {
        var registered:Int = 0;

        for (entry in FileSystem.readDirectory(dir))
        {
            var fullPath:String = '$dir/$entry';

            if (FileSystem.isDirectory(fullPath))
            {
                registered += scanLooseScripts(fullPath, extensions);
                continue;
            }

            var isScript:Bool = false;

            for (ext in extensions)
            {
                if (StringTools.endsWith(fullPath, ext))
                {
                    isScript = true;
                    break;
                }
            }

            if (!isScript) continue;
            if (Assets.exists(fullPath)) continue;

            try
            {
                var body:String = File.getContent(fullPath);
                polymod.hscript._internal.PolymodScriptClass.registerScriptClassByString(body, fullPath);
                registered++;
            }
            catch (e:Dynamic)
            {
                trace('Failed to register loose script "$fullPath": $e', "POLYMOD");
            }
        }

        return registered;
    }
    #end
}