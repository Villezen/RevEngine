package menus;

import backend.MusicBeatState;
import backend.modding.PolymodManager;
import backend.utils.MathUtil;

import flixel.FlxCamera;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxBitmapText;

import polymod.Polymod.ModMetadata;

class ModLoaderState extends MusicBeatState
{
    var mods:Array<ModMetadata> = [];
    var titleScales:Array<Float> = [];
    var inInfoMenu:Bool = false;

    var curSelected:Int = 0;

    var camModList:FlxCamera;
    var camContributorList:FlxCamera;
    var camUI:FlxCamera;

    var camTargetY:Float = 0;

    var menuSong:FunkinSound;
    var scrollSound:FunkinSound;

    var modListBox:FunkinSprite;
    var selectBox:FunkinSprite;
    var selectSolid:FunkinSprite;

    var infoGroup:FlxSpriteGroup;
    var leftInfoSolid:FunkinSprite;
    var rightInfoSolid:FunkinSprite;

    var modGroup:FlxSpriteGroup;
    var contributorGroup:FlxSpriteGroup;
    var uiTextGroup:FlxSpriteGroup;

    var modDesc:FlxBitmapText;
    var modStatus:FlxBitmapText;
    var apiText:FlxBitmapText;
    var verText:FlxBitmapText;
    var licenseText:FlxBitmapText;

    var contributorScrollY:Float = 0;
    var maxContributorScroll:Float = 0;

    var scrollBarBg:FunkinSprite;
    var scrollBarHandle:FunkinSprite;
    var isDraggingScrollbar:Bool = false;
    var scrollDragOffset:Float = 0;

    var modScrollBarBg:FunkinSprite;
    var modScrollBarHandle:FunkinSprite;
    var isDraggingModScrollbar:Bool = false;
    var modScrollDragOffset:Float = 0;
    var maxModScroll:Float = 0;

    var mouseMode:Bool = false;
    var keyboardMode:Bool = true;

    var toggleBack:Bool = false;

