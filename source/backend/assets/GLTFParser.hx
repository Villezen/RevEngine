package backend.assets;

import haxe.io.Bytes;
import haxe.Json;

import away3d.animators.SkeletonAnimationSet;
import away3d.animators.SkeletonAnimator;
import away3d.animators.data.JointPose;
import away3d.animators.data.Skeleton;
import away3d.animators.data.SkeletonJoint;
import away3d.animators.data.SkeletonPose;
import away3d.animators.nodes.SkeletonClipNode;
import away3d.containers.ObjectContainer3D;
import away3d.core.base.Geometry;
import away3d.core.base.SubGeometry;
import away3d.core.base.SkinnedSubGeometry;
import away3d.core.math.Quaternion;
import away3d.entities.Mesh;
import away3d.materials.ColorMaterial;
import away3d.materials.MaterialBase;
import away3d.materials.TextureMaterial;
import away3d.textures.BitmapTexture;

import openfl.Vector;
import openfl.display.BitmapData;
import openfl.geom.Matrix3D;
import openfl.geom.Vector3D;

import backend.utils.BitmapUtil;
import backend.assets.GLTFNodeAnimator.GLTFSampler;
import backend.assets.GLTFNodeAnimator.GLTFNodeClip;
import backend.assets.GLTFNodeAnimator.GLTFNodeTrack;

typedef GLTFModel = 
{
    var object:ObjectContainer3D;
    var meshes:Array<Mesh>;
    var skinnedMeshes:Array<Mesh>;
    var bitmaps:Array<BitmapData>;
    var skeleton:Skeleton;
    var animationSet:SkeletonAnimationSet;
    var animationNames:Array<String>;
    var nodeAnimator:GLTFNodeAnimator;
}

class GLTFParser 
{
    // ltf component types 
    static inline var CT_BYTE = 5120;
    static inline var CT_UBYTE = 5121;
    static inline var CT_SHORT = 5122;
    static inline var CT_USHORT = 5123;
    static inline var CT_UINT = 5125;
    static inline var CT_FLOAT = 5126;

    static inline var RESAMPLE_FPS = 30.0;

    var _json:Dynamic;
    var _bin:Bytes;

    var _nodeContainers:Array<ObjectContainer3D> = [];
    var _childToParent:Map<Int, Int> = new Map();

    var _skeleton:Skeleton;
    var _skeletonAnimator:SkeletonAnimator;
    var _activeSkinIndex:Int = -1; 
    var _jointNodes:Array<Int> = []; 
    var _jointNodeToIndex:Map<Int, Int> = new Map();
    var _ibm:Array<Matrix3D> = [];

    var _outMeshes:Array<Mesh> = [];
    var _outSkinnedMeshes:Array<Mesh> = [];
    var _outBitmaps:Array<BitmapData> = [];
    var _materialCache:Map<Int, MaterialBase> = new Map();

    function new() {}

    public static function parseGLB(bytes:Bytes):GLTFModel 
    {
        if (bytes == null || bytes.length < 12) 
            return null;

        if (bytes.getInt32(0) != 0x46546C67) 
        {
            trace("Not a valid binary glTF file has been given.", "ERROR");
            return null;
        }

        var json:Dynamic = null;
        var bin:Bytes = null;
        var pos = 12;

        while (pos + 8 <= bytes.length) 
        {
            var chunkLength = bytes.getInt32(pos);
            var chunkType = bytes.getInt32(pos + 4);
            var dataStart = pos + 8;

            if (chunkType == 0x4E4F534A) 
                json = Json.parse(bytes.getString(dataStart, chunkLength));
            else if (chunkType == 0x004E4942) 
                bin = bytes.sub(dataStart, chunkLength);

            pos = dataStart + chunkLength;
        }

        if (json == null) 
        {
            trace("Parser has founded no JSON chunk.", "WARNING");
            return null;
        }

        return new GLTFParser().build(json, bin);
    }

