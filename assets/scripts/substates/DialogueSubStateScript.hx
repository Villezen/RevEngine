import flixel.group.FlxSpriteGroup;
import flixel.text.FlxTextBorderStyle;
import haxe.io.Path;

class DialogueSubStateScript extends MusicBeatSubState
{
    var dialoguePos = -1;

    var skinData = null;
    var songData = null;

    var characters:Dynamic = {};
    var vocals:Dynamic = {};

    var dataList = ["" => []];

    var box:FlxSprite;

    var wordQueue:Array<Dynamic> = [];
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

    override function create()
    {
        initCameras();
        initGroups();
        
        loadData();
        loadSong();

        refreshBox();
        refreshPortraits();

        super.create();
    }

    function initCameras()
    {
        var game = PlayState.instance;

        if (game != null)
        {
            FlxTween.tween(game.camHUD, {alpha: 0}, 0.2, {ease: FlxEase.sineOut});
            FlxTween.tween(game.camStrums, {alpha: 0}, 0.2, {ease: FlxEase.sineOut});

            game = null;
        }

        camDialogue = new FlxCamera();
        camDialogue.bgColor = 0x00000000;
        FlxG.cameras.add(camDialogue, false);

        solid = new FlxSprite().makeGraphic(camDialogue.width, camDialogue.height, 0xFF000000);
        solid.camera = camDialogue;
        solid.alpha = 0;
        add(solid);

        FlxTween.tween(solid, {alpha: 0.4}, 0.5, {ease: FlxEase.sineOut});
    }

    function initGroups()
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

    function loadData()
    {
        var game = PlayState.instance;

        if (game == null)
            return;

        DialogueRegistry.reloadSong(game.name);
        songData = DialogueRegistry.getSong(game.name);

        DialogueRegistry.reloadSkin(songData.skin);
        skinData = DialogueRegistry.getSkin(songData.skin);
    }

    function loadSong()
    {
        dialogueSong = new FlxSound().loadEmbedded(Paths.music(songData.song.path));
        dialogueSong.volume = 0;
        dialogueSong.looped = songData.song.looped;
        FlxG.sound.list.add(dialogueSong);

        if (dialogueSong != null)
        {
            dialogueSong.play();

            if (songData.song.fadeIn)
                dialogueSong.fadeIn(songData.song.fadeInTime, 0, songData.song.volume);
            else
                dialogueSong.volume = songData.song.volume;
        }
    }

