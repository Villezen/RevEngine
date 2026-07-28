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

/**
 * Everything a glTF model containts: its 3D object, meshes, textures and animations.
 * 
 * HUGE props to Khronos glTF registry i couldn't figure any of this without it 
 * https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html
 * 
 */
typedef GLTFModel =
{
    /**
     * The root 3D object holding the whole model.
     */
    var object:ObjectContainer3D;

    /**
     * Every mesh in the model.
     */
    var meshes:Array<Mesh>;

    /**
     * Just the meshes that follow the skeleton.
     */
    var skinnedMeshes:Array<Mesh>;

    /**
     * Every texture bitmap, kept so they can be freed later.
     */
    var bitmaps:Array<BitmapData>;

    /**
     * The bone skeleton, or null if there isn't one.
     */
    var skeleton:Skeleton;

    /**
     * The set of skeleton animations, or null if there aren't any.
     */
    var animationSet:SkeletonAnimationSet;

    /**
     * The names of the skeleton animations.
     */
    var animationNames:Array<String>;

    /**
     * The animator for models that move nodes around instead of bones.
     */
    var nodeAnimator:GLTFNodeAnimator;
}

/**
 * A group of meshes that share a material, merged so they draw as one.
 */
typedef GLTFBatch =
{
    /**
     * The merged geometry all the pieces get added to.
     */
    var geom:Geometry;

    /**
     * The current chunk's vertex positions, three numbers each.
     */
    var verts:Vector<Float>;

    /**
     * The current chunk's normals, three numbers each.
     */
    var normals:Vector<Float>;

    /**
     * The current chunk's texture coordinates, two numbers each.
     */
    var uvs:Vector<Float>;

    /**
     * The current chunk's triangle indices.
     */
    var indices:Vector<UInt>;

    /**
     * How many vertices are in the current chunk.
     */
    var count:Int;

    /**
     * Whether every piece in the chunk so far had normals.
     */
    var hasNormals:Bool;

    /**
     * Whether any piece in the chunk had texture coordinates.
     */
    var hasUvs:Bool;

    /**
     * How many finished chunks this batch has made.
     */
    var subs:Int;
}

class GLTFParser 
{
    /**
     * The glTF component type IDs.
     */
    private static inline var CT_BYTE = 5120;
    private static inline var CT_UBYTE = 5121;
    private static inline var CT_SHORT = 5122;
    private static inline var CT_USHORT = 5123;
    private static inline var CT_UINT = 5125;
    private static inline var CT_FLOAT = 5126;

    /**
     * The glTF texture wrap modes, telling the engine whether a texture tiles or clamps at its edges.
     */
    private static inline var WRAP_CLAMP = 33071;
    private static inline var WRAP_REPEAT = 10497;

    /**
     * The framerate skeleton animations get resampled to.
     */
    private static inline var RESAMPLE_FPS = 30.0;

    /**
     * How many vertices a merged chunk can hold before it gets split.
     */
    private static inline var CHUNK_LIMIT = 60000;

    /**
     * The most vertices a model can load before the rest is skipped.
     */
    private static inline var MAX_VERTS = 2500000;

    /**
     * The parsed json part of the glTF.
     */
    private var _json:Dynamic;

    /**
     * The raw binary part of the glTF, holding all the vertex and image data.
     */
    private var _bin:Bytes;

    /**
     * The glTF accessors, cached so the engine doesn't look them up over and over.
     */
    private var _accessors:Array<Dynamic>;

    /**
     * The glTF buffer views, cached the same way.
     */
    private var _bufferViews:Array<Dynamic>;

    /**
     * The glTF nodes, cached the same way.
     */
    private var _nodes:Array<Dynamic>;

    /**
     * The glTF mesh definitions, cached the same way.
     */
    private var _meshesDef:Array<Dynamic>;

    /**
     * One container per node, in the same order as the glTF nodes.
     */
    private var _nodeContainers:Array<ObjectContainer3D> = [];

    /**
     * Maps a node to its parent node.
     */
    private var _childToParent:Map<Int, Int> = new Map();

    /**
     * The merged geometry so far, one batch per material.
     */
    private var _batches:Map<Int, GLTFBatch> = new Map();

    /**
     * Every node that an animation moves directly.
     */
    private var _animatedNodes:Map<Int, Bool> = new Map();

    /**
     * How many vertices the engine has loaded so far, checked against the cap.
     */
    private var _totalVerts:Int = 0;

