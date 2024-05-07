using System;

namespace NabuNet.ModemPacktes
{
    public class UpdateImageDownloadRequest
        : BasePacket
    {
        public UpdateImageDownloadRequest()
            : base(8)
        {
        }

        protected override void DeserializeNow(ArraySegment<byte> data)
        {
            Type = data[0];
            Asset = ExtractInt(data, 1);
            Offset = ExtractInt(data, 5);
        }
        public byte Type { get; set; }
        public int Asset { get; set; }
        public int Offset { get; set; }

        protected override int SerializeNow(ArraySegment<byte> data)
        {
            throw new NotImplementedException();
        }
    }
}