    function build(json:Dynamic, bin:Bytes):GLTFModel 
    {
        _json = json;
        _bin = bin;

        buildChildToParent();
        _activeSkinIndex = findActiveSkin();

        var root = new ObjectContainer3D();
        buildNodeContainers(root);

        var animationSet:SkeletonAnimationSet = null;
        var animationNames:Array<String> = [];
        
        if (_activeSkinIndex >= 0) 
        {
            var skins = getArray("skins");
            buildSkeleton(skins[_activeSkinIndex]);
        }

        if (_skeleton != null) 
        {
            animationSet = new SkeletonAnimationSet(4); 
            _skeletonAnimator = new SkeletonAnimator(animationSet, _skeleton);
            
            var anims = getArray("animations");
            for (i in 0...anims.length) 
            {
                var clip = buildClip(anims[i], i);

                if (clip != null) 
                {
                    animationSet.addAnimation(clip);
                    animationNames.push(clip.name);
                }
            }
        }

        var nodes = getArray("nodes");
        for (i in 0...nodes.length) 
        {
            var node = nodes[i];

            if (node.mesh == null) 
                continue;

            var skinIndex = Reflect.hasField(node, "skin") ? Std.int(node.skin) : -1;
            var meshDef = getArray("meshes")[Std.int(node.mesh)];
            
            if (meshDef.primitives == null) 
                continue;

            for (prim in (meshDef.primitives : Array<Dynamic>)) 
                buildPrimitive(prim, skinIndex, i, root);
        }

        return 
        {
            object: root,
            meshes: _outMeshes,
            skinnedMeshes: _outSkinnedMeshes,
            bitmaps: _outBitmaps,
            skeleton: _skeleton,
            animationSet: animationSet,
            animationNames: animationNames,
            nodeAnimator: buildNodeAnimator()
        };
    }

    function buildNodeContainers(root:ObjectContainer3D):Void 
    {
        var nodes = getArray("nodes");
        
        for (i in 0...nodes.length) 
        {
            var c = new ObjectContainer3D();
            c.transform = getLocalMatrix(nodes[i]);
            _nodeContainers.push(c);
        }

        for (i in 0...nodes.length) 
        {
            if (nodes[i].children != null) 
            {
                for (childIndex in (nodes[i].children : Array<Dynamic>)) 
                    _nodeContainers[i].addChild(_nodeContainers[Std.int(childIndex)]);
            }
        }

        var sceneIndex = Reflect.hasField(_json, "scene") ? Std.int(_json.scene) : 0;
        var scenes = getArray("scenes");
        
        if (scenes.length > sceneIndex && scenes[sceneIndex].nodes != null) 
        {
            for (r in (scenes[sceneIndex].nodes : Array<Dynamic>)) 
                root.addChild(_nodeContainers[Std.int(r)]);
        } 
        else 
        {
            for (i in 0...nodes.length) 
            {
                if (!_childToParent.exists(i)) 
                    root.addChild(_nodeContainers[i]);
            }
        }
    }

    function buildSkeleton(skin:Dynamic):Void 
    {
        var joints:Array<Dynamic> = skin.joints;
        var ibmRaw:Array<Float> = skin.inverseBindMatrices != null ? readFloats(Std.int(skin.inverseBindMatrices)) : null;

        _skeleton = new Skeleton();
        _skeleton.joints = new Vector<SkeletonJoint>();

        for (ji in 0...joints.length) 
        {
            var nodeIndex = Std.int(joints[ji]);
            _jointNodes.push(nodeIndex);
            _jointNodeToIndex.set(nodeIndex, ji);
        }

        var nodes = getArray("nodes");
        
        for (ji in 0...joints.length) 
        {
            var nodeIndex = _jointNodes[ji];
            var joint = new SkeletonJoint();
            joint.name = nodes[nodeIndex].name != null ? nodes[nodeIndex].name : 'joint_$ji';

            var parentNode = _childToParent.exists(nodeIndex) ? _childToParent.get(nodeIndex) : -1;
            joint.parentIndex = (parentNode >= 0 && _jointNodeToIndex.exists(parentNode)) ? _jointNodeToIndex.get(parentNode) : -1;

            if (ibmRaw != null) 
            {
                var rawMatrix = ibmRaw.slice(ji * 16, (ji + 1) * 16);

                var m = new Matrix3D(Vector.ofArray(rawMatrix));
                m.appendScale(1, 1, -1); 
                m.prependScale(1, 1, -1);
                
                joint.inverseBindPose = m.rawData;
                _ibm.push(m);
            }

            _skeleton.joints.push(joint);
        }
    }

