using System.Collections.Generic;

namespace NabuNet.Models
{
    public class ServerListModel
    {
        public bool HasVirtualServers { get; set; }
        public VirtualServerInfo RootServer { get; set; }
        public IEnumerable<VirtualServerInfo> Virtuals { get; set; }
    }
}