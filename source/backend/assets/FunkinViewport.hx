package backend.assets;

import away3d.cameras.Camera3D;
import away3d.cameras.lenses.PerspectiveLens;
import away3d.containers.ObjectContainer3D;
import away3d.containers.Scene3D;
import away3d.containers.View3D;
import away3d.entities.Mesh;
import away3d.lights.DirectionalLight;
import away3d.materials.lightpickers.StaticLightPicker;

import openfl.display.BitmapData;
import openfl.geom.Vector3D;

import flixel.FlxBasic;
import flixel.FlxCamera;

/**
 * Params used when making a viewport.
 */
typedef ViewportParams =
{
	/**
	 * Draws straight to the screen instead of into a bitmap.
	 */
	var ?direct:Bool;

	/**
	 * The size of the viewport. 
	 */
	var ?width:Float;
	var ?height:Float;

	/**
	 * Where a direct view sits on the screen.
	 */
	var ?x:Float;
	var ?y:Float;

	/**
	 * How wide the camera sees, in degrees. Defaults to 60.
	 */
	var ?fov:Float;

	/**
	 * Wheater the model is aliased or not.
	 */
	var ?antiAlias:Int;

	/**
	 * How lit the sides facing away from the light still are. Defaults to 0.35.
	 */
	var ?ambient:Float;
}

/**
 * An Away3D viewport. Renders as a bitmap, or directly on the screen.
 */
class FunkinViewport extends FlxBasic
{
	/**
	 * The viewport the scene gets rendered through.
	 */
	public var view:View3D;

	/**
	 * The 3D world the models sit in.
	 */
	public var scene:Scene3D;

	/**
	 * The camera the scene gets rendered from.
	 */
	public var camera3D:Camera3D;

	/**
	 * The light shining on the models.
	 */
	public var light:DirectionalLight;

	/**
	 * Hands the light over to the materials of every model, so they get lit by it.
	 */
	public var lightPicker:StaticLightPicker;

	/**
	 * Every model this viewport renders.
	 */
	public var models(default, null):Array<FunkinModel> = [];

	/**
	 * Whether this viewport draws straight to the screen instead of into a bitmap.
	 */
	public var direct(default, null):Bool = false;

	/**
	 * The game camera a direct view follows.
	 */
	public var followCamera:FlxCamera;

	/**
	 * Offset values for positioning this viewport. Mainly used while its is attached to a game camera.
	 */
	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var offsetZ:Float = 0;

	/**
	 * The perspective lens the camera looks through.
	 */
	private var _lens:PerspectiveLens;

	/**
	 * Whether a direct view resizes along with the screen.
	 */
	private var _autoSize:Bool = false;

	/**
	 * The lowest and highest corner a model reaches.
	 */
	private var _min:Vector3D = new Vector3D();
	private var _max:Vector3D = new Vector3D();

	/**
	 * Backup vectors reused while measuring, so a new one isn't made for every corner.
	 */
	private var _corner:Vector3D = new Vector3D();
	private var _moved:Vector3D = new Vector3D();

	/**
	 * Builds the scene.
	 * @param params How to set the viewport up.
	 */
	public function new(?params:ViewportParams)
	{
		super();

		if (params == null) params = {};

		if (params.direct == null) params.direct = false;
		if (params.fov == null) params.fov = 60;
		if (params.antiAlias == null) params.antiAlias = 0;
		if (params.ambient == null) params.ambient = 0.35;

		direct = params.direct;

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

		if (direct)
		{
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

			if (FlxG.game != null)
				FlxG.game.addChildAt(view, 0);

			FlxG.signals.postDraw.add(drawDirect);
			FlxG.signals.gameResized.add(onResize);

			return;
		}

		view.width = params.width ?? FlxG.width;
		view.height = params.height ?? FlxG.height;

		view.visible = false;
		FlxG.stage.addChildAt(view, 0);
	}

	/**
	 * Sizes a direct view to the screen.
	 */
	private function fitToStage():Void
	{
		view.width = FlxG.stage.stageWidth;
		view.height = FlxG.stage.stageHeight;
	}

	/**
	 * Keeps a direct view the of the size of the screen when the window changes.
	 * @param width The new width of the screen.
	 * @param height The new height of the screen.
	 */
	private function onResize(width:Int, height:Int):Void
	{
		if (_autoSize)
			fitToStage();
	}