    function buildClip(anim:Dynamic, index:Int):SkeletonClipNode 
    {
        var channels:Array<Dynamic> = anim.channels;
        var samplers:Array<Dynamic> = anim.samplers;

        var jointT = new Map<Int, GLTFSampler>();
        var jointR = new Map<Int, GLTFSampler>();
        var minT = Math.POSITIVE_INFINITY;
        var maxT = Math.NEGATIVE_INFINITY;

        for (ch in channels) 
        {
            var target = ch.target;

            if (target.node == null || !_jointNodeToIndex.exists(Std.int(target.node))) 
                continue;

            var ji = _jointNodeToIndex.get(Std.int(target.node));
            var sampler = readSampler(samplers[Std.int(ch.sampler)]);
            
            if (sampler.times.length > 0) 
            {
                minT = Math.min(minT, sampler.times[0]);
                maxT = Math.max(maxT, sampler.times[sampler.times.length - 1]);
            }

            if (target.path == "translation") 
                jointT.set(ji, sampler);
            else if (target.path == "rotation") 
                jointR.set(ji, sampler);
        }

        if (!Math.isFinite(minT)) 
            return null;

        var duration = maxT - minT;
        var numFrames = Math.round(duration * RESAMPLE_FPS);
        
        if (numFrames < 1) 
            numFrames = 1;
        
        var frameDurMs = Std.int(duration * 1000 / numFrames);

        var clip = new SkeletonClipNode();
        var nodes = getArray("nodes");

        for (k in 0...numFrames) 
        {
            var t = minT + (numFrames == 1 ? 0.0 : (k / numFrames) * duration);
            var pose = new SkeletonPose();
            pose.jointPoses = new Vector<JointPose>();

            for (ji in 0..._skeleton.joints.length) 
            {
                var nodeDef = nodes[_jointNodes[ji]];
                
                var tr = jointT.exists(ji) ? GLTFNodeAnimator.eval(jointT.get(ji), 3, false, t) : (nodeDef.translation != null ? cast nodeDef.translation : [0.0, 0.0, 0.0]);
                var ro = jointR.exists(ji) ? GLTFNodeAnimator.eval(jointR.get(ji), 4, true, t) : (nodeDef.rotation != null ? cast nodeDef.rotation : [0.0, 0.0, 0.0, 1.0]);

                var jp = new JointPose();
                jp.translation = new Vector3D(tr[0], tr[1], -tr[2]); 
                jp.orientation = new Quaternion(-ro[0], -ro[1], ro[2], ro[3]);
                pose.jointPoses.push(jp);
            }

            clip.addFrame(pose, frameDurMs);
        }

        clip.name = anim.name != null ? anim.name : 'clip_$index';
        clip.looping = true;
        return clip;
    }

