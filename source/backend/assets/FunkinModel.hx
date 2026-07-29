package backend.assets;

import away3d.animators.SkeletonAnimationSet;
import away3d.animators.SkeletonAnimator;
import away3d.animators.nodes.SkeletonClipNode;
import away3d.containers.ObjectContainer3D;
import away3d.entities.Mesh;
import away3d.events.Asset3DEvent;
import away3d.events.LoaderEvent;
import away3d.library.assets.Asset3DType;
import away3d.loaders.Loader3D;
import away3d.loaders.misc.AssetLoaderContext;
import away3d.loaders.parsers.OBJParser;
import away3d.materials.ColorMaterial;
import away3d.materials.MaterialBase;
import away3d.materials.TextureMaterial;
import away3d.textures.Texture2DBase;
import away3d.materials.utils.DefaultMaterialManager;
import openfl.Lib;
import openfl.display.BitmapData;
import flixel.FlxBasic;
import backend.assets.GLTFParser.GLTFModel;
import backend.utils.BitmapUtil;
import backend.utils.MtlUtil;
import backend.utils.tools.TagTools.ITaggable;

/**
 * Params used when loading a model.
 */
typedef ModelParams =
{
	/**
	 * The folder the model sits in. Defaults to models.
	 */
	var ?folder:String;

	/**
	 * The file extension. If left out, it loads a .glb if there's one sitting there, and .obj if there isn't.
	 */
	var ?extension:String;

	/**
	 * Whether the path is somewhere outside the game's assets.
	 */
	var ?absolute:Bool;

	/**
	 * The scale of the model.
	 */
	var ?scale:Float;

	/**
	 * A flat color to paint the whole model. Overwrites materials if there are any.
	 */
	var ?color:Null<FlxColor>;

	/**
	 * Whether faces show from behind as well as in front.
	 */
	var ?bothSides:Bool;

	/**
	 * Called once the model has finished loading.
	 */
	var ?onLoad:FunkinModel->Void;
}

/**
 * A 3D model. Pretty cool...
 */
class FunkinModel extends FlxBasic implements ITaggable
{
	/**
	 * A name to look this model up by.
	 */
	public var tag:String = "";

	/**
	 * The 3D object holding the whole model.
	 */
	public var object3D(default, null):ObjectContainer3D;

	/**
	 * The viewport drawing this model, or null while it isn't in one.
	 */
	public var viewport(default, null):FunkinViewport;

	/**
	 * Whether the model has finished loading.
	 */
	public var loaded(default, null):Bool = false;

	/**
	 * Base positions of the model.
	 */
	public var x(get, set):Float;
	public var y(get, set):Float;
	public var z(get, set):Float;

	/**
	 * Base rotations of the model.
	 */
	public var rotationX(get, set):Float;
	public var rotationY(get, set):Float;
	public var rotationZ(get, set):Float;

	/**
	 * Base scale of the model.
	 */
	public var scaleX(get, set):Float;
	public var scaleY(get, set):Float;
	public var scaleZ(get, set):Float;

	/**
	 * The path the model was loaded from.
	 */
	public var modelPath(default, null):String;

	/**
	 * The params the model was loaded with.
	 */
	public var modelParams:ModelParams;

	/**
	 * Every mesh in the model.
	 */
	public var meshes(default, null):Array<Mesh> = [];

	/**
	 * The names of every animation the model has.
	 */
	public var animations(default, null):Array<String> = [];

	/**
	 * The animation playing right now.
	 */
	public var currentAnimation(default, null):String;

	/**
	 * Which keyframe the model's animation is at.
	 */
	public var frame(get, never):Int;

	/**
	 * The loader that reads the models. 
	 */
	private var _loader:Loader3D;

	/**
	 * Called once the model has finished loading.
	 */
	private var _onLoad:FunkinModel->Void;

	/**
	 * The color to paint the model with. Overwrites existing materials.
	 */
	private var _color:Null<FlxColor>;

	/**
	 * Whether faces show from behind as well as in front.
	 */
	private var _bothSides:Bool = false;

	/**
	 * Every texture bitmap the model made, kept so they can be cleared later.
	 */
	private var _mappedBitmaps:Array<BitmapData> = [];

	/**
	 * The object holding a .glb model's meshes.
	 */
	private var _gltfContainer:ObjectContainer3D;

	/**
	 * Everything the glb reader handed back, kept so the whole lot can go into the cache instead of being thrown away.
	 */
	private var _gltfResult:GLTFModel;

	/**
	 * The path the glb was read from, which is what the cache keeps it under.
	 */
	private var _gltfKey:String;

	/**
	 * The animator that moves the model's armature.
	 */
	private var _animator:SkeletonAnimator;

