namespace NabuNet
{
    public class VirtualServerDetails
    {
        /// <summary>
        /// True if the server is running in "NabuNet" mode, false if it is running in "Legacy" mode (not yet implemented!)
        /// </summary>
        /// <remarks>
        /// <para>The "legacy" mode will enable the original Nabu HCCA protocol and provide resources from this virtual server in a way that allows hosting original Nabu content. The NabuNet version will run the "NabuNet" version of the HCCA protocol and provide features based on the NabuNet kernel...</para>
        /// </remarks>
        public bool IsNabuNet { get; set; }

        /// <summary>
        /// The kernel is the ID of the kernel that the client needs to load to boot into this server.
        /// </summary>
        public int Kernel { get; set; }

        /// <summary>
        /// The "loader" is the ID of what other OSs might call "shell" for lack of a better term. Depending on the 
        /// kernel type and/or other settings this should be an applicatoin that is auto-chained from the 
        /// kernel and re-loaded when a program "exits".
        /// </summary>
        public int Loader { get; set; }

        /// <summary>
        /// Generic information about the server...
        /// </summary>
        public VirtualServerInfo Info { get; set; }
    }
}