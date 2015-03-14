package cz.j4w.map {
	import com.imageworks.debug.Debugger;
	import feathers.core.FeathersControl;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import starling.animation.Transitions;
	import starling.animation.Tween;
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.display.Sprite;
	import starling.events.EnterFrameEvent;
	import starling.events.Touch;
	import starling.events.TouchEvent;
	import starling.events.TouchPhase;
	
	/**
	 * Main Starling class. Provides demo Feathers UI for map controll.
	 */
	public class Map extends FeathersControl {
		private var currentTween:Tween;
		protected var mapOptions:MapOptions;
		
		protected var mapContainer:Sprite;
		protected var markersContainer:Sprite;
		protected var touchSheet:TouchSheet;
		
		protected var layers:Array;
		protected var mapViewPort:Rectangle;
		
		public function Map(mapOptions:MapOptions) {
			this.mapOptions = mapOptions;
		}
		
		override protected function initialize():void {
			layers = [];
			
			mapViewPort = new Rectangle();
			mapContainer = new Sprite();
			markersContainer = new Sprite();
			touchSheet = new TouchSheet(mapContainer, viewPort, mapOptions);
			addChild(touchSheet);
			mapContainer.addChild(markersContainer);
			
			touchSheet.scaleX = touchSheet.scaleY = mapOptions.initialScale || 1;
			
			if (mapOptions.initialCenter)
				setCenter(mapOptions.initialCenter);
			
			addEventListener(EnterFrameEvent.ENTER_FRAME, onEnterFrame);
			addEventListener(TouchEvent.TOUCH, onTouch);
			Starling.current.nativeStage.addEventListener(MouseEvent.MOUSE_WHEEL, onNativeStageMouseWheel);
		}
		
		override public function dispose():void {
			super.dispose();
			Starling.current.nativeStage.removeEventListener(MouseEvent.MOUSE_WHEEL, onNativeStageMouseWheel);
		}
		
		override protected function draw():void {
			clipRect = bounds.clone();
			update();
		}
		
		private function update():void {
			getBounds(touchSheet, mapViewPort); // calculate mapViewPort before bounds check
			touchSheet.applyBounds();
			getBounds(touchSheet, mapViewPort); // calculate mapViewPort after bounds check
			updateMarkers();
		}
		
		private function updateMarkers():void {
			var n:int = markersContainer.numChildren;
			var sx:Number = 1 / touchSheet.scaleX;
			for (var i:int = 0; i < n; i++) {
				var marker:DisplayObject = markersContainer.getChildAt(i); // scaling markers always to be 1:1
				marker.scaleX = marker.scaleY = sx;
				marker.visible = mapViewPort.intersects(marker.bounds);
			}
		}
		
		public function addLayer(id:String, options:Object = null):MapLayer {
			if (layers[id]) {
				Debugger.log("Layer", id, "already added.")
				return layers[id];
			}
			
			if (!options)
				options = {};
			
			var childIndex:uint = options.index >= 0 ? options.index : mapContainer.numChildren;
			
			var layer:MapLayer = new MapLayer(this, id, options);
			mapContainer.addChildAt(layer, childIndex);
			mapContainer.addChild(markersContainer); // markers are always on top
			
			layers[id] = layer;
			
			return layer;
		}
		
		public function removeLayer(id:String):void {
			if (layers[id]) {
				var layer:MapLayer = layers[id] as MapLayer;
				layer.removeFromParent(true);
				layers[id] = null;
				delete layers[id];
			}
		}
		
		public function removeAllLayers():void {
			for (var layerId:String in layers) {
				removeLayer(layerId);
			}
		}
		
		public function addMarker(id:String, x:Number, y:Number, displayObject:DisplayObject):void {
			displayObject.name = id;
			displayObject.x = x;
			displayObject.y = y;
			markersContainer.addChild(displayObject);
		}
		
		public function removeMarker(id:String):DisplayObject {
			var marker:DisplayObject = markersContainer.getChildByName(id);
			marker.removeFromParent();
			return marker;
		}
		
		public function removeAllMarkers():void {
			while (markersContainer.numChildren) {
				var marker:DisplayObject = markersContainer.getChildAt(0);
				removeMarker(marker.name);
			}
		}
		
		public function get viewPort():Rectangle {
			return mapViewPort;
		}
		
		public function get zoom():int {
			var s:uint = scale;
			var z:int = 1;
			while (s > 1) {
				s >>= 1;
				++z;
			}
			return z;
		}
		
		public function get scale():int {
			var scale:uint = 1;
			var z:int = int(1 / touchSheet.scaleX);
			while (scale < z) {
				scale <<= 1;
			}
			return scale;
		}
		
		public function setCenter(point:Point):void {
			setCenterXY(point.x, point.y);
		}
		
		public function getCenter():Point {
			return new Point(mapViewPort.x + mapViewPort.width / 2, mapViewPort.y + mapViewPort.height / 2);
		}
		
		public function setCenterXY(x:Number, y:Number):void {
			update();
			touchSheet.pivotX = x;
			touchSheet.pivotY = y;
			touchSheet.x = width / 2;
			touchSheet.y = height / 2;
			update();
		}
		
		public function tweenTo(x:Number, y:Number, scale:Number = 1, time:Number = 3):Tween {
			cancelTween();
			
			var center:Point = getCenter();
			
			var tweenObject:Object = {x: center.x, y: center.y, scale: touchSheet.scaleX};
			currentTween = Starling.juggler.tween(tweenObject, time, {x: x, y: y, scale: scale, onComplete: tweenComplete, onUpdate: tweenUpdate, onUpdateArgs: [tweenObject], transition: Transitions.EASE_IN_OUT}) as Tween;
			
			return currentTween;
		}
		
		public function cancelTween():void {
			if (currentTween) {
				Starling.juggler.remove(currentTween);
				currentTween = null;
			}
		}
		
		public function isTweening():Boolean {
			return currentTween != null;
		}
		
		private function tweenUpdate(tweenObject:Object):void {
			touchSheet.scaleX = touchSheet.scaleY = tweenObject.scale;
			setCenterXY(tweenObject.x, tweenObject.y);
		}
		
		private function tweenComplete():void {
			Starling.juggler.remove(currentTween);
			currentTween = null;
		}
		
		//*************************************************************//
		//********************  Event Listeners  **********************//
		//*************************************************************//
		
		private function onEnterFrame(e:EnterFrameEvent):void {
			update();
		}
		
		private function onTouch(e:TouchEvent):void {
			var touch:Touch = e.getTouch(this, TouchPhase.MOVED);
			if (touch)
				cancelTween();
		}
		
		private function onNativeStageMouseWheel(e:MouseEvent):void {
			var point:Point = globalToLocal(new Point(Starling.current.nativeStage.mouseX, Starling.current.nativeStage.mouseY));
			
			if (bounds.containsPoint(point)) {
				point.x -= width / 2;
				point.y -= height / 2;
				
				var center:Point = getCenter();
				center.x += point.x / touchSheet.scaleX;
				center.y += point.y / touchSheet.scaleY;
				
				var newScale:Number = touchSheet.scaleX / (e.delta > 0 ? 0.5 : 2);
				newScale = Math.max(mapOptions.minimumScale, newScale);
				newScale = Math.min(mapOptions.maximumScale, newScale);
				tweenTo(center.x, center.y, newScale, .3);
			}
		}
	
	}
}