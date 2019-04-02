package cz.j4w.map 
{
	import starling.display.DisplayObject;
	
	/**
	 * MapMarker
	 * @author Jakub Wagner, J4W
	 */
	public class MapMarker 
	{
		private var _id:String;
		public function get id():String 
		{
			return _id;
		}
		
		private var _data:Object;
		public function get data():Object 
		{
			return _data;
		}
		
		private var _displayObject:DisplayObject;
		public function get displayObject():DisplayObject 
		{
			return _displayObject;
		}
		
		public var scaleWithMap:Boolean;
		
		/** Set this, followed by <code>Map.sortMarkers</code> to make the marker aways appear on top. */
		public var alwaysOnTop:Boolean;
		
		public function MapMarker(id:String, displayObject:DisplayObject, data:Object, scaleWithMap:Boolean = false, alwaysOnTop:Boolean = false) 
		{
			_id = id;
			_displayObject = displayObject;
			_data = data;
			this.scaleWithMap = scaleWithMap;
			this.alwaysOnTop = alwaysOnTop;
		}
	}
}