    function refreshBox()
    {
        if (boxGroup != null)
        {
            boxGroup.forEachAlive(function(spr:FlxSprite)
            {
                remove(spr, true);
                spr.destroy();
            });

            boxGroup.clear();
        }

        var boxData = skinData.box;

        if (Paths.exists("images/" + boxData.path + ".png"))
        {
            box = new FlxSprite();

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
    }

    function refreshPortraits()
    {
        if (portraitGroup != null)
        {
            portraitGroup.forEachAlive(function(spr:FlxSprite)
            {
                remove(spr, true);
                spr.destroy();
            });

            portraitGroup.clear();
        }

        var characterList:Array<String> = [];
        var preloadList:Array<String> = [];

        var dialogueData = songData.dialogue;

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

        for (i in 0...songData.dialogue.length)
        {
            var dialogue = songData.dialogue[i];

            if (dialogue.audio.path != "" && Paths.exists('audio/' + dialogue.audio.path + '.ogg'))
            {
                var snd:FlxSound = new FlxSound().loadEmbedded(Paths.audio(dialogue.audio.path));
                snd.volume = dialogue.audio.volume;
                FlxG.sound.list.add(snd);

                lineAudioList[i] = snd;
            }

            if (dialogue.field.audio.path != "" && Paths.exists('audio/' + dialogue.field.audio.path + '.ogg'))
            {
                var snd:FlxSound = new FlxSound().loadEmbedded(Paths.audio(dialogue.field.audio.path));
                snd.volume = dialogue.field.audio.volume;
                FlxG.sound.list.add(snd);

                lineVoicesList[i] = snd;
            }
        }

        for (entry in preloadList)
        {
            var split:Array<String> = entry.split(":");

            var char:String = split[0];
            var expression:String = split[1];

            var data = dataList[char];
            var expressionData = null;

            for (e in data.expressions)
            {
                if (e.name == expression)
                {
                    expressionData = e;
                    break;
                }
            }

            if (expressionData == null) continue;

            var spr = new FlxSprite();

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

            if (characters[char] == null)
                characters[char] = {};
            
            var charData = Reflect.field(characters, char);
            if (charData == null)
            {
                charData = {};
                Reflect.setField(characters, char, charData);
            }
            
            Reflect.setField(charData, expression, spr);

            var audioPath:String = "";
            var soundList:Array<FlxSound> = [];

            if (Paths.isDirectory("audio/sounds/gameplay/dialogue/characters/" + char + "/" + expression))
                audioPath = expression;
            else if (Paths.isDirectory("audio/sounds/gameplay/dialogue/characters/" + char + "/default"))
                audioPath = "default";

            for (file in Paths.readDirectory("audio/sounds/gameplay/dialogue/characters/" + char + "/" + audioPath))
            {
                var snd:FlxSound = new FlxSound().loadEmbedded(Paths.sound('gameplay/dialogue/characters/' + char + '/' + audioPath + '/' + Path.withoutExtension(file)));
                snd.volume = 0;
                snd.play();
                snd.stop();
                FlxG.sound.list.add(snd);
                soundList.push(snd);
            }

            if (vocals[char] == null)
                vocals[char] = {};
            
            var vocalsData = Reflect.field(vocals, char);

            if (vocalsData == null)
            {
                vocalsData = {};
                Reflect.setField(vocals, char, soundList);
            }
        }
    }

    function start()
    {
        increment();
    }

    function increment()
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

    function playBoxAnim(animName:String)
    {
        if (box == null || box.animation == null) return;

        if (box.animation.exists(animName))
            box.animation.play(animName, true);

        box.updateHitbox();

        if (skinData != null && skinData.box != null && skinData.box.animations != null)
        {
            var anims:Array<Dynamic> = skinData.box.animations;
            for (i in 0...anims.length)
            {
                var entry = anims[i];
                if (entry.name == animName && entry.offsets != null && entry.offsets.length >= 2)
                {
                    box.offset.x += entry.offsets[0];
                    box.offset.y += entry.offsets[1];
                    break;
                }
            }
        }
    }

    function generatePortrait(index:Int):Void 
    {
        var indexData = songData.dialogue[index];

        if (indexData.audio.path != "")
        {
            for (snd in lineAudioList)
            {
                if (snd != null)
                    snd.stop();
            }

            if (lineAudioList[index] != null)
                lineAudioList[index].play();
        }

        if (indexData.field.audio.path != "")
        {
            for (snd in lineVoicesList)
            {
                if (snd != null)
                    snd.stop();
            }

            if (lineVoicesList[index] != null)
                lineVoicesList[index].play();
        }

        var charData = Reflect.field(characters, indexData.character);
        var expressionData:Dynamic = null;

        var expressionsArray = Reflect.field(dataList[indexData.character], "expressions");

        if (expressionsArray != null)
        {
            for (i in 0...expressionsArray.length)
            {
                var entry = expressionsArray[i];
                if (Reflect.field(entry, "name") == indexData.expression)
                {
                    expressionData = entry;
                    break;
                }
            }
        }

        currentCharacter = indexData.character;
        currentExpression = indexData.expression;
        currentColor = dataList[currentCharacter].color;

        if (charData != null)
        {
            var charSprite = Reflect.field(charData, indexData.expression);
            
            if (charSprite != null)
            {
                for (i in 0...portraitGroup.members.length)
                {
                    var spr = portraitGroup.members[i];
                    
                    if (spr != null && spr != charSprite)
                    {
                        FlxTween.cancelTweensOf(spr);
                        spr.alpha = 0;
                    }
                }

                FlxTween.cancelTweensOf(charSprite);

                var boxSuffix = (indexData.boxSuffix != null && indexData.boxSuffix != "") ? "-" + indexData.boxSuffix : "";
                playBoxAnim(indexData.direction + boxSuffix);

                var charX = switch(indexData.direction)
                {
                    case "left": -charSprite.width;
                    case "right": charSprite.width;
                    case "center": 0;
                    default: 0;
                }
                var charY = charSprite.y;
                var charScale = charSprite.scale;
                var charAngle = charSprite.angle;

                var portraitData = Reflect.field(skinData.portraits, indexData.direction);
                
                if (portraitData.alphaTween.enabled)
                {
                    charSprite.alpha = portraitData.alphaTween.values.from;
                    FlxTween.tween(charSprite, {alpha: expressionData.alpha}, portraitData.alphaTween.duration, {ease: Reflect.field(FlxEase, portraitData.alphaTween.ease)});
                }
                else
                    charSprite.alpha = expressionData.alpha;

                if (portraitData.xTween.enabled)
                {
                    charSprite.screenCenter(0x01);
                    charSprite.x += expressionData.position[0];
                    var curX = charSprite.x + charX;

                    charSprite.x = curX + portraitData.xTween.values.from;
                    FlxTween.tween(charSprite, {x: curX}, portraitData.xTween.duration, {ease: Reflect.field(FlxEase, portraitData.xTween.ease)});
                }
                else
                {
                    charSprite.screenCenter(0x01);
                    charSprite.x += charX;
                }

                if (portraitData.yTween.enabled)
                {
                    charSprite.screenCenter(0x10);
                    charSprite.y += expressionData.position[1];
                    FlxTween.tween(charSprite, {y: charY}, portraitData.yTween.duration, {ease: Reflect.field(FlxEase, portraitData.yTween.ease)});
                }
                else
                {
                    charSprite.screenCenter(0x10);
                    charSprite.y += expressionData.position[1];
                }

                if (portraitData.scaleTween.enabled)
                {
                    charSprite.scale.set(portraitData.scaleTween.values.from, portraitData.scaleTween.values.from);
                    FlxTween.tween(charSprite, {"scale.x": expressionData.scale[0], "scale.y": expressionData.scale[1]}, portraitData.scaleTween.duration, {ease: Reflect.field(FlxEase, portraitData.scaleTween.ease)});
                }
                else
                    charSprite.scale.set(expressionData.scale[0], expressionData.scale[1]);

                if (portraitData.angleTween.enabled)
                {
                    charSprite.angle = portraitData.angleTween.values.from;
                    FlxTween.tween(charSprite, {angle: expressionData.angle}, portraitData.angleTween.duration, {ease: Reflect.field(FlxEase, portraitData.angleTween.ease)});
                }
                else
                    charSprite.angle = expressionData.angle;
            }
        }
    }

    function parseRichText(rawText:String, defaultSize:Int, defaultColor:Int, defaultSpeed:Float):Array<Dynamic>
    {
        var chunks:Array<Dynamic> = [];
        var regex = new EReg("<([^>]+)>", "g"); 
        
        var lastPos:Int = 0;
        
        var currentEffects:Dynamic =
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
                chunks.push({text: textBefore, effects: {size: currentEffects.size, color: currentEffects.color, wave: currentEffects.wave, shake: currentEffects.shake, speed: currentEffects.speed}});
            
            if (StringTools.startsWith(tag, "/")) 
            {
                var tagName = tag.substring(1);
                if (tagName == "size") currentEffects.size = defaultSize;
                if (tagName == "color") currentEffects.color = defaultColor;
                if (tagName == "wave") currentEffects.wave = false;
                if (tagName == "shake") currentEffects.shake = 0.0;
                if (tagName == "speed") currentEffects.speed = defaultSpeed;
            } 
            else 
            {
                var splitTag = tag.split("=");

                if (splitTag.length == 2) 
                {
                    var tagName = splitTag[0];
                    var tagValue = splitTag[1];
                    
                    if (tagName == "size") currentEffects.size = Std.parseInt(tagValue);
                    if (tagName == "wave") currentEffects.wave = (tagValue == "true");
                    if (tagName == "shake") currentEffects.shake = Std.parseFloat(tagValue);
                    if (tagName == "speed") currentEffects.speed = Std.parseFloat(tagValue);
                    
                    if (tagName == "color") 
                    {
                        if (StringTools.startsWith(tagValue, "#")) 
                            currentEffects.color = Std.parseInt("0xFF" + tagValue.substring(1));
                    }
                    
                    if (tagName == "image")
                    {
                        var imgArgs = tagValue.split(":");
                        var imgPath = imgArgs[0];
                        var imgW = imgArgs.length > 1 ? Std.parseInt(imgArgs[1]) : 0;
                        var imgH = imgArgs.length > 2 ? Std.parseInt(imgArgs[2]) : 0;
                        
                        chunks.push(
                        {
                            isImage: true,
                            path: imgPath,
                            width: imgW,
                            height: imgH,
                            effects: {size: currentEffects.size, color: currentEffects.color, wave: currentEffects.wave, shake: currentEffects.shake, speed: currentEffects.speed}
                        });
                    }

                    if (tagName == "audio")
                    {
                        var audioArgs = tagValue.split(":");
                        var audioPath = audioArgs[0];
                        var audioVol = audioArgs.length > 1 ? Std.parseFloat(audioArgs[1]) : 1.0;

                        chunks.push(
                        {
                            isAudio: true,
                            path: audioPath,
                            volume: audioVol,
                            effects: {size: currentEffects.size, color: currentEffects.color, wave: currentEffects.wave, shake: currentEffects.shake, speed: currentEffects.speed}
                        });
                    }
                }
            }
            
            lastPos = matchedPos.pos + matchedPos.len;
        }
        
        var remainder = rawText.substring(lastPos);
        if (remainder.length > 0)
        {
            chunks.push({
                text: remainder,
                effects: { size: currentEffects.size, color: currentEffects.color, wave: currentEffects.wave, shake: currentEffects.shake, speed: currentEffects.speed }
            });
        }
        
        return chunks;
    }

