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
		/** If >= 0, only tiles up to this zoom level will be shown. */
		public var limitZoom:int = -1;
		public var notUsedZoomThreshold:int;
		public var tileCreationMargin:int;
		public var tileSize:int;
		public var urlTemplate:String;
	}

}