    function buildPrimitive(prim:Dynamic, skinIndex:Int, nodeIndex:Int, root:ObjectContainer3D):Void 
    {
        var attrs = prim.attributes;
        
        if (attrs == null || !Reflect.hasField(attrs, "POSITION")) 
            return;

        var positions = readFloats(Std.int(attrs.POSITION));
        var normals = Reflect.hasField(attrs, "NORMAL") ? readFloats(Std.int(attrs.NORMAL)) : null;
        var uvs = Reflect.hasField(attrs, "TEXCOORD_0") ? readFloats(Std.int(attrs.TEXCOORD_0)) : null;
        var vertCount = Std.int(positions.length / 3);
        
        var isSkinned = (skinIndex == _activeSkinIndex && Reflect.hasField(attrs, "JOINTS_0") && Reflect.hasField(attrs, "WEIGHTS_0"));
        var subGeom:ISubGeometry;

        if (isSkinned) 
        {
            var joints = readFloats(Std.int(attrs.JOINTS_0));
            var weights = readFloats(Std.int(attrs.WEIGHTS_0));
            var skinnedSub = new SkinnedSubGeometry(4);
            
            var jIndices = new Vector<Float>();
            var jWeights = new Vector<Float>();

            for (i in 0...(vertCount * 4)) 
            {
                jIndices.push(joints[i]);
                jWeights.push(weights[i]);
            }
            
            skinnedSub.updateJointIndexData(jIndices);
            skinnedSub.updateJointWeightsData(jWeights);
            subGeom = skinnedSub;
        } 
        else 
        {
            subGeom = new SubGeometry();
        }

        var verts = new Vector<Float>();
        var normVec = normals != null ? new Vector<Float>() : null;
        
        for (i in 0...vertCount) 
        {
            verts.push(positions[i * 3]);
            verts.push(positions[i * 3 + 1]);
            verts.push(-positions[i * 3 + 2]); 

            if (normVec != null) 
            {
                normVec.push(normals[i * 3]);
                normVec.push(normals[i * 3 + 1]);
                normVec.push(-normals[i * 3 + 2]);
            }
        }

        var uvVec = uvs != null ? Vector.ofArray(uvs) : null;
        
        var indices:Array<Int> = Reflect.hasField(prim, "indices") ? readInts(Std.int(prim.indices)) : [for (i in 0...vertCount) i];
        var idxVec = new Vector<UInt>();

        for (t in 0...Std.int(indices.length / 3)) 
        {
            idxVec.push(indices[t * 3]);
            idxVec.push(indices[t * 3 + 2]);
            idxVec.push(indices[t * 3 + 1]);
        }

        subGeom.updateVertexData(verts);
        subGeom.updateIndexData(idxVec);
        
        if (normVec != null) 
            subGeom.updateVertexNormalData(normVec); 
        else 
            subGeom.autoDeriveVertexNormals = true;

        if (uvVec != null) 
            subGeom.updateUVData(uvVec); 
        else 
            subGeom.autoDeriveVertexTangents = true;
        
        var geom = new Geometry();
        geom.addSubGeometry(subGeom);

        var material = resolveMaterial(Reflect.hasField(prim, "material") ? Std.int(prim.material) : -1);
        var mesh = new Mesh(geom, material);
        
        if (isSkinned && _skeletonAnimator != null) 
        {
            mesh.animator = _skeletonAnimator;

            _outSkinnedMeshes.push(mesh);
            root.addChild(mesh); 
        } 
        else 
        {
            _nodeContainers[nodeIndex].addChild(mesh);
            _outMeshes.push(mesh);
        }
    }

    function getLocalMatrix(node:Dynamic):Matrix3D 
    {
        var m = new Matrix3D();
        
        if (node.matrix != null) 
        {
            m.copyRawDataFrom(Vector.ofArray(cast node.matrix));
            m.appendScale(1, 1, -1);
            m.prependScale(1, 1, -1);

            return m;
        }

        var t = node.translation != null ? cast node.translation : [0.0, 0.0, 0.0];
        var r = node.rotation != null ? cast node.rotation : [0.0, 0.0, 0.0, 1.0];
        var s = node.scale != null ? cast node.scale : [1.0, 1.0, 1.0];
        
        var q = new Quaternion(-r[0], -r[1], r[2], r[3]);
        m = q.toMatrix3D();
        m.prependScale(s[0], s[1], s[2]);
        m.appendTranslation(t[0], t[1], -t[2]);
        
        return m;
    }

