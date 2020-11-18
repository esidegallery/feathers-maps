package cz.j4w.map
{
	import feathers.media.VideoPlayer;

	import flash.media.SoundTransform;

	import starling.display.Image;
	import starling.display.Sprite;
	import starling.events.Event;
	import starling.textures.RenderTexture;

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
			_options = options || new MapVideoLayerOptions;

			if (options.videoPlayerFactory != null)
			{
				_videoPlayer = new options.videoPlayerFactory as VideoPlayer;
			}
			else
			{
				_videoPlayer = new VideoPlayer;
			}
			_videoPlayer.soundTransform = new SoundTransform(_options.volume);
			_videoPlayer.autoPlay = true;
			_videoPlayer.videoSource = _options.videoSource;
			
			_videoDisplay = new Image(null);
			_videoPlayer.addChild(_videoDisplay);

			_videoPlayer.addEventListener(Event.READY, videoPlayer_readyHandler);
			_videoPlayer.addEventListener(Event.COMPLETE, videoPlayer_completeHandler);

			addChild(_videoPlayer);
		}

		protected function videoPlayer_readyHandler(event:Event):void
		{
			_videoDisplay.texture = _videoPlayer.texture;
			_videoDisplay.readjustSize();
			disposeRenderTexture();
			_renderTexture = new RenderTexture(_videoDisplay.width, _videoDisplay.height);
		}

		protected function videoPlayer_completeHandler(event:Event):void
		{
			_renderTexture.clear();
			_renderTexture.draw(_videoDisplay);
			replayVideo();
		}

		protected function replayVideo():void
		{
			_videoDisplay.texture = _renderTexture;
			_videoPlayer.videoSource = null;
			_videoPlayer.videoSource = options.videoSource;
		}

		protected function disposeRenderTexture():void
		{
			if (_renderTexture == null)
			{
				return;
			}
			_renderTexture.dispose();
		}

		override public function dispose():void
		{
			disposeRenderTexture();
			super.dispose();
		}
	}
}