    override public function create():Void
    {
        FlxG.mouse.visible = false;

        scrollSound = FunkinSound.load(Paths.sound('menus/modLoader/scroll'), 0.2);

        if (FlxG.sound.music.playing)
            FlxG.sound.music.fadeOut(0.3, 0);

        menuSong = FunkinSound.load(Paths.music('menus/modLoader'), 0.0, true);
        menuSong.play();
        menuSong.fadeIn(2, 0, 0.5);

        var bg:FunkinSprite = new FunkinSprite().loadGraphic(Paths.image('menus/backgrounds/menuDesat'));
        bg.setGraphicSize(FlxG.width, FlxG.height);
        bg.updateHitbox();
        bg.color = 0xFF4C4C4C;
        add(bg);

        modListBox = new FunkinSprite().makeGraphic(1, 1, 0xFF000000);
        modListBox.scale.set(450, 600);
        modListBox.updateHitbox();
        modListBox.screenCenter();
        modListBox.alpha = 0.4;
        add(modListBox);

        modScrollBarBg = new FunkinSprite().makeGraphic(5, 1, 0xFF000000);
        modScrollBarBg.alpha = 0;
        add(modScrollBarBg);

        modScrollBarHandle = new FunkinSprite().makeGraphic(5, 50, 0xFFFFFFFF);
        modScrollBarHandle.alpha = 0;
        add(modScrollBarHandle);

        infoGroup = new FlxSpriteGroup();
        infoGroup.alpha = 0;
        add(infoGroup);

        leftInfoSolid = new FunkinSprite().makeGraphic(250, 160, 0xFF000000);
        leftInfoSolid.ID = 1;
        leftInfoSolid.alpha = 0.4;
        leftInfoSolid.x = 120;
        leftInfoSolid.y = FlxG.height - leftInfoSolid.height - 50;
        infoGroup.add(leftInfoSolid);

        rightInfoSolid = new FunkinSprite().makeGraphic(500, 250, 0xFF000000);
        rightInfoSolid.ID = 1;
        rightInfoSolid.alpha = 0.4;
        rightInfoSolid.x = FlxG.width - rightInfoSolid.width - 120;
        rightInfoSolid.y = FlxG.height - rightInfoSolid.height - 200;
        infoGroup.add(rightInfoSolid);

        scrollBarBg = new FunkinSprite().makeGraphic(5, Std.int(rightInfoSolid.height), 0xFF000000);
        scrollBarBg.x = rightInfoSolid.x + rightInfoSolid.width;
        scrollBarBg.y = rightInfoSolid.y;
        infoGroup.add(scrollBarBg);

        scrollBarHandle = new FunkinSprite().makeGraphic(5, 50, 0xFFFFFFFF);
        scrollBarHandle.x = scrollBarBg.x;
        scrollBarHandle.y = scrollBarBg.y;
        infoGroup.add(scrollBarHandle);

        camModList = new FlxCamera(Std.int(modListBox.x), Std.int(modListBox.y), Std.int(modListBox.width), Std.int(modListBox.height));
        camModList.bgColor = 0x00000000;
        camModList.scroll.set(modListBox.x, modListBox.y);
        FlxG.cameras.add(camModList, false);

        camContributorList = new FlxCamera(Std.int(rightInfoSolid.x), Std.int(rightInfoSolid.y), Std.int(rightInfoSolid.width), Std.int(rightInfoSolid.height));
        camContributorList.bgColor = 0x00000000;
        camContributorList.scroll.set(rightInfoSolid.x, rightInfoSolid.y);
        FlxG.cameras.add(camContributorList, false);

        camUI = new FlxCamera();
        camUI.bgColor = 0x00000000;
        FlxG.cameras.add(camUI, false);

        uiTextGroup = new FlxSpriteGroup();
        uiTextGroup.camera = camUI;
        uiTextGroup.alpha = 0;
        add(uiTextGroup);

        selectBox = new FunkinSprite(modListBox.x, modListBox.y).loadGraphic(Paths.image('menus/modLoader/selectBox'));
        selectBox.alpha = 0.8;
        selectBox.camera = camModList;

        selectSolid = new FunkinSprite(modListBox.x, modListBox.y).makeGraphic(Std.int(modListBox.width), Std.int(selectBox.height), 0xFF000000);
        selectSolid.alpha = 0.4;
        selectSolid.camera = camModList;
        add(selectSolid);

        modGroup = new FlxSpriteGroup();
        modGroup.camera = camModList;
        add(modGroup);

        add(selectBox);

        contributorGroup = new FlxSpriteGroup();
        contributorGroup.camera = camContributorList;
        contributorGroup.alpha = 0;
        add(contributorGroup);

        if (PolymodManager.availableMods != null && PolymodManager.availableMods.length > 0)
        {
            reloadMods();
            reloadContributors(curSelected);
        }
        else
        {
            var infoIcon:FunkinSprite = new FunkinSprite().loadGraphic(Paths.image('menus/modLoader/info'));
            infoIcon.alpha = 0.4;
            infoIcon.scale.set(0.2, 0.2);
            infoIcon.updateHitbox();
            infoIcon.screenCenter();
            infoIcon.antialiasing = true;
            infoIcon.y -= 10;
            add(infoIcon);

            var infoTxt:FlxBitmapText = new FlxBitmapText(0, 0, "No Mods Found.", Paths.getAngelFont('jetbrains'));
            infoTxt.scale.set(0.7, 0.7);
            infoTxt.updateHitbox();
            infoTxt.screenCenter();
            infoTxt.alpha = 0.2;
            infoTxt.y -= 15;
            add(infoTxt);

            var infoDesc:FlxBitmapText = new FlxBitmapText(0, 0, "Press F5 to refresh this menu and check for any newly added mods.", Paths.getAngelFont('jetbrains'));
            infoDesc.scale.set(0.24, 0.24);
            infoDesc.updateHitbox();
            infoDesc.screenCenter();
            infoDesc.alpha = 0.1;
            infoDesc.y += 15;
            add(infoDesc);
        }

        modDesc = new FlxBitmapText(0, 0, mods.length > 0 ? mods[curSelected].description : "No Mods Found", Paths.getAngelFont('tardling'));
        modDesc.scale.set(0.2, 0.2);
        modDesc.updateHitbox();
        modDesc.alpha = 0;
        uiTextGroup.add(modDesc);

        var contributorsTitle:FlxBitmapText = new FlxBitmapText(0, 0, "CONTRIBUTORS:", Paths.getAngelFont('pah'));
        contributorsTitle.scale.set(0.2, 0.2);
        contributorsTitle.updateHitbox();
        contributorsTitle.setPosition(rightInfoSolid.x + (rightInfoSolid.width - contributorsTitle.width) - 5, rightInfoSolid.y - (contributorsTitle.height / 2));
        uiTextGroup.add(contributorsTitle);

        modStatus = new FlxBitmapText(0, 0, "ENABLED", Paths.getAngelFont('pah'));
        modStatus.scale.set(0.25, 0.25);
        modStatus.updateHitbox();
        modStatus.setPosition(220, 115);
        uiTextGroup.add(modStatus);

        var apiTitle:FlxBitmapText = new FlxBitmapText(0, 0, "API VERSION:", Paths.getAngelFont('pah'));
        apiTitle.scale.set(0.25, 0.25);
        apiTitle.updateHitbox();
        apiTitle.setPosition(leftInfoSolid.x + 10, leftInfoSolid.y + 10);
        uiTextGroup.add(apiTitle);

        apiText = new FlxBitmapText(0, 0, '0.0.0', Paths.getAngelFont('pah'));
        apiText.scale.set(0.2, 0.2);
        apiText.updateHitbox();
        apiText.setPosition(leftInfoSolid.x + 10, leftInfoSolid.y + 30);
        uiTextGroup.add(apiText);

        var verTitle:FlxBitmapText = new FlxBitmapText(0, 0, "MOD VERSION:", Paths.getAngelFont('pah'));
        verTitle.scale.set(0.25, 0.25);
        verTitle.updateHitbox();
        verTitle.setPosition(leftInfoSolid.x + 10, leftInfoSolid.y + 60);
        uiTextGroup.add(verTitle);

        verText = new FlxBitmapText(0, 0, '0.0.0', Paths.getAngelFont('pah'));
        verText.scale.set(0.2, 0.2);
        verText.updateHitbox();
        verText.setPosition(leftInfoSolid.x + 10, leftInfoSolid.y + 80);
        uiTextGroup.add(verText);

        var licenseTitle:FlxBitmapText = new FlxBitmapText(0, 0, "LICENSE:", Paths.getAngelFont('pah'));
        licenseTitle.scale.set(0.25, 0.25);
        licenseTitle.updateHitbox();
        licenseTitle.setPosition(leftInfoSolid.x + 10, leftInfoSolid.y + 110);
        uiTextGroup.add(licenseTitle);

        licenseText = new FlxBitmapText(0, 0, 'banana', Paths.getAngelFont('pah'));
        licenseText.scale.set(0.2, 0.2);
        licenseText.updateHitbox();
        licenseText.setPosition(leftInfoSolid.x + 10, leftInfoSolid.y + 130);
        uiTextGroup.add(licenseText);

        var infoText:FlxBitmapText = new FlxBitmapText(0, 0, '[ PRESS CONFIRM TO SWITCH ]', Paths.getAngelFont('pah'));
        infoText.ID = 1;
        infoText.scale.set(0.2, 0.2);
        infoText.updateHitbox();
        infoText.alpha = 0.2;
        infoText.x = FlxG.width - infoText.width - 130;
        infoText.y = FlxG.height - infoText.height - 50;
        uiTextGroup.add(infoText);

        camTargetY = modListBox.y;

        selectBox.color = (mods.length > 0 && PolymodManager.activeMod == mods[curSelected].id) ? 0xFF7FFF7F : 0xFFFF7F7F;

        if (mods.length == 0)
        {
            selectBox.visible = false;
            selectSolid.visible = false;
            infoText.visible = false;
        }

        super.create();
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (PolymodManager.availableMods == null || PolymodManager.availableMods.length == 0)
        {
            if (controls.BACK.justPressed && !toggleBack)
                exit();
            
            return;
        }

        if (!keyboardMode && (controls.UI_DOWN.justPressed || controls.UI_UP.justPressed || controls.ACCEPT.justPressed))
        {
            keyboardMode = true;
            mouseMode = false;
            FlxG.mouse.visible = false;
        }
        else if (!mouseMode && (FlxG.mouse.justMoved || FlxG.mouse.wheel != 0))
        {
            mouseMode = true;
            keyboardMode = false;
            FlxG.mouse.visible = true;
        }

        if (!inInfoMenu)
        {
            modListBox.scale.x = MathUtil.smoothLerpPrecision(modListBox.scale.x, 450, elapsed, 0.2);
            modListBox.scale.y = MathUtil.smoothLerpPrecision(modListBox.scale.y, 600, elapsed, 0.2);

            camModList.width = Std.int(modListBox.scale.x);
            camModList.height = Std.int(modListBox.scale.y);

            camModList.x = MathUtil.smoothLerpPrecision(camModList.x, modListBox.x, elapsed, 0.2);
            camModList.y = MathUtil.smoothLerpPrecision(camModList.y, modListBox.y, elapsed, 0.2);

            maxModScroll = Math.max(0, (mods.length * 100) - modListBox.height);

            if (maxModScroll > 0 && FlxG.mouse.wheel != 0)
                camTargetY -= FlxG.mouse.wheel * 50;

            if (mouseMode && maxModScroll > 0)
            {
                if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(modScrollBarHandle))
                {
                    isDraggingModScrollbar = true;
                    modScrollDragOffset = FlxG.mouse.y - modScrollBarHandle.y;
                }
                else if (FlxG.mouse.justReleased)
                    isDraggingModScrollbar = false;
            }

            if (isDraggingModScrollbar)
            {
                var newHandleY:Float = FlxG.mouse.y - modScrollDragOffset;
                var minHandleY:Float = modScrollBarBg.y;
                var maxHandleY:Float = modScrollBarBg.y + modScrollBarBg.height - modScrollBarHandle.height;

                if (newHandleY < minHandleY) newHandleY = minHandleY;
                if (newHandleY > maxHandleY) newHandleY = maxHandleY;

                var scrollFraction:Float = (newHandleY - minHandleY) / (maxHandleY - minHandleY);
                camTargetY = modListBox.y + (scrollFraction * maxModScroll);
            }

            if (keyboardMode)
            {
                var itemTop:Float = modListBox.y + (100 * curSelected);
                var itemBottom:Float = itemTop + 100;
                if (itemTop < camTargetY)
                    camTargetY = itemTop;
                else if (itemBottom > camTargetY + modListBox.height)
                    camTargetY = itemBottom - modListBox.height;
            }

            if (camTargetY < modListBox.y)
                camTargetY = modListBox.y;
            if (camTargetY > modListBox.y + maxModScroll)
                camTargetY = modListBox.y + maxModScroll;

            camModList.scroll.y = MathUtil.smoothLerpPrecision(camModList.scroll.y, camTargetY, elapsed, 0.2);

            modScrollBarBg.x = modListBox.x + modListBox.width;
            modScrollBarBg.y = modListBox.y;
            modScrollBarBg.scale.y = modListBox.height;
            modScrollBarBg.updateHitbox();

            if (maxModScroll > 0)
            {
                modScrollBarBg.alpha = MathUtil.smoothLerpPrecision(modScrollBarBg.alpha, 0.7, elapsed, 0.1);
                modScrollBarHandle.alpha = MathUtil.smoothLerpPrecision(modScrollBarHandle.alpha, 1, elapsed, 0.1);

                modScrollBarHandle.x = modScrollBarBg.x;
                var scrollFraction:Float = (camTargetY - modListBox.y) / maxModScroll;
                modScrollBarHandle.y = modScrollBarBg.y + scrollFraction * (modScrollBarBg.height - modScrollBarHandle.height);
            }
            else
            {
                modScrollBarBg.alpha = MathUtil.smoothLerpPrecision(modScrollBarBg.alpha, 0, elapsed, 0.1);
                modScrollBarHandle.alpha = MathUtil.smoothLerpPrecision(modScrollBarHandle.alpha, 0, elapsed, 0.1);
            }

            selectBox.y = MathUtil.smoothLerpPrecision(selectBox.y, modListBox.y + (100 * curSelected), elapsed, 0.2);
            selectSolid.y = MathUtil.smoothLerpPrecision(selectSolid.y, modListBox.y + (100 * curSelected), elapsed, 0.2);

            selectBox.alpha = MathUtil.smoothLerpPrecision(selectBox.alpha, 0.8, elapsed, 0.2);
            selectSolid.alpha = MathUtil.smoothLerpPrecision(selectSolid.alpha, 0.4, elapsed, 0.2);

            for (spr in infoGroup.members)
                spr.alpha = MathUtil.smoothLerpPrecision(spr.alpha, 0, elapsed, 0.1);

            for (spr in contributorGroup.members)
                spr.alpha = MathUtil.smoothLerpPrecision(spr.alpha, 0, elapsed, 0.1);

            for (spr in uiTextGroup.members)
                spr.alpha = MathUtil.smoothLerpPrecision(spr.alpha, 0, elapsed, 0.1);

            for (spr in modGroup.members)
            {
                var tag = spr.getTag();

                if (tag == "hitbox")
                    spr.alpha = MathUtil.smoothLerpPrecision(spr.alpha, 0.2, elapsed, 0.2);
                else if (tag == "active")
                    spr.alpha = MathUtil.smoothLerpPrecision(spr.alpha, 0.3, elapsed, 0.2);
                else
                    spr.alpha = MathUtil.smoothLerpPrecision(spr.alpha, spr.ID == curSelected ? 1 : 0.5, elapsed, 0.2);

                if (tag == "border")
                {
                    spr.x = MathUtil.smoothLerpPrecision(spr.x, modListBox.x + 20, elapsed, 0.2);
                    spr.y = MathUtil.smoothLerpPrecision(spr.y, modListBox.y + ((selectSolid.height - 70) / 2) + (selectSolid.height * spr.ID), elapsed, 0.2);
                }
                else if (tag == "icon")
                {
                    spr.x = MathUtil.smoothLerpPrecision(spr.x, modListBox.x + 23, elapsed, 0.2);
                    spr.y = MathUtil.smoothLerpPrecision(spr.y, modListBox.y + 3 + ((selectSolid.height - 70) / 2) + (selectSolid.height * spr.ID), elapsed, 0.2);
                }
                else if (tag == "title")
                {
                    spr.scale.x = MathUtil.smoothLerpPrecision(spr.scale.x, titleScales[spr.ID], elapsed, 0.2);
                    spr.scale.y = spr.scale.x;
                    spr.updateHitbox();

                    spr.x = MathUtil.smoothLerpPrecision(spr.x, modListBox.x + 105, elapsed, 0.2);
                    spr.y = MathUtil.smoothLerpPrecision(spr.y, (modListBox.y + ((selectSolid.height - 70) / 2) + (selectSolid.height * spr.ID)) + ((70 - spr.height) / 2) + 4, elapsed, 0.2);
                }
                else if (tag == "hitbox")
                {
                    if (mouseMode)
                    {
                        spr.visible = FlxG.mouse.overlaps(spr, camModList);

                        if (FlxG.mouse.overlaps(spr, camModList) && FlxG.mouse.justPressed)
                        {
                            if (curSelected != spr.ID)
                                scroll(spr.ID, true);

                            select(spr.ID);
                        }
                    }
                    else if (!mouseMode && spr.visible)
                        spr.visible = false;
                }
                else if (tag == "active")
                {
                    if (mouseMode)
                        spr.visible = !FlxG.mouse.overlaps(spr, camModList) && PolymodManager.activeMod == mods[spr.ID].id && curSelected != spr.ID;
                    else if (keyboardMode)
                        spr.visible = PolymodManager.activeMod == mods[spr.ID].id && curSelected != spr.ID;
                }
            }

            modDesc.x = MathUtil.smoothLerpPrecision(modDesc.x, 500, elapsed, 0.3);
            modStatus.x = MathUtil.smoothLerpPrecision(modStatus.x, 500, elapsed, 0.3);
            modDesc.alpha = MathUtil.smoothLerpPrecision(modDesc.alpha, 0, elapsed, 0.1);

            if (keyboardMode)
            {
                if (controls.UI_DOWN.justPressed || controls.UI_UP.justPressed)
                    scroll(controls.UI_UP.justPressed ? -1 : 1);
                else if (controls.ACCEPT.justPressed)
                    select(curSelected);
            }

            if (controls.BACK.justPressed && !toggleBack)
                exit();
        }
        else
        {
            selectBox.alpha = MathUtil.smoothLerpPrecision(selectBox.alpha, 0, elapsed, 0.1);
            selectSolid.alpha = MathUtil.smoothLerpPrecision(selectSolid.alpha, 0, elapsed, 0.1);

            camModList.x = MathUtil.smoothLerpPrecision(camModList.x, 0, elapsed, 0.3);
            camModList.y = MathUtil.smoothLerpPrecision(camModList.y, 0, elapsed, 0.3);
            camModList.scroll.y = MathUtil.smoothLerpPrecision(camModList.scroll.y, modListBox.y, elapsed, 0.2);

            modListBox.scale.x = MathUtil.smoothLerpPrecision(modListBox.scale.x, FlxG.width - 200, elapsed, 0.13);
            modListBox.scale.y = MathUtil.smoothLerpPrecision(modListBox.scale.y, FlxG.height - 50, elapsed, 0.13);

            camModList.width = Std.int(modListBox.scale.x + 200);
            camModList.height = Std.int(modListBox.scale.y + 50);

            modScrollBarBg.alpha = MathUtil.smoothLerpPrecision(modScrollBarBg.alpha, 0, elapsed, 0.1);
            modScrollBarHandle.alpha = MathUtil.smoothLerpPrecision(modScrollBarHandle.alpha, 0, elapsed, 0.1);

            for (spr in infoGroup.members)
                spr.alpha = MathUtil.smoothLerpPrecision(spr.alpha, spr.ID == 1 ? 0.4 : 1, elapsed, 0.1);

            for (spr in contributorGroup.members)
            {
                var tag = spr.getTag();

                if (tag == "hitbox")
                    spr.alpha = MathUtil.smoothLerpPrecision(spr.alpha, 0.3, elapsed, 0.1);
                else if (tag == "title" || tag == "description")
                    spr.alpha = MathUtil.smoothLerpPrecision(spr.alpha, 1, elapsed, 0.1);
            }

            for (spr in uiTextGroup.members)
                spr.alpha = MathUtil.smoothLerpPrecision(spr.alpha, spr.ID == 1 ? 0.4 : 1, elapsed, 0.1);

            for (spr in modGroup.members)
            {
                var tag = spr.getTag();

                spr.alpha = MathUtil.smoothLerpPrecision(spr.alpha, (spr.ID == curSelected) ? ((tag == "hitbox") ? 0 : 1) : 0, elapsed, 0.15);

                if (spr.ID == curSelected)
                {
                    if (tag == "border")
                    {
                        spr.x = MathUtil.smoothLerpPrecision(spr.x, 550, elapsed, 0.2);
                        spr.y = MathUtil.smoothLerpPrecision(spr.y, 130, elapsed, 0.2);
                    }
                    else if (tag == "icon")
                    {
                        spr.x = MathUtil.smoothLerpPrecision(spr.x, 553, elapsed, 0.2);
                        spr.y = MathUtil.smoothLerpPrecision(spr.y, 133, elapsed, 0.2);
                    }
                    else if (tag == "title")
                    {
                        spr.scale.x = MathUtil.smoothLerpPrecision(spr.scale.x, 0.37, elapsed, 0.2);
                        spr.scale.y = spr.scale.x;
                        spr.updateHitbox();

                        spr.x = MathUtil.smoothLerpPrecision(spr.x, 546, elapsed, 0.2);
                        spr.y = MathUtil.smoothLerpPrecision(spr.y, 210, elapsed, 0.2);

                        modDesc.alpha = MathUtil.smoothLerpPrecision(modDesc.alpha, 1, elapsed, 0.3);

                        modDesc.x = MathUtil.smoothLerpPrecision(modDesc.x, 136, elapsed, 0.3);
                        modStatus.x = MathUtil.smoothLerpPrecision(modStatus.x, 220, elapsed, 0.3);
                        modDesc.y = MathUtil.smoothLerpPrecision(modDesc.y, spr.y - 30, elapsed, 0.3);
                    }
                }
            }

            for (spr in contributorGroup.members)
            {
                var tag = spr.getTag();

                if (tag == "url" || tag == "mail")
                    spr.alpha = MathUtil.smoothLerpPrecision(spr.alpha, FlxG.mouse.overlaps(spr, camContributorList) ? 1 : 0.3, elapsed, 0.2);

                if (tag == "url" && FlxG.mouse.overlaps(spr, camContributorList) && FlxG.mouse.justPressed)
                    openLink(spr.ID);
                else if (tag == "mail" && FlxG.mouse.overlaps(spr, camContributorList) && FlxG.mouse.justPressed)
                    openMail(spr.ID);
            }

            if (maxContributorScroll > 0)
            {
                if (FlxG.mouse.wheel != 0)
                    contributorScrollY -= FlxG.mouse.wheel * 50;

                if (keyboardMode)
                {
                    if (controls.UI_UP.pressed)
                        contributorScrollY -= 400 * elapsed;

                    if (controls.UI_DOWN.pressed)
                        contributorScrollY += 400 * elapsed;
                }

                if (mouseMode)
                {
                    if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(scrollBarHandle))
                    {
                        isDraggingScrollbar = true;
                        scrollDragOffset = FlxG.mouse.y - scrollBarHandle.y;
                    }
                    else if (FlxG.mouse.justReleased)
                        isDraggingScrollbar = false;
                }

                if (isDraggingScrollbar)
                {
                    var newHandleY:Float = FlxG.mouse.y - scrollDragOffset;
                    var minHandleY:Float = scrollBarBg.y;
                    var maxHandleY:Float = scrollBarBg.y + scrollBarBg.height - scrollBarHandle.height;

                    if (newHandleY < minHandleY) newHandleY = minHandleY;
                    if (newHandleY > maxHandleY) newHandleY = maxHandleY;

                    var scrollFraction:Float = (newHandleY - minHandleY) / (maxHandleY - minHandleY);
                    contributorScrollY = scrollFraction * maxContributorScroll;
                }

                if (contributorScrollY < 0) contributorScrollY = 0;
                if (contributorScrollY > maxContributorScroll) contributorScrollY = maxContributorScroll;

                camContributorList.scroll.y = MathUtil.smoothLerpPrecision(camContributorList.scroll.y, rightInfoSolid.y + contributorScrollY, elapsed, 0.2);

                var scrollFraction:Float = contributorScrollY / maxContributorScroll;
                scrollBarHandle.y = scrollBarBg.y + scrollFraction * (scrollBarBg.height - scrollBarHandle.height);
            }

