using System;

namespace NabuNet.ModemPacktes
{
    public class ModemConnectRequest
        : BasePacket
    {
        public ModemConnectRequest()
            : base(0)
        {

        }
        public string ModemVersion { get; set; }
        public string ModemConfigVersion { get; set; }
        public string MacAddress { get; set; }
        public byte RequestedApiVersion { get; set; }

        protected override void DeserializeNow(ArraySegment<byte> data)
        {
            MacAddress = string.Format("{0:X2}:{1:X2}:{2:X2}:{3:X2}:{4:X2}:{5:X2}", data[0], data[1], data[2], data[3], data[4], data[5]);
            RequestedApiVersion = data[6];
            int ofs = 7;
            ModemVersion = ExtractString(data, ofs, out ofs);
            ModemConfigVersion = ExtractString(data, ofs, out _);
        }
        protected override int SerializeNow(ArraySegment<byte> data)
        {
            throw new NotImplementedException();
        }
    }
}