package game.handlers;

import openfl.utils.Assets;
import haxe.io.Path;

import sys.FileSystem;
import json2object.JsonParser;

import backend.assets.AsyncPaths;
import backend.assets.Paths;
import game.world.Stage;

import backend.registries.misc.PreloaderRegistry;

import backend.registries.song.ChartRegistry;
import backend.registries.song.MetaRegistry;

import backend.registries.world.CharacterRegistry;
import backend.registries.world.StageRegistry;

import flixel.graphics.FlxGraphic;
import openfl.media.Sound;

using StringTools;

class Preloader
{
    public static function start(name:String, difficulty:String, variation:String, onComplete:Void->Void):Void
    {
        Sys.println('');

        var requestedAssets:Map<String, Bool> = [];
        var tasks:Array<Void->Void> = [];

        var totalAssets:Int = 0;
        var loadedAssets:Int = 0;

        PreloaderRegistry.reload(name);
        var data:PreloaderData = PreloaderRegistry.get(name);

        var addToQueue = function(path:String, task:Void->Void)
        {
            var key = path.toLowerCase();

            if (requestedAssets.exists(key)) return;
            requestedAssets.set(key, true);
            tasks.push(task);
            totalAssets++;
        };

        var nextTask:Void->Void = null;
        nextTask = function()
        {
            if (tasks.length > 0)
            {
                var currentTask = tasks.shift();
                currentTask();
            }
            else if (onComplete != null)
            {
                Sys.println('');
                onComplete();
            }
        };

        var checkDone = function(?message:String)
        {
            loadedAssets++;

            if (message != null)
                trace('$message [$loadedAssets/$totalAssets]', "PRELOAD");

            nextTask();
        };

        var _chart = ChartRegistry.get(name, difficulty, variation);
        var _meta = MetaRegistry.get(name, variation);

        if (data.general.characters)
        {
            for (_strumline in _chart.strumlines)
            {
                var _name = _strumline.character;

                var _path:String = 'images/characters/$_name';

                for (_file in Paths.readDirectoryRecursive(_path))
                {
                    var _fullPath:String = '$_path/$_file';

                    if (_file.endsWith('.png'))
                    {
                        addToQueue(_fullPath, function()
                        {
                            AsyncPaths.image('assets/' + _fullPath, "", "", true, false, true, function(g)
                            {
                                checkDone('(Character Asset) Preloaded: $_name/${_file.replace(".png", "")}');
                            });
                        });
                    }
                    else if (_file.endsWith('.xml') || _file.endsWith('.json'))
                    {
                        addToQueue(_fullPath, function()
                        {
                            AsyncPaths.data('assets/' + _fullPath, "", true, function(d)
                            {
                                checkDone('(Character Data) Preloaded: $_name/$_file');
                            });
                        });
                    }
                }
            }
        }

        if (data.general.stage)
        {
            var _stageData = StageRegistry.get(_meta.stage);

            if (_stageData != null && _stageData.sprites != null)
            {
                for (_sprite in _stageData.sprites)
                {
                    var _path:String = 'images/${_sprite.path}.png';

                    addToQueue(_path, function()
                    {
                        AsyncPaths.image('assets/' + _path, "", "", true, false, true, function(g)
                        {
                            checkDone('(Stage) Preloaded: ${_sprite.name}');
                        });
                    });

                    var _xmlPath:String = 'images/${_sprite.path}.xml';
                    if (Paths.exists(_xmlPath))
                    {
                        addToQueue(_xmlPath, function()
                        {
                            AsyncPaths.data('assets/' + _xmlPath, "", true, function(d)
                            {
                                checkDone();
                            });
                        });
                    }
                }
            }
        }

        if (data.general.song)
        {
            var songFiles = Paths.readDirectoryRecursive('songs/$name');

            for (file in songFiles)
            {
                if (Path.extension(file) == "ogg")
                {
                    var cacheKey = 'assets/songs/$name/$file';

                    addToQueue(cacheKey, function()
                    {
                        AsyncPaths.audio(cacheKey, "", "", true, false, true, false, function(s)
                        {
                            checkDone('(Song) Preloaded: $file');
                        });
                    });
                }
            }
        }

        if (data.general.noteskins)
        {
            for (_strumline in _chart.strumlines)
            {
                var _skinPaths = ['${_strumline.skin}.png', '${_strumline.skin}_ek.png'];
                var _coverPaths = ['covers/${_strumline.skin}/blue.png', 'covers/${_strumline.skin}/green.png', 'covers/${_strumline.skin}/purple.png', 'covers/${_strumline.skin}/red.png'];
                var _splashPaths = ['splashes/${_strumline.skin}.png', 'splashes/${_strumline.skin}_ek.png'];

                for (_p in _skinPaths)
                {
                    var pth = 'images/game/notes/$_p';
                    addToQueue(pth, function()
                    {
                        AsyncPaths.image('assets/' + pth, "", "", true, false, true, function(g)
                        {
                            checkDone('(Note Skin) Preloaded Noteskin: $_p');
                        });
                    });

                    var xmlPth = pth.replace(".png", ".xml");
                    if (Paths.exists(xmlPth))
                    {
                        addToQueue(xmlPth, function()
                        {
                            AsyncPaths.data('assets/' + xmlPth, "", true, function(d) { checkDone(); });
                        });
                    }
                }

                for (_p in _coverPaths)
                {
                    var pth = 'images/game/notes/$_p';
                    addToQueue(pth, function()
                    {
                        AsyncPaths.image('assets/' + pth, "", "", true, false, true, function(g)
                        {
                            checkDone('(Cover Skin) Preloaded Hold Cover: $_p');
                        });
                    });

                    var xmlPth = pth.replace(".png", ".xml");
                    if (Paths.exists(xmlPth))
                    {
                        addToQueue(xmlPth, function()
                        {
                            AsyncPaths.data('assets/' + xmlPth, "", true, function(d) { checkDone(); });
                        });
                    }
                }

                for (_p in _splashPaths)
                {
                    var pth = 'images/game/notes/$_p';
                    addToQueue(pth, function()
                    {
                        AsyncPaths.image('assets/' + pth, "", "", true, false, true, function(g)
                        {
                            checkDone('(Splash Skin) Preloaded Splash: $_p');
                        });
                    });

                    var xmlPth = pth.replace(".png", ".xml");
                    if (Paths.exists(xmlPth))
                    {
                        addToQueue(xmlPth, function()
                        {
                            AsyncPaths.data('assets/' + xmlPth, "", true, function(d) { checkDone(); });
                        });
                    }
                }
            }
        }

        if (data.general.countdown)
        {
            var _pathSkin:String = 'images/game/ui/countdown/${_meta.countdown.skin}';
            var _pathAudio:String = 'audio/sounds/gameplay/intro/${_meta.countdown.audio}';

            var _skinNames:Array<String> = ['threeSpr', 'twoSpr', 'oneSpr', 'goSpr'];
            var _audioNames:Array<String> = ['intro3', 'intro2', 'intro1', 'introGo'];

            for (_file in _skinNames)
            {
                var pth = '$_pathSkin/$_file.png';
                addToQueue(pth, function()
                {
                    AsyncPaths.image('assets/' + pth, "", "", true, false, true, function(g)
                    {
                        checkDone('(Countdown) Preloaded Asset: ${_meta.countdown.skin}/$_file.png');
                    });
                });
            }

            for (_file in _audioNames)
            {
                var pth = '$_pathAudio/$_file.ogg';
                addToQueue(pth, function()
                {
                    AsyncPaths.audio('assets/' + pth, "", "", true, false, true, false, function(g)
                    {
                        checkDone('(Countdown) Preloaded Sound: ${_meta.countdown.audio}/$_file.ogg');
                    });
                });
            }
        }

        if (data.general.ratings)
        {
            var _ratings:Array<String> = ['sick', 'good', 'bad', 'shit'];
            var _combos:Array<String> = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'x'];

            for (_rating in _ratings)
            {
                var pth = 'images/game/ui/ratings/${_meta.ratings.skin}/$_rating.png';
                addToQueue(pth, function()
                {
                    AsyncPaths.image('assets/' + pth, "", "", true, false, true, function(g)
                    {
                        checkDone('(Ratings) Preloaded Rating: ${_meta.ratings.skin}/$_rating.png');
                    });
                });
            }

            for (_combo in _combos)
            {
                var pth = 'images/game/ui/ratings/${_meta.ratings.skin}/combo/$_combo.png';
                addToQueue(pth, function()
                {
                    AsyncPaths.image('assets/' + pth, "", "", true, false, true, function(g)
                    {
                        checkDone('(Ratings) Preloaded Combo: ${_meta.ratings.skin}/combo/$_combo.png');
                    });
                });
            }
        }

