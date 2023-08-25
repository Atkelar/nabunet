namespace NabuNet.Models
{
    public class BootstrapParameters
    {
        /// <summary>
        /// Provides the preshared init secret for the server. MUST match the server side 
        /// configured value and is used as a means of authenticating the request before
        /// bootstrapping the user management system.
        /// </summary>
        public string Secret { get; set; }

    }
}