package menus;

import haxe.io.Path;

import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.sound.FlxSound;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxAxes;
import flixel.util.FlxDestroyUtil;

import backend.MusicBeatSubState;
import backend.registries.ui.DialogueRegistry;
import backend.registries.ui.DialogueRegistry.DialogueSkinData;
import backend.registries.ui.DialogueRegistry.DialogueSongData;
import backend.registries.ui.DialogueRegistry.DialogueCharacterData;
import backend.registries.ui.DialogueRegistry.DialogueTextFontData;
import backend.registries.ui.DialogueRegistry.DialoguePortraitEntry;
import backend.registries.ui.DialogueRegistry.DialogueCharacterExpressionEntry;

import game.PlayState;

class DialogueSubState extends MusicBeatSubState
{
    var dialoguePos:Int = -1;

    var skinData:DialogueSkinData = null;
    var songData:DialogueSongData = null;

    var dataList:Map<String, DialogueCharacterData> = new Map();
    var characters:Map<String, Map<String, FunkinSprite>> = new Map();
    var vocals:Map<String, Array<FlxSound>> = new Map();

    var camDialogue:FlxCamera;
    var solid:FunkinSprite;

    var portraitGroup:FlxSpriteGroup;
    var boxGroup:FlxSpriteGroup;
    var textGroup:FlxSpriteGroup;

    var box:FunkinSprite;

    var wordQueue:Array<DialogueWord> = [];
    var currentWordIndex:Int = 0;
    var currentCharIndex:Int = 0;

    var currentPrintTime:Float = 0;
    var printSpeed:Float = 0.1;
    var globalTextTimer:Float = 0;

    var currentCharacter:String = "";
    var currentExpression:String = "";
    var currentColor:String = "";

    var transitioning:Bool = false;

    var lineAudioList:Array<FlxSound> = [];
    var lineVoicesList:Array<FlxSound> = [];

    var dialogueSong:FlxSound;

    override public function create():Void
    {
        loadData();

        if (songData == null || songData.dialogue == null || songData.dialogue.length == 0)
        {
            super.create();
            close();
            return;
        }

        initCameras();
        initGroups();

        loadSong();

        refreshBox();
        refreshPortraits();

        super.create();
    }

    function loadData():Void
    {
        var game = PlayState.instance;

        if (game == null)
            return;

        DialogueRegistry.reloadSong(game.name);
        songData = DialogueRegistry.getSong(game.name);

        DialogueRegistry.reloadSkin(songData.skin);
        skinData = DialogueRegistry.getSkin(songData.skin);
    }

    function initCameras():Void
    {
        var game = PlayState.instance;

        if (game != null)
        {
            FlxTween.tween(game.camHUD, {alpha: 0}, 0.2, {ease: FlxEase.sineOut});
            FlxTween.tween(game.camStrums, {alpha: 0}, 0.2, {ease: FlxEase.sineOut});
        }

        camDialogue = new FlxCamera();
        camDialogue.bgColor = 0x00000000;
        FlxG.cameras.add(camDialogue, false);

        solid = new FunkinSprite().makeGraphic(camDialogue.width, camDialogue.height, 0xFF000000);
        solid.camera = camDialogue;
        solid.alpha = 0;
        add(solid);

        FlxTween.tween(solid, {alpha: 0.4}, 0.5, {ease: FlxEase.sineOut});
    }

    function initGroups():Void
    {
        portraitGroup = new FlxSpriteGroup();
        boxGroup = new FlxSpriteGroup();
        textGroup = new FlxSpriteGroup();

        for (group in [portraitGroup, boxGroup, textGroup])
        {
            group.camera = camDialogue;
            add(group);
        }
    }

    function loadSong():Void
    {
        if (songData == null)
            return;

        dialogueSong = new FlxSound().loadEmbedded(Paths.music(songData.song.path));
        dialogueSong.volume = 0;
        dialogueSong.looped = songData.song.looped;
        FlxG.sound.list.add(dialogueSong);

        dialogueSong.play();

        if (songData.song.fadeIn)
            dialogueSong.fadeIn(songData.song.fadeInTime, 0, songData.song.volume);
        else
            dialogueSong.volume = songData.song.volume;
    }

