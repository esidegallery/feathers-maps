package cz.j4w.map
{
	public class MapUtils
	{
		/** 
		 * Returns the maximum zoom value for the MapLayer. This is 1-based (1 being minimum zoom),
		 * so if using this to generate maps, subtract 1 for a 0-based value.
		 */
		public static function getMaxZoom(mapWidth:Number, mapHeight:Number, tileSize:int):int
		{
			var zoom:int = 1;
			var currentSize:int = Math.max(mapWidth, mapHeight);
			while (currentSize > tileSize)
			{
				currentSize *= 0.5;
				zoom++;
			}
			return zoom;
		}
	}
}