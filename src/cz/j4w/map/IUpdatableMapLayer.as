package cz.j4w.map
{
	public interface IUpdatableMapLayer
	{
		function get suspendUpdates():Boolean;
		function set suspendUpdates(value:Boolean):void;

		function update():void;
	}
}