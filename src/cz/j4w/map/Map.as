package cz.j4w.map {
	
	
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;
	
	import cz.j4w.map.events.MapEvent;
	
	import feathers.core.FeathersControl;
	import feathers.utils.textures.TextureCache;
	
	import starling.animation.Transitions;
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.display.Quad;
	import starling.display.Sprite;
	import starling.events.EnterFrameEvent;
	import starling.events.Touch;
	import starling.events.TouchEvent;
	import starling.events.TouchPhase;
	
	/**
	 * Main Starling class. Provides demo Feathers UI for map controll.
	 */
	public class Map extends FeathersControl {
		private var tweenTransition:Function = Transitions.getTransition(Transitions.EASE_IN_OUT);
		private var currentTween:uint;
		protected var mapTilesBuffer:MapTilesBuffer;
		
		protected var mapOptions:MapOptions;
		protected var _mapContainer:Sprite;
		protected var _circlesContainer:Sprite;
		protected var _markersContainer:Sprite;
		protected var _touchSheet:TouchSheet;
		public function get touchSheet():TouchSheet
		{
			return _touchSheet;
		}
		protected var _markers:Dictionary;
		protected var _circles:Dictionary;
		
		protected var layers:Array;
		protected var mapViewPort:Rectangle;
		protected var centerBackup:Point;
		
		private var _vecMarkerDisplays:Vector.<DisplayObject>;
		private var _vecCircleDisplays:Vector.<DisplayObject>;
		
		private var _scaleRatio:int;
		private var _zoom:int;
		private var _pntCenter:Point;
		
		public var textureCache:TextureCache;
		
		public function Map($mapOptions:MapOptions) {
			this.mapOptions = $mapOptions;
			
		}
		
		override protected function initialize():void {
			layers = [];
			this._vecMarkerDisplays = new Vector.<DisplayObject>();
			this._vecCircleDisplays = new Vector.<DisplayObject>();
			mapTilesBuffer = new MapTilesBuffer();
			_markers = new Dictionary();
			_circles = new Dictionary();
			centerBackup = new Point();
			this._pntCenter = new Point();
			mapViewPort = new Rectangle();
			this._mapContainer = new Sprite();
			this._markersContainer = new Sprite();
			this._circlesContainer = new Sprite();
			_touchSheet = new TouchSheet(this._mapContainer, viewPort, mapOptions);
			this.addChild(_touchSheet);
			this._mapContainer.addChild(this._circlesContainer);
			this._mapContainer.addChild(this._markersContainer);
			
			_touchSheet.scaleX = _touchSheet.scaleY = mapOptions.initialScale || 1;
			
			if (mapOptions.initialCenter)
				setCenter(mapOptions.initialCenter);
			
			
			addEventListener(EnterFrameEvent.ENTER_FRAME, onEnterFrame);
			addEventListener(TouchEvent.TOUCH, onTouch);
			Starling.current.nativeStage.addEventListener(MouseEvent.MOUSE_WHEEL, onNativeStageMouseWheel);
		}
		
		override public function dispose():void {
			super.dispose();
			mapTilesBuffer.dispose();
			Starling.current.nativeStage.removeEventListener(MouseEvent.MOUSE_WHEEL, onNativeStageMouseWheel);
		}
		
		override protected function draw():void {
			mask = new Quad(scaledActualWidth, scaledActualHeight);
			setCenter(centerBackup);
		}
		
		protected function update():void {
			getBounds(_touchSheet, mapViewPort); // calculate mapViewPort before bounds check
			_touchSheet.applyBounds();
			getBounds(_touchSheet, mapViewPort); // calculate mapViewPort after bounds check
			updateMarkersAndCircles();
			updateZoomAndScale();
		}
		
		protected function updateMarkersAndCircles():void {
			var n:int = _markersContainer.numChildren;
			var sx:Number = 1 / _touchSheet.scaleX;
			var i:int=0;
			var marker:DisplayObject;
			for (i = 0; i < n; i++) {
				marker = _markersContainer.getChildAt(i); // scaling markers always to be 1:1
				marker.scaleX = marker.scaleY = sx;
				marker.visible = mapViewPort.intersects(marker.bounds);
			}
			n = _circlesContainer.numChildren;
			var circle:DisplayObject;
			var numCalcSize:Number;
			var numCircleW:Number;
			var numCircleWMin:Number = 50;
			for (i=0; i<n; i++){
				numCircleW = 798;
				circle = _circlesContainer.getChildAt(i);
				numCalcSize = circle.width*_touchSheet.scaleX;
				
				
				circle.visible = mapViewPort.intersects(circle.bounds);
			}
			
		}
		
		public function addLayer($id:String, $options:Object = null):MapLayer {
			if (layers[$id]) {
				trace("Layer", $id, "already added.")
				return layers[$id];
			}
			
			if (!$options)
				$options = {};
			
			var childIndex:uint = $options.index >= 0 ? $options.index : _mapContainer.numChildren;
			
			var layer:MapLayer = new MapLayer(this, $id, $options, mapTilesBuffer);
			layer.textureCache = textureCache;
			this._mapContainer.addChildAt(layer, childIndex); //add layer			
			this._mapContainer.addChild(this._circlesContainer); //circles above layers
			this._mapContainer.addChild(this._markersContainer); //markers above circles
			
			layers[$id] = layer;
			
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
		
		public function hasLayer(id:String):Boolean {
			return layers[id];
		}
		
		public function getLayer(id:String):MapLayer {
			return layers[id];
		}
		
		
		public function addMarker($id:String, $x:Number, $y:Number, $displayObject:DisplayObject, $data:Object = null):MapMarker {
			$displayObject.name = $id;
			$displayObject.x = $x;
			$displayObject.y = $y;
			
			var numLen:int = this._vecMarkerDisplays.length;
			
			//find the index to insertAt, based on y
			var index:int = 0;
			for(var i:int=0; i<numLen; i++){
				if($y>this._vecMarkerDisplays[i].y){
					if(i==numLen-1){ //if none are less than, insert last
						index=numLen;
					}
				}else{
					index=i;//finally found 1 that it is less than, so use it				
					break;
				}				
			}
			
			this._vecMarkerDisplays.insertAt(index, $displayObject);
			
			
			this._markersContainer.addChildAt($displayObject,index);
			
			var mapMarker:MapMarker = this.createMarker($id, $displayObject, $data);
			_markers[$id] = mapMarker;
			return mapMarker;
		}
		
		public function addCircleOverlay($id:String, $x:Number, $y:Number, $displayObject:DisplayObject, $data:Object=null):MapCircleOverlay{
			
			
			$displayObject.name =$id;
			$displayObject.x = $x;
			$displayObject.y = $y;
			
			this._vecCircleDisplays.push($displayObject);
			
			this._circlesContainer.addChild($displayObject);
			
			var mapCircle:MapCircleOverlay = this.createCircleOverlay($id, $displayObject, $data);
			_circles[$id] = mapCircle;
			
			return mapCircle;
		}
		
		protected function createCircleOverlay($id:String, $displayObject:DisplayObject, $data:Object):MapCircleOverlay {
			return new MapCircleOverlay($id, $displayObject, $data);
		}
		
		protected function createMarker($id:String, $displayObject:DisplayObject, $data:Object):MapMarker {
			return new MapMarker($id, $displayObject, $data);
		}
		
		public function getMarker($id:String):MapMarker {
			return _markers[$id] as MapMarker;
		}
		public function getCircle($id:String):MapCircleOverlay {
			return _circles[$id] as MapCircleOverlay;
		}
		
		public function removeCircleOverlay($id:String):MapCircleOverlay {
			var mapCircle:MapCircleOverlay = _circles[$id] as MapCircleOverlay;
			
			if (mapCircle) {
				var displayObject:DisplayObject = mapCircle.displayObject;
				var index:int = this._vecCircleDisplays.indexOf(displayObject);
				this._vecCircleDisplays.removeAt(index);
				displayObject.removeFromParent();
				delete _circles[$id];
			}
			
			return mapCircle;
		}
		public function removeMarker($id:String):MapMarker {
			var mapMarker:MapMarker = _markers[$id] as MapMarker;
			
			if (mapMarker) {
				var displayObject:DisplayObject = mapMarker.displayObject;
				var index:int = this._vecMarkerDisplays.indexOf(displayObject);
				this._vecMarkerDisplays.removeAt(index);
				displayObject.removeFromParent();
				delete _markers[$id];
			}
			
			return mapMarker;
		}
		
		public function removeAllMarkers():void {
			_markersContainer.removeChildren();
			_markers = new Dictionary();
			this._vecMarkerDisplays.length=0;
		}
		
		public function removeAllCircles():void {
			_circlesContainer.removeChildren();
			_circles = new Dictionary();
			this._vecCircleDisplays.length=0;
		}
		
		public function get viewPort():Rectangle {
			return mapViewPort;
		}
		
		public function get zoom():int {
			return _zoom;
		}
		
		public function get scaleRatio():int {
			return _scaleRatio;
		}
		
		private function updateZoomAndScale():void {
			_scaleRatio = 1;
			var z:int = int(1 / _touchSheet.scaleX);
			while (_scaleRatio < z) {
				_scaleRatio <<= 1;
			}
			
			var s:uint = _scaleRatio;
			_zoom = 1;
			while (s > 1) {
				s >>= 1;
				++_zoom;
			}
		}
		
		public function setCenter($point:Point):void {
			setCenterXY($point.x, $point.y);
		}
		
		public function getCenter():Point {
			_pntCenter.x = mapViewPort.x + mapViewPort.width / 2;
			_pntCenter.y = mapViewPort.y + mapViewPort.height / 2;
			return _pntCenter;
		}
		
		public function setCenterXY($x:Number, $y:Number):void {
			update();
		
			centerBackup.setTo($x, $y);
			_touchSheet.pivotX = $x;
			_touchSheet.pivotY = $y;
			_touchSheet.x = this.width / 2;
			_touchSheet.y = this.height / 2;
			update();
		}
		
		public function tweenTo($x:Number, $y:Number, $scale:Number = 1, $time:Number = 3):uint {
			this.cancelTween();
			var center:Point = getCenter();
			var tweenObject:Object = {ratio: 0, x: center.x, y: center.y, scale: _touchSheet.scaleX};
			var tweenTo:Object = {ratio: 1, x: $x, y: $y, scale: $scale};
			this.currentTween = Starling.juggler.tween(tweenObject, $time, {ratio: 1, onComplete: tweenComplete, onUpdate: tweenUpdate, onUpdateArgs: [tweenObject, tweenTo]});
			return this.currentTween;
		}
		
		public function cancelTween():void {			
			if (this.currentTween!=0) {
				Starling.juggler.removeByID(this.currentTween);
				this.currentTween = 0;
			}
		}		
		public function isTweening():Boolean {
			return currentTween != 0;
		}		
		protected function tweenUpdate(tweenObject:Object, tweenTo:Object):void {
			// scale tween is much slower then position
			
			var ratio:Number = tweenObject.ratio;
			var r1:Number = tweenTransition(ratio);
			var r2:Number = tweenTransition(ratio * 3 <= 1 ? ratio * 3 : 1); // faster ratio
			
			var currentScale:Number = tweenObject.scale + (tweenTo.scale - tweenObject.scale) * r1;
			var currentX:Number = tweenObject.x + (tweenTo.x - tweenObject.x) * r2;
			var currentY:Number = tweenObject.y + (tweenTo.y - tweenObject.y) * r2;
			
			_touchSheet.scaleX = _touchSheet.scaleY = currentScale;
			setCenterXY(currentX, currentY);
		}
		
		protected function tweenComplete():void {
			Starling.juggler.removeByID(this.currentTween);
			this.currentTween = 0;
		}
		
		//*************************************************************//
		//********************  Event Listeners  **********************//
		//*************************************************************//
		
		private function onEnterFrame(e:EnterFrameEvent):void {
			if(this.isEnabled){
				update();
			}
		}
		
		private function onTouch(e:TouchEvent):void {
			var touch:Touch = e.getTouch(this, TouchPhase.MOVED);
			if (touch)
				cancelTween();
			
			touch = e.getTouch(_markersContainer, TouchPhase.ENDED);
			if (touch) {
				var displayObject:DisplayObject = touch.target;
				if (displayObject && displayObject.parent.parent == _markersContainer) {
					var marker:MapMarker = getMarker(displayObject.parent.name);
					dispatchEvent(new MapEvent(MapEvent.MARKER_TRIGGERED, false, marker));
				}
			}
		}
		
		private function onNativeStageMouseWheel(e:MouseEvent):void {
			
			if(this.isEnabled){
				
				/*var point:Point = globalToLocal(new Point(Starling.current.nativeStage.mouseX, Starling.current.nativeStage.mouseY));
				
				point.x = point.x*MainData.UNSCALE;
				point.y = point.y*MainData.UNSCALE;
				
				if(point.x>bounds.x && point.x<bounds.x+bounds.width){
					
					if(e.delta>0){
						this.zoomIn();
					}else{
						this.zoomOut(); 
					}
				}*/
				
				if(e.delta>0){
					this.zoomIn();
				}else{
					this.zoomOut(); 
				}
			}
			
		}
		protected function _zoomInOut($in:Boolean=true):void{
			trace(mapOptions.minimumScale);
			var center:Point = getCenter();
			var newScale:Number = _touchSheet.scaleX / ($in?0.5:2); //in is 0.5, out is 2
			newScale = Math.max(mapOptions.minimumScale, newScale);
			newScale = Math.min(mapOptions.maximumScale, newScale);
			tweenTo(center.x, center.y, newScale, 0.3);
		}
		public function zoomIn():void{
			this._zoomInOut(true);
		}
		public function zoomOut():void{
			this._zoomInOut(false);
			
		}
		protected function _zoomToScale($lvl:int):Number{
			var numScale:Number = 1;
			if($lvl<0)$lvl=1;
			if($lvl>18)$lvl=18;
			var numA:Number = $lvl-1;
			for(var i:int=0; i<numA; i++){
				numScale = numScale/2;
			}
			
			return numScale;
		}
		
		public function setZoom($lvl:int, $speed:Number=0.3):void{
			var center:Point = getCenter();
			
			var numScale:Number = this._zoomToScale($lvl);
			numScale = Math.max(mapOptions.minimumScale, numScale);
			numScale = Math.min(mapOptions.maximumScale, numScale);
			tweenTo(center.x, center.y, numScale, $speed);
		}
		
		private function sortMarkersFunction(d1:DisplayObject, d2:DisplayObject):int {
			return d1.x > d2.x ? 1 : -1;
		}
	
	}
}
