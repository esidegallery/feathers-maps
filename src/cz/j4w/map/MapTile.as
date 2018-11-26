package cz.j4w.map 
{
	import feathers.controls.ImageLoader;
	
	import starling.core.Starling;
	import starling.events.Event;
	
	/**
	 * ...
	 * @author Jakub Wagner, J4W
	 */
	public class MapTile extends ImageLoader 
	{
		protected static const INVALIDATION_FLAG_SOURCE:String = "source";

		protected var buffer:MapTilesBuffer;
		
		public var loadInstantly:Boolean;
		public var prioritiseBuffering:Boolean;
		public var delayedSource:Object;
		public var animateShow:Boolean;
		
		public var mapX:int;
		public var mapY:int;
		public var zoom:int;
		
		public function MapTile(mapX:int, mapY:int, zoom:int, buffer:MapTilesBuffer) 
		{
			super();
			
			this.mapX = mapX;
			this.mapY = mapY;
			this.zoom = zoom;
			this.buffer = buffer;
		}
		
		override protected function initialize():void
		{
			super.initialize();
			
			addEventListener(Event.COMPLETE, show);
		}
		
		protected function show():void
		{
			visible = true;
			if (animateShow && alpha < 1)
			{
				Starling.juggler.tween(this, 0.1, {
					alpha: 1,
					onComplete: dispatchReady
				});
			}
			else
			{
				alpha = 1;
				dispatchReady();
			}
		}
		
		protected function dispatchReady():void
		{
			dispatchEventWith(Event.READY);
		}
		
		override protected function layout():void
		{
			if (!this.image || !this._currentTexture)
			{
				return;
			}
			
			this.image.x = 0;
			this.image.y = 0;
			this.image.width = this.actualWidth;
			this.image.height = this.actualHeight;
		}
		
		override public function set source(value:Object):void
		{
			if (value && source == value)
			{
				animateShow = !_texture
				show();
				return;
			}
			
			if (loadInstantly)
			{
				super.source = value;
				return;
			}
			
			
			var cacheKey:String = sourceToTextureCacheKey(value);
			if (_textureCache && cacheKey && _textureCache.hasTexture(cacheKey))
			{
				animateShow = false;
				super.source = value;
				return;
			}
			
			if (!delayedSource) 
			{
				delayedSource = value;
				buffer.add(this, prioritiseBuffering);
				return;
			}
			
			animateShow = true;
			super.source = value;
		}
		
		public function get isDisposed():Boolean 
		{
			return _isDisposed;
		}
	}
}