    function generateText(index:Int)
    {
        if (textGroup != null)
        {
            textGroup.forEachAlive(function(spr:FlxSprite)
            {
                remove(spr, true);
                spr.destroy();
            });

            textGroup.clear();
        }

        var indexData = songData.dialogue[index];
        var fontData:Dynamic = null;

        for (entry in skinData.text.fonts)
        {
            if (entry.name == indexData.font)
            {
                fontData = entry;
                break;
            }
        }

        if (fontData == null) return;

        var fieldData = indexData.field;
        
        printSpeed = fieldData.speed;
        currentPrintTime = 0;

        wordQueue = [];
        currentWordIndex = 0;
        currentCharIndex = 0;

        var defColor:Int = 0xFFFFFFFF;
        if (fontData.color != null && StringTools.startsWith(fontData.color, "#"))
            defColor = Std.parseInt("0xFF" + fontData.color.substring(1));

        var chunks = parseRichText(fieldData.text, fontData.size, defColor, printSpeed);

        var startX:Float = box.x + 50;
        var cursorX:Float = startX;
        var cursorY:Float = box.y + (box.height / 4) + 40;
        var maxWidth:Float = fontData.fieldWidth;
        var currentLineHeight:Float = 0;

        for (chunk in chunks)
        {
            if (chunk.isAudio)
            {
                wordQueue.push(
                {
                    isAudio: true,
                    path: chunk.path,
                    volume: chunk.volume,
                    effects: chunk.effects
                });
                continue;
            }

            if (chunk.isImage)
            {
                var imgSprite = new FlxSprite(cursorX, cursorY);
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

                wordQueue.push(
                {
                    isImage: true,
                    sprite: imgSprite,
                    effects: chunk.effects,
                    baseX: imgSprite.x,
                    baseY: imgSprite.y 
                });
                
                continue;
            }

            var words = chunk.text.split(" ");
            
            for (i in 0...words.length)
            {
                var wordText = words[i];
                if (i < words.length - 1) wordText += " "; 
                
                if (wordText == "") continue;

                var textSprite:FlxText = new FlxText(cursorX, cursorY, 0, wordText, chunk.effects.size);
                
                if (Paths.exists('fonts/' + fontData.file))
                    textSprite.font = Paths.font(fontData.file);
                
                textSprite.color = chunk.effects.color;
                textSprite.antialiasing = fontData.antialiasing;

                var parsedBorderColor:Int = 0xFF000000;

                if (fontData.borderColor != null)
                {
                    if (StringTools.startsWith(fontData.borderColor, "#")) 
                        parsedBorderColor = Std.parseInt("0xFF" + fontData.borderColor.substring(1));
                }
                else if (currentColor != null)
                {
                    if (StringTools.startsWith(currentColor, "#")) 
                        parsedBorderColor = Std.parseInt("0xFF" + currentColor.substring(1));
                }

                if (fontData.shadow != null && (fontData.shadow.x != 0 || fontData.shadow.y != 0))
                {
                    textSprite.setBorderStyle(FlxTextBorderStyle.SHADOW, parsedBorderColor, fontData.borderSize);
                    textSprite.shadowOffset.set(fontData.shadow.x, fontData.shadow.y);
                }
                else
                {
                    textSprite.setBorderStyle(FlxTextBorderStyle.OUTLINE, parsedBorderColor, fontData.borderSize);
                }
                
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

                wordQueue.push(
                {
                    isImage: false,
                    isAudio: false,
                    fullText: wordText,
                    sprite: textSprite,
                    effects: chunk.effects,
                    baseX: textSprite.x,
                    baseY: textSprite.y
                });
            }
        }
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        handleInputs();
        handleTextRendering(elapsed);

        globalTextTimer += elapsed;

        for (i in 0...wordQueue.length)
        {
            var word:Dynamic = wordQueue[i];

            if (word.isAudio) continue;

            var isActive = word.isImage ? word.sprite.visible : (word.sprite.text != "");

            if (i <= currentWordIndex && isActive)
            {
                var targetX:Float = word.baseX;
                var targetY:Float = word.baseY;

                if (word.effects.wave)
                    targetY += (Math.sin((globalTextTimer * 8) + i) * 6);

                if (word.effects.shake > 0)
                {
                    targetX += FlxG.random.float(-word.effects.shake, word.effects.shake);
                    targetY += FlxG.random.float(-word.effects.shake, word.effects.shake);
                }

                word.sprite.x = targetX;
                word.sprite.y = targetY;
            }
        }
    }