    function refreshBox():Void
    {
        if (boxGroup != null)
        {
            boxGroup.forEachAlive(function(spr:FlxSprite) spr.destroy());
            boxGroup.clear();
        }

        var boxData = skinData.box;

        if (!Paths.exists("images/" + boxData.path + ".png"))
            return;

        box = new FunkinSprite();

        if (Paths.exists("images/" + boxData.path + ".xml"))
            box.frames = Paths.getSparrowAtlas(boxData.path);
        else
            box.loadGraphic(Paths.image(boxData.path));

        for (entry in boxData.animations)
        {
            if (entry.indices == null || entry.indices.length == 0)
                box.animation.addByPrefix(entry.name, entry.prefix, entry.fps, entry.looped, entry.flip[0], entry.flip[1]);
            else
                box.animation.addByIndices(entry.name, entry.prefix, entry.indices, "", entry.fps, entry.looped, entry.flip[0], entry.flip[1]);
        }

        box.scale.set(boxData.scale[0], boxData.scale[1]);
        box.updateHitbox();
        box.screenCenter();

        box.x += boxData.position[0];
        box.y += boxData.position[1];

        box.alpha = boxData.alpha;

        var startSuffix = songData.startingBoxSuffix != "" ? "-" + songData.startingBoxSuffix : "";
        var startAnim = "open-" + songData.dialogue[0].direction + startSuffix;

        if (box.animation.exists(startAnim))
        {
            playBoxAnim(startAnim);
            box.animation.onFinish.addOnce((_) -> start());
        }
        else
        {
            box.alpha = 0;
            FlxTween.tween(box, {alpha: boxData.alpha}, 0.3, {ease: FlxEase.sineOut, onComplete: (_) -> start()});
        }

        boxGroup.add(box);
    }

    function refreshPortraits():Void
    {
        if (portraitGroup != null)
        {
            portraitGroup.forEachAlive(function(spr:FlxSprite) spr.destroy());
            portraitGroup.clear();
        }

        var dialogueData = songData.dialogue;

        var characterList:Array<String> = [];
        var preloadList:Array<String> = [];

        for (entry in dialogueData)
        {
            if (!preloadList.contains(entry.character + ":" + entry.expression))
                preloadList.push(entry.character + ":" + entry.expression);

            if (!characterList.contains(entry.character))
                characterList.push(entry.character);
        }

        for (entry in characterList)
        {
            DialogueRegistry.reloadCharacter(entry);
            dataList[entry] = DialogueRegistry.getCharacter(entry);
        }

        for (i in 0...dialogueData.length)
        {
            var line = dialogueData[i];

            if (line.audio.path != "" && Paths.exists('audio/' + line.audio.path + '.ogg'))
            {
                var snd = new FlxSound().loadEmbedded(Paths.audio(line.audio.path));
                snd.volume = line.audio.volume;
                FlxG.sound.list.add(snd);

                lineAudioList[i] = snd;
            }

            if (line.field.audio.path != "" && Paths.exists('audio/' + line.field.audio.path + '.ogg'))
            {
                var snd = new FlxSound().loadEmbedded(Paths.audio(line.field.audio.path));
                snd.volume = line.field.audio.volume;
                FlxG.sound.list.add(snd);

                lineVoicesList[i] = snd;
            }
        }

        for (entry in preloadList)
        {
            var split = entry.split(":");

            var char = split[0];
            var expression = split[1];

            var data = dataList[char];
            var expressionData = getExpression(char, expression);

            loadBlips(char, expression);

            if (data == null || expressionData == null)
                continue;

            var spr = new FunkinSprite();

            if (Paths.exists("images/" + data.folder + "/" + expression + ".png"))
                spr.loadGraphic(Paths.image(data.folder + '/' + expression));

            spr.scale.set(expressionData.scale[0], expressionData.scale[1]);
            spr.updateHitbox();

            spr.screenCenter();

            spr.x += expressionData.position[0];
            spr.y += expressionData.position[1];

            spr.alpha = 0;
            spr.antialiasing = expressionData.antialiasing;

            portraitGroup.add(spr);

            if (!characters.exists(char))
                characters.set(char, new Map());

            characters.get(char).set(expression, spr);
        }
    }

