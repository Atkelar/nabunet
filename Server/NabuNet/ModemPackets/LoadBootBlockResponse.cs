using System;

namespace NabuNet.ModemPacktes
{
    public class LoadBootBlockResponse
        : BasePacket
    {
        public LoadBootBlockResponse()
            : base(5)
        {

        }

        public bool IsLastBlock { get; set; }
        public byte[] Data { get; set; }

        protected override void DeserializeNow(ArraySegment<byte> data)
        {
            throw new NotImplementedException();
        }
        protected override int SerializeNow(ArraySegment<byte> data)
        {
            if (Data != null)
            {
                data[0] = (byte)(IsLastBlock ? 3 : 1);
                PutWord(data, 1, Data.Length);
                for (int i = 0; i < Data.Length; i++)
                {
                    data[3 + i] = Data[i];
                }
                return 3 + Data.Length;
            }
            else
            {
                data[0] = 0;
                return 1;
            }
        }
    }
}