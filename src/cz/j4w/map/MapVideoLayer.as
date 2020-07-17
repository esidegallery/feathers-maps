package cz.j4w.map
{
	import feathers.media.VideoPlayer;

	import starling.display.Image;
	import starling.display.Sprite;
	import starling.events.Event;
	import starling.textures.RenderTexture;
	import starling.textures.Texture;

	public class MapVideoLayer extends Sprite
	{
		protected var _options:MapVideoLayerOptions;
		public function get options():MapVideoLayerOptions 
		{
			return _options;
		}

		protected var _map:Map;
		protected var _id:String;
		protected var _videoPlayer:VideoPlayer;
		protected var _videoDisplay:Image;
		protected var _renderTexture:RenderTexture;

		public function MapVideoLayer(map:Map, id:String, options:MapVideoLayerOptions)
		{
			_map = map;
			_id = id;
			_options = options;

			_videoPlayer = new VideoPlayer;
			_videoPlayer.autoPlay = true;
			_videoPlayer.videoSource = options.videoSource;
			
			_videoDisplay = new Image(null);
			_videoPlayer.addChild(_videoDisplay);

			_videoPlayer.addEventListener(Event.READY, videoPlayer_readyHandler);
			_videoPlayer.addEventListener(Event.COMPLETE, videoPlayer_completeHandler);

			addChild(_videoPlayer);
		}

		private function videoPlayer_readyHandler(event:Event):void
		{
			_videoDisplay.texture = _videoPlayer.texture;
			_videoDisplay.readjustSize();
			if (_renderTexture !== null)
			{
				_renderTexture.dispose();
			}
			_renderTexture = new RenderTexture(_videoDisplay.width, _videoDisplay.height);
		}

		private function videoPlayer_completeHandler(event:Event):void
		{
			_renderTexture.clear();
			_renderTexture.draw(_videoDisplay);
			replayVideo(_renderTexture);
		}

		private function replayVideo(fillTexture:Texture = null):void
		{
			_videoDisplay.texture = fillTexture;
			_videoPlayer.play();
		}
	}
}