    function loadBlips(char:String, expression:String):Void
    {
        if (vocals.exists(char))
            return;

        var base = "audio/sounds/gameplay/dialogue/characters/" + char;

        var audioPath = "";
        if (Paths.isDirectory(base + "/" + expression))
            audioPath = expression;
        else if (Paths.isDirectory(base + "/default"))
            audioPath = "default";

        var soundList:Array<FlxSound> = [];

        if (audioPath != "")
        {
            for (file in Paths.readDirectory(base + "/" + audioPath))
            {
                var snd = new FlxSound().loadEmbedded(Paths.sound('gameplay/dialogue/characters/' + char + '/' + audioPath + '/' + Path.withoutExtension(file)));
                snd.volume = 0;
                snd.play();
                snd.stop();
                FlxG.sound.list.add(snd);
                soundList.push(snd);
            }
        }

        vocals.set(char, soundList);
    }

    function start():Void
    {
        increment();
    }

    function increment():Void
    {
        if (dialoguePos >= songData.dialogue.length - 1)
        {
            trace("Finished Dialogue. Starting song...", "INFO");
            finish();
            return;
        }

        dialoguePos++;

        generatePortrait(dialoguePos);
        generateText(dialoguePos);
    }

    function playBoxAnim(animName:String):Void
    {
        if (box == null || box.animation == null)
            return;

        if (box.animation.exists(animName))
            box.animation.play(animName, true);

        box.updateHitbox();

        if (skinData == null || skinData.box == null || skinData.box.animations == null)
            return;

        for (entry in skinData.box.animations)
        {
            if (entry.name == animName && entry.offsets != null && entry.offsets.length >= 2)
            {
                box.offset.x += entry.offsets[0];
                box.offset.y += entry.offsets[1];
                break;
            }
        }
    }

    function generatePortrait(index:Int):Void
    {
        var indexData = songData.dialogue[index];

        if (indexData.audio.path != "")
        {
            for (snd in lineAudioList)
                if (snd != null) snd.stop();

            if (lineAudioList[index] != null)
                lineAudioList[index].play();
        }

        if (indexData.field.audio.path != "")
        {
            for (snd in lineVoicesList)
                if (snd != null) snd.stop();

            if (lineVoicesList[index] != null)
                lineVoicesList[index].play();
        }

        currentCharacter = indexData.character;
        currentExpression = indexData.expression;

        var characterData = dataList[currentCharacter];
        currentColor = (characterData != null) ? characterData.color : "#FFFFFF";

        var expressionData = getExpression(indexData.character, indexData.expression);
        var charSprites = characters.get(indexData.character);

        if (charSprites == null || expressionData == null)
            return;

        var charSprite = charSprites.get(indexData.expression);

        if (charSprite == null)
            return;

        for (spr in portraitGroup.members)
        {
            if (spr != null && spr != charSprite)
            {
                FlxTween.cancelTweensOf(spr);
                spr.alpha = 0;
            }
        }

        FlxTween.cancelTweensOf(charSprite);

        var boxSuffix = (indexData.boxSuffix != null && indexData.boxSuffix != "") ? "-" + indexData.boxSuffix : "";
        playBoxAnim(indexData.direction + boxSuffix);

        var charX = switch (indexData.direction)
        {
            case "left": -charSprite.width;
            case "right": charSprite.width;
            default: 0;
        }
        var charY = charSprite.y;

        var portraitData = getPortraitData(indexData.direction);

        if (portraitData.alphaTween.enabled)
        {
            charSprite.alpha = portraitData.alphaTween.values.from;
            FlxTween.tween(charSprite, {alpha: expressionData.alpha}, portraitData.alphaTween.duration, {ease: resolveEase(portraitData.alphaTween.ease)});
        }
        else
            charSprite.alpha = expressionData.alpha;

        if (portraitData.xTween.enabled)
        {
            charSprite.screenCenter(FlxAxes.X);
            charSprite.x += expressionData.position[0];
            var curX = charSprite.x + charX;

            charSprite.x = curX + portraitData.xTween.values.from;
            FlxTween.tween(charSprite, {x: curX}, portraitData.xTween.duration, {ease: resolveEase(portraitData.xTween.ease)});
        }
        else
        {
            charSprite.screenCenter(FlxAxes.X);
            charSprite.x += charX;
        }

        if (portraitData.yTween.enabled)
        {
            charSprite.screenCenter(FlxAxes.Y);
            charSprite.y += expressionData.position[1];
            FlxTween.tween(charSprite, {y: charY}, portraitData.yTween.duration, {ease: resolveEase(portraitData.yTween.ease)});
        }
        else
        {
            charSprite.screenCenter(FlxAxes.Y);
            charSprite.y += expressionData.position[1];
        }

        if (portraitData.scaleTween.enabled)
        {
            charSprite.scale.set(portraitData.scaleTween.values.from, portraitData.scaleTween.values.from);
            FlxTween.tween(charSprite, {"scale.x": expressionData.scale[0], "scale.y": expressionData.scale[1]}, portraitData.scaleTween.duration, {ease: resolveEase(portraitData.scaleTween.ease)});
        }
        else
            charSprite.scale.set(expressionData.scale[0], expressionData.scale[1]);

        if (portraitData.angleTween.enabled)
        {
            charSprite.angle = portraitData.angleTween.values.from;
            FlxTween.tween(charSprite, {angle: expressionData.angle}, portraitData.angleTween.duration, {ease: resolveEase(portraitData.angleTween.ease)});
        }
        else
            charSprite.angle = expressionData.angle;
    }

