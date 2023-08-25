using System;

namespace NabuNet.ModemPacktes
{
    public class LoadBootBlockRequest
        : BasePacket
    {
        public LoadBootBlockRequest()
            : base(4)
        {

        }

        public byte A { get; set; }
        public byte B { get; set; }
        public byte C { get; set; }

        public int Block { get; set; }
        public int BlockSize { get; set; }
        public int AssetId { get; set; }
        public int Channel { get; set; }

        protected override void DeserializeNow(ArraySegment<byte> data)
        {
            A = data[0];
            B = data[1];
            C = data[2];
            Block = ExtractWord(data, 3);
            BlockSize = ExtractWord(data, 5);
            AssetId = ExtractInt(data, 7);
            Channel = ExtractWord(data, 11);
        }

        protected override int SerializeNow(ArraySegment<byte> data)
        {
            throw new NotImplementedException();
        }
    }
}