	/**
	 * The set of bone animations the animator plays from.
	 */
	private var _animationSet:SkeletonAnimationSet;

	/**
	 * The names of the bone animations.
	 */
	private var _skeletonAnims:Array<String> = [];

	/**
	 * The animator that moves whole nodes, used by models that animate without bones.
	 */
	private var _nodeAnimator:GLTFNodeAnimator;

	/**
	 * Materials the model made itself, kept so they can be cleared later.
	 */
	private var _ownedMaterials:Array<MaterialBase> = [];

	public function new(?path:String, ?params:ModelParams)
	{
		super();
		object3D = new ObjectContainer3D();

		if (path != null)
			loadModel(path, params);
	}

	/**
	 * Attaches the model up to a viewport, so it gets lit by that viewport's light.
	 * @param vp The viewport taking the model.
	 */
	@:allow(backend.assets.FunkinViewport)
	private function attach(vp:FunkinViewport):Void
	{
		viewport = vp;
		configureMaterials();
	}

	/**
	 * Detaches the model from its viewport.
	 */
	@:allow(backend.assets.FunkinViewport)
	private function detach():Void
	{
		viewport = null;
	}

	/**
	 * Loads a model.
	 * @param path The model to load.
	 * @param params Additional params, if any are given. 
	 * @return The loaded model.
	 */
	public function loadModel(path:String, ?params:ModelParams):FunkinModel
	{
		if (params == null) params = {};

		if (params.folder == null) params.folder = "models";
		if (params.absolute == null) params.absolute = false;
		if (params.scale == null) params.scale = 1.0;
		if (params.bothSides == null) params.bothSides = false;
		if (params.extension == null) params.extension = Paths.exists('${params.folder}/$path.glb', params.absolute) ? "glb" : "obj";

		this.modelParams = params;
		this.modelPath = path;

		_onLoad = params.onLoad;
		_color = params.color;
		_bothSides = params.bothSides;

		clearModel();

		var ext = params.extension.toLowerCase();

		if (ext == "glb" || ext == "gltf")
		{
			loadGLTF(path, ext, params.folder, params.absolute, params.scale);
			return this;
		}

		var file = '$path.$ext';
		if (!Paths.exists('${params.folder}/$file', params.absolute))
		{
			trace('Could not find model: ${params.folder}/$file', "WARNING");
			return this;
		}

		var text = Paths.data(file, params.folder, params.absolute);
		if (text == null || text == "")
		{
			trace('Model file is empty: ${params.folder}/$file', "WARNING");
			return this;
		}

		var context = (_color == null) ? buildDependencyContext(text, params.folder, params.absolute) : null;

		_loader = new Loader3D(false);
		_loader.addEventListener(Asset3DEvent.MESH_COMPLETE, onMeshComplete);
		_loader.addEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceComplete);
		_loader.addEventListener(LoaderEvent.LOAD_ERROR, onLoadError);
		_loader.loadData(text, context, null, new OBJParser(params.scale));

		object3D.addChild(_loader);