    function parseRichText(rawText:String, defaultSize:Int, defaultColor:Int, defaultSpeed:Float):Array<DialogueChunk>
    {
        var chunks:Array<DialogueChunk> = [];
        var regex = new EReg("<([^>]+)>", "g");

        var lastPos:Int = 0;

        var current:DialogueEffects =
        {
            size: defaultSize,
            color: defaultColor,
            wave: false,
            shake: 0.0,
            speed: defaultSpeed
        };

        while (regex.matchSub(rawText, lastPos))
        {
            var matchedPos = regex.matchedPos();
            var tag = regex.matched(1);

            var textBefore = rawText.substring(lastPos, matchedPos.pos);

            if (textBefore.length > 0)
                chunks.push({text: textBefore, effects: copyEffects(current)});

            if (StringTools.startsWith(tag, "/"))
            {
                var tagName = tag.substring(1);
                if (tagName == "size") current.size = defaultSize;
                if (tagName == "color") current.color = defaultColor;
                if (tagName == "wave") current.wave = false;
                if (tagName == "shake") current.shake = 0.0;
                if (tagName == "speed") current.speed = defaultSpeed;
            }
            else
            {
                var splitTag = tag.split("=");

                if (splitTag.length == 2)
                {
                    var tagName = splitTag[0];
                    var tagValue = splitTag[1];

                    if (tagName == "size")
                    {
                        var parsed = Std.parseInt(tagValue);
                        if (parsed != null) current.size = parsed;
                    }
                    if (tagName == "wave") current.wave = (tagValue == "true");
                    if (tagName == "shake") current.shake = Std.parseFloat(tagValue);
                    if (tagName == "speed") current.speed = Std.parseFloat(tagValue);

                    if (tagName == "color" && StringTools.startsWith(tagValue, "#"))
                    {
                        var parsed = Std.parseInt("0xFF" + tagValue.substring(1));
                        if (parsed != null) current.color = parsed;
                    }

                    if (tagName == "image")
                    {
                        var imgArgs = tagValue.split(":");

                        chunks.push(
                        {
                            isImage: true,
                            path: imgArgs[0],
                            width: imgArgs.length > 1 ? Std.parseInt(imgArgs[1]) : 0,
                            height: imgArgs.length > 2 ? Std.parseInt(imgArgs[2]) : 0,
                            effects: copyEffects(current)
                        });
                    }

                    if (tagName == "audio")
                    {
                        var audioArgs = tagValue.split(":");

                        chunks.push(
                        {
                            isAudio: true,
                            path: audioArgs[0],
                            volume: audioArgs.length > 1 ? Std.parseFloat(audioArgs[1]) : 1.0,
                            effects: copyEffects(current)
                        });
                    }
                }
            }

            lastPos = matchedPos.pos + matchedPos.len;
        }

        var remainder = rawText.substring(lastPos);
        if (remainder.length > 0)
            chunks.push({text: remainder, effects: copyEffects(current)});

        return chunks;
    }

