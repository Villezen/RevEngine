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
import away3d.materials.utils.DefaultMaterialManager;
import openfl.Lib;
import openfl.display.BitmapData;
import flixel.FlxBasic;
import backend.utils.BitmapUtil;
import backend.utils.MtlUtil;
import backend.utils.tools.TagTools.ITaggable;

typedef ModelParams =
{
	var ?folder:String;
	var ?extension:String;
	var ?absolute:Bool;
	var ?scale:Float;
	var ?color:Null<FlxColor>;
	var ?bothSides:Bool;
	var ?onLoad:FunkinModel->Void;
}

class FunkinModel extends FlxBasic implements ITaggable
{
	public var tag:String = "";

	public var object3D(default, null):ObjectContainer3D;
	public var viewport(default, null):FunkinViewport;
	public var loaded(default, null):Bool = false;

	public var x(get, set):Float;
	public var y(get, set):Float;
	public var z(get, set):Float;

	public var rotationX(get, set):Float;
	public var rotationY(get, set):Float;
	public var rotationZ(get, set):Float;

	public var scaleX(get, set):Float;
	public var scaleY(get, set):Float;
	public var scaleZ(get, set):Float;

	public var modelPath(default, null):String;
	public var modelParams:ModelParams;

	public var meshes(default, null):Array<Mesh> = [];
	public var animations(default, null):Array<String> = [];
	public var currentAnimation(default, null):String;

	var _loader:Loader3D;
	var _onLoad:FunkinModel->Void;
	var _color:Null<FlxColor>;
	var _bothSides:Bool = false;

	var _mappedBitmaps:Array<BitmapData> = [];
	var _gltfContainer:ObjectContainer3D;

	var _animator:SkeletonAnimator; 
	var _animationSet:SkeletonAnimationSet;
	var _skeletonAnims:Array<String> = []; 
	var _nodeAnimator:GLTFNodeAnimator;

	var _ownedMaterials:Array<MaterialBase> = [];

	public function new(?path:String, ?params:ModelParams)
	{
		super();
		object3D = new ObjectContainer3D();

		if (path != null)
			loadModel(path, params);
	}

	@:allow(backend.assets.FunkinViewport)
	function attach(vp:FunkinViewport):Void
	{
		viewport = vp;
		configureMaterials();
	}

	@:allow(backend.assets.FunkinViewport)
	function detach():Void
	{
		viewport = null;
	}

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

	function loadGLTF(path:String, ext:String, folder:String, absolute:Bool, scale:Float):Void
	{
		var file = '$path.$ext';

		if (!Paths.exists('$folder/$file', absolute))
		{
			trace('Could not find model: $folder/$file', "ERROR");
			return;
		}

		var bytes = Paths.bytes(file, folder, absolute);
		if (bytes == null) return;

		var result = GLTFParser.parseGLB(bytes);
		if (result == null)
		{
			trace('Failed to parse glTF: $folder/$file', "ERROR");
			return;
		}

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

	function buildDependencyContext(objText:String, folder:String, absolute:Bool):AssetLoaderContext
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

	function onMeshComplete(event:Asset3DEvent):Void
	{
		if (event.asset != null && event.asset.assetType == Asset3DType.MESH)
			meshes.push(cast event.asset);
	}

	function onResourceComplete(_):Void
	{
		loaded = true;
		configureMaterials();

		if (_onLoad != null)
			_onLoad(this);
	}

	function onLoadError(event:LoaderEvent):Void
	{
		trace('Failed to load model $modelPath: ${event.message}', "ERROR");
	}

	function configureMaterials():Void
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

	public function setColor(color:FlxColor):Void
	{
		_color = color;
		configureMaterials();
	}

	public function setScale(value:Float):Void
	{
		object3D.scaleX = object3D.scaleY = object3D.scaleZ = value;
	}

	public function setPosition(x:Float = 0, y:Float = 0, z:Float = 0):Void
	{
		object3D.x = x;
		object3D.y = y;
		object3D.z = z;
	}

	function get_x():Float return object3D.x;
	function set_x(value:Float):Float return object3D.x = value;

	function get_y():Float return object3D.y;
	function set_y(value:Float):Float return object3D.y = value;

	function get_z():Float return object3D.z;
	function set_z(value:Float):Float return object3D.z = value;

	function get_rotationX():Float return object3D.rotationX;
	function set_rotationX(value:Float):Float return object3D.rotationX = value;

	function get_rotationY():Float return object3D.rotationY;
	function set_rotationY(value:Float):Float return object3D.rotationY = value;

	function get_rotationZ():Float return object3D.rotationZ;
	function set_rotationZ(value:Float):Float return object3D.rotationZ = value;

	function get_scaleX():Float return object3D.scaleX;
	function set_scaleX(value:Float):Float return object3D.scaleX = value;

	function get_scaleY():Float return object3D.scaleY;
	function set_scaleY(value:Float):Float return object3D.scaleY = value;

	function get_scaleZ():Float return object3D.scaleZ;
	function set_scaleZ(value:Float):Float return object3D.scaleZ = value;

	function clearModel():Void
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

		var defaultTex = DefaultMaterialManager.getDefaultTexture();
		for (mesh in meshes)
		{
			if (Std.isOfType(mesh.material, TextureMaterial))
			{
				var tex = cast(mesh.material, TextureMaterial).texture;

				if (tex != null && tex != defaultTex)
					tex.dispose();
			}
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

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var time = Lib.getTimer();

		if (_animator != null)
			_animator.update(Std.int(time));

		if (_nodeAnimator != null)
			_nodeAnimator.update(time);
	}

	override function set_visible(value:Bool):Bool
	{
		if (object3D != null)
			object3D.visible = value;

		return super.set_visible(value);
	}

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