            if (controls.BACK.justPressed)
                back();
            else if (controls.ACCEPT.justPressed)
                toggleMod(curSelected);
        }
    }

    function reloadMods():Void
    {
        modGroup.forEach(function(spr) spr.destroy());
        modGroup.clear();

        titleScales = [];

        PolymodManager.readAvaliableMods();
        mods = PolymodManager.availableMods;

        for (i in 0...mods.length)
        {
            var mod:ModMetadata = mods[i];

            var activeBox:FunkinSprite = new FunkinSprite().makeGraphic(Std.int(modListBox.width), Std.int(selectSolid.height), 0xFF598759);
            activeBox.tag = "active";
            activeBox.setPosition(modListBox.x, selectSolid.y + (selectSolid.height * i));
            activeBox.ID = i;
            activeBox.visible = false;
            activeBox.alpha = 0.3;
            modGroup.add(activeBox);

            var hitbox:FunkinSprite = new FunkinSprite().makeGraphic(Std.int(modListBox.width), Std.int(selectSolid.height));
            hitbox.tag = "hitbox";
            hitbox.setPosition(modListBox.x, selectSolid.y + (selectSolid.height * i));
            hitbox.ID = i;
            hitbox.visible = false;
            hitbox.alpha = 0.3;
            modGroup.add(hitbox);

            var iconBorder:FunkinSprite = new FunkinSprite().loadGraphic(Paths.image('menus/modLoader/iconBox'));
            iconBorder.tag = "border";
            iconBorder.setPosition(modListBox.x + 20, selectSolid.y + ((selectSolid.height - iconBorder.height) / 2) + (selectSolid.height * i));
            iconBorder.ID = i;
            iconBorder.alpha = i == curSelected ? 1 : 0.5;
            modGroup.add(iconBorder);

            var icon:FunkinSprite = new FunkinSprite().loadGraphic(Paths.image('mods/' + mod.id + '/_polymod_icon', "", "png", true, false));
            icon.tag = "icon";
            icon.setGraphicSize(Std.int(iconBorder.width - 6), Std.int(iconBorder.height - 6));
            icon.updateHitbox();
            icon.setPosition(modListBox.x + 23, iconBorder.y + 3);
            icon.ID = i;
            icon.alpha = i == curSelected ? 1 : 0.5;
            modGroup.add(icon);

            var text:FunkinBitmapText = new FunkinBitmapText(0, 0, mod.title, Paths.getAngelFont('tardling'));
            text.tag = "title";
            text.letterSpacing = -5;
            text.scale.set(0.37, 0.37);
            text.updateHitbox();

            var maxTitleWidth:Float = modListBox.width - 105 - 15;
            var titleScale:Float = 0.37;
            if (text.width > maxTitleWidth)
            {
                titleScale = 0.37 * (maxTitleWidth / text.width);
                text.scale.set(titleScale, titleScale);
                text.updateHitbox();
            }
            titleScales.push(titleScale);

            text.setPosition(iconBorder.x + 85, iconBorder.y + ((iconBorder.height - text.height) / 2) + 4);
            text.ID = i;
            text.alpha = i == curSelected ? 1 : 0.5;
            modGroup.add(text);
        }

        var totalModHeight:Float = mods.length * 100;
        var viewHeight:Float = 600;
        maxModScroll = Math.max(0, totalModHeight - viewHeight);

        if (maxModScroll > 0)
        {
            var handleHeight:Float = Math.max(20, (viewHeight / totalModHeight) * viewHeight);
            modScrollBarHandle.makeGraphic(5, Std.int(handleHeight), 0xFFFFFFFF);
        }
    }

    function reloadContributors(id:Int):Void
    {
        contributorGroup.forEach(function(spr) spr.destroy());
        contributorGroup.clear();

        for (i in 0...mods[id].contributors.length)
        {
            var contributor = mods[id].contributors[i];

            var name:String = contributor.name != null ? contributor.name : Std.string(contributor);
            var role:String = contributor.role;
            var url:String = contributor.url;
            var email:String = contributor.email;

            var hitbox:FunkinSprite = new FunkinSprite().makeGraphic(Std.int(rightInfoSolid.width), 70, 0xFF000000);
            hitbox.tag = "hitbox";
            hitbox.setPosition(rightInfoSolid.x, rightInfoSolid.y + ((hitbox.height + 5) * i));
            hitbox.ID = i;
            hitbox.alpha = 0.3;
            contributorGroup.add(hitbox);

            var title:FunkinBitmapText = new FunkinBitmapText(0, 0, name, Paths.getAngelFont('tardling'));
            title.tag = "title";
            title.scale.set(0.3, 0.3);
            title.updateHitbox();
            title.letterSpacing = -15;
            title.setPosition(hitbox.x + 10, hitbox.y + 2 + ((hitbox.height - title.height) / 2) - (role == null ? 0 : 10));
            contributorGroup.add(title);

            if (role != null)
            {
                var description:FunkinBitmapText = new FunkinBitmapText(0, 0, role, Paths.getAngelFont('pah'));
                description.tag = "description";
                description.scale.set(0.15, 0.15);
                description.updateHitbox();
                description.setPosition(hitbox.x + 15, hitbox.y + 2 + ((hitbox.height - description.height) / 2) + 10);
                contributorGroup.add(description);
            }

            if (url != null)
            {
                var urlIcon:FunkinSprite = new FunkinSprite().loadGraphic(Paths.image('menus/modLoader/contributorLink'));
                urlIcon.tag = "url";
                urlIcon.scale.set(0.5, 0.5);
                urlIcon.updateHitbox();
                urlIcon.setPosition(hitbox.x + (hitbox.width - urlIcon.width) - 5, hitbox.y + (hitbox.height - urlIcon.height) - 5);
                urlIcon.ID = i;
                urlIcon.alpha = 0.3;
                contributorGroup.add(urlIcon);
            }

            if (email != null)
            {
                var mailIcon:FunkinSprite = new FunkinSprite().loadGraphic(Paths.image('menus/modLoader/contributorMail'));
                mailIcon.tag = "mail";
                mailIcon.scale.set(0.5, 0.5);
                mailIcon.updateHitbox();
                mailIcon.setPosition(hitbox.x + (hitbox.width - mailIcon.width) - mailIcon.width - 10, hitbox.y + (hitbox.height - mailIcon.height) - 5);
                mailIcon.ID = i;
                mailIcon.alpha = 0.3;
                contributorGroup.add(mailIcon);
            }
        }

        var totalHeight:Float = 0;

        if (mods[id].contributors.length > 0)
            totalHeight = mods[id].contributors.length * 75;

        maxContributorScroll = Math.max(0, totalHeight - rightInfoSolid.height - 5);
        contributorScrollY = 0;
        camContributorList.scroll.y = rightInfoSolid.y;

        if (maxContributorScroll > 0)
        {
            scrollBarBg.visible = true;
            scrollBarHandle.visible = true;

            var handleHeight:Float = Math.max(20, (rightInfoSolid.height / totalHeight) * rightInfoSolid.height);
            scrollBarHandle.makeGraphic(5, Std.int(handleHeight), 0xFFFFFFFF);
        }
        else
        {
            scrollBarBg.visible = false;
            scrollBarHandle.visible = false;
        }
    }

    function scroll(dir:Int, ?force:Bool = false):Void
    {
        if (PolymodManager.availableMods.length == 0) return;

        if (!force)
        {
            curSelected += dir;

            if (curSelected >= PolymodManager.availableMods.length)
                curSelected = 0;
            else if (curSelected < 0)
                curSelected = PolymodManager.availableMods.length - 1;
        }
        else
            curSelected = dir;

        scrollSound.stop();
        scrollSound.play();

        var oldColor:FlxColor = selectBox.color;
        FlxTween.cancelTweensOf(selectBox);
        FlxTween.color(selectBox, 0.05, oldColor, PolymodManager.activeMod == mods[curSelected].id ? 0xFF7FFF7F : 0xFFFF7F7F);
    }

    function select(id:Int):Void
    {
        curSelected = id;
        inInfoMenu = true;
        contributorScrollY = 0;

        reloadContributors(curSelected);

        apiText.text = "v" + mods[id].apiVersion.toString();
        verText.text = "v" + mods[id].modVersion.toString();

        licenseText.text = mods[id].license;
        modDesc.text = mods[id].description;

        modStatus.color = (PolymodManager.activeMod == mods[curSelected].id ? 0xFF7FFF7F : 0xFFFF7F7F);
        modStatus.text = (PolymodManager.activeMod == mods[curSelected].id ? "ENABLED" : "DISABLED");
    }

    function toggleMod(id:Int):Void
    {
        var mod:ModMetadata = PolymodManager.availableMods[id];

        if (PolymodManager.activeMod != mod.id)
        {
            PolymodManager.enableMod(mod.id, false);
            FunkinSound.playOnce(Paths.sound('menus/modLoader/enable'), 1);
        }
        else
        {
            PolymodManager.disableMod(false);
            FunkinSound.playOnce(Paths.sound('menus/modLoader/disable'), 1);
        }

        back();
    }

    function back():Void
    {
        inInfoMenu = false;
        scroll(0);
    }

    function exit():Void
    {
        toggleBack = true;
        menuSong.fadeOut(0.3, 0);

        FlxG.mouse.visible = true;

        PolymodManager.reloadMods();

        ConfigRegistry.load();
        ConfigRegistry.execute();

        FunkinSound.stopAllAudio(true);
        Manager.switchState(new MainMenuState());
    }

    function openLink(id:Int):Void
    {
        var contributor = mods[curSelected].contributors[id];

        if (contributor.url != null)
            FlxG.openURL(contributor.url);
    }

    function openMail(id:Int):Void
    {
        var contributor = mods[curSelected].contributors[id];

        if (contributor.email != null)
            FlxG.openURL("https://mail.google.com/mail/?view=cm&fs=1&to=" + contributor.email);
    }
}
