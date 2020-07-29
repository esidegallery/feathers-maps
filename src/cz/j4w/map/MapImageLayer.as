package cz.j4w.map
{
	import feathers.controls.ImageLoader;

	import starling.display.Sprite;

	public class MapImageLayer extends Sprite
	{
		protected var _options:MapImageLayerOptions;
		public function get options():MapImageLayerOptions 
		{
			return _options;
		}

		protected var _map:Map;
		protected var _id:String;
		protected var _imageLoader:ImageLoader;

		public function MapImageLayer(map:Map, id:String, options:MapImageLayerOptions)
		{
			_map = map;
			_id = id;
			_options = options || new MapImageLayerOptions;

			initialize();
		}

		protected function initialize():void
		{
			_imageLoader = new ImageLoader;
			_imageLoader.scaleContent = false;
			_imageLoader.source = _options.imageSource;
			addChild(_imageLoader);
		}
	}
}