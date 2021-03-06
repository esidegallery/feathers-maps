package cz.j4w.map 
{
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	/**
	 * ...
	 * @author Jakub Wagner, J4W
	 */
	public class MapOptions 
	{
		public var disableMovement:Boolean;
		public var disableRotation:Boolean;
		public var disableZooming:Boolean;
		public var initialScale:Number;
		public var maximumScale:Number = 6;
		public var minimumScale:Number = 1 / Math.pow(2, 17);
		public var initialCenter:Point;
		public var movementBounds:Rectangle;
	}
}