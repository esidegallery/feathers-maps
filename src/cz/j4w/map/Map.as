package cz.j4w.map 
{
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;
	
	import cz.j4w.map.events.MapEventType;
	
	import feathers.core.FeathersControl;
	import feathers.utils.math.clamp;
	import feathers.utils.textures.TextureCache;
	
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.display.Quad;
	import starling.display.Sprite;
	import starling.events.Event;
	import starling.events.Touch;
	import starling.events.TouchEvent;
	import starling.events.TouchPhase;
	import starling.utils.Pool;
	
	/**
	 * Main Starling class. Provides demo Feathers UI for map controll.
	 */
	public class Map extends FeathersControl 
	{
		public static const MIN_ZOOM:int = 1;
		public static const MAX_ZOOM:int = 20;
		
		protected var mapTilesBuffer:MapTilesBuffer;
		
		protected var mapOptions:MapOptions;
		protected var mapContainer:Sprite;
		protected var circlesContainer:Sprite;
		protected var markersContainer:Sprite;
		
		protected var _touchSheet:TouchSheet;
		public function get touchSheet():TouchSheet
		{
			return _touchSheet;
		}
		protected var layers:Dictionary;
		protected var circles:Dictionary;
		protected var markers:Dictionary;
		
		private var markerDisplays:Vector.<DisplayObject>;
		private var circleDisplays:Vector.<DisplayObject>;
		
		public function get viewPort():Rectangle 
		{
			return touchSheet.viewPort;
		}
		
		private var _zoom:int;
		public function get zoom():int 
		{
			return _zoom;
		}
		
		private var _scaleRatio:int;
		public function get scaleRatio():int 
		{
			return _scaleRatio;
		}
		
		public var textureCache:TextureCache;
		
		/** 
		 * Defaults to <code>MapLayer</code>. The class contructor needs to have the following signature:<br>
		 * <code>MapLayer(map:Map, id:String, options:MapLayerOptions, buffer:MapTilesBuffer)</code> 
		 */
		public var layerFactoryClass:Class = MapLayer;
		
		public function Map(mapOptions:MapOptions)
		{
			this.mapOptions = mapOptions;
			
			layers = new Dictionary;
			circles = new Dictionary;
			markers = new Dictionary;
			
			mapTilesBuffer = new MapTilesBuffer;
			markerDisplays = new Vector.<DisplayObject>;
			circleDisplays = new Vector.<DisplayObject>;
			
			mapContainer = new Sprite;
			markersContainer = new Sprite;
			circlesContainer = new Sprite;
			mapContainer.addChild(circlesContainer);
			mapContainer.addChild(markersContainer);
			
			_touchSheet = new TouchSheet(mapContainer, null, mapOptions);
			_touchSheet.scale = mapOptions.initialScale || 1;
			addChild(_touchSheet);
		}
		
		override protected function initialize():void 
		{
			super.initialize();
			
			var maskQuad:Quad = new Quad(1, 1);
			addChild(maskQuad);
			mask = maskQuad;
			
			_touchSheet.addEventListener(Event.CHANGE, function():void
			{
				update();
			});
			
			addEventListener(TouchEvent.TOUCH, onTouch);
			stage.starling.nativeStage.addEventListener(MouseEvent.MOUSE_WHEEL, onNativeStageMouseWheel);
		}
		
		override protected function draw():void 
		{
			super.draw();
			
			if (!isCreated)
			{
				if (mapOptions.initialCenter)
				{
					_touchSheet.setCenter(mapOptions.initialCenter);
				}
			}
			
			if (isInvalid(INVALIDATION_FLAG_LAYOUT) || isInvalid(INVALIDATION_FLAG_SIZE))
			{
				update();
			}
		}
		
		protected function update():void
		{
			if (!actualWidth || !actualHeight)
			{
				return;
			}
			
			mask.x = 0;
			mask.y = 0;
			mask.width = actualWidth;
			mask.height = actualHeight;
			
			mask.getBounds(_touchSheet, _touchSheet.viewPort);
			_touchSheet.invalidateBounds();
			
			updateMarkersAndCircles();
			updateZoomAndScale();
			for (var id:String in layers) 
			{
				getLayer(id).update();
			}
		}
		
		protected function updateMarkersAndCircles():void 
		{
			var sx:Number = 1 / _touchSheet.scaleX;
			
			for (var i:int = 0, n:int = markersContainer.numChildren; i < n; i++) 
			{
				var marker:DisplayObject = markersContainer.getChildAt(i); // scaling markers always to be 1:1
//				marker.pivotX = marker.width / 2;
//				marker.pivotY = marker.height / 2;
//				marker.scaleX = marker.scaleY = sx;
				marker.visible = _touchSheet.viewPort.intersects(marker.bounds);
			}
			
			for (i = 0, n = circlesContainer.numChildren; i < n; i++)
			{
				var circle:DisplayObject = circlesContainer.getChildAt(i);
				circle.visible = _touchSheet.viewPort.intersects(circle.bounds);
			}
		}
		
		public function addLayer(id:String, options:MapLayerOptions = null):MapLayer 
		{
			var layer:MapLayer = layers[id] as MapLayer;
			
			if (!layer)
			{
				options ||= new MapLayerOptions;
				
				var childIndex:uint = options.index >= 0 ? options.index : mapContainer.numChildren;
				
				layer = new layerFactoryClass(this, id, options, mapTilesBuffer) as MapLayer;
				if (!layer)
				{
					throw new Error("layerFactoryClass is invalid");
				}
				layer.textureCache = textureCache;
				
				mapContainer.addChildAt(layer, childIndex);			
				mapContainer.addChild(circlesContainer); // Circles above layers.
				mapContainer.addChild(markersContainer); // Markers above circles.
			
				layers[id] = layer;
				invalidate(INVALIDATION_FLAG_LAYOUT);
			}
			
			return layer;
		}

		public function removeLayer(id:String):MapLayer
		{
			var layer:MapLayer = layers[id] as MapLayer;
			if (layer) 
			{
				layer.removeFromParent(true);
				delete layers[id];
				invalidate(INVALIDATION_FLAG_LAYOUT);
			}
			return layer;
		}
		
		public function removeAllLayers():void 
		{
			for (var id:String in layers) 
			{
				removeLayer(id);
			}
		}
		
		public function hasLayer(id:String):Boolean
		{
			return layers[id];
		}
		
		public function getLayer(id:String):MapLayer
		{
			return layers[id];
		}
		
		public function addMarker(id:String, x:Number, y:Number, displayObject:DisplayObject, data:Object = null):MapMarker
		{
			displayObject.name = id;
			displayObject.x = x;
			displayObject.y = y;
			
			// Find the index to insertAt, based on y:
			var index:int = 0;
			for (var i:int = 0, l:int = markerDisplays.length; i < l; i++)
			{
				if (y > markerDisplays[i].y)
				{
					if (i == l-1) // If none are less than, insert last:
					{
						index = l;
					}
				}
				else
				{
					index = i; // Finally found 1 that it is less than, so use it:				
					break;
				}				
			}
			
			markerDisplays.insertAt(index, displayObject);
			markersContainer.addChildAt(displayObject, index);
			
			var mapMarker:MapMarker = new MapMarker(id, displayObject, data);
			markers[id] = mapMarker;
			invalidate(INVALIDATION_FLAG_LAYOUT);
			
			return mapMarker;
		}
		
		public function getMarker(id:String):MapMarker
		{
			return markers[id] as MapMarker;
		}
		
		public function getAllMarkers():Vector.<MapMarker>
		{
			var markers:Vector.<MapMarker> = new Vector.<MapMarker>;
			for (var key:Object in markers)
			{
				var marker:MapMarker = markers[key] as MapMarker;
				marker && markers.push(marker);
			}
			return markers;
		}
		
		public function removeMarker(id:String, dispose:Boolean = false):MapMarker 
		{
			var mapMarker:MapMarker = getMarker(id);
			
			if (mapMarker)
			{
				var displayObject:DisplayObject = mapMarker.displayObject;
				displayObject && displayObject.removeFromParent(dispose);
				delete markers[id];
				invalidate(INVALIDATION_FLAG_LAYOUT);
			}
			
			return mapMarker;
		}
		
		public function removeAllMarkers(dispose:Boolean = false):void 
		{
			markersContainer.removeChildren(0, -1, dispose);
			markers = new Dictionary();
			markerDisplays.length = 0;
			invalidate(INVALIDATION_FLAG_LAYOUT);
		}
		
		public function addCircleOverlay(id:String, x:Number, y:Number, displayObject:DisplayObject, data:Object = null):MapCircleOverlay
		{
			displayObject.name = id;
			displayObject.x = x;
			displayObject.y = y;
			
			circleDisplays.push(displayObject);
			circlesContainer.addChild(displayObject);
			
			var mapCircle:MapCircleOverlay = new MapCircleOverlay(id, displayObject, data);
			circles[id] = mapCircle;
			invalidate(INVALIDATION_FLAG_LAYOUT);
			
			return mapCircle;
		}
		
		public function getCircleOverlay(id:String):MapCircleOverlay 
		{
			return circles[id] as MapCircleOverlay;
		}
		
		public function removeCircleOverlay(id:String, dispose:Boolean = false):MapCircleOverlay 
		{
			var mapCircle:MapCircleOverlay = getCircleOverlay(id);
			
			if (mapCircle) 
			{
				var displayObject:DisplayObject = mapCircle.displayObject;
				displayObject && displayObject.removeFromParent(dispose);
				delete circles[id];
				invalidate(INVALIDATION_FLAG_LAYOUT);
			}
			
			return mapCircle;
		}
		
		public function removeAllCircleOverlays(dispose:Boolean = false):void
		{
			circlesContainer.removeChildren(0, -1, dispose);
			circles = new Dictionary();
			circleDisplays.length = 0;
			invalidate(INVALIDATION_FLAG_LAYOUT);
		}
		
		private function updateZoomAndScale():void 
		{
			_scaleRatio = 1;
			var z:int = int(1 / _touchSheet.scaleX);
			while (z >= _scaleRatio << 1)
			{
				_scaleRatio <<= 1;
			}
			
			var s:uint = _scaleRatio;
			_zoom = 1;
			while (s > 1) 
			{
				s >>= 1;
				++_zoom;
			}
		}
		
		private function sortMarkersFunction(d1:DisplayObject, d2:DisplayObject):int 
		{
			return d1.x > d2.x ? 1 : -1;
		}
		
		/** Converts the input zoom level to the equivalent scale value. */
		protected function getScale(zoomLevel:int):Number
		{
			var numScale:Number = 1;
			for (var i:int = 0, l:int = clamp(zoomLevel, MIN_ZOOM, MAX_ZOOM - 1); i < l; i++)
			{
				numScale *= 0.5;
			}
			return numScale;
		}
		
		public function getCenter():Point 
		{
			return _touchSheet ? _touchSheet.getViewCenter() : new Point;
		}
		
		public function zoomIn(center:Point = null):void
		{
			_touchSheet && _touchSheet.zoomIn(center);
		}
		
		public function zoomOut(center:Point = null):void
		{
			_touchSheet && _touchSheet.zoomOut(center);
		}
			
		public function zoomTo(level:int, time:Number = 0.3):void
		{
			var center:Point = getCenter();
			_touchSheet && _touchSheet.scaleTo(getScale(level), center.x, center.y, time);
		}
		
		public function setCenterXY(centerX:Number, centerY:Number):void
		{
			_touchSheet && _touchSheet.setCenterXY(centerX, centerY);
		}
		
		public function tweenTo(centerX:Number, centerY:Number, scale:Number, duration:Number = 1, transition:String = "easeInOut"):void
		{
			_touchSheet &_touchSheet.tweenTo(centerX, centerY, scale, transition);
		}
		
		override public function dispose():void
		{
			mapTilesBuffer.dispose();
			Starling.current.nativeStage.removeEventListener(MouseEvent.MOUSE_WHEEL, onNativeStageMouseWheel);
			
			super.dispose();
		}
		
		//*************************************************************//
		//********************  Event Listeners  **********************//
		//*************************************************************//
		
		private function onTouch(event:TouchEvent):void
		{
			var touch:Touch = event.getTouch(this, TouchPhase.MOVED);
			
			touch = event.getTouch(markersContainer, TouchPhase.ENDED);
			if (touch)
			{
				var displayObject:DisplayObject = touch.target;
				if (displayObject && displayObject.parent.parent == markersContainer)
				{
					var marker:MapMarker = getMarker(displayObject.parent.name);
					dispatchEventWith(MapEventType.MARKER_TRIGGERED, false, marker);
				}
			}
		}
		
		private function onNativeStageMouseWheel(event:MouseEvent):void 
		{
			if (isCreated && isEnabled && _touchSheet)
			{
				var loc:Point = Pool.getPoint(event.stageX, event.stageY);
				_touchSheet.globalToLocal(loc, loc);
				
				if (_touchSheet.hitTest(loc))
				{
					if (event.delta > 0)
					{
						zoomIn(loc);
					}
					else
					{
						zoomOut(loc);
					}
				}
				
				Pool.putPoint(loc);
			}
		}
	}
}
