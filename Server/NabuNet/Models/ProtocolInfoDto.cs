
namespace NabuNet
{

    public class ProtocolInfoDto
    {
        /// <summary>
        /// The server name / title. Set by the admins.
        /// </summary>
        public string Name { get; set; } = "?";
        /// <summary>
        /// The server tag line; a subtitle of sorts for added "coolness" ;)
        /// </summary>
        public string TagLine { get; set; } = "?";
        /// <summary>
        /// The version of the server software that is running in the background.
        /// </summary>
        public string ServerVersion { get; set; } = "unknown";
        /// <summary>
        /// The supported API version for the Nabu Modem protocol. Currently 1-255 maximum, as it is encoded as byte there and "0" is used for "not connected" indications.
        /// </summary>
        public int ApiVersion { get; set; }
        /// <summary>
        /// True, if the server has "guest" users enabled. These are temporary users that allow exploring features and content and expire after a given timeout...
        /// </summary>
        public bool SupportsGuest { get; set; }
        /// <summary>
        /// The number of minutes that a new guest account can be used on this system. Note: this number is currently treated as "sliding expiration". i.e. as long as the account is active within the timeout, it will stay active.
        /// </summary>
        public int GuestTimeout { get; set; }

        /// <summary>
        /// True, if the server supports logins via the Modem. False if only anonymous access is allowed.
        /// </summary>
        public bool SupportsLogin { get; set; }

        /// <summary>
        /// True, if the server supports "virtual servers" - i.e. "channel codes". If false, only channel code "00000" is going to be served to clients.
        /// </summary>
        public bool SupportsVirtualServers { get; set; }
    }
}