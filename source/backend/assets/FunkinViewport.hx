package backend.assets;

import away3d.cameras.Camera3D;
import away3d.cameras.lenses.PerspectiveLens;
import away3d.containers.Scene3D;
import away3d.containers.View3D;
import away3d.lights.DirectionalLight;
import away3d.materials.lightpickers.StaticLightPicker;

import openfl.geom.Vector3D;

import flixel.FlxBasic;
import flixel.FlxCamera;

typedef ViewportParams =
{
	var ?x:Float;
	var ?y:Float;

	var ?width:Float;
	var ?height:Float;

	var ?fov:Float;

	var ?antiAlias:Int;
	var ?ambient:Float;
}

class FunkinViewport extends FlxBasic
{
	public var view:View3D;
	public var scene:Scene3D;
	public var camera3D:Camera3D;
	public var light:DirectionalLight;
	public var lightPicker:StaticLightPicker;
	public var models(default, null):Array<FunkinModel> = [];

	public var followCamera:FlxCamera;
	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var offsetZ:Float = 0;

	var _lens:PerspectiveLens;
	var _autoSize:Bool = false;

	public function new(?params:ViewportParams)
	{
		super();

		if (params == null) params = {};

		if (params.fov == null) params.fov = 60;
		if (params.antiAlias == null) params.antiAlias = 0;
		if (params.ambient == null) params.ambient = 0.35;

		scene = new Scene3D();

		_lens = new PerspectiveLens(params.fov);
		camera3D = new Camera3D(_lens);
		camera3D.z = -1000;
		camera3D.lookAt(new Vector3D(0, 0, 0));

		view = new View3D(scene, camera3D);
		view.antiAlias = params.antiAlias;
		view.mouseEnabled = false;
		view.mouseChildren = false;

		view.backgroundAlpha = 0;

		light = new DirectionalLight(-0.5, -1, 0.5);
		light.color = 0xffffff;
		light.ambient = params.ambient;
		light.diffuse = 0.9;
		light.specular = 0.4;

		lightPicker = new StaticLightPicker([light]);
		scene.addChild(light);

		if (FlxG.game != null)
			FlxG.game.addChildAt(view, 0);

		view.x = params.x ?? 0;
		view.y = params.y ?? 0;

		if (params.width != null && params.height != null)
		{
			view.width = params.width;
			view.height = params.height;
		}
		else
		{
			_autoSize = true;
			fitToStage();
		}

		FlxG.signals.postDraw.add(render);
		FlxG.signals.gameResized.add(onResize);
	}

	function fitToStage():Void
	{
		view.width = FlxG.stage.stageWidth;
		view.height = FlxG.stage.stageHeight;
	}

	function onResize(width:Int, height:Int):Void
	{
		if (_autoSize)
			fitToStage();
	}

	public function lookAt(x:Float, y:Float, z:Float):Void
	{
		camera3D.lookAt(new Vector3D(x, y, z));
	}

	public function add(model:FunkinModel):FunkinModel
	{
		if (model == null || models.contains(model))
			return model;

		models.push(model);
		model.attach(this);

		if (!scene.contains(model.object3D))
			scene.addChild(model.object3D);

		return model;
	}

	public function remove(model:FunkinModel):FunkinModel
	{
		if (model == null || !models.contains(model))
			return model;

		models.remove(model);

		if (scene.contains(model.object3D))
			scene.removeChild(model.object3D);

		model.detach();

		return model;
	}

	public function updateFollow():Void
	{
		if (followCamera == null)
			return;

		camera3D.z = offsetZ;

		var focalDist = Math.abs(offsetZ);
		var worldPerPixel = 2 * focalDist * Math.tan(_lens.fieldOfView * Math.PI / 360) / view.height;
		var scale = worldPerPixel * followCamera.zoom;

		camera3D.x = offsetX + followCamera.scroll.x * scale;
		camera3D.y = offsetY - followCamera.scroll.y * scale;
	}

	public function render():Void
	{
		if (!exists || models.length == 0 || view == null || view.stage3DProxy == null)
			return;

		updateFollow();
		view.render();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		for (model in models)
		{
			if (model.active)
				model.update(elapsed);
		}
	}

	override public function destroy():Void
	{
		FlxG.signals.postDraw.remove(render);
		FlxG.signals.gameResized.remove(onResize);

		while (models.length > 0)
		{
			var model = models.pop();

			if (scene.contains(model.object3D))
				scene.removeChild(model.object3D);

			model.detach();
			model.destroy();
		}

		if (view != null)
		{
			if (view.parent != null)
				view.parent.removeChild(view);

			view.dispose();
			view = null;
		}

		scene = null;
		camera3D = null;
		light = null;
		lightPicker = null;
		followCamera = null;
		_lens = null;

		super.destroy();
	}
}
