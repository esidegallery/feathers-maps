package cz.j4w.map
{
	public class MapUtils
	{
		public static function getMaxZoom(mapWidth:Number, mapHeight:Number, tileSize:int):int
		{
			var zoom:int = 0;
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