    /**
     * Whether the engine has already warned about the model being too big, so it only says it once.
     */
    private var _warned:Bool = false;

    /**
     * A spare vector the engine reuses so it doesn't make a new one per vertex.
     */
    private var _v1:Vector3D = new Vector3D();

    /**
     * A second spare vector, reused again by the engine.
     */
    private var _v2:Vector3D = new Vector3D();

    /**
     * The finished bone skeleton, or null if the model has none.
     */
    private var _skeleton:Skeleton;

    /**
     * The animator that plays skeleton clips.
     */
    private var _skeletonAnimator:SkeletonAnimator;

    /**
     * The skin the model uses, or -1 if there isn't one.
     */
    private var _activeSkinIndex:Int = -1;

    /**
     * The node index behind each bone, in bone order.
     */
    private var _jointNodes:Array<Int> = [];

    /**
     * The reverse of _jointNodes, a node index back to its bone slot.
     */
    private var _jointNodeToIndex:Map<Int, Int> = new Map();

    /**
     * Each bone's inverse bind matrix, its rest pose.
     */
    private var _ibm:Array<Matrix3D> = [];

    /**
     * Every mesh the engine made, handed back in the model.
     */
    private var _outMeshes:Array<Mesh> = [];

    /**
     * Just the skinned meshes, so the caller can attach the animator to them.
     */
    private var _outSkinnedMeshes:Array<Mesh> = [];

    /**
     * Every texture bitmap the engine made, kept so they can be freed later.
     */
    private var _outBitmaps:Array<BitmapData> = [];

    /**
     * Materials the engine has already built, determined by their index.
     */
    private var _materialCache:Map<Int, MaterialBase> = new Map();

    /**
     * Makes an empty parser. Use parseGLB instead of calling this.
     */
    private function new() {}

    /**
     * Reads a binary glTF (.glb) file and turns it into a model, or null if it isn't valid.
     */
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

