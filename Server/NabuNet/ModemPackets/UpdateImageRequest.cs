using System;

namespace NabuNet.ModemPacktes
{
    public class UpdateImageRequest
        : BasePacket
    {
        public UpdateImageRequest()
            : base(6)
        {
        }

        protected override void DeserializeNow(ArraySegment<byte> data)
        {
        }
        protected override int SerializeNow(ArraySegment<byte> data)
        {
            throw new NotImplementedException();
        }
    }
}