	/**
	 * Moves the camera of a direct view so the scene lines up with the game camera it follows.
	 */
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

	/**
	 * Draws a direct view onto the screen.
	 */
	private function drawDirect():Void
	{
		if (!exists || models.length == 0 || view == null || view.stage3DProxy == null)
			return;

		updateFollow();
		view.render();
	}

	/**
	 * Adds a model to the scene.
	 * @param model The model to add.
	 * @return The model that was added.
	 */
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

	/**
	 * Removes a model from the scene.
	 * @param model The model to take out.
	 * @return The model that was taken out.
	 */
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

	/**
	 * Calculates the model's actual size by converting all mesh corners to the viewport's coordinates.
	 * @param obj The object to go width.
	 */
	private function measure(obj:ObjectContainer3D):Void
	{
		if (Std.isOfType(obj, Mesh))
		{
			var bounds = cast(obj, Mesh).bounds;
			var world = obj.sceneTransform;

			if (bounds != null && Math.isFinite(bounds.min.x) && Math.isFinite(bounds.max.x))
			{
				for (i in 0...8)
				{
					_corner.x = (i & 1) == 0 ? bounds.min.x : bounds.max.x;
					_corner.y = (i & 2) == 0 ? bounds.min.y : bounds.max.y;
					_corner.z = (i & 4) == 0 ? bounds.min.z : bounds.max.z;

					world.transformVectorToOutput(_corner, _moved);

					if (_moved.x < _min.x) _min.x = _moved.x;
					if (_moved.y < _min.y) _min.y = _moved.y;
					if (_moved.z < _min.z) _min.z = _moved.z;

					if (_moved.x > _max.x) _max.x = _moved.x;
					if (_moved.y > _max.y) _max.y = _moved.y;
					if (_moved.z > _max.z) _max.z = _moved.z;
				}
			}
		}

		for (i in 0...obj.numChildren)
			measure(obj.getChildAt(i));
	}

	/**
	 * Points the camera at a model and backs off far enough that it stays in frame.
	 * @param model The model to look at.
	 * @param margin The spare margin left around it to ensure it doesn't cut off.
	 */
	public function frame(model:FunkinModel, margin:Float = 2.0):Void
	{
		_min.setTo(Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY);
		_max.setTo(Math.NEGATIVE_INFINITY, Math.NEGATIVE_INFINITY, Math.NEGATIVE_INFINITY);

		measure(model.object3D);

		if (!Math.isFinite(_min.x))
			return;

		var cx = (_min.x + _max.x) / 2;
		var cy = (_min.y + _max.y) / 2;
		var cz = (_min.z + _max.z) / 2;

		var halfW = (_max.x - _min.x) / 2;
		var halfH = (_max.y - _min.y) / 2;
		var halfD = (_max.z - _min.z) / 2;

		var radius = Math.sqrt(halfW * halfW + halfH * halfH + halfD * halfD);

		if (radius <= 0)
			radius = 1;

		var dist = radius / Math.sin(_lens.fieldOfView * Math.PI / 360) * margin;

		_lens.near = dist * 0.01;
		_lens.far = dist * 100;

		camera3D.x = cx;
		camera3D.y = cy;
		camera3D.z = cz - dist;
		camera3D.lookAt(new Vector3D(cx, cy, cz));
	}

	/**
	 * Renders the viewport into the given bitmap.
	 * @param target The bitmap the scene gets drawn onto.
	 */
	public function render(target:BitmapData):Void
	{
		if (direct || !exists || models.length == 0 || view == null || target == null)
			return;

		if (view.parent == null)
			FlxG.stage.addChildAt(view, 0);

		view.renderer.queueSnapshot(target);
		view.render();
	}

	/**
	 * Frees every model, the view and the scene around it.
	 */
	override public function destroy():Void
	{
		if (direct)
		{
			FlxG.signals.postDraw.remove(drawDirect);
			FlxG.signals.gameResized.remove(onResize);
		}

		while (models.length > 0)
		{
			var model = models.pop();

			if (scene != null && scene.contains(model.object3D))
				scene.removeChild(model.object3D);

			model.detach();
			model.destroy();
		}

		if (view != null)
		{
			if (view.parent != null)
				view.parent.removeChild(view);

			view.renderer.queueSnapshot(null);
			view.dispose();
			view = null;
		}

		scene = null;
		camera3D = null;
		light = null;
		lightPicker = null;
		_lens = null;

		super.destroy();
	}
}