    /**
     * Reads the whole glTF and builds the finished model from it.
     */
    private function build(json:Dynamic, bin:Bytes):GLTFModel 
    {
        _json = json;
        _bin = bin;

        _accessors = getArray("accessors");
        _bufferViews = getArray("bufferViews");
        _nodes = getArray("nodes");
        _meshesDef = getArray("meshes");

        buildChildToParent();
        buildAnimatedNodes();
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

        var nodes = _nodes;
        for (i in 0...nodes.length)
        {
            var node = nodes[i];

            if (node.mesh == null)
                continue;

            var skinIndex = Reflect.hasField(node, "skin") ? Std.int(node.skin) : -1;
            var meshDef = _meshesDef[Std.int(node.mesh)];

            if (meshDef.primitives == null)
                continue;

            var moves = isAnimated(i);

            for (prim in (meshDef.primitives : Array<Dynamic>))
            {
                if (moves || isSkinned(prim, skinIndex))
                    buildPrimitive(prim, skinIndex, i, root);
                else
                    mergePrimitive(prim, i);
            }
        }

        buildBatches(root);

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

    /**
     * Makes a container for every node and links them into their parent and child tree.
     */
    private function buildNodeContainers(root:ObjectContainer3D):Void 
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

    /**
     * Builds the bone skeleton from a skin, including each bone's rest pose.
     */
    private function buildSkeleton(skin:Dynamic):Void 
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

    /**
     * Turns one glTF animation into a finished skeleton clip by reading it at a steady framerate.
     */
    private function buildClip(anim:Dynamic, index:Int):SkeletonClipNode 
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

    /**
     * Builds a single moving or skinned primitive into its own mesh under its node.
     */
    private function buildPrimitive(prim:Dynamic, skinIndex:Int, nodeIndex:Int, root:ObjectContainer3D):Void 
    {
        var attrs = prim.attributes;
        
        if (attrs == null || !Reflect.hasField(attrs, "POSITION")) 
            return;

        var positions = readFloats(Std.int(attrs.POSITION));
        var normals = Reflect.hasField(attrs, "NORMAL") ? readFloats(Std.int(attrs.NORMAL)) : null;
        var uvs = Reflect.hasField(attrs, "TEXCOORD_0") ? readFloats(Std.int(attrs.TEXCOORD_0)) : null;
        var vertCount = Std.int(positions.length / 3);

        if (!canAdd(vertCount))
            return;

        var skinned = (skinIndex == _activeSkinIndex && Reflect.hasField(attrs, "JOINTS_0") && Reflect.hasField(attrs, "WEIGHTS_0"));
        var boundJoint = -1;

        if (skinned)
        {
            var joints = readFloats(Std.int(attrs.JOINTS_0));
            var weights = readFloats(Std.int(attrs.WEIGHTS_0));
            boundJoint = dominantJoint(joints, weights, vertCount);
        }

        var subGeom = new SubGeometry();

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

        if (boundJoint >= 0 && boundJoint < _jointNodes.length && boundJoint < _ibm.length)
        {
            mesh.transform = _ibm[boundJoint].clone();
            _nodeContainers[_jointNodes[boundJoint]].addChild(mesh);
        }
        else
            _nodeContainers[nodeIndex].addChild(mesh);

        _outMeshes.push(mesh);
    }

    /**
     * Marks every node that an animation moves directly.
     */
    private function buildAnimatedNodes():Void
    {
        for (anim in getArray("animations"))
        {
            if (anim.channels == null)
                continue;

            for (ch in (anim.channels : Array<Dynamic>))
            {
                if (ch.target != null && ch.target.node != null)
                    _animatedNodes.set(Std.int(ch.target.node), true);
            }
        }
    }

    /**
     * Whether a node moves, either itself or through an animated parent above it.
     */
    private function isAnimated(node:Int):Bool
    {
        var n = node;
        var guard = 0;

        while (n >= 0 && guard++ < 100000)
        {
            if (_animatedNodes.exists(n))
                return true;

            n = _childToParent.exists(n) ? _childToParent.get(n) : -1;
        }

        return false;
    }

    /**
     * Whether a primitive is tied to the skeleton and follows its bones.
     */
    private inline function isSkinned(prim:Dynamic, skin:Int):Bool
    {
        return _activeSkinIndex >= 0 && skin == _activeSkinIndex && prim.attributes != null
            && Reflect.hasField(prim.attributes, "JOINTS_0") && Reflect.hasField(prim.attributes, "WEIGHTS_0");
    }

    /**
     * Adds to the vertex total, or returns false once the model gets too big.
     */
    private function canAdd(count:Int):Bool
    {
        if (_totalVerts + count > MAX_VERTS)
        {
            if (!_warned)
            {
                _warned = true;
                trace('Model has too many vertices, skipping the rest.', "WARNING");
            }

            return false;
        }

        _totalVerts += count;
        return true;
    }

    /**
     * Gets the batch for a material, making a new empty one the first time.
     */
    private function getBatch(mat:Int):GLTFBatch
    {
        if (_batches.exists(mat))
            return _batches.get(mat);

        var batch:GLTFBatch =
        {
            geom: new Geometry(),
            verts: new Vector<Float>(),
            normals: new Vector<Float>(),
            uvs: new Vector<Float>(),
            indices: new Vector<UInt>(),
            count: 0,
            hasNormals: true,
            hasUvs: false,
            subs: 0
        };

        _batches.set(mat, batch);
        return batch;
    }

    /**
     * Puts a non moving primitive in its final place and adds it to its material's batch.
     */
    private function mergePrimitive(prim:Dynamic, node:Int):Void
    {
        var attrs = prim.attributes;

        if (attrs == null || !Reflect.hasField(attrs, "POSITION"))
            return;

        var positions = readFloats(Std.int(attrs.POSITION));
        var vertCount = Std.int(positions.length / 3);

        if (vertCount == 0)
            return;

        if (!canAdd(vertCount))
            return;

        var normals = Reflect.hasField(attrs, "NORMAL") ? readFloats(Std.int(attrs.NORMAL)) : null;
        var uvs = Reflect.hasField(attrs, "TEXCOORD_0") ? readFloats(Std.int(attrs.TEXCOORD_0)) : null;
        var indices:Array<Int> = Reflect.hasField(prim, "indices") ? readInts(Std.int(prim.indices)) : [for (i in 0...vertCount) i];

        var mat = Reflect.hasField(prim, "material") ? Std.int(prim.material) : -1;
        var batch = getBatch(mat);

        if (batch.count > 0 && (vertCount > CHUNK_LIMIT || batch.count + vertCount > CHUNK_LIMIT))
            flushBatch(batch);

        var world = _nodeContainers[node].sceneTransform.clone();
        var nmat = world.clone();
        var ok = nmat.invert();

        if (ok)
            nmat.transpose();

        var flip = world.determinant < 0;
        var base = batch.count;

        for (i in 0...vertCount)
        {
            _v1.x = positions[i * 3];
            _v1.y = positions[i * 3 + 1];
            _v1.z = -positions[i * 3 + 2];
            world.transformVectorToOutput(_v1, _v2);

            batch.verts.push(_v2.x);
            batch.verts.push(_v2.y);
            batch.verts.push(_v2.z);

            if (normals != null)
            {
                _v1.x = normals[i * 3];
                _v1.y = normals[i * 3 + 1];
                _v1.z = -normals[i * 3 + 2];

                if (ok)
                    nmat.deltaTransformVectorToOutput(_v1, _v2);
                else
                {
                    _v2.x = _v1.x;
                    _v2.y = _v1.y;
                    _v2.z = _v1.z;
                }

                var len = Math.sqrt(_v2.x * _v2.x + _v2.y * _v2.y + _v2.z * _v2.z);

                if (len > 0)
                {
                    batch.normals.push(_v2.x / len);
                    batch.normals.push(_v2.y / len);
                    batch.normals.push(_v2.z / len);
                }
                else
                {
                    batch.normals.push(0);
                    batch.normals.push(0);
                    batch.normals.push(0);
                }
            }
            else
            {
                batch.normals.push(0);
                batch.normals.push(0);
                batch.normals.push(0);
                batch.hasNormals = false;
            }

            if (uvs != null)
            {
                batch.uvs.push(uvs[i * 2]);
                batch.uvs.push(uvs[i * 2 + 1]);
                batch.hasUvs = true;
            }
            else
            {
                batch.uvs.push(0);
                batch.uvs.push(0);
            }
        }

        var tris = Std.int(indices.length / 3);

        for (t in 0...tris)
        {
            var a = base + indices[t * 3];
            var b = base + indices[t * 3 + 1];
            var c = base + indices[t * 3 + 2];

            if (flip)
            {
                batch.indices.push(a);
                batch.indices.push(b);
                batch.indices.push(c);
            }
            else
            {
                batch.indices.push(a);
                batch.indices.push(c);
                batch.indices.push(b);
            }
        }

        batch.count += vertCount;
    }

    /**
     * Turns the batch's current chunk into a SubGeometry and starts a new one.
     */
    private function flushBatch(batch:GLTFBatch):Void
    {
        if (batch.count == 0)
            return;

        var sub = new SubGeometry();
        sub.updateVertexData(batch.verts);
        sub.updateIndexData(batch.indices);

        if (batch.hasNormals)
            sub.updateVertexNormalData(batch.normals);
        else
            sub.autoDeriveVertexNormals = true;

        if (batch.hasUvs)
            sub.updateUVData(batch.uvs);
        else
            sub.autoDeriveVertexTangents = true;

        batch.geom.addSubGeometry(sub);
        batch.subs++;

        batch.verts = new Vector<Float>();
        batch.normals = new Vector<Float>();
        batch.uvs = new Vector<Float>();
        batch.indices = new Vector<UInt>();
        batch.count = 0;
        batch.hasNormals = true;
        batch.hasUvs = false;
    }

    /**
     * Makes one mesh per material from the finished batches and adds them to the model.
     */
    private function buildBatches(root:ObjectContainer3D):Void
    {
        for (mat in _batches.keys())
        {
            var batch = _batches.get(mat);
            flushBatch(batch);

            if (batch.subs == 0)
                continue;

            var mesh = new Mesh(batch.geom, resolveMaterial(mat));
            root.addChild(mesh);
            _outMeshes.push(mesh);
        }
    }

    /**
     * Finds the bone with the most weight on a primitive, so the whole piece can follow that one bone.
     */
    private function dominantJoint(joints:Array<Float>, weights:Array<Float>, vertCount:Int):Int
    {
        var totals = new Map<Int, Float>();

        for (i in 0...vertCount)
        {
            for (k in 0...4)
            {
                var w = weights[i * 4 + k];

                if (w <= 0)
                    continue;

                var j = Std.int(joints[i * 4 + k]);
                totals.set(j, (totals.exists(j) ? totals.get(j) : 0.0) + w);
            }
        }

        var best = -1;
        var bestWeight = -1.0;

        for (j => w in totals)
        {
            if (w > bestWeight)
            {
                bestWeight = w;
                best = j;
            }
        }

        return best;
    }

    /**
     * Reads a node's own transform and converts it from glTF space into away3d space.
     */
    private function getLocalMatrix(node:Dynamic):Matrix3D 
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

    /**
     * Builds the animator that moves whole nodes around, used when there's no skeleton.
     */
    private function buildNodeAnimator():GLTFNodeAnimator 
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

    /**
     * Finds how long an animation runs, in seconds.
     */
    private function getClipDuration(anim:Dynamic):Float 
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

    /**
     * Reads an animation sampler, its keyframe times, values and how it blends between them.
     */
    private function readSampler(sampler:Dynamic):GLTFSampler 
    {
        return 
        {
            times: readFloats(Std.int(sampler.input)),
            values: readFloats(Std.int(sampler.output)),
            interp: sampler.interpolation != null ? sampler.interpolation : "LINEAR"
        };
    }

    /**
     * Gets the material for an index, building it once and reusing it after that.
     */
    private function resolveMaterial(index:Int):MaterialBase 
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
                var texIndex = Std.int(pbr.baseColorTexture.index);
                var tex = loadTexture(texIndex);

                if (tex != null)
                {
                    var texMat = new TextureMaterial(tex);
                    texMat.repeat = textureRepeats(texIndex);

                    mat = texMat;
                }
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

    /**
     * Whether a texture tiles instead of clamping at its edges.
     */
    private function textureRepeats(index:Int):Bool
    {
        var textures = getArray("textures");

        if (index < 0 || index >= textures.length || textures[index].sampler == null)
            return true;

        var samplers = getArray("samplers");
        var slot = Std.int(textures[index].sampler);

        if (slot < 0 || slot >= samplers.length)
            return true;

        var sampler = samplers[slot];

        var s = sampler.wrapS != null ? Std.int(sampler.wrapS) : WRAP_REPEAT;
        var t = sampler.wrapT != null ? Std.int(sampler.wrapT) : WRAP_REPEAT;

        return s != WRAP_CLAMP || t != WRAP_CLAMP;
    }

    /**
     * Loads a texture image out of the binary buffer and sizes it to a power of two.
     */
    private function loadTexture(index:Int):BitmapTexture 
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

    /**
     * Records each node's parent so the engine can look it up later.
     */
    private function buildChildToParent():Void 
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

    /**
     * Finds the skin the model actually uses, or -1 if it has none.
     */
    private function findActiveSkin():Int 
    {
        var nodes = getArray("nodes");

        for (n in nodes) 
        {
            if (n.skin != null) 
                return Std.int(n.skin);
        }

        return getArray("skins").length > 0 ? 0 : -1;
    }

    /**
     * Reads an accessor out of the binary buffer as a flat list of floats.
     */
    private function readFloats(accIndex:Int):Array<Float>
    {
        var acc = _accessors[accIndex];

        if (acc.bufferView == null)
            return [];

        var view = _bufferViews[Std.int(acc.bufferView)];
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

    /**
     * Reads an accessor out of the binary buffer as a flat list of ints, used for indices.
     */
    private function readInts(accIndex:Int):Array<Int>
    {
        var acc = _accessors[accIndex];

        if (acc.bufferView == null)
            return [];

        var view = _bufferViews[Std.int(acc.bufferView)];
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

    /**
     * Reads one number from the binary buffer, matching how glTF stored it.
     */
    private inline function readComponent(type:Int, offset:Int):Float 
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

    /**
     * How many bytes one number of the given type takes.
     */
    private static inline function componentSize(type:Int):Int 
    {
        return (type == CT_BYTE || type == CT_UBYTE) ? 1 : (type == CT_SHORT || type == CT_USHORT) ? 2 : 4;
    }

    /**
     * How many numbers make up one value of the given type, so a VEC3 is 3.
     */
    private static inline function numComponents(type:String):Int 
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

    /**
     * Turns a 0 to 1 colour value into a 0 to 255 byte, keeping it in range.
     */
    private static inline function clamp8(v:Float):Int 
    {
        var i = Std.int(v * 255);
        return i < 0 ? 0 : (i > 255 ? 255 : i);
    }
    
    /**
     * Gets a top array from the json by name, or an empty one if it's missing.
     */
    private inline function getArray(name:String):Array<Dynamic> 
    {
        return Reflect.hasField(_json, name) ? cast Reflect.field(_json, name) : [];
    }
}