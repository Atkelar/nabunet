using System;

namespace NabuNet.ModemPacktes
{
    public class ValidateChannelCodeRequest
        : BasePacket
    {
        public ValidateChannelCodeRequest()
            : base(2)
        {

        }
        public int Code { get; set; }

        protected override void DeserializeNow(ArraySegment<byte> data)
        {
            Code = data[0] | data[1] << 8;
        }
        protected override int SerializeNow(ArraySegment<byte> data)
        {
            throw new NotImplementedException();
        }
    }
}