    function buildNodeAnimator():GLTFNodeAnimator 
    {
        var animator = new GLTFNodeAnimator();
        var anims = getArray("animations");
        var nodes = getArray("nodes");
        
        for (i in 0...anims.length) 
        {
            var anim = anims[i];
            var byNode = new Map<Int, GLTFNodeTrack>();
            
            for (ch in (anim.channels : Array<Dynamic>)) 
            {
                if (ch.target.node == null) 
                    continue;
                
                var nodeIdx = Std.int(ch.target.node);

                if (nodeIdx < 0 || nodeIdx >= _nodeContainers.length) 
                    continue;
                
                var sampler = readSampler(anim.samplers[Std.int(ch.sampler)]);
                
                if (!byNode.exists(nodeIdx)) 
                {
                    var nDef = nodes[nodeIdx];
                    var base = [];

                    var bt = nDef.translation != null ? cast nDef.translation : [0.0, 0.0, 0.0];
                    var br = nDef.rotation != null ? cast nDef.rotation : [0.0, 0.0, 0.0, 1.0];
                    var bs = nDef.scale != null ? cast nDef.scale : [1.0, 1.0, 1.0];

                    base = base.concat(bt).concat(br).concat(bs);
                    
                    byNode.set(nodeIdx, 
                    {
                        container: _nodeContainers[nodeIdx], 
                        base: base, 
                        t: null, 
                        r: null, 
                        s: null
                    });
                }
                
                var track = byNode.get(nodeIdx);
                switch (ch.target.path) 
                {
                    case "translation": 
                        track.t = sampler;
                    case "rotation": 
                        track.r = sampler;
                    case "scale": 
                        track.s = sampler;
                }
            }
            
            var tracks = [for (t in byNode) t];
            if (tracks.length > 0) 
            {
                animator.addClip(
                {
                    name: anim.name != null ? anim.name : 'clip_$i',
                    startTime: 0,
                    duration: getClipDuration(anim),
                    tracks: tracks
                });
            }
        }
        return animator;
    }

    function getClipDuration(anim:Dynamic):Float 
    {
        var maxT = 0.0;

        for (s in (anim.samplers : Array<Dynamic>)) 
        {
            var times = readFloats(Std.int(s.input));

            if (times.length > 0 && times[times.length - 1] > maxT) 
                maxT = times[times.length - 1];
        }

        return maxT;
    }

    function readSampler(sampler:Dynamic):GLTFSampler 
    {
        return 
        {
            times: readFloats(Std.int(sampler.input)),
            values: readFloats(Std.int(sampler.output)),
            interp: sampler.interpolation != null ? sampler.interpolation : "LINEAR"
        };
    }

    function resolveMaterial(index:Int):MaterialBase 
    {
        if (index < 0) 
            return new ColorMaterial(0xcccccc);
        
        if (_materialCache.exists(index)) 
            return _materialCache.get(index);

        var materials = getArray("materials");

        if (index >= materials.length) 
            return new ColorMaterial(0xcccccc);

        var def = materials[index];
        var mat:MaterialBase = null;

        if (def.pbrMetallicRoughness != null) 
        {
            var pbr = def.pbrMetallicRoughness;

            if (pbr.baseColorTexture != null) 
            {
                var tex = loadTexture(Std.int(pbr.baseColorTexture.index));

                if (tex != null) 
                    mat = new TextureMaterial(tex);
            }
            
            if (mat == null) 
            {
                var color = 0xcccccc;

                if (pbr.baseColorFactor != null) 
                {
                    var f:Array<Float> = cast pbr.baseColorFactor;
                    color = (clamp8(f[0]) << 16) | (clamp8(f[1]) << 8) | clamp8(f[2]);
                }

                mat = new ColorMaterial(color);
            }
        } 
        else 
            mat = new ColorMaterial(0xcccccc);

        _materialCache.set(index, mat);
        return mat;
    }

    function loadTexture(index:Int):BitmapTexture 
    {
        var textures = getArray("textures");
        var images = getArray("images");
        var views = getArray("bufferViews");

        if (index < 0 || index >= textures.length || textures[index].source == null) 
            return null;
        
        var img = images[Std.int(textures[index].source)];

        if (img.bufferView == null) 
            return null;

        var view = views[Std.int(img.bufferView)];
        var offset = view.byteOffset != null ? Std.int(view.byteOffset) : 0;
        var length = Std.int(view.byteLength);

        var bmp = BitmapData.fromBytes(_bin.sub(offset, length));

        if (bmp == null) 
            return null;

        var pot = BitmapUtil.toPowerOfTwo(bmp);

        if (pot != bmp) 
            bmp.dispose();
        
        _outBitmaps.push(pot);
        return new BitmapTexture(pot);
    }

