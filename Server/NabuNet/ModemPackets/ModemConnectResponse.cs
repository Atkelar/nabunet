using System;

namespace NabuNet.ModemPacktes
{
    public class ModemConnectResponse
        : BasePacket
    {
        public ModemConnectResponse()
            : base(1)
        {

        }
        public string ServerVersion { get; set; }
        public byte ServerApiVersion { get; set; }
        public bool GuestAccess { get; set; }
        public bool AllowLogin { get; set; }
        public bool HasVirtualServers { get; set; }
        public bool IsReadOnly { get; set; }
        public string ServerName { get; set; }

        protected override void DeserializeNow(ArraySegment<byte> data)
        {
            throw new NotImplementedException();
        }

        // flags bits need to be sync'd with firmware in modem and config software!
        [Flags]
        private enum ServerFeatureFlags
        {
            HasGuestSupport = 1,
            HasLoginSupport = 2,
            IsReadOnly = 4,
            HasVirtualServers = 8
        }

        protected override int SerializeNow(ArraySegment<byte> data)
        {
            data[0] = ServerApiVersion;
            byte flags = 0;
            if (GuestAccess)
                flags |= (byte)ServerFeatureFlags.HasGuestSupport;
            if (AllowLogin)
                flags |= (byte)ServerFeatureFlags.HasLoginSupport;
            if (IsReadOnly)
                flags |= (byte)ServerFeatureFlags.IsReadOnly;
            if (HasVirtualServers)
                flags |= (byte)ServerFeatureFlags.HasVirtualServers;

            data[1] = flags;
            int pos = PutString(data, 2, ServerVersion, 32);
            return PutString(data, pos, ServerName, 32);
        }
    }
}