		return this;
	}

	/**
	 * Loads a glb model and sets up whatever animations came with it.
	 * @param path The model to load.
	 * @param ext The file extension, glb or gltf.
	 * @param folder The folder its located in.
	 * @param absolute Whether the path is outside the game's assets.
	 * @param scale The scale of the model.
	 */
	private function loadGLTF(path:String, ext:String, folder:String, absolute:Bool, scale:Float):Void
	{
		var file = '$path.$ext';

		if (!Paths.exists('$folder/$file', absolute))
		{
			trace('Could not find model: $folder/$file', "ERROR");
			return;
		}

		var key = absolute ? file : 'assets/$folder/$file';
		var result = Cacher.instance.takeModel(key);

		if (result == null)
		{
			var bytes = Paths.bytes(file, folder, absolute);
			if (bytes == null) return;

			result = GLTFParser.parseGLB(bytes);

			if (result == null)
			{
				trace('Failed to parse glTF: $folder/$file', "ERROR");
				return;
			}
		}

		_gltfResult = result;
		_gltfKey = key;

		_gltfContainer = result.object;
		_gltfContainer.scaleX = _gltfContainer.scaleY = _gltfContainer.scaleZ = scale;
		object3D.addChild(_gltfContainer);

		meshes = result.meshes;
		_mappedBitmaps = result.bitmaps;

		if (result.skeleton != null && result.animationSet != null && result.animationNames.length > 0 && result.skinnedMeshes.length > 0)
		{
			_animationSet = result.animationSet;
			_skeletonAnims = result.animationNames;

			var forceCPU = result.skeleton.joints.length > 30;
			_animator = new SkeletonAnimator(_animationSet, result.skeleton, forceCPU);
			_animator.autoUpdate = false;

			for (mesh in result.skinnedMeshes)
				mesh.animator = _animator;

			var firstAnim = cast(_animationSet.getAnimation(_skeletonAnims[0]), SkeletonClipNode);
			if (firstAnim != null) firstAnim.looping = true;

			_animator.play(_skeletonAnims[0], null, 0);
		}

		_nodeAnimator = result.nodeAnimator;
		animations = (_nodeAnimator != null && _nodeAnimator.names.length > 0) ? _nodeAnimator.names.copy() : _skeletonAnims.copy();

		if (animations.length > 0)
			play(animations[0]);

		loaded = true;
		configureMaterials();

		if (_onLoad != null)
			_onLoad(this);
	}

	/**
	 * Plays one of the model's animations.
	 * @param name The animation to play.
	 * @param loop Whether it loops.
	 */
	public function play(name:String, loop:Bool = true):Void
	{
		var played = false;

		if (_nodeAnimator != null && _nodeAnimator.hasClip(name))
		{
			_nodeAnimator.play(name, loop);
			played = true;
		}

		if (_animator != null && _skeletonAnims.indexOf(name) >= 0)
		{
			if (_animationSet != null)
			{
				var node = cast(_animationSet.getAnimation(name), SkeletonClipNode);
				if (node != null) node.looping = loop;
			}

			_animator.play(name, null, 0);
			played = true;
		}

		if (played)
			currentAnimation = name;
		else
			trace('Model animation not found: $name', "WARNING");
	}

	/**
	 * Gets the mtl file and the textures an obj model asks for, so the loader can find them.
	 * @param objText The text of the obj file.
	 * @param folder The folder it sits in.
	 * @param absolute Whether the path is outside the game's assets.
	 * @return The context holding the mtl and the textures the loader needs.
	 */
	private function buildDependencyContext(objText:String, folder:String, absolute:Bool):AssetLoaderContext
	{
		var mtlName = MtlUtil.findMtlLib(objText);
		if (mtlName == null) return null;

		var mtlText = Paths.data(mtlName, folder, absolute);
		if (mtlText == null || mtlText == "") return null;

		var context = new AssetLoaderContext(true);
		context.mapUrlToData(mtlName, mtlText);

		for (texName in MtlUtil.findTextureRefs(mtlText))
		{
			var bmp = Paths.bitmapData(texName, folder, "", absolute);
			if (bmp == null) continue;

			var pot = BitmapUtil.toPowerOfTwo(bmp);
			_mappedBitmaps.push(pot);
			context.mapUrlToData(texName, pot);
		}

		return context;
	}

	/**
	 * Keeps every mesh the obj loader hands over.
	 * @param event The loader event holding the mesh.
	 */
	private function onMeshComplete(event:Asset3DEvent):Void
	{
		if (event.asset != null && event.asset.assetType == Asset3DType.MESH)
			meshes.push(cast event.asset);
	}

	/**
	 * Finishes an obj load once everything it needed has come in.
	 * @param event The loader event.
	 */
	private function onResourceComplete(event):Void
	{
		loaded = true;
		configureMaterials();

		if (_onLoad != null)
			_onLoad(this);
	}

	/**
	 * Traces an error that may occur while loading a mode.
	 * @param event The loader event, containing info about the error.
	 */
	private function onLoadError(event:LoaderEvent):Void
	{
		trace('Failed to load model $modelPath: ${event.message}', "ERROR");
	}

	/**
	 * Gives every mesh the light of the viewport it sits in.
	 */
	private function configureMaterials():Void
	{
		for (mat in _ownedMaterials)
			mat.dispose();

		_ownedMaterials = [];
		var picker = viewport?.lightPicker;

		for (mesh in meshes)
		{
			if (_color != null)
			{
				var mat = new ColorMaterial(_color);
				mat.lightPicker = picker;
				mat.bothSides = _bothSides;
				mesh.material = mat;

				_ownedMaterials.push(mat);
			}
			else if (mesh.material != null)
			{
				mesh.material.lightPicker = picker;
				mesh.material.bothSides = _bothSides;
			}
		}
	}

	/**
	 * Paints the whole model one color.
	 * @param color The color to paint it.
	 */
	public function setColor(color:FlxColor):Void
	{
		_color = color;
		configureMaterials();
	}

	/**
	 * Sets how big the model is.
	 * @param value The scale to set on every axis.
	 */
	public function setScale(value:Float):Void
	{
		object3D.scaleX = object3D.scaleY = object3D.scaleZ = value;
	}

	/**
	 * Moves the model.
	 * @param x Target X Axis.
	 * @param y Target Y Axis.
	 * @param z Target Z Axis.
	 */
	public function setPosition(x:Float = 0, y:Float = 0, z:Float = 0):Void
	{
		object3D.x = x;
		object3D.y = y;
		object3D.z = z;
	}

	private function get_frame():Int return _nodeAnimator != null ? _nodeAnimator.frame : -1;

	private function get_x():Float return object3D.x;
	private function set_x(value:Float):Float return object3D.x = value;

	private function get_y():Float return object3D.y;
	private function set_y(value:Float):Float return object3D.y = value;

	private function get_z():Float return object3D.z;
	private function set_z(value:Float):Float return object3D.z = value;

	private function get_rotationX():Float return object3D.rotationX;
	private function set_rotationX(value:Float):Float return object3D.rotationX = value;

	private function get_rotationY():Float return object3D.rotationY;
	private function set_rotationY(value:Float):Float return object3D.rotationY = value;

	private function get_rotationZ():Float return object3D.rotationZ;
	private function set_rotationZ(value:Float):Float return object3D.rotationZ = value;

	private function get_scaleX():Float return object3D.scaleX;
	private function set_scaleX(value:Float):Float return object3D.scaleX = value;

	private function get_scaleY():Float return object3D.scaleY;
	private function set_scaleY(value:Float):Float return object3D.scaleY = value;

	private function get_scaleZ():Float return object3D.scaleZ;
	private function set_scaleZ(value:Float):Float return object3D.scaleZ = value;

	/**
	 * Puts a glb model into the cache instead of freeing it.
	 * @return Whether the model went into the cache.
	 */
	private function keepModel():Bool
	{
		if (_gltfResult == null || _gltfKey == null || _color != null)
			return false;

		for (mat in _ownedMaterials)
			mat.dispose();

		if (object3D != null && object3D.contains(_gltfContainer))
			object3D.removeChild(_gltfContainer);

		Cacher.instance.stampFile(_gltfKey, Paths.getPath(_gltfKey));
		Cacher.instance.putModel(_gltfKey, _gltfResult);

		_gltfResult = null;
		_gltfKey = null;
		_gltfContainer = null;

		_ownedMaterials = [];
		_mappedBitmaps = [];
		meshes = [];
		loaded = false;

		return true;
	}

	/**
	 * Frees everything the model currently has loaded.
	 */
	private function clearModel():Void
	{
		if (_animator != null)
		{
			_animator.stop();
			_animator = null;
		}

		_animationSet = null;
		_nodeAnimator = null;
		_skeletonAnims = [];
		animations = [];
		currentAnimation = null;

		if (keepModel())
			return;

		var defaultTex = DefaultMaterialManager.getDefaultTexture();
		var freed:Array<Texture2DBase> = [];

		for (mesh in meshes)
		{
			if (!Std.isOfType(mesh.material, TextureMaterial))
				continue;

			var tex = cast(mesh.material, TextureMaterial).texture;

			if (tex == null || tex == defaultTex || freed.contains(tex))
				continue;

			freed.push(tex);
			tex.dispose();
		}

		for (mat in _ownedMaterials) mat.dispose();
		for (bmp in _mappedBitmaps) bmp.dispose();

		if (_loader != null)
		{
			_loader.removeEventListener(Asset3DEvent.MESH_COMPLETE, onMeshComplete);
			_loader.removeEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceComplete);
			_loader.removeEventListener(LoaderEvent.LOAD_ERROR, onLoadError);
			_loader.stopLoad();

			if (object3D.contains(_loader))
				object3D.removeChild(_loader);

			_loader.disposeWithChildren();
			_loader = null;
		}

		if (_gltfContainer != null)
		{
			if (object3D.contains(_gltfContainer))
				object3D.removeChild(_gltfContainer);

			_gltfContainer.disposeWithChildren();
			_gltfContainer = null;
		}

		_ownedMaterials = [];
		_mappedBitmaps = [];
		meshes = [];
		loaded = false;
	}

	/**
	 * Updates the model's animation.
	 */
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var time = Lib.getTimer();

		if (_animator != null)
			_animator.update(Std.int(time));

		if (_nodeAnimator != null)
			_nodeAnimator.update(time);
	}

	/**
	 * Shows or hides the model.
	 * @param value Whether the model shows.
	 * @return The value that was set.
	 */
	override function set_visible(value:Bool):Bool
	{
		if (object3D != null)
			object3D.visible = value;

		return super.set_visible(value);
	}

	/**
	 * Frees the model and takes it out of the viewport it was in.
	 */
	override public function destroy():Void
	{
		clearModel();

		if (viewport != null)
			viewport.remove(this);

		if (object3D != null)
		{
			object3D.disposeWithChildren();
			object3D = null;
		}

		super.destroy();
	}
}
