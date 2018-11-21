package cz.j4w.map 
{
	import flash.utils.clearInterval;
	import flash.utils.setInterval;

	/**
	 * MapTiles loading buffer and pool.
	 * @author Jakub Wagner, J4W
	 */
	public class MapTilesBuffer 
	{
		protected var pool:Vector.<MapTile> = new Vector.<MapTile>;
		protected var currentlyBuffering:Vector.<MapTile> = new Vector.<MapTile>;
		
		protected var intervalID:uint;
		
		public function MapTilesBuffer() 
		{
			intervalID = setInterval(checkCurrentlyCommiting, 1000 / 60);
		}
		
		public function create(mapX:int, mapY:int, zoom:int):MapTile
		{
			var mapTile:MapTile = pool.pop();
			
			if (!mapTile) 
			{
				mapTile = new MapTile(mapX, mapY, zoom, this);
			}
			else 
			{
				mapTile.mapX = mapX;
				mapTile.mapY = mapY;
				mapTile.zoom = zoom;
			}
			mapTile.visible = false;
			mapTile.alpha = 0;
			
			return mapTile;
		}
		
		public function add(mapTile:MapTile, prioritise:Boolean = false):void
		{
			if (currentlyBuffering.indexOf(mapTile) < 0)
			{
				if (prioritise)
				{
					currentlyBuffering.unshift(mapTile);
				}
				else
				{
					currentlyBuffering.push(mapTile);
				}
			}
		}
		
		public function release(mapTile:MapTile):void 
		{
			if (mapTile.source)
			{
				mapTile.source = null;
			}
			mapTile.loadInstantly = false;
			mapTile.delayedSource = null;
			mapTile.visible = false;
			pool.push(mapTile);
		}
		
		protected function checkCurrentlyCommiting():void
		{
			while (currentlyBuffering.length)
			{
				var mapTile:MapTile = currentlyBuffering.shift();
				if (mapTile.isDisposed || !mapTile.delayedSource) 
				{
					continue;
				}
				mapTile.source = mapTile.delayedSource;
				return;
			}
		}
		
		public function dispose():void 
		{
			for each (var tile:MapTile in pool) 
			{
				tile.isDisposed || tile.dispose();
			}
			for each (tile in currentlyBuffering)
			{
				tile.isDisposed || tile.dispose();
			}
			clearInterval(intervalID);
			pool.length = 0;
			currentlyBuffering.length = 0;
		}
	}
}