        for (_extra in data.extras)
        {
            if (_extra == null || _extra.path == null || _extra.path == "") continue;

            var _type:String = (_extra.type != null ? _extra.type : "image").toLowerCase();
            var _extraPath:String = _extra.path;

            switch (_type)
            {
                case "image":
                    var pth = 'images/$_extraPath.png';
                    addToQueue(pth, function()
                    {
                        AsyncPaths.image('assets/' + pth, "", "", true, false, true, function(g)
                        {
                            checkDone('(Extra) Preloaded Image: $_extraPath');
                        });
                    });

                case "sound":
                    var pth = 'audio/sounds/$_extraPath.ogg';
                    addToQueue(pth, function()
                    {
                        AsyncPaths.audio('assets/' + pth, "", "", true, false, true, false, function(s)
                        {
                            checkDone('(Extra) Preloaded Sound: $_extraPath');
                        });
                    });

                case "music":
                    var pth = 'audio/music/$_extraPath.ogg';
                    addToQueue(pth, function()
                    {
                        AsyncPaths.audio('assets/' + pth, "", "", true, false, true, false, function(s)
                        {
                            checkDone('(Extra) Preloaded Music: $_extraPath');
                        });
                    });

                case "data":
                    var pth = _extraPath;
                    addToQueue(pth, function()
                    {
                        AsyncPaths.data('assets/' + pth, "", true, function(d)
                        {
                            checkDone('(Extra) Preloaded Data: $_extraPath');
                        });
                    });

                default:
                    trace('Unknown extra preload type "$_type" for "$_extraPath", skipping.', "WARNING");
            }
        }

        if (Constants.PRELOAD_ASSETS.length > 0)
        {
            for (_asset in Constants.PRELOAD_ASSETS)
            {
                var pth = '$_asset.png';
                addToQueue(pth, function()
                {
                    AsyncPaths.image('assets/' + pth, "", "", true, false, true, function(g)
                    {
                        checkDone('(Miscellaneous) Preloaded Asset: $pth');
                    });
                });
            }
        }

        if (Constants.PRELOAD_SOUNDS.length > 0)
        {
            for (_sound in Constants.PRELOAD_SOUNDS)
            {
                var pth = '$_sound.ogg';
                addToQueue(pth, function()
                {
                    AsyncPaths.audio('assets/' + pth, "", "", true, false, true, false, function(g)
                    {
                        checkDone('(Miscellaneous) Preloaded Sound: $pth');
                    });
                });
            }
        }

        nextTask();
    }
}
