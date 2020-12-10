package cz.j4w.map
{
	public class MapVideoLayerOptions
	{
		public var index:int = -1;
		public var videoSource:String;
		public var videoDisplayWidth:int;
		public var videoDisplayHeight:int;
		public var videoCodedHeight:int;
		/** A number between 0 and 1. */
		public var volume:Number = 1;
		/** Set to override the default of <code>VideoPlayer</code>. */
		public var videoPlayerFactory:Function;
	}
}