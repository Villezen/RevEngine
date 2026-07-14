	package backend.display;

	import backend.utils.MemoryUtil;
	import backend.display.FPS;
	import openfl.text.TextField;
	import openfl.text.TextFormat;

	/**
	 * An OpenFL text object used for displaying the current memory usage being used.
	 * This displays the in-game memory usage, and the memory usage shown in the Task Manager.
	 */
	class MEM extends TextField {
		/**
		 * The current tracked memory, in bytes.
		 */
		var mem:Float = 0;

		/**
		 * The highest tracked memory used, in bytes.
		 */
		var memPeak:Float = 0;

		/**
		 * The current width of this text object.
		 */
		public static var daWidth:Float = 0;

		/**
		 * Constant for converting Bytes To Megabytes.
		 */
		static final BYTES_PER_MEG:Float = 1024 * 1024;

		public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000, font:String = 'exo2.otf')
		{
			super();

			this.x = x;
			this.y = y + 2;
			this.width = 500;
			this.selectable = false;
			this.mouseEnabled = false;
			defaultTextFormat = new TextFormat('Monsterrat', 12, color);
			alpha = 0.8;
			text = "";

			#if flash
			addEventListener(Event.ENTER_FRAME, function(e) {
				var time = Lib.getTimer();
				__enterFrame(time - currentTime);
			});
			#end
		}

		/**
		 * Event Handlers
		 */
		@:noCompletion
		#if !flash override #end function __enterFrame(deltaTime:Float):Void
		{
			var gcMEM:Float = MemoryUtil.roundMemory(MemoryUtil.getGCMemory(), true, true);
			var taskMEM:Float = MemoryUtil.roundMemory(MemoryUtil.getTaskMemory(), true, true);

			text = (''
				// GC MEM
				+ 'GC: ${gcMEM} ${MemoryUtil.setMemoryUnitString(MemoryUtil.getGCMemory())}'
				// TASK MEM
				+ (MemoryUtil.supportsTaskMem() 
					? '  |  TASK: ${taskMEM} ${MemoryUtil.setMemoryUnitString((MemoryUtil.getTaskMemory()))}'
					: ''
				)
			);

			this.x = Std.int(FPS.daWidth + 20);
			daWidth = this.textWidth;
		}
	}