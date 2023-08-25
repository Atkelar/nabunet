namespace NabuNet.ProgramModel
{

    [System.Serializable]
    public class InvalidAssetDefinitionException : System.Exception
    {
        public InvalidAssetDefinitionException() { }
        public InvalidAssetDefinitionException(string message) : base(message) { }
        public InvalidAssetDefinitionException(string message, System.Exception inner) : base(message, inner) { }
        protected InvalidAssetDefinitionException(
            System.Runtime.Serialization.SerializationInfo info,
            System.Runtime.Serialization.StreamingContext context) : base(info, context) { }
    }
}