using System;

namespace NabuNet.ModemPacktes
{
    public class ValidateChannelCodeResponse
        : BasePacket
    {
        public ValidateChannelCodeResponse()
            : base(3)
        {

        }

        public bool IsValid { get; set; }
        public bool IsNabuNet { get; set; }
        public int KernelAsset { get; set; }
        public int LoaderAsset { get; set; }

        protected override void DeserializeNow(ArraySegment<byte> data)
        {
            throw new NotImplementedException();
        }
        protected override int SerializeNow(ArraySegment<byte> data)
        {
            data[0] = (byte)((IsValid ? 1 : 0) | (IsNabuNet ? 2 : 0));

            PutInt(data, 1, KernelAsset);
            PutInt(data, 5, LoaderAsset);

            return 9;
        }

    }
}