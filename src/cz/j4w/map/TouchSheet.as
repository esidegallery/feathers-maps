package cz.j4w.map 
{
	import com.greensock.easing.ExpoScaleEase;
	import com.greensock.easing.Power1;
	
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import feathers.utils.math.clamp;
	
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.display.Sprite;
	import starling.events.EnterFrameEvent;
	import starling.events.Event;
	import starling.events.Touch;
	import starling.events.TouchEvent;
	import starling.events.TouchPhase;
	import starling.utils.MathUtil;
	import starling.utils.Pool;
	
	/**
	 * ...
	 * @author Jakub Wagner, J4W
	 */
	public class TouchSheet extends Sprite 
	{
		public static const TOUCH_START:String = "touchStart";
		public static const TOUCH_END:String = "touchEnd";
		public static const MOVE:String = "move";
		public static const ZOOM:String = "zoom";
		public static const ROTATE:String = "rotate";
		
		public static const MINIMUM_VELOCITY:Number = 0.1;
		
		/** Previous velocities are saved for an accurate measurement at the end of a touch. */
		private static const MAXIMUM_SAVED_VELOCITY_COUNT:int = 3;
		
		public var disableMovement:Boolean;
		public var disableRotation:Boolean;
		public var disableZooming:Boolean;
		
		private var _minimumScale:Number = 0;
		public function get minimumScale():Number
		{
			return _minimumScale;
		}
		public function set minimumScale(value:Number):void
		{
			if (_minimumScale != value)
			{
				_minimumScale = value;
				applyScaleBounds(false);
				invalidateBounds();
			}
		}
		
		private var _maximumScale:Number = Number.MAX_VALUE;
		public function get maximumScale():Number
		{
			return _maximumScale;
		}
		public function set maximumScale(value:Number):void
		{
			if (_maximumScale != value)
			{
				_maximumScale = value;
				applyScaleBounds(false);
				invalidateBounds();
			}
		}
		
		protected var _touchElasticity:Number = 0.3;
		public function get touchElasticity():Number
		{
			return _touchElasticity;
		}
		public function set touchElasticity(value:Number):void
		{
			_touchElasticity = value;
		}
		
		private var _nonTouchElasticity:Number = 0.85;
		public function get nonTouchElasticity():Number
		{
			return _nonTouchElasticity;
		}
		public function set nonTouchElasticity(value:Number):void
		{
			_nonTouchElasticity = MathUtil.clamp(value, 0, 1);
		}
		
		private var _decelerationRatio:Number = 0.95;
		public function get decelerationRatio():Number
		{
			return _decelerationRatio;
		}
		public function set decelerationRatio(value:Number):void
		{
			_decelerationRatio = MathUtil.clamp(value, 0, 1);
		}
		
		private var _movementBounds:Rectangle;
		public function get movementBounds():Rectangle 
		{
			return _movementBounds;
		}
		public function set movementBounds(value:Rectangle):void 
		{
			_movementBounds = value;
			invalidateBounds();
			snapToBoundsPending = true;
		}
		
		private var _viewPort:Rectangle;
		public function get viewPort():Rectangle
		{
			return _viewPort;
		}
		public function set viewPort(value:Rectangle):void
		{
			_viewPort = value;
			invalidateBounds();
			snapToBoundsPending = true;
		}
		
		/** Set this when the viewport size changes or when TouchSheet dispatches Event.CHANGE so that movementBounds can be applied. */ 
		public function setViewportTo(xa:Number, ya:Number, widtha:Number, heighta:Number):void
		{
			if (viewPort) 
			{
				viewPort.setTo(xa, ya, widtha, heighta);
			}
			else
			{
				viewPort = new Rectangle(xa, ya, widtha, heighta);
			}
			invalidateBounds();
		}
		
		private var _isTouching:Boolean;
		public function get isTouching():Boolean
		{
			return _isTouching;
		}
		
		protected var _isEnabled:Boolean = true;
		public function get isEnabled():Boolean
		{
			return _isEnabled;
		}
		public function set isEnabled(value:Boolean):void
		{
			_isEnabled = value;
			if (!_isEnabled)
			{
				endTouch();
			}
		}
		
		private var touchAID:int = -1;
		private var touchBID:int = -1;
		
		private var boundsInvalid:Boolean
		private var snapToBoundsPending:Boolean;
		private var shadowX:Number;
		private var shadowY:Number;
		private var shadowScale:Number;
		private var previousX:Number;
		private var previousY:Number;
		private var previousPivotX:Number;
		private var previousPivotY:Number;
		private var previousVelocities:Vector.<Point> = new Vector.<Point>;
		private var pendingVelocityChange:Boolean;
		private var _velocity:Point = new Point;
		public function get velocity():Point
		{
			return _velocity.clone();
		}

		private var scaleTweenID:uint;
		private var viewTweenID:int; 
		
		/**
		 * Image
		 * @param	contents		DisplayObject to insert immiadiatly as a child.
		 * @param	params			Object with params...
		 *
		 * 							disableZooming
		 * 							disableRotation
		 * 							disableMovement
		 * 							movementBounds
		 * 							minimumScale
		 * 							maximumScale
		 */
		public function TouchSheet(contents:DisplayObject, viewPort:Rectangle = null, params:Object = null) 
		{
			this.viewPort = viewPort || new Rectangle;
			params ||= {};
			
			disableZooming = params.disableZooming ? true : false;
			disableRotation = params.disableRotation ? true : false;
			disableMovement = params.disableMovement ? true : false;
			minimumScale = params.minimumScale;
			maximumScale = params.maximumScale;
			movementBounds = params.movementBounds;
			
			addChild(contents);
			
			addEventListener(TouchEvent.TOUCH, onTouch);
			addEventListener(EnterFrameEvent.ENTER_FRAME, validateNow);
		}
		
		private function onTouch(event:TouchEvent):void
		{
			if (!isEnabled)
			{
				return;
			}
			
			var prevAID:int = touchAID;
			var prevBID:int = touchBID;
			
			// first check if the existing touches ended
			if (touchBID != -1)
			{
				if (event.getTouch(this, TouchPhase.ENDED, touchBID))
				{
					touchBID = -1;
				}
			}
			if (touchAID != -1) // we checeked touch b first because a might be replaced by b
			{
				if (event.getTouch(this, TouchPhase.ENDED, touchAID))
				{
					touchAID = touchBID;
					touchBID = -1;
				}
			}
			// then, check for new touches, if necessary
			if (touchAID == -1 || touchBID == -1)
			{
				var touches:Vector.<Touch> = event.getTouches(this, TouchPhase.BEGAN);
				var touchCount:int = touches.length;
				for (var i:int = 0; i < touchCount; i++)
				{
					var touch:Touch = touches[i];
					if (touchAID == -1)
					{
						touchAID = touch.id;
					}
					else if (touchBID == -1)
					{
						touchBID = touch.id;
					}
				}
			}
			
			// do a multi-touch gesture if we have enough touches
			if (touchAID != -1 && touchBID != -1 && (!disableRotation || !disableZooming || !disableMovement))
			{
				// two fingers touching -> rotate and scale
				startTouch(2);
				
				var touchA:Touch = event.getTouch(this, null, touchAID);
				var touchB:Touch = event.getTouch(this, null, touchBID);
				
				if (!touchA || !touchB || touchA.phase != TouchPhase.MOVED && touchB.phase != TouchPhase.MOVED)
				{
					//neither touch moved, so nothing has changed
					return;
				}
				
				var currentPosA:Point  = touchA.getLocation(stage, Pool.getPoint());
				var previousPosA:Point = touchA.getPreviousLocation(stage, Pool.getPoint());
				var currentPosB:Point  = touchB.getLocation(stage, Pool.getPoint());
				var previousPosB:Point = touchB.getPreviousLocation(stage, Pool.getPoint());
				
				var currentVector:Point  = currentPosA.subtract(currentPosB);
				var previousVector:Point = previousPosA.subtract(previousPosB);
				
				var currentAngle:Number  = Math.atan2(currentVector.y, currentVector.x);
				var previousAngle:Number = Math.atan2(previousVector.y, previousVector.x);
				var deltaAngle:Number = currentAngle - previousAngle;
				
				// update pivot point based on previous center
				var point:Point = Pool.getPoint(
					(previousPosA.x + previousPosB.x) * 0.5,
					(previousPosA.y + previousPosB.y) * 0.5
				);
				globalToLocal(point, point);
				pivotX = point.x;
				pivotY = point.y;
				
				// update location based on the current center
				point.setTo(
					(currentPosA.x + currentPosB.x) * 0.5,
					(currentPosA.y + currentPosB.y) * 0.5
				);
				parent.globalToLocal(point, point);
				
				shadowX = point.x;
				shadowY = point.y;
				x = shadowX;
				y = shadowY;
				
				
				Pool.putPoint(currentPosA);
				Pool.putPoint(previousPosA);
				Pool.putPoint(currentPosB);
				Pool.putPoint(previousPosB);
				Pool.putPoint(point);
				Pool.putPoint(gravity);
				
				if (!disableRotation && deltaAngle !== 0)
				{
					rotation += deltaAngle;
					dispatchEventWith(ROTATE);
				}
				
				var sizeDiff:Number = currentVector.length / previousVector.length;
				if (!disableZooming && sizeDiff !== 1)
				{
					shadowScale *= sizeDiff;
					if (shadowScale < minimumScale) 
					{
						scale = shadowScale + (minimumScale - shadowScale) * (1 - _touchElasticity);
					}
					else if (shadowScale > maximumScale)
					{
						scale = shadowScale - (shadowScale - maximumScale) * (1 - _touchElasticity);
					}
					else
					{
						scale = shadowScale;
					}
					dispatchEventWith(ZOOM);
				}
				
				// After everything, apply movement gravity:
				// Currently only works for elasticity = 0:
				// Perhaps shadowX & Y could be applied before grabbing the touch location values?
				if (nonTouchElasticity == 0)
				{
					dispatchEventWith(Event.CHANGE);
					var gravity:Point = getMovementGravity(Pool.getPoint());
					x += gravity.x;
					y += gravity.y;
				}
				
				pendingVelocityChange = true;
				dispatchEventWith(MOVE);
			}
			else if (touchAID != -1) //single touch gesture
			{
				startTouch(1);
				
				touchA = event.getTouch(this, null, touchAID);
				
				if (!disableMovement)
				{
					// one finger touching -> move
					var delta:Point = touchA.getMovement(stage, Pool.getPoint());
					if(delta.length !== 0)
					{
						shadowX += delta.x;
						shadowY += delta.y;
						x = shadowX;
						y = shadowY;
						
						dispatchEventWith(Event.CHANGE);
						gravity = getMovementGravity(Pool.getPoint());
						// Pull back according to gravity:
						x += gravity.x * (1 - _touchElasticity);
						y += gravity.y * (1 - _touchElasticity);
						Pool.putPoint(gravity);
						
						pendingVelocityChange = true;
						dispatchEventWith(MOVE);
					}
					Pool.putPoint(delta);
				}
			}
			else
			{
				endTouch();
			}
		}
		
		protected function saveVelocity():void
		{
			pendingVelocityChange = false;
			if (_isTouching)
			{
				_velocity.setTo((x - pivotX) - (previousX - previousPivotX), (y - pivotY) - (previousY - previousPivotY));
				previousVelocities.push(Pool.getPoint(_velocity.x, _velocity.y));
				if (previousVelocities.length > MAXIMUM_SAVED_VELOCITY_COUNT)
				{
					Pool.putPoint(previousVelocities.shift());
				}
				invalidateBounds();
				previousX = x;
				previousY = y;
				previousPivotX = pivotX;
				previousPivotY = pivotY;
			}
		}
		
		protected function startTouch(numTouchPoints:int):void
		{
			cancelTweens();
			
			if (!_isTouching)
			{
				killVelocity();
				_isTouching = true;
				previousX = x;
				previousY = y;
				previousPivotX = pivotX;
				previousPivotY = pivotY;
				shadowX = x;
				shadowY = y;
				shadowScale = scale;
				addEventListener(Event.ENTER_FRAME, saveVelocity);
				dispatchEventWith(TOUCH_START);
			}
		}
		
		protected function endTouch():void
		{
			if (_isTouching) 
			{
				_isTouching = false;
				touchAID = touchBID = -1;
				applyScaleBounds(true);
				invalidateBounds();
				removeEventListener(Event.ENTER_FRAME, saveVelocity);
				
				// Calculate the final velocity based on an average of the saved velocities:
				var weight:Number = 1;
				var totalWeight:Number = 0;
				var sumX:Number = 0;
				var sumY:Number = 0;
				for (var i:int = 0, l:int = previousVelocities.length; i < l; i++)
				{
					var v:Point = previousVelocities.shift();
					sumX += v.x * weight;
					sumY += v.y * weight;
					totalWeight += weight;
					Pool.putPoint(v);
					weight *= 1.33;
				}
				_velocity.setTo(sumX / totalWeight || 0, sumY / totalWeight || 0);
				
				dispatchEventWith(TOUCH_END);
			}
		}
		
		public function setCenter(point:Point):void
		{
			setCenterXY(point.x, point.y);
		}
		
		public function setCenterXY(centerX:Number, centerY:Number):void 
		{
			if (_viewPort)
			{
				pivotX = centerX;
				pivotY = centerY;
				x = (_viewPort.width / 2) * scale;
				y = (_viewPort.height / 2) * scale;
			}
		}
		
		/**
		 * Uses GreenSock's amazing ExpoScaleEase to maintain constant velocity over multiple scale factors.
		 * @param centerX Pass NaN to keep this value as is.
		 * @param centerY Pass NaN to keep this value as is.
		 * @param scale Pass NaN to keep this value as is.
		 * @param duration In seconds.
		 * @param transition A value of <code>starling.animation.Transitions</code>.
		 */
		public function tweenTo(centerX:Number = NaN, centerY:Number = NaN, scale:Number = NaN, duration:Number = 1, transition:String = "easeInOut"):void
		{
			if (!_viewPort)
			{
				return;
			}
			
			cancelTweens();
			
			setCenterXY(_viewPort.x + _viewPort.width / 2, _viewPort.y + _viewPort.height / 2);
			var viewCenter:Point = getViewCenter();
			
			var toScale:Number = isNaN(scale) ? this.scale : clamp(scale, minimumScale, maximumScale);
			var scaleDiff:Number = toScale / this.scale;
			
			var projectedViewPortWidth:Number = _viewPort.width / scaleDiff;
			var projectedViewPortHeight:Number = _viewPort.height / scaleDiff;
			
			if (movementBounds)
			{
				if (projectedViewPortWidth > movementBounds.width)
				{
					var minToX:Number = movementBounds.left + movementBounds.width / 2;
					var maxToX:Number = minToX;
				}
				else
				{
					minToX = movementBounds.left + projectedViewPortWidth / 2;
					maxToX = movementBounds.right - projectedViewPortWidth / 2;
				}
				if (projectedViewPortHeight > movementBounds.height)
				{
					var minToY:Number = movementBounds.top + movementBounds.height / 2;
					var maxToY:Number = minToY;
				}
				else
				{
					minToY = movementBounds.top + projectedViewPortHeight / 2;
					maxToY = movementBounds.bottom - projectedViewPortHeight / 2;
				}
			}
			else
			{
				minToX = maxToX = minToY = maxToY = Number.MAX_VALUE;
			}
			
			// Work out a min/max centerX/Y based on projected 
			
			var tweenTarget:Object = {
				ratio: 0,
				fromX: viewCenter.x,
				toX: isNaN(centerX) ? viewCenter.x : clamp(centerX, minToX, maxToX),
				fromY: viewCenter.y,
				toY: isNaN(centerY) ? viewCenter.y : clamp(centerY, minToY, maxToY),
				fromScale: this.scale,
				toScale: toScale,
				expoScaleEase: new ExpoScaleEase(this.scale, scale),
				expoMoveEase: new ExpoScaleEase(scale, this.scale)
			};
			if (duration > 0)
			{
				viewTweenID = Starling.juggler.tween(tweenTarget, duration, {
					ratio: 1, 
					transition: transition, 
					onUpdate: onViewTweenUpdate, 
					onUpdateArgs: [tweenTarget],
					onComplete: function():void
					{
						tweenTarget.ratio = 1;
						onViewTweenUpdate(tweenTarget);
						killVelocity();
					}
				});
			}
			else
			{
				tweenTarget.ratio = 1;
				onViewTweenUpdate(tweenTarget);
				killVelocity();
			}
		}
		
		protected function onViewTweenUpdate(tweenTarget:Object):void 
		{
			var scaleRatio:Number = (tweenTarget.expoScaleEase as ExpoScaleEase).getRatio(tweenTarget.ratio);
			var moveRatio:Number = (tweenTarget.expoMoveEase as ExpoScaleEase).getRatio(tweenTarget.ratio);
			
			var currentScale:Number = tweenTarget.fromScale + (tweenTarget.toScale - tweenTarget.fromScale) * scaleRatio;
			var currentX:Number = tweenTarget.fromX + (tweenTarget.toX - tweenTarget.fromX) * moveRatio;
			var currentY:Number = tweenTarget.fromY + (tweenTarget.toY - tweenTarget.fromY) * moveRatio;
			
			setCenterXY(currentX, currentY);
			scale = currentScale;
			
			dispatchEventWith(Event.CHANGE);
		}
		
		public function getViewCenter():Point 
		{
			return new Point(viewPort.x + viewPort.width / 2, viewPort.y + viewPort.height / 2);
		}
		
		public function zoomIn(center:Point = null):void
		{
			zoomInOut(true, center);
		}
		
		public function zoomOut(center:Point = null):void
		{
			zoomInOut(false, center);
		}
		
		protected function zoomInOut($in:Boolean = true, center:Point = null):void
		{
			var newScale:Number = scale / ($in ? 0.5 : 2);
			center ||= getViewCenter();
			scaleTo(newScale, center.x, center.y, 0.3);
		}
		
		public function scaleTo(newScale:Number, pivotX:Number = 0, pivotY:Number = 0, duration:Number = 0):void
		{
			if (_isTouching)
			{
				return;
			}
			
			cancelTweens();
			
			this.x += (pivotX - this.pivotX) * scale;
			this.y += (pivotY - this.pivotY) * scale;
			if (!isNaN(pivotX))
			{
				this.pivotX = pivotX;
			}
			if (!isNaN(pivotY))
			{
				this.pivotY = pivotY;
			}
			
			var finalScale:Number = MathUtil.clamp(newScale, minimumScale, maximumScale);
			if (scale != finalScale)
			{
				if (duration > 0)
				{
					scaleTweenID = Starling.juggler.tween(this, duration, {
						transitionFunc: new ExpoScaleEase(scale, finalScale, Power1.easeOut).getRatio,
						scale: finalScale,
						onUpdate: function():void
						{
							invalidateBounds();
							validateNow();
						},
						onComplete: killVelocity
					});
				}
				else
				{
					scale = finalScale;
					invalidateBounds();
					validateNow();
				}
			}
		}
		
		protected function cancelTweens():void
		{
			if (scaleTweenID)
			{
				Starling.juggler.removeByID(scaleTweenID);
				scaleTweenID = 0;
			}
			if (viewTweenID) 
			{
				Starling.juggler.removeByID(viewTweenID);
				viewTweenID = 0;
			}
		}
		
		protected function applyScaleBounds(animate:Boolean):void
		{
			cancelTweens();
			scaleTo(scale, pivotX, pivotY, animate ? _touchElasticity : 0);
		}
		
		protected function getMovementGravity(outPoint:Point = null):Point
		{
			var gravity:Point = outPoint || new Point;
			
			if (movementBounds && viewPort) 
			{
				if (viewPort.width > movementBounds.width) 
				{
					gravity.x = ((viewPort.left - movementBounds.left) + (viewPort.width - movementBounds.width) / 2) * scale;
				} 
				else if (viewPort.left < movementBounds.left) 
				{
					gravity.x = (viewPort.left - movementBounds.left) * scale;
				} 
				else if (viewPort.right > movementBounds.right) 
				{
					gravity.x = (viewPort.right - movementBounds.right) * scale;
				}
				
				if (viewPort.height > movementBounds.height) 
				{
					gravity.y = ((viewPort.top - movementBounds.top) + (viewPort.height - movementBounds.height) / 2) * scale;
				} 
				else if (viewPort.top < movementBounds.top) 
				{
					gravity.y = (viewPort.top - movementBounds.top) * scale;
				} 
				else if (viewPort.bottom > movementBounds.bottom) 
				{
					gravity.y = (viewPort.bottom - movementBounds.bottom) * scale;
				}
			}
			
			return gravity;
		}
		
		public function invalidateBounds():void
		{
			boundsInvalid = true;
		}
		
		public function validateNow():void
		{
			if (!boundsInvalid && !_velocity.length)
			{
				return;
			}
			
			
			if (!_isTouching) 
			{
				previousX = x;
				previousY = y;
				
				// Move according to velocity:
				x += velocity.x;
				y += velocity.y;
				
				dispatchEventWith(Event.CHANGE);
				
				// Get the gravity having moved:
				var gravity:Point = getMovementGravity(Pool.getPoint());
				
				if (!snapToBoundsPending && (Math.abs(_velocity.length) > MINIMUM_VELOCITY || Math.abs(gravity.length) > MINIMUM_VELOCITY))
				{
					// Pull back according to gravity:
					x += gravity.x * (1 - _nonTouchElasticity);
					y += gravity.y * (1 - _nonTouchElasticity);
					// Adjust velocity for the next frame:
					_velocity.x *= decelerationRatio * (gravity.x ? _nonTouchElasticity : 1);
					_velocity.y *= decelerationRatio * (gravity.y ? _nonTouchElasticity : 1);
				}
				else
				{
					_velocity.setTo(0, 0);
					x += gravity.x;
					y += gravity.y;
				}
				
				
				Pool.putPoint(gravity);
				
				if (previousX.toFixed(2) == x.toFixed(2) && previousY.toFixed(2) == y.toFixed(2)) // Full precision may result in a flip-flop effect.
				{
					boundsInvalid = false;
				}
				
				snapToBoundsPending = false;
			}
			else
			{
				dispatchEventWith(Event.CHANGE);
				boundsInvalid = false;
			}
		}
		
		public function killVelocity():void
		{
			_velocity.setTo(0, 0);
			while (previousVelocities.length)
			{
				Pool.putPoint(previousVelocities.pop());
			}
		}
		
		public function snapToBounds():void
		{
			endTouch();
			applyScaleBounds(false);
			invalidateBounds();
			snapToBoundsPending = true;
			_velocity.setTo(0, 0);
			validateNow();
		}
		
		override public function dispose():void
		{
			cancelTweens();
			killVelocity();
			super.dispose();
		}
	}
}
