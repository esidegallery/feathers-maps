package cz.j4w.map 
{
	import cz.j4w.map.events.MapEventType;

	import feathers.core.FeathersControl;
	import feathers.utils.math.clamp;
	import feathers.utils.pixelsToInches;
	import feathers.utils.textures.TextureCache;
	import feathers.utils.touch.TapToEvent;

	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;

	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.display.Quad;
	import starling.display.Sprite;
	import starling.events.Event;
	import starling.events.Touch;
	import starling.events.TouchEvent;
	import starling.events.TouchPhase;
	import starling.extensions.starlingCallLater.callLater;
	import starling.extensions.starlingCallLater.clearCallLater;
	import starling.utils.Pool;
	
	public class Map extends FeathersControl 
	{
		protected static const MIN_DRAG_DISTANCE:Number = 0.04;
		
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
		
		public function get viewPort():Rectangle 
		{
			return _touchSheet.viewPort;
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
		 * Defaults to <code>MapLayer</code>. The class contructor needs to have the following signature:<br/>
		 * <code>MapLayer(map:Map, id:String, options:MapLayerOptions, buffer:MapTilesBuffer)</code> 
		 */
		public var layerFactoryClass:Class = MapLayer;
		/** 
		 * Defaults to <code>MapImageLayer</code>. The class contructor needs to have the following signature:<br/>
		 * <code>MapImageLayer(map:Map, id:String, options:MapImageLayerOptions)</code> 
		 */
		public var imageLayerFactoryClass:Class = MapImageLayer;
		/** 
		 * Defaults to <code>MapVideoLayer</code>. The class contructor needs to have the following signature:<br/>
		 * <code>MapVideoLayer(map:Map, id:String, options:MapVideoLayerOptions)</code> 
		 */
		public var videoLayerFactoryClass:Class = MapVideoLayer;
		
		protected static function markerCompareFunction(marker1:MapMarker, marker2:MapMarker):Number
		{
			if (marker1.alwaysOnTop && !marker2.alwaysOnTop)
			{
				return 1;
			}
			if (!marker1.alwaysOnTop && marker2.alwaysOnTop)
			{
				return -1;
			}
			
			if (marker1.scaleWithMap)
			{
				if (marker2.scaleWithMap) // Compare y's:
				{
					return marker1.displayObject.y - marker2.displayObject.y;
				}
				else // marker 2 will be higher: 
				{
					return -1;
				}
			}
			
			if (marker2.scaleWithMap)
			{
				return 1;
			}
			else
			{
				return marker1.displayObject.y - marker2.displayObject.y;
			}
		}
		
		public function Map(mapOptions:MapOptions)
		{
			this.mapOptions = mapOptions;
			
			layers = new Dictionary;
			circles = new Dictionary;
			markers = new Dictionary;
			
			mapTilesBuffer = new MapTilesBuffer;
			
			mapContainer = new Sprite;
			markersContainer = new Sprite;
			circlesContainer = new Sprite;
			mapContainer.addChild(circlesContainer);
			mapContainer.addChild(markersContainer);
			
			_touchSheet = new TouchSheet(mapContainer, null, mapOptions);
			addChild(_touchSheet);
		}
		
		override protected function initialize():void 
		{
			var maskQuad:Quad = new Quad(1, 1);
			addChild(maskQuad);
			mask = maskQuad;
			
			super.initialize();

			_touchSheet.addEventListener(Event.CHANGE, function():void
			{
				update();
			});
			
			addEventListener(TouchEvent.TOUCH, touchHandler);
			stage.starling.nativeStage.addEventListener(MouseEvent.MOUSE_WHEEL, onNativeStageMouseWheel);
		}
		
		override protected function draw():void 
		{
			if (isInvalid(INVALIDATION_FLAG_LAYOUT) || isInvalid(INVALIDATION_FLAG_SIZE))
			{
				_touchSheet.invalidateBounds();
			}

			super.draw();
			
			if (!isCreated)
			{
				if (mapOptions.initialScale)
				{
					_touchSheet.scale = mapOptions.initialScale || 1;
				}
				if (mapOptions.initialCenter)
				{
					_touchSheet.setCenter(mapOptions.initialCenter);
				}
			}
		}
		
		protected function update():void
		{
			if (!actualWidth || !actualHeight)
			{
				return;
			}
			
			if (mask != null)
			{
				mask.x = 0;
				mask.y = 0;
				mask.width = actualWidth;
				mask.height = actualHeight;
				
				if (_touchSheet.width > 0 && _touchSheet.height > 0)
				{
					mask.getBounds(_touchSheet, _touchSheet.viewPort);
				}
			}
			_touchSheet.invalidateBounds();
			
			updateZoomAndScale();
			updateMarkersAndCircles();
			for (var id:String in layers) 
			{
				var layer:IUpdatableMapLayer = getLayer(id) as IUpdatableMapLayer;
				if (layer != null && !layer.suspendUpdates)
				{
					layer.update();
				}
			}
		}
		
		protected function updateMarkersAndCircles():void 
		{
			var staticScale:Number = 1 / _touchSheet.scaleX;
			
			for each (var marker:MapMarker in getAllMarkers())
			{
				if (marker.displayObject)
				{
					if (!marker.scaleWithMap)
					{
						marker.displayObject.scale = staticScale;
					}
				}
			}
			
			for (var i:int = 0, n:int = circlesContainer.numChildren; i < n; i++)
			{
				var circle:DisplayObject = circlesContainer.getChildAt(i);
				circle.visible = _touchSheet.viewPort.intersects(circle.bounds);
			}
		}
		
		public function addLayer(id:String, options:MapLayerOptions = null):DisplayObject 
		{
			var layer:MapLayer = layers[id] as MapLayer;
			
			if (layer == null && options != null)
			{
				var childIndex:uint = options.index >= 0 ? Math.min(options.index, mapContainer.numChildren) : mapContainer.numChildren;
				
				layer = new layerFactoryClass(this, id, options, mapTilesBuffer) as MapLayer;
				if (layer == null)
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

		public function addImageLayer(id:String, options:MapImageLayerOptions):DisplayObject
		{
			var layer:MapImageLayer = layers[id] as MapImageLayer;

			if (layer == null && options != null)
			{
				var childIndex:uint = options.index >= 0 ? Math.min(options.index, mapContainer.numChildren) : mapContainer.numChildren;

				layer = new imageLayerFactoryClass(this, id, options) as MapImageLayer;
				if (layer == null)
				{
					throw new Error("imageLayerFactoryClass is invalid");
				}
				
				mapContainer.addChildAt(layer, childIndex);			
				mapContainer.addChild(circlesContainer); // Circles above layers.
				mapContainer.addChild(markersContainer); // Markers above circles.
				
				layers[id] = layer;
				invalidate(INVALIDATION_FLAG_LAYOUT);
			}

			return layer;
		}

		public function addVideoLayer(id:String, options:MapVideoLayerOptions):DisplayObject
		{
			var layer:MapVideoLayer = layers[id] as MapVideoLayer;

			if (layer == null && options != null)
			{
				var childIndex:uint = options.index >= 0 ? Math.min(options.index, mapContainer.numChildren) : mapContainer.numChildren;

				layer = new videoLayerFactoryClass(this, id, options) as MapVideoLayer;
				if (layer == null)
				{
					throw new Error("videoLayerFactoryClass is invalid");
				}

				mapContainer.addChildAt(layer, childIndex);			
				mapContainer.addChild(circlesContainer); // Circles above layers.
				mapContainer.addChild(markersContainer); // Markers above circles.
				
				layers[id] = layer;
				invalidate(INVALIDATION_FLAG_LAYOUT);
				
				layer.addEventListener(Event.READY, function():void
				{
					invalidate(INVALIDATION_FLAG_LAYOUT);
				});
			}

			return layer;
		}
		
		public function removeLayer(id:String):DisplayObject
		{
			var layer:DisplayObject = layers[id] as DisplayObject;
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
			return layers[id] != null;
		}
		
		public function getLayer(id:String):DisplayObject
		{
			return layers[id] as DisplayObject;
		}
		
		public function addMarker(id:String, x:Number, y:Number, displayObject:DisplayObject, data:Object = null, scaleWithMap:Boolean = false):MapMarker
		{
			if (!id || displayObject == null)
			{
				return null;
			}
			
			// Can't have markers with the same ID: 
			removeMarker(id, true);
			
			var newMarker:MapMarker = new MapMarker(id, displayObject, data, scaleWithMap);
			markers[id] = newMarker;
			
			displayObject.name = id;
			displayObject.x = x;
			displayObject.y = y;
			
			new TapToEvent(displayObject, MapEventType.MARKER_TRIGGERED);
			displayObject.addEventListener(MapEventType.MARKER_TRIGGERED, markerTriggeredHandler);
			
			markersContainer.addChild(displayObject);
			sortMarkers();
			invalidate(INVALIDATION_FLAG_LAYOUT);
			
			return newMarker;
		}
		
		public function getMarker(id:String):MapMarker
		{
			return markers[id] as MapMarker;
		}
		
		public function hasMarker(id:String):Boolean
		{
			return markers[id];
		}
		
		public function getAllMarkers():Vector.<MapMarker>
		{
			var allMarkers:Vector.<MapMarker> = new Vector.<MapMarker>;
			for (var id:Object in markers)
			{
				var marker:MapMarker = markers[id] as MapMarker;
				marker && allMarkers.push(marker);
			}
			return allMarkers;
		}
		
		public function removeMarker(id:String, dispose:Boolean = false):MapMarker 
		{
			var mapMarker:MapMarker = getMarker(id);
			
			if (mapMarker)
			{
				var displayObject:DisplayObject = mapMarker.displayObject;
				if (displayObject)
				{
					displayObject.removeEventListener(MapEventType.MARKER_TRIGGERED, markerTriggeredHandler);
					displayObject.removeFromParent(dispose);
				}
				delete markers[id];
				invalidate(INVALIDATION_FLAG_LAYOUT);
			}
			
			return mapMarker;
		}
		
		public function removeAllMarkers(dispose:Boolean = false):void 
		{
			for (var id:String in markers)
			{
				removeMarker(id, dispose);
			}
		}
		
		public function sortMarkers():void
		{
			var markers:Vector.<MapMarker> = getAllMarkers();
			markers.sort(markerCompareFunction);
			for (var i:int = 0, l:int = markers.length; i < l; i++)
			{
				markersContainer.addChildAt(markers[i].displayObject, i);
			}
		}
		
		public function addCircleOverlay(id:String, x:Number, y:Number, displayObject:DisplayObject, data:Object = null):MapCircleOverlay
		{
			displayObject.name = id;
			displayObject.x = x;
			displayObject.y = y;
			
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
			_touchSheet && _touchSheet.tweenTo(centerX, centerY, scale, duration, transition);
		}
		
		override public function dispose():void
		{
			clearCallLater(dispatchEventWith);
			mapTilesBuffer.dispose();
			Starling.current.nativeStage.removeEventListener(MouseEvent.MOUSE_WHEEL, onNativeStageMouseWheel);
			
			super.dispose();
		}
		
		//*************************************************************//
		//********************  Event Listeners  **********************//
		//*************************************************************//
		
		private var touchPointID:int = -1;
		private var dragDistance:Number = 0;
		
		private function touchHandler(event:TouchEvent):void
		{
			if (!isEnabled || stage == null)
			{
				touchPointID = -1;
				return;
			}
			
			if (touchPointID >= 0)
			{
				var touch:Touch = event.getTouch(this, null, touchPointID);
				
				if (!touch)
				{
					return;
				}
				
				if (touch.phase == TouchPhase.MOVED)
				{
					var point:Point = Pool.getPoint(touch.globalX, touch.globalY);
					var prevPoint:Point = Pool.getPoint(touch.previousGlobalX, touch.previousGlobalY);
					dragDistance += Math.abs(prevPoint.subtract(point).length);
					Pool.putPoint(point);
					Pool.putPoint(prevPoint);
				}
				else if (touch.phase == TouchPhase.ENDED)
				{
					touchPointID = -1;
				}
			}
			else 
			{
				touch = event.getTouch(this, TouchPhase.BEGAN);
				
				if (!touch)
				{
					return;
				}
				
				touchPointID = touch.id;
				dragDistance = 0;
			}
		}
		
		private function markerTriggeredHandler(event:Event):void
		{
			var displayObject:DisplayObject = event.currentTarget as DisplayObject;
			if (!displayObject)
			{
				return;
			}
			if (displayObject is FeathersControl && !(displayObject as FeathersControl).isEnabled)
			{
				return;
			}
			var marker:MapMarker = getMarker(displayObject.name);
			if (!marker)
			{
				return;
			}
			if (Math.abs(_touchSheet.velocity.length) < TouchSheet.MINIMUM_VELOCITY && pixelsToInches(dragDistance) < MIN_DRAG_DISTANCE)
			{
				callLater(dispatchEventWith, [MapEventType.MARKER_TRIGGERED, false, marker]);
			}
		}
		
		protected function onNativeStageMouseWheel(event:MouseEvent):void 
		{
			if (isCreated && isEnabled && _touchSheet && !_touchSheet.disableZooming)
			{
				var loc:Point = Pool.getPoint(event.stageX, event.stageY);
				var hitTest:DisplayObject = root.hitTest(loc);
				
				if (_touchSheet == hitTest || _touchSheet.contains(hitTest))
				{
					_touchSheet.globalToLocal(loc, loc);
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