    function generateText(index:Int):Void
    {
        if (textGroup != null)
        {
            textGroup.forEachAlive(function(spr:FlxSprite) spr.destroy());
            textGroup.clear();
        }

        if (box == null)
            return;

        var indexData = songData.dialogue[index];
        var fontData:DialogueTextFontData = null;

        for (entry in skinData.text.fonts)
        {
            if (entry.name == indexData.font)
            {
                fontData = entry;
                break;
            }
        }

        if (fontData == null)
            return;

        var fieldData = indexData.field;

        printSpeed = fieldData.speed;
        currentPrintTime = 0;

        wordQueue = [];
        currentWordIndex = 0;
        currentCharIndex = 0;

        var defColor:Int = 0xFFFFFFFF;
        if (fontData.color != null && StringTools.startsWith(fontData.color, "#"))
        {
            var parsed = Std.parseInt("0xFF" + fontData.color.substring(1));
            if (parsed != null) defColor = parsed;
        }

        var chunks = parseRichText(fieldData.text, fontData.size, defColor, printSpeed);

        var startX:Float = box.x + 50;
        var cursorX:Float = startX;
        var cursorY:Float = box.y + (box.height / 4) + 40;
        var maxWidth:Float = fontData.fieldWidth;
        var currentLineHeight:Float = 0;

        for (chunk in chunks)
        {
            if (chunk.isAudio == true)
            {
                wordQueue.push({isImage: false, isAudio: true, path: chunk.path, volume: chunk.volume == null ? 1.0 : chunk.volume, effects: chunk.effects});
                continue;
            }

            if (chunk.isImage == true)
            {
                var imgSprite = new FunkinSprite(cursorX, cursorY);
                imgSprite.loadGraphic(Paths.image(chunk.path));

                if (chunk.width != null && chunk.width > 0 && chunk.height != null && chunk.height > 0)
                {
                    imgSprite.setGraphicSize(chunk.width, chunk.height);
                    imgSprite.updateHitbox();
                    imgSprite.setPosition(cursorX, cursorY - (imgSprite.height / 4));
                }

                if (cursorX + imgSprite.width > startX + maxWidth && cursorX > startX)
                {
                    cursorX = startX;
                    cursorY += currentLineHeight;
                    currentLineHeight = 0;
                    imgSprite.x = cursorX;
                    imgSprite.y = cursorY;
                }

                if (imgSprite.height > currentLineHeight)
                    currentLineHeight = imgSprite.height;

                cursorX += imgSprite.width;

                imgSprite.visible = false;
                imgSprite.alpha = 0;
                textGroup.add(imgSprite);

                wordQueue.push({isImage: true, isAudio: false, sprite: imgSprite, effects: chunk.effects, baseX: imgSprite.x, baseY: imgSprite.y});
                continue;
            }

            if (chunk.text == null)
                continue;

            var words = chunk.text.split(" ");

            for (i in 0...words.length)
            {
                var wordText = words[i];
                if (i < words.length - 1) wordText += " ";

                if (wordText == "") continue;

                var textSprite = new FlxText(cursorX, cursorY, 0, wordText, chunk.effects.size);

                if (Paths.exists('fonts/' + fontData.file))
                    textSprite.font = Paths.font(fontData.file);

                textSprite.color = chunk.effects.color;
                textSprite.antialiasing = fontData.antialiasing;

                var parsedBorderColor:Int = 0xFF000000;

                if (fontData.borderColor != null)
                {
                    if (StringTools.startsWith(fontData.borderColor, "#"))
                    {
                        var parsed = Std.parseInt("0xFF" + fontData.borderColor.substring(1));
                        if (parsed != null) parsedBorderColor = parsed;
                    }
                }
                else if (currentColor != null && StringTools.startsWith(currentColor, "#"))
                {
                    var parsed = Std.parseInt("0xFF" + currentColor.substring(1));
                    if (parsed != null) parsedBorderColor = parsed;
                }

                if (fontData.shadow != null && (fontData.shadow.x != 0 || fontData.shadow.y != 0))
                {
                    textSprite.setBorderStyle(FlxTextBorderStyle.SHADOW, parsedBorderColor, fontData.borderSize);
                    textSprite.shadowOffset.set(fontData.shadow.x, fontData.shadow.y);
                }
                else
                    textSprite.setBorderStyle(FlxTextBorderStyle.OUTLINE, parsedBorderColor, fontData.borderSize);

                if (cursorX + textSprite.width > startX + maxWidth && cursorX > startX)
                {
                    cursorX = startX;
                    cursorY += currentLineHeight;
                    currentLineHeight = 0;
                    textSprite.x = cursorX;
                    textSprite.y = cursorY;
                }

                if (textSprite.height > currentLineHeight)
                    currentLineHeight = textSprite.height;

                cursorX += textSprite.width;

                textSprite.text = "";
                textGroup.add(textSprite);

                wordQueue.push({isImage: false, isAudio: false, fullText: wordText, sprite: textSprite, effects: chunk.effects, baseX: textSprite.x, baseY: textSprite.y});
            }
        }
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);