    function handleInputs()
    {
        if (FlxG.keys.justPressed.ENTER)
        {
            if (wordQueue.length == 0 || currentWordIndex >= wordQueue.length)
            {
                increment();
            }
            else
            {
                while (currentWordIndex < wordQueue.length)
                {
                    var currentWord:Dynamic = wordQueue[currentWordIndex];

                    if (currentWord.isImage)
                    {
                        currentWord.sprite.visible = true;
                        FlxTween.cancelTweensOf(currentWord.sprite); 
                        currentWord.sprite.alpha = 1;                
                    }
                    else if (currentWord.isAudio)
                    {
                        FlxG.sound.play(Paths.audio(currentWord.path), currentWord.volume);
                    }
                    else
                    {
                        currentWord.sprite.text = currentWord.fullText;
                    }
                    
                    currentWordIndex++;
                }
                
                currentCharIndex = 0; 
            }
        }
    }

    function handleTextRendering(elapsed:Float)
    {
        if (wordQueue.length == 0 || currentWordIndex >= wordQueue.length)
            return;

        if (printSpeed <= 0)
        {
            while (currentWordIndex < wordQueue.length)
            {
                var currentWord:Dynamic = wordQueue[currentWordIndex];

                if (currentWord.isImage)
                {
                    currentWord.sprite.visible = true;
                    currentWord.sprite.alpha = 1;
                }
                else if (currentWord.isAudio)
                {
                    FlxG.sound.play(Paths.audio(currentWord.path), currentWord.volume);
                }
                else
                    currentWord.sprite.text = currentWord.fullText;
                
                currentWordIndex++;
            }
            return;
        }

        currentPrintTime += elapsed;

        while (currentWordIndex < wordQueue.length)
        {
            var currentWord:Dynamic = wordQueue[currentWordIndex];
            var currentWordSpeed:Float = (currentWord.effects != null && currentWord.effects.speed != null) ? currentWord.effects.speed : printSpeed;

            if (currentWordSpeed > 0 && currentPrintTime < currentWordSpeed)
                break;

            playSound();
            
            if (currentWordSpeed > 0)
                currentPrintTime -= currentWordSpeed;

            if (currentWord.isAudio)
            {
                FlxG.sound.play(Paths.audio(currentWord.path), currentWord.volume);
                currentWordIndex++;
                continue; 
            }
            
            if (currentWord.isImage)
            {
                currentWord.sprite.visible = true;
                var fadeSpeed = currentWordSpeed > 0 ? currentWordSpeed * 3 : 0.15;
                FlxTween.tween(currentWord.sprite, {alpha: 1}, fadeSpeed, {ease: FlxEase.linear});
                
                currentWordIndex++;
                continue;
            }
            
            currentWord.sprite.text += currentWord.fullText.charAt(currentCharIndex);
            currentCharIndex++;

            if (currentCharIndex >= currentWord.fullText.length)
            {
                currentCharIndex = 0;
                currentWordIndex++;
            }
        }
    }

