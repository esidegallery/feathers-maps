package cz.j4w.map
{
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;
	
	import feathers.controls.ImageLoader;
	import feathers.utils.textures.TextureCache;
	
	import starling.display.BlendMode;
	import starling.display.Sprite;
	import starling.events.Event;
	
	/**
	 * ...
	 * @author Jakub Wagner, J4W
	 */
	public class MapLayer extends Sprite 
	{
		protected var _options:MapLayerOptions;
		public function get options():MapLayerOptions 
		{
			return _options;
		}
		
		protected var mapTilesBuffer:MapTilesBuffer;
		protected var map:Map;
		protected var id:String;
		protected var urlTemplate:String;
		protected var tilesDictionary:Dictionary = new Dictionary(true);
		protected var tileSize:int;
		protected var limitZoom:int;
		protected var notUsedZoomThreshold:int;
		protected var tileCreationMargin:int;
		protected var firstLoad:Boolean = true;
		
		/** Required to calculate the ${z} portion of the URL from the map zoom level. */ 
		protected var maximumZoom:int;
		
		public var textureCache:TextureCache;
		
		public var debugTrace:Boolean = false;
		
		protected var pendingReadyTiles:Vector.<ImageLoader> = new Vector.<ImageLoader>;
		
		public function MapLayer(map:Map, id:String, options:MapLayerOptions, buffer:MapTilesBuffer)
		{
			super();
			this._options = options;
			this.id = id;
			this.map = map;
			mapTilesBuffer = buffer;
			
			urlTemplate = _options.urlTemplate;
			if (!urlTemplate) 
			{
				throw new Error("urlTemplate option is required");
			}
			notUsedZoomThreshold = _options.notUsedZoomThreshold || 0;
			tileCreationMargin = _options.tileCreationMargin || 0;
			blendMode = _options.blendMode || BlendMode.NORMAL;
			tileSize = _options.tileSize || 256;
			maximumZoom = _options.maximumZoom || Map.MAX_ZOOM;
			limitZoom = _options.limitZoom;
		}
		
		/**
		 * Check tiles and create new ones if needed.
		 */
		protected function checkTiles(mapViewport:Rectangle, zoom:int, scale:int):void
		{
			var actualTileSize:Number = tileSize * scale;
			
			var startX:int = Math.floor(mapViewport.left / actualTileSize);
			var endX:int = Math.ceil(mapViewport.right / actualTileSize);
			var startY:int = Math.floor(mapViewport.top / actualTileSize);
			var endY:int = Math.ceil(mapViewport.bottom / actualTileSize);
			
			var tilesCreated:int = 0;
			for (var i:int = startX; i < endX; i += 1) 
			{
				for (var j:int = startY; j < endY; j += 1) 
				{
					if (createTile(i, j, actualTileSize, zoom, scale))
					{
						tilesCreated++;
					}
				}
			}
			if (debugTrace && tilesCreated)
			{
				trace("Created", tilesCreated, "tiles.")
			}
		}
		
		/**
		 * Check tiles visibility and removes those not visible.
		 */
		protected function checkNotUsedTiles(mapViewPort:Rectangle, zoom:int):void
		{
			var tilesCount:int = 0;
			var tilesRemoved:int = 0;
			for each (var tile:MapTile in tilesDictionary)
			{
				tilesCount++;
				// its outside viewport or its not current zoom
				if (!mapViewPort.intersects(tile.bounds) || Math.abs(zoom - tile.zoom) > notUsedZoomThreshold) 
				{
					removeTile(tile);
					tilesRemoved++;
				}
			}
			if (debugTrace && tilesRemoved)
			{
				trace("Removed", tilesRemoved, "tiles.")
			}
		}
		
		protected function createTile(x:int, y:int, actualTileSize:Number, zoom:int, scale:int):Boolean 
		{
			var key:String = getKey(x, y, zoom);
			
			var tile:MapTile = tilesDictionary[key] as MapTile;
			if (tile)
			{
				addChild(tile);
				return false;
			}
			
			var url:String = urlTemplate.replace("${z}", maximumZoom - zoom).replace("${x}", x).replace("${y}", y);
			tile = mapTilesBuffer.create(x, y, zoom);
			addChild(tile);

			tile.loadInstantly ||= (_options.loadInitialTilesInstantly && firstLoad);
			tile.prioritiseBuffering = options.prioritiseTileLoading;
			if (pendingReadyTiles) 
			{
				pendingReadyTiles.push(tile);
				tile.addEventListener(Event.COMPLETE, tile_readyHandler);
				tile.addEventListener(Event.IO_ERROR, tile_readyHandler);
				tile.addEventListener(Event.SECURITY_ERROR, tile_readyHandler);
			}
			tile.textureCache = textureCache;
			tile.source = url;
			tile.setSize(tileSize, tileSize);
			tile.x = x * actualTileSize;
			tile.y = y * actualTileSize;
			tile.scaleX = tile.scaleY = scale;
			
			tilesDictionary[key] = tile;
			
			return true;
		}
		
		protected function tile_readyHandler(event:Event):void
		{
			removeTileFromPending(event.currentTarget as MapTile);
		}
		
		protected function removeTileFromPending(tile:MapTile):void
		{
			tile.removeEventListener(Event.COMPLETE, tile_readyHandler);
			tile.removeEventListener(Event.IO_ERROR, tile_readyHandler);
			tile.removeEventListener(Event.SECURITY_ERROR, tile_readyHandler);
			if (pendingReadyTiles)
			{
				var index:int = pendingReadyTiles.indexOf(tile);
				index >= 0 && pendingReadyTiles.removeAt(index);
			}
		}
		
		protected function removeTile(tile:MapTile):void 
		{
			mapTilesBuffer.release(tile);
			tile.removeFromParent();
			
			removeTileFromPending(tile);
			
			var key:String = getKey(tile.mapX, tile.mapY, tile.zoom);
			tilesDictionary[key] = null;
			delete tilesDictionary[key];
		}
		
		protected function checkIsReady():void
		{
			if (pendingReadyTiles && !pendingReadyTiles.length)
			{
				dispatchEventWith(Event.READY);
				pendingReadyTiles = null;
			}
		}
		
		protected function getKey(x:int, y:int, zoom:int):String 
		{
			return x + "x" + y + "x" + zoom;
		}
		
		public function update():void
		{
			var mapViewport:Rectangle = map.viewPort.clone();
			if (tileCreationMargin)
			{
				mapViewport.inflate(tileCreationMargin, tileCreationMargin);
			}
			var zoom:int = map.zoom;
			var scale:int = map.scaleRatio;
			while (limitZoom >= 0 && maximumZoom - zoom > limitZoom)
			{
				zoom++;
				scale <<= 1;
			}
			
			checkTiles(mapViewport, zoom, scale);
			checkNotUsedTiles(mapViewport, zoom);
			checkIsReady();
			firstLoad = false;
		}
	}
}