        handleInputs();
        handleTextRendering(elapsed);

        globalTextTimer += elapsed;

        var limit = currentWordIndex + 1;
        if (limit > wordQueue.length) limit = wordQueue.length;

        for (i in 0...limit)
        {
            var word = wordQueue[i];

            if (word.isAudio) continue;
            if (!word.effects.wave && word.effects.shake <= 0) continue;

            var active = word.isImage ? word.sprite.visible : (cast(word.sprite, FlxText).text != "");
            if (!active) continue;

            var targetX:Float = word.baseX;
            var targetY:Float = word.baseY;

            if (word.effects.wave)
                targetY += Math.sin((globalTextTimer * 8) + i) * 6;

            if (word.effects.shake > 0)
            {
                targetX += FlxG.random.float(-word.effects.shake, word.effects.shake);
                targetY += FlxG.random.float(-word.effects.shake, word.effects.shake);
            }

            word.sprite.x = targetX;
            word.sprite.y = targetY;
        }
    }

    function handleInputs():Void
    {
        if (!FlxG.keys.justPressed.ENTER)
            return;

        if (wordQueue.length == 0 || currentWordIndex >= wordQueue.length)
        {
            increment();
            return;
        }

        while (currentWordIndex < wordQueue.length)
        {
            var word = wordQueue[currentWordIndex];

            if (word.isImage)
            {
                word.sprite.visible = true;
                FlxTween.cancelTweensOf(word.sprite);
                word.sprite.alpha = 1;
            }
            else if (word.isAudio)
                FlxG.sound.play(Paths.audio(word.path), word.volume);
            else
                (cast(word.sprite, FlxText)).text = word.fullText;

            currentWordIndex++;
        }

        currentCharIndex = 0;
    }

    function handleTextRendering(elapsed:Float):Void
    {
        if (wordQueue.length == 0 || currentWordIndex >= wordQueue.length)
            return;

        if (printSpeed <= 0)
        {
            while (currentWordIndex < wordQueue.length)
            {
                var word = wordQueue[currentWordIndex];

                if (word.isImage)
                {
                    word.sprite.visible = true;
                    word.sprite.alpha = 1;
                }
                else if (word.isAudio)
                    FlxG.sound.play(Paths.audio(word.path), word.volume);
                else
                    (cast(word.sprite, FlxText)).text = word.fullText;

                currentWordIndex++;
            }
            return;
        }

        currentPrintTime += elapsed;

        while (currentWordIndex < wordQueue.length)
        {
            var word = wordQueue[currentWordIndex];
            var wordSpeed:Float = word.effects.speed;

            if (wordSpeed > 0 && currentPrintTime < wordSpeed)
                break;

            playSound();

            if (wordSpeed > 0)
                currentPrintTime -= wordSpeed;

            if (word.isAudio)
            {
                FlxG.sound.play(Paths.audio(word.path), word.volume);
                currentWordIndex++;
                continue;
            }

            if (word.isImage)
            {
                word.sprite.visible = true;
                var fadeSpeed = wordSpeed > 0 ? wordSpeed * 3 : 0.15;
                FlxTween.tween(word.sprite, {alpha: 1}, fadeSpeed, {ease: FlxEase.linear});

                currentWordIndex++;
                continue;
            }

            var textSprite:FlxText = cast word.sprite;
            textSprite.text += word.fullText.charAt(currentCharIndex);
            currentCharIndex++;

            if (currentCharIndex >= word.fullText.length)
            {
                currentCharIndex = 0;
                currentWordIndex++;
            }
        }
    }

    function playSound():Void
    {
        var vocalList = vocals.get(currentCharacter);

        if (vocalList == null || vocalList.length == 0)
            return;

        for (vocal in vocalList)
            if (vocal != null) vocal.stop();

        var index = FlxG.random.int(0, vocalList.length - 1);
        var snd = vocalList[index];

        if (snd == null)
            return;

        if (snd.volume != 1)
            snd.volume = 1;

        snd.play();
    }

    function finish():Void
    {
        if (transitioning)
            return;

        transitioning = true;

        if (dialogueSong != null)
        {
            var song = dialogueSong;
            dialogueSong = null;

            if (songData.song.fadeOut)
                song.fadeOut(songData.song.fadeOutTime, 0, (_) -> destroySound(song));
            else
                song.volume = songData.song.volume;
        }

        FlxTween.tween(solid, {alpha: 0}, 0.15);

        for (group in [boxGroup, portraitGroup, textGroup])
        {
            if (group == null) continue;

            for (item in group.members)
                if (item != null) FlxTween.tween(item, {alpha: 0}, 0.15);
        }

        for (soundList in vocals)
        {
            if (soundList == null) continue;

            for (snd in soundList)
                if (snd != null) FlxTween.tween(snd, {volume: 0}, 0.15);
        }

        var game = PlayState.instance;

        if (game == null)
        {
            close();
            return;
        }

        FlxTween.tween(game.camHUD, {alpha: 1}, 0.2);
        FlxTween.tween(game.camStrums, {alpha: 1}, 0.2, {onComplete: (_) -> close()});
    }

    function getExpression(character:String, expression:String):DialogueCharacterExpressionEntry
    {
        var data = dataList[character];
        if (data == null || data.expressions == null)
            return null;

        for (e in data.expressions)
            if (e.name == expression) return e;

        return null;
    }

    inline function getPortraitData(direction:String):DialoguePortraitEntry
    {
        return switch (direction)
        {
            case "right": skinData.portraits.right;
            case "center": skinData.portraits.center;
            default: skinData.portraits.left;
        }
    }

    function resolveEase(name:String):Float->Float
    {
        var fn:Dynamic = (name == null) ? null : Reflect.field(FlxEase, name);
        if (fn == null)
            return FlxEase.linear;
        return fn;
    }

    inline function copyEffects(e:DialogueEffects):DialogueEffects
    {
        return {size: e.size, color: e.color, wave: e.wave, shake: e.shake, speed: e.speed};
    }

    function destroySound(snd:FlxSound):Void
    {
        if (snd == null)
            return;

        snd.stop();
        FlxG.sound.list.remove(snd, true);
        snd.destroy();
    }

    override public function destroy():Void
    {
        portraitGroup = FlxDestroyUtil.destroy(portraitGroup);
        textGroup = FlxDestroyUtil.destroy(textGroup);

        boxGroup = FlxDestroyUtil.destroy(boxGroup);
        box = null;

        solid = FlxDestroyUtil.destroy(solid);

        if (camDialogue != null)
        {
            if (FlxG.cameras.list.contains(camDialogue))
                FlxG.cameras.remove(camDialogue, true);
            camDialogue = null;
        }

        destroySound(dialogueSong);
        dialogueSong = null;

        if (lineAudioList != null)
        {
            for (snd in lineAudioList) destroySound(snd);
            lineAudioList = null;
        }

        if (lineVoicesList != null)
        {
            for (snd in lineVoicesList) destroySound(snd);
            lineVoicesList = null;
        }

        if (vocals != null)
        {
            for (soundList in vocals)
                if (soundList != null)
                    for (snd in soundList) destroySound(snd);

            vocals = null;
        }

        wordQueue = null;
        characters = null;
        dataList = null;
        skinData = null;
        songData = null;

        super.destroy();
    }
}

private typedef DialogueEffects =
{
    var size:Int;
    var color:Int;
    var wave:Bool;
    var shake:Float;
    var speed:Float;
}

private typedef DialogueChunk =
{
    var effects:DialogueEffects;
    @:optional var text:String;
    @:optional var isImage:Null<Bool>;
    @:optional var isAudio:Null<Bool>;
    @:optional var path:String;
    @:optional var width:Null<Int>;
    @:optional var height:Null<Int>;
    @:optional var volume:Null<Float>;
}

private typedef DialogueWord =
{
    var isImage:Bool;
    var isAudio:Bool;
    var effects:DialogueEffects;
    @:optional var fullText:String;
    @:optional var sprite:FlxSprite;
    @:optional var baseX:Float;
    @:optional var baseY:Float;
    @:optional var path:String;
    @:optional var volume:Float;
}
