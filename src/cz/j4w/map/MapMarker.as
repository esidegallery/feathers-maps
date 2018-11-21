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
		
		/** Delegate property for <code>displayObject.x</code>. */ 
		public function get x():Number 
		{
			return displayObject.x;
		}
		public function set x(value:Number):void 
		{
			displayObject.x = value;
		}
		
		/** Delegate property for <code>displayObject.y</code>. */ 
		public function get y():Number 
		{
			return displayObject.y;
		}
		public function set y(value:Number):void 
		{
			displayObject.y = value;
		}
		
		public function MapMarker(id:String, displayObject:DisplayObject, data:Object) 
		{
			_id = id;
			_displayObject = displayObject;
			_data = data;
		}
	}
}