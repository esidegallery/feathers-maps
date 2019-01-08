package cz.j4w.map 
{
	/**
	 * ...
	 * @author Jakub Wagner, J4W
	 */
	public class MapLayerOptions 
	{
		public var loadInitialTilesInstantly:Boolean;
		public var prioritiseTileLoading:Boolean;
		public var blendMode:String;
		public var index:int = -1;
		public var maximumZoom:int;
		/** If >= 0, only tiles up to this zoom level will be shown, and kept visible beyond it. */
		public var limitZoom:int = -1;
		public var notUsedZoomThreshold:int;
		/** 
		 * Tiles are created only if they intersect with the viewport bounds.
		 * This value adds a margin to those bounds so that tiles are loaded earlier.
		 */
		public var tileCreationMargin:int;
		public var tileSize:int;
		public var urlTemplate:String;
	}

}