    function buildChildToParent():Void 
    {
        var nodes = getArray("nodes");

        for (i in 0...nodes.length) 
        {
            if (nodes[i].children != null) 
            {
                for (c in (nodes[i].children : Array<Dynamic>)) 
                    _childToParent.set(Std.int(c), i);
            }
        }
    }

    function findActiveSkin():Int 
    {
        var nodes = getArray("nodes");

        for (n in nodes) 
        {
            if (n.skin != null) 
                return Std.int(n.skin);
        }

        return getArray("skins").length > 0 ? 0 : -1;
    }

    function readFloats(accIndex:Int):Array<Float> 
    {
        var acc = getArray("accessors")[accIndex];

        if (acc.bufferView == null) 
            return [];

        var view = getArray("bufferViews")[Std.int(acc.bufferView)];
        var comps = numComponents(acc.type);
        var compType = Std.int(acc.componentType);
        var count = Std.int(acc.count);
        var compSize = componentSize(compType);
        
        var base = (view.byteOffset != null ? Std.int(view.byteOffset) : 0) + (acc.byteOffset != null ? Std.int(acc.byteOffset) : 0);
        var stride = view.byteStride != null ? Std.int(view.byteStride) : comps * compSize;
        var out = [];

        for (i in 0...count) 
        {
            var elem = base + i * stride;

            for (c in 0...comps) 
                out.push(readComponent(compType, elem + c * compSize));
        }
        return out;
    }

    function readInts(accIndex:Int):Array<Int> 
    {
        var acc = getArray("accessors")[accIndex];

        if (acc.bufferView == null) 
            return [];

        var view = getArray("bufferViews")[Std.int(acc.bufferView)];
        var compType = Std.int(acc.componentType);
        var compSize = componentSize(compType);
        var count = Std.int(acc.count);
        
        var base = (view.byteOffset != null ? Std.int(view.byteOffset) : 0) + (acc.byteOffset != null ? Std.int(acc.byteOffset) : 0);
        var stride = view.byteStride != null ? Std.int(view.byteStride) : compSize;
        var out = [];

        for (i in 0...count) 
            out.push(Std.int(readComponent(compType, base + i * stride)));

        return out;
    }

    inline function readComponent(type:Int, offset:Int):Float 
    {
        return switch (type) 
        {
            case CT_FLOAT: _bin.getFloat(offset);
            case CT_UBYTE: _bin.get(offset);

            case CT_BYTE: 
			{
				var v = _bin.get(offset); 
                (v < 128) ? v : v - 256;
			}
            case CT_USHORT: _bin.getUInt16(offset);

            case CT_SHORT: 
			{
				var v = _bin.getUInt16(offset); 
                (v < 32768) ? v : v - 65536;
			}

            case CT_UINT: _bin.getInt32(offset);
            default: 0;
        }
    }

    static inline function componentSize(type:Int):Int 
    {
        return (type == CT_BYTE || type == CT_UBYTE) ? 1 : (type == CT_SHORT || type == CT_USHORT) ? 2 : 4;
    }

    static inline function numComponents(type:String):Int 
    {
        return switch (type) 
        { 
            case "VEC2": 2; 
            case "VEC3": 3; 
            case "VEC4": 4; 
            case "MAT4": 16; 
            default: 1; 
        }
    }

    static inline function clamp8(v:Float):Int 
    {
        var i = Std.int(v * 255);
        return i < 0 ? 0 : (i > 255 ? 255 : i);
    }
    
    inline function getArray(name:String):Array<Dynamic> 
    {
        return Reflect.hasField(_json, name) ? cast Reflect.field(_json, name) : [];
    }
}