    function playSound()
    {
        var vocalList = Reflect.field(vocals, currentCharacter);

        for (vocal in vocalList)
            vocal.stop();

        var index = FlxG.random.int(0, vocalList.length - 1);

        if (vocalList[index] == null)
            return;

        if (vocalList[index].volume != 1)
            vocalList[index].volume = 1;

        vocalList[index].play();
    }

    function finish()
    {
        if (transitioning)
            return;

        if (dialogueSong != null)
        {
            if (songData.song.fadeOut)
                dialogueSong.fadeOut(songData.song.fadeOutTime, 0);
            else
                dialogueSong.volume = songData.song.volume;
        }

        transitioning = true;

        FlxTween.tween(solid, {alpha: 0}, 0.15);

        for (group in [boxGroup, portraitGroup, textGroup])
        {
            if (group != null)
            {
                for (item in group.members)
                {
                    if (item != null)
                        FlxTween.tween(item, {alpha: 0}, 0.15);
                }
            }
        }

        if (vocals != null)
        {
            for (charKey in Reflect.fields(vocals))
            {
                var soundList:Array<Dynamic> = Reflect.field(vocals, charKey);
                for (snd in soundList)
                {
                    if (snd != null)
                        FlxTween.tween(snd, {volume: 0}, 0.15);
                }
            }
        }

        var game = PlayState.instance;

        if (game == null)
        {
            close();
            return;
        }

        FlxTween.tween(game.camHUD, {alpha: 1}, 0.2);
        FlxTween.tween(game.camStrums, {alpha: 1}, 0.2, {onComplete: (_) -> {
            game.initCountdown();
            close();
            game = null;
        }});
    }

    override function destroy()
    {
        portraitGroup = FlxDestroyUtil.destroy(portraitGroup);
        boxGroup = FlxDestroyUtil.destroy(boxGroup);
        textGroup = FlxDestroyUtil.destroy(textGroup);

        box = FlxDestroyUtil.destroy(box);
        solid = FlxDestroyUtil.destroy(solid);

        if (camDialogue != null)
        {
            if (FlxG.cameras.list.contains(camDialogue))
                FlxG.cameras.remove(camDialogue, true);
            camDialogue = null;
        }

        if (vocals != null)
        {
            for (charKey in Reflect.fields(vocals))
            {
                var soundList:Array<Dynamic> = Reflect.field(vocals, charKey);
                if (soundList != null)
                {
                    for (snd in soundList)
                    {
                        if (snd != null)
                        {
                            FlxG.sound.list.remove(snd, true);
                            snd.destroy();
                        }
                    }
                }
            }
        }

        wordQueue = null;
        characters = null;
        vocals = null;
        dataList = null;
        skinData = null;
        songData = null;

        super.destroy();
    }
}