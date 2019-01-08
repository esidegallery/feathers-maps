package cz.j4w.map 
{
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import starling.animation.Transitions;
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
		
		protected static const MINIMUM_VELOCITY:Number = 0.1;
		
		public var disableMovement:Boolean;
		public var disableRotation:Boolean;
		public var disableZooming:Boolean;
		
		private var _minimumScale:Number;
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
		
		private var _maximumScale:Number;
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
		
		private var _elasticity:Number = 0.85;
		public function get elasticity():Number
		{
			return _elasticity;
		}
		public function set elasticity(value:Number):void
		{
			_elasticity = MathUtil.clamp(value, 0, 1);
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
			_snapToBounds = true;
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
			_snapToBounds = true;
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
		private var _snapToBounds:Boolean;
		private var scale2:Number;
		private var _velocity:Point = new Point;
		public function get velocity():Point
		{
			return _velocity.clone();
		}

		private var scaleTweenID:uint;
		
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
			var prevX:Number = x;
			var prevY:Number = y;
			var prevPivotX:Number = pivotX;
			var prevPivotY:Number = pivotY;
			
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
				x = point.x;
				y = point.y;
				
				Pool.putPoint(point);
				Pool.putPoint(currentPosA);
				Pool.putPoint(previousPosA);
				Pool.putPoint(currentPosB);
				Pool.putPoint(previousPosB);
				
				if (!disableRotation && deltaAngle !== 0)
				{
					rotation += deltaAngle;
					dispatchEventWith(ROTATE);
				}
				
				var sizeDiff:Number = currentVector.length / previousVector.length;
				if (!disableZooming && sizeDiff !== 1)
				{
					scale2 *= sizeDiff;
					if (scale2 < minimumScale) 
					{
						scale = scale2 + (minimumScale - scale2) * _elasticity;
					}
					else if (scale2 > maximumScale)
					{
						scale = scale2 - (scale2 - maximumScale) * _elasticity;
					}
					else
					{
						scale = scale2;
					}
					dispatchEventWith(ZOOM);
				}
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
						x += delta.x;
						y += delta.y;
						
						dispatchEventWith(MOVE);
					}
					Pool.putPoint(delta);
				}
			}
			else
			{
				endTouch();
			}
			
			if (_isTouching)
			{
				_velocity.setTo((x - pivotX) - (prevX - prevPivotX), (y - pivotY) - (prevY - prevPivotY));
				invalidateBounds();
			}
		}
		
		protected function startTouch(numTouchPoints:int):void
		{
			cancelScaleTween();
			if (!_isTouching)
			{
				trace(scale);
				_isTouching = true;
				scale2 = scale;
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
				dispatchEventWith(TOUCH_END);
			}
		}
		
		public function scaleTo(newScale:Number, pivotX:Number = NaN, pivotY:Number = NaN, duration:Number = 0):void
		{
			if (_isTouching)
			{
				return;
			}
			
			cancelScaleTween();
			
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
						transition: Transitions.EASE_OUT,
						scale: finalScale,
						onUpdate: invalidateBounds
					});
				}
				else
				{
					scale = finalScale;
					invalidateBounds();
				}
			}
		}
		
		protected function cancelScaleTween():void
		{
			if (scaleTweenID)
			{
				Starling.juggler.removeByID(scaleTweenID);
				scaleTweenID = 0;
			}
		}
		
		protected function applyScaleBounds(animate:Boolean):void
		{
			cancelScaleTween();
			scaleTo(scale, pivotX, pivotY, animate ? _elasticity * 0.4 : 0);
		}
		
		protected function getMovementGravity():Point
		{
			var gravity:Point = new Point;
			
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
			
			dispatchEventWith(Event.CHANGE);
			
			if (!_isTouching) 
			{
				var prevX:Number = x;
				var prevY:Number = y;
				var gravity:Point = getMovementGravity();
				
				if (!_snapToBounds && (Math.abs(_velocity.length) > MINIMUM_VELOCITY || Math.abs(gravity.length) > MINIMUM_VELOCITY))
				{
					_velocity.x *= decelerationRatio * (gravity.x ? _elasticity : 1);
					_velocity.y *= decelerationRatio * (gravity.y ? _elasticity : 1);
					x += _velocity.x + gravity.x * (1 - _elasticity);
					y += _velocity.y + gravity.y * (1 - _elasticity);
				}
				else
				{
					_velocity.setTo(0, 0);
					x += gravity.x;
					y += gravity.y;
				}
				
				if (prevX.toFixed(2) == x.toFixed(2) && prevY.toFixed(2) == y.toFixed(2)) // Full precision may result in a flip-flop effect.
				{
					boundsInvalid = false;
				}
				
				_snapToBounds = false;
			}
			else
			{
				boundsInvalid = false;
			}
		}
		
		public function killVelocity():void
		{
			_velocity.setTo(0, 0);
		}
		
		public function snapToBounds():void
		{
			endTouch();
			applyScaleBounds(false);
			invalidateBounds();
			_snapToBounds = true;
			_velocity.setTo(0, 0);